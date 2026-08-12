import csv, json, collections

ARCHIVE = "archive_106b.ndjson"
DELETED_CSV = "deleted_29.csv"

with open(DELETED_CSV) as f:
    deleted = list(csv.DictReader(f))

groups = collections.OrderedDict()
for row in deleted:
    groups.setdefault(row["group"], {"agent_id": row["agent_id"], "date": row["date"], "rows": []})
    groups[row["group"]]["rows"].append(row)

by_agent_date_demands = collections.defaultdict(set)
by_agent_date_positions = collections.defaultdict(int)
with open(ARCHIVE) as f:
    for line in f:
        rec = json.loads(line)
        key = (rec["agent_id"], rec["transaction_date_raw"][:10])
        by_agent_date_demands[key].add(rec["demand_id"])
        by_agent_date_positions[key] += 1

print(f"{'group':14s} {'date':10s} {'missing_rows':>12s} {'distinct_demands_in_archive':>28s} {'total_positions_in_archive':>26s}")
for g, info in groups.items():
    key = (info["agent_id"], info["date"])
    n_demands = len(by_agent_date_demands.get(key, set()))
    n_pos = by_agent_date_positions.get(key, 0)
    print(f"{g:14s} {info['date']:10s} {len(info['rows']):12d} {n_demands:28d} {n_pos:26d}")
