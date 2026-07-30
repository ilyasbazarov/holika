# ── CF-Dim / config.py ───────────────────────────────────────────────────────
# Все константы пайплайна. Менять только здесь.

GCP_PROJECT = "msklad-bi-prod"
GCS_RAW     = "msklad-raw-msklad-bi-prod"

BQ_CORE     = f"{GCP_PROJECT}.core"
BQ_STG      = f"{GCP_PROJECT}.stg_msklad"

MSKLAD_BASE = "https://api.moysklad.ru/api/remap/1.2"
MSKLAD_RPS  = 4        # запросов/сек
PAGE_SIZE   = 1000
RPS_DELAY   = 0.25     # секунд между запросами

SECRET_TOKEN = "msklad-token"

# Временная зона для дат снэпшотов
TZ_BISHKEK = "Asia/Bishkek"
