#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== ЯКОРЬ НАЧАЛА ==="; date -u; gcloud auth list 2>&1 | head -4; echo
echo "=== A. Все пары (id канала, имя канала) во ВСЕЙ истории ядра ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 50 '
SELECT
  IF(sales_channel_id IS NULL, "(id NULL)", "(id есть)") AS id_state,
  COALESCE(sales_channel_name,"(имя NULL)")              AS channel_name,
  COUNT(*)                                               AS n_rows,
  MIN(transaction_date) AS min_d, MAX(transaction_date) AS max_d
FROM `msklad-bi-prod.core.fact_sales_profit`
GROUP BY id_state, channel_name
ORDER BY n_rows DESC'
echo
echo "=== B. Коллизия: строки с НЕПУСТЫМ id и именем Розница/Комиссия (сломали бы предикат) ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 20 '
SELECT COUNT(*) AS n_collisions
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE sales_channel_id IS NOT NULL AND sales_channel_name IN ("Розница","Комиссия")'
echo
echo "=== C. Что попало бы под КАЖДЫЙ предикат в окне 90 суток (проверка до правки) ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 20 '
SELECT
  COUNTIF(sales_channel_id IS NULL AND sales_channel_name IN ("Розница","Комиссия"))     AS rows_perimeter_scope,
  COUNTIF(NOT (sales_channel_id IS NULL AND sales_channel_name IN ("Розница","Комиссия"))) AS rows_sales_scope,
  COUNT(*)                                                                                AS rows_total
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)'
echo "=== ЯКОРЬ КОНЦА ==="; date -u
