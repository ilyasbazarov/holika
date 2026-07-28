#!/bin/bash
set -euo pipefail

echo "=== ANCHOR START ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR START END ==="

echo
echo "### Когда прод marts.expenses пересобирался в последний раз (задания DTS по transferConfig) ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT
  creation_time, end_time, state
FROM \`msklad-bi-prod.region-us\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 DAY)
  AND destination_table.dataset_id = 'marts'
  AND destination_table.table_id = 'expenses'
  AND state = 'DONE'
ORDER BY creation_time DESC
LIMIT 5"

echo
echo "### core.fact_payments: строки за июль-2026, разбивка по _loaded_at (после/до вчерашней сборки прода) ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT
  COUNTIF(_loaded_at < TIMESTAMP '2026-07-27 12:00:00 UTC') AS loaded_before,
  COUNTIF(_loaded_at >= TIMESTAMP '2026-07-27 12:00:00 UTC') AS loaded_after,
  COUNT(*) AS total
FROM \`msklad-bi-prod.core.fact_payments\`
WHERE moment >= DATE '2026-07-01'"

echo
echo "### core.fact_loss + core.fact_commissionreportin: строки за июль-2026, разбивка по _loaded_at ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT 'loss' AS src,
  COUNTIF(_loaded_at < TIMESTAMP '2026-07-27 12:00:00 UTC') AS loaded_before,
  COUNTIF(_loaded_at >= TIMESTAMP '2026-07-27 12:00:00 UTC') AS loaded_after,
  COUNT(*) AS total
FROM \`msklad-bi-prod.core.fact_loss\`
WHERE DATE(moment) >= DATE '2026-07-01'
UNION ALL
SELECT 'commission',
  COUNTIF(_loaded_at < TIMESTAMP '2026-07-27 12:00:00 UTC'),
  COUNTIF(_loaded_at >= TIMESTAMP '2026-07-27 12:00:00 UTC'),
  COUNT(*)
FROM \`msklad-bi-prod.core.fact_commissionreportin\`
WHERE DATE(moment) >= DATE '2026-07-01'"

echo
echo "=== ANCHOR END ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR END END ==="
