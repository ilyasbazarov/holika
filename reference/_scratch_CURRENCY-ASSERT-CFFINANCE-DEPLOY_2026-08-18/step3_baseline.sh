#!/usr/bin/env bash
set -uo pipefail
echo "=== UTC anchor (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list
echo; echo "=== Базовое состояние core.fact_payments ДО выкладки (read-only) ==="
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 10 '
SELECT COUNT(*) AS n_rows,
       MAX(_loaded_at) AS max_loaded_at,
       MAX(moment) AS max_moment
FROM `msklad-bi-prod.core.fact_payments`'
echo "=== UTC anchor (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
