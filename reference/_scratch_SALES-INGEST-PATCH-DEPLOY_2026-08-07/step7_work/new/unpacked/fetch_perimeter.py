"""
fetch_perimeter.py — SALES-PERIMETER-EXTEND (ADR-103 §8, вариант (a) объекта паритета продаж).

Расширяет периметр ингеста продаж на два типа документов, которые `report/profit/*`
считает продажами, а `entity/demand`-ингест (fetch_demands.py) не читает вовсе
(подтверждено `grep -rn "retaildemand\\|commissionreportin"` по снапшоту — 0 совпадений
до этого патча, `reference/sales_h1h4_adj_2026-08-02.md §3` признак 4):

  - entity/retaildemand — розница.
  - entity/commissionreportin — продажи по отчёту комиссионера. Правило (ADR-104 §4):
    отчёт `report/profit/*` считает эти продажи ПОЛНОЙ суммой документа (`sum`,
    тождественно Σ price × quantity позиций), а НЕ суммой комитента (`commitentSum`).
    Ингест, взявший `commitentSum`, занизит выручку ровно на вознаграждение комиссионера.
    Это НЕ то же самое, что уже грузит cf-loss-commission (тот берёт reward/commissionOverhead
    в core.fact_commissionreportin, `ADR-026`) — здесь считается сама продажа.

Прецедент разреза (ADR-024): ОТДЕЛЬНЫЙ ингест, не расширение `_build_merge_sql`
(bq_ops.py) — та функция патчится отдельной задачей `SALES-REFRESH-WINDOW`
(окно/сироты/замороженная дата, `ADR-100 §7`); смешивать периметр с тем патчем
запрещено брифом `SALES-INGEST-PATCH`.

Правило суток (ADR-088 §3): дата — функция UTC-момента документа
(`DATE(PARSE_TIMESTAMP(...), 'Asia/Bishkek')`, см. `bq_ops.py::_PERIMETER_PARSE_DATE`),
не `moment_str[:10]`.

Ограничение метода, названное явно (не скрыто): форма позиций `entity/retaildemand`
подтверждена полями ответа (`reference/parity_sales_discriminate_step2_2026-08-02.md §Шаг 2`:
document incl. `agent`, `rate`, `positions`, `sum`, `store`) — по аналогии с `entity/demand`
предполагается тот же состав полей позиции (`price`, `quantity`, `discount`, `assortment`);
позиционный уровень (`positions.rows[]`) этой сессией живым `GET` не проверялся (класс B,
не выдан). Форма позиций `entity/commissionreportin` подтверждена измерением
(`reference/sales_perimeter_confirm_2026-08-02.md §6`: `price`, `quantity`, `assortment`,
`reward` — БЕЗ `discount`). Перед деплоем (класс B, отдельный мандат) оба предположения
о позиционной форме `retaildemand` обязаны быть проверены одним живым `GET` — названо в
`reference/sales_ingest_patch_<date>.md §Что не делает эта сессия`, не подразумевается молча.
"""

import logging
from datetime import date
from typing import Optional

import requests

from helpers import now_utc_str, paginate_entity, parse_href

log = logging.getLogger(__name__)


def _format_moment(d: date) -> str:
    """МойСклад datetime filter format: 'YYYY-MM-DD HH:MM:SS'."""
    return f"{d.isoformat()} 00:00:00"


def _fetch_positions_for(
    token: str,
    entity_path: str,
    docs: list[dict],
    doc_type: str,
    session: requests.Session,
    run_id: str,
    loaded_at: str,
    has_discount: bool,
) -> list[dict]:
    """
    Общая часть извлечения позиций для retaildemand/commissionreportin —
    тот же паттерн, что `fetch_demands.py::fetch_demand_positions` (expand=positions
    в list-режиме не работает, позиции — отдельным запросом на документ).
    """
    all_records: list[dict] = []
    skipped = 0

    for doc in docs:
        doc_id = doc.get("id")
        if not doc_id:
            skipped += 1
            continue

        agent_href = doc.get("agent", {}).get("meta", {}).get("href", "")
        agent_id = parse_href(agent_href)
        moment_str = doc.get("moment", "")

        positions = paginate_entity(
            token,
            f"{entity_path}/{doc_id}/positions",
            session=session,
        )

        if not positions:
            log.debug("%s %s has 0 positions — skipping", doc_type, doc_id)
            continue

        for pos in positions:
            pos_id = pos.get("id")
            if not pos_id:
                continue

            assortment = pos.get("assortment", {})
            assortment_meta = assortment.get("meta", {})
            product_href = assortment_meta.get("href", "")
            product_id   = parse_href(product_href)
            entity_type  = assortment_meta.get("type", "product")

            if not product_id:
                log.warning("Position %s in %s %s has no product_id — skipping", pos_id, doc_type, doc_id)
                continue

            currency_rate = doc.get("rate", {}).get("value") or 1.0
            price_kgs = pos.get("price", 0) / 100.0 * currency_rate
            quantity  = pos.get("quantity", 0.0)
            discount  = pos.get("discount", 0.0) if has_discount else 0.0
            revenue_kgs = round(price_kgs * quantity * (1.0 - discount / 100.0), 4)

            all_records.append({
                "run_id":               run_id,
                "doc_id":               doc_id,
                "source_doc_type":      doc_type,
                "position_id":          pos_id,
                "transaction_date_raw": moment_str,
                "product_id":           product_id,
                "agent_id":             agent_id,
                "quantity":             quantity,
                "price_kgs":            price_kgs,
                "discount":             discount,
                "revenue_kgs":          revenue_kgs,
                "entity_type":          entity_type,
                "_loaded_at":           loaded_at,
            })

    if skipped:
        log.warning("Skipped %d %s docs (missing id)", skipped, doc_type)

    return all_records


def fetch_retaildemand_positions(
    token: str,
    date_from: date,
    date_to: date,
    run_id: str,
    session: Optional[requests.Session] = None,
) -> list[dict]:
    """Fetch entity/retaildemand positions in [date_from, date_to]."""
    if session is None:
        session = requests.Session()

    loaded_at = now_utc_str()
    moment_from = _format_moment(date_from)
    moment_to   = f"{date_to.isoformat()} 23:59:59"

    log.info("Fetching retaildemand: %s → %s", moment_from, moment_to)

    docs = paginate_entity(
        token,
        "entity/retaildemand",
        params={
            "filter": f"moment>={moment_from};moment<={moment_to};applicable=true",
            "order": "moment,asc",
        },
        session=session,
    )
    log.info("Found %d retaildemand documents", len(docs))

    records = _fetch_positions_for(
        token, "entity/retaildemand", docs, "retaildemand", session, run_id, loaded_at,
        has_discount=True,
    )
    log.info("Fetched %d retaildemand position records from %d docs", len(records), len(docs))
    return records


def fetch_commission_sales_positions(
    token: str,
    date_from: date,
    date_to: date,
    run_id: str,
    session: Optional[requests.Session] = None,
) -> list[dict]:
    """
    Fetch продажи по entity/commissionreportin (сумма документа, ADR-104 §4) — НЕ то,
    что уже грузит cf-loss-commission (reward/commissionOverhead).
    """
    if session is None:
        session = requests.Session()

    loaded_at = now_utc_str()
    moment_from = _format_moment(date_from)
    moment_to   = f"{date_to.isoformat()} 23:59:59"

    log.info("Fetching commissionreportin sales: %s → %s", moment_from, moment_to)

    docs = paginate_entity(
        token,
        "entity/commissionreportin",
        params={
            "filter": f"moment>={moment_from};moment<={moment_to};applicable=true",
            "order": "moment,asc",
        },
        session=session,
    )
    log.info("Found %d commissionreportin documents", len(docs))

    records = _fetch_positions_for(
        token, "entity/commissionreportin", docs, "commissionreportin_sale", session, run_id, loaded_at,
        # positions.rows[] entity/commissionreportin НЕ несёт `discount` — подтверждено
        # ключами ответа (sales_perimeter_confirm_2026-08-02.md §6), не домысел.
        has_discount=False,
    )
    log.info("Fetched %d commissionreportin_sale position records from %d docs", len(records), len(docs))
    return records
