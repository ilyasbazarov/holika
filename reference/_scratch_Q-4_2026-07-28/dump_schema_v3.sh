#!/bin/bash
set -euo pipefail
echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

for ds in core marts audit stg_msklad; do
  echo "=== dataset: $ds ==="
  bq query --use_legacy_sql=false --format=prettyjson --max_rows=100000 "
  SELECT table_schema, table_name, column_name, data_type, is_nullable, ordinal_position
  FROM \`msklad-bi-prod\`.${ds}.INFORMATION_SCHEMA.COLUMNS
  ORDER BY table_name, ordinal_position
  "
done

echo "=== UTC anchor (end) ==="
date -u
echo "=== identity (end) ==="
gcloud auth list
