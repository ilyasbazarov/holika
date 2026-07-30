import functions_framework
import logging
import json
from datetime import date, datetime, timezone, timedelta

import requests
from google.cloud import bigquery, secretmanager, storage

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

GCP_PROJECT  = "msklad-bi-prod"
GCS_RAW      = "msklad-raw-msklad-bi-prod"
BQ_CORE      = f"{GCP_PROJECT}.core"
BAKAI_FX_URL = "https://openbanking-api.bakai.kg/api/Directory/GetRateDirectory"
BAKAI_SECRET = "bakai-fx-token"


# ─── helpers ──────────────────────────────────────────────────────────────────

def get_secret(secret_id: str) -> str:
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{GCP_PROJECT}/secrets/{secret_id}/versions/latest"
    return client.access_secret_version(request={"name": name}).payload.data.decode()


def fetch_rates(token: str) -> dict:
    """Single call to Bakai API — returns full raw response."""
    resp = requests.get(
        BAKAI_FX_URL,
        headers={"Authorization": f"Bearer {token}", "accept": "application/json"},
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def extract_usd_rate(data: dict) -> float:
    """Extract USD/KGS official rate from officialRates[]."""
    for rate_obj in data.get("officialRates", []):
        if rate_obj.get("currencySymbol") == "USD":
            rate = float(rate_obj["rate"])
            log.info("НБКР USD/KGS via Bakai: %.4f", rate)
            return rate
    raise ValueError(f"USD not found in officialRates. Keys: {list(data.keys())}")


def archive_to_gcs(gcs_client: storage.Client, data: dict, today: date) -> None:
    try:
        blob_path = f"fx-rates/bakai_{today.isoformat()}.json"
        bucket = gcs_client.bucket(GCS_RAW)
        bucket.blob(blob_path).upload_from_string(
            json.dumps(data, ensure_ascii=False),
            content_type="application/json",
        )
        log.info("Archived → gs://%s/%s", GCS_RAW, blob_path)
    except Exception as exc:
        log.warning("GCS archive failed (non-blocking): %s", exc)


def get_max_fx_date(bq: bigquery.Client) -> date:
    row = next(bq.query(
        f"SELECT MAX(date) AS max_date FROM `{BQ_CORE}.dim_fx_rates`"
    ).result())
    return row.max_date if row.max_date else date(2020, 1, 1)


def upsert_fx_rate(bq: bigquery.Client, rate_date: date, rate: float) -> str:
    """
    MERGE rate into dim_fx_rates.
    Fixes TD-CF-FX: replaces WRITE_APPEND (caused duplicates on forward-fill days)
    with idempotent MERGE — safe to run multiple times per day.
    """
    sql = f"""
    MERGE `{BQ_CORE}.dim_fx_rates` T
    USING (
        SELECT DATE('{rate_date.isoformat()}') AS date,
               CAST({rate} AS FLOAT64)          AS rate_kgs_per_usd
    ) S
    ON T.date = S.date
    WHEN MATCHED THEN
        UPDATE SET T.rate_kgs_per_usd = S.rate_kgs_per_usd
    WHEN NOT MATCHED THEN
        INSERT (date, rate_kgs_per_usd) VALUES (S.date, S.rate_kgs_per_usd)
    """
    job = bq.query(sql)
    job.result()
    return "updated" if job.num_dml_affected_rows == 1 else "inserted"


def forward_fill_in_bq(bq: bigquery.Client) -> None:
    today = date.today().isoformat()
    sql = f"""
    INSERT INTO `{BQ_CORE}.dim_fx_rates` (date, rate_kgs_per_usd)
    SELECT
        DATE('{today}')       AS date,
        MAX(rate_kgs_per_usd) AS rate_kgs_per_usd
    FROM `{BQ_CORE}.dim_fx_rates`
    WHERE date = (SELECT MAX(date) FROM `{BQ_CORE}.dim_fx_rates`)
      AND NOT EXISTS (
          SELECT 1 FROM `{BQ_CORE}.dim_fx_rates`
          WHERE date = DATE('{today}')
      )
    """
    bq.query(sql).result()
    log.warning("Forward-filled rate for %s", today)


# ─── entry point ──────────────────────────────────────────────────────────────

@functions_framework.http
def main(request):
    bq  = bigquery.Client(project=GCP_PROJECT)
    gcs = storage.Client(project=GCP_PROJECT)
    today = datetime.now(timezone(timedelta(hours=6))).date()

    try:
        # 1. Skip if today already loaded
        if get_max_fx_date(bq) >= today:
            log.info("Rate for %s already in dim_fx_rates — skip", today)
            return {"status": "ok", "rows_added": 0, "reason": "already_up_to_date"}, 200

        # 2. Fetch from Bakai API (single call)
        token = get_secret(BAKAI_SECRET)
        raw_data = fetch_rates(token)

        # 3. Extract USD rate
        rate = extract_usd_rate(raw_data)

        # 4. Archive raw JSON to GCS (non-blocking)
        archive_to_gcs(gcs, raw_data, today)

        # 5. MERGE into dim_fx_rates (idempotent — fixes TD-CF-FX)
        action = upsert_fx_rate(bq, today, rate)
        log.info("Done: %s %.4f for %s", action, rate, today)

        return {
            "status": "ok",
            "date":   today.isoformat(),
            "rate":   rate,
            "action": action,
            "source": "bakai_bank_api",
        }, 200

    except requests.HTTPError as exc:
        status_code = exc.response.status_code if exc.response is not None else 0
        if status_code == 401:
            # Token expired — forward-fill and alert
            log.error("Bakai token 401 — needs rotation in Secret Manager (bakai-fx-token)")
            try:
                forward_fill_in_bq(bq)
            except Exception as ff_exc:
                log.error("Forward-fill failed: %s", ff_exc)
            return {
                "status": "degraded",
                "error":  "bakai_token_expired — update bakai-fx-token in Secret Manager",
            }, 200

        log.exception("CF-FX HTTP error: %s", exc)
        return {"status": "error", "error": str(exc)}, 500

    except Exception as exc:
        log.exception("CF-FX failed: %s", exc)
        try:
            forward_fill_in_bq(bq)
        except Exception as ff_exc:
            log.error("Forward-fill also failed: %s", ff_exc)
        return {"status": "degraded", "error": str(exc)}, 200
