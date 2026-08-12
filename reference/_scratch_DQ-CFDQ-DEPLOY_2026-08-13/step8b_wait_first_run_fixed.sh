#!/bin/bash
set -uo pipefail
BASELINE_RUN_ID="1786561202.3581266"
DEPLOY_UPDATE_TIME="2026-08-12 19:14:47.725221 UTC"
DEADLINE=$(( $(date -u +%s) + 90*60 ))
echo "=== date -u (start) ==="
date -u
echo "waiting for audit.dq_runs run_id != ${BASELINE_RUN_ID} with checked_at > deploy updateTime ${DEPLOY_UPDATE_TIME}"

while true; do
  NOW=$(date -u +%s)
  if [ "$NOW" -gt "$DEADLINE" ]; then
    echo "TIMEOUT: 90 minutes elapsed without a new run"
    exit 1
  fi
  ROWS=$(bq query --use_legacy_sql=false --format=csv \
    "SELECT DISTINCT run_id FROM \`msklad-bi-prod.audit.dq_runs\`
     WHERE checked_at > TIMESTAMP('${DEPLOY_UPDATE_TIME}')
       AND run_id != '${BASELINE_RUN_ID}'
     ORDER BY run_id LIMIT 5" 2>/dev/null | tail -n +2)
  if [ -n "$ROWS" ]; then
    echo "=== FOUND new run(s) ==="
    echo "$ROWS"
    break
  fi
  sleep 120
done

echo "=== date -u (end) ==="
date -u
