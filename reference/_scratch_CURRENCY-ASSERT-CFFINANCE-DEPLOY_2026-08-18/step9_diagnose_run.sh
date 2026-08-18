#!/usr/bin/env bash
set -uo pipefail
echo "=== UTC anchor (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list
echo; echo "=== READ-ONLY 1. Состояние core.fact_payments после вызова ==="
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 10 '
SELECT COUNT(*) AS n_rows, MAX(_loaded_at) AS max_loaded_at, MAX(moment) AS max_moment
FROM `msklad-bi-prod.core.fact_payments`'
echo; echo "=== READ-ONLY 2. Журнал cf-finance за последний час (последние 30 записей) ==="
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="cf-finance" AND timestamp>="2026-08-18T18:30:00Z"' \
  --project=msklad-bi-prod --limit=30 --order=asc \
  --format="table(timestamp, severity, textPayload)" 2>&1 | head -40
echo "=== UTC anchor (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
