#!/bin/bash
set -euo pipefail
SCRATCH="reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Cloud Monitoring alert policies (grep cf-alert / DQ / severity) ==="
gcloud alpha monitoring policies list --project=msklad-bi-prod --format=json \
  > "$SCRATCH/step3_monitoring_policies.json" 2>"$SCRATCH/step3_monitoring.err" || {
    echo "monitoring policies list FAILED"; cat "$SCRATCH/step3_monitoring.err"
  }
python3 -c "
import json
try:
    d = json.load(open('$SCRATCH/step3_monitoring_policies.json'))
    print('policy count:', len(d))
    for p in d:
        print('-', p.get('displayName'), '| notif channels:', p.get('notificationChannels'))
except Exception as e:
    print('parse error:', e)
"

echo "=== Cloud Logging sinks (look for cf-alert / pubsub destinations) ==="
gcloud logging sinks list --project=msklad-bi-prod --format=json \
  > "$SCRATCH/step3_logging_sinks.json" 2>"$SCRATCH/step3_sinks.err" || {
    echo "logging sinks list FAILED"; cat "$SCRATCH/step3_sinks.err"
  }
python3 -c "
import json
try:
    d = json.load(open('$SCRATCH/step3_logging_sinks.json'))
    print('sink count:', len(d))
    for s in d:
        print('-', s.get('name'), '->', s.get('destination'), '| filter:', s.get('filter',''))
except Exception as e:
    print('parse error:', e)
"

echo "=== Pub/Sub topics/subscriptions mentioning alert ==="
gcloud pubsub topics list --project=msklad-bi-prod --format=json > "$SCRATCH/step3_pubsub_topics.json" 2>"$SCRATCH/step3_pubsub.err" || {
    echo "pubsub topics list FAILED"; cat "$SCRATCH/step3_pubsub.err"
}
cat "$SCRATCH/step3_pubsub_topics.json"

echo "=== cf-alert trigger (event vs http) ==="
gcloud functions describe cf-alert --region=asia-east1 --gen2 --project=msklad-bi-prod --format=json \
  > "$SCRATCH/step3_cf_alert_describe.json" 2>"$SCRATCH/step3_cf_alert.err" || {
    echo "describe cf-alert FAILED"; cat "$SCRATCH/step3_cf_alert.err"
  }
python3 -c "
import json
try:
    d = json.load(open('$SCRATCH/step3_cf_alert_describe.json'))
    print('eventTrigger:', d.get('eventTrigger'))
    print('serviceConfig.ingressSettings:', d.get('serviceConfig',{}).get('ingressSettings'))
except Exception as e:
    print('parse error:', e)
"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
