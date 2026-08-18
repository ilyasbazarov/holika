#!/usr/bin/env bash
set -uo pipefail
echo "=== UTC anchor (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list
SCRATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; REPO="$SCRATCH/holika-prod"
echo; echo "=== Приёмка 1. Read-back: скачиваю АРХИВ новой ревизии по generation ==="
gcloud functions describe cf-finance --gen2 --region=asia-east1 --project=msklad-bi-prod --format=json > "$SCRATCH/postdeploy_describe.json"
GEN=$(python3 -c "import json;d=json.load(open('$SCRATCH/postdeploy_describe.json'));print(d['buildConfig']['source']['storageSource']['generation'])")
BKT=$(python3 -c "import json;d=json.load(open('$SCRATCH/postdeploy_describe.json'));print(d['buildConfig']['source']['storageSource']['bucket'])")
OBJ=$(python3 -c "import json;d=json.load(open('$SCRATCH/postdeploy_describe.json'));print(d['buildConfig']['source']['storageSource']['object'])")
REV=$(python3 -c "import json;d=json.load(open('$SCRATCH/postdeploy_describe.json'));print(d['serviceConfig']['revision'])")
echo "  обслуживающая ревизия: $REV, generation: $GEN"
rm -rf "$SCRATCH/new_revision_archive"; mkdir -p "$SCRATCH/new_revision_archive"
gsutil -q cp "gs://$BKT/$OBJ#$GEN" "$SCRATCH/new_source.zip" && unzip -q -o "$SCRATCH/new_source.zip" -d "$SCRATCH/new_revision_archive"
echo "  состав архива:"; (cd "$SCRATCH/new_revision_archive" && find . -type f | sort | sed 's/^/    /')
echo; echo "  побайтовая сверка архив ↔ ветка деплоя:"
ALL=1
for f in main.py invoices.py requirements.txt; do
  a=$(shasum -a 256 "$SCRATCH/new_revision_archive/$f" | cut -d' ' -f1)
  b=$(shasum -a 256 "$REPO/cf-finance/$f" | cut -d' ' -f1)
  if [ "$a" = "$b" ]; then echo "    $f СОВПАДАЕТ  $a"; else echo "    $f РАСХОДИТСЯ ($a vs $b)"; ALL=0; fi
done
echo "  ALL_MATCH=$ALL"
echo; echo "  мусор в архиве (.bak/__pycache__/.pyc) — ожидание: ничего:"
find "$SCRATCH/new_revision_archive" \( -name '*.bak' -o -name '__pycache__' -o -name '*.pyc' \) | sed 's/^/    /' || true
echo; echo "=== Приёмка 4. Детекция присутствует в ВЫЛОЖЕННОМ коде (греп по архиву, с печатью строк) ==="
grep -n "INGEST-CURRENCY-ASSERT\|timeout=90\|raise_for_status\|НЕ выполнялась" "$SCRATCH/new_revision_archive/main.py"
echo; echo "=== Приёмка 2. Трафик ==="
gcloud run services describe cf-finance --region=asia-east1 --project=msklad-bi-prod --format="value(status.traffic)"
echo "=== UTC anchor (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
