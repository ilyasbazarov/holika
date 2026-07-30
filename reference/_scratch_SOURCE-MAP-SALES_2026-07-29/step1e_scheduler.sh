#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

PROJECT=msklad-bi-prod

echo "=== Scheduler jobs, фильтр по cf-facts в URI ==="
gcloud scheduler jobs list --project="$PROJECT" --location=asia-east1 --format=json 2>&1

gcloud auth list
date -u
