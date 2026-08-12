#!/usr/bin/env bash
set -euo pipefail

PROJECT="msklad-bi-prod"
DATASET="core"
TARGET="${PROJECT}.${DATASET}.fact_sales_profit"
SNAP="${PROJECT}.${DATASET}.fact_sales_profit_snap_20260811_163306"
ID1="786f54b87f1e81ecf04efead3ab59250"
ID2="8e05d4b486a48d5b018df201217eb7f3"

COLS="transaction_id, transaction_date, product_id, entity_type, agent_id, sell_quantity, return_quantity, revenue_kgs, cogs_kgs, margin_kgs, revenue_usd, cogs_usd, margin_usd, _week_start, _loaded_at, sell_sum_kgs, return_sum_kgs, discount, sales_channel_id, sales_channel_name, project_id, project_name, document_owner_employee_id"

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== INSERT: две строки из снимка в target ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson "
INSERT INTO \`${TARGET}\` (${COLS})
SELECT ${COLS}
FROM \`${SNAP}\`
WHERE transaction_id IN ('${ID1}', '${ID2}')
"

echo "=== date -u (end) ==="
date -u

echo "=== gcloud auth list (end) ==="
gcloud auth list
