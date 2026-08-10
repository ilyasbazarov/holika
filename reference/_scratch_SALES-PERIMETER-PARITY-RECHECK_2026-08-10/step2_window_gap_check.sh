#!/usr/bin/env bash
# Шаг 2 брифа SALES-PERIMETER-PARITY-RECHECK: закрыть нюанс окна.
# Живой прогон perimeter (2026-08-07) покрыл 2026-05-09..2026-08-07 (PERIMETER_WINDOW_DAYS=90 от даты прогона).
# Проверяем, есть ли документы entity/retaildemand / entity/commissionreportin в необследованном
# отрезке 2026-05-01 00:00:00 .. 2026-05-09 00:00:00 (зона API, ADR-088 §3).
set -euo pipefail

OUT="$(dirname "$0")"
echo "=== date -u (начало) ==="
date -u
echo "=== gcloud auth list (начало) ==="
gcloud auth list

MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
echo "=== токен прочитан, длина: ${#MSKLAD_TOKEN} символов ==="

BASE="https://api.moysklad.ru/api/remap/1.2"

check_gap_window() {
  local endpoint="$1" outbase="$2"
  curl -s --compressed \
    -H "Authorization: Bearer ${MSKLAD_TOKEN}" -H "Accept-Encoding: gzip" \
    -G "$BASE/${endpoint}" \
    --data-urlencode "filter=moment>=2026-05-01 00:00:00;moment<2026-05-09 00:00:00" \
    --data-urlencode "limit=100" \
    --data-urlencode "offset=0" \
    > "$OUT/${outbase}_gapwindow.json"
  local size got
  size="$(jq -r '.meta.size' "$OUT/${outbase}_gapwindow.json")"
  got="$(jq -r '.rows | length' "$OUT/${outbase}_gapwindow.json")"
  echo "${outbase}: meta.size=${size}, rows в первой странице=${got}"
  if [ "$size" != "null" ] && [ "$size" -gt 0 ]; then
    echo "${outbase}: сумма sum (минорные единицы, документы окна разрыва) = $(jq -r '[.rows[].sum] | add // 0' "$OUT/${outbase}_gapwindow.json")"
    jq -r '.rows[] | [.id, .moment, (.agent.meta.href // "нет agent")] | @tsv' "$OUT/${outbase}_gapwindow.json"
  fi
}

echo "=== entity/retaildemand, окно разрыва 2026-05-01..2026-05-09 ==="
check_gap_window "entity/retaildemand" "retaildemand"

echo "=== entity/commissionreportin, окно разрыва 2026-05-01..2026-05-09 ==="
check_gap_window "entity/commissionreportin" "commissionreportin"

echo "=== проверка token не в артефактах ==="
grep -rF -- "$MSKLAD_TOKEN" "$OUT" && echo "СТОП: токен найден в артефактах" && exit 1 || echo "0 совпадений — чисто"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
