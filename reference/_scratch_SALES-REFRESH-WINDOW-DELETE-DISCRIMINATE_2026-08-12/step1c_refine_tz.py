import csv, json, collections, datetime

ARCHIVE = "archive_106b.ndjson"
DELETED_CSV = "deleted_29.csv"

def bishkek_date(raw):
    # transaction_date_raw: "YYYY-MM-DD HH:MM:SS.mmm", parsed as UTC by BQ PARSE_TIMESTAMP,
    # then converted to Asia/Bishkek (UTC+6, no DST) via bq_ops.py:230 (_PARSE_DATE).
    dt = datetime.datetime.strptime(raw.split(".")[0], "%Y-%m-%d %H:%M:%S")
    dt_bishkek = dt + datetime.timedelta(hours=6)
    return dt_bishkek.date().isoformat()

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
        bdate = bishkek_date(rec["transaction_date_raw"])
        key = (rec["agent_id"], bdate)
        by_agent_date_demands[key].add(rec["demand_id"])
        by_agent_date_positions[key] += 1

print(f"{'group':14s} {'date(Bishkek)':14s} {'missing_rows':>12s} {'distinct_demands':>17s} {'positions_in_archive':>22s} -> verdict")
for g, info in groups.items():
    key = (info["agent_id"], info["date"])
    n_demands = len(by_agent_date_demands.get(key, set()))
    n_pos = by_agent_date_positions.get(key, 0)
    verdict = "DOCUMENT PRESENT -> partial loss, defect (b)" if n_pos > 0 else "DOCUMENT ABSENT -> hypothesis (a) plausible, needs step 3"
    print(f"{g:14s} {info['date']:14s} {len(info['rows']):12d} {n_demands:17d} {n_pos:22d} -> {verdict}")
