#!/bin/bash
set -euo pipefail
date -u
gcloud auth list --format="value(account,status)"

TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)

echo "--- GET entity/invoiceout limit=5 expand=state,agent,salesChannel ---"
HTTP_CODE=$(curl -s --compressed -o reference/_scratch_INVOICES-FIELD-MAP_2026-08-02/invoiceout_expand.json -w "%{http_code}" \
  "https://api.moysklad.ru/api/remap/1.2/entity/invoiceout?limit=5&expand=state,agent,salesChannel" \
  -H "Authorization: Bearer ${TOKEN}")
echo "HTTP_CODE=${HTTP_CODE}"

date -u
gcloud auth list --format="value(account,status)"
