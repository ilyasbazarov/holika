#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== gcloud functions describe cf-facts (post-deploy) ==="
gcloud functions describe cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod --format=json > cf-facts_describe_post.json
python3 -c "
import json
d = json.load(open('cf-facts_describe_post.json'))
print('revision:', d['serviceConfig']['revision'])
bucket = d['buildConfig']['source']['storageSource']['bucket']
obj = d['buildConfig']['source']['storageSource']['object']
gen = d['buildConfig']['source']['storageSource']['generation']
open('archive_uri_post.txt','w').write(f'gs://{bucket}/{obj}#{gen}')
print('archive:', f'gs://{bucket}/{obj}#{gen}')
"
ARCHIVE_URI=$(cat archive_uri_post.txt)

echo "=== download new archive by pinned generation ==="
mkdir -p live_archive_post
gcloud storage cp "$ARCHIVE_URI" live_archive_post/function-source.zip
cd live_archive_post && unzip -o -q function-source.zip && cd ..

echo "=== мусор в архиве? ==="
find live_archive_post -name "*.bak" -o -name "__pycache__" -o -name "*.pyc" -o -name "src.zip" -o -name "patch_*.py"
echo "(пусто выше = мусора нет)"

echo "=== sha256 нового живого архива (все файлы функции) ==="
for f in helpers.py fetch_returns.py fetch_purchases.py main.py bq_ops.py config.py requirements.txt; do
  shasum -a 256 "live_archive_post/$f"
done

echo "=== sha256 ветки deploy/cf-facts-2026-08-09-moment-zone (те же файлы) ==="
for f in helpers.py fetch_returns.py fetch_purchases.py main.py bq_ops.py config.py requirements.txt; do
  shasum -a 256 "code_repo/cf-facts/$f"
done

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
