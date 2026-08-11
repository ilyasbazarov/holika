#!/usr/bin/env bash
# SALES-REFRESH-WINDOW-MANDATE-ADJ · шаг 2 · холостая проверка НОВОГО текста запроса
# предохранителя (четыре поля) против обеих живых staging, оба реальных window_days.
# Класс A: --dry_run не исполняет запрос и ничего не пишет.
set -u
P=msklad-bi-prod
echo "=== ЯКОРЬ НАЧАЛА ==="; date -u; gcloud auth list 2>&1 | head -4; echo

run_guard () {  # $1 = таблица, $2 = window_days, $3 = метка
  echo "--- $3 : $1 , window_days=$2 ---"
  bq query --project_id=$P --use_legacy_sql=false --dry_run "
    SELECT
      MIN(DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek')) AS min_date,
      MAX(DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek')) AS max_date,
      DATE_SUB(CURRENT_DATE(), INTERVAL $2 DAY) AS window_start,
      DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)  AS freshness_floor
    FROM \`$1\` s" 2>&1 | tail -2
  echo
}

run_guard "msklad-bi-prod.stg_msklad.fact_sales_staging"           7  "продажи, часовой"
run_guard "msklad-bi-prod.stg_msklad.fact_sales_staging"           90 "продажи, недельный"
run_guard "msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging" 90 "периметр, недельный"

echo "=== ФАКТИЧЕСКОЕ СОСТОЯНИЕ ОБЕИХ STAGING (что решил бы предохранитель сегодня) ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 10 "
WITH s AS (
  SELECT 'продажи' AS t,
         MIN(DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek')) AS min_date,
         MAX(DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek')) AS max_date
  FROM \`msklad-bi-prod.stg_msklad.fact_sales_staging\`
  UNION ALL
  SELECT 'периметр',
         MIN(DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek')),
         MAX(DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek'))
  FROM \`msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging\`
)
SELECT t, min_date, max_date,
       DATE_ADD(DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY), INTERVAL 3 DAY) AS depth_limit_90,
       DATE_SUB(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY), INTERVAL 3 DAY)  AS fresh_limit,
       IF(min_date > DATE_ADD(DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY), INTERVAL 3 DAY), 'ОТКАЗ глубина', 'ok') AS verdict_depth_90,
       IF(max_date < DATE_SUB(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY), INTERVAL 3 DAY), 'ОТКАЗ свежесть', 'ok') AS verdict_fresh
FROM s"

echo "=== ЯКОРЬ КОНЦА ==="; date -u; gcloud auth list 2>&1 | head -4
