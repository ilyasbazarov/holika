#!/bin/bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "${SCRATCH}/archive_new"
cd "${SCRATCH}/archive_new"

echo "=== gcloud run services describe cf-dq (status.traffic after deploy) ==="
gcloud run services describe cf-dq --region=asia-east1 --project=msklad-bi-prod \
  --format="yaml(status.traffic,status.latestReadyRevisionName)"

echo "=== gcloud storage cp new revision archive (generation pinned) ==="
gcloud storage cp "gs://gcf-v2-sources-420804682491-asia-east1/cf-dq/function-source.zip#1786561996565446" ./function-source.zip
unzip -o -q function-source.zip -d unzipped
echo "=== files in new archive ==="
find unzipped -maxdepth 1 -type f | sort
echo "=== sha256 of unpacked new archive files ==="
shasum -a 256 unzipped/main.py unzipped/config.py unzipped/helpers.py unzipped/requirements.txt

echo "=== diff new archive vs deploy branch ==="
diff "${SCRATCH}/archive_new/unzipped/main.py" "${SCRATCH}/holika-prod/cf-dq/main.py" && echo "main.py IDENTICAL" || echo "main.py MISMATCH"
diff "${SCRATCH}/archive_new/unzipped/config.py" "${SCRATCH}/holika-prod/cf-dq/config.py" && echo "config.py IDENTICAL" || echo "config.py MISMATCH"
diff "${SCRATCH}/archive_new/unzipped/helpers.py" "${SCRATCH}/holika-prod/cf-dq/helpers.py" && echo "helpers.py IDENTICAL" || echo "helpers.py MISMATCH"
diff "${SCRATCH}/archive_new/unzipped/requirements.txt" "${SCRATCH}/holika-prod/cf-dq/requirements.txt" && echo "requirements.txt IDENTICAL" || echo "requirements.txt MISMATCH"

echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
