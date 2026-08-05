#!/usr/bin/env bash
set -euo pipefail

SCRATCH="reference/_scratch_PARITY-STOCK-INTRANSIT-RECHECK_2026-08-05"

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

def get(url, headers):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        body = resp.read()
        if resp.headers.get("Content-Encoding") == "gzip":
            body = gzip.decompress(body)
    return json.loads(body)

def paginate_entity(path, params=None):
    headers = {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}
    limit = 100
    offset = 0
    all_rows = []
    qs = ""
    if params:
        qs = "&" + "&".join(f"{k}={v}" for k, v in params.items())
    meta_size = None
    while True:
        url = f"{base}/{path}?limit={limit}&offset={offset}{qs}"
        data = get(url, headers)
        rows = data.get("rows", [])
        all_rows.extend(rows)
        meta_size = data.get("meta", {}).get("size")
        if len(rows) < limit:
            break
        offset += limit
        time.sleep(0.25)
    return all_rows, meta_size

orders, meta_size = paginate_entity("entity/purchaseorder", params={"expand": "agent,state"})
with open(f"{scratch}/step3_purchaseorder_all_meta.json", "w") as f:
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

with open(f"{scratch}/step3_target_order_ids.json", "w") as f:
    json.dump([
        {"id": t["order"]["id"], "name": t["order"].get("name"), "status_name": t["status_name"]}
        for t in target_orders
    ], f, ensure_ascii=False, indent=2)

all_positions = []
time.sleep(0.25)
for i, t in enumerate(target_orders):
    order = t["order"]
    order_id = order["id"]
    positions, pmeta = paginate_entity(f"entity/purchaseorder/{order_id}/positions")
    with open(f"{scratch}/step3_positions_order_{order_id}.json", "w") as f:
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

with open(f"{scratch}/step3_all_positions.json", "w") as f:
    json.dump(all_positions, f, ensure_ascii=False, indent=2)

n_missing_rate = sum(1 for p in all_positions if not p["has_rate_value"])
n_nonzero = sum(1 for p in all_positions if p["in_transit_sum_kgs"] > 0)
sum_in_transit = round(sum(p["in_transit_sum_kgs"] for p in all_positions), 2)
sum_in_transit_nonzero = round(sum(p["in_transit_sum_kgs"] for p in all_positions if p["in_transit_sum_kgs"] > 0), 2)
print(f"total positions: {len(all_positions)}, nonzero: {n_nonzero}, missing rate.value: {n_missing_rate}, SUM(in_transit_sum_kgs)={sum_in_transit}, SUM(nonzero)={sum_in_transit_nonzero}")

with open(f"{scratch}/step3_source_summary.json", "w") as f:
    json.dump({
        "n_target_orders": len(target_orders),
        "n_positions_total": len(all_positions),
        "n_positions_nonzero": n_nonzero,
        "n_missing_rate_value": n_missing_rate,
        "sum_in_transit_sum_kgs_all": sum_in_transit,
        "sum_in_transit_sum_kgs_nonzero": sum_in_transit_nonzero,
        "by_status": by_status,
    }, f, indent=2)

# check for the 4 prior-tail order ids
prior_ids = {
    "04a41f62-826b-11f1-0a80-14070015f6ec": "zero-remainder-symmetric-1",
    "aab67ac6-e2d4-11f0-0a80-0fda0015d3cf": "zero-remainder-symmetric-2",
    "08bfe70e-7b8b-11f1-0a80-03b8000e83b3": "one-sided-tail-1",
    "e7d7a18b-81c6-11f1-0a80-0170000b1cc0": "one-sided-tail-2",
}
all_order_ids_seen = {o["id"]: o for o in orders}
prior_status_now = {}
for oid, label in prior_ids.items():
    if oid in all_order_ids_seen:
        o = all_order_ids_seen[oid]
        state_href = o.get("state", {}).get("meta", {}).get("href", "")
        status_id = parse_href(state_href)
        status_name = PURCHASE_ORDER_STATES.get(status_id, "Неизвестен")
        prior_status_now[oid] = {"label": label, "found_in_source": True, "status_name": status_name, "name": o.get("name")}
    else:
        prior_status_now[oid] = {"label": label, "found_in_source": False}
with open(f"{scratch}/step3_prior_tail_status.json", "w") as f:
    json.dump(prior_status_now, f, ensure_ascii=False, indent=2)
print("prior tail status:", json.dumps(prior_status_now, ensure_ascii=False, indent=2))
PYEOF

echo "GET_END_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "=== step3_token_leak_check: verify token not printed anywhere in this run's log (single-process check) ==="
if [ -n "${MSKLAD_TOKEN:-}" ]; then
  if grep -rF "$MSKLAD_TOKEN" "$SCRATCH"/*.json "$SCRATCH"/*.log 2>/dev/null; then
    echo "TOKEN_LEAK_DETECTED"
  else
    echo "token_leak_check: clean (0 matches)"
  fi
fi

unset MSKLAD_TOKEN

echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u

echo "SCRATCH_PATH=$SCRATCH"
