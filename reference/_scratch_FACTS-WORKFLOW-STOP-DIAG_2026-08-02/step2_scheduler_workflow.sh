#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Cloud Scheduler jobs (region asia-east1) ==="
gcloud scheduler jobs list --location=asia-east1 --format=json

echo "=== Scheduler job describe: msklad-pipeline-hourly ==="
gcloud scheduler jobs describe msklad-pipeline-hourly --location=asia-east1 --format=json || echo "NOT FOUND: msklad-pipeline-hourly"

echo "=== Scheduler job describe: msklad-pipeline-weekly ==="
gcloud scheduler jobs describe msklad-pipeline-weekly --location=asia-east1 --format=json || echo "NOT FOUND: msklad-pipeline-weekly"

echo "=== Cloud Workflows list (region asia-east1) ==="
gcloud workflows list --location=asia-east1 --format=json

echo "=== Workflow describe: msklad-pipeline-hourly ==="
gcloud workflows describe msklad-pipeline-hourly --location=asia-east1 --format=json || echo "NOT FOUND (workflow object): msklad-pipeline-hourly"

echo "=== Workflow describe: msklad-pipeline-weekly ==="
gcloud workflows describe msklad-pipeline-weekly --location=asia-east1 --format=json || echo "NOT FOUND (workflow object): msklad-pipeline-weekly"

echo "=== Executions: msklad-pipeline-hourly, последние 30 ==="
gcloud workflows executions list msklad-pipeline-hourly --location=asia-east1 --limit=30 --format=json || echo "FAILED: executions list hourly"

echo "=== Executions: msklad-pipeline-weekly, последние 10 ==="
gcloud workflows executions list msklad-pipeline-weekly --location=asia-east1 --limit=10 --format=json || echo "FAILED: executions list weekly"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
