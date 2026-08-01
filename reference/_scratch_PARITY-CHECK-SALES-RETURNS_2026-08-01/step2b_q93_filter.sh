#!/usr/bin/env bash
# Продолжение Шага 2: momentFrom/momentTo не действуют на entity/salesreturn (факт, снят step2_q93.sh —
# все 5 окон вернули идентичные 11 документов, включая заведомо непопадающее контрольное окно).
# Пробуем документированный для entity-API синтаксис: filter=moment>=X;moment<=X
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

call_filter() {
  local label="$1" filter="$2"
  echo "=== $label : filter=$filter ==="
  curl -s --compressed \
    -H "Authorization: Bearer ${MSKLAD_TOKEN}" \
    -H "Accept-Encoding: gzip" \
    -G "$BASE/entity/salesreturn" \
    --data-urlencode "filter=$filter" \
    --data-urlencode "limit=100" \
    > "$OUT/${label}.json"
  echo "meta.size:"
  jq -r '.meta.size // .errors' "$OUT/${label}.json"
  echo "id документа №00008 присутствует в rows:"
  jq -r --arg id "$DOC_ID" '[.rows[]?.id] | index($id) != null' "$OUT/${label}.json"
  echo "moments в rows:"
  jq -r '.rows[]?.moment' "$OUT/${label}.json"
}

# Зона API (UTC по гипотезе ADR-088): нулевое окно ровно на M
call_filter "q93f_zero_api" "moment>=2026-07-01 15:33:00;moment<=2026-07-01 15:33:00"
# Зона API: узкое окно ±1 минута
call_filter "q93f_narrow_api" "moment>=2026-07-01 15:32:00;moment<=2026-07-01 15:34:00"
# Зона API: окно БЕЗ верхней границы включительно (M-1мин .. M, точно ДО M) — проверка включения верхней границы
call_filter "q93f_upper_excl_test" "moment>=2026-07-01 15:32:00;moment<2026-07-01 15:33:00"
# Гипотеза сдвига +3ч (Москва): нулевое окно на M+3ч
call_filter "q93f_zero_plus3" "moment>=2026-07-01 18:33:00;moment<=2026-07-01 18:33:00"
# Контроль: далёкое окно, документ не должен попасть ни при одной гипотезе
call_filter "q93f_control_far" "moment>=2026-07-01 10:00:00;moment<=2026-07-01 10:01:00"

echo "=== проверка token не в артефактах ==="
grep -rF -- "$MSKLAD_TOKEN" "$OUT" && echo "СТОП: токен найден в артефактах" && exit 1 || echo "0 совпадений — чисто"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
