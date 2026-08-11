#!/usr/bin/env bash
set -euo pipefail

PROJECT="msklad-bi-prod"

echo "=== UTC anchor (start) ==="
date -u
echo "=== auth identity (start) ==="
gcloud auth list

echo "=== CREATE SNAPSHOT TABLE ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --nouse_cache '
CREATE SNAPSHOT TABLE `msklad-bi-prod.core.fact_sales_profit_snap_20260811`
CLONE `msklad-bi-prod.core.fact_sales_profit`
'

echo "=== snapshot totals (all-time) ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --nouse_cache '
SELECT COUNT(*) AS row_count, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit_snap_20260811`
'

echo "=== snapshot totals — May 2026 ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --nouse_cache '
SELECT COUNT(*) AS row_count, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit_snap_20260811`
WHERE transaction_date BETWEEN "2026-05-01" AND "2026-05-31"
'

echo "=== snapshot totals — July 2026 ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --nouse_cache '
SELECT COUNT(*) AS row_count, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit_snap_20260811`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
'

echo "=== auth identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u
