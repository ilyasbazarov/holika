"""
fetch_returns.py — fetch salesreturn + retailsalesreturn positions from МойСклад API.

Returns position-level records for core.fact_returns.

Notes:
  - expand=positions не работает в списочных запросах (подтверждено Аппендикс Е).
    Позиции тянутся отдельным запросом на каждый документ.
  - applicable=true: только проведённые документы.
  - cost field: присутствует у salesreturn без основания (тыйыны ÷ 100).
                ОТСУТСТВУЕТ у retailsalesreturn и salesreturn с основанием → 0.0.
  - has_basis: True только если есть ссылка на demand (только salesreturn).
               Для retailsalesreturn всегда False — розничный возврат без основания по определению.
"""

import logging
import time
from datetime import date

import requests as req_lib

from helpers import get_token, paginate_entity, parse_href, parse_moment_to_bishkek_date

log = logging.getLogger(__name__)

# МойСклад rate limit: 5 req/sec. При 100+ документах позиции тянутся отдельно.
_POSITION_REQUEST_DELAY = 0.21  # чуть больше 1/5 сек — запас на jitter


def fetch_return_positions(
    token: str,
    date_from: date,
    date_to: date,
    session: req_lib.Session | None = None,
) -> list[dict]:
    """
    Возвращает записи на уровне позиций для обоих типов возвратов.
    Формат записи совместим со схемой core.fact_returns (FACT_RETURNS_SCHEMA в bq_ops.py).
    """
    records: list[dict] = []

    # Формат фильтра МойСклад: момент документа + только проведённые
    date_from_str = date_from.strftime("%Y-%m-%d 00:00:00")
    date_to_str   = date_to.strftime("%Y-%m-%d 23:59:59")
    base_filter   = (
        f"moment>={date_from_str};"
        f"moment<={date_to_str};"
        f"applicable=true"          # TD-11: defensive — исключаем черновики
    )

    for entity_type in ("salesreturn", "retailsalesreturn"):
        log.info("Fetching %s list: %s → %s", entity_type, date_from_str, date_to_str)

        docs = paginate_entity(
            token,
            f"entity/{entity_type}",
            params={"filter": base_filter},
            session=session,
        )

        log.info("%s: %d documents found", entity_type, len(docs))

        for doc in docs:
            return_id   = doc["id"]
            return_date = _parse_moment_kgt(doc["moment"])
            agent_id    = parse_href(
                doc.get("agent", {}).get("meta", {}).get("href", "")
            ) or None
            # has_basis: только у salesreturn может быть ссылка на отгрузку
            has_basis = "demand" in doc  # retailsalesreturn никогда не имеет demand

            positions = paginate_entity(
                token,
                f"entity/{entity_type}/{return_id}/positions",
                session=session,
            )
            time.sleep(_POSITION_REQUEST_DELAY)  # rate limit guard

            currency_rate = doc.get("rate", {}).get("value") or 1.0  # KGS per currency unit
            for pos in positions:
                price    = pos.get("price", 0.0)      # тыйыны
                quantity = pos.get("quantity", 0.0)
                discount = pos.get("discount", 0.0)   # процент (0–100)
                # cost: тыйыны у salesreturn без основания; ABSENT у остальных → 0
                cost     = pos.get("cost", 0)          # int тыйынов или отсутствует

                assortment_href = (
                    pos.get("assortment", {})
                       .get("meta", {})
                       .get("href", "")
                )
                product_id = parse_href(assortment_href) or None

                records.append({
                    "return_id":   return_id,
                    "return_type": entity_type,
                    "return_date": return_date,
                    "agent_id":    agent_id,
                    "product_id":  product_id,
                    "quantity":    quantity,
                    # sum_kgs: цена × кол-во × (1 − скидка%) ÷ 100 (тыйыны → KGS)
                    "sum_kgs":     round(price / 100.0 * quantity * (1.0 - discount / 100.0) * currency_rate, 4),
                    # cost_kgs: себестоимость возврата; 0.0 если нет поля
                    "cost_kgs":    round(cost / 100.0, 4),
                    "has_basis":   has_basis,
                })

        log.info("%s: %d positions collected", entity_type, len(records))

    return records


# ─── helpers ──────────────────────────────────────────────────────────────────

def _parse_moment_kgt(moment_str: str) -> str:
    """
    Парсит moment МойСклада ('2026-01-15 14:30:00.000') в DATE строку по Asia/Bishkek.
    Возвращает 'YYYY-MM-DD'. МойСклад отдаёт время в UTC (ADR-088 §1) — конвертация +6ч.
    """
    return parse_moment_to_bishkek_date(moment_str)