#!/usr/bin/env bash
# Шаг 4: выбор одного майского документа для второго замера сдвига (ADR-088 §10).
# Берём документ entity/demand (пара "Продажи") с moment в мае-2026 — не на границе суток,
# чтобы сдвиг +3ч не пересекал дату.
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
  -G "$BASE/entity/demand" \
  --data-urlencode "filter=moment>=2026-05-15 08:00:00;moment<2026-05-15 09:00:00;applicable=true" \
  --data-urlencode "limit=5" \
  > "$OUT/step4_candidate_demands.json"

jq -r '.meta.size' "$OUT/step4_candidate_demands.json"
jq -r '.rows[] | .id + " name=" + .name + " moment=" + .moment' "$OUT/step4_candidate_demands.json"

echo "=== проверка token не в артефактах ==="
grep -rF -- "$MSKLAD_TOKEN" "$OUT" && echo "СТОП: токен найден в артефактах" && exit 1 || echo "0 совпадений — чисто"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
