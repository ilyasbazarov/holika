#!/usr/bin/env bash
# Read-only: подтвердить, что сервер отработал успешно, несмотря на клиентский ReadTimeout.
set -uo pipefail
OUT="$(dirname "$0")"
echo "=== date -u (начало) ==="
date -u
echo "=== gcloud auth list (начало) ==="
gcloud auth list

echo "=== httpRequest-лог cf-facts с 2026-08-10T11:46:00Z ==="
gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-facts"
logName="projects/msklad-bi-prod/logs/run.googleapis.com%2Frequests"
timestamp>="2026-08-10T11:46:00Z"
' --project=msklad-bi-prod --format=json --limit=10 --order=asc > "$OUT/step3c_httprequest_log.json"
cat "$OUT/step3c_httprequest_log.json"

echo "=== текстовые логи функции (успех/ошибка) с того же момента ==="
gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-facts"
timestamp>="2026-08-10T11:46:00Z"
severity>=DEFAULT
' --project=msklad-bi-prod --format=json --limit=50 --order=asc > "$OUT/step3c_textlog.json"
cat "$OUT/step3c_textlog.json"

echo "=== staging: stg_msklad.fact_sales_perimeter_staging, run_id этого прогона ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT source_doc_type, run_id, MIN(_loaded_at) AS loaded_at, COUNT(*) AS row_count,
       COUNT(DISTINCT doc_id) AS doc_count,
       ROUND(SUM(revenue_kgs),2) AS revenue_sum_kgs,
       MIN(transaction_date_raw) AS min_date, MAX(transaction_date_raw) AS max_date
FROM \`msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging\`
WHERE run_id = 'SALES-PERIMETER-PARITY-RECHECK_2026-08-10_perimeter'
GROUP BY source_doc_type, run_id
" > "$OUT/step3c_staging_by_run.json"
cat "$OUT/step3c_staging_by_run.json"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
