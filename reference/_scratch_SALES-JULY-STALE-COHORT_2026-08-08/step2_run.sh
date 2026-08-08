#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== UTC-якорь (начало) ==="
date -u
echo "=== личность вызывающего (начало) ==="
gcloud auth list

python3 step2c_match.py

echo "=== личность вызывающего (конец) ==="
gcloud auth list
echo "=== UTC-якорь (конец) ==="
date -u
