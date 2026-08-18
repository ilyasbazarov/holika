#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/../.."

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

OUT_DIR="reference/_scratch_MARTS-STAMP-WEIGHTFLOW_2026-08-18"

echo "=== bq show (схема таблицы) ==="
bq show --format=prettyjson msklad-bi-prod:marts.weight_flow > "${OUT_DIR}/table_schema_2026-08-18.json" 2> "${OUT_DIR}/table_schema_2026-08-18.err"
echo "rc=$?"
python3 -c "
import json
d = json.load(open('${OUT_DIR}/table_schema_2026-08-18.json'))
fields = [f['name'] for f in d['schema']['fields']]
print('колонки:', fields)
print('_marts_built_at в схеме:', '_marts_built_at' in fields)
print('_source_max_loaded_at в схеме:', '_source_max_loaded_at' in fields)
"

echo "=== bq query: непустота и значения двух колонок ==="
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson "
SELECT
  COUNT(*) AS total_rows,
  COUNTIF(_marts_built_at IS NOT NULL) AS built_at_nonnull,
  COUNTIF(_source_max_loaded_at IS NOT NULL) AS source_loaded_nonnull,
  MIN(_marts_built_at) AS min_built_at,
  MAX(_marts_built_at) AS max_built_at,
  MIN(_source_max_loaded_at) AS min_source_loaded,
  MAX(_source_max_loaded_at) AS max_source_loaded
FROM \`msklad-bi-prod.marts.weight_flow\`
" > "${OUT_DIR}/data_check_2026-08-18.json" 2> "${OUT_DIR}/data_check_2026-08-18.err"
echo "rc=$?"
cat "${OUT_DIR}/data_check_2026-08-18.json"
cat "${OUT_DIR}/data_check_2026-08-18.err"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
