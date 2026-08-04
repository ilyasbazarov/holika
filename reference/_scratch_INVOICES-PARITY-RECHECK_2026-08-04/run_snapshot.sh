#!/usr/bin/env bash
set -euo pipefail

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRATCH_DIR"

echo "=== UTC-якорь + личность вызывающего (начало) ==="
date -u
gcloud auth list

echo "=== Секрет: чтение в переменную окружения (значение не печатается) ==="
export MSKLAD_TOKEN
MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"

echo "=== Живой снимок entity/invoiceout (read-only) ==="
python3 "$SCRATCH_DIR/fetch_invoices_live.py" > "$SCRATCH_DIR/live_source_snapshot.json" 2> "$SCRATCH_DIR/live_source_fetch.log"
cat "$SCRATCH_DIR/live_source_fetch.log"
cat "$SCRATCH_DIR/live_source_snapshot.json"

echo "=== Наша сторона: marts.customer_invoices_ar (read-only BQ) ==="
bq query --use_legacy_sql=false --format=prettyjson < "$SCRATCH_DIR/query_marts_side.sql" | tee "$SCRATCH_DIR/marts_side_snapshot.json"

unset MSKLAD_TOKEN

echo "=== UTC-якорь + личность вызывающего (конец) ==="
date -u
gcloud auth list

echo "=== Готово. Артефакты в: $SCRATCH_DIR ==="
