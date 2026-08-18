#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== caller identity (start) ==="
gcloud auth list

export MSKLAD_TOKEN
MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"

python3 "$(dirname "$0")/check_source_resume.py"

unset MSKLAD_TOKEN

echo "=== UTC anchor (end) ==="
date -u
echo "=== caller identity (end) ==="
gcloud auth list
