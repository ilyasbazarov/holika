#!/bin/bash
set -euo pipefail
date -u
gcloud auth list

echo "=== q3: employee names for the 4 owner IDs found in May raw demand bodies ==="
bq query --use_legacy_sql=false --format=prettyjson '
SELECT employee_id, full_name, position
FROM `msklad-bi-prod.core.dim_employees`
WHERE employee_id IN (
  "90ff70de-8162-11ef-0a80-0262000b020c",
  "013381e5-492d-11f1-0a80-144c001f5a3c",
  "de4c5757-4533-11f0-0a80-1aae0032c6f1",
  "1f9b9d60-fa31-11ee-0a80-08920071063a"
)
' > q3_owner_employee_names.json

echo "=== q4: our May revenue by manager (dim_counterparties.owner_employee_id), for comparison ==="
bq query --use_legacy_sql=false --format=prettyjson '
SELECT
  e.full_name AS manager_name,
  COUNT(*) AS row_count,
  ROUND(SUM(f.revenue_kgs), 2) AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit` f
LEFT JOIN `msklad-bi-prod.core.dim_counterparties` c
  ON f.agent_id = c.agent_id AND c.scd2_is_current = TRUE
LEFT JOIN `msklad-bi-prod.core.dim_employees` e
  ON c.owner_employee_id = e.employee_id
WHERE f.transaction_date BETWEEN "2026-05-01" AND "2026-05-31"
GROUP BY manager_name
ORDER BY revenue_kgs DESC
' > q4_our_may_by_manager.json

echo "=== q5: our May total revenue + doc count proxy (distinct agent_id count is not doc count, just for scale) ==="
bq query --use_legacy_sql=false --format=prettyjson '
SELECT COUNT(*) AS row_count, ROUND(SUM(revenue_kgs),2) AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-05-01" AND "2026-05-31"
' > q5_our_may_total.json

date -u
gcloud auth list
