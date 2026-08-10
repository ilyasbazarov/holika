#!/bin/bash
# Read-only bq dry_run проверка SQL предохранителя ADR-145 §4/§5 (SALES-REFRESH-WINDOW).
# Класс A, только --dry_run (валидация синтаксиса+стоимости, ничего не исполняет и не читает данные).
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"
PARSE_DATE="DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek')"

echo "=== dry_run: guard SELECT против stg_msklad.fact_sales_staging ==="
bq query --project_id="$PROJECT" --nouse_legacy_sql --dry_run \
  "SELECT MIN(${PARSE_DATE}) AS min_date FROM \`${PROJECT}.stg_msklad.fact_sales_staging\` s"

echo "=== dry_run: guard SELECT против stg_msklad.fact_sales_perimeter_staging ==="
bq query --project_id="$PROJECT" --nouse_legacy_sql --dry_run \
  "SELECT MIN(${PARSE_DATE}) AS min_date FROM \`${PROJECT}.stg_msklad.fact_sales_perimeter_staging\` s"

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== date -u (end) ==="
date -u
