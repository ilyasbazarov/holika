#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  (SELECT ROUND(SUM(sell_sum_kgs),   2) FROM \`msklad-bi-prod.core.fact_sales_profit\`
     WHERE transaction_date BETWEEN '2026-05-01' AND '2026-05-31')       AS sales_sell_sum_kgs,
  (SELECT ROUND(SUM(revenue_kgs),    2) FROM \`msklad-bi-prod.core.fact_sales_profit\`
     WHERE transaction_date BETWEEN '2026-05-01' AND '2026-05-31')       AS sales_revenue_kgs,
  (SELECT ROUND(SUM(return_sum_kgs), 2) FROM \`msklad-bi-prod.core.fact_sales_profit\`
     WHERE transaction_date BETWEEN '2026-05-01' AND '2026-05-31')       AS sales_return_sum_kgs,
  (SELECT ROUND(SUM(sum_kgs),        2) FROM \`msklad-bi-prod.core.fact_returns\`
     WHERE return_date      BETWEEN '2026-05-01' AND '2026-05-31')       AS returns_sum_kgs
" 2>&1

gcloud auth list
date -u
