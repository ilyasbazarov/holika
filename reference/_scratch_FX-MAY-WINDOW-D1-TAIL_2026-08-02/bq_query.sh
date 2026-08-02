#!/bin/bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== query ==="
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson \
"SELECT date, rate_kgs_per_usd FROM \`msklad-bi-prod.core.dim_fx_rates\` WHERE date BETWEEN '2026-05-11' AND '2026-06-02' ORDER BY date"
echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list --filter=status:ACTIVE --format='value(account)'
