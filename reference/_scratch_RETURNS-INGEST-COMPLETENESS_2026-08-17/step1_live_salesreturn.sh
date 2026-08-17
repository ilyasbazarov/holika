#!/usr/bin/env bash
# RETURNS-INGEST-COMPLETENESS шаг 2 — живой read-only запрос к entity/salesreturn.
# Класс B, мандат выдан владельцем (чат 2026-08-17). Только GET, ничего не пишется.
set -u
echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4

TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
if [ -z "$TOKEN" ]; then echo "ГЭП: токен пуст"; exit 1; fi
echo "токен получен, длина: ${#TOKEN}"

BASE="https://api.moysklad.ru/api/remap/1.2/entity/salesreturn"
AGENT_HREF="https://api.moysklad.ru/api/remap/1.2/entity/counterparty/0276f431-2ff5-11ef-0a80-11d40019917f"
FILTER="moment>=2026-07-01 00:00:00;moment<=2026-07-31 23:59:59;agent=${AGENT_HREF}"

echo; echo "--- GET entity/salesreturn, июль-2026, agent=UMAI WB (Договор КР) ---"
curl -sS -w "\nHTTP_CODE=%{http_code}\n" --max-time 90 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept-Encoding: gzip" --compressed \
  --data-urlencode "filter=${FILTER}" \
  --get "$BASE" -o resp_salesreturn_july_umaiwb.json
echo "размер ответа: $(wc -c < resp_salesreturn_july_umaiwb.json) байт"

python3 - <<'PY'
import json
d = json.load(open('resp_salesreturn_july_umaiwb.json'))
rows = d.get('rows', [])
print('строк в ответе:', len(rows), '| meta.size:', d.get('meta', {}).get('size'))
for r in rows:
    print('  id=%s moment=%s applicable=%s sum=%.2f name=%s' % (
        r.get('id'), r.get('moment'), r.get('applicable'),
        (r.get('sum') or 0) / 100, r.get('name'),
    ))
PY

echo
echo "--- контроль: тот же фильтр по retailsalesreturn (K4 — второй известный тип) ---"
BASE2="https://api.moysklad.ru/api/remap/1.2/entity/retailsalesreturn"
curl -sS -w "\nHTTP_CODE=%{http_code}\n" --max-time 90 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept-Encoding: gzip" --compressed \
  --data-urlencode "filter=${FILTER}" \
  --get "$BASE2" -o resp_retailsalesreturn_july_umaiwb.json
echo "размер ответа: $(wc -c < resp_retailsalesreturn_july_umaiwb.json) байт"

python3 - <<'PY'
import json
d = json.load(open('resp_retailsalesreturn_july_umaiwb.json'))
rows = d.get('rows', [])
print('строк в ответе:', len(rows), '| meta.size:', d.get('meta', {}).get('size'))
for r in rows:
    print('  id=%s moment=%s applicable=%s sum=%.2f name=%s' % (
        r.get('id'), r.get('moment'), r.get('applicable'),
        (r.get('sum') or 0) / 100, r.get('name'),
    ))
PY

echo
gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
