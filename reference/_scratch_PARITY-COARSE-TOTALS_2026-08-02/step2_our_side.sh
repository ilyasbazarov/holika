#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"

echo "=== marts.inventory_health — SUM(stock) + число строк ==="
bq --project_id="$PROJECT" query --use_legacy_sql=false --format=prettyjson '
SELECT
  COUNT(*) AS n_rows,
  SUM(stock) AS sum_stock,
  MAX(date_snapshot) AS date_snapshot
FROM `msklad-bi-prod.marts.inventory_health`
'

echo "=== marts.in_transit — SUM(in_transit_sum_kgs) + число строк ==="
bq --project_id="$PROJECT" query --use_legacy_sql=false --format=prettyjson '
SELECT
  COUNT(*) AS n_rows,
  SUM(in_transit_sum_kgs) AS sum_in_transit_kgs
FROM `msklad-bi-prod.marts.in_transit`
'

echo "=== marts.customer_invoices_ar — SUM(sum_kgs/payed_sum_kgs/unpaid_sum_kgs) + число строк ==="
bq --project_id="$PROJECT" query --use_legacy_sql=false --format=prettyjson '
SELECT
  COUNT(*) AS n_rows,
  SUM(total_invoiced_kgs) AS sum_kgs,
  SUM(total_paid_kgs) AS payed_sum_kgs,
  SUM(total_unpaid_kgs) AS unpaid_sum_kgs
FROM `msklad-bi-prod.marts.customer_invoices_ar`
'

echo "=== date -u (end) ==="
date -u

echo "=== gcloud auth list (end) ==="
gcloud auth list
