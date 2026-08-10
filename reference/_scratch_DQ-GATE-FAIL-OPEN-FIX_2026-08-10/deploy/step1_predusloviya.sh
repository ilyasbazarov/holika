#!/usr/bin/env bash
# ADR-152 §6 — предусловия ДО правки ветки деплоя. Read-only, класс A.
# (i) сверка живой ревизии cf-dq с ожиданием MANIFEST.md / 11_INFRA_FACTS.md
# (ii) проверка .gcloudignore, действующего для --source cf-dq/ в код-репо holika-prod
set -euo pipefail

echo "=== UTC-якорь (начало) ==="
date -u

echo
echo "=== личность вызывающего (начало) ==="
gcloud auth list

WORKDIR="$(mktemp -d)"
echo
echo "=== рабочий каталог: $WORKDIR ==="

echo
echo "=== (i) gcloud functions describe cf-dq ==="
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
print('entryPoint:', bc.get('entryPoint'))
print('runtime:', bc.get('runtime'))
"

echo
echo "=== (i) read-back архива живой ревизии ==="
BUCKET_URI=$(python3 -c "
import json
d = json.load(open('$WORKDIR/describe.json'))
ss = d['buildConfig']['source']['storageSource']
print(f\"gs://{ss['bucket']}/{ss['object']}#{ss['generation']}\")
")
echo "storageSource: $BUCKET_URI"
gcloud storage cp "$BUCKET_URI" "$WORKDIR/function-source.zip"
mkdir -p "$WORKDIR/unzipped"
unzip -o -q "$WORKDIR/function-source.zip" -d "$WORKDIR/unzipped"
echo
echo "--- sha256 живого архива ---"
( cd "$WORKDIR/unzipped" && shasum -a 256 main.py config.py helpers.py requirements.txt patch_dq.py 2>/dev/null || true )

echo
echo "--- ожидаемые sha256 (reference/code/cf-dq/MANIFEST.md, переподтверждено 2026-08-02T20:50:05Z) ---"
cat <<'EOF'
main.py           9693010ae04cd14859b7ed53bba25fa28cbf1962a9b127c012a75d521d86ea09
helpers.py        0f335877c29d9c18c5e8d9617ab38768c6d2ba01986d178abaff92d4ce9dd146
config.py         7a818364c78fdf21cb32d8ce52d54da0972a6de511d1f6023fb8ea812fc543b6
requirements.txt  587133daa6a4c31e57bfd84c371ea4d6e0831e69ed66babf12c15dbebfd6b516
patch_dq.py       bb1bc968b81573431c5f7c912539918d51d1ee18cd34b040a109ccf213eeb22a
EOF

echo
echo "=== (ii) .gcloudignore в код-репо holika-prod для cf-dq/ ==="
git clone --depth=1 https://github.com/ilyasbazarov/holika-prod.git "$WORKDIR/holika-prod" 2>&1 | tail -5
echo "--- листинг cf-dq/ в master ---"
ls -la "$WORKDIR/holika-prod/cf-dq/" 2>&1 || echo "КАТАЛОГ cf-dq/ НЕ НАЙДЕН В master"
echo "--- .gcloudignore (корень) ---"
cat "$WORKDIR/holika-prod/.gcloudignore" 2>&1 || echo ".gcloudignore В КОРНЕ НЕ НАЙДЕН"
echo "--- .gcloudignore (cf-dq/) ---"
cat "$WORKDIR/holika-prod/cf-dq/.gcloudignore" 2>&1 || echo ".gcloudignore В cf-dq/ НЕ НАЙДЕН"

echo
echo "=== (i) sha256 main.py текущего master (для сравнения с живым архивом) ==="
shasum -a 256 "$WORKDIR/holika-prod/cf-dq/main.py" 2>&1 || echo "main.py В master НЕ НАЙДЕН"

echo
echo "=== путь рабочего каталога (не удаляется, ADR-043) ==="
echo "$WORKDIR"

echo
echo "=== UTC-якорь (конец) ==="
date -u

echo
echo "=== личность вызывающего (конец) ==="
gcloud auth list
