#!/bin/bash
# Повторный read-only bq dry_run по прямой просьбе архитектора (второй ответ адъюдикации,
# правка верхнего края допуском). Текст SQL-запроса НЕ изменился со второго коммита
# (v2, guard_dryrun_v2.sh) — правка чисто в питоновском сравнении (freshness_floor - допуск).
# Прогоняется всё равно, для полноты, как явно запрошено.
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"
PARSE_DATE="DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek')"

for TABLE in "stg_msklad.fact_sales_staging" "stg_msklad.fact_sales_perimeter_staging"; do
  echo "=== dry_run: guard SELECT против ${TABLE} ==="
  bq query --project_id="$PROJECT" --nouse_legacy_sql --dry_run \
    "SELECT
       MIN(${PARSE_DATE}) AS min_date,
       MAX(${PARSE_DATE}) AS max_date,
       DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AS window_start,
       DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)  AS freshness_floor
     FROM \`${PROJECT}.${TABLE}\` s"
done

echo "=== live values (read-only, не dry_run, для сверки с числами адъюдикации) ==="
for TABLE in "stg_msklad.fact_sales_staging" "stg_msklad.fact_sales_perimeter_staging"; do
  echo "--- ${TABLE} ---"
  bq query --project_id="$PROJECT" --nouse_legacy_sql --format=pretty \
    "SELECT MIN(${PARSE_DATE}) AS min_date, MAX(${PARSE_DATE}) AS max_date FROM \`${PROJECT}.${TABLE}\` s"
done

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== date -u (end) ==="
date -u
