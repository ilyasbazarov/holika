#!/usr/bin/env bash
set -uo pipefail
echo "=== UTC anchor (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list
SCRATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
URI=$(python3 -c "import json;d=json.load(open('$SCRATCH/postdeploy_describe.json'));print(d['serviceConfig']['uri'])")
echo "  URI: $URI"
TOKEN=$(gcloud auth print-identity-token --impersonate-service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com --audiences="${URI}")
echo; echo "=== Приёмка 3. Вызов режима payments (пустое тело — режим по умолчанию) ==="
curl -sS -w "\nHTTP_STATUS=%{http_code}\n" --max-time 900 -X POST "${URI}" -H "Authorization: Bearer ${TOKEN}"
echo "=== UTC anchor (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
