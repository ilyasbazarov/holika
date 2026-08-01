#!/usr/bin/env bash
# Санитарная проверка находки Шага 3: entity/salesreturn май-2026 applicable=true дал 0.
# Проверяем без applicable-фильтра и без периода вовсе (полный список всех 11 документов с датами),
# чтобы исключить ложноотрицательный вывод фильтра (rc=0 при пустой выдаче — гэп наблюдения,
# ★ Успех инструмента ≠ факт, пока не подтверждено независимо).
set -euo pipefail

OUT="$(dirname "$0")"
echo "=== date -u (начало) ==="
date -u
echo "=== gcloud auth list (начало) ==="
gcloud auth list

MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
echo "=== токен прочитан, длина: ${#MSKLAD_TOKEN} символов ==="

BASE="https://api.moysklad.ru/api/remap/1.2"

echo "=== entity/salesreturn май-2026, БЕЗ applicable ==="
curl -s --compressed \
  -H "Authorization: Bearer ${MSKLAD_TOKEN}" -H "Accept-Encoding: gzip" \
  -G "$BASE/entity/salesreturn" \
  --data-urlencode "filter=moment>=2026-05-01 00:00:00;moment<2026-06-01 00:00:00" \
  --data-urlencode "limit=100" \
  > "$OUT/returns_may_no_applicable.json"
jq -r '.meta.size' "$OUT/returns_may_no_applicable.json"
jq -r '.rows[] | .moment + " applicable=" + (.applicable|tostring) + " name=" + .name' "$OUT/returns_may_no_applicable.json"

echo "=== entity/salesreturn ВСЕ документы (без фильтра периода), moment + applicable + name ==="
curl -s --compressed \
  -H "Authorization: Bearer ${MSKLAD_TOKEN}" -H "Accept-Encoding: gzip" \
  -G "$BASE/entity/salesreturn" \
  --data-urlencode "limit=100" \
  > "$OUT/returns_all.json"
jq -r '.meta.size' "$OUT/returns_all.json"
jq -r '.rows[] | .moment + " applicable=" + (.applicable|tostring) + " name=" + .name' "$OUT/returns_all.json" | sort

echo "=== entity/retailsalesreturn май-2026 (второй источник core.fact_returns по fetch_returns.py) ==="
curl -s --compressed \
  -H "Authorization: Bearer ${MSKLAD_TOKEN}" -H "Accept-Encoding: gzip" \
  -G "$BASE/entity/retailsalesreturn" \
  --data-urlencode "filter=moment>=2026-05-01 00:00:00;moment<2026-06-01 00:00:00" \
  --data-urlencode "limit=100" \
  > "$OUT/retail_returns_may.json"
jq -r '.meta.size // .errors' "$OUT/retail_returns_may.json"

echo "=== проверка token не в артефактах ==="
grep -rF -- "$MSKLAD_TOKEN" "$OUT" && echo "СТОП: токен найден в артефактах" && exit 1 || echo "0 совпадений — чисто"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
