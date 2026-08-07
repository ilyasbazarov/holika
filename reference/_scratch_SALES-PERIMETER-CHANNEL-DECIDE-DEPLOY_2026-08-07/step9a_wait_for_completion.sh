#!/bin/bash
set -uo pipefail

DEADLINE=$(( $(date -u +%s) + 480 ))
FOUND=0
while [ "$(date -u +%s)" -lt "${DEADLINE}" ]; do
  COUNT="$(bq query --use_legacy_sql=false --format=csv --project_id=msklad-bi-prod '
SELECT COUNT(*) FROM `msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging`
WHERE run_id = "verify_deploy_2026-08-07_channel_perimeter"
' 2>/dev/null | tail -1)"
  echo "$(date -u +%FT%TZ) poll: staging_row_count=${COUNT}"
  if [ -n "${COUNT}" ] && [ "${COUNT}" != "0" ]; then
    FOUND=1
    break
  fi
  sleep 20
done

if [ "${FOUND}" -eq 1 ]; then
  echo "=== FOUND rows in staging ==="
else
  echo "=== NOT FOUND within deadline (480s) ==="
fi
