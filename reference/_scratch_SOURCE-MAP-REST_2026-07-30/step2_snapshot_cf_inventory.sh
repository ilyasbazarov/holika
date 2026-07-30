#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

WORKDIR="$(dirname "$0")/cf-inventory-extract"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "=== скачивание архива (путь из describe Шага 1) ==="
gcloud storage cp "gs://gcf-v2-sources-420804682491-asia-east1/cf-inventory/function-source.zip#1778486115150159" ./function-source.zip 2>&1

echo "=== распаковка ==="
unzip -o function-source.zip -d unpacked 2>&1

echo "=== содержимое ==="
find unpacked -type f 2>&1

echo "=== sha256 по каждому файлу ==="
find unpacked -type f -exec sha256sum {} \; 2>&1

gcloud auth list
date -u

echo "PATH_PRINTED: $WORKDIR"
