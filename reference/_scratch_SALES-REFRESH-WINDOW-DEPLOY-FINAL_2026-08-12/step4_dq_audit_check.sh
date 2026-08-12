#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

echo "=== audit.dq_runs: failed checks, last 6 hours ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT checked_at, run_id, check_name, passed, detail
FROM \`msklad-bi-prod.audit.dq_runs\`
WHERE checked_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 HOUR)
  AND passed = FALSE
ORDER BY checked_at DESC
"

echo "=== audit.dq_runs: full result set for most recent run_id ==="
bq query --use_legacy_sql=false --format=prettyjson "
WITH latest AS (
  SELECT run_id FROM \`msklad-bi-prod.audit.dq_runs\`
  ORDER BY checked_at DESC LIMIT 1
)
SELECT r.checked_at, r.check_name, r.passed, r.detail
FROM \`msklad-bi-prod.audit.dq_runs\` r, latest
WHERE r.run_id = latest.run_id
ORDER BY r.checked_at
"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
