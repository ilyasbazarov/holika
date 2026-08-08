#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== UTC-якорь (начало) ==="
date -u
echo "=== личность вызывающего (начало) ==="
gcloud auth list

echo "=== листинг gs://msklad-raw-msklad-bi-prod/demand/incremental/ ==="
gcloud storage ls -l gs://msklad-raw-msklad-bi-prod/demand/incremental/ | tee listing_2026-08-08.txt

echo "=== личность вызывающего (конец) ==="
gcloud auth list
echo "=== UTC-якорь (конец) ==="
date -u
