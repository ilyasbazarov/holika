#!/usr/bin/env bash
set -uo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== caller identity (start) ==="
gcloud auth list

echo "=== call cf-facts mode=perimeter_promote ==="
gcloud functions call cf-facts \
  --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --data='{"mode":"perimeter_promote","run_id":"verify_deploy_2026-08-07_channel_promote"}'
echo "call exit code: $?"

echo "=== UTC anchor (end) ==="
date -u
echo "=== caller identity (end) ==="
gcloud auth list
