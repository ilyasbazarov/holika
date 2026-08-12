#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

echo "=== 1) staging: current content for 2026-08-11 (Asia/Bishkek) ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  COUNT(*) AS n_rows,
  COUNT(DISTINCT demand_id) AS n_demands,
  SUM(revenue_kgs) AS total_rev,
  MIN(_loaded_at) AS min_loaded_at,
  MAX(_loaded_at) AS max_loaded_at
FROM \`msklad-bi-prod.stg_msklad.fact_sales_staging\`
WHERE DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek') = '2026-08-11'
"

echo "=== 2) staging: is 2026-08-11 within the rolling 7-day window today? ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT MIN(DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek')) AS min_date,
       MAX(DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek')) AS max_date,
       COUNT(*) AS n_rows
FROM \`msklad-bi-prod.stg_msklad.fact_sales_staging\`
"

echo "=== 3) core.fact_sales_profit: 2026-08-11 rows (post-restore state) ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS n_rows, SUM(revenue_kgs) AS total_rev
FROM \`msklad-bi-prod.core.fact_sales_profit\`
WHERE transaction_date = '2026-08-11'
"

echo "=== 4) МойСклад source: real document count for 2026-08-11 (Bishkek day, moment filter) ==="
TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)
RESP=$(curl -s --compressed -G "https://api.moysklad.ru/api/remap/1.2/entity/demand" \
  --data-urlencode "filter=moment>=2026-08-11 00:00:00;moment<=2026-08-11 23:59:59" \
  --data-urlencode "limit=100" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept-Encoding: gzip")
echo "$RESP" > source_aug11.json
python3 -c "
import json
d = json.load(open('source_aug11.json'))
meta = d.get('meta') or {}
print('meta_size (source doc count, filtered):', meta.get('size'))
print('rows returned this page:', len(d.get('rows', [])))
"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
