#!/bin/bash
# Read-only bq dry_run проверка ОБНОВЛЁННОГО SQL предохранителя (три правки
# reference/sales_refresh_window_mandate_adj_2026-08-11.md §3): допуск константой (в Python,
# не в SQL), обе даты в одном запросе, проверка обоих концов окна (MIN и MAX).
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"
PARSE_DATE="DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek')"

for TABLE in "stg_msklad.fact_sales_staging" "stg_msklad.fact_sales_perimeter_staging"; do
  echo "=== dry_run: обновлённый guard SELECT против ${TABLE} ==="
  bq query --project_id="$PROJECT" --nouse_legacy_sql --dry_run \
    "SELECT
       MIN(${PARSE_DATE}) AS min_date,
       MAX(${PARSE_DATE}) AS max_date,
       DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AS window_start,
       DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)  AS freshness_floor
     FROM \`${PROJECT}.${TABLE}\` s"
done

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== date -u (end) ==="
date -u
