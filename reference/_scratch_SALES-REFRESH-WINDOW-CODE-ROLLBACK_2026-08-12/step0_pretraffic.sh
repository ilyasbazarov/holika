#!/usr/bin/env bash
set -euo pipefail

date -u
gcloud auth list

echo "=== cf-facts traffic BEFORE rollback ==="
gcloud run services describe cf-facts \
  --region=asia-east1 --project=msklad-bi-prod \
  --format="table(status.traffic.revisionName, status.traffic.percent)"

echo "=== core.fact_sales_profit vs snap_20260811_163306 — pre-rollback baseline, rows in snapshot missing from live, by channel ==="
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

echo "=== total row counts, snapshot vs live ==="
bq query --use_legacy_sql=false --project_id=msklad-bi-prod --format=prettyjson '
SELECT
  (SELECT COUNT(*) FROM `msklad-bi-prod.core.fact_sales_profit_snap_20260811_163306`) AS snapshot_rows,
  (SELECT COUNT(*) FROM `msklad-bi-prod.core.fact_sales_profit`) AS live_rows
'

date -u
gcloud auth list
