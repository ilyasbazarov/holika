#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

echo "=== traffic status (confirm still on cf-facts-00017-jon) ==="
gcloud run services describe cf-facts --region=asia-east1 --project=msklad-bi-prod --format="value(status.traffic)"

echo "=== Cloud Logging: PAGINATE_PROBE lines since traffic switch (2026-08-12T15:17:45Z) ==="
gcloud logging read \
  'resource.type="cloud_run_revision" resource.labels.service_name="cf-facts" resource.labels.revision_name="cf-facts-00017-jon" textPayload:"PAGINATE_PROBE"' \
  --project=msklad-bi-prod \
  --freshness=2h \
  --format="value(timestamp,textPayload)" \
  --order=asc > paginate_probe_lines.txt
echo "count of PAGINATE_PROBE lines:"
wc -l < paginate_probe_lines.txt
echo "--- lines ---"
cat paginate_probe_lines.txt
echo "--- lines with has_filter=true ---"
grep -c "has_filter=True" paginate_probe_lines.txt || true

echo "=== Cloud Logging: any PAGINATE_PROBE FAILED / fetched<meta_size ==="
gcloud logging read \
  'resource.type="cloud_run_revision" resource.labels.service_name="cf-facts" resource.labels.revision_name="cf-facts-00017-jon" (textPayload:"PAGINATE_PROBE FAILED" OR textPayload:"RuntimeError")' \
  --project=msklad-bi-prod \
  --freshness=2h \
  --format="value(timestamp,textPayload)" > paginate_probe_failed.txt
echo "count of FAILED lines:"
wc -l < paginate_probe_failed.txt
cat paginate_probe_failed.txt

echo "=== Cloud Logging: execution status of hourly runs since switch ==="
gcloud logging read \
  'resource.type="cloud_run_revision" resource.labels.service_name="cf-facts" resource.labels.revision_name="cf-facts-00017-jon"' \
  --project=msklad-bi-prod \
  --freshness=2h \
  --format="value(timestamp,severity,textPayload)" \
  --order=asc > all_lines_00017.txt
echo "total log lines for cf-facts-00017-jon:"
wc -l < all_lines_00017.txt
echo "severity ERROR count:"
grep -c '^.*ERROR' all_lines_00017.txt || true

echo "=== BigQuery: fact_sales_profit row count vs snap_20260811_163306, since traffic switch ==="
bq query --use_legacy_sql=false --format=json "
SELECT COUNT(*) AS missing_from_live
FROM \`msklad-bi-prod.core.fact_sales_profit_snap_20260811_163306\` s
LEFT JOIN \`msklad-bi-prod.core.fact_sales_profit\` l USING (transaction_id)
WHERE l.transaction_id IS NULL
" > snap_diff.json
cat snap_diff.json

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
