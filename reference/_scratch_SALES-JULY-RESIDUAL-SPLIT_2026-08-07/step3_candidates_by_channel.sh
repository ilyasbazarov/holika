#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list

bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 1000 '
SELECT
  entity_type,
  sales_channel_name,
  COUNT(*) AS n_rows,
  SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
  AND _loaded_at < TIMESTAMP("2026-07-19 00:00:00 UTC")
GROUP BY entity_type, sales_channel_name
ORDER BY entity_type, sales_channel_name
'

date -u
gcloud auth list
