#!/usr/bin/env bash
# Дополнение к Шагу 3: entity/salesreturn (назначенный оракул пары, ADR-085 §2) даёт 0 документов
# в мае-2026, а core.fact_returns за май целиком состоит из 8 retailsalesreturn (570,00 KGS,
# step3c_bq_returns_may.log). Считаем ночные полосы для entity/retailsalesreturn отдельно —
# это факт о том, что реально наполняет core.fact_returns за май, не подмена оракула.
set -euo pipefail

OUT="$(dirname "$0")"
echo "=== date -u (начало) ==="
date -u
echo "=== gcloud auth list (начало) ==="
gcloud auth list

MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
echo "=== токен прочитан, длина: ${#MSKLAD_TOKEN} символов ==="

BASE="https://api.moysklad.ru/api/remap/1.2"

curl -s --compressed \
  -H "Authorization: Bearer ${MSKLAD_TOKEN}" -H "Accept-Encoding: gzip" \
  -G "$BASE/entity/retailsalesreturn" \
  --data-urlencode "filter=moment>=2026-05-01 00:00:00;moment<2026-06-01 00:00:00" \
  --data-urlencode "limit=100" \
  > "$OUT/retail_returns_may_full.json"

echo "meta.size:"
jq -r '.meta.size' "$OUT/retail_returns_may_full.json"
echo "moment + applicable + name + sum:"
jq -r '.rows[] | .moment + " applicable=" + (.applicable|tostring) + " name=" + .name + " sum=" + (.sum|tostring)' "$OUT/retail_returns_may_full.json" | sort

jq -r '.rows[].moment' "$OUT/retail_returns_may_full.json" | sort > "$OUT/retail_returns_may_moments.txt"

echo "=== полоса интерфейс/возвраты [21:00;24:00) UTC ==="
awk '{split($2,t,":"); h=t[1]+0; if (h>=21 && h<24) c++} END{print c+0}' "$OUT/retail_returns_may_moments.txt"
echo "=== полоса продажи/возвраты [18:00;24:00) UTC ==="
awk '{split($2,t,":"); h=t[1]+0; if (h>=18 && h<24) c++} END{print c+0}' "$OUT/retail_returns_may_moments.txt"
echo "=== вне обеих полос ==="
awk '{split($2,t,":"); h=t[1]+0; if (h<18) c++} END{print c+0}' "$OUT/retail_returns_may_moments.txt"

echo "=== проверка token не в артефактах ==="
grep -rF -- "$MSKLAD_TOKEN" "$OUT" && echo "СТОП: токен найден в артефактах" && exit 1 || echo "0 совпадений — чисто"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
