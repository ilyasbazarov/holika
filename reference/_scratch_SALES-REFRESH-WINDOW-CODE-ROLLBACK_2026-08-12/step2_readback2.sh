#!/usr/bin/env bash
set -euo pipefail

date -u
gcloud auth list

echo "=== read-back 2: core.fact_sales_profit vs snap_20260811_163306, immediately after traffic switch, by channel ==="
bq query --use_legacy_sql=false --project_id=msklad-bi-prod --format=prettyjson '
SELECT
  s.sales_channel_id,
  COUNT(*) AS missing_from_live
FROM `msklad-bi-prod.core.fact_sales_profit_snap_20260811_163306` s
LEFT JOIN `msklad-bi-prod.core.fact_sales_profit` l
  USING (transaction_id)
WHERE l.transaction_id IS NULL
GROUP BY s.sales_channel_id
ORDER BY s.sales_channel_id
'

echo "=== total missing_from_live (expected: 36, no new since step0) ==="
bq query --use_legacy_sql=false --project_id=msklad-bi-prod --format=prettyjson '
SELECT COUNT(*) AS total_missing_from_live
FROM `msklad-bi-prod.core.fact_sales_profit_snap_20260811_163306` s
LEFT JOIN `msklad-bi-prod.core.fact_sales_profit` l
  USING (transaction_id)
WHERE l.transaction_id IS NULL
'

date -u
gcloud auth list
