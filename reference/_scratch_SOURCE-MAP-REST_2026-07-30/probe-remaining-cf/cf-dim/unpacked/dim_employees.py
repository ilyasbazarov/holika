# ── CF-Dim / dim_employees.py ────────────────────────────────────────────────
# Выгружает entity/employee → stg → SCD1 MERGE в core.dim_employees

import logging

from google.cloud import bigquery, storage

from config import BQ_CORE, BQ_STG
from helpers import now_utc, paginate_entity, upload_json_gz

log = logging.getLogger(__name__)

_STG_TABLE  = f"{BQ_STG}.employees_staging"
_CORE_TABLE = f"{BQ_CORE}.dim_employees"

_SCHEMA = [
    bigquery.SchemaField("employee_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("full_name",   "STRING", mode="NULLABLE"),
    bigquery.SchemaField("position",    "STRING", mode="NULLABLE"),
    bigquery.SchemaField("_loaded_at",  "STRING", mode="NULLABLE"),
]


def _parse_employee(entity: dict) -> dict:
    # full_name: МойСклад хранит как "lastName firstName middleName" в name
    # или отдельно в полях — берём name как есть
    return {
        "employee_id": entity.get("id", ""),
        "full_name":   entity.get("name"),
        "position":    entity.get("position"),
        "_loaded_at":  now_utc(),
    }


def run(session, bq_client: bigquery.Client,
        gcs_client: storage.Client, uuids: dict, run_id: str) -> int:
    log.info("dim_employees: выгрузка из entity/employee")

    records = [_parse_employee(e)
               for e in paginate_entity(session, "entity/employee")]

    log.info("dim_employees: получено %d записей", len(records))

    if not records:
        raise ValueError("dim_employees: пустой ответ от API — прерываем")

    # ── GCS raw ──────────────────────────────────────────────────────────────
    upload_json_gz(
        gcs_client, records,
        f"employees/incremental/run_{run_id}.json.gz",
    )

    # ── Staging (WRITE_TRUNCATE) ──────────────────────────────────────────────
    job_config = bigquery.LoadJobConfig(
        schema=_SCHEMA,
        write_disposition="WRITE_TRUNCATE",
    )
    job = bq_client.load_table_from_json(records, _STG_TABLE,
                                         job_config=job_config)
    job.result()
    log.info("dim_employees: staging загружен (%d строк)", len(records))

    # ── MERGE → core.dim_employees (SCD1) ────────────────────────────────────
    merge_sql = f"""
    MERGE `{_CORE_TABLE}` T
    USING `{_STG_TABLE}` S
    ON T.employee_id = S.employee_id

    WHEN MATCHED THEN UPDATE SET
        T.full_name  = S.full_name,
        T.position   = S.position,
        T._loaded_at = CAST(S._loaded_at AS TIMESTAMP)

    WHEN NOT MATCHED THEN INSERT (
        employee_id, full_name, position, _loaded_at
    ) VALUES (
        S.employee_id, S.full_name, S.position,
        CAST(S._loaded_at AS TIMESTAMP)
    )
    """
    bq_client.query(merge_sql).result()
    log.info("dim_employees: MERGE в core завершён")

    return len(records)