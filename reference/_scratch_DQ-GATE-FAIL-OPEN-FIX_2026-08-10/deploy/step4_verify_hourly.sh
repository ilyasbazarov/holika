#!/usr/bin/env bash
# ADR-152 §5, условия 2 и 3 — проверка на первом плановом часовом прогоне после деплоя.
# Read-only, класс A. Ждёт наступления следующего часа UTC + запас на выполнение workflow,
# затем читает audit.dq_runs (не синтезирует результат, не запускает cf-dq вручную).
set -euo pipefail

DEPLOY_TIME_UTC="2026-08-10 14:42:35"

echo "=== UTC-якорь (начало) ==="
date -u
echo
echo "=== личность вызывающего (начало) ==="
gcloud auth list

echo
echo "=== ожидание планового часового прогона (0 * * * *) + запас 5 минут ==="
until [ "$(date -u +%H%M)" -ge "1505" ] || [ "$(date -u +%H)" -gt "15" ]; do
  sleep 30
done
echo "Условие ожидания выполнено: $(date -u)"

echo
echo "=== audit.dq_runs — прогоны ПОСЛЕ деплоя ($DEPLOY_TIME_UTC UTC) ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT run_id, check_name, passed, detail, checked_at
FROM \`msklad-bi-prod.audit.dq_runs\`
WHERE checked_at > TIMESTAMP('${DEPLOY_TIME_UTC} UTC')
ORDER BY checked_at ASC, check_name ASC
"

echo
echo "=== UTC-якорь (конец) ==="
date -u
echo
echo "=== личность вызывающего (конец) ==="
gcloud auth list
