#!/usr/bin/env bash
set -euo pipefail

SCRATCH="reference/_scratch_PURCHASES-INTRANSIT-RECHECK-VERIFY_2026-08-09"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo "=== step1a: freshness core.fact_purchases ==="
bq query --use_legacy_sql=false --format=prettyjson --max_rows=10 \
  "SELECT MAX(_loaded_at) AS max_loaded_at, COUNT(DISTINCT purchase_order_id) AS n_orders, COUNT(*) AS n_rows FROM \`msklad-bi-prod.core.fact_purchases\`" \
  | tee "$SCRATCH/step1a_freshness.json"

echo "=== step1b: our side, mart filter verbatim from sq_marts_in_transit.sql (same filter as PARITY-STOCK-INTRANSIT-RECHECK step2a) ==="
bq query --use_legacy_sql=false --format=prettyjson --max_rows=1000 \
  "SELECT COUNT(DISTINCT purchase_order_id) AS n_orders, COUNT(*) AS n_positions, ROUND(SUM(in_transit_sum_kgs), 2) AS sum_in_transit_kgs FROM \`msklad-bi-prod.core.fact_purchases\` WHERE status_name IN ('В пути','Прибыл частично') AND in_transit_sum_kgs > 0" \
  | tee "$SCRATCH/step1b_our_side_summary.json"

echo "=== step1c: our side rows (mart filter), full detail — same query as PARITY-STOCK-INTRANSIT-RECHECK step2b ==="
bq query --use_legacy_sql=false --format=prettyjson --max_rows=1000 \
  "SELECT purchase_order_id, order_name, position_id, product_id, status_name, quantity_in_transit, price_kgs, in_transit_sum_kgs FROM \`msklad-bi-prod.core.fact_purchases\` WHERE status_name IN ('В пути','Прибыл частично') AND in_transit_sum_kgs > 0 ORDER BY purchase_order_id, position_id" \
  > "$SCRATCH/step1c_our_side_rows.json"
python3 -c "import json; d=json.load(open('$SCRATCH/step1c_our_side_rows.json')); print('n_rows_detail =', len(d))"

echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u

echo "SCRATCH_PATH=$SCRATCH"
