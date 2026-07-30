#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

PROJECT=msklad-bi-prod
REGION=asia-east1

echo "=== describe cf-inventory ==="
gcloud functions describe cf-inventory --gen2 --region="$REGION" --project="$PROJECT" --format=yaml 2>&1

gcloud auth list
date -u
