#!/usr/bin/env bash
# SALES-PERIMETER-CONFIRM, часть B (класс B, мандат — владелец, чат 2026-08-02).
# ТОЛЬКО добыча: один GET на чтение. Расчёт идёт офлайн отдельным шагом по сохранённому телу
# (ADR-055 §2 — диагностику и действие в один скрипт не объединять).
# Оговорки ADR-076 §5: токен не печатается (в лог только длина); форма заголовка — дословно
# reference/code/cf-finance/main.py:39; grep -rF по значению токена перед git add — отдельным шагом.
# Форма логирования ADR-079 §6: date -u и gcloud auth list первой И последней командой.
set -uo pipefail

OUT="$(dirname "$0")"

echo "=== ЯКОРЬ НАЧАЛА ==="
date -u
gcloud auth list 2>&1
echo

MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
echo "токен прочитан, длина строки: ${#MSKLAD_TOKEN} символов (значение не печатается)"
echo

# Фильтр — дословно тот же, что у загрузчика reference/code/cf-loss-commission/main.py:129
FILTER='moment>=2026-05-01 00:00:00;moment<2026-06-01 00:00:00'
URL="https://api.moysklad.ru/api/remap/1.2/entity/commissionreportin?filter=$(python3 -c "
import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$FILTER")&expand=positions,agent,rate.currency&limit=100&offset=0"

echo "=== URL запроса (без токена) ==="
echo "$URL"
echo

curl -sS -w '\nHTTP_STATUS=%{http_code}\n' \
  -H "Authorization: Bearer ${MSKLAD_TOKEN}" \
  -H "Accept-Encoding: gzip" \
  --compressed \
  "$URL" -o "$OUT/commissionreportin_may_page_0.json" 2>&1
echo

echo "=== контроль тела ответа ==="
ls -la "$OUT/commissionreportin_may_page_0.json"
python3 - "$OUT/commissionreportin_may_page_0.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print("meta:", json.dumps(d.get("meta", {}), ensure_ascii=False)[:300])
rows = d.get("rows", [])
print("rows в теле:", len(rows))
if rows:
    print("ключи rows[0] (ADR-079 §6):", ", ".join(sorted(rows[0].keys())))
    pos = (rows[0].get("positions") or {}).get("rows") or []
    print("позиций в rows[0]:", len(pos))
    if pos:
        print("ключи positions.rows[0]:", ", ".join(sorted(pos[0].keys())))
PY
echo

echo "=== ЯКОРЬ КОНЦА ==="
date -u
gcloud auth list 2>&1
