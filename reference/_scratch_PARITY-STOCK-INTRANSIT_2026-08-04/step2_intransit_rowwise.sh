#!/usr/bin/env bash
set -euo pipefail

SCRATCH="reference/_scratch_PARITY-STOCK-INTRANSIT_2026-08-04"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

export MSKLAD_TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)
echo "token length: ${#MSKLAD_TOKEN}"

echo "GET_START_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

python3 - "$SCRATCH" <<'PYEOF'
import json, os, sys, time, gzip, urllib.request

scratch = sys.argv[1]
token = os.environ["MSKLAD_TOKEN"]
base = "https://api.moysklad.ru/api/remap/1.2"

PURCHASE_ORDER_STATES = {
    "491d6da5-8b37-11ef-0a80-0762000253a8": "В пути",
    "491d62b6-8b37-11ef-0a80-0762000253a7": "Прибыл",
    "87b7a192-349f-11f1-0a80-1a0f000384c2": "Прибыл частично",
    "87b7a5e5-349f-11f1-0a80-1a0f000384c3": "Отменен",
}
TARGET_STATUSES = {"В пути", "Прибыл частично"}

def parse_href(href):
    if not href:
        return None
    return href.rstrip("/").split("/")[-1]

def get(url, headers, tries=0):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        status = resp.status
        body = resp.read()
        if resp.headers.get("Content-Encoding") == "gzip":
            body = gzip.decompress(body)
    return status, json.loads(body)

def paginate_entity(path, params=None, extra_headers=None):
    headers = {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}
    if extra_headers:
        headers.update(extra_headers)
    limit = 100
    offset = 0
    all_rows = []
    qs = ""
    if params:
        qs = "&" + "&".join(f"{k}={v}" for k, v in params.items())
    while True:
        url = f"{base}/{path}?limit={limit}&offset={offset}{qs}"
        status, data = get(url, headers)
        rows = data.get("rows", [])
        all_rows.extend(rows)
        meta_size = data.get("meta", {}).get("size")
        if len(rows) < limit:
            break
        offset += limit
        time.sleep(0.25)
    return all_rows, meta_size

# Step 6a: fetch ALL orders (no state filter available server-side by name; same approach as prod ingest)
orders, meta_size = paginate_entity("entity/purchaseorder", params={"expand": "agent,state"})
with open(f"{scratch}/step2_purchaseorder_all.json", "w") as f:
    json.dump({"meta_size": meta_size, "n_fetched": len(orders)}, f, indent=2)
print(f"orders fetched: {len(orders)} (meta.size={meta_size})")

target_orders = []
for o in orders:
    state_href = o.get("state", {}).get("meta", {}).get("href", "")
    status_id = parse_href(state_href)
    status_name = PURCHASE_ORDER_STATES.get(status_id, "Неизвестен")
    if status_name in TARGET_STATUSES:
        target_orders.append({"order": o, "status_id": status_id, "status_name": status_name})

print(f"target orders (В пути / Прибыл частично): {len(target_orders)}")
by_status = {}
for t in target_orders:
    by_status[t["status_name"]] = by_status.get(t["status_name"], 0) + 1
print("by_status:", by_status)

with open(f"{scratch}/step2_target_order_ids.json", "w") as f:
    json.dump([t["order"]["id"] for t in target_orders], f, indent=2)

# Step 6b: positions per target order
all_positions = []
time.sleep(0.25)
for i, t in enumerate(target_orders):
    order = t["order"]
    order_id = order["id"]
    positions, pmeta = paginate_entity(f"entity/purchaseorder/{order_id}/positions")
    with open(f"{scratch}/step2_positions_order_{order_id}.json", "w") as f:
        json.dump(positions, f, ensure_ascii=False, indent=2)

    currency_rate = order.get("rate", {}).get("value")
    for pos in positions:
        pos_id = pos.get("id")
        if not pos_id:
            continue
        product_id = parse_href(pos.get("assortment", {}).get("meta", {}).get("href", ""))
        quantity_ordered = pos.get("quantity", 0.0)
        quantity_shipped = pos.get("shipped", 0.0)
        quantity_in_transit = pos.get("inTransit", 0.0)
        raw_price = pos.get("price")
        has_rate = currency_rate is not None
        price_kgs = (raw_price or 0) / 100.0 * (currency_rate if has_rate else 1.0)
        discount = pos.get("discount", 0.0)
        sum_kgs = round(price_kgs * quantity_ordered * (1.0 - discount / 100.0), 4)
        in_transit_sum_kgs = round(price_kgs * quantity_in_transit * (1.0 - discount / 100.0), 4)
        all_positions.append({
            "purchase_order_id": order_id,
            "order_name": order.get("name"),
            "position_id": pos_id,
            "product_id": product_id,
            "quantity_ordered": quantity_ordered,
            "quantity_shipped": quantity_shipped,
            "quantity_in_transit": quantity_in_transit,
            "price": raw_price,
            "has_rate_value": has_rate,
            "currency_rate": currency_rate,
            "discount": discount,
            "sum_kgs": sum_kgs,
            "in_transit_sum_kgs": in_transit_sum_kgs,
            "status_id": t["status_id"],
            "status_name": t["status_name"],
        })
    print(f"[{i+1}/{len(target_orders)}] order {order_id}: {len(positions)} positions")
    time.sleep(0.25)

with open(f"{scratch}/step2_all_positions.json", "w") as f:
    json.dump(all_positions, f, ensure_ascii=False, indent=2)

n_missing_rate = sum(1 for p in all_positions if not p["has_rate_value"])
sum_in_transit = round(sum(p["in_transit_sum_kgs"] for p in all_positions), 2)
print(f"total positions: {len(all_positions)}, missing rate.value: {n_missing_rate}, SUM(in_transit_sum_kgs)={sum_in_transit}")

with open(f"{scratch}/step2_source_summary.json", "w") as f:
    json.dump({
        "n_target_orders": len(target_orders),
        "n_positions_total": len(all_positions),
        "n_missing_rate_value": n_missing_rate,
        "sum_in_transit_sum_kgs": sum_in_transit,
        "by_status": by_status,
    }, f, indent=2)
PYEOF

echo "GET_END_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
unset MSKLAD_TOKEN

TARGET_IDS=$(python3 -c "import json; ids=json.load(open('$SCRATCH/step2_target_order_ids.json')); print(','.join('\"%s\"' % i for i in ids))")

echo "=== step8: our side, same 19 (or N) order ids, from core.fact_purchases ==="
bq query --use_legacy_sql=false --format=prettyjson \
  "SELECT purchase_order_id, position_id, product_id, quantity_ordered, quantity_shipped, quantity_in_transit, price_kgs, discount, sum_kgs, in_transit_sum_kgs, currency_rate, status_id, status_name FROM \`msklad-bi-prod.core.fact_purchases\` WHERE purchase_order_id IN ($TARGET_IDS)" \
  > "$SCRATCH/step8_core_fact_purchases.json"
python3 -c "import json; d=json.load(open('$SCRATCH/step8_core_fact_purchases.json')); print('n_rows_core =', len(d))"

echo "=== step8b: cross-check via marts.in_transit for same ids ==="
bq query --use_legacy_sql=false --format=prettyjson \
  "SELECT purchase_order_id, position_id, product_id, quantity_in_transit, in_transit_sum_kgs, status_name FROM \`msklad-bi-prod.marts.in_transit\` WHERE purchase_order_id IN ($TARGET_IDS)" \
  > "$SCRATCH/step8b_mart_in_transit.json"
python3 -c "import json; d=json.load(open('$SCRATCH/step8b_mart_in_transit.json')); print('n_rows_mart =', len(d))"

echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u

echo "SCRATCH_PATH=$SCRATCH"
