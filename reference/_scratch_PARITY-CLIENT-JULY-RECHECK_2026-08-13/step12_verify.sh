#!/usr/bin/env bash
set -u
echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4
TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
BASE="https://api.moysklad.ru/api/remap/1.2/report/profit/bycounterparty"

echo "--- страница 2 (offset=100): проверка полноты ---"
curl -sS --max-time 90 -H "Authorization: Bearer $TOKEN" --compressed \
 "$BASE?momentFrom=2026-07-01%2000:00:00&momentTo=2026-07-31%2023:59:59&limit=100&offset=100" \
 -o resp_page2.json
python3 - <<'PY'
import json
d=json.load(open('resp_page2.json'))
rows=d.get('rows',[])
print('строк на 2-й странице:', len(rows), '| meta.size:', d.get('meta',{}).get('size'))
tot=sum(r.get('returnSum',0) for r in rows)
print('returnSum 2-й страницы: %.2f' % (tot/100))
for r in rows:
    if r.get('returnSum',0):
        print('  ', r.get('counterparty',{}).get('name','?')[:60], r['returnSum']/100)
PY

echo; echo "--- есть ли UMAI WB в наших возвратах вообще ---"
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 20 "
SELECT c.name AS agent_name, r.return_date, r.return_id, ROUND(r.sum_kgs,2) AS sum_kgs, r.has_basis
FROM \`msklad-bi-prod.core.fact_returns\` r
LEFT JOIN \`msklad-bi-prod.core.dim_counterparties\` c ON r.agent_id=c.agent_id AND c.scd2_is_current=TRUE
WHERE LOWER(c.name) LIKE '%umai%'" 2>&1 | tail -8

echo; echo "--- есть ли UMAI WB в справочнике контрагентов ---"
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 20 "
SELECT agent_id, name FROM \`msklad-bi-prod.core.dim_counterparties\`
WHERE LOWER(name) LIKE '%umai%' AND scd2_is_current=TRUE" 2>&1 | tail -10

gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
