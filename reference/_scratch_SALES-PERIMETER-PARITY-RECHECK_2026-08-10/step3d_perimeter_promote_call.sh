#!/usr/bin/env bash
# MERGE staging -> core.fact_sales_profit, window_days=99 (подтверждено владельцем отдельно).
set -uo pipefail
OUT="$(dirname "$0")"
echo "=== date -u (начало) ==="
date -u
echo "=== gcloud auth list (начало) ==="
gcloud auth list

echo "=== call cf-facts mode=perimeter_promote window_days=99 ==="
gcloud functions call cf-facts \
  --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --data='{"mode":"perimeter_promote","window_days":99}'
CALL_RC=$?
echo "gcloud functions call rc=${CALL_RC}"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
