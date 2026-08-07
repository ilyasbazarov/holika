#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list

bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 1000 '
SELECT
  transaction_date,
  agent_id,
  COUNT(*) AS n_rows,
  SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date IN ("2026-07-20","2026-07-21","2026-07-27","2026-07-29","2026-07-30")
  AND (sales_channel_name IS NULL OR sales_channel_name = "Оптовая торговля")
GROUP BY transaction_date, agent_id
ORDER BY transaction_date, sum_revenue_kgs DESC
'

date -u
gcloud auth list
