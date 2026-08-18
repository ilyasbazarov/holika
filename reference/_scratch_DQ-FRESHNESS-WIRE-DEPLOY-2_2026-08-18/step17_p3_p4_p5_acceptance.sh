#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ID="1787011202.5458951"

echo "=== Пункт приёмки 3: список имён 19 проверок первого естественного прогона ($RUN_ID) ==="
bq query --use_legacy_sql=false --format=prettyjson --project_id=msklad-bi-prod "
SELECT check_name, passed, checked_at
FROM \`msklad-bi-prod.audit.dq_runs\`
WHERE run_id = '$RUN_ID'
ORDER BY check_name
" | tee "$SCRATCH_DIR/step17_run_detail.json"

echo "=== число проверок в этом прогоне ==="
bq query --use_legacy_sql=false --format=csv --project_id=msklad-bi-prod "
SELECT COUNT(*) FROM \`msklad-bi-prod.audit.dq_runs\` WHERE run_id = '$RUN_ID'
"

echo "=== Пункт приёмки 4: шесть блокирующих проверок — все passed=true? ==="
bq query --use_legacy_sql=false --format=prettyjson --project_id=msklad-bi-prod "
SELECT check_name, passed
FROM \`msklad-bi-prod.audit.dq_runs\`
WHERE run_id = '$RUN_ID'
  AND check_name IN ('not_empty','drift_check','drift_zero_docs','fk_integrity','freshness','currency_normalization')
ORDER BY check_name
"

echo "=== Пункт приёмки 5: двенадцать freshness_* — ни одного passed=false? ==="
bq query --use_legacy_sql=false --format=prettyjson --project_id=msklad-bi-prod "
SELECT check_name, passed
FROM \`msklad-bi-prod.audit.dq_runs\`
WHERE run_id = '$RUN_ID'
  AND check_name LIKE 'freshness_%'
ORDER BY check_name
"

echo "=== контроль: есть ли ХОТЬ ОДНА passed=false во всём прогоне ==="
bq query --use_legacy_sql=false --format=csv --project_id=msklad-bi-prod "
SELECT COUNT(*) FROM \`msklad-bi-prod.audit.dq_runs\` WHERE run_id = '$RUN_ID' AND passed = false
"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
