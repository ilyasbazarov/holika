#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list

URI="https://cf-finance-xw5u2boozq-de.a.run.app"
TOKEN=$(gcloud auth print-identity-token --impersonate-service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com --audiences="${URI}")

echo "=== вызов mode=invoices (прод) ==="
curl -sS -w "\nHTTP_STATUS=%{http_code}\n" --max-time 1750 -X POST "${URI}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"mode":"invoices"}'

unset TOKEN
date -u
gcloud auth list
