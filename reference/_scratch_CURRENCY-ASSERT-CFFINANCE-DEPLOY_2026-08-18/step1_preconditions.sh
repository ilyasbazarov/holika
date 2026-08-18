#!/usr/bin/env bash
set -uo pipefail
echo "=== UTC anchor (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list
SCRATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo; echo "=== П2. Живой describe cf-finance (обслуживающая ревизия + флаги для деплоя) ==="
gcloud functions describe cf-finance --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --format=json > "$SCRATCH/predeploy_describe.json" || { echo "FAIL: describe не отработал"; exit 1; }
python3 - <<'PY'
import json
d = json.load(open("reference/_scratch_CURRENCY-ASSERT-CFFINANCE-DEPLOY_2026-08-18/predeploy_describe.json"))
sc, bc = d.get("serviceConfig", {}), d.get("buildConfig", {})
ss = bc.get("source", {}).get("storageSource", {})
print("  обслуживающая ревизия :", sc.get("revision"))
print("  state                 :", d.get("state"))
print("  updateTime            :", d.get("updateTime"))
print("  runtime / entryPoint  :", bc.get("runtime"), "/", bc.get("entryPoint"))
print("  service account       :", sc.get("serviceAccountEmail"))
print("  memory / timeout      :", sc.get("availableMemory"), "/", sc.get("timeoutSeconds"))
print("  maxInstances / ingress:", sc.get("maxInstanceCount"), "/", sc.get("ingressSettings"))
print("  env vars              :", sc.get("environmentVariables"))
print("  архив                 :", f"gs://{ss.get('bucket')}/{ss.get('object')}", "generation", ss.get("generation"))
PY

echo; echo "=== П3a. Скачиваю АРХИВ обслуживающей ревизии (то, что реально работает в проде) ==="
GEN=$(python3 -c "import json;d=json.load(open('$SCRATCH/predeploy_describe.json'));s=d['buildConfig']['source']['storageSource'];print(s['generation'])")
BKT=$(python3 -c "import json;d=json.load(open('$SCRATCH/predeploy_describe.json'));s=d['buildConfig']['source']['storageSource'];print(s['bucket'])")
OBJ=$(python3 -c "import json;d=json.load(open('$SCRATCH/predeploy_describe.json'));s=d['buildConfig']['source']['storageSource'];print(s['object'])")
rm -rf "$SCRATCH/serving_archive"; mkdir -p "$SCRATCH/serving_archive"
gsutil cp "gs://$BKT/$OBJ#$GEN" "$SCRATCH/serving_source.zip" && \
  unzip -q -o "$SCRATCH/serving_source.zip" -d "$SCRATCH/serving_archive" && echo "  архив развёрнут"
echo "  состав архива:"; find "$SCRATCH/serving_archive" -type f | sed "s|$SCRATCH/serving_archive/|    |" | sort
echo "  sha256 файлов архива:"; (cd "$SCRATCH/serving_archive" && shasum -a 256 $(find . -type f | sort) | sed 's/^/    /')

echo; echo "=== П3b. Клонирую код-репо и ищу коммит, чей cf-finance равен архиву ==="
rm -rf "$SCRATCH/holika-prod"
git clone -q https://github.com/ilyasbazarov/holika-prod.git "$SCRATCH/holika-prod" && echo "  клон готов"
cd "$SCRATCH/holika-prod" && git fetch -q origin
echo "  голова master: $(git rev-parse master) — $(git log -1 --format='%ci %s' master)"
echo "  последние коммиты, трогавшие cf-finance:"
git log --format='    %h %ci %s' -5 -- cf-finance/ | cat
echo
echo "  сверка sha256 cf-finance по коммитам против архива:"
for c in $(git log --format=%h -8 -- cf-finance/); do
  for f in main.py invoices.py requirements.txt; do
    a=$(shasum -a 256 "$SCRATCH/serving_archive/$f" 2>/dev/null | cut -d' ' -f1)
    b=$(git show "$c:cf-finance/$f" 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
    [ "$a" = "$b" ] && echo "    $c $f СОВПАДАЕТ" || echo "    $c $f расходится"
  done
done
echo "=== UTC anchor (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
