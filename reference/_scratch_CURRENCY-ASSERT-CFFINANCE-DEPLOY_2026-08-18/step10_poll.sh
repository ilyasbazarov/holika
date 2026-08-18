#!/usr/bin/env bash
set -uo pipefail
echo "=== UTC anchor (start) ==="; date -u
for i in $(seq 1 20); do
  R=$(bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=csv -n 10 \
      'SELECT COUNT(*), MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_payments`' 2>/dev/null | tail -1)
  echo "$(date -u +%H:%M:%SZ) попытка $i: $R"
  case "$R" in
    *2026-08-18*) echo "ЗАГРУЗКА ПРОШЛА — _loaded_at обновился"; break;;
  esac
  sleep 60
done
echo "=== хвост журнала cf-finance ==="
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="cf-finance" AND timestamp>="2026-08-18T18:33:00Z"' \
  --project=msklad-bi-prod --limit=40 --order=asc --format="value(timestamp, severity, textPayload)" 2>&1 | tail -25
echo "=== UTC anchor (end) ==="; date -u
