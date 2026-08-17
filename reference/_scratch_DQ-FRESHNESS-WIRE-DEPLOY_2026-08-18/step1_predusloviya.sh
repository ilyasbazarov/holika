#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT=msklad-bi-prod
REGION=asia-east1
SCRATCH="$(cd "$(dirname "$0")" && pwd)"

echo
echo "=== П2: обслуживающая ревизия cf-dq (status.traffic) ==="
gcloud run services describe cf-dq --project="$PROJECT" --region="$REGION" --format="yaml(status.traffic)"

echo
echo "=== П3a: describe cf-dq (generation, storageSource) ==="
gcloud functions describe cf-dq --gen2 --region="$REGION" --project="$PROJECT" \
  --format="value(serviceConfig.revision,buildConfig.source.storageSource.bucket,buildConfig.source.storageSource.object,buildConfig.source.storageSource.generation)"

STORAGE_URI=$(gcloud functions describe cf-dq --gen2 --region="$REGION" --project="$PROJECT" \
  --format="value(buildConfig.source.storageSource.bucket,buildConfig.source.storageSource.object)" | tr '\t' '/')
GENERATION=$(gcloud functions describe cf-dq --gen2 --region="$REGION" --project="$PROJECT" \
  --format="value(buildConfig.source.storageSource.generation)")

echo
echo "=== П3b: скачивание и распаковка живого архива ==="
mkdir -p "$SCRATCH/live_archive"
gcloud storage cp "gs://${STORAGE_URI}#${GENERATION}" "$SCRATCH/live_archive/function-source.zip"
cd "$SCRATCH/live_archive"
unzip -o -q function-source.zip -d unzipped
echo "--- содержимое архива ---"
find unzipped -maxdepth 1 -type f -exec basename {} \;
echo "--- sha256 живого архива ---"
shasum -a 256 unzipped/*.py unzipped/requirements.txt 2>/dev/null | sort -k2

echo
echo "=== П3c: клон master код-репо для сверки ==="
rm -rf "$SCRATCH/master_clone"
git clone --quiet --branch master https://github.com/ilyasbazarov/holika-prod.git "$SCRATCH/master_clone"
echo "--- sha256 master код-репо (cf-dq/) ---"
shasum -a 256 "$SCRATCH/master_clone"/cf-dq/*.py "$SCRATCH/master_clone"/cf-dq/requirements.txt 2>/dev/null | sort -k2

echo
echo "=== П3d: побайтовое сравнение живого архива vs master ==="
for f in main.py config.py helpers.py requirements.txt; do
  if [ -f "$SCRATCH/live_archive/unzipped/$f" ] && [ -f "$SCRATCH/master_clone/cf-dq/$f" ]; then
    if cmp -s "$SCRATCH/live_archive/unzipped/$f" "$SCRATCH/master_clone/cf-dq/$f"; then
      echo "$f: IDENTICAL"
    else
      echo "$f: DRIFT (различаются)"
    fi
  else
    echo "$f: ОТСУТСТВУЕТ в одной из сторон"
  fi
done

echo
echo "=== П4: git diff --stat master vs holika-снапшот (не применено, только показ) ==="
cp "$(git -C /Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/DQ-FRESHNESS-WIRE-DEPLOY rev-parse --show-toplevel)/reference/code/cf-dq/main.py" "$SCRATCH/master_clone/cf-dq/main.py.holika"
diff -q "$SCRATCH/master_clone/cf-dq/main.py" "$SCRATCH/master_clone/cf-dq/main.py.holika" && echo "main.py: master == holika-снапшот (дельты нет)" || echo "main.py: master != holika-снапшот (есть дельта — ожидаемо, это и есть патч)"
rm -f "$SCRATCH/master_clone/cf-dq/main.py.holika"

echo
echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
