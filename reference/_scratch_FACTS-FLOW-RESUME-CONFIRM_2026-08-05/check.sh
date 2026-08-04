#!/usr/bin/env bash
# FACTS-FLOW-RESUME-CONFIRM · контрольная точка ADR-121 §7 — read-only проверка,
# появились ли строки 2026-08-01…2026-08-04 в core.fact_sales_profit и сдвинулся ли
# MAX(_loaded_at) относительно замера FACTS-FLOW-RESTORE-ADJ (2026-08-04T07:41…07:49Z).
# Класс A: только read-only bq query/bq show, секретов нет, живых вызовов к МойСкладу нет.
set -uo pipefail
PROJECT=msklad-bi-prod

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo
echo "=== step0: схема core.fact_sales_profit — подтвердить наличие колонки _loaded_at ==="
bq show --project_id="$PROJECT" --format=prettyjson "${PROJECT}:core.fact_sales_profit" \
  | grep -A2 '"name"'

echo
echo "=== query1: присутствие строк 2026-08-01..2026-08-04 в core.fact_sales_profit ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=100 '
SELECT transaction_date, COUNT(*) AS n_rows, ROUND(SUM(revenue_kgs), 2) AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-08-01" AND "2026-08-04"
GROUP BY transaction_date
ORDER BY transaction_date
'

echo
echo "=== query2: сдвиг MAX(_loaded_at) относительно замера FACTS-FLOW-RESTORE-ADJ (2026-08-04T07:41:07Z) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=10 '
SELECT MAX(_loaded_at) AS max_loaded_at, COUNT(DISTINCT _loaded_at) AS n_distinct_loaded_at
FROM `msklad-bi-prod.core.fact_sales_profit`
'

echo
echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u
echo "SCRATCH_PATH=reference/_scratch_FACTS-FLOW-RESUME-CONFIRM_2026-08-05"
