#!/usr/bin/env bash
set -euo pipefail
cd /Users/ilyasbazarov/Desktop/msklad_project/holika

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list --filter=status:ACTIVE --format='value(account)'

echo "=== read token into env var (not printed) ==="
export MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
if [ -z "${MSKLAD_TOKEN}" ]; then
  echo "TOKEN EMPTY - stop"
  exit 1
fi
echo "token length (not value): ${#MSKLAD_TOKEN}"

python3 - <<'PYEOF'
import os, time, json, sys
import requests

token = os.environ["MSKLAD_TOKEN"]
headers = {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}

BASE = "https://api.moysklad.ru/api/remap/1.2"

# Candidate report-API endpoints, gathered from МойСклад JSON API 1.2 documentation
# structure (report group). Period filter: May-2026 (momentFrom/momentTo), or
# last closed month where periodicity does not apply. NOT invented by page name.
candidates = [
    ("report/profit/byproduct?momentFrom=2026-05-01 00:00:00&momentTo=2026-06-01 00:00:00", "profit-byproduct (прибыльность по товарам)"),
    ("report/profit/bycounterparty?momentFrom=2026-05-01 00:00:00&momentTo=2026-06-01 00:00:00", "profit-bycounterparty (прибыльность по контрагентам)"),
    ("report/sales/byproduct?momentFrom=2026-05-01 00:00:00&momentTo=2026-06-01 00:00:00", "sales-byproduct"),
    ("report/sales/bycounterparty?momentFrom=2026-05-01 00:00:00&momentTo=2026-06-01 00:00:00", "sales-bycounterparty"),
    ("report/counterparty/debt", "counterparty-debt (задолженность контрагентов / дебиторка)"),
    ("report/money/plotseries?momentFrom=2026-05-01 00:00:00&momentTo=2026-06-01 00:00:00&interval=day", "money-plotseries"),
    ("report/money/byaccount", "money-byaccount"),
    ("report/stock/all", "stock-all (остатки)"),
    ("report/stock/bystore", "stock-bystore"),
    ("report/turnover/all?momentFrom=2026-05-01 00:00:00&momentTo=2026-06-01 00:00:00", "turnover-all (обороты)"),
    ("report/dashboard/money", "dashboard-money"),
    ("report/dashboard/orders", "dashboard-orders"),
]

results = []
consecutive_401_or_empty = 0
for path, label in candidates:
    url = f"{BASE}/{path}"
    print(f"\n--- CANDIDATE: {label} ---")
    print(f"URL: {url}")
    try:
        resp = requests.get(url, headers=headers, timeout=90)
    except Exception as e:
        print(f"EXCEPTION: {e}")
        results.append((label, url, "EXCEPTION", str(e)))
        continue
    time.sleep(0.25)
    status = resp.status_code
    body = resp.text
    print(f"HTTP {status}, bytes={len(body)}")
    is_401_or_empty = (status == 401) or (len(body.strip()) == 0)
    if is_401_or_empty:
        consecutive_401_or_empty += 1
    else:
        consecutive_401_or_empty = 0
    if consecutive_401_or_empty >= 3:
        print("STOP CONDITION: 3+ consecutive 401/empty responses - auth degradation, aborting run cleanly.")
        results.append((label, url, status, body[:500]))
        break
    try:
        parsed = resp.json()
        top_keys = list(parsed.keys()) if isinstance(parsed, dict) else f"<list len={len(parsed)}>"
        print(f"top-level keys: {top_keys}")
        snippet = json.dumps(parsed, ensure_ascii=False)[:800]
        print(f"snippet: {snippet}")
    except Exception as e:
        print(f"NOT JSON / parse error: {e}")
        print(f"raw first 500 chars: {body[:500]}")
    results.append((label, url, status, body[:500]))

print("\n=== SUMMARY ===")
for label, url, status, body_snip in results:
    print(f"{label} | {url} | status={status}")
PYEOF

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list --filter=status:ACTIVE --format='value(account)'
