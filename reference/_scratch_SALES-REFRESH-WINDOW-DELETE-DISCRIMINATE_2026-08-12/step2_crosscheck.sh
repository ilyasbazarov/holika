#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== bq query: snapshot vs current row counts per group (agent_id + date) ==="
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=pretty < step_crosscheck.sql

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
