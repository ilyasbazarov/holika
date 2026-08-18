import logging
from datetime import datetime, timezone
from typing import Any
from google.cloud import bigquery
from config import GCP_PROJECT

log = logging.getLogger(__name__)

def get_bq_client() -> bigquery.Client:
    return bigquery.Client(project=GCP_PROJECT)

def run_scalar(bq: bigquery.Client, sql: str) -> Any:
    rows = list(bq.query(sql).result())
    if not rows:
        return None
    return list(rows[0].values())[0]

def run_row(bq: bigquery.Client, sql: str) -> dict | None:
    rows = list(bq.query(sql).result())
    if not rows:
        return None
    return dict(rows[0])

def write_dq_results(bq: bigquery.Client, run_id: str, checks: list) -> None:
    table_id = f"{GCP_PROJECT}.audit.dq_runs"
    now_iso  = datetime.now(timezone.utc).isoformat()
    rows = [
        {"run_id": run_id, "check_name": c["name"],
         "passed": c["passed"], "detail": c["detail"], "checked_at": now_iso}
        for c in checks
    ]
    errors = bq.insert_rows_json(table_id, rows)
    if errors:
        log.warning("audit.dq_runs insert errors: %s", errors)
    else:
        log.info("audit.dq_runs: %d чеков записано, run_id=%s", len(rows), run_id)
