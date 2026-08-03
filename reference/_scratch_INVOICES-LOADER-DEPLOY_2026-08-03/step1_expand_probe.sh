#!/usr/bin/env bash
set -euo pipefail

# Шаг 1 брифа INVOICES-LOADER-DEPLOY: один read-only GET к entity/invoiceout
# с limit=100 и expand=state,agent,salesChannel,rate.currency — проверка,
# что приём всех четырёх компонентов expand при limit=100 не деградирует тихо
# (design §11.3, гэп 3). Только чтение, никаких записей.

date -u
gcloud auth list

MSKLAD_TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)

RESP_FILE="$(dirname "$0")/step1_invoiceout_response.json"

curl -sS -X GET \
  --get \
  --data-urlencode "limit=100" \
  --data-urlencode "expand=state,agent,salesChannel,rate.currency" \
  -H "Authorization: Bearer ${MSKLAD_TOKEN}" \
  -H "Accept-Encoding: gzip" \
  --compressed \
  "https://api.moysklad.ru/api/remap/1.2/entity/invoiceout" \
  -o "${RESP_FILE}"

echo "=== meta.size первой страницы ==="
python3 -c "
import json
with open('${RESP_FILE}') as f:
    data = json.load(f)
print('meta.size =', data.get('meta', {}).get('size'))
rows = data.get('rows', [])
print('rows_len =', len(rows))
for i, row in enumerate(rows[:5]):
    agent = row.get('agent') or {}
    state = row.get('state') or {}
    sc = row.get('salesChannel')
    rate = row.get('rate') or {}
    currency = rate.get('currency') or {}
    print(f'--- row {i} id={row.get(\"id\")} ---')
    print('  agent.name       =', agent.get('name'))
    print('  state.name       =', state.get('name'))
    print('  salesChannel     =', sc.get('name') if isinstance(sc, dict) else sc)
    print('  rate.currency.isoCode =', currency.get('isoCode'))
    print('  rate.value       =', rate.get('value'))
"

echo "=== ПРОВЕРКА: секрет не попал в файлы сессии ==="
if grep -rF -- "${MSKLAD_TOKEN}" "$(dirname "$0")" ; then
  echo "СТОП: НАЙДЕН ТОКЕН В ФАЙЛАХ"
else
  echo "OK: токен в файлах сессии не найден"
fi

unset MSKLAD_TOKEN

date -u
gcloud auth list
