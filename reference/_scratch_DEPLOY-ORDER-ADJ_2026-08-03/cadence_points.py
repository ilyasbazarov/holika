#!/usr/bin/env python3
"""Опорные точки для выбора каденции пересъёма эталона."""
import json, glob, datetime, os
SRC = "reference/_scratch_PARITY-CHECK-SALES-RETURNS_2026-08-01"
docs = {}
for f in sorted(glob.glob(os.path.join(SRC, "demand_*page_*.json")) +
                glob.glob(os.path.join(SRC, "sales_may_page_*.json"))):
    for r in json.load(open(f)).get("rows", []):
        if r.get("id") and r.get("moment", "").startswith("2026-05"):
            docs[r["id"]] = r
ts = lambda s: datetime.datetime.strptime(s[:19], "%Y-%m-%d %H:%M:%S")
n = len(docs)
print(f"майских документов: {n}\n")
print("доля застывших на конкретные календарные даты (правил больше не было):")
for d in ("2026-06-07", "2026-06-30", "2026-07-15", "2026-07-19", "2026-07-26", "2026-08-01"):
    cut = datetime.datetime.strptime(d, "%Y-%m-%d") + datetime.timedelta(hours=23, minutes=59)
    k = sum(1 for r in docs.values() if ts(r["updated"]) <= cut)
    print(f"  {d}: {k:>4}/{n} = {100.0*k/n:6.2f} %")
print("\nпоследние воскресные прогоны и покрытие мая окном 90 суток:")
for d in ("2026-07-19", "2026-07-26", "2026-08-02", "2026-08-09", "2026-08-30"):
    dt = datetime.date.fromisoformat(d)
    lo = dt - datetime.timedelta(days=90)
    cov = "весь май" if lo <= datetime.date(2026, 5, 1) else (
        f"май c {lo.isoformat()}" if lo <= datetime.date(2026, 5, 31) else "мая нет вовсе")
    print(f"  прогон {d}: нижняя граница {lo} → {cov}")
print("\nKGS-величина трёх документов, правленных после 2026-07-19 и уже вне досягаемости:")
tot = 0.0
for nm in ("04195", "04456x", "04227"):
    for r in docs.values():
        if r.get("name") == nm:
            rate = (r.get("rate") or {}).get("value") or 1.0
            kgs = r["sum"] / 100.0 * rate
            tot += kgs
            print(f"  №{nm}: {r['sum']/100:>14,.2f} × {rate} = {kgs:>16,.2f} KGS   (updated {r['updated'][:16]})")
print(f"  ИТОГО стоимость документов: {tot:,.2f} KGS")
print("  ВНИМАНИЕ: это полная стоимость документов, а не величина правки —")
print("  что именно изменилось внутри них, этим замером НЕ установлено.")
