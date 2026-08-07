#!/usr/bin/env bash
set -uo pipefail

DEADLINE=$(( $(date -u +%s) + 360 ))
FOUND=0
while [ "$(date -u +%s)" -lt "${DEADLINE}" ]; do
  COUNT="$(gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-facts"
logName="projects/msklad-bi-prod/logs/run.googleapis.com%2Frequests"
timestamp>="2026-08-07T09:19:00Z"
' --project=msklad-bi-prod --format="value(timestamp)" --limit=10 2>/dev/null | wc -l | tr -d ' ')"
  echo "$(date -u +%FT%TZ) poll: completed-request-entries=${COUNT}"
  if [ "${COUNT}" -gt 0 ]; then
    FOUND=1
    break
  fi
  sleep 20
done

if [ "${FOUND}" -eq 1 ]; then
  echo "=== FOUND completion, full entry ==="
  gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-facts"
logName="projects/msklad-bi-prod/logs/run.googleapis.com%2Frequests"
timestamp>="2026-08-07T09:19:00Z"
' --project=msklad-bi-prod --format=json --limit=10 --order=asc
else
  echo "=== NOT FOUND within deadline ==="
fi
