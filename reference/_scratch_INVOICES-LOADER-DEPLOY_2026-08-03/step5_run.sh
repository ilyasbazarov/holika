#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list
export MSKLAD_TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)
export GCLOUD_ACCESS_TOKEN=$(gcloud auth print-access-token)
source "$(dirname "$0")/venv/bin/activate"
python3 "$(dirname "$0")/step5_staging_run.py"
echo "=== ПРОВЕРКА: секрет не попал в файлы сессии ==="
if grep -rF -- "${MSKLAD_TOKEN}" "$(dirname "$0")" --exclude-dir=venv || grep -rF -- "${GCLOUD_ACCESS_TOKEN}" "$(dirname "$0")" --exclude-dir=venv; then
  echo "СТОП: НАЙДЕН ТОКЕН В ФАЙЛАХ"
else
  echo "OK: токен в файлах сессии не найден"
fi
unset MSKLAD_TOKEN
unset GCLOUD_ACCESS_TOKEN
date -u
gcloud auth list
