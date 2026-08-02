#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Cloud Logging: workflow msklad-pipeline-weekly вокруг 2026-07-26T01:00-01:10Z (первый отказ) ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id="msklad-pipeline-weekly"
timestamp>="2026-07-26T00:59:00Z"
timestamp<="2026-07-26T01:10:00Z"
' --format=json --order=asc --limit=200

echo "=== Cloud Logging: workflow msklad-pipeline-weekly вокруг 2026-08-02T01:00-01:10Z (сегодняшний отказ) ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id="msklad-pipeline-weekly"
timestamp>="2026-08-02T00:59:00Z"
timestamp<="2026-08-02T01:10:00Z"
' --format=json --order=asc --limit=200

echo "=== Проверка: сработал ли weekly СЕГОДНЯ (2026-08-02) вообще — задания BQ с целью fact_returns за последние 24ч ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT job_id, creation_time, end_time, state, error_result.reason AS error_reason, error_result.message AS error_message
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND destination_table.table_id = 'fact_returns'
ORDER BY creation_time ASC
"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
