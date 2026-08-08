#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."

echo "=== UTC-якорь (начало) ==="
date -u
echo "=== личность вызывающего (начало) ==="
gcloud auth list

echo "=== чтение токена (значение не печатается) ==="
export MSKLAD_TOKEN
MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"

python3 reference/_scratch_SALES-CHANNEL-NULL-DEMAND_2026-08-08/step1_live_get.py

echo "=== проверка: значение токена не просочилось в файлы сессии ==="
if grep -rF -- "$MSKLAD_TOKEN" reference/_scratch_SALES-CHANNEL-NULL-DEMAND_2026-08-08/ ; then
  echo "СТОП: значение токена найдено в файлах сессии" >&2
  exit 1
else
  echo "OK: токен не найден в файлах сессии"
fi

unset MSKLAD_TOKEN

echo "=== личность вызывающего (конец) ==="
gcloud auth list
echo "=== UTC-якорь (конец) ==="
date -u
