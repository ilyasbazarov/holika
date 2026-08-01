#!/usr/bin/env bash
# Шаг 2 брифа PARITY-CHECK-SALES-RETURNS: различитель Q-93 (зона границ momentFrom/momentTo)
# Метод: узкое окно вокруг документа entity/salesreturn №00008 (M=2026-07-01 15:33:00.000 по API),
# сравнение окна "как есть" (зона API) с окном, сдвинутым на +3ч/-3ч (гипотеза "границы в зоне Москвы").
set -euo pipefail

OUT="$(dirname "$0")"
echo "=== date -u (начало) ==="
date -u
echo "=== gcloud auth list (начало) ==="
gcloud auth list

MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
echo "=== токен прочитан, длина: ${#MSKLAD_TOKEN} символов ==="

DOC_ID="0d9650b7-7549-11f1-0a80-19c400103fb5"
BASE="https://api.moysklad.ru/api/remap/1.2"

call() {
  local label="$1" mf="$2" mt="$3"
  echo "=== $label : momentFrom=$mf momentTo=$mt ==="
  curl -s --compressed \
    -H "Authorization: Bearer ${MSKLAD_TOKEN}" \
    -H "Accept-Encoding: gzip" \
    -G "$BASE/entity/salesreturn" \
    --data-urlencode "momentFrom=$mf" \
    --data-urlencode "momentTo=$mt" \
    --data-urlencode "limit=100" \
    > "$OUT/${label}.json"
  echo "meta.size:"
  jq -r '.meta.size' "$OUT/${label}.json"
  echo "id документа №00008 присутствует в rows:"
  jq -r --arg id "$DOC_ID" '[.rows[]?.id] | index($id) != null' "$OUT/${label}.json"
  echo "moments в rows (если немного строк):"
  jq -r '.rows[]?.moment' "$OUT/${label}.json" | head -20
}

# Гипотеза A: границы в той же зоне, что и moment в ответе (условно UTC/API-зона).
# Нулевое окно ровно на M — проверяет включение обеих границ.
call "q93_A_zero_window_api" "2026-07-01 15:33:00" "2026-07-01 15:33:00"

# Узкое окно вокруг M в зоне API (минус/плюс 1 минута)
call "q93_A_narrow_api" "2026-07-01 15:32:00" "2026-07-01 15:34:00"

# Гипотеза B: границы в зоне Москвы (интерфейс), т.е. запрос должен использовать M+3ч, чтобы поймать документ,
# если сервер трактует переданные границы как московское время и сам сравнивает их с M (в API-зоне) с сдвигом.
call "q93_B_shifted_plus3_zero" "2026-07-01 18:33:00" "2026-07-01 18:33:00"
call "q93_B_shifted_plus3_narrow" "2026-07-01 18:32:00" "2026-07-01 18:34:00"

# Контроль: заведомо непопадающее окно (далеко от M в обеих гипотезах)
call "q93_control_far" "2026-07-01 10:00:00" "2026-07-01 10:01:00"

echo "=== проверка token не в артефактах ==="
grep -rF -- "$MSKLAD_TOKEN" "$OUT" && echo "СТОП: токен найден в артефактах" && exit 1 || echo "0 совпадений — чисто"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
