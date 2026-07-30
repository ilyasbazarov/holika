#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

PROJECT=msklad-bi-prod

echo "=== регион cf-facts из полного имени ресурса ==="
gcloud functions list --project="$PROJECT" --filter="name:cf-facts" --format="value(name)" 2>&1

gcloud auth list
date -u
