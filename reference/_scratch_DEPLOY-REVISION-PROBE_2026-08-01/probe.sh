#!/usr/bin/env bash
# DEPLOY-REVISION-PROBE · класс A, только чтение облака (ADR-076 §1)
# Форма логирования ADR-055/ADR-063: date -u и gcloud auth list ПЕРВОЙ И ПОСЛЕДНЕЙ командой.
set -u

SCRATCH="$(cd "$(dirname "$0")" && pwd)"
REPO="/Users/ilyasbazarov/Desktop/msklad_project/holika"
PROJECT="msklad-bi-prod"
REGION="asia-east1"
FN="cf-finance"

echo "=== ЯКОРЬ НАЧАЛА ==="
date -u
gcloud auth list 2>&1
gcloud config get-value project 2>&1

echo
echo "=== ШАГ 1. Какая ревизия обслуживает трафик СЕЙЧАС ==="
gcloud run services describe "$FN" --region="$REGION" --project="$PROJECT" \
  --format="value(status.latestReadyRevisionName, status.traffic)" 2>&1
echo "--- полный список ревизий с долей трафика ---"
gcloud run revisions list --service="$FN" --region="$REGION" --project="$PROJECT" \
  --format="table(metadata.name, status.conditions[0].status, metadata.creationTimestamp)" 2>&1

echo
echo "=== ШАГ 2. Откуда взят исходник задеплоенной сборки ==="
gcloud functions describe "$FN" --region="$REGION" --project="$PROJECT" --gen2 \
  --format="json(buildConfig.source.storageSource, buildConfig.build, serviceConfig.revision, updateTime)" \
  2>&1 | tee "$SCRATCH/describe.json"

BUCKET=$(python3 -c "import json,sys;d=json.load(open('$SCRATCH/describe.json'));print(d['buildConfig']['source']['storageSource'].get('bucket',''))" 2>/dev/null)
OBJECT=$(python3 -c "import json,sys;d=json.load(open('$SCRATCH/describe.json'));print(d['buildConfig']['source']['storageSource'].get('object',''))" 2>/dev/null)
GEN=$(python3 -c "import json,sys;d=json.load(open('$SCRATCH/describe.json'));print(d['buildConfig']['source']['storageSource'].get('generation',''))" 2>/dev/null)
echo "bucket=[$BUCKET] object=[$OBJECT] generation=[$GEN]"

if [ -z "$BUCKET" ] || [ -z "$OBJECT" ]; then
  echo "ГЭП НАБЛЮДЕНИЯ: storageSource не разобран — дальше не идём, вывод выше недостоверен"
else
  echo
  echo "=== ШАГ 3. Скачать архив исходников ИМЕННО этой сборки (по generation) ==="
  SRC="gs://${BUCKET}/${OBJECT}"
  if [ -n "$GEN" ]; then SRC="${SRC}#${GEN}"; fi
  echo "источник: $SRC"
  gcloud storage cp "$SRC" "$SCRATCH/function-source.zip" --project="$PROJECT" 2>&1
  ls -l "$SCRATCH/function-source.zip" 2>&1
  shasum -a 256 "$SCRATCH/function-source.zip" 2>&1

  echo
  echo "=== ШАГ 4. Распаковать и посчитать sha256 main.py задеплоенной сборки ==="
  rm -rf "$SCRATCH/src" && mkdir -p "$SCRATCH/src"
  unzip -o -q "$SCRATCH/function-source.zip" -d "$SCRATCH/src" 2>&1
  find "$SCRATCH/src" -maxdepth 2 -type f | sed "s|$SCRATCH/src/||" 2>&1
  echo "--- sha256 ---"
  shasum -a 256 "$SCRATCH/src/main.py" 2>&1

  echo
  echo "=== ШАГ 5. Конвертер задеплоенной сборки: есть ли множитель на курс ==="
  echo "--- все строки с rate.value / rate[ / rateValue ---"
  grep -n "rate\.value\|rate\[\|rateValue\|rate_value" "$SCRATCH/src/main.py" 2>&1 || echo "(совпадений нет)"
  echo "--- окрестность строки 69 (контекст 12 строк) ---"
  sed -n '57,81p' "$SCRATCH/src/main.py" 2>&1
fi

echo
echo "=== ШАГ 6. sha256 снимка-провенанса в репо (до-фиксовая версия по записи) ==="
shasum -a 256 "$REPO/reference/code/cf-finance/main.py" 2>&1
echo "--- есть ли множитель на курс в снимке ---"
grep -n "rate\.value\|rate\[\|rateValue\|rate_value" "$REPO/reference/code/cf-finance/main.py" 2>&1 || echo "(совпадений нет)"

echo
echo "=== ШАГ 7. Диск Cloud Shell — доступен ли отсюда ==="
echo "(машина сессии — локальный Mac владельца; диск Cloud Shell есть удалённая машина."
echo " Если доступа нет, третья колонка таблицы приёмки остаётся незаполненной С НАЗВАННОЙ ПРИЧИНОЙ,"
echo " вердикт по Q-95 при этом выводим из сравнения «задеплоенное против снимка».)"

echo
echo "=== ЯКОРЬ КОНЦА ==="
date -u
gcloud auth list 2>&1
