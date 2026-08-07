#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list

# 4a. суточный разрез ВСЕГО июля (весь `core.fact_sales_profit`, по `transaction_date`)
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 1000 '
SELECT
  transaction_date,
  COUNT(*) AS n_rows,
  SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
GROUP BY transaction_date
ORDER BY transaction_date
'

# 4b. суточный разрез ТОЛЬКО кандидатов-сирот (по `transaction_date`) — локализация превышения
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 1000 '
SELECT
  transaction_date,
  COUNT(*) AS n_rows,
  SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
  AND _loaded_at < TIMESTAMP("2026-07-19 00:00:00 UTC")
GROUP BY transaction_date
ORDER BY transaction_date
'

date -u
gcloud auth list
