# ── CF-Dim / main.py ─────────────────────────────────────────────────────────
# Cloud Function Gen2 — точка входа.
# Обновляет dim_products, dim_counterparties, dim_employees.
# Триггер: HTTP POST (Cloud Workflows или ручной вызов)
#
# Деплой:
#   gcloud functions deploy cf-dim \
#     --gen2 --runtime=python312 --region=asia-east1 \
#     --source=cf/cf_dim --entry-point=main \
#     --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
#     --memory=1024MB --timeout=540s \
#     --set-secrets="MSKLAD_TOKEN=msklad-token:latest"
#
# Ручной тест:
#   gcloud functions call cf-dim --region=asia-east1
#
# Тело запроса (опционально):
#   {"run_id": "manual_20260503"}

import logging
import os
import uuid
from datetime import datetime, timezone

import functions_framework
from google.cloud import bigquery, storage

import dim_counterparties
import dim_employees
import dim_products
from config import GCP_PROJECT, GCS_RAW
from helpers import get_token, load_uuids, make_session

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
log = logging.getLogger("cf_dim")


# ── Preflight ─────────────────────────────────────────────────────────────────

def preflight_checks(bq_client: bigquery.Client,
                     gcs_client: storage.Client) -> None:
    """
    Проверки перед запуском основной логики.
    GCS не проверяем в preflight — etl-sa имеет objectAdmin но не objects.list.
    Падение при upload даст понятную ошибку.
    """
    # 1. dim_metadata_mappings доступна и содержит нужные UUID
    uuids = load_uuids(bq_client)
    required = {"shelf_life", "country", "status_in_transit"}
    missing  = required - set(uuids.keys())
    if missing:
        raise RuntimeError(f"dim_metadata_mappings: отсутствуют UUID для {missing}")

    # 2. dim_fx_rates не устарела (tolerance 3 дня — выходные)
    fx_sql = """
        SELECT DATE_DIFF(CURRENT_DATE(), MAX(date), DAY) AS lag
        FROM `msklad-bi-prod.core.dim_fx_rates`
    """
    rows = list(bq_client.query(fx_sql).result())
    lag  = rows[0].lag if rows else 999
    if lag > 5:
        raise RuntimeError(f"dim_fx_rates устарела: {lag} дней назад")

    log.info("Preflight ✅  UUID=%d, FX lag=%d дн", len(uuids), lag)


# ── Entry point ───────────────────────────────────────────────────────────────

@functions_framework.http
def main(request):
    body   = request.get_json(silent=True) or {}
    run_id = body.get("run_id") or datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
    log.info("═" * 60)
    log.info("CF-Dim START  run_id=%s", run_id)

    try:
        # ── Клиенты ──────────────────────────────────────────────────────────
        bq_client  = bigquery.Client(project=GCP_PROJECT)
        gcs_client = storage.Client(project=GCP_PROJECT)

        # ── Auth / session ────────────────────────────────────────────────────
        token   = get_token(GCP_PROJECT)
        session = make_session(token)

        # ── Preflight ─────────────────────────────────────────────────────────
        preflight_checks(bq_client, gcs_client)
        uuids = load_uuids(bq_client)

        # ── dim_products ──────────────────────────────────────────────────────
        n_products = dim_products.run(
            session, bq_client, gcs_client, uuids, run_id
        )

        # ── dim_counterparties ────────────────────────────────────────────────
        n_counterparties = dim_counterparties.run(
            session, bq_client, gcs_client, uuids, run_id
        )

        # ── dim_employees ─────────────────────────────────────────────────────
        n_employees = dim_employees.run(
            session, bq_client, gcs_client, uuids, run_id
        )

        result = {
            "status":          "ok",
            "run_id":          run_id,
            "dim_products":    n_products,
            "dim_counterparties": n_counterparties,
            "dim_employees":   n_employees,
        }
        log.info("CF-Dim END ✅  %s", result)
        return result, 200

    except Exception as exc:
        log.exception("CF-Dim FAILED  run_id=%s: %s", run_id, exc)
        return {"status": "error", "run_id": run_id, "error": str(exc)}, 500