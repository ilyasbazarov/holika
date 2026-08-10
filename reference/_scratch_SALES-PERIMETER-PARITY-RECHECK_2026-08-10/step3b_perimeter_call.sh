#!/usr/bin/env bash
# Досев периметра: покрыть 2026-05-01..2026-08-07 (window_days=99 от даты прогона 2026-08-07).
# mode=perimeter пишет ТОЛЬКО в staging (stg_msklad.fact_sales_perimeter_staging).
set -uo pipefail

OUT="$(dirname "$0")"
echo "=== date -u (начало) ==="
date -u
echo "=== gcloud auth list (начало) ==="
gcloud auth list

echo "=== call cf-facts mode=perimeter window_days=99 ==="
gcloud functions call cf-facts \
  --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --data='{"mode":"perimeter","window_days":99,"run_id":"SALES-PERIMETER-PARITY-RECHECK_2026-08-10_perimeter"}'
CALL_RC=$?
echo "gcloud functions call rc=${CALL_RC} (timeout клиента при успехе сервера — известная ловушка, не факт провала)"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
