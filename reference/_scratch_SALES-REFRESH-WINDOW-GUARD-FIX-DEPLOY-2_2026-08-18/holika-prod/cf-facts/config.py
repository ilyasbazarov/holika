# ─── GCP ──────────────────────────────────────────────────────────────────────
GCP_PROJECT  = "msklad-bi-prod"

# ─── GCS ──────────────────────────────────────────────────────────────────────
GCS_RAW      = "msklad-raw-msklad-bi-prod"
GCS_ARCHIVE  = "msklad-archive-msklad-bi-prod"

# ─── BigQuery datasets ────────────────────────────────────────────────────────
BQ_STG       = f"{GCP_PROJECT}.stg_msklad"
BQ_CORE      = f"{GCP_PROJECT}.core"
BQ_AUDIT     = f"{GCP_PROJECT}.audit"
BQ_MARTS     = f"{GCP_PROJECT}.marts"
BQ_BACKUP    = f"{GCP_PROJECT}._backup"

# ─── МойСклад API ─────────────────────────────────────────────────────────────
MSKLAD_BASE  = "https://api.moysklad.ru/api/remap/1.2"
MSKLAD_RPS   = 4          # req/sec (hard limit 5, buffer to 4)
PAGE_SIZE    = 1000       # max rows per page

# ─── Secret Manager ───────────────────────────────────────────────────────────
SECRET_TOKEN = "msklad-token"

# ─── Staging table names ──────────────────────────────────────────────────────
STG_FACT_SALES     = f"{BQ_STG}.fact_sales_staging"
STG_BYVARIANT      = f"{BQ_STG}.byvariant_staging"
# SALES-PERIMETER-EXTEND (ADR-103 §8 вариант (a)) — отдельная staging-таблица, отдельный
# ингест по прецеденту ADR-024, не расширение `fact_sales_staging`/`_build_merge_sql`.
STG_FACT_SALES_PERIMETER = f"{BQ_STG}.fact_sales_perimeter_staging"

# ─── Core table names ─────────────────────────────────────────────────────────
CORE_FACT_SALES    = f"{BQ_CORE}.fact_sales_profit"
CORE_DIM_FX        = f"{BQ_CORE}.dim_fx_rates"
# Static byvariant backup for COGS approximation in hourly mode
CORE_BYVARIANT_BCK = f"{BQ_CORE}.fact_sales_profit_byvariant_backup"

# ─── GCS paths ────────────────────────────────────────────────────────────────
GCS_PREFIX_DEMAND  = "demand/incremental"

# ─── Rolling windows ──────────────────────────────────────────────────────────
HOURLY_WINDOW_DAYS  = 7
WEEKLY_WINDOW_DAYS  = 90

# ─── Предохранитель ADR-145 §4/§5 (SALES-REFRESH-WINDOW-MANDATE-ADJ, две правки) ──────
# Допуск ОБОИХ краёв окна MERGE в _assert_staging_covers_merge_window (bq_ops.py):
# сравнение по MIN/MAX(transaction_date) даёт ложный отказ, если ровно на границе окна
# случился день без единой продажи. Измерено по 180-суточному окну core.fact_sales_profit
# (reference/sales_refresh_window_mandate_adj_2026-08-11.md §2, решение 3): 12 суток без
# продаж из 181 (6,63%), окон из ТРЁХ подряд пустых суток — ноль. Допуск в 3 суток снимает
# ложный отказ (не встречен ни разу за 180 суток) ценой трёх суток глубины защиты против
# класса ошибки в 83 суток (часовой staging при window_days=90) на нижнем крае.
# Верхний край изначально был задуман без допуска (отставание = признак пропущенного
# прогона), но это предположение опровергнуто второй адъюдикацией (2026-08-11): MAX(date)
# есть свойство ДАННЫХ (последний день с продажей), не признак того, что прогон отработал
# — без допуска один пустой день останавливал бы promote (в т.ч. часовой, ежечасный) на
# ~24 прогона подряд. Тот же допуск применяется к обоим концам одной константой.
GUARD_TOLERANCE_DAYS = 3

# ─── Метки канала периметра — ЕДИНЫЙ источник (SALES-REFRESH-WINDOW-ROLLBACK-ADJ §6 вариант 1) ─
# Значения проставляет fetch_perimeter.py (розница и отчёты комиссионера), и по НИМ ЖЕ обе ветки
# удаления в bq_ops.py отличают свои строки от чужих. Держать их в двух местах нельзя: смена метки
# в загрузчике молча расширила бы область удаления соседней ветки — ровно тот дефект, который
# вскрыт 2026-08-11. Различитель — ПАРА полей: у строк периметра sales_channel_id всегда NULL,
# у настоящих каналов МойСклада id заполнен. Коллизий в истории ноль (замер
# reference/_scratch_SALES-REFRESH-WINDOW-ROLLBACK-ADJ_2026-08-11/, запрос B).
PERIMETER_CHANNEL_RETAIL     = "Розница"
PERIMETER_CHANNEL_COMMISSION = "Комиссия"
PERIMETER_CHANNEL_NAMES      = (PERIMETER_CHANNEL_RETAIL, PERIMETER_CHANNEL_COMMISSION)
# SALES-PERIMETER-EXTEND: тот же скользящий охват, что у весового (weekly) демand-ингеста —
# отдельный ингест, но не отдельная каденция без основания.
PERIMETER_WINDOW_DAYS = WEEKLY_WINDOW_DAYS

# ─── SALES-CONSIGNMENT-REVENUE (ADR-103 §7) ───────────────────────────────────
# Комиссионный канал за зону паритета (2026-05-01…2026-08-01) исчерпывающе измерен
# `ADR-104 §2/§5` (`reference/sales_perimeter_confirm_2026-08-02.md`): ровно эти три
# контрагента, и на весь этот период приходится ровно один документ `entity/demand`
# на них (отгрузка комиссионеру, не продажа). Различитель `SALES-INGEST-PATCH` Шаг 1:
# среди уже загружаемых полей `fetch_demands.py` (agent_id, sales_channel_id, project_id,
# entity_type) единственный пригодный признак — сам `agent_id`; ни тип договора, ни склад
# ингестом не читаются. Форма фикса — исключение по списку контрагентов канала.
# Риск, названный явно (не скрыт): список измерен на зоне до 2026-08-01; появление нового
# контрагента в комиссионном канале потребует повторного замера, автоматически не подхватится.
COMMISSION_CHANNEL_AGENT_IDS = {
    "0276f431-2ff5-11ef-0a80-11d40019917f",  # UMAI WB (Договор КР)
    "3c080755-03ff-11f0-0a80-0c2c00104bbb",  # Bloom WB (Договор)
    "31d135bc-4df8-11f1-0a80-1c8a0053c5b4",  # ООО «РВБ»
}

# ─── Purchase order statuses ──────────────────────────────────────────────────
PURCHASE_ORDER_STATES = {
    "491d6da5-8b37-11ef-0a80-0762000253a8": "В пути",
    "491d62b6-8b37-11ef-0a80-0762000253a7": "Прибыл",
    "87b7a192-349f-11f1-0a80-1a0f000384c2": "Прибыл частично",
    "87b7a5e5-349f-11f1-0a80-1a0f000384c3": "Отменен",
}
IN_TRANSIT_STATUS_ID = "491d6da5-8b37-11ef-0a80-0762000253a8"
CORE_FACT_PURCHASES  = f"{GCP_PROJECT}.core.fact_purchases"
GCS_PREFIX_PURCHASES = "purchases/incremental"
