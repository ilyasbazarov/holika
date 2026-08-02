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
  echo "=== COUNT(*) INFORMATION_SCHEMA.COLUMNS — dataset ${DS} ==="
  bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --format=prettyjson "
    SELECT COUNT(*) AS n_columns, COUNT(DISTINCT table_name) AS n_tables
    FROM \`${PROJECT}.${DS}.INFORMATION_SCHEMA.COLUMNS\`
  "
  echo "=== full dump, max_rows=10000 — dataset ${DS} ==="
  bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --max_rows=10000 --format=json "
    SELECT table_name, column_name, data_type, ordinal_position
    FROM \`${PROJECT}.${DS}.INFORMATION_SCHEMA.COLUMNS\`
    ORDER BY table_name, ordinal_position
  " > "columns_${DS}_full.json"
  echo "rows written to columns_${DS}_full.json: $(python3 -c "import json; print(len(json.load(open('columns_${DS}_full.json'))))")"
done

echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
