"""
bq_ops.py — BigQuery operations for CF-Facts.

Covers:
  - BQ schemas for staging tables
  - ensure_staging_tables(): idempotent table creation
  - load_staging(): WRITE_TRUNCATE into stg_msklad.fact_sales_staging
  - load_byvariant_staging(): WRITE_TRUNCATE into stg_msklad.byvariant_staging
  - promote_to_core(): MERGE staging → core.fact_sales_profit

MERGE partition filter is the primary cost-control mechanism — always specify
  AND T.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL N DAY)
so BQ prunes partitions and avoids full table scan.

COGS source:
  - hourly (7d): core.fact_sales_profit_byvariant_backup (static, from bootstrap)
  - weekly (90d): stg_msklad.byvariant_staging (fresh, loaded this run)

Week standard: WEEK(SATURDAY) — Аппендикс Ж.
Datetime parse: DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', ...), 'Asia/Bishkek') — Аппендикс Е.
Partition: PARTITION BY transaction_date (DATE column — NOT DATE(col)) — Аппендикс Ж.
"""

import logging
from datetime import date, timedelta

from google.cloud import bigquery

from config import (
    BQ_CORE,
    BQ_STG,
    CORE_BYVARIANT_BCK,
    CORE_DIM_FX,
    CORE_FACT_SALES,
    CORE_FACT_PURCHASES,
    GCP_PROJECT,
    GUARD_TOLERANCE_DAYS,
    PERIMETER_CHANNEL_NAMES,
    STG_BYVARIANT,
    STG_FACT_SALES,
    STG_FACT_SALES_PERIMETER,
)

log = logging.getLogger(__name__)


# ─── Schemas ──────────────────────────────────────────────────────────────────

STAGING_SCHEMA = [
    bigquery.SchemaField("run_id",               "STRING"),
    bigquery.SchemaField("demand_id",            "STRING"),
    bigquery.SchemaField("order_name",        "STRING"),
    bigquery.SchemaField("position_id",          "STRING"),
    bigquery.SchemaField("transaction_date_raw", "STRING"),   # "YYYY-MM-DD HH:MM:SS.mmm"
    bigquery.SchemaField("product_id",           "STRING"),
    bigquery.SchemaField("agent_id",             "STRING"),
    # SALES-DOCUMENT-OWNER-INGEST (ADR-128): сотрудник-владелец ДОКУМЕНТА entity/demand.owner,
    # тот же приём разбора href, что у agent_id. В отличие от agent_id колонка ОБНОВЛЯЕТСЯ в
    # WHEN MATCHED THEN UPDATE SET (ADR-136 §2): расхождение с agent_id намеренное — без обновления
    # уже промоутнутые строки остались бы с NULL и разрез по сотруднику не изменился бы вовсе.
    bigquery.SchemaField("document_owner_employee_id", "STRING"),
    bigquery.SchemaField("quantity",             "FLOAT64"),
    bigquery.SchemaField("price_kgs",            "FLOAT64"),  # price / 100
    bigquery.SchemaField("discount",             "FLOAT64"),  # percent 0–100
    bigquery.SchemaField("revenue_kgs",          "FLOAT64"),  # price_kgs * qty * (1-disc/100)
    bigquery.SchemaField("entity_type",          "STRING"),   # product/variant/bundle
    bigquery.SchemaField("_loaded_at",           "TIMESTAMP"),
    bigquery.SchemaField("sales_channel_id",     "STRING"),
    bigquery.SchemaField("sales_channel_name",   "STRING"),
    bigquery.SchemaField("project_id",           "STRING"),
    bigquery.SchemaField("project_name",         "STRING"),
]

BYVARIANT_SCHEMA = [
    bigquery.SchemaField("product_id",       "STRING"),
    bigquery.SchemaField("_week_start",      "DATE"),
    bigquery.SchemaField("sell_quantity",    "FLOAT64"),
    bigquery.SchemaField("sell_sum_kgs",     "FLOAT64"),
    bigquery.SchemaField("cogs_kgs",         "FLOAT64"),
    bigquery.SchemaField("return_sum_kgs",   "FLOAT64"),
    bigquery.SchemaField("return_cost_kgs",  "FLOAT64"),
    bigquery.SchemaField("profit_kgs",       "FLOAT64"),
    bigquery.SchemaField("_loaded_at",       "TIMESTAMP"),
]

# SALES-PERIMETER-EXTEND (ADR-103 §8 вариант (a)): отдельная staging-схема, отдельная
# таблица — не переиспользует STAGING_SCHEMA/STG_FACT_SALES (`ADR-024` прецедент разреза).
# `doc_id`/`source_doc_type` — только для аудита и построения transaction_id; в
# `core.fact_sales_profit` они не попадают, целевая схема (`02_ERP_CONTRACTS.md:36-49`)
# этим патчем не меняется.
PERIMETER_STAGING_SCHEMA = [
    bigquery.SchemaField("run_id",               "STRING"),
    bigquery.SchemaField("doc_id",               "STRING"),
    bigquery.SchemaField("source_doc_type",      "STRING"),   # retaildemand | commissionreportin_sale
    bigquery.SchemaField("position_id",          "STRING"),
    bigquery.SchemaField("transaction_date_raw", "STRING"),
    bigquery.SchemaField("product_id",           "STRING"),
    bigquery.SchemaField("agent_id",             "STRING"),
    bigquery.SchemaField("quantity",             "FLOAT64"),
    bigquery.SchemaField("price_kgs",            "FLOAT64"),
    bigquery.SchemaField("discount",             "FLOAT64"),
    bigquery.SchemaField("revenue_kgs",          "FLOAT64"),
    bigquery.SchemaField("entity_type",          "STRING"),
    # SALES-PERIMETER-CHANNEL-DECIDE: константная метка типа документа
    # (`sales_channel_id` NULL — синтетической строки-справочника нет; `sales_channel_name`
    # несёт метку), см. докстринг `fetch_perimeter.py`.
    bigquery.SchemaField("sales_channel_id",     "STRING"),
    bigquery.SchemaField("sales_channel_name",   "STRING"),
    bigquery.SchemaField("_loaded_at",           "TIMESTAMP"),
]

# ─── Ensure staging tables exist ──────────────────────────────────────────────

def ensure_staging_tables(bq: bigquery.Client) -> None:
    """Create staging tables if they don't exist. Idempotent."""
    _ensure_table(bq, STG_FACT_SALES, STAGING_SCHEMA,  time_partitioning=None)
    _ensure_table(bq, STG_BYVARIANT,  BYVARIANT_SCHEMA, time_partitioning=None)


def ensure_perimeter_staging_table(bq: bigquery.Client) -> None:
    """Create stg_msklad.fact_sales_perimeter_staging if it doesn't exist. Idempotent."""
    _ensure_table(bq, STG_FACT_SALES_PERIMETER, PERIMETER_STAGING_SCHEMA, time_partitioning=None)


def _ensure_table(
    bq: bigquery.Client,
    full_table_id: str,
    schema: list,
    time_partitioning,
) -> None:
    tbl = bigquery.Table(full_table_id, schema=schema)
    if time_partitioning:
        tbl.time_partitioning = time_partitioning
    tbl = bq.create_table(tbl, exists_ok=True)
    log.debug("Staging table ready: %s", full_table_id)


# ─── Load to staging ──────────────────────────────────────────────────────────

def load_staging(
    bq: bigquery.Client,
    records: list[dict],
) -> int:
    """
    WRITE_TRUNCATE load into stg_msklad.fact_sales_staging.
    Returns number of rows loaded.
    """
    if not records:
        raise ValueError("load_staging called with 0 records — abort")

    job_config = bigquery.LoadJobConfig(
        schema=STAGING_SCHEMA,
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        ignore_unknown_values=False,
        max_bad_records=0,
    )

    job = bq.load_table_from_json(records, STG_FACT_SALES, job_config=job_config)
    job.result()  # wait

    rows = bq.get_table(STG_FACT_SALES).num_rows
    log.info("Loaded %d rows → %s", rows, STG_FACT_SALES)
    return rows


def load_perimeter_staging(
    bq: bigquery.Client,
    records: list[dict],
) -> int:
    """
    WRITE_TRUNCATE load into stg_msklad.fact_sales_perimeter_staging
    (SALES-PERIMETER-EXTEND, retaildemand + commissionreportin_sale).
    """
    if not records:
        raise ValueError("load_perimeter_staging called with 0 records — abort")

    job_config = bigquery.LoadJobConfig(
        schema=PERIMETER_STAGING_SCHEMA,
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        ignore_unknown_values=False,
        max_bad_records=0,
    )

    job = bq.load_table_from_json(records, STG_FACT_SALES_PERIMETER, job_config=job_config)
    job.result()

    rows = bq.get_table(STG_FACT_SALES_PERIMETER).num_rows
    log.info("Loaded %d rows → %s", rows, STG_FACT_SALES_PERIMETER)
    return rows


def load_byvariant_staging(
    bq: bigquery.Client,
    records: list[dict],
) -> int:
    """
    WRITE_TRUNCATE load into stg_msklad.byvariant_staging (weekly mode only).
    """
    if not records:
        log.warning("load_byvariant_staging: 0 records — skipping")
        return 0

    job_config = bigquery.LoadJobConfig(
        schema=BYVARIANT_SCHEMA,
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        ignore_unknown_values=False,
        max_bad_records=0,
    )

    job = bq.load_table_from_json(records, STG_BYVARIANT, job_config=job_config)
    job.result()

    rows = bq.get_table(STG_BYVARIANT).num_rows
    log.info("Loaded %d rows → %s", rows, STG_BYVARIANT)
    return rows


# ─── MERGE SQLs ───────────────────────────────────────────────────────────────

# Shared parse expression for transaction_date — Аппендикс Е pattern (maintain consistency)
# Список меток периметра в виде SQL-кортежа. Строится ОДИН раз из config.PERIMETER_CHANNEL_NAMES,
# чтобы предикаты обеих веток удаления и метки, которые пишет fetch_perimeter.py, не могли
# разойтись (ROLLBACK-ADJ §6). Апостроф внутри метки экранируется — метки задаёт наш код, но
# подстановка в SQL обязана быть безопасной независимо от их содержимого.
_PERIMETER_NAMES_SQL = "(" + ", ".join("'" + n.replace("'", "''") + "'" for n in PERIMETER_CHANNEL_NAMES) + ")"

_PARSE_DATE = "DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek')"

# COGS proportional allocation formula (shared across both MERGE variants)
# Allocates COGS proportional to revenue share within the weekly bucket
_COGS_EXPR = (
    "ROUND(b.cogs_kgs * SAFE_DIVIDE(s.revenue_kgs, NULLIF(b.sell_sum_kgs, 0)), 4)"
)
_MARGIN_EXPR = (
    "ROUND(s.revenue_kgs - b.cogs_kgs * SAFE_DIVIDE(s.revenue_kgs, NULLIF(b.sell_sum_kgs, 0)), 4)"
)
_COGS_USD_EXPR = (
    "ROUND(SAFE_DIVIDE(b.cogs_kgs * SAFE_DIVIDE(s.revenue_kgs, NULLIF(b.sell_sum_kgs, 0)), fx.rate_kgs_per_usd), 4)"
)
_MARGIN_USD_EXPR = (
    "ROUND(SAFE_DIVIDE(s.revenue_kgs - b.cogs_kgs * SAFE_DIVIDE(s.revenue_kgs, NULLIF(b.sell_sum_kgs, 0)), fx.rate_kgs_per_usd), 4)"
)


def _build_merge_sql(cogs_source_table: str, window_days: int) -> str:
    """
    Build idempotent MERGE SQL for fact_sales_profit.

    cogs_source_table: either CORE_BYVARIANT_BCK (hourly) or STG_BYVARIANT (weekly)
    window_days: partition filter — 7 for hourly, 90 for weekly

    Partition filter in ON clause prunes BQ partitions on the target table,
    avoiding a full table scan. Required for cost control.
    """
    return f"""
MERGE `{CORE_FACT_SALES}` T
USING (
  SELECT
    TO_HEX(MD5(CONCAT(s.demand_id, '|', s.position_id)))            AS transaction_id,
    {_PARSE_DATE}                                                   AS transaction_date,
    s.product_id,
    s.entity_type,
    s.discount,
    s.agent_id,
    s.document_owner_employee_id,
    s.quantity                                                      AS sell_quantity,
    CAST(0.0 AS FLOAT64)                                            AS return_quantity,
    s.revenue_kgs                                                   AS sell_sum_kgs,
    CAST(0.0 AS FLOAT64)                                            AS return_sum_kgs,
    s.revenue_kgs                                                   AS revenue_kgs,
    CASE
      WHEN b.cogs_kgs IS NOT NULL AND b.sell_sum_kgs > 0
        THEN {_COGS_EXPR}
      ELSE NULL
    END                                                             AS cogs_kgs,
    CASE
      WHEN b.cogs_kgs IS NOT NULL AND b.sell_sum_kgs > 0
        THEN {_MARGIN_EXPR}
      ELSE NULL
    END                                                             AS margin_kgs,
    ROUND(SAFE_DIVIDE(s.revenue_kgs, fx.rate_kgs_per_usd), 4)       AS revenue_usd,
    CASE
      WHEN b.cogs_kgs IS NOT NULL AND b.sell_sum_kgs > 0 AND fx.rate_kgs_per_usd IS NOT NULL
        THEN {_COGS_USD_EXPR}
      ELSE NULL
    END                                                             AS cogs_usd,
    CASE
      WHEN b.cogs_kgs IS NOT NULL AND b.sell_sum_kgs > 0 AND fx.rate_kgs_per_usd IS NOT NULL
        THEN {_MARGIN_USD_EXPR}
      ELSE NULL
    END                                                             AS margin_usd,
    s.sales_channel_id,
    s.sales_channel_name,
    s.project_id,
    s.project_name,
    CURRENT_TIMESTAMP()                                             AS _loaded_at
  FROM `{STG_FACT_SALES}` s
  LEFT JOIN `{cogs_source_table}` b
    ON  s.product_id = b.product_id
    AND DATE_TRUNC(
          {_PARSE_DATE},
          WEEK(SATURDAY)
        ) = b._week_start
  LEFT JOIN `{CORE_DIM_FX}` fx
    ON  {_PARSE_DATE} = fx.date
) S
ON  T.transaction_id   = S.transaction_id
AND T.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL {window_days} DAY)

WHEN MATCHED THEN UPDATE SET
  T.sell_quantity   = S.sell_quantity,
  T.return_quantity = S.return_quantity,
  T.sell_sum_kgs    = S.sell_sum_kgs,
  T.return_sum_kgs  = S.return_sum_kgs,
  T.revenue_kgs     = S.revenue_kgs,
  T.cogs_kgs        = S.cogs_kgs,
  T.margin_kgs      = S.margin_kgs,
  T.revenue_usd     = S.revenue_usd,
  T.cogs_usd        = S.cogs_usd,
  T.margin_usd      = S.margin_usd,
  T.sales_channel_id   = S.sales_channel_id,
  T.sales_channel_name = S.sales_channel_name,
  T.project_id         = S.project_id,
  T.project_name       = S.project_name,
  T.discount        = S.discount,
  T._loaded_at      = S._loaded_at,
  T.document_owner_employee_id = S.document_owner_employee_id

WHEN NOT MATCHED THEN INSERT (
  transaction_id,
  transaction_date,
  product_id,
  entity_type,
  agent_id,
  document_owner_employee_id,
  sell_quantity,
  return_quantity,
  sell_sum_kgs,
  return_sum_kgs,
  revenue_kgs,
  cogs_kgs,
  margin_kgs,
  revenue_usd,
  cogs_usd,
  margin_usd,
  sales_channel_id,
  sales_channel_name,
  project_id,
  project_name,
  discount,
  _loaded_at
) VALUES (
  S.transaction_id,
  S.transaction_date,
  S.product_id,
  S.entity_type,
  S.agent_id,
  S.document_owner_employee_id,
  S.sell_quantity,
  S.return_quantity,
  S.sell_sum_kgs,
  S.return_sum_kgs,
  S.revenue_kgs,
  S.cogs_kgs,
  S.margin_kgs,
  S.revenue_usd,
  S.cogs_usd,
  S.margin_usd,
  S.sales_channel_id,
  S.sales_channel_name,
  S.project_id,
  S.project_name,
  S.discount,
  S._loaded_at
)

-- SALES-REFRESH-WINDOW (ADR-144 §8, узкая форма): строки, исчезнувшие из источника внутри
-- окна выборки, удаляются. Условие DELETE обязано ПОВТОРЯТЬ границу окна ON явно (C2,
-- ADR-101 §7 ловушка ii) — без этого повтора `WHEN NOT MATCHED BY SOURCE` по умолчанию
-- матчит и удаляет ВСЮ историю за пределами окна (там ON тоже не находит пару), а не только
-- сироты внутри окна. window_days тот же параметр, что несёт ON — единственный параметр в
-- узкой форме, режим `topoff` с раздельными окнами выборки/MERGE этим патчем не строится.
WHEN NOT MATCHED BY SOURCE
  AND T.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL {window_days} DAY)
  -- ROLLBACK-ADJ §6 вариант 1: удалять ТОЛЬКО свои строки. Источник этого MERGE —
  -- staging обычных продаж (entity/demand без комиссионных агентов); строки периметра
  -- (розница и отчёты комиссионера) в него не входят и без этого условия удалялись бы
  -- как «исчезнувшие из источника». Различитель — ПАРА полей: у периметра
  -- sales_channel_id всегда NULL (fetch_perimeter.py), у настоящих каналов МойСклада id
  -- заполнен; COALESCE обязателен, иначе строка с именем канала NULL даёт NULL вместо
  -- FALSE и не удаляется никогда.
  AND NOT (T.sales_channel_id IS NULL
           AND COALESCE(T.sales_channel_name, '') IN {_PERIMETER_NAMES_SQL})
THEN DELETE
"""


# ─── Предохранитель ADR-145 §4/§5 (SALES-REFRESH-WINDOW) ──────────────────────

def _assert_staging_covers_merge_window(
    bq: bigquery.Client,
    staging_table: str,
    window_days: int,
    label: str,
) -> None:
    """
    Предусловие мандата на деплой ветки удаления (`ADR-145 §4/§5`): до исполнения
    `MERGE` подтвердить, что фактическое покрытие staging по датам не УЖЕ окна,
    которое получит ветка `WHEN NOT MATCHED BY SOURCE ... THEN DELETE`. Свойства
    защиты по `ADR-145 §4`: сравнить покрытие staging с окном `MERGE`, ОТКАЗАТЬ при
    недостаточном покрытии (не предупредить логом), сработать ДО исполнения `MERGE`.
    Форма и три правки — адъюдикация `reference/sales_refresh_window_mandate_adj_2026-08-11.md §3`.

    Метод: MIN/MAX(transaction_date) в staging (тот же `_PARSE_DATE`, что несёт сам
    `MERGE`) и обе границы окна `MERGE` (`CURRENT_DATE() - window_days` — нижняя,
    `CURRENT_DATE() - 1` — верхняя, ADR-145-ADJ §3 правка 3) считаются ОДНИМ запросом
    BigQuery (правка 2 — обе даты обязаны идти из одних часов: раньше нижняя граница
    считалась питоновским `date.today()`, а MERGE — `CURRENT_DATE()`; сегодня оба дают
    UTC и совпадают, но это незаписанное свойство среды, не гарантия).

    Проверяются ОБА конца окна:
    - нижний (глубина) — если MIN(date) в staging моложе начала окна минус допуск
      (`GUARD_TOLERANCE_DAYS`, правка 1), staging не дотягивается до всей глубины,
      которую получит DELETE, и строки внутри окна, отсутствующие в staging не потому
      что удалены в источнике, а потому что не были выбраны этим прогоном, будут
      стёрты как «исчезнувшие». Сценарий `ADR-145 §4`: часовой staging (7 суток) при
      `mode=promote, window_days=90` — MIN(date) окажется около «сегодня-7д», отказ.
    - верхний (свежесть) — найдено адъюдикацией `MANDATE-ADJ` §1 (первая версия),
      в исходном запросе отсутствовало: если MAX(date) в staging старше «сегодня-1д»,
      часть окна около сегодняшнего дня в staging попросту не загружена (устаревший
      прогон), и та же ветка DELETE снесла бы строки внутри окна, отсутствующие в
      устаревшем staging, хотя они никуда не делись в источнике. Симметричная
      опасность нижнему краю.

    Допуск `GUARD_TOLERANCE_DAYS` (`config.py`) применяется к ОБОИМ концам окна
    (адъюдикация `MANDATE-ADJ` §2, вторая правка верхнего края, 2026-08-11) —
    измерено (`§C`, окно 180 суток): 6,63% суток без единой продажи, ни одного окна
    из трёх подряд пустых суток. Первая версия правки не несла допуска на верхнем
    крае в предположении, что отставание там — признак пропущенного прогона, а не
    свойство данных; это предположение опровергнуто архитектором: MAX(date) —
    свойство данных (последний день с продажей), не признак того, что прогон
    отработал, и без допуска один пустой день останавливал бы `promote` (в т.ч.
    часовой, вызываемый ежечасно) примерно на 24 прогона подряд до первой продажи
    нового дня. Асимметрия направления ошибки при выборе допуска: недолёт ГЛУБИНЫ
    невосстановим (строки удаляются и не возвращаются следующим прогоном), недолёт
    СВЕЖЕСТИ самоизлечим (следующий успешный прогон подтянет пропущенные даты) —
    поэтому ложный отказ дороже наверху, допуск обоснован сильнее, чем внизу, а не
    слабее.
    """
    row = next(
        bq.query(
            f"""
            SELECT
              MIN({_PARSE_DATE}) AS min_date,
              MAX({_PARSE_DATE}) AS max_date,
              DATE_SUB(CURRENT_DATE(), INTERVAL {window_days} DAY) AS window_start,
              DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)             AS freshness_floor
            FROM `{staging_table}` s
            """
        ).result()
    )
    tolerant_window_start = row.window_start + timedelta(days=GUARD_TOLERANCE_DAYS)
    if row.min_date is None or row.min_date > tolerant_window_start:
        raise ValueError(
            f"{label}: предохранитель ADR-145 §4 (глубина) — staging покрывает с "
            f"{row.min_date}, а окно MERGE начинается {row.window_start} "
            f"(window_days={window_days}, допуск {GUARD_TOLERANCE_DAYS}д → "
            f"{tolerant_window_start}). Покрытие staging уже окна MERGE — ветка "
            f"DELETE удалила бы строки внутри окна, отсутствующие в staging не "
            f"потому что исчезли в источнике. Отказ, MERGE не исполняется."
        )
    tolerant_freshness_floor = row.freshness_floor - timedelta(days=GUARD_TOLERANCE_DAYS)
    if row.max_date is None or row.max_date < tolerant_freshness_floor:
        raise ValueError(
            f"{label}: предохранитель ADR-145 §4 (свежесть) — staging доходит "
            f"только до {row.max_date}, а окно MERGE ожидает свежесть не старше "
            f"{row.freshness_floor} (допуск {GUARD_TOLERANCE_DAYS}д → "
            f"{tolerant_freshness_floor}). Верхний край окна в staging не покрыт — "
            f"ветка DELETE удалила бы строки внутри окна около сегодняшнего дня, "
            f"отсутствующие в устаревшем staging не потому что исчезли в источнике. "
            f"Отказ, MERGE не исполняется."
        )
    log.info(
        "%s: предохранитель ADR-145 §4 пройден — staging покрывает %s…%s, "
        "окно MERGE %s…%s (допуск %sд на обоих концах)",
        label, row.min_date, row.max_date, row.window_start, row.freshness_floor,
        GUARD_TOLERANCE_DAYS,
    )


# ─── Promote staging → core ───────────────────────────────────────────────────

def promote_to_core(
    bq: bigquery.Client,
    window_days: int,
) -> dict:
    """
    Execute MERGE from staging into core.fact_sales_profit.

    window_days=7  → hourly mode: uses byvariant backup for COGS
    window_days=90 → weekly mode: uses fresh byvariant_staging for COGS

    Returns stats dict for logging / Cloud Monitoring.
    """
    # ── Pre-promote: verify staging is non-empty
    count_row = next(
        bq.query(f"SELECT COUNT(*) AS cnt FROM `{STG_FACT_SALES}`").result()
    )
    staging_count = count_row.cnt
    if staging_count == 0:
        raise ValueError("promote_to_core: staging table is empty — refuse to MERGE")

    # ── Pre-promote: предохранитель ADR-145 §4/§5 — покрытие staging обязано
    # достигать начала окна MERGE, иначе ветка DELETE сотрёт непокрытую историю
    _assert_staging_covers_merge_window(bq, STG_FACT_SALES, window_days, "promote_to_core")

    log.info("Staging rows: %d | window_days: %d", staging_count, window_days)

    # ── Choose COGS source
    if window_days >= 90:
        # Weekly: use freshly loaded byvariant_staging
        cogs_source = STG_BYVARIANT
        # Verify byvariant_staging is also loaded
        bv_count = next(
            bq.query(f"SELECT COUNT(*) AS cnt FROM `{STG_BYVARIANT}`").result()
        ).cnt
        if bv_count == 0:
            log.warning(
                "byvariant_staging is empty — COGS will be NULL for weekly MERGE. "
                "Consider re-running weekly load."
            )
            cogs_source = CORE_BYVARIANT_BCK  # graceful degradation to backup
    else:
        # Hourly: use static backup from bootstrap
        cogs_source = CORE_BYVARIANT_BCK

    log.info("COGS source: %s", cogs_source)

    # ── Execute MERGE
    merge_sql = _build_merge_sql(cogs_source, window_days)
    log.debug("Executing MERGE SQL:\n%s", merge_sql)

    job = bq.query(merge_sql)
    job.result()  # wait for completion

    stats = {
        "staging_rows":   staging_count,
        "window_days":    window_days,
        "cogs_source":    cogs_source,
        "affected_rows":  job.num_dml_affected_rows,
    }
    log.info("MERGE complete: %s", stats)
    return stats


# ─── SALES-PERIMETER-EXTEND: MERGE периметра → core.fact_sales_profit ─────────

# Тот же паттерн даты, что у основного MERGE (`_PARSE_DATE` выше) — ADR-088 §3, дата как
# функция UTC-момента документа, не переопределяется здесь ради единообразия при чтении.
_PERIMETER_PARSE_DATE = "DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek')"


def _build_perimeter_merge_sql(window_days: int) -> str:
    """
    MERGE периметра (retaildemand + commissionreportin_sale) → core.fact_sales_profit.

    ОТДЕЛЬНЫЙ от `_build_merge_sql` (прецедент ADR-024): своя staging-таблица
    (`STG_FACT_SALES_PERIMETER`), свой ON.

    C1 (ADR-030): явный `INSERT (колонки)`, `INSERT ROW` не используется.

    C2 (ADR-101 §7, SALES-REFRESH-WINDOW/ADR-144 §7/§8): ветка удаления ЕСТЬ —
    узкая форма фикса `SALES-REFRESH-WINDOW` называет ОБА `MERGE` cf-facts поимённо
    (`ADR-144 §7`), симметричный фикс для периметра больше не отложен на будущую
    отдельную задачу. Условие `WHEN NOT MATCHED BY SOURCE` несёт собственное явное
    ограничение по дате, повторяющее границу `ON` (`ADR-101 §7` ловушка ii) — без
    повтора удалило бы всю историю за пределами окна, не только сирот внутри него.

    SALES-PERIMETER-CHANNEL-DECIDE: `sales_channel_id`/`sales_channel_name` читаются
    из staging (константа типа документа, проставленная `fetch_perimeter.py`), не
    `CAST(NULL AS STRING)`; `WHEN MATCHED` тоже их обновляет — уже промоутнутые строки
    получают метку на следующем прогоне, не только новые.
    """
    return f"""
MERGE `{CORE_FACT_SALES}` T
USING (
  SELECT
    TO_HEX(MD5(CONCAT(s.doc_id, '|', s.position_id)))               AS transaction_id,
    {_PERIMETER_PARSE_DATE}                                         AS transaction_date,
    s.product_id,
    s.entity_type,
    s.discount,
    s.agent_id,
    s.quantity                                                      AS sell_quantity,
    CAST(0.0 AS FLOAT64)                                            AS return_quantity,
    s.revenue_kgs                                                   AS sell_sum_kgs,
    CAST(0.0 AS FLOAT64)                                            AS return_sum_kgs,
    s.revenue_kgs                                                   AS revenue_kgs,
    CASE
      WHEN b.cogs_kgs IS NOT NULL AND b.sell_sum_kgs > 0
        THEN {_COGS_EXPR}
      ELSE NULL
    END                                                             AS cogs_kgs,
    CASE
      WHEN b.cogs_kgs IS NOT NULL AND b.sell_sum_kgs > 0
        THEN {_MARGIN_EXPR}
      ELSE NULL
    END                                                             AS margin_kgs,
    ROUND(SAFE_DIVIDE(s.revenue_kgs, fx.rate_kgs_per_usd), 4)       AS revenue_usd,
    CASE
      WHEN b.cogs_kgs IS NOT NULL AND b.sell_sum_kgs > 0 AND fx.rate_kgs_per_usd IS NOT NULL
        THEN {_COGS_USD_EXPR}
      ELSE NULL
    END                                                             AS cogs_usd,
    CASE
      WHEN b.cogs_kgs IS NOT NULL AND b.sell_sum_kgs > 0 AND fx.rate_kgs_per_usd IS NOT NULL
        THEN {_MARGIN_USD_EXPR}
      ELSE NULL
    END                                                             AS margin_usd,
    s.sales_channel_id,
    s.sales_channel_name,
    CAST(NULL AS STRING)                                            AS project_id,
    CAST(NULL AS STRING)                                            AS project_name,
    CURRENT_TIMESTAMP()                                             AS _loaded_at
  FROM `{STG_FACT_SALES_PERIMETER}` s
  LEFT JOIN `{CORE_BYVARIANT_BCK}` b
    ON  s.product_id = b.product_id
    AND DATE_TRUNC({_PERIMETER_PARSE_DATE}, WEEK(SATURDAY)) = b._week_start
  LEFT JOIN `{CORE_DIM_FX}` fx
    ON  {_PERIMETER_PARSE_DATE} = fx.date
) S
ON  T.transaction_id   = S.transaction_id
AND T.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL {window_days} DAY)

WHEN MATCHED THEN UPDATE SET
  T.sell_quantity   = S.sell_quantity,
  T.return_quantity = S.return_quantity,
  T.sell_sum_kgs    = S.sell_sum_kgs,
  T.return_sum_kgs  = S.return_sum_kgs,
  T.revenue_kgs     = S.revenue_kgs,
  T.cogs_kgs        = S.cogs_kgs,
  T.margin_kgs      = S.margin_kgs,
  T.revenue_usd     = S.revenue_usd,
  T.cogs_usd        = S.cogs_usd,
  T.margin_usd      = S.margin_usd,
  T.sales_channel_id   = S.sales_channel_id,
  T.sales_channel_name = S.sales_channel_name,
  T.discount        = S.discount,
  T._loaded_at      = S._loaded_at

WHEN NOT MATCHED THEN INSERT (
  transaction_id,
  transaction_date,
  product_id,
  entity_type,
  agent_id,
  sell_quantity,
  return_quantity,
  sell_sum_kgs,
  return_sum_kgs,
  revenue_kgs,
  cogs_kgs,
  margin_kgs,
  revenue_usd,
  cogs_usd,
  margin_usd,
  sales_channel_id,
  sales_channel_name,
  project_id,
  project_name,
  discount,
  _loaded_at
) VALUES (
  S.transaction_id,
  S.transaction_date,
  S.product_id,
  S.entity_type,
  S.agent_id,
  S.sell_quantity,
  S.return_quantity,
  S.sell_sum_kgs,
  S.return_sum_kgs,
  S.revenue_kgs,
  S.cogs_kgs,
  S.margin_kgs,
  S.revenue_usd,
  S.cogs_usd,
  S.margin_usd,
  S.sales_channel_id,
  S.sales_channel_name,
  S.project_id,
  S.project_name,
  S.discount,
  S._loaded_at
)

-- SALES-REFRESH-WINDOW (ADR-144 §8, узкая форма): второй MERGE того же класса (ADR-144 §7).
-- Тот же явный повтор границы ON в условии DELETE, то же обоснование (C2, ADR-101 §7
-- ловушка ii). Прежний докстринг функции («ветки удаления НЕТ, будущая отдельная задача»)
-- обновлён ниже — задача больше не будущая, это она и есть.
WHEN NOT MATCHED BY SOURCE
  AND T.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL {window_days} DAY)
  -- ROLLBACK-ADJ §6 вариант 1, зеркало условия в _build_merge_sql: источник этого MERGE —
  -- staging периметра, и он представляет ТОЛЬКО строки розницы и отчётов комиссионера.
  -- Оптовые продажи в него не входят: без этого условия ветка удаления снесла бы их все
  -- (замер 2026-08-11: 6 922 строки, 269 440 872,10 KGS в окне 90 суток).
  AND T.sales_channel_id IS NULL
  AND COALESCE(T.sales_channel_name, '') IN {_PERIMETER_NAMES_SQL}
THEN DELETE
"""


def promote_perimeter_to_core(
    bq: bigquery.Client,
    window_days: int,
) -> dict:
    """MERGE stg_msklad.fact_sales_perimeter_staging → core.fact_sales_profit."""
    count_row = next(
        bq.query(f"SELECT COUNT(*) AS cnt FROM `{STG_FACT_SALES_PERIMETER}`").result()
    )
    staging_count = count_row.cnt
    if staging_count == 0:
        raise ValueError("promote_perimeter_to_core: staging table is empty — refuse to MERGE")

    # ── Pre-promote: предохранитель ADR-145 §4/§5 — тот же приём, второй MERGE
    # того же класса (ADR-144 §7); staging несёт ту же колонку transaction_date_raw
    # (PERIMETER_STAGING_SCHEMA), _PARSE_DATE применим без изменений
    _assert_staging_covers_merge_window(
        bq, STG_FACT_SALES_PERIMETER, window_days, "promote_perimeter_to_core"
    )

    log.info("Perimeter staging rows: %d | window_days: %d", staging_count, window_days)

    merge_sql = _build_perimeter_merge_sql(window_days)
    log.debug("Executing perimeter MERGE SQL:\n%s", merge_sql)

    job = bq.query(merge_sql)
    job.result()

    stats = {
        "staging_rows":   staging_count,
        "window_days":    window_days,
        "affected_rows":  job.num_dml_affected_rows,
    }
    log.info("Perimeter MERGE complete: %s", stats)
    return stats


# ─── Post-MERGE DQ snapshot ───────────────────────────────────────────────────

def get_coverage_stats(bq: bigquery.Client, window_days: int) -> dict:
    """
    Quick coverage check after promote — logged but NOT used as a gate
    (gate is CF-DQ's job). Used for diagnostics.
    """
    cutoff = (date.today() - timedelta(days=window_days)).isoformat()
    sql = f"""
    SELECT
      COUNTIF(agent_id IS NOT NULL) / COUNT(*)   AS agent_coverage,
      COUNTIF(cogs_kgs IS NOT NULL) / COUNT(*)   AS cogs_coverage,
      COUNTIF(revenue_usd IS NOT NULL) / COUNT(*) AS usd_coverage,
      COUNT(*)                                    AS total_rows,
      SUM(revenue_kgs)                            AS total_revenue_kgs
    FROM `{CORE_FACT_SALES}`
    WHERE transaction_date >= '{cutoff}'
    """
    row = next(bq.query(sql).result())
    stats = {
        "agent_coverage": round(float(row.agent_coverage or 0), 4),
        "cogs_coverage":  round(float(row.cogs_coverage or 0), 4),
        "usd_coverage":   round(float(row.usd_coverage or 0), 4),
        "total_rows":     row.total_rows,
        "total_revenue_kgs": round(float(row.total_revenue_kgs or 0), 2),
    }
    log.info("Coverage stats (last %dd): %s", window_days, stats)
    return stats


# ─── Schema ───────────────────────────────────────────────────────────────────

PURCHASE_SCHEMA = [
    bigquery.SchemaField("purchase_order_id",     "STRING",    mode="REQUIRED"),
    bigquery.SchemaField("order_name",        "STRING"),
    bigquery.SchemaField("position_id",           "STRING"),
    bigquery.SchemaField("order_date",            "DATE",      mode="REQUIRED"),
    bigquery.SchemaField("planned_delivery_date", "DATE"),
    bigquery.SchemaField("product_id",            "STRING"),
    bigquery.SchemaField("supplier_id",           "STRING"),
    bigquery.SchemaField("quantity_ordered",      "FLOAT64"),
    bigquery.SchemaField("quantity_shipped",      "FLOAT64"),
    bigquery.SchemaField("quantity_in_transit",   "FLOAT64"),
    bigquery.SchemaField("price_kgs",             "FLOAT64"),
    bigquery.SchemaField("discount",              "FLOAT64"),
    bigquery.SchemaField("sum_kgs",               "FLOAT64"),
    bigquery.SchemaField("in_transit_sum_kgs",    "FLOAT64"),
    bigquery.SchemaField("currency_rate",         "FLOAT64"),
    bigquery.SchemaField("status_id",             "STRING"),
    bigquery.SchemaField("status_name",           "STRING"),
    bigquery.SchemaField("is_in_transit",         "BOOL"),
    bigquery.SchemaField("_loaded_at",            "TIMESTAMP"),
]


# ─── DDL ──────────────────────────────────────────────────────────────────────

def ensure_fact_purchases(bq: bigquery.Client) -> None:
    """
    Create core.fact_purchases if it doesn't exist.
    Partitioned by order_date, clustered by product_id + supplier_id.
    Idempotent.
    """
    tbl = bigquery.Table(CORE_FACT_PURCHASES, schema=PURCHASE_SCHEMA)
    tbl.time_partitioning = bigquery.TimePartitioning(
        type_=bigquery.TimePartitioningType.DAY,
        field="order_date",
    )
    tbl.clustering_fields = ["product_id", "supplier_id"]
    bq.create_table(tbl, exists_ok=True)
    log.info("Table ready: %s", CORE_FACT_PURCHASES)


# ─── Load ─────────────────────────────────────────────────────────────────────

def load_purchases(
    bq: bigquery.Client,
    records: list[dict],
) -> int:
    """
    WRITE_TRUNCATE load into core.fact_purchases.

    Strategy: full replace every run. With only 173 orders and ~5K positions,
    WRITE_TRUNCATE is cheaper and simpler than MERGE — no deduplication edge cases.

    Returns number of rows loaded.
    """
    if not records:
        log.warning("load_purchases: 0 records — skipping")
        return 0

    ensure_fact_purchases(bq)

    job_config = bigquery.LoadJobConfig(
        schema=PURCHASE_SCHEMA,
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        ignore_unknown_values=False,
        max_bad_records=0,
    )

    job = bq.load_table_from_json(records, CORE_FACT_PURCHASES, job_config=job_config)
    job.result()

    rows = bq.get_table(CORE_FACT_PURCHASES).num_rows
    log.info("Loaded %d rows → %s (WRITE_TRUNCATE)", rows, CORE_FACT_PURCHASES)
    return rows

# ─── fact_returns schema ───────────────────────────────────────────────────────

FACT_RETURNS_SCHEMA = [
    bigquery.SchemaField("return_id",   "STRING",    mode="REQUIRED"),
    bigquery.SchemaField("return_type", "STRING",    mode="REQUIRED"),
    bigquery.SchemaField("return_date", "DATE",      mode="REQUIRED"),
    bigquery.SchemaField("product_id",  "STRING"),
    bigquery.SchemaField("agent_id",    "STRING"),
    bigquery.SchemaField("quantity",    "FLOAT64"),
    bigquery.SchemaField("sum_kgs",     "FLOAT64"),
    bigquery.SchemaField("cost_kgs",    "FLOAT64"),
    bigquery.SchemaField("has_basis",   "BOOL"),
    bigquery.SchemaField("_loaded_at",  "TIMESTAMP", mode="REQUIRED"),
]

_FACT_RETURNS_TABLE = f"{GCP_PROJECT}.core.fact_returns"


def load_returns(bq: bigquery.Client, records: list[dict]) -> int:
    """
    WRITE_TRUNCATE в core.fact_returns.
    Полная перезапись окна — идемпотентно, без MERGE.
    _loaded_at проставляется здесь, не в fetch-слое.
    """
    import datetime as _dt

    loaded_at = _dt.datetime.now(_dt.timezone.utc).isoformat()
    rows = [{**r, "_loaded_at": loaded_at} for r in records]

    job_config = bigquery.LoadJobConfig(
        schema=FACT_RETURNS_SCHEMA,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
    )

    job = bq.load_table_from_json(rows, _FACT_RETURNS_TABLE, job_config=job_config)
    job.result()

    if job.errors:
        raise RuntimeError(f"load_returns BQ errors: {job.errors}")

    log.info("load_returns: %d rows → %s (WRITE_TRUNCATE)", len(rows), _FACT_RETURNS_TABLE)
    return len(rows)