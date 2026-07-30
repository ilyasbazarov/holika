# ─── GCP ─────────────────────────────────────────────────────────────────────
GCP_PROJECT  = "msklad-bi-prod"

# ─── GCS ─────────────────────────────────────────────────────────────────────
GCS_RAW      = "msklad-raw-msklad-bi-prod"
GCS_ARCHIVE  = "msklad-archive-msklad-bi-prod"

# ─── BigQuery датасеты ───────────────────────────────────────────────────────
BQ_STG       = f"{GCP_PROJECT}.stg_msklad"
BQ_CORE      = f"{GCP_PROJECT}.core"
BQ_AUDIT     = f"{GCP_PROJECT}.audit"
BQ_MARTS     = f"{GCP_PROJECT}.marts"
BQ_BACKUP    = f"{GCP_PROJECT}._backup"

# ─── Service Accounts ────────────────────────────────────────────────────────
SA_ETL       = "etl-sa@msklad-bi-prod.iam.gserviceaccount.com"

# ─── Secrets ─────────────────────────────────────────────────────────────────
SECRET_TOKEN = "msklad-token"

# ─── МойСклад API ────────────────────────────────────────────────────────────
MSKLAD_BASE  = "https://api.moysklad.ru/api/remap/1.2"
MSKLAD_RPS   = 4      # запросов в секунду (чуть ниже лимита 5)
PAGE_SIZE    = 1000   # максимум МойСклад
