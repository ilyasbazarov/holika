#!/usr/bin/env bash
# Шаг 3 брифа: датированный снимок эталона report/profit/{byproduct,bycounterparty}, май-2026.
# Форма запроса идентична parity_sales_close_2026-08-04.md / step5_sales_reconciliation.sh.
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
  echo "${outbase}: сумма sellSum (сырые единицы API, /100 = KGS) = $(awk '{s+=$1} END{printf "%.2f", s}' "$OUT/${outbase}_sellsum.txt")"
  echo "${outbase}: сумма returnSum (сырые единицы API, /100 = KGS) = $(awk '{s+=$1} END{printf "%.2f", s}' "$OUT/${outbase}_returnsum.txt")"
}

echo "=== report/profit/byproduct, май-2026 ==="
fetch_report_sum "report/profit/byproduct" "byproduct_may_2026-08-10"

echo "=== report/profit/bycounterparty, май-2026 (внутренний контроль согласованности) ==="
fetch_report_sum "report/profit/bycounterparty" "bycounterparty_may_2026-08-10"

echo "=== проверка token не в артефактах ==="
grep -rF -- "$MSKLAD_TOKEN" "$OUT" && echo "СТОП: токен найден в артефактах" && exit 1 || echo "0 совпадений — чисто"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
