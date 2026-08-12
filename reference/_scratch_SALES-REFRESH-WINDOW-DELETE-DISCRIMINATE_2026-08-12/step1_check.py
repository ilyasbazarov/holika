import csv
import hashlib
import json

ARCHIVE = "archive_106b.ndjson"
DELETED_CSV = "deleted_29.csv"

with open(DELETED_CSV) as f:
    deleted = list(csv.DictReader(f))

deleted_ids = {row["transaction_id"]: row for row in deleted}

archive_hashes = {}       # transaction_id -> record
archive_by_agent_date = {}  # (agent_id, transaction_date_raw[:10]) -> list of records

n = 0
with open(ARCHIVE) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        rec = json.loads(line)
        n += 1
        demand_id = rec["demand_id"]
        position_id = rec["position_id"]
        tid = hashlib.md5(f"{demand_id}|{position_id}".encode("utf-8")).hexdigest()
        archive_hashes[tid] = rec
        agent_id = rec["agent_id"]
        date10 = rec["transaction_date_raw"][:10]
        archive_by_agent_date.setdefault((agent_id, date10), []).append(rec)

print(f"archive records processed: {n}")
print(f"archive unique transaction_id (hash collisions if < n): {len(archive_hashes)}")
print()

found = []
not_found = []
for tid, row in deleted_ids.items():
    if tid in archive_hashes:
        found.append((tid, row))
    else:
        not_found.append((tid, row))

print(f"=== STEP 1 RESULT: {len(found)} found in archive / {len(not_found)} not found (of 29) ===")
print()
print("--- FOUND (present in raw archive, means выгрузка вернула, дефект archive->staging) ---")
for tid, row in found:
    print(f"  FOUND  {row['group']:14s} {row['date']} {row['agent_id']} {tid} rev={row['revenue_kgs']}")

print()
print("--- NOT FOUND (absent from raw archive entirely) ---")
for tid, row in not_found:
    print(f"  MISS   {row['group']:14s} {row['date']} {row['agent_id']} {tid} rev={row['revenue_kgs']}")

print()
print("=== STEP 2: for NOT FOUND transaction_ids, search archive by (agent_id, date) ===")
groups_step2 = {}
for tid, row in not_found:
    key = (row['agent_id'], row['date'])
    groups_step2.setdefault(key, []).append((tid, row))

for (agent_id, date10), items in groups_step2.items():
    matches = archive_by_agent_date.get((agent_id, date10), [])
    verdict = "DOCUMENT PRESENT (partial loss -> defect b)" if matches else "DOCUMENT ABSENT (hypothesis a)"
    print(f"  group={items[0][1]['group']:14s} date={date10} agent={agent_id} missing_rows={len(items)} archive_matches_same_agent_date={len(matches)} -> {verdict}")
