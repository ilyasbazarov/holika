#!/usr/bin/env bash
# RETURNS-INGEST-COMPLETENESS шаг 2 (продолжение) — позитивный контроль.
# Класс B, мандат выдан владельцем (чат 2026-08-17). Только GET, ничего не пишется.
# Цель: убедиться, что entity/salesreturn за июль вообще непусто и что фильтр по agent
# (href контрагента) синтаксически рабочий — иначе HTTP 200 + 0 строк из шага 1 не факт
# «документа нет», а гэп наблюдения (ADR-021 §2).
set -u
echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4

TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
if [ -z "$TOKEN" ]; then echo "ГЭП: токен пуст"; exit 1; fi
echo "токен получен, длина: ${#TOKEN}"

BASE="https://api.moysklad.ru/api/remap/1.2/entity/salesreturn"
MOMENT_FILTER="moment>=2026-07-01 00:00:00;moment<=2026-07-31 23:59:59"

echo; echo "--- контроль A: entity/salesreturn, июль-2026, БЕЗ фильтра по agent (позитивный контроль на непустоту) ---"
curl -sS -w "\nHTTP_CODE=%{http_code}\n" --max-time 90 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept-Encoding: gzip" --compressed \
  --data-urlencode "filter=${MOMENT_FILTER}" \
  --data-urlencode "limit=100" \
  --get "$BASE" -o resp_salesreturn_july_nofilter.json
echo "размер ответа: $(wc -c < resp_salesreturn_july_nofilter.json) байт"
python3 - <<'PY'
import json
d = json.load(open('resp_salesreturn_july_nofilter.json'))
rows = d.get('rows', [])
print('строк в ответе:', len(rows), '| meta.size:', d.get('meta', {}).get('size'))
for r in rows[:20]:
    agent = (r.get('agent') or {}).get('meta', {}).get('href', '')
    print('  id=%s moment=%s applicable=%s sum=%.2f agent_href_tail=...%s' % (
        r.get('id'), r.get('moment'), r.get('applicable'),
        (r.get('sum') or 0) / 100, agent[-40:],
    ))
PY

echo; echo "--- контроль B: entity/salesreturn, июль-2026, agent=Эргешева (известный совпадающий возврат — позитивный контроль синтаксиса agent-фильтра) ---"
# Эргешева Алтынай — контрагент с совпавшим до копейки возвратом 62 709,00 (parity_client_july_recheck_2026-08-13.md).
# UUID контрагента в репо не зафиксирован явно — ищем среди строк контроля A по имени.
python3 - <<'PY'
import json
d = json.load(open('resp_salesreturn_july_nofilter.json'))
rows = d.get('rows', [])
for r in rows:
    agent_meta = r.get('agent', {}).get('meta', {})
    href = agent_meta.get('href', '')
    print(r.get('id'), '| moment=', r.get('moment'), '| agent_href=', href)
PY

echo
gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
