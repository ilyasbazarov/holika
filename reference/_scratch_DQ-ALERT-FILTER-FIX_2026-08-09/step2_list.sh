#!/bin/bash
set -uo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== gcloud logging metrics list ==="
gcloud logging metrics list --project=msklad-bi-prod --format=yaml

echo "=== gcloud alpha monitoring policies list (display_name+filters) ==="
gcloud alpha monitoring policies list --project=msklad-bi-prod \
  --format="yaml(displayName,enabled,conditions,notificationChannels)"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
