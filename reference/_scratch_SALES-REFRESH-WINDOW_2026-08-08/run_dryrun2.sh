#!/bin/bash
set -uo pipefail
echo "=== UTC anchor (start) ==="
date -u
echo "=== caller identity (start) ==="
gcloud auth list

for name in hourly weekly perimeter; do
  echo ""
  echo "=== dry_run: merge_sql_${name}.sql ==="
  bq query --nouse_legacy_sql --dry_run --project_id=msklad-bi-prod < "merge_sql_${name}.sql"
  echo "--- exit code: $? ---"
done

echo "=== UTC anchor (end) ==="
date -u
echo "=== caller identity (end) ==="
gcloud auth list
