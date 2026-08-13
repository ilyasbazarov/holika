#!/usr/bin/env bash
# PARITY-CLIENT-JULY-RECHECK шаг 11 — живой read-only запрос к оракулу возвратов.
# Класс B, мандат выдан владельцем (чат 2026-08-13). Только GET, ничего не пишется.
set -u
echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4

TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
if [ -z "$TOKEN" ]; then echo "ГЭП: токен пуст"; exit 1; fi
echo "токен получен, длина: ${#TOKEN}"

BASE="https://api.moysklad.ru/api/remap/1.2/report/profit/bycounterparty"
Q="momentFrom=2026-07-01%2000:00:00&momentTo=2026-07-31%2023:59:59&limit=100"

echo; echo "--- GET bycounterparty, июль-2026 ---"
curl -sS -w "\nHTTP_CODE=%{http_code}\n" --max-time 90 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept-Encoding: gzip" --compressed \
  "$BASE?$Q" -o resp_bycounterparty_july.json
echo "размер ответа: $(wc -c < resp_bycounterparty_july.json) байт"

python3 - <<'PY'
import json
d=json.load(open('resp_bycounterparty_july.json'))
rows=d.get('rows',[])
print('строк в ответе:', len(rows), '| meta.size:', d.get('meta',{}).get('size'))
tot_ret=sum(r.get('returnSum',0) for r in rows)
print('СУММА returnSum по всем контрагентам: %.2f' % (tot_ret/100))
print()
print('контрагенты с ненулевым returnSum:')
for r in sorted(rows, key=lambda x: -x.get('returnSum',0)):
    if r.get('returnSum',0):
        print('  %-60s returnSum=%12.2f  returnCount=%s  sellSum=%.2f' % (
            r.get('counterparty',{}).get('name','?')[:60],
            r['returnSum']/100, r.get('returnCount'), r.get('sellSum',0)/100))
PY

echo
gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
