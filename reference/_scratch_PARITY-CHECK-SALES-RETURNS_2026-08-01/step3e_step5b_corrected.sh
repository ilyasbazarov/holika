#!/usr/bin/env bash
# Коррекция: fetch_demands.py (reference/code/cf-facts/fetch_demands.py:71-74) тянет entity/demand
# БЕЗ фильтра applicable, окно moment>=X;moment<=Y (обе границы включительно). Предыдущий замер
# (step3_night_bands.log, step5_sales_reconciliation.log/demand_sum_raw) ошибочно добавлял
# applicable=true — не соответствует реальному ингесту. Пересчёт точно по форме cf-facts.
set -euo pipefail

OUT="$(dirname "$0")"
echo "=== date -u (начало) ==="
date -u
echo "=== gcloud auth list (начало) ==="
gcloud auth list

MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
echo "=== токен прочитан, длина: ${#MSKLAD_TOKEN} символов ==="

BASE="https://api.moysklad.ru/api/remap/1.2"

offset=0; limit=100
: > "$OUT/demand_may_all_moments.txt"
: > "$OUT/demand_may_all_sum.txt"
: > "$OUT/demand_may_applicable_flags.txt"
while true; do
  curl -s --compressed \
    -H "Authorization: Bearer ${MSKLAD_TOKEN}" -H "Accept-Encoding: gzip" \
    -G "$BASE/entity/demand" \
    --data-urlencode "filter=moment>=2026-05-01 00:00:00;moment<=2026-05-31 23:59:59" \
    --data-urlencode "limit=${limit}" \
    --data-urlencode "offset=${offset}" \
    > "$OUT/demand_all_page_${offset}.json"
  got="$(jq -r '.rows | length' "$OUT/demand_all_page_${offset}.json")"
  size="$(jq -r '.meta.size' "$OUT/demand_all_page_${offset}.json")"
  jq -r '.rows[].moment' "$OUT/demand_all_page_${offset}.json" >> "$OUT/demand_may_all_moments.txt"
  jq -r '.rows[].sum' "$OUT/demand_all_page_${offset}.json" >> "$OUT/demand_may_all_sum.txt"
  jq -r '.rows[] | (.applicable|tostring)' "$OUT/demand_all_page_${offset}.json" >> "$OUT/demand_may_applicable_flags.txt"
  offset=$((offset + limit))
  if [ "$got" -lt "$limit" ]; then echo "entity/demand май (без applicable-фильтра): meta.size=${size}"; break; fi
  sleep 0.25
done

echo "документов всего: $(wc -l < "$OUT/demand_may_all_moments.txt")"
echo "из них applicable=true: $(grep -c '^true$' "$OUT/demand_may_applicable_flags.txt" || true)"
echo "из них applicable=false: $(grep -c '^false$' "$OUT/demand_may_applicable_flags.txt" || true)"

echo "=== сумма entity/demand.sum ВСЕХ документов (минорные единицы -> /100 KGS) ==="
awk '{s+=$1} END{printf "%.2f\n", s/100}' "$OUT/demand_may_all_sum.txt"

echo "=== ночная полоса интерфейс/продажи [18:00;21:00) UTC, все документы (без applicable-фильтра) ==="
awk '{split($2,t,":"); h=t[1]+0; if (h>=18 && h<21) c++} END{print c+0}' "$OUT/demand_may_all_moments.txt"
echo "=== полоса продажи/возвраты [18:00;24:00) UTC, все документы ==="
awk '{split($2,t,":"); h=t[1]+0; if (h>=18 && h<24) c++} END{print c+0}' "$OUT/demand_may_all_moments.txt"

echo "=== проверка token не в артефактах ==="
grep -rF -- "$MSKLAD_TOKEN" "$OUT" && echo "СТОП: токен найден в артефактах" && exit 1 || echo "0 совпадений — чисто"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
