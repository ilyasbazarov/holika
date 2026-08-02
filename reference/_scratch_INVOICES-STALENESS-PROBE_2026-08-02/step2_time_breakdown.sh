#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"

echo "=== MIN/MAX(_loaded_at), MIN/MAX(moment), COUNT(*) ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson '
SELECT
  MIN(_loaded_at) AS min_loaded_at,
  MAX(_loaded_at) AS max_loaded_at,
  MIN(moment) AS min_moment,
  MAX(moment) AS max_moment,
  COUNT(*) AS total_rows,
  COUNT(DISTINCT _loaded_at) AS distinct_loaded_at_values
FROM `msklad-bi-prod.core.fact_customer_invoices`
' | tee minmax_summary.json

echo "=== distribution of _loaded_at (top 20 distinct values by count) ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson '
SELECT _loaded_at, COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_customer_invoices`
GROUP BY _loaded_at
ORDER BY n_rows DESC
LIMIT 20
' | tee loaded_at_distribution.json

echo "=== COUNT(*) by year(moment) ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson '
SELECT EXTRACT(YEAR FROM moment) AS yr, COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_customer_invoices`
GROUP BY yr
ORDER BY yr
' | tee count_by_year.json

echo "=== COUNT(*) by month of last available year(moment) ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson '
DECLARE last_yr INT64;
SET last_yr = (SELECT MAX(EXTRACT(YEAR FROM moment)) FROM `msklad-bi-prod.core.fact_customer_invoices`);
SELECT last_yr AS year_used, EXTRACT(MONTH FROM moment) AS mo, COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_customer_invoices`
WHERE EXTRACT(YEAR FROM moment) = last_yr
GROUP BY year_used, mo
ORDER BY mo
' | tee count_by_month_last_year.json

echo "=== date -u (end) ==="
date -u

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== ARTIFACT DIR ==="
pwd
