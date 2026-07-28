#!/usr/bin/env bash
set -euo pipefail
cd /Users/ilyasbazarov/Desktop/msklad_project/holika

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list --filter=status:ACTIVE --format='value(account)'

export MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
if [ -z "${MSKLAD_TOKEN}" ]; then
  echo "TOKEN EMPTY - stop"
  exit 1
fi
echo "token length (not value): ${#MSKLAD_TOKEN}"

python3 - <<'PYEOF'
import os, time, json
import requests

token = os.environ["MSKLAD_TOKEN"]
headers = {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}
BASE = "https://api.moysklad.ru/api/remap/1.2"

candidates = [
    ("report/profit/bysalesreturn?momentFrom=2026-05-01 00:00:00&momentTo=2026-06-01 00:00:00", "profit-bysalesreturn (возвраты покупателей)"),
    ("report/money/turnover?momentFrom=2026-05-01 00:00:00&momentTo=2026-06-01 00:00:00", "money-turnover"),
    ("report/counterparty/debt/all", "counterparty-debt-all"),
    ("entity/invoiceout?limit=1&expand=agent,state", "entity-invoiceout (level ii, для AR)"),
]

consecutive_401_or_empty = 0
for path, label in candidates:
    url = f"{BASE}/{path}"
    print(f"\n--- CANDIDATE: {label} ---")
    print(f"URL: {url}")
    try:
        resp = requests.get(url, headers=headers, timeout=90)
    except Exception as e:
        print(f"EXCEPTION: {e}")
        continue
    time.sleep(0.25)
    status = resp.status_code
    body = resp.text
    print(f"HTTP {status}, bytes={len(body)}")
    is_401_or_empty = (status == 401) or (len(body.strip()) == 0)
    consecutive_401_or_empty = consecutive_401_or_empty + 1 if is_401_or_empty else 0
    if consecutive_401_or_empty >= 3:
        print("STOP CONDITION reached")
        break
    try:
        parsed = resp.json()
        top_keys = list(parsed.keys()) if isinstance(parsed, dict) else f"<list len={len(parsed)}>"
        print(f"top-level keys: {top_keys}")
        print(f"snippet: {json.dumps(parsed, ensure_ascii=False)[:600]}")
    except Exception as e:
        print(f"NOT JSON: {e}; raw: {body[:400]}")
PYEOF

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list --filter=status:ACTIVE --format='value(account)'
