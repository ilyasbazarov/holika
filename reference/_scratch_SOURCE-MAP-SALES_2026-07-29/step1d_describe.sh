#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

gcloud functions describe cf-facts --gen2 --region=asia-east1 \
  --project=msklad-bi-prod --format=yaml 2>&1

gcloud auth list
date -u
