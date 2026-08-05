#!/usr/bin/env bash
set -euo pipefail

SCRATCH="reference/_scratch_PARITY-STOCK-INTRANSIT-RECHECK_2026-08-05"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo "=== step5: our side, current status of four prior-tail orders (any status, no filter) ==="
bq query --use_legacy_sql=false --format=prettyjson --max_rows=100 \
  "SELECT purchase_order_id, order_name, status_name, COUNT(*) AS n_positions, ROUND(SUM(in_transit_sum_kgs),2) AS sum_in_transit_kgs, MAX(_loaded_at) AS max_loaded_at
   FROM \`msklad-bi-prod.core.fact_purchases\`
   WHERE purchase_order_id IN (
     '04a41f62-826b-11f1-0a80-14070015f6ec',
     'aab67ac6-e2d4-11f0-0a80-0fda0015d3cf',
     '08bfe70e-7b8b-11f1-0a80-03b8000e83b3',
     'e7d7a18b-81c6-11f1-0a80-0170000b1cc0'
   )
   GROUP BY purchase_order_id, order_name, status_name
   ORDER BY purchase_order_id" \
  | tee "$SCRATCH/step5_prior_tails_our_status.json"

echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u

echo "SCRATCH_PATH=$SCRATCH"
