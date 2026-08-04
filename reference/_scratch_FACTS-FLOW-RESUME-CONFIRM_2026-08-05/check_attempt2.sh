#!/usr/bin/env bash
# FACTS-FLOW-RESUME-CONFIRM · попытка 2 (первая была преждевременной, ADR-121 §7).
# Контрольная точка ADR-121 §5: появились ли строки 2026-08-01…2026-08-04 в
# core.fact_sales_profit и сдвинулся ли MAX(_loaded_at) на прогоне 2026-08-04T18:00:02Z.
# Класс A: только read-only bq query / gcloud workflows executions list.
# Секретов нет, живых вызовов к МойСкладу нет, записи нет нигде.
set -uo pipefail
PROJECT=msklad-bi-prod
REGION=asia-east1
WORKFLOW=msklad-pipeline-hourly

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo
echo "=== step0: предусловие — текущее время ПОСЛЕ ожидаемого прогона 2026-08-04T18:00:02Z ==="
echo "Это ровно то, на чём сорвалась попытка 1 (запущена 09:03Z, до прогона)."
NOW_EPOCH=$(date -u +%s)
RUN_EPOCH=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "2026-08-04T18:00:02Z" +%s 2>/dev/null \
            || date -u -d "2026-08-04T18:00:02Z" +%s)
echo "now_epoch=$NOW_EPOCH  run_epoch=$RUN_EPOCH  delta_sec=$((NOW_EPOCH-RUN_EPOCH))"
if [ "$NOW_EPOCH" -le "$RUN_EPOCH" ]; then
  echo "ПРЕДУСЛОВИЕ НЕ ВЫПОЛНЕНО: замер преждевременен, вердикт не выносится."
else
  echo "предусловие выполнено: прогон уже состоялся по времени"
fi

echo
echo "=== step1: присутствие строк 2026-08-01..2026-08-04 в core.fact_sales_profit ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=100 '
SELECT transaction_date, COUNT(*) AS n_rows, ROUND(SUM(revenue_kgs), 2) AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-08-01" AND "2026-08-04"
GROUP BY transaction_date
ORDER BY transaction_date
'

echo
echo "=== step2: сдвиг MAX(_loaded_at) (замер FACTS-FLOW-RESTORE-ADJ давал 2026-08-01 17:02:14) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=10 '
SELECT MAX(_loaded_at) AS max_loaded_at,
       COUNT(DISTINCT _loaded_at) AS n_distinct_loaded_at,
       COUNT(*) AS n_rows_total
FROM `msklad-bi-prod.core.fact_sales_profit`
'

echo
echo "=== step3: состояние прогонов hourly-конвейера (расширение сверх буквы строки задачи) ==="
echo "Мотив: при отрицательном исходе step1 нужно различить «гейт снова заблокировал»"
echo "и «прогон ещё идёт» — иначе отрицательный вердикт снова окажется неинтерпретируемым."
gcloud workflows executions list "$WORKFLOW" \
  --project="$PROJECT" --location="$REGION" \
  --format="table(name.basename(), state, startTime, endTime)" \
  --limit=6

echo
echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u
echo "SCRATCH_PATH=reference/_scratch_FACTS-FLOW-RESUME-CONFIRM_2026-08-05"
