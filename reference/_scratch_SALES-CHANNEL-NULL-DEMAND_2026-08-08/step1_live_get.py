"""
step1_live_get.py — ADR-139 §2 differentiator: list-mode vs single-GET salesChannel presence.
Budget: 2 list GETs (2026-07-02, 2026-07-21) + up to 3 single GETs on found doc ids. Max 5 of 6 allowed.
"""
import json
import os
import sys
import time

import requests

MSKLAD_BASE = "https://api.moysklad.ru/api/remap/1.2"
TOKEN = os.environ["MSKLAD_TOKEN"]
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Accept-Encoding": "gzip"}
SCRATCH = "reference/_scratch_SALES-CHANNEL-NULL-DEMAND_2026-08-08"

TARGET_AGENTS = {
    "2026-07-02": "178ba7b4-87c0-11ef-0a80-1568002f4222",
    "2026-07-21": "13564a08-87c0-11ef-0a80-1568002f3f8d",
}

def parse_href(href):
    if not href:
        return None
    return href.rstrip("/").rsplit("/", 1)[-1] or None

def get(url, params=None):
    resp = requests.get(url, headers=HEADERS, params=params, timeout=90)
    resp.raise_for_status()
    return resp.json()

found_ids = []
call_count = 0

for date_str, agent_id in TARGET_AGENTS.items():
    moment_from = f"{date_str} 00:00:00"
    moment_to = f"{date_str} 23:59:59"
    params = {"filter": f"moment>={moment_from};moment<={moment_to}", "limit": 1000}
    data = get(f"{MSKLAD_BASE}/entity/demand", params=params)
    call_count += 1
    rows = data.get("rows", [])
    print(f"=== list GET {date_str}: rows={len(rows)} ===")
    with open(f"{SCRATCH}/list_{date_str}.json", "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    matched = [r for r in rows if parse_href((r.get("agent") or {}).get("meta", {}).get("href", "")) == agent_id]
    print(f"matched agent {agent_id}: {len(matched)} doc(s)")
    for row in matched:
        doc_id = row.get("id")
        has_sc = "salesChannel" in row
        print(f"  doc={doc_id} has_salesChannel_key_in_LIST={has_sc}")
        if doc_id and len(found_ids) < 3:
            found_ids.append((date_str, doc_id, has_sc))

print(f"found_ids for single-GET follow-up: {[d for _, d, _ in found_ids]}")

for date_str, doc_id, list_has_sc in found_ids:
    data = get(f"{MSKLAD_BASE}/entity/demand/{doc_id}")
    call_count += 1
    single_has_sc = "salesChannel" in data
    sc_value = data.get("salesChannel")
    print(f"=== single GET {doc_id} ({date_str}): list_has_salesChannel={list_has_sc} single_has_salesChannel={single_has_sc} salesChannel_value_present={sc_value is not None} ===")
    with open(f"{SCRATCH}/single_{doc_id}.json", "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    time.sleep(0.3)

print(f"TOTAL_GET_CALLS={call_count}")
if call_count > 6:
    print("СТОП: превышен лимит ADR-139 §2 (не более шести GET)", file=sys.stderr)
    sys.exit(1)
