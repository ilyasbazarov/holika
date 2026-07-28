#!/bin/bash
set -euo pipefail
echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo "=== INFORMATION_SCHEMA.COLUMNS dump ==="
bq query --use_legacy_sql=false --format=prettyjson '
SELECT table_schema, table_name, column_name, data_type, is_nullable, ordinal_position
FROM `msklad-bi-prod`.`region-asia-east1`.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema IN ("core", "marts", "audit", "stg_msklad")
ORDER BY table_schema, table_name, ordinal_position
'

echo "=== UTC anchor (end) ==="
date -u
echo "=== identity (end) ==="
gcloud auth list
