#!/bin/bash
set -euo pipefail
date -u
gcloud auth list --format="value(account,status)"

TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)

echo "--- GET entity/invoiceout limit=1 ---"
HTTP_CODE=$(curl -s --compressed -o reference/_scratch_INVOICES-FIELD-MAP_2026-08-02/invoiceout_sample.json -w "%{http_code}" \
  "https://api.moysklad.ru/api/remap/1.2/entity/invoiceout?limit=1" \
  -H "Authorization: Bearer ${TOKEN}")
echo "HTTP_CODE=${HTTP_CODE}"

echo "--- field count in body ---"
python3 -c "
import json
d = json.load(open('reference/_scratch_INVOICES-FIELD-MAP_2026-08-02/invoiceout_sample.json'))
rows = d.get('rows', [])
print('rows:', len(rows))
if rows:
    print('top-level fields:', sorted(rows[0].keys()))
"

date -u
gcloud auth list --format="value(account,status)"
