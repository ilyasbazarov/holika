#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

PROJECT=msklad-bi-prod
LOCATION=asia-east1

bq show -j --project_id="$PROJECT" --location="$LOCATION" --format=prettyjson fcd260f7-1fef-42ba-bfb1-101fd0f4b7ca 2>&1

gcloud auth list
date -u
