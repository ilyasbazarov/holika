#!/bin/bash
set -uo pipefail
BASELINE_TS="2026-08-12 19:02:14"
DEADLINE=$(( $(date -u +%s) + 90*60 ))
echo "=== date -u (start) ==="
date -u
echo "waiting for first audit.dq_runs entry with checked_at > ${BASELINE_TS} UTC (post-deploy 19:14:47Z)"

while true; do
  NOW=$(date -u +%s)
  if [ "$NOW" -gt "$DEADLINE" ]; then
    echo "TIMEOUT: 90 minutes elapsed without a new run"
    exit 1
  fi
  ROWS=$(bq query --use_legacy_sql=false --format=csv \
    "SELECT DISTINCT run_id FROM \`msklad-bi-prod.audit.dq_runs\` WHERE checked_at > TIMESTAMP('${BASELINE_TS} UTC') ORDER BY run_id LIMIT 5" 2>/dev/null | tail -n +2)
  if [ -n "$ROWS" ]; then
    echo "=== FOUND new run(s) ==="
    echo "$ROWS"
    break
  fi
  sleep 120
done

echo "=== date -u (end) ==="
date -u
