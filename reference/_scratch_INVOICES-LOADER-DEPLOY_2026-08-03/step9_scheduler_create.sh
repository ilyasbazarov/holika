#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list

gcloud scheduler jobs create http invoices-daily-update \
  --project=msklad-bi-prod \
  --location=asia-east1 \
  --schedule="0 4 * * *" \
  --time-zone="Asia/Bishkek" \
  --uri="https://cf-finance-xw5u2boozq-de.a.run.app" \
  --http-method=POST \
  --message-body='{"mode":"invoices"}' \
  --headers="Content-Type=application/json" \
  --oidc-service-account-email=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --attempt-deadline=1800s \
  --max-retry-attempts=0

echo "=== read-back ==="
gcloud scheduler jobs describe invoices-daily-update --project=msklad-bi-prod --location=asia-east1 --format=json

date -u
gcloud auth list
