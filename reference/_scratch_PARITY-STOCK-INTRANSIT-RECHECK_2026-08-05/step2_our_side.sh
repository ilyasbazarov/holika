#!/usr/bin/env bash
set -euo pipefail

SCRATCH="reference/_scratch_PARITY-STOCK-INTRANSIT-RECHECK_2026-08-05"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo "=== step2a: our side, mart filter verbatim from sq_marts_in_transit.sql:47-48 ==="
bq query --use_legacy_sql=false --format=prettyjson --max_rows=1000 \
  "SELECT COUNT(DISTINCT purchase_order_id) AS n_orders, COUNT(*) AS n_positions, ROUND(SUM(in_transit_sum_kgs), 2) AS sum_in_transit_kgs FROM \`msklad-bi-prod.core.fact_purchases\` WHERE status_name IN ('В пути','Прибыл частично') AND in_transit_sum_kgs > 0" \
  | tee "$SCRATCH/step2a_our_side_summary.json"

echo "=== step2b: our side rows (mart filter), full detail ==="
bq query --use_legacy_sql=false --format=prettyjson --max_rows=1000 \
  "SELECT purchase_order_id, order_name, position_id, product_id, status_name, quantity_in_transit, price_kgs, in_transit_sum_kgs FROM \`msklad-bi-prod.core.fact_purchases\` WHERE status_name IN ('В пути','Прибыл частично') AND in_transit_sum_kgs > 0 ORDER BY purchase_order_id, position_id" \
  > "$SCRATCH/step2b_our_side_rows.json"
python3 -c "import json; d=json.load(open('$SCRATCH/step2b_our_side_rows.json')); print('n_rows_detail =', len(d))"

echo "=== step2c: same status filter WITHOUT sum condition (status only) ==="
bq query --use_legacy_sql=false --format=prettyjson --max_rows=1000 \
  "SELECT COUNT(DISTINCT purchase_order_id) AS n_orders, COUNT(*) AS n_positions FROM \`msklad-bi-prod.core.fact_purchases\` WHERE status_name IN ('В пути','Прибыл частично')" \
  | tee "$SCRATCH/step2c_status_only.json"

echo "=== step2d: core vs marts.in_transit order-set symmetric diff (mart filter) ==="
bq query --use_legacy_sql=false --format=prettyjson --max_rows=1000 \
  "WITH core_orders AS (
     SELECT DISTINCT purchase_order_id FROM \`msklad-bi-prod.core.fact_purchases\`
     WHERE status_name IN ('В пути','Прибыл частично') AND in_transit_sum_kgs > 0
   ), mart_orders AS (
     SELECT DISTINCT purchase_order_id FROM \`msklad-bi-prod.marts.in_transit\`
   )
   SELECT
     (SELECT COUNT(*) FROM core_orders c WHERE c.purchase_order_id NOT IN (SELECT purchase_order_id FROM mart_orders)) AS in_core_not_mart,
     (SELECT COUNT(*) FROM mart_orders m WHERE m.purchase_order_id NOT IN (SELECT purchase_order_id FROM core_orders)) AS in_mart_not_core" \
  | tee "$SCRATCH/step2d_core_vs_mart_orderset.json"

echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u

echo "SCRATCH_PATH=$SCRATCH"
