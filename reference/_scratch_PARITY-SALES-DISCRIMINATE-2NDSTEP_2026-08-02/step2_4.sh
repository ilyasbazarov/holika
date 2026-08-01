#!/usr/bin/env bash
# Шаг 2-4 брифа PARITY-SALES-DISCRIMINATE-2NDSTEP: H1 (розничный периметр entity/retaildemand)
# и H4 (симметрия верхней границы report/profit/bycounterparty). Read-only, класс B
# (секрет msklad-token), мандат ADR-100 §10. Форма запроса/заголовка — дословно из
# прецедента reference/_scratch_PARITY-CHECK-SALES-RETURNS_2026-08-01/step5_sales_reconciliation.sh.
set -euo pipefail

OUT="$(dirname "$0")"
echo "=== date -u (начало) ==="
date -u
echo "=== gcloud auth list (начало) ==="
gcloud auth list

MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
echo "=== токен прочитан, длина: ${#MSKLAD_TOKEN} символов ==="

BASE="https://api.moysklad.ru/api/remap/1.2"

echo "=== Шаг 2: entity/retaildemand, май-2026 (форма окна как у step5 entity/demand) ==="
offset=0; limit=100; : > "$OUT/retaildemand_sum_raw.txt"
retail_size=""
while true; do
  curl -s --compressed \
    -H "Authorization: Bearer ${MSKLAD_TOKEN}" -H "Accept-Encoding: gzip" \
    -G "$BASE/entity/retaildemand" \
    --data-urlencode "filter=moment>=2026-05-01 00:00:00;moment<2026-06-01 00:00:00;applicable=true" \
    --data-urlencode "limit=${limit}" \
    --data-urlencode "offset=${offset}" \
    > "$OUT/retaildemand_page_${offset}.json"
  got="$(jq -r '.rows | length' "$OUT/retaildemand_page_${offset}.json")"
  retail_size="$(jq -r '.meta.size' "$OUT/retaildemand_page_${offset}.json")"
  jq -r '.rows[].sum' "$OUT/retaildemand_page_${offset}.json" >> "$OUT/retaildemand_sum_raw.txt"
  if [ "$offset" -eq 0 ]; then
    echo "=== ключи rows[0] entity/retaildemand (ADR-079 §6 форма логирования) ==="
    jq -r 'if (.rows|length)>0 then (.rows[0] | keys | sort | tostring) else "NO ROWS" end' "$OUT/retaildemand_page_${offset}.json"
  fi
  offset=$((offset + limit))
  if [ "$got" -lt "$limit" ]; then echo "entity/retaildemand: meta.size=${retail_size}, страниц собрано, offset финальный=${offset}"; break; fi
  sleep 0.25
done
retail_sum_minor="$(awk '{s+=$1} END{printf "%.2f", s}' "$OUT/retaildemand_sum_raw.txt")"
retail_sum_kgs="$(awk '{s+=$1} END{printf "%.2f", s/100}' "$OUT/retaildemand_sum_raw.txt")"
echo "entity/retaildemand май-2026: meta.size=${retail_size}"
echo "entity/retaildemand май-2026: сумма поля sum (сырые минорные единицы) = ${retail_sum_minor}"
echo "entity/retaildemand май-2026: сумма поля sum, KGS (/100) = ${retail_sum_kgs}"

echo "=== Шаг 3: проверка прочтения 639 = 127 + retaildemand ==="
echo "639 - 127 = 512"
echo "meta.size(entity/retaildemand) = ${retail_size}"
if [ "${retail_size}" = "512" ]; then
  echo "СОВПАЛО: 512 == ${retail_size}"
else
  echo "НЕ СОВПАЛО: 512 != ${retail_size}"
fi

echo "=== Шаг 4: report/profit/bycounterparty, momentTo симметричный (2026-05-31 23:59:59) ==="
offset=0; limit=100; : > "$OUT/bycounterparty_sym_sellsum.txt"
while true; do
  curl -s --compressed \
    -H "Authorization: Bearer ${MSKLAD_TOKEN}" -H "Accept-Encoding: gzip" \
    -G "$BASE/report/profit/bycounterparty" \
    --data-urlencode "momentFrom=2026-05-01 00:00:00" \
    --data-urlencode "momentTo=2026-05-31 23:59:59" \
    --data-urlencode "limit=${limit}" \
    --data-urlencode "offset=${offset}" \
    > "$OUT/bycounterparty_sym_page_${offset}.json"
  got="$(jq -r '.rows | length' "$OUT/bycounterparty_sym_page_${offset}.json")"
  sym_size="$(jq -r '.meta.size' "$OUT/bycounterparty_sym_page_${offset}.json")"
  jq -r '.rows[].sellSum' "$OUT/bycounterparty_sym_page_${offset}.json" >> "$OUT/bycounterparty_sym_sellsum.txt"
  offset=$((offset + limit))
  if [ "$got" -lt "$limit" ]; then echo "bycounterparty (momentTo симметричный): meta.size=${sym_size}, offset финальный=${offset}"; break; fi
  sleep 0.25
done
sym_sellsum="$(awk '{s+=$1} END{printf "%.2f", s}' "$OUT/bycounterparty_sym_sellsum.txt")"
prev_sellsum="93234205.80"
diff="$(python3 -c "print(f'{${sym_sellsum} - ${prev_sellsum}:.2f}')")"
echo "report/profit/bycounterparty momentTo=2026-05-31 23:59:59: sellSum сумма = ${sym_sellsum}"
echo "report/profit/bycounterparty momentTo=2026-06-01 00:00:00 (прежний замер, REPORT-FIELDS/PARITY-CHECK-SALES-RETURNS) = ${prev_sellsum}"
echo "разность (симметричный - прежний) = ${diff}"

echo "=== проверка: токен не в артефактах этого шага ==="
grep -rF -- "$MSKLAD_TOKEN" "$OUT" && echo "СТОП: токен найден в артефактах" && exit 1 || echo "0 совпадений — чисто"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
