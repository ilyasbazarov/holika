#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

PROJECT=msklad-bi-prod
LOCATION=asia-east1

echo "=== job 1: CREATE_TABLE ==="
bq show -j --project_id="$PROJECT" --location="$LOCATION" --format=prettyjson bqjob_r15d696c9f4d48773_0000019e96f835a9_1 2>&1

echo "=== job 2: MERGE ==="
bq show -j --project_id="$PROJECT" --location="$LOCATION" --format=prettyjson 9026b571-70bc-475d-84eb-06a393692929 2>&1

gcloud auth list
date -u
