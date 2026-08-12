#!/usr/bin/env bash
set -euo pipefail

date -u
gcloud auth list

echo "=== read-back 3: core.fact_sales_profit vs snap_20260811_163306, after first natural hourly run, by channel ==="
bq query --use_legacy_sql=false --project_id=msklad-bi-prod --format=prettyjson '
SELECT
  s.sales_channel_id,
  COUNT(*) AS missing_from_live
FROM `msklad-bi-prod.core.fact_sales_profit_snap_20260811_163306` s
LEFT JOIN `msklad-bi-prod.core.fact_sales_profit` l
  USING (transaction_id)
WHERE l.transaction_id IS NULL
GROUP BY s.sales_channel_id
ORDER BY s.sales_channel_id
'

echo "=== total missing_from_live (expected: still 36, zero new since step2) ==="
bq query --use_legacy_sql=false --project_id=msklad-bi-prod --format=prettyjson '
SELECT COUNT(*) AS total_missing_from_live
FROM `msklad-bi-prod.core.fact_sales_profit_snap_20260811_163306` s
LEFT JOIN `msklad-bi-prod.core.fact_sales_profit` l
  USING (transaction_id)
WHERE l.transaction_id IS NULL
'

echo "=== cf-facts traffic status (confirm still on cf-facts-00011-mab) ==="
gcloud run services describe cf-facts \
  --region=asia-east1 --project=msklad-bi-prod \
  --format="table(status.traffic.revisionName, status.traffic.percent)"

echo "=== Cloud Logging: which revision served cf-facts requests since traffic switch (2026-08-12T07:52:38Z) ==="
gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-facts"
timestamp>="2026-08-12T07:52:38Z"
' \
  --project=msklad-bi-prod --limit=1000 --format=json \
  | python3 -c "
import json, sys
entries = json.load(sys.stdin)
revs = {}
for e in entries:
    r = e.get('resource', {}).get('labels', {}).get('revision_name', 'UNKNOWN')
    revs[r] = revs.get(r, 0) + 1
print('revision_name counts since traffic switch:')
for r, c in sorted(revs.items()):
    print(f'  {r}: {c}')
"

date -u
gcloud auth list
