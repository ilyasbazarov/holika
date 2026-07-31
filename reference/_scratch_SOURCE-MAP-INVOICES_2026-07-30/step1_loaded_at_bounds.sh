#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

PROJECT=msklad-bi-prod

bq query --use_legacy_sql=false --project_id="$PROJECT" --format=prettyjson '
SELECT
  COUNT(*) AS row_count,
  MIN(_loaded_at) AS min_loaded_at,
  MAX(_loaded_at) AS max_loaded_at,
  COUNT(DISTINCT DATE(_loaded_at)) AS distinct_load_dates
FROM `msklad-bi-prod.core.fact_customer_invoices`
' 2>&1

gcloud auth list
date -u
