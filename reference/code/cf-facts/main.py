"""
main.py — CF-Facts entry point.

Modes (passed as JSON body field "mode"):

  hourly   → fetch entity/demand for last 7 days → GCS NDJSON → BQ staging
  weekly   → fetch entity/demand for last 90 days + report/profit/byvariant
             for 90 days → GCS NDJSON → BQ staging (both demand + byvariant)
  promote  → MERGE stg_msklad.fact_sales_staging → core.fact_sales_profit
  purchases → fetch ALL purchaseorders (full refresh) → core.fact_purchases

Workflow sequence (from workflow.yaml):
  step_facts (mode=hourly)  →  step_dq  →  step_promote (mode=promote, window_days=7)
  step_facts (mode=weekly)  →  step_dq  →  step_promote (mode=promote, window_days=90)
                                           →  step_purchases (mode=purchases)

CF-DQ (separate function) runs between load and promote — it reads staging and
decides pass/fail. CF-Facts does NOT gate on DQ — that's CF-DQ's job.

Deploy:
  gcloud functions deploy cf-facts \
    --gen2 --runtime=python312 --region=asia-east1 \
    --source=cf/cf_facts --entry-point=main \
    --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
    --memory=2048MB --timeout=540s --min-instances=1 \
    --set-secrets="MSKLAD_TOKEN=msklad-token:latest"
"""

import json
import logging
from datetime import date, timedelta, timezone, datetime

import flask
import requests
from google.cloud import bigquery, storage

from bq_ops import (
    ensure_staging_tables,
    get_coverage_stats,
    load_byvariant_staging,
    load_staging,
    promote_to_core,
    ensure_fact_purchases,
    load_purchases,
    load_returns,          # ← новое
)
from config import (
    GCS_PREFIX_DEMAND,
    GCS_RAW,
    GCP_PROJECT,
    HOURLY_WINDOW_DAYS,
    WEEKLY_WINDOW_DAYS,
)
from fetch_byvariant import fetch_byvariant_cogs
from fetch_demands import fetch_demand_positions
from fetch_purchases import fetch_purchase_positions
from fetch_returns import fetch_return_positions  # ← новое
from helpers import get_token, run_ts, upload_ndjson_gz

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger(__name__)


# ─── Main entry point ─────────────────────────────────────────────────────────

def main(request: flask.Request) -> flask.Response:
    body = request.get_json(force=True, silent=True) or {}
    mode        = body.get("mode", "hourly")
    run_id      = body.get("run_id") or run_ts()
    window_days = int(body.get("window_days", HOURLY_WINDOW_DAYS if mode != "weekly" else WEEKLY_WINDOW_DAYS))

    log.info("CF-Facts start | mode=%s run_id=%s window_days=%d", mode, run_id, window_days)

    try:
        if mode == "hourly":
            result = _run_load(run_id, window_days=HOURLY_WINDOW_DAYS)
        elif mode == "weekly":
            result = _run_weekly_load(run_id)
        elif mode == "promote":
            result = _run_promote(window_days)
        elif mode == "purchases":
            result = _run_purchases()
        elif mode == "returns":
            result = _run_returns(window_days)
        else:
            raise ValueError(f"Unknown mode: {mode!r}. Expected: hourly | weekly | promote | purchases | returns")

        log.info("CF-Facts complete | mode=%s | %s", mode, result)
        return flask.make_response(flask.jsonify({"status": "ok", "mode": mode, "run_id": run_id, **result}), 200)

    except Exception as exc:
        log.exception("CF-Facts FAILED | mode=%s run_id=%s", mode, run_id)
        return flask.make_response(flask.jsonify({"status": "error", "mode": mode, "run_id": run_id, "error": str(exc)}), 500)


# ─── Load modes ───────────────────────────────────────────────────────────────

def _run_load(run_id: str, window_days: int) -> dict:
    """
    Fetch demand positions for the last `window_days` days.
    Save NDJSON to GCS, then load to BQ staging (WRITE_TRUNCATE).
    """
    token  = get_token()
    bq     = bigquery.Client(project=GCP_PROJECT)
    gcs    = storage.Client(project=GCP_PROJECT)
    session = requests.Session()

    ensure_staging_tables(bq)

    date_to   = date.today()
    date_from = date_to - timedelta(days=window_days)

    log.info("Fetching demands: %s → %s (%dd rolling)", date_from, date_to, window_days)

    records = fetch_demand_positions(
        token, date_from, date_to, run_id, session=session
    )

    if not records:
        raise ValueError(
            f"API returned 0 demand position records for {date_from}→{date_to}. "
            "Possible: no shipments in window, or API issue."
        )

    # ── Save raw NDJSON to GCS (immutable archive)
    blob_path = f"{GCS_PREFIX_DEMAND}/run_{run_id}.ndjson.gz"
    upload_ndjson_gz(gcs, GCS_RAW, blob_path, records)

    # ── Load to BQ staging (WRITE_TRUNCATE — idempotent)
    loaded_rows = load_staging(bq, records)

    return {
        "demand_positions_fetched": len(records),
        "staging_rows_loaded": loaded_rows,
        "date_from": str(date_from),
        "date_to":   str(date_to),
        "gcs_path":  f"gs://{GCS_RAW}/{blob_path}",
    }


def _run_weekly_load(run_id: str) -> dict:
    """
    Weekly mode: fetch 90d demands + 90d byvariant COGS.
    Loads both to BQ staging for the subsequent promote step.
    """
    token   = get_token()
    bq      = bigquery.Client(project=GCP_PROJECT)
    gcs     = storage.Client(project=GCP_PROJECT)
    session = requests.Session()

    ensure_staging_tables(bq)

    date_to   = date.today()
    date_from = date_to - timedelta(days=WEEKLY_WINDOW_DAYS)

    # ── Step 1: demand positions (same as hourly but 90d window)
    log.info("Weekly load: fetching demands %s → %s", date_from, date_to)

    demand_records = fetch_demand_positions(
        token, date_from, date_to, run_id, session=session
    )

    if not demand_records:
        raise ValueError(f"0 demand positions for 90d window {date_from}→{date_to}")

    blob_path = f"{GCS_PREFIX_DEMAND}/weekly_run_{run_id}.ndjson.gz"
    upload_ndjson_gz(gcs, GCS_RAW, blob_path, demand_records)
    demand_loaded = load_staging(bq, demand_records)

    # ── Step 2: byvariant COGS (week-by-week for 90d)
    log.info("Weekly load: fetching byvariant COGS %s → %s", date_from, date_to)

    byvariant_records = fetch_byvariant_cogs(token, date_from, date_to, session=session)
    bv_loaded = load_byvariant_staging(bq, byvariant_records)

    return {
        "demand_positions_fetched":  len(demand_records),
        "staging_rows_loaded":       demand_loaded,
        "byvariant_records_fetched": len(byvariant_records),
        "byvariant_rows_loaded":     bv_loaded,
        "date_from": str(date_from),
        "date_to":   str(date_to),
    }


# ─── Promote mode ─────────────────────────────────────────────────────────────

def _run_promote(window_days: int) -> dict:
    """
    MERGE staging → core.fact_sales_profit.
    Called by Workflow AFTER CF-DQ passes.

    window_days drives both the MERGE partition filter and the COGS source selection:
      7  → hourly → byvariant backup
      90 → weekly → fresh byvariant_staging
    """
    bq = bigquery.Client(project=GCP_PROJECT)

    merge_stats    = promote_to_core(bq, window_days)
    coverage_stats = get_coverage_stats(bq, window_days)

    return {
        "merge_stats":    merge_stats,
        "coverage_stats": coverage_stats,
    }


# ─── Purchases mode ───────────────────────────────────────────────────────────

def _run_purchases() -> dict:
    """
    Fetch ALL purchaseorders (full refresh via WRITE_TRUNCATE).
    ~173 orders × avg 10-30 positions = ~2K-5K rows. Fast, no checkpoint needed.

    Called from:
      - weekly workflow (step_purchases after step_promote)
      - manual bootstrap: curl ... -d '{"mode":"purchases"}'

    WRITE_TRUNCATE strategy: cheaper and simpler than MERGE for this volume.
    Status changes (В пути → Прибыл) are captured on every run.
    """
    import requests as _requests
    from google.cloud import bigquery as _bq, storage as _storage
    from config import GCS_PREFIX_PURCHASES, GCS_RAW, GCP_PROJECT
    from helpers import get_token, run_ts, upload_ndjson_gz
    from fetch_purchases import fetch_purchase_positions
    from bq_ops import load_purchases

    token   = get_token()
    bq      = _bq.Client(project=GCP_PROJECT)
    gcs     = _storage.Client(project=GCP_PROJECT)
    session = _requests.Session()
    run_id  = run_ts()

    records = fetch_purchase_positions(token, session=session)

    if not records:
        # Non-fatal: 0 orders is unusual but possible
        import logging
        logging.getLogger(__name__).warning("fetch_purchase_positions returned 0 records")
        return {"purchase_positions_fetched": 0, "rows_loaded": 0}

    # Archive to GCS (immutable raw)
    blob_path = f"{GCS_PREFIX_PURCHASES}/run_{run_id}.ndjson.gz"
    upload_ndjson_gz(gcs, GCS_RAW, blob_path, records)

    rows = load_purchases(bq, records)

    return {
        "purchase_positions_fetched": len(records),
        "rows_loaded":                rows,
        "gcs_path":                   f"gs://{GCS_RAW}/{blob_path}",
    }


# ─── Returns mode ─────────────────────────────────────────────────────────────

def _run_returns(window_days: int) -> dict:
    """
    Fetch salesreturn + retailsalesreturn positions for last `window_days` days.
    WRITE_TRUNCATE to core.fact_returns — full window refresh, no MERGE needed.

    Called from:
      - weekly workflow (step_returns, after step_promote)
      - manual: curl ... -d '{"mode":"returns","window_days":90}'

    Notes:
      - applicable=true filter: only posted documents (no drafts)
      - cost field: present for salesreturn без основания (тыйыны ÷100)
                    ABSENT for retailsalesreturn and salesreturn с основанием → defaults to 0.0
      - has_basis: True only for salesreturn with demand link; always False for retailsalesreturn
    """
    token   = get_token()
    bq      = bigquery.Client(project=GCP_PROJECT)
    session = requests.Session()

    date_to   = date.today()
    date_from = date_to - timedelta(days=window_days)

    log.info("Returns load: fetching %s → %s (%dd window)", date_from, date_to, window_days)

    records = fetch_return_positions(token, date_from, date_to, session=session)

    # 0 возвратов — не ошибка (бывают периоды без возвратов)
    if not records:
        log.warning("fetch_return_positions returned 0 records for %s→%s", date_from, date_to)
        return {"return_positions_fetched": 0, "rows_loaded": 0}

    rows_loaded = load_returns(bq, records)

    by_type = {}
    for r in records:
        by_type[r["return_type"]] = by_type.get(r["return_type"], 0) + 1

    log.info("Returns loaded: %s", by_type)

    return {
        "return_positions_fetched": len(records),
        "rows_loaded":              rows_loaded,
        "by_type":                  by_type,
        "date_from":                str(date_from),
        "date_to":                  str(date_to),
    }