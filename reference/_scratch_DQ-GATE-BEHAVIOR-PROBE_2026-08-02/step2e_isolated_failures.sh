#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

for pair in \
  "382dac8c-d893-42a1-947d-8c0718619677:2026-07-14T12:00" \
  "29aeccd8-c09f-4cb7-a7d7-ab96732061ff:2026-07-18T08:00" \
  "8be4d433-c506-4af9-82cb-f48760b6bc2f:2026-07-21T17:00" \
  "38ebcabb-7e35-47ab-ac4d-2d05a2dc4816:2026-07-23T04:00" \
  "facac7ab-2072-41a4-be64-4fbc7b9bef5c:2026-07-28T20:00" \
; do
  eid="${pair%%:*}"
  ts="${pair##*:}"
  echo "=== execution $eid ($ts) — describe (error/step) ==="
  gcloud workflows executions describe "$eid" --workflow=msklad-pipeline-hourly --location=asia-east1 --format=json
done

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
