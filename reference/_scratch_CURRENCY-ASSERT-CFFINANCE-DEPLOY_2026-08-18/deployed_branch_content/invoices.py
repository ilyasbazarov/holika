"""
invoices.py — новый модуль cf-finance, режим `mode=invoices` (T3, `INVOICES-LOADER-BUILD`).

Проектный документ: reference/invoices_loader_design_2026-08-02.md (самодостаточен, читается целиком).
Контракт программы: ADR-110. Каждое решение ниже цитирует свой источник в комментарии рядом с кодом,
а не пересказывает документ — сам документ самодостаточен и не копируется сюда прозой.

Ключевые унаследованные правила (не переоткрывать, не изобретать заново):
  - ADR-010: minor_units ÷ 100 × rate.value документа, если задан; иначе — текущий курс валюты.
  - ADR-027: currency_code = rate.currency.isoCode (буквенный ISO), не числовой .code.
  - ADR-029 §1: fallback-ветка ОБЯЗАНА падать исключением, если курс не прочитан — 1.0 запрещён.
  - ADR-034: applicable фильтруется В БАЗЕ (SQL, MERGE USING), никогда на выгрузке (if/continue).
  - ADR-088 §3/§4: сутки документа = DATE(M+6ч) — то же правило, что у продаж; вычисляется в SQL,
    не в Python (design §4.2) — срез строки в Python и есть дефект четырёх существующих веток.
  - ADR-100 §1/§2: MERGE обязан иметь ветку удаления (сироты) И обновлять T.moment при матче
    (дата, проставленная один раз, — второй дефект продаж).
  - ADR-101 §7 / C1/C2 (05_CONVENTIONS.md): явный INSERT(колонки), запрет INSERT ROW; ветка удаления
    без окна в ON (окна нет вообще — design §6.6/§7.2, сильнее требования C1/C2).
"""

import time
import datetime

from google.cloud import bigquery
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

PROJECT = "msklad-bi-prod"
MSKLAD_BASE = "https://api.moysklad.ru/api/remap/1.2"

STG_INVOICES = f"{PROJECT}.stg_msklad.fact_customer_invoices_staging"
CORE_INVOICES = f"{PROJECT}.core.fact_customer_invoices"

# design §3.1 — limit=100 обязателен, потому что запрошены четыре expand-компонента
# (02_ERP_CONTRACTS.md строка 297: expand + limit>100 → API молча роняет expand → NULL).
LIMIT = 100
TIMEOUT = 90
SLEEP_S = 0.25
EXPAND = "state,agent,salesChannel,rate.currency"

_CURRENCY_RATE_CACHE = {}


# ─── HTTP / пагинация (design §3.2 — явный offset, НЕ meta.nextHref) ──────────

class _RetryableError(Exception):
    pass


@retry(
    retry=retry_if_exception_type(_RetryableError),
    stop=stop_after_attempt(5),
    wait=wait_exponential(multiplier=1, min=1, max=60),
    reraise=True,
)
def _api_get(session, url, headers, params):
    """design §3.4: 429/5xx ретраятся (tenacity, экспоненциально, до 5 попыток);
    401 и прочие 4xx НЕ ретраятся — падают наверх немедленно."""
    resp = session.get(url, headers=headers, params=params, timeout=TIMEOUT)
    if resp.status_code == 429:
        raise _RetryableError("429 Too Many Requests")
    if resp.status_code >= 500:
        raise _RetryableError(f"{resp.status_code} Server Error")
    if resp.status_code == 401:
        resp.raise_for_status()  # не ретраится — токен истёк, падаем наверх
    resp.raise_for_status()
    return resp.json()


def parse_href(meta_obj):
    """Образец — cf-finance/main.py:12-14 (существующая функция, копируется как есть)."""
    href = (meta_obj or {}).get("meta", {}).get("href")
    return href.split("/")[-1].split("?")[0] if href else None


def fetch_all_invoices(token, session):
    """
    design §3.2: явный offset/limit, НЕ meta.nextHref (nextHref — строка, сформированная
    сервером, сохранность в ней expand ничем не подтверждена; при явном offset параметры
    собираются нами на каждой странице).

    Возвращает (collected: list[dict], meta_size_first: int|None).
    """
    headers = {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}
    url = f"{MSKLAD_BASE}/entity/invoiceout"
    collected = []
    meta_size_first = None
    offset = 0

    while True:
        params = {"limit": LIMIT, "offset": offset, "expand": EXPAND}
        page = _api_get(session, url, headers, params)
        rows = page.get("rows", [])
        if offset == 0:
            meta_size_first = page.get("meta", {}).get("size")
        collected.extend(rows)
        if len(rows) < LIMIT:
            break
        offset += LIMIT
        time.sleep(SLEEP_S)

    return collected, meta_size_first


def check_completeness(collected, meta_size_first):
    """
    design §3.3 — G1 (полнота) / G2 (непустота), ДО записи в staging.
    `>=`, не `==`: документы, созданные в источнике во время обхода, легитимно
    увеличивают набор; уменьшить его может только оборванный обход.
    Печатает оба числа (ADR-044) независимо от исхода.
    """
    n = len(collected)
    print(f"INVOICES: G1 fetched={n} meta_size_first={meta_size_first}")
    if n == 0:
        raise RuntimeError("G2 FAILED: fetched=0 documents from entity/invoiceout")
    if meta_size_first is not None and n < meta_size_first:
        raise RuntimeError(
            f"G1 FAILED: fetched={n} < meta_size_first={meta_size_first} — обход оборван"
        )


# ─── Конвертация валюты (design §8 — образец cf-loss-commission/main.py:55-94) ─

def _fetch_current_rate(session, token, iso_code):
    """
    Образец — reference/code/cf-loss-commission/main.py:55-76, перенесено дословно
    (переменные адаптированы под session/token, не глобальный TOKEN модуля).

    ВАЖНО (предупреждение автора образца, переносится вместе с кодом): точная форма поля
    'rate' в ответе entity/currency не была проверена на живых данных на момент этой правки.
    Код обрабатывает и объектную {"value": ...}, и скалярную форму, но при первом реальном
    срабатывании этой ветки — проверь лог ниже глазами, не доверяй молча.
    """
    if iso_code in _CURRENCY_RATE_CACHE:
        return _CURRENCY_RATE_CACHE[iso_code]
    headers = {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}
    data = _api_get(session, f"{MSKLAD_BASE}/entity/currency", headers, {})
    for c in data.get("rows", []):
        if c.get("isoCode") == iso_code:
            rate_field = c.get("rate")
            value = rate_field.get("value") if isinstance(rate_field, dict) else rate_field
            if value is None:
                # ADR-029 §1: НЕ подставлять 1.0 — падать исключением.
                raise RuntimeError(
                    f"entity/currency: не удалось прочитать курс для {iso_code}, "
                    f"сырое поле rate={rate_field!r} — проверь вручную, не догадка"
                )
            _CURRENCY_RATE_CACHE[iso_code] = float(value)
            print(f"INFO: текущий курс {iso_code} = {value} (из entity/currency)")
            return _CURRENCY_RATE_CACHE[iso_code]
    raise RuntimeError(f"entity/currency: валюта {iso_code} не найдена в справочнике")


def rate_and_currency(session, token, doc):
    """
    design §8.2 — три ветви, ни одной неявной:
      1. rate.value задан            → float(rate.value)
      2. rate.value пуст, currency=KGS → 1.0
      3. rate.value пуст, currency!=KGS → текущий курс из entity/currency, WARNING в лог

    Третья ветвь при невозможности прочитать курс падает исключением (см. _fetch_current_rate),
    не подставляет 1.0 (ADR-029 §1).

    Возвращает (rate_value: float, currency_code: str, used_fallback: bool).
    ADR-027: currency_code = rate.currency.isoCode (буквенный), НЕ .code (числовой).
    """
    rate = doc.get("rate") or {}
    rate_value = rate.get("value")
    currency = rate.get("currency") or {}
    currency_code = currency.get("isoCode") or "KGS"

    if rate_value is not None:
        return float(rate_value), currency_code, False

    if currency_code == "KGS":
        return 1.0, currency_code, False

    rate_value = _fetch_current_rate(session, token, currency_code)
    print(
        f"WARNING: doc {doc.get('id')} currency={currency_code} без rate.value — "
        f"применён текущий курс {rate_value} (ADR-029, fallback)."
    )
    return float(rate_value), currency_code, True


# ─── Схема staging — 19 колонок (design §6.2) ─────────────────────────────────

STAGING_SCHEMA = [
    bigquery.SchemaField("invoice_id", "STRING"),
    bigquery.SchemaField("invoice_name", "STRING"),
    bigquery.SchemaField("moment_raw", "STRING"),
    bigquery.SchemaField("payment_planned_raw", "STRING"),
    bigquery.SchemaField("agent_id", "STRING"),
    bigquery.SchemaField("agent_name", "STRING"),
    bigquery.SchemaField("state_id", "STRING"),
    bigquery.SchemaField("state_name", "STRING"),
    bigquery.SchemaField("sales_channel_id", "STRING"),
    bigquery.SchemaField("sales_channel_name", "STRING"),
    bigquery.SchemaField("applicable", "BOOLEAN"),
    bigquery.SchemaField("currency_code", "STRING"),
    bigquery.SchemaField("rate_value", "FLOAT64"),
    bigquery.SchemaField("sum_minor", "FLOAT64"),
    bigquery.SchemaField("payed_sum_minor", "FLOAT64"),
    bigquery.SchemaField("sum_kgs", "FLOAT64"),
    bigquery.SchemaField("payed_sum_kgs", "FLOAT64"),
    bigquery.SchemaField("unpaid_sum_kgs", "FLOAT64"),
    bigquery.SchemaField("_loaded_at", "TIMESTAMP"),
]

assert len(STAGING_SCHEMA) == 19, "design §6.2: staging обязана нести ровно 19 колонок"


def build_staging_row(session, token, doc, loaded_at_iso):
    """
    design §6.2, колонка-в-колонку. Возвращает (row: dict, used_fallback: bool).

    `applicable` НЕ дефолтится в Python (в отличие от cf-loss-commission `d.get(..., True)`):
    сырое значение едет как есть, NULL-семантика ("проведён по умолчанию") разрешается
    в SQL (`WHERE applicable IS NOT FALSE`, design §6.5) — фильтрация в базе, не на выгрузке
    (ADR-034).
    """
    rate_value, currency_code, used_fallback = rate_and_currency(session, token, doc)

    agent = doc.get("agent") or {}
    state = doc.get("state") or {}
    sales_channel = doc.get("salesChannel") or {}

    sum_minor = doc.get("sum")
    payed_sum_minor = doc.get("payedSum")

    sum_kgs = round((sum_minor or 0) / 100.0 * rate_value, 2)
    payed_sum_kgs = round((payed_sum_minor or 0) / 100.0 * rate_value, 2)
    unpaid_sum_kgs = round(sum_kgs - payed_sum_kgs, 2)

    row = {
        "invoice_id": doc.get("id"),
        "invoice_name": str(doc.get("name")) if doc.get("name") is not None else None,
        "moment_raw": doc.get("moment"),
        "payment_planned_raw": doc.get("paymentPlannedMoment"),
        "agent_id": parse_href(agent),
        "agent_name": agent.get("name"),
        "state_id": parse_href(state),
        "state_name": state.get("name"),
        "sales_channel_id": parse_href(sales_channel) if sales_channel else None,
        "sales_channel_name": sales_channel.get("name") if sales_channel else None,
        "applicable": doc.get("applicable"),
        "currency_code": currency_code,
        "rate_value": rate_value,
        "sum_minor": sum_minor,
        "payed_sum_minor": payed_sum_minor,
        "sum_kgs": sum_kgs,
        "payed_sum_kgs": payed_sum_kgs,
        "unpaid_sum_kgs": unpaid_sum_kgs,
        "_loaded_at": loaded_at_iso,
    }
    return row, used_fallback


def load_staging(bq, rows, table_id=STG_INVOICES):
    """
    design §6.3 — WRITE_TRUNCATE, схема явная всегда (не выводится из данных: датасет
    stg_msklad живёт 14 суток, автовывод типов на пересозданной таблице дал бы INTEGER
    вместо FLOAT64 на удачном наборе данных).
    """
    job_config = bigquery.LoadJobConfig(
        schema=STAGING_SCHEMA,
        write_disposition="WRITE_TRUNCATE",
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
    )
    job = bq.load_table_from_json(rows, table_id, job_config=job_config)
    job.result()
    return len(rows)


# ─── Текст MERGE — design §7.5, перенесён дословно ────────────────────────────
# Параметризован ТОЛЬКО по имени staging/core таблицы (для тестов на нежилой копии, см.
# reference/_scratch_INVOICES-LOADER-BUILD_2026-08-02/); структура и комментарии — как в
# документе, побайтовое соответствие проверяется скриптом selfcheck_merge.py.

def build_merge_sql(core_table=CORE_INVOICES, staging_table=STG_INVOICES):
    return f"""
MERGE `{core_table}` T
USING (
  SELECT
    invoice_id,
    invoice_name,
    -- ADR-088 §3 / ADR-101 §6: бишкекские сутки как функция UTC-времени документа, DATE(M+6ч).
    -- НЕ moment_raw[:10] — это дефект четырёх существующих веток ингеста.
    DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', moment_raw), 'Asia/Bishkek')  AS moment,
    agent_id,
    agent_name,
    state_id,
    state_name,
    sum_kgs,
    payed_sum_kgs,
    unpaid_sum_kgs,
    -- то же правило суток; NULL допустим (поле есть не у всех документов)
    CASE
      WHEN payment_planned_raw IS NULL THEN NULL
      ELSE DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', payment_planned_raw), 'Asia/Bishkek')
    END                                                                        AS payment_planned,
    sales_channel_id,
    sales_channel_name,
    _loaded_at
  FROM `{staging_table}`
  -- ADR-034: черновики фильтруются в базе, не на выгрузке; NULL читается как «проведён»
  WHERE applicable IS NOT FALSE
) S
ON T.invoice_id = S.invoice_id

WHEN MATCHED THEN UPDATE SET
  T.invoice_name       = S.invoice_name,
  -- ADR-100 §2: дата документа ОБЯЗАНА обновляться при матче.
  -- Её отсутствие в UPDATE SET и есть второй дефект MERGE продаж.
  T.moment             = S.moment,
  T.agent_id           = S.agent_id,
  T.agent_name         = S.agent_name,
  T.state_id           = S.state_id,
  T.state_name         = S.state_name,
  T.sum_kgs            = S.sum_kgs,
  T.payed_sum_kgs      = S.payed_sum_kgs,
  T.unpaid_sum_kgs     = S.unpaid_sum_kgs,
  T.payment_planned    = S.payment_planned,
  T.sales_channel_id   = S.sales_channel_id,
  T.sales_channel_name = S.sales_channel_name,
  T._loaded_at         = S._loaded_at

-- C1 / ADR-030: только явный INSERT (колонки) VALUES (...).
-- WHEN NOT MATCHED THEN INSERT ROW ЗАПРЕЩЁН (позиционное сопоставление колонок).
WHEN NOT MATCHED BY TARGET THEN INSERT (
  invoice_id,
  invoice_name,
  moment,
  agent_id,
  agent_name,
  state_id,
  state_name,
  sum_kgs,
  payed_sum_kgs,
  unpaid_sum_kgs,
  payment_planned,
  sales_channel_id,
  sales_channel_name,
  _loaded_at
) VALUES (
  S.invoice_id,
  S.invoice_name,
  S.moment,
  S.agent_id,
  S.agent_name,
  S.state_id,
  S.state_name,
  S.sum_kgs,
  S.payed_sum_kgs,
  S.unpaid_sum_kgs,
  S.payment_planned,
  S.sales_channel_id,
  S.sales_channel_name,
  S._loaded_at
)

-- C2 / ADR-101 §7 + ADR-100 §1: ветка удаления присутствует.
-- Предикат корректен, потому что staging несёт ПОЛНЫЙ набор документов источника (§6.6),
-- а окна нет ни в выборке, ни в ON (§7.2). Инвариант держат проверки G1/G2 (§3.3).
WHEN NOT MATCHED BY SOURCE THEN DELETE
"""


def merge_predicted_stats(bq, core_table=CORE_INVOICES, staging_table=STG_INVOICES):
    """
    Числа веток MERGE, посчитанные ДО его исполнения тем же предикатом, что использует
    сам MERGE (applicable IS NOT FALSE, ON invoice_id). BigQuery не отдаёт разбивку
    inserted/updated/deleted для одного MERGE — числа получаем сравнением множеств
    staging/core; после исполнения MERGE эти множества и есть его результат (staging
    не меняется между вызовом этой функции и запуском MERGE в рамках одного прогона).
    Печатает и возвращает числа (ADR-044).
    """
    sql = f"""
    WITH s AS (
      SELECT invoice_id FROM `{staging_table}` WHERE applicable IS NOT FALSE
    ), t AS (
      SELECT invoice_id FROM `{core_table}`
    )
    SELECT
      (SELECT COUNT(*) FROM s WHERE invoice_id NOT IN (SELECT invoice_id FROM t)) AS to_insert,
      (SELECT COUNT(*) FROM s WHERE invoice_id IN (SELECT invoice_id FROM t))     AS to_update,
      (SELECT COUNT(*) FROM t WHERE invoice_id NOT IN (SELECT invoice_id FROM s)) AS to_delete
    """
    row = list(bq.query(sql).result())[0]
    stats = {"merged_inserted": row.to_insert, "merged_updated": row.to_update, "merged_deleted": row.to_delete}
    print(f"INVOICES: merge_predicted {stats}")
    return stats


def run_merge(bq, core_table=CORE_INVOICES, staging_table=STG_INVOICES):
    stats = merge_predicted_stats(bq, core_table, staging_table)
    bq.query(build_merge_sql(core_table, staging_table)).result()
    return stats


# ─── Проверки свежести — design §9.2 (текст, место исполнения — DQ-GATE-SCOPE-SPLIT) ─

def freshness_technical_sql(core_table=CORE_INVOICES):
    """(A) Техническая свежесть — СТОРОЖ. Порог 48ч — design §9.2 A (выведен из формы
    ADR-007/03_PIPELINE_SPEC.md:86, не подобран)."""
    return f"""
    SELECT
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
      COUNT(DISTINCT _loaded_at)                                 AS distinct_load_stamps,
      COUNT(*)                                                   AS n_rows
    FROM `{core_table}`
    """


def freshness_business_sql(core_table=CORE_INVOICES):
    """(B) Бизнес-свежесть — диагностика, НЕ блокирующая; порог не назначается (design §9.2 B)."""
    return f"""
    SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(moment), DAY) AS business_lag_days
    FROM `{core_table}`
    """


# ─── Прогон целиком (design §7.6) ──────────────────────────────────────────────

def run_invoices_etl(token, bq, session, core_table=CORE_INVOICES, staging_table=STG_INVOICES):
    run_started_at = datetime.datetime.now(datetime.timezone.utc)
    loaded_at_iso = run_started_at.isoformat()

    collected, meta_size_first = fetch_all_invoices(token, session)
    check_completeness(collected, meta_size_first)

    rows = []
    fallback_hits = 0
    applicable_false = 0
    for doc in collected:
        row, used_fallback = build_staging_row(session, token, doc, loaded_at_iso)
        if used_fallback:
            fallback_hits += 1
        if row["applicable"] is False:
            applicable_false += 1
        rows.append(row)

    staged = load_staging(bq, rows, staging_table)

    merge_stats = run_merge(bq, core_table, staging_table)

    tech = list(bq.query(freshness_technical_sql(core_table)).result())[0]
    biz = list(bq.query(freshness_business_sql(core_table)).result())[0]

    print(
        f"INVOICES: fetched={len(collected)} meta_size={meta_size_first} "
        f"applicable_false={applicable_false}"
    )
    print(
        f"INVOICES: staged={staged} merged_inserted={merge_stats['merged_inserted']} "
        f"merged_updated={merge_stats['merged_updated']} merged_deleted={merge_stats['merged_deleted']}"
    )
    print(
        f"INVOICES: load_lag_hours={tech.load_lag_hours} business_lag_days={biz.business_lag_days} "
        f"distinct_load_stamps={tech.distinct_load_stamps}"
    )
    print(f"INVOICES: currency_fallback_hits={fallback_hits}")

    return {
        "fetched": len(collected),
        "meta_size": meta_size_first,
        "applicable_false": applicable_false,
        "staged": staged,
        **merge_stats,
        "load_lag_hours": tech.load_lag_hours,
        "business_lag_days": biz.business_lag_days,
        "distinct_load_stamps": tech.distinct_load_stamps,
        "currency_fallback_hits": fallback_hits,
    }
