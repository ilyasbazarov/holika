#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

PROJECT=msklad-bi-prod

echo "=== 1. инвентарь Cloud Functions (все регионы) ==="
gcloud functions list --project="$PROJECT" --format="table(name,state,environment,updateTime)" 2>&1

echo "=== 2. инвентарь Cloud Run (gen2-функции видны и здесь) ==="
gcloud run services list --project="$PROJECT" --format="table(metadata.name,status.url,metadata.namespace)" 2>&1

gcloud auth list
date -u
