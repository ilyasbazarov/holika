#!/usr/bin/env bash
# PARITY-STOCK-INTRANSIT-CLOSE · шаг 3 — прямая проверка двух арифметических выводов шага 2.
# Вывод 1 (проверяется): два заказа, которые источник числит «в пути», а мы нет, несут в нашем
#   ядре нулевой остаток к поставке — тогда фильтр моста (`in_transit_sum_kgs > 0`) исключает их
#   с ОБЕИХ сторон и расхождением они не являются.
# Вывод 2 (проверяется): 15 заказов пересечения дают на нашей стороне ровно 76 514 274,30 KGS.
# Класс A: только read-only `bq query`. Явный --max_rows.
set -uo pipefail
PROJECT=msklad-bi-prod

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo
echo "=== step3a: два заказа, которые источник числит в целевых статусах, а наше ядро — нет ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=100 '
SELECT
  purchase_order_id,
  ANY_VALUE(order_name)                     AS order_name,
  ANY_VALUE(status_name)                    AS our_status_name,
  COUNT(*)                                  AS n_positions,
  COUNTIF(in_transit_sum_kgs > 0)           AS n_positions_nonzero,
  ROUND(SUM(in_transit_sum_kgs), 2)         AS sum_in_transit_kgs,
  ROUND(SUM(quantity_in_transit), 2)        AS qty_in_transit
FROM `msklad-bi-prod.core.fact_purchases`
WHERE purchase_order_id IN (
  "04a41f62-826b-11f1-0a80-14070015f6ec",
  "aab67ac6-e2d4-11f0-0a80-0fda0015d3cf"
)
GROUP BY purchase_order_id
ORDER BY purchase_order_id
'

echo
echo "=== step3b: 15 заказов пересечения — наша сторона, фильтр моста ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=100 '
SELECT
  COUNT(DISTINCT purchase_order_id)   AS n_orders,
  COUNT(*)                            AS n_positions,
  ROUND(SUM(in_transit_sum_kgs), 2)   AS sum_in_transit_kgs
FROM `msklad-bi-prod.core.fact_purchases`
WHERE status_name IN ("В пути", "Прибыл частично")
  AND in_transit_sum_kgs > 0
  AND purchase_order_id NOT IN (
    "08bfe70e-7b8b-11f1-0a80-03b8000e83b3",
    "e7d7a18b-81c6-11f1-0a80-0170000b1cc0"
  )
'

echo
echo "=== step3c: два заказа одностороннего хвоста — их статус и время загрузки ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=100 '
SELECT
  purchase_order_id,
  ANY_VALUE(order_name)             AS order_name,
  ANY_VALUE(status_name)            AS our_status_name,
  ANY_VALUE(order_date)             AS order_date,
  MAX(_loaded_at)                   AS max_loaded_at,
  COUNT(*)                          AS n_positions,
  ROUND(SUM(in_transit_sum_kgs), 2) AS sum_in_transit_kgs
FROM `msklad-bi-prod.core.fact_purchases`
WHERE purchase_order_id IN (
  "08bfe70e-7b8b-11f1-0a80-03b8000e83b3",
  "e7d7a18b-81c6-11f1-0a80-0170000b1cc0"
)
GROUP BY purchase_order_id
ORDER BY purchase_order_id
'

echo
echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u
echo "SCRATCH_PATH=reference/_scratch_PARITY-STOCK-INTRANSIT-CLOSE_2026-08-04"
