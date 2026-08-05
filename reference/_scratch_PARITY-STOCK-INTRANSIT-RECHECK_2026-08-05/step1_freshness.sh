#!/usr/bin/env bash
set -euo pipefail

SCRATCH="reference/_scratch_PARITY-STOCK-INTRANSIT-RECHECK_2026-08-05"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo "=== step1: freshness of core.fact_purchases ==="
bq query --use_legacy_sql=false --format=prettyjson --max_rows=10 \
  "SELECT MAX(_loaded_at) AS max_loaded_at, COUNT(DISTINCT purchase_order_id) AS n_orders, COUNT(*) AS n_rows, TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), MINUTE) AS minutes_since_load FROM \`msklad-bi-prod.core.fact_purchases\`" \
  | tee "$SCRATCH/step1_freshness.json"

echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u

echo "SCRATCH_PATH=$SCRATCH"
