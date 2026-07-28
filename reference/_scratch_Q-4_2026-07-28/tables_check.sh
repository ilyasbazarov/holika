#!/bin/bash
set -euo pipefail
echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo "=== core.INFORMATION_SCHEMA.TABLES ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT table_name, table_type
FROM \`msklad-bi-prod\`.core.INFORMATION_SCHEMA.TABLES
ORDER BY table_name
"

echo "=== UTC anchor (end) ==="
date -u
echo "=== identity (end) ==="
gcloud auth list
