#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

for exec_id in 382dac8c-d893-42a1-947d-8c0718619677 29aeccd8-c09f-4cb7-a7d7-ab96732061ff 8be4d433-c506-4af9-82cb-f48760b6bc2f 38ebcabb-7e35-47ab-ac4d-2d05a2dc4816 facac7ab-2072-41a4-be64-4fbc7b9bef5c; do
  echo "=== describe $exec_id ==="
  gcloud workflows executions describe "$exec_id" --workflow=msklad-pipeline-hourly --location=asia-east1 --format=json
done

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
