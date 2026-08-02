#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== marts.customer_invoices_ar — SUM(invoice_count), доп. к шагу 2 (число счетов, не число строк-групп) ==="
bq --project_id=msklad-bi-prod query --use_legacy_sql=false --format=prettyjson '
SELECT
  COUNT(*) AS n_groups,
  SUM(invoice_count) AS n_invoices_total
FROM `msklad-bi-prod.marts.customer_invoices_ar`
'

echo "=== date -u (end) ==="
date -u

echo "=== gcloud auth list (end) ==="
gcloud auth list
