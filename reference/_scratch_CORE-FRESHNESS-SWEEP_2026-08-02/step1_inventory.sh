#!/bin/bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"
LOCATION="asia-east1"

for DS in core marts; do
  echo ""
  echo "=== __TABLES__ meta — dataset ${DS} (location ${LOCATION}): table_id, table_type, row_count, creation_time, last_modified_time ==="
  bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --format=prettyjson "
    SELECT
      table_id,
      CASE type WHEN 1 THEN 'TABLE' WHEN 2 THEN 'VIEW' ELSE CAST(type AS STRING) END AS table_type,
      row_count,
      TIMESTAMP_MILLIS(creation_time) AS creation_time,
      TIMESTAMP_MILLIS(last_modified_time) AS last_modified_time
    FROM \`${PROJECT}.${DS}.__TABLES__\`
    ORDER BY table_id
  "
done

echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
