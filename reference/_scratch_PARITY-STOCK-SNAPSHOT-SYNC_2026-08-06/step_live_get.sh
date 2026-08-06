#!/usr/bin/env bash
set -uo pipefail
echo "=== date -u (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list

TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)

OUTFILE="reference/_scratch_PARITY-STOCK-SNAPSHOT-SYNC_2026-08-06/live_get_stock_all_raw.ndjson"
> "$OUTFILE"
OFFSET=0
PAGE=1000
TOTAL=0
while true; do
  RESP=$(curl -s --compressed \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept-Encoding: gzip" \
    "https://api.moysklad.ru/api/remap/1.2/report/stock/all?stockMode=all&quantityMode=all&limit=${PAGE}&offset=${OFFSET}")
  echo "$RESP" >> "$OUTFILE"
  ROWS=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('rows',[])))")
  echo "offset=${OFFSET} rows=${ROWS}"
  TOTAL=$((TOTAL+ROWS))
  if [ "$ROWS" -lt "$PAGE" ]; then break; fi
  OFFSET=$((OFFSET+PAGE))
  sleep 0.3
done
echo "TOTAL_ROWS=${TOTAL}"

TOKEN_TAIL="${TOKEN: -6}"
echo "=== token leak check (token+grep one command) ==="
grep -r "$TOKEN" reference/_scratch_PARITY-STOCK-SNAPSHOT-SYNC_2026-08-06/ 2>/dev/null | grep -v "live_get_stock_all_raw.ndjson" | grep -c "$TOKEN" || echo "0 matches outside raw response file (expected: token appears only in Authorization header of the request itself, never persisted to disk except possibly page bodies if echoed — verifying)"

unset TOKEN

echo "=== date -u (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
