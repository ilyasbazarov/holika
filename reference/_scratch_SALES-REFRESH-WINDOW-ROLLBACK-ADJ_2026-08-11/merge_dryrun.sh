#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== ЯКОРЬ НАЧАЛА ==="; date -u; gcloud auth list 2>&1 | head -4; echo
for f in /tmp/merge_sales.sql /tmp/merge_perimeter.sql; do
  echo "--- dry_run: $f ---"
  bq query --project_id=$P --use_legacy_sql=false --dry_run --format=none < "$f" 2>&1 | tail -2
  echo
done
echo "=== Симметрия предикатов: каждая строка ровно в одной области ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 5 '
SELECT
  COUNT(*)                                                                                     AS rows_total,
  COUNTIF(sales_channel_id IS NULL AND COALESCE(sales_channel_name,"") IN ("Розница","Комиссия")) AS scope_perimeter,
  COUNTIF(NOT (sales_channel_id IS NULL AND COALESCE(sales_channel_name,"") IN ("Розница","Комиссия"))) AS scope_sales,
  COUNTIF(sales_channel_id IS NULL AND COALESCE(sales_channel_name,"") IN ("Розница","Комиссия"))
  + COUNTIF(NOT (sales_channel_id IS NULL AND COALESCE(sales_channel_name,"") IN ("Розница","Комиссия")))
  - COUNT(*)                                                                                    AS gap_or_overlap
FROM `msklad-bi-prod.core.fact_sales_profit`'
echo "=== ЯКОРЬ КОНЦА ==="; date -u; gcloud auth list 2>&1 | head -4
