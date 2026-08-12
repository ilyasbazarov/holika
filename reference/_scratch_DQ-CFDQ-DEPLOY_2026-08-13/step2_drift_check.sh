#!/bin/bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "${SCRATCH}/archive_serving"
cd "${SCRATCH}/archive_serving"

echo "=== gcloud storage cp serving revision archive (generation pinned) ==="
gcloud storage cp "gs://gcf-v2-sources-420804682491-asia-east1/cf-dq/function-source.zip#1786372858921485" ./function-source.zip
unzip -o -q function-source.zip -d unzipped
echo "=== sha256 of unpacked archive files ==="
shasum -a 256 unzipped/main.py unzipped/config.py unzipped/helpers.py unzipped/requirements.txt

echo "=== clone holika-prod master ==="
cd "${SCRATCH}"
rm -rf holika-prod
git clone --branch master https://github.com/ilyasbazarov/holika-prod.git holika-prod
echo "=== sha256 of master cf-dq/ ==="
shasum -a 256 holika-prod/cf-dq/main.py holika-prod/cf-dq/config.py holika-prod/cf-dq/helpers.py holika-prod/cf-dq/requirements.txt

echo "=== diff serving archive vs master (byte-level) ==="
diff "${SCRATCH}/archive_serving/unzipped/main.py" "${SCRATCH}/holika-prod/cf-dq/main.py" && echo "main.py IDENTICAL" || echo "main.py MISMATCH"
diff "${SCRATCH}/archive_serving/unzipped/config.py" "${SCRATCH}/holika-prod/cf-dq/config.py" && echo "config.py IDENTICAL" || echo "config.py MISMATCH"
diff "${SCRATCH}/archive_serving/unzipped/helpers.py" "${SCRATCH}/holika-prod/cf-dq/helpers.py" && echo "helpers.py IDENTICAL" || echo "helpers.py MISMATCH"
diff "${SCRATCH}/archive_serving/unzipped/requirements.txt" "${SCRATCH}/holika-prod/cf-dq/requirements.txt" && echo "requirements.txt IDENTICAL" || echo "requirements.txt MISMATCH"

echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
