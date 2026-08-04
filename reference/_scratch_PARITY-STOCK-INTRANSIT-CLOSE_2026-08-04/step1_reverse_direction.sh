#!/usr/bin/env bash
# PARITY-STOCK-INTRANSIT-CLOSE · шаг 1 — обратное направление сверки строки 22 реестра.
#
# Вопрос шага: есть ли на НАШЕЙ стороне заказы в целевых статусах, которых нет в списке 17 заказов,
# снятых живым GET 2026-08-04T05:31Z сессией PARITY-INTRANSIT-ROWWISE. Прежний замер сверял только
# направление «источник → мы» (фильтр `purchase_order_id IN (17 id)`), обратное направление не
# измерялось. Оно существенно, потому что `core.fact_purchases` не пополняется с 2026-08-01T17:05Z
# (блок DQ Gate), а состав заказов в статусе меняется день ко дню (19 на 08-02, 17 на 08-04).
#
# Класс A: только read-only `bq query`, секретов нет, живых вызовов к МойСкладу нет.
# Явный --max_rows везде (ловушка тихого обрезания до 100 строк, ADR-115-эпизод PARITY-STOCK-INTRANSIT).
set -uo pipefail
PROJECT=msklad-bi-prod

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo
echo "=== step1a: агрегат нашей стороны по ЦЕЛЕВЫМ СТАТУСАМ (без фильтра по списку id) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=10 '
SELECT
  COUNT(DISTINCT purchase_order_id) AS n_orders,
  COUNT(*)                          AS n_positions,
  ROUND(SUM(in_transit_sum_kgs), 2) AS sum_in_transit_kgs
FROM `msklad-bi-prod.core.fact_purchases`
WHERE status_name IN ("В пути", "Прибыл частично")
  AND in_transit_sum_kgs > 0
'

echo
echo "=== step1b: тот же срез, но БЕЗ условия in_transit_sum_kgs > 0 (периметр фильтра марта) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=10 '
SELECT
  COUNT(DISTINCT purchase_order_id) AS n_orders,
  COUNT(*)                          AS n_positions
FROM `msklad-bi-prod.core.fact_purchases`
WHERE status_name IN ("В пути", "Прибыл частично")
'

echo
echo "=== step1c: поимённый список заказов нашей стороны в целевых статусах ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=5000 '
SELECT
  purchase_order_id,
  ANY_VALUE(order_name)             AS order_name,
  ANY_VALUE(status_name)            AS status_name,
  COUNT(*)                          AS n_positions,
  ROUND(SUM(in_transit_sum_kgs), 2) AS sum_in_transit_kgs
FROM `msklad-bi-prod.core.fact_purchases`
WHERE status_name IN ("В пути", "Прибыл частично")
  AND in_transit_sum_kgs > 0
GROUP BY purchase_order_id
ORDER BY purchase_order_id
'

echo
echo "=== step1d: то же по витрине marts.in_transit (без фильтра по списку id) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=5000 '
SELECT
  purchase_order_id,
  ANY_VALUE(status_name)            AS status_name,
  COUNT(*)                          AS n_positions,
  ROUND(SUM(in_transit_sum_kgs), 2) AS sum_in_transit_kgs
FROM `msklad-bi-prod.marts.in_transit`
GROUP BY purchase_order_id
ORDER BY purchase_order_id
'

echo
echo "=== step1e: свежесть нашей стороны — когда таблица последний раз пополнялась ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=10 '
SELECT
  MAX(_loaded_at) AS max_loaded_at,
  COUNT(*)        AS n_rows_total
FROM `msklad-bi-prod.core.fact_purchases`
'

echo
echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u
echo "SCRATCH_PATH=reference/_scratch_PARITY-STOCK-INTRANSIT-CLOSE_2026-08-04"
