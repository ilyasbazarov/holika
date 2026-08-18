#!/usr/bin/env bash
set -uo pipefail

DEPLOY_TIME_UTC="2026-08-17 23:07:53"
echo "poll: ожидание первого естественного прогона ПОСЛЕ деплоя ($DEPLOY_TIME_UTC UTC)"

while true; do
  NOW=$(date -u +"%Y-%m-%d %H:%M:%S")
  RESULT=$(bq query --use_legacy_sql=false --format=json --project_id=msklad-bi-prod \
    "SELECT run_id, MIN(checked_at) AS first_checked_at, COUNT(*) AS n_checks
     FROM \`msklad-bi-prod.audit.dq_runs\`
     WHERE checked_at > TIMESTAMP('$DEPLOY_TIME_UTC')
     GROUP BY run_id
     ORDER BY first_checked_at ASC
     LIMIT 1" 2>/dev/null)

  if [ -n "$RESULT" ] && [ "$RESULT" != "[]" ]; then
    echo "$NOW poll: НАЙДЕН прогон после деплоя: $RESULT"
    break
  else
    echo "$NOW poll: пока нет прогона после деплоя, жду..."
  fi
  sleep 90
done
