import re
import sys

SRC = "listing_2026-08-08.txt"
OUT = "step2b_objects_from_20260722.txt"

pattern = re.compile(r"^\s*(\d+)\s+(\S+)\s+(gs://\S+)$")

selected = []
with open(SRC) as f:
    for line in f:
        m = pattern.match(line)
        if not m:
            continue
        size, ts, uri = m.groups()
        if ts >= "2026-07-22T00:00:00Z":
            selected.append(uri)

with open(OUT, "w") as f:
    for uri in selected:
        f.write(uri + "\n")

print(f"selected {len(selected)} objects from >= 2026-07-22T00:00:00Z, written to {OUT}")
