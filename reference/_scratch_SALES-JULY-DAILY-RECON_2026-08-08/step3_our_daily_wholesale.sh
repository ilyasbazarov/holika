#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list

bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 1000 '
SELECT
  transaction_date,
  COUNT(*) AS n_rows,
  SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
  AND (sales_channel_name IS NULL OR sales_channel_name = "Оптовая торговля")
GROUP BY transaction_date
ORDER BY transaction_date
'

date -u
gcloud auth list
