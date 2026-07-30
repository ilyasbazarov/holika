#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

PROJECT=msklad-bi-prod

echo "=== cf-facts, JSON, чтобы увидеть region факта ==="
gcloud functions list --project="$PROJECT" --filter="name:cf-facts" --format=json 2>&1

gcloud auth list
date -u
