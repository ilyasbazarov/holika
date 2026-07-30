"""
CF-Inventory — ежедневный снэпшот остатков из МойСклад → GCS → BigQuery.

Запускается Cloud Scheduler: 0 21 * * * UTC = 03:00 KGT.
Стратегия: APPEND в партицию date_snapshot (= дата по KGT).
Идемпотентность: DELETE сегодняшней партиции перед APPEND.
"""

import json
import gzip
import logging
import functions_framework
from datetime import datetime, timezone, timedelta

from google.cloud import bigquery, storage

from config import GCP_PROJECT, GCS_RAW, BQ_CORE, SECRET_TOKEN
from helpers import get_token, paginate_report_stock, upload_ndjson_gz

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
log = logging.getLogger(__name__)

# ─── Схема BQ ────────────────────────────────────────────────────────────────

FACT_INVENTORY_SCHEMA = [
    bigquery.SchemaField("date_snapshot",      "DATE",      mode="REQUIRED"),
    bigquery.SchemaField("product_id",          "STRING",    mode="REQUIRED"),
    bigquery.SchemaField("entity_type",         "STRING"),
    bigquery.SchemaField("name",                "STRING"),
    bigquery.SchemaField("stock",               "FLOAT64"),
    bigquery.SchemaField("reserve",             "FLOAT64"),
    bigquery.SchemaField("in_transit",          "FLOAT64"),
    bigquery.SchemaField("quantity_available",  "FLOAT64"),
    bigquery.SchemaField("stock_days",          "FLOAT64"),   # API даёт float, не int
    bigquery.SchemaField("cost_kgs",            "FLOAT64"),   # price / 100
    bigquery.SchemaField("_loaded_at",          "TIMESTAMP", mode="REQUIRED"),
]

# ─── Парсинг ─────────────────────────────────────────────────────────────────

def _parse_href(href: str) -> str:
    """Извлечь последний сегмент URL как entity ID. Strip query params (?expand=...)."""
    return href.rstrip("/").rsplit("/", 1)[-1].split("?")[0]


def parse_stock_row(row: dict, date_snapshot: str, loaded_at: str) -> dict:
    meta       = row.get("meta", {})
    product_id = _parse_href(meta.get("href", ""))
    entity_type = meta.get("type", "unknown")

    # price в тыйынах → KGS
    price_raw = row.get("price") or 0
    cost_kgs  = round(float(price_raw) / 100.0, 4)

    return {
        "date_snapshot":      date_snapshot,
        "product_id":         product_id,
        "entity_type":        entity_type,
        "name":               row.get("name") or "",
        "stock":              float(row.get("stock") or 0),
        "reserve":            float(row.get("reserve") or 0),
        "in_transit":         float(row.get("inTransit") or 0),
        "quantity_available": float(row.get("quantity") or 0),
        "stock_days":         float(row.get("stockDays") or 0),
        "cost_kgs":           cost_kgs,
        "_loaded_at":         loaded_at,
    }

# ─── DQ Gate ─────────────────────────────────────────────────────────────────

def run_dq_gate(records: list) -> None:
    """
    Минимальный DQ перед загрузкой в BQ.
    При провале любого чека — прерываем, core не трогаем.
    """
    checks = []

    # 1. Не пустой ответ
    checks.append(("not_empty", len(records) > 0,
                   f"rows={len(records)}"))

    # 2. product_id заполнен у всех
    missing_ids = sum(1 for r in records if not r["product_id"])
    checks.append(("product_id_populated", missing_ids == 0,
                   f"missing={missing_ids}"))

    # 3. Финансовая нормализация: cost_kgs не в тыйынах
    #    Если средняя себестоимость > 500 000 KGS — скорее всего /100 не применилось
    positive_costs = [r["cost_kgs"] for r in records if r["cost_kgs"] > 0]
    if positive_costs:
        avg_cost = sum(positive_costs) / len(positive_costs)
        checks.append(("currency_normalization", avg_cost < 500_000,
                       f"avg_cost_kgs={avg_cost:.0f}"))

    # 4. Нет отрицательного stock_days (аномалия данных)
    bad_stock_days = sum(1 for r in records if r["stock_days"] < 0)
    checks.append(("stock_days_non_negative", bad_stock_days == 0,
                   f"bad_rows={bad_stock_days}"))

    all_passed = True
    for name, passed, detail in checks:
        status = "✅" if passed else "❌"
        log.info("%s DQ %s: %s", status, name, detail)
        if not passed:
            all_passed = False

    if not all_passed:
        raise ValueError("DQ Gate failed — core.fact_inventory не обновляется")

# ─── BQ операции ─────────────────────────────────────────────────────────────

def delete_todays_partition(bq: bigquery.Client, date_snapshot: str) -> None:
    """
    Идемпотентность: удаляем сегодняшнюю партицию перед APPEND.
    Если запуск первый за день — DELETE 0 строк, без ошибок.
    Если CF упала и перезапустилась — чистим предыдущую попытку.
    """
    query = f"""
        DELETE FROM `{BQ_CORE}.fact_inventory`
        WHERE date_snapshot = '{date_snapshot}'
    """
    job = bq.query(query)
    job.result()
    log.info("Partition %s deleted (idempotency reset)", date_snapshot)


def load_to_bq(bq: bigquery.Client, gcs_uri: str) -> int:
    """BQ load job: GCS NDJSON → APPEND в core.fact_inventory."""
    table_ref = f"{BQ_CORE}.fact_inventory"

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        schema=FACT_INVENTORY_SCHEMA,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        create_disposition=bigquery.CreateDisposition.CREATE_IF_NEEDED,
        ignore_unknown_values=False,
        max_bad_records=0,
    )

    load_job = bq.load_table_from_uri(gcs_uri, table_ref, job_config=job_config)
    load_job.result()  # ждём завершения

    rows_loaded = load_job.output_rows
    log.info("BQ load complete: %d rows → %s", rows_loaded, table_ref)
    return rows_loaded

# ─── Entry point ─────────────────────────────────────────────────────────────

@functions_framework.http
def main(request):
    KGT = timezone(timedelta(hours=6))
    now_kgt    = datetime.now(KGT)
    now_utc    = datetime.now(timezone.utc)

    # date_snapshot = дата по Бишкеку, не UTC
    date_snapshot = now_kgt.date().isoformat()           # "YYYY-MM-DD"
    loaded_at     = now_utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    ts_str        = now_kgt.strftime("%Y%m%dT%H%M%S")

    log.info("CF-Inventory START | date_snapshot=%s | ts=%s", date_snapshot, ts_str)

    token      = get_token(GCP_PROJECT, SECRET_TOKEN)
    bq_client  = bigquery.Client(project=GCP_PROJECT)
    gcs_client = storage.Client(project=GCP_PROJECT)

    # ── 1. Выгрузка из API ────────────────────────────────────────────────────
    log.info("Fetching report/stock/all (stockMode=all, quantityMode=all) ...")
    raw_rows = list(paginate_report_stock(token))
    log.info("API fetch done: %d rows", len(raw_rows))

    # ── 2. Парсинг ────────────────────────────────────────────────────────────
    records = [parse_stock_row(r, date_snapshot, loaded_at) for r in raw_rows]

    # ── 3. DQ Gate ────────────────────────────────────────────────────────────
    run_dq_gate(records)

    # ── 4. Сохранить сырой NDJSON в GCS ──────────────────────────────────────
    gcs_path = f"stock/incremental/snapshot_{ts_str}.ndjson.gz"
    payload  = b"\n".join(
        json.dumps(r, ensure_ascii=False, default=str).encode("utf-8")
        for r in records
    )
    gcs_uri = upload_ndjson_gz(gcs_client, GCS_RAW, gcs_path, payload)
    log.info("GCS upload done: %s", gcs_uri)

    # ── 5. Идемпотентность: сброс сегодняшней партиции ───────────────────────
    delete_todays_partition(bq_client, date_snapshot)

    # ── 6. APPEND в BQ ───────────────────────────────────────────────────────
    rows_loaded = load_to_bq(bq_client, gcs_uri)

    result = {
        "status":        "ok",
        "date_snapshot": date_snapshot,
        "rows_fetched":  len(records),
        "rows_loaded":   rows_loaded,
        "gcs_path":      gcs_uri,
    }
    log.info("CF-Inventory DONE: %s", result)
    return result, 200