#!/bin/bash
set -euo pipefail
echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

for t in fact_purchases fact_returns fact_sales_profit fact_payments_stg fact_sales_profit_byvariant_backup; do
  echo "=== columns for core.$t ==="
  bq query --use_legacy_sql=false --format=prettyjson "
  SELECT table_name, column_name, data_type, is_nullable, ordinal_position
  FROM \`msklad-bi-prod\`.core.INFORMATION_SCHEMA.COLUMNS
  WHERE table_name = '$t'
  ORDER BY ordinal_position
  " || echo "QUERY_FAILED table=$t rc=$?"
done

echo "=== UTC anchor (end) ==="
date -u
echo "=== identity (end) ==="
gcloud auth list
