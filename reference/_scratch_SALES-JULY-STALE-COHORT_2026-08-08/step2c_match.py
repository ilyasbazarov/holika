import gzip
import hashlib
import json
import subprocess
import sys

TARGETS_0721 = "step2a_txids_0721.json"
TARGETS_0730 = "step2a_txids_0730.json"
OBJ_LIST = "step2b_objects_from_20260722.txt"
RAW_DIR = "raw_archives"

import os
os.makedirs(RAW_DIR, exist_ok=True)


def load_targets(path, transaction_date):
    with open(path) as f:
        rows = json.load(f)
    out = {}
    for r in rows:
        out[r["transaction_id"]] = {
            "transaction_date": transaction_date,
            "revenue_kgs": r["revenue_kgs"],
            "loaded_date": r["loaded_date"],
        }
    return out


targets = {}
targets.update(load_targets(TARGETS_0721, "2026-07-21"))
targets.update(load_targets(TARGETS_0730, "2026-07-30"))
print(f"целевых transaction_id: {len(targets)}", file=sys.stderr)

with open(OBJ_LIST) as f:
    objects = [l.strip() for l in f if l.strip()]
print(f"объектов для скачивания: {len(objects)}", file=sys.stderr)

# скачиваем все объекты одним вызовом gcloud storage cp
manifest_path = os.path.join(RAW_DIR, "_manifest.txt")
with open(manifest_path, "w") as f:
    f.write("\n".join(objects) + "\n")

subprocess.run(
    ["gcloud", "storage", "cp", "-I", RAW_DIR],
    stdin=open(manifest_path),
    check=True,
)

# для каждого локального файла — распаковать, посчитать хэш по каждой строке
hits = {tid: [] for tid in targets}
n_records = 0
n_files = 0
for uri in objects:
    fname = uri.rsplit("/", 1)[-1]
    local_path = os.path.join(RAW_DIR, fname)
    if not os.path.exists(local_path):
        print(f"ПРОПУЩЕН (не скачан): {uri}", file=sys.stderr)
        continue
    n_files += 1
    with gzip.open(local_path, "rt", encoding="utf-8") as gz:
        for line in gz:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            demand_id = rec.get("demand_id")
            position_id = rec.get("position_id")
            if demand_id is None or position_id is None:
                continue
            n_records += 1
            tid = hashlib.md5(f"{demand_id}|{position_id}".encode("utf-8")).hexdigest()
            if tid in targets:
                hits[tid].append({
                    "source_object": uri,
                    "demand_id": demand_id,
                    "position_id": position_id,
                    "transaction_date_raw": rec.get("transaction_date_raw"),
                    "run_id": rec.get("run_id"),
                    "_loaded_at": rec.get("_loaded_at"),
                })

print(f"файлов обработано: {n_files}", file=sys.stderr)
print(f"записей обработано: {n_records}", file=sys.stderr)

result = {"targets": targets, "hits": hits}
with open("step2c_match_result.json", "w") as f:
    json.dump(result, f, ensure_ascii=False, indent=2)

print("=== СВОДКА ПО КАЖДОМУ transaction_id ===")
for tid, info in targets.items():
    h = hits[tid]
    print(f"{tid} (transaction_date={info['transaction_date']}, revenue_kgs={info['revenue_kgs']}): найден в {len(h)} более поздних архивах")
    for entry in h:
        print(f"    {entry}")
