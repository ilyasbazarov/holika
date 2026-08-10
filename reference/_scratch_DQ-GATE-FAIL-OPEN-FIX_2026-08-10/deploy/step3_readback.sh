#!/usr/bin/env bash
# ADR-152 §5(1) — read-back архива новой ревизии cf-dq. Read-only, класс A.
set -euo pipefail

BRANCH_DIR="$1"

echo "=== UTC-якорь (начало) ==="
date -u
echo
echo "=== личность вызывающего (начало) ==="
gcloud auth list

WORKDIR="$(mktemp -d)"
echo
echo "=== рабочий каталог: $WORKDIR ==="

echo
echo "=== describe cf-dq (после деплоя) ==="
gcloud functions describe cf-dq --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --format=json > "$WORKDIR/describe.json"
python3 -c "
import json
d = json.load(open('$WORKDIR/describe.json'))
sc = d.get('serviceConfig', {})
bc = d.get('buildConfig', {})
print('revision:', sc.get('revision'))
print('updateTime:', d.get('updateTime'))
print('state:', d.get('state'))
print('storageSource:', bc.get('source', {}).get('storageSource', {}))
"

BUCKET_URI=$(python3 -c "
import json
d = json.load(open('$WORKDIR/describe.json'))
ss = d['buildConfig']['source']['storageSource']
print(f\"gs://{ss['bucket']}/{ss['object']}#{ss['generation']}\")
")
echo
echo "=== read-back архива: $BUCKET_URI ==="
gcloud storage cp "$BUCKET_URI" "$WORKDIR/function-source.zip"
mkdir -p "$WORKDIR/unzipped"
unzip -o -q "$WORKDIR/function-source.zip" -d "$WORKDIR/unzipped"

echo
echo "--- состав архива (ожидание: 5 исполняемых файлов + .gcloudignore, БЕЗ patch_dq.py и вложенных zip) ---"
ls -la "$WORKDIR/unzipped"

echo
echo "--- sha256 нового архива ---"
( cd "$WORKDIR/unzipped" && shasum -a 256 main.py config.py helpers.py requirements.txt 2>/dev/null )

echo
echo "--- sha256 ветки деплоя (ожидаемое) ---"
( cd "$BRANCH_DIR/cf-dq" && shasum -a 256 main.py config.py helpers.py requirements.txt )

echo
echo "--- patch_dq.py в новом архиве? (ожидание: НЕТ, исключён .gcloudignore) ---"
[ -f "$WORKDIR/unzipped/patch_dq.py" ] && echo "ПРИСУТСТВУЕТ (неожиданно)" || echo "отсутствует (как ожидалось)"

echo
echo "--- вложенные архивы src.zip/function-source*.zip в новом архиве? (ожидание: НЕТ) ---"
find "$WORKDIR/unzipped" -iname "*.zip" -o -iname "src.zip"

echo
echo "=== путь рабочего каталога (не удаляется, ADR-043) ==="
echo "$WORKDIR"

echo
echo "=== UTC-якорь (конец) ==="
date -u
echo
echo "=== личность вызывающего (конец) ==="
gcloud auth list
