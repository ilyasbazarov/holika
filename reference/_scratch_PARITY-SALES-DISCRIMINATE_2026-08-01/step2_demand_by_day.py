#!/usr/bin/env python3
"""Офлайн (без сети): Sigma demand.sum по суткам документа (moment, UTC -> Asia/Bishkek), курс = валюта документа."""
import json
from datetime import datetime, timedelta, date

SCRATCH_RETURNS = "reference/_scratch_PARITY-CHECK-SALES-RETURNS_2026-08-01"

CURRENCY_RATES = {
    "1fb4954e-fa31-11ee-0a80-08920071069f": 1.0,     # KGS
    "3ea7aa1b-2c68-11ef-0a80-117500188e00": 90.0,    # USD
    "9ac2585d-8036-11ef-0a80-0d7a00094bfe": 1.135,   # RUB
}

def currency_id_from_href(href):
    return href.rstrip("/").split("/")[-1]

def bishkek_date(moment_str):
    # moment_str: "YYYY-MM-DD HH:MM:SS.mmm" — задокументировано как UTC (ADR-088)
    dt = datetime.strptime(moment_str, "%Y-%m-%d %H:%M:%S.%f")
    dt_bishkek = dt + timedelta(hours=6)
    return dt_bishkek.date()

docs = []
for fname in ["demand_page_0.json", "demand_page_100.json"]:
    d = json.load(open(f"{SCRATCH_RETURNS}/{fname}"))
    docs.extend(d["rows"])

assert len(docs) == 127, f"expected 127 docs, got {len(docs)}"

by_day = {}
per_doc_rows = []
for doc in docs:
    cur_id = currency_id_from_href(doc["rate"]["currency"]["meta"]["href"])
    rate = doc["rate"].get("value", CURRENCY_RATES[cur_id])
    sum_minor = doc["sum"]
    sum_kgs = sum_minor / 100.0 * rate
    day = bishkek_date(doc["moment"])
    by_day.setdefault(day, {"n": 0, "sum_kgs": 0.0})
    by_day[day]["n"] += 1
    by_day[day]["sum_kgs"] += sum_kgs
    per_doc_rows.append({
        "id": doc["id"],
        "moment_utc": doc["moment"],
        "updated_utc": doc["updated"],
        "date_bishkek": str(day),
        "currency_id": cur_id,
        "sum_minor": sum_minor,
        "sum_kgs_converted": round(sum_kgs, 2),
    })

total = sum(v["sum_kgs"] for v in by_day.values())
print("=== Sigma demand.sum конвертированная по суткам (Asia/Bishkek, из moment UTC) ===")
for day in sorted(by_day):
    v = by_day[day]
    print(f"{day}\tn={v['n']}\tsum_kgs={v['sum_kgs']:.2f}")
print(f"ИТОГО: n={len(docs)} sum_kgs={total:.2f}")

with open("reference/_scratch_PARITY-SALES-DISCRIMINATE_2026-08-01/step2_by_day.json", "w") as f:
    json.dump({str(k): v for k, v in sorted(by_day.items())}, f, ensure_ascii=False, indent=2)

with open("reference/_scratch_PARITY-SALES-DISCRIMINATE_2026-08-01/step2_per_doc.json", "w") as f:
    json.dump(per_doc_rows, f, ensure_ascii=False, indent=2)

print("PATH: reference/_scratch_PARITY-SALES-DISCRIMINATE_2026-08-01/step2_by_day.json")
print("PATH: reference/_scratch_PARITY-SALES-DISCRIMINATE_2026-08-01/step2_per_doc.json")
