#!/usr/bin/env bash
set -euo pipefail

SCRATCH="reference/_scratch_PARITY-STOCK-INTRANSIT_2026-08-04"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo "=== step1: our side date_snapshot (MAX) ==="
bq query --use_legacy_sql=false --format=prettyjson \
  'SELECT MAX(date_snapshot) AS max_snapshot FROM `msklad-bi-prod.core.fact_inventory`' \
  | tee "$SCRATCH/step1_max_snapshot.json"

MAX_SNAPSHOT=$(python3 -c "import json;print(json.load(open('$SCRATCH/step1_max_snapshot.json'))[0]['max_snapshot'])")
echo "MAX_SNAPSHOT=$MAX_SNAPSHOT"

echo "=== step2: live GET report/stock/all (immediately after step1) ==="
echo "GET_START_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

export MSKLAD_TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)
echo "token length: ${#MSKLAD_TOKEN}"

python3 - "$SCRATCH" <<'PYEOF'
import json, os, sys, time, urllib.request

scratch = sys.argv[1]
token = os.environ["MSKLAD_TOKEN"]
base = "https://api.moysklad.ru/api/remap/1.2/report/stock/all"
limit = 1000
offset = 0
all_rows = []
page = 0
while True:
    url = f"{base}?limit={limit}&offset={offset}&stockMode=all&quantityMode=all"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "Accept-Encoding": "gzip",
    })
    with urllib.request.urlopen(req) as resp:
        status = resp.status
        body = resp.read()
        import gzip
        if resp.headers.get("Content-Encoding") == "gzip":
            body = gzip.decompress(body)
    data = json.loads(body)
    with open(f"{scratch}/step2_stock_all_page{page}.json", "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    rows = data.get("rows", [])
    all_rows.extend(rows)
    meta_size = data.get("meta", {}).get("size")
    print(f"page={page} status={status} rows_in_page={len(rows)} meta.size={meta_size}")
    if len(rows) < limit:
        break
    offset += limit
    page += 1
    time.sleep(0.25)

total_stock = sum(float(r.get("stock") or 0) for r in all_rows)
result = {
    "n_rows": len(all_rows),
    "sum_stock": round(total_stock, 2),
}
with open(f"{scratch}/step2_stock_all_summary.json", "w") as f:
    json.dump(result, f, ensure_ascii=False, indent=2)
print("SUMMARY", result)
PYEOF

echo "GET_END_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
unset MSKLAD_TOKEN

echo "=== step3: our side, same partition (bq query) ==="
bq query --use_legacy_sql=false --format=prettyjson \
  "SELECT COUNT(*) AS n_rows, SUM(stock) AS sum_stock FROM \`msklad-bi-prod.core.fact_inventory\` WHERE date_snapshot = '$MAX_SNAPSHOT'" \
  | tee "$SCRATCH/step3_our_side.json"

echo "=== step3b: marts.inventory_health same snapshot, for cross-check ==="
bq query --use_legacy_sql=false --format=prettyjson \
  "SELECT COUNT(*) AS n_rows, SUM(stock) AS sum_stock, MAX(date_snapshot) AS date_snapshot FROM \`msklad-bi-prod.marts.inventory_health\` WHERE date_snapshot = '$MAX_SNAPSHOT'" \
  | tee "$SCRATCH/step3b_mart_side.json"

echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u

echo "SCRATCH_PATH=$SCRATCH"
