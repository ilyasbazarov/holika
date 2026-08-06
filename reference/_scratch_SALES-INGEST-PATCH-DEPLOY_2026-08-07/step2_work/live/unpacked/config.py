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
