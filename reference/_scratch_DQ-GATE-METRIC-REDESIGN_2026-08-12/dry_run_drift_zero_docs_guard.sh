#!/bin/bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== dry_run: ma7 (T-8..T-2) — используется внутри target_rev==0 различителя ==="
bq query --use_legacy_sql=false --dry_run '
SELECT COALESCE(AVG(daily_rev),0) FROM (
    SELECT transaction_date, SUM(revenue_kgs) AS daily_rev
    FROM `msklad-bi-prod.core.fact_sales_profit`
    WHERE transaction_date >= DATE_SUB(CURRENT_DATE("Asia/Bishkek"), INTERVAL 8 DAY)
      AND transaction_date  <  DATE_SUB(CURRENT_DATE("Asia/Bishkek"), INTERVAL 1 DAY)
    GROUP BY 1)
'

echo "=== dry_run: COUNT(*) core.fact_sales_profit — used как ever_had_data ==="
bq query --use_legacy_sql=false --dry_run '
SELECT COUNT(*) FROM `msklad-bi-prod.core.fact_sales_profit`
'

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== date -u (end) ==="
date -u
