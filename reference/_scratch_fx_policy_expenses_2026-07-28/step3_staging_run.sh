#!/bin/bash
set -euo pipefail

echo "=== ANCHOR START ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR START END ==="

echo
echo "### Прогон нового SQL в marts.expenses_staging (replace) ###"
bq query --use_legacy_sql=false \
  --destination_table=msklad-bi-prod:marts.expenses_staging \
  --replace \
  "$(cat sq_marts_expenses_new.sql)"

echo
echo "### Число строк в staging ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT COUNT(*) AS row_count FROM \`msklad-bi-prod.marts.expenses_staging\`"

echo
echo "=== ANCHOR END ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR END END ==="
