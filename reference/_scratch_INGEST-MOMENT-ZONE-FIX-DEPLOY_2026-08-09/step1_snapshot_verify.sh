#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== gcloud functions describe cf-facts ==="
gcloud functions describe cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod --format=json > cf-facts_describe.json
python3 -c "
import json
d = json.load(open('cf-facts_describe.json'))
print('revision:', d['serviceConfig']['revision'])
print('updateTime:', d.get('updateTime'))
bucket = d['buildConfig']['source']['storageSource']['bucket']
obj = d['buildConfig']['source']['storageSource']['object']
gen = d['buildConfig']['source']['storageSource']['generation']
print('bucket:', bucket)
print('object:', obj)
print('generation:', gen)
print(f'gs://{bucket}/{obj}#{gen}' , file=open('archive_uri.txt','w'), end='')
"
ARCHIVE_URI=$(cat archive_uri.txt)
echo "archive uri: $ARCHIVE_URI"

echo "=== download archive by pinned generation ==="
mkdir -p live_archive
gcloud storage cp "$ARCHIVE_URI" live_archive/function-source.zip
cd live_archive && unzip -o -q function-source.zip && cd ..

echo "=== sha256 live archive (cf-facts relevant files) ==="
for f in helpers.py fetch_returns.py fetch_purchases.py main.py bq_ops.py config.py; do
  shasum -a 256 "live_archive/$f" 2>&1 || echo "MISSING in live archive: $f"
done

echo "=== sha256 code_repo master (same files) ==="
for f in helpers.py fetch_returns.py fetch_purchases.py main.py bq_ops.py config.py; do
  shasum -a 256 "code_repo/cf-facts/$f" 2>&1 || echo "MISSING in code_repo: $f"
done

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
