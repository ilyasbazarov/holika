#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"
TABLE="core.fact_customer_invoices"

echo "=== bq show (schema+meta), table=${TABLE} ==="
bq show --format=prettyjson "${PROJECT}:${TABLE}" | tee bq_show_fact_customer_invoices.json

echo "=== INFORMATION_SCHEMA.COLUMNS for fact_customer_invoices ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson '
SELECT column_name, data_type, ordinal_position
FROM `msklad-bi-prod.core.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = "fact_customer_invoices"
ORDER BY ordinal_position
' | tee information_schema_columns.json

echo "=== COUNT(*) total ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson '
SELECT COUNT(*) AS total_rows
FROM `msklad-bi-prod.core.fact_customer_invoices`
' | tee count_total.json

echo "=== date -u (end) ==="
date -u

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== ARTIFACT DIR ==="
pwd
