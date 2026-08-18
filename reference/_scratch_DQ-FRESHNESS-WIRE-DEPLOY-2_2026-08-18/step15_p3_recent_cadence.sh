#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "--- уникальные run_id за последние 6 часов, с числом проверок и временем в каждом ---"
bq query --use_legacy_sql=false --format=prettyjson --project_id=msklad-bi-prod '
SELECT run_id, MIN(checked_at) AS first_checked_at, MAX(checked_at) AS last_checked_at, COUNT(*) AS n_checks
FROM `msklad-bi-prod.audit.dq_runs`
WHERE checked_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 HOUR)
GROUP BY run_id
ORDER BY first_checked_at DESC
'

echo "--- детали самого свежего прогона ---"
bq query --use_legacy_sql=false --format=prettyjson --project_id=msklad-bi-prod '
SELECT check_name, passed, checked_at
FROM `msklad-bi-prod.audit.dq_runs`
WHERE checked_at = (SELECT MAX(checked_at) FROM `msklad-bi-prod.audit.dq_runs`)
   OR run_id = (SELECT run_id FROM `msklad-bi-prod.audit.dq_runs` ORDER BY checked_at DESC LIMIT 1)
ORDER BY check_name
'

echo "--- расписание Cloud Scheduler, задание hourly workflow (для cf-dq/workflow_hourly) ---"
gcloud scheduler jobs list --project=msklad-bi-prod --location=asia-east1 \
  --format="table(name,schedule,state,lastAttemptTime)" 2>&1 | grep -i "hourly\|dq" || \
  gcloud scheduler jobs list --project=msklad-bi-prod --location=asia-east1 \
  --format="table(name,schedule,state)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
