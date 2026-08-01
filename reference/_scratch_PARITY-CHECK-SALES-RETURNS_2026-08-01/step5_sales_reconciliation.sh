#!/usr/bin/env bash
# Шаг 5, часть "Продажи": итог за май-2026, core.fact_sales_profit.revenue_kgs vs sellSum
# по report/profit/byproduct (и bycounterparty как внутренний контроль согласованности).
# Ночная полоса интерфейс/продажи [18:00;21:00) пуста (step3_night_bands.log) -> "без полос" = общий итог.
set -euo pipefail

OUT="$(dirname "$0")"
echo "=== date -u (начало) ==="
date -u
echo "=== gcloud auth list (начало) ==="
gcloud auth list

MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
echo "=== токен прочитан, длина: ${#MSKLAD_TOKEN} символов ==="

BASE="https://api.moysklad.ru/api/remap/1.2"

fetch_report_sum() {
  local endpoint="$1" outbase="$2"
  local offset=0 limit=100
  : > "$OUT/${outbase}_sellsum.txt"
  : > "$OUT/${outbase}_returnsum.txt"
  while true; do
    curl -s --compressed \
      -H "Authorization: Bearer ${MSKLAD_TOKEN}" -H "Accept-Encoding: gzip" \
      -G "$BASE/${endpoint}" \
      --data-urlencode "momentFrom=2026-05-01 00:00:00" \
      --data-urlencode "momentTo=2026-06-01 00:00:00" \
      --data-urlencode "limit=${limit}" \
      --data-urlencode "offset=${offset}" \
      > "$OUT/${outbase}_page_${offset}.json"
    local got size
    got="$(jq -r '.rows | length' "$OUT/${outbase}_page_${offset}.json")"
    size="$(jq -r '.meta.size' "$OUT/${outbase}_page_${offset}.json")"
    jq -r '.rows[].sellSum' "$OUT/${outbase}_page_${offset}.json" >> "$OUT/${outbase}_sellsum.txt"
    jq -r '.rows[].returnSum' "$OUT/${outbase}_page_${offset}.json" >> "$OUT/${outbase}_returnsum.txt"
    offset=$((offset + limit))
    if [ "$got" -lt "$limit" ]; then echo "${outbase}: meta.size=${size}, offset финальный=${offset}"; break; fi
    sleep 0.25
  done
  echo "${outbase}: сумма sellSum (сырые единицы API) = $(awk '{s+=$1} END{printf "%.2f", s}' "$OUT/${outbase}_sellsum.txt")"
  echo "${outbase}: сумма returnSum (сырые единицы API) = $(awk '{s+=$1} END{printf "%.2f", s}' "$OUT/${outbase}_returnsum.txt")"
}

echo "=== report/profit/byproduct, май-2026 ==="
fetch_report_sum "report/profit/byproduct" "byproduct_may"

echo "=== report/profit/bycounterparty, май-2026 (контроль согласованности) ==="
fetch_report_sum "report/profit/bycounterparty" "bycounterparty_may"

echo "=== спот-проверка масштаба единиц: entity/demand.sum (минорные единицы) за май-2026 ==="
offset=0; limit=100; : > "$OUT/demand_sum_raw.txt"
while true; do
  curl -s --compressed \
    -H "Authorization: Bearer ${MSKLAD_TOKEN}" -H "Accept-Encoding: gzip" \
    -G "$BASE/entity/demand" \
    --data-urlencode "filter=moment>=2026-05-01 00:00:00;moment<2026-06-01 00:00:00;applicable=true" \
    --data-urlencode "limit=${limit}" \
    --data-urlencode "offset=${offset}" \
    > "$OUT/demand_page_${offset}.json"
  got="$(jq -r '.rows | length' "$OUT/demand_page_${offset}.json")"
  jq -r '.rows[].sum' "$OUT/demand_page_${offset}.json" >> "$OUT/demand_sum_raw.txt"
  offset=$((offset + limit))
  if [ "$got" -lt "$limit" ]; then break; fi
  sleep 0.25
done
echo "entity/demand.sum сумма (минорные единицы, /100 = KGS если валюта документа KGS) = $(awk '{s+=$1} END{printf "%.2f", s/100}' "$OUT/demand_sum_raw.txt")"

echo "=== BigQuery: core.fact_sales_profit май-2026 ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  COUNT(*) AS n_rows,
  ROUND(SUM(sell_sum_kgs),2) AS sell_sum_kgs,
  ROUND(SUM(revenue_kgs),2) AS revenue_kgs,
  ROUND(SUM(return_sum_kgs),2) AS return_sum_kgs
FROM \`msklad-bi-prod.core.fact_sales_profit\`
WHERE transaction_date >= DATE('2026-05-01') AND transaction_date < DATE('2026-06-01')
" > "$OUT/bq_fact_sales_profit_may.json"
cat "$OUT/bq_fact_sales_profit_may.json"

echo "=== BigQuery: core.fact_returns май-2026 (уже снято step3c, повтор для полноты артефакта Шага 5) ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS n_rows, ROUND(SUM(sum_kgs),2) AS sum_kgs
FROM \`msklad-bi-prod.core.fact_returns\`
WHERE return_date >= DATE('2026-05-01') AND return_date < DATE('2026-06-01')
" > "$OUT/bq_fact_returns_may.json"
cat "$OUT/bq_fact_returns_may.json"

echo "=== проверка token не в артефактах ==="
grep -rF -- "$MSKLAD_TOKEN" "$OUT" && echo "СТОП: токен найден в артефактах" && exit 1 || echo "0 совпадений — чисто"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
