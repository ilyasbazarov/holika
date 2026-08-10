#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod

echo "=== explicit COUNT (not GROUP BY) for purchases order_date 2026-07-30..2026-08-05 ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS n FROM \`$PROJECT.core.fact_purchases\`
WHERE order_date BETWEEN '2026-07-30' AND '2026-08-05'
"

echo "=== explicit COUNT for returns return_date 2026-07-28..2026-08-05 ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS n FROM \`$PROJECT.core.fact_returns\`
WHERE return_date BETWEEN '2026-07-28' AND '2026-08-05'
"

echo "=== fact_purchases order_date full distribution, last 30 days, explicit per-day (LEFT JOIN against a date spine to force zero rows to print) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT d AS order_date, COUNTIF(p.order_date IS NOT NULL) AS n
FROM UNNEST(GENERATE_DATE_ARRAY('2026-07-25','2026-08-10')) AS d
LEFT JOIN \`$PROJECT.core.fact_purchases\` p ON p.order_date = d
GROUP BY d ORDER BY d
"

echo "=== second returns load job (11:14:59) — investigate trigger: any weekly executions or manual calls around that time ==="
gcloud logging read '
  resource.type="workflows.googleapis.com/Workflow"
  AND timestamp>="2026-08-09T10:50:00Z"
  AND timestamp<="2026-08-09T11:30:00Z"
' --project="$PROJECT" --format="value(timestamp, resource.labels.workflow_id, severity, textPayload)" --limit=50 --order=asc

date -u
gcloud auth list 2>&1
