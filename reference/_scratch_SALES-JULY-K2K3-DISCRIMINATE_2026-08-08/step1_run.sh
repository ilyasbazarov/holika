#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== UTC-якорь (начало) ==="
date -u
echo "=== личность вызывающего (начало) ==="
gcloud auth list

echo "=== чтение токена (значение не печатается) ==="
export MSKLAD_TOKEN
MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"

python3 step1_fetch_demands.py

echo "=== проверка: значение токена не просочилось в выгруженные файлы ==="
if grep -rF -- "$MSKLAD_TOKEN" . ; then
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
