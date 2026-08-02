#!/bin/bash
set -euo pipefail
SCRATCH="reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== reconstruction of check_drift() for every Saturday, 70d, core.fact_sales_profit ==="
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=json '
WITH daily AS (
  SELECT transaction_date AS d, SUM(revenue_kgs) AS rev
  FROM `msklad-bi-prod.core.fact_sales_profit`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE("Asia/Bishkek"), INTERVAL 70 DAY)
  GROUP BY d
),
saturdays AS (
  SELECT d, rev FROM daily WHERE EXTRACT(DAYOFWEEK FROM d) = 7
)
SELECT
  s.d AS saturday,
  s.rev AS saturday_rev,
  (SELECT AVG(rev) FROM daily WHERE d >= DATE_SUB(s.d, INTERVAL 7 DAY) AND d < s.d) AS ma7_prior,
  SAFE_DIVIDE(s.rev, (SELECT AVG(rev) FROM daily WHERE d >= DATE_SUB(s.d, INTERVAL 7 DAY) AND d < s.d)) AS ratio
FROM saturdays s
ORDER BY s.d
' > "$SCRATCH/step12_saturdays_bq.json" 2>"$SCRATCH/step12.err" || cat "$SCRATCH/step12.err"
cat "$SCRATCH/step12_saturdays_bq.json"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
