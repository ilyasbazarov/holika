#!/usr/bin/env bash
# Шаг 3 брифа: замер ночных полос (ADR-088 §5/§6) за май-2026 по продажам (entity/demand) и
# возвратам (entity/salesreturn). Различитель Q-93 (снят step2b): границы filter=moment>=X;moment<=X
# интерпретируются в зоне API (той же, что moment), верхняя граница включительна при "<=".
# Полосы (UTC, зона API): продажи/интерфейс [18:00;21:00); возвраты/интерфейс [21:00;24:00);
# продажи/возвраты [18:00;24:00) = объединение первых двух.
set -euo pipefail

OUT="$(dirname "$0")"
echo "=== date -u (начало) ==="
date -u
echo "=== gcloud auth list (начало) ==="
gcloud auth list

MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
echo "=== токен прочитан, длина: ${#MSKLAD_TOKEN} символов ==="

BASE="https://api.moysklad.ru/api/remap/1.2"

fetch_all_moments() {
  # $1 = entity type, $2 = filter (без applicable, добавляется здесь), $3 = output basename
  local entity="$1" filter="$2" outbase="$3"
  local offset=0 limit=100 total=0
  : > "$OUT/${outbase}_moments.txt"
  while true; do
    curl -s --compressed \
      -H "Authorization: Bearer ${MSKLAD_TOKEN}" \
      -H "Accept-Encoding: gzip" \
      -G "$BASE/entity/${entity}" \
      --data-urlencode "filter=${filter}" \
      --data-urlencode "limit=${limit}" \
      --data-urlencode "offset=${offset}" \
      > "$OUT/${outbase}_page_${offset}.json"
    local size
    size="$(jq -r '.meta.size' "$OUT/${outbase}_page_${offset}.json")"
    local got
    got="$(jq -r '.rows | length' "$OUT/${outbase}_page_${offset}.json")"
    jq -r '.rows[].moment' "$OUT/${outbase}_page_${offset}.json" >> "$OUT/${outbase}_moments.txt"
    total="$size"
    offset=$((offset + limit))
    if [ "$got" -lt "$limit" ]; then break; fi
    sleep 0.25
  done
  echo "${outbase}: meta.size=${total}, строк moment собрано=$(wc -l < "$OUT/${outbase}_moments.txt")"
}

echo "=== продажи (entity/demand), май-2026, applicable=true ==="
fetch_all_moments "demand" "moment>=2026-05-01 00:00:00;moment<2026-06-01 00:00:00;applicable=true" "sales_may"

echo "=== возвраты (entity/salesreturn), май-2026, applicable=true ==="
fetch_all_moments "salesreturn" "moment>=2026-05-01 00:00:00;moment<2026-06-01 00:00:00;applicable=true" "returns_may"

echo "=== подсчёт полос (час UTC из moment, зона API = зона документа) ==="
count_band() {
  local file="$1" lo="$2" hi="$3"
  awk -v lo="$lo" -v hi="$hi" '{
    split($2, t, ":"); h = t[1]+0;
    if (h >= lo && h < hi) c++
  } END { print c+0 }' "$OUT/${file}_moments.txt"
}
count_total() {
  wc -l < "$OUT/${1}_moments.txt" | tr -d ' '
}

SALES_TOTAL=$(count_total sales_may)
RETURNS_TOTAL=$(count_total returns_may)
SALES_BAND1=$(count_band sales_may 18 21)   # интерфейс/продажи
RETURNS_BAND2=$(count_band returns_may 21 24) # интерфейс/возвраты
SALES_BAND3=$(count_band sales_may 18 24)   # продажи/возвраты (продажи-часть)
RETURNS_BAND3=$(count_band returns_may 18 24) # продажи/возвраты (возвраты-часть)

echo "ИТОГО май-2026:"
echo "  продажи (entity/demand, applicable=true): total=${SALES_TOTAL}"
echo "  возвраты (entity/salesreturn, applicable=true): total=${RETURNS_TOTAL}"
echo "  полоса интерфейс/продажи [18:00;21:00) UTC — документов продаж: ${SALES_BAND1}"
echo "  полоса интерфейс/возвраты [21:00;24:00) UTC — документов возвратов: ${RETURNS_BAND2}"
echo "  полоса продажи/возвраты [18:00;24:00) UTC — документов продаж: ${SALES_BAND3}, документов возвратов: ${RETURNS_BAND3}"

echo "=== проверка token не в артефактах ==="
grep -rF -- "$MSKLAD_TOKEN" "$OUT" && echo "СТОП: токен найден в артефактах" && exit 1 || echo "0 совпадений — чисто"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
