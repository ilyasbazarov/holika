#!/usr/bin/env bash
set -uo pipefail
echo "=== UTC anchor (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list
echo; echo "=== 1. Хвост журнала ПОСЛЕ MERGE — чем кончился прогон ==="
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="cf-finance" AND timestamp>="2026-08-18T18:47:30Z"' \
  --project=msklad-bi-prod --limit=25 --order=asc --format="value(timestamp, textPayload)" 2>&1 | head -25
echo; echo "=== 2. Схема core.fact_payments ==="
bq show --schema --format=prettyjson msklad-bi-prod:core.fact_payments 2>/dev/null | python3 -c "
import json,sys
for f in json.load(sys.stdin): print('   ', f['name'], f['type'])"
echo; echo "=== 3. Двадцать два помеченных платежа из журнала: что они такое в ядре ==="
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 20 '
SELECT COUNT(*) AS n_rows, MIN(moment) AS min_moment, MAX(moment) AS max_moment,
       ROUND(SUM(sum_kgs),2) AS sum_kgs_total
FROM `msklad-bi-prod.core.fact_payments`
WHERE payment_id IN (
 "59dce128-3221-11ef-0a80-0bad00b735cd","5c28da4a-7751-11ef-0a80-19220012d87d",
 "5fe687c1-7740-11ef-0a80-0089000f90fc","7d039868-3e12-11ef-0a80-02230032f1b8",
 "8239cc15-7754-11ef-0a80-14480013b158","8df7779f-7752-11ef-0a80-0f2800137ba3",
 "8e848b5d-7755-11ef-0a80-17e20014074c","954e8e74-7751-11ef-0a80-0ccb0012d10d",
 "9740cd50-7740-11ef-0a80-0ccb000eb05a","9ec3a499-7747-11ef-0a80-0ccb001064a5",
 "a1b3e871-7746-11ef-0a80-17e200107550","a35cf22f-7744-11ef-0a80-144800100102",
 "ab17009a-7755-11ef-0a80-13ce0013501f","adc72425-7754-11ef-0a80-04080014042f",
 "c135d9ea-7751-11ef-0a80-0f2800135391","d0223fef-7755-11ef-0a80-00890014b5cd",
 "d531f1a3-7754-11ef-0a80-192200138f39","d74e0089-7747-11ef-0a80-14480010b001",
 "e16508d7-7750-11ef-0a80-19220012bcd2","edba8045-7755-11ef-0a80-14480013fd29",
 "f1b34665-7751-11ef-0a80-11450013572d","f493c3b1-7754-11ef-0a80-10690013c5ab")'
echo "=== UTC anchor (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
