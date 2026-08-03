#!/usr/bin/env python3
"""Правки майских документов, пришедшие ПОСЛЕ последнего успешного недельного прогона
(2026-07-19T01:11:56Z) — то есть те, которых наша сторона могла не увидеть.
Считает также, какие из них уже не попадут ни в один будущий прогон из-за
скользящего окна 90 суток."""
import json, glob, datetime, os
SRC = "reference/_scratch_PARITY-CHECK-SALES-RETURNS_2026-08-01"
LAST_WEEKLY = datetime.datetime(2026, 7, 19, 1, 11, 56)
NEXT_WEEKLY = datetime.date(2026, 8, 9)          # ближайшее воскресенье после снятия блокировки
WINDOW = 90
docs = {}
for f in sorted(glob.glob(os.path.join(SRC, "demand_*page_*.json")) +
                glob.glob(os.path.join(SRC, "sales_may_page_*.json"))):
    d = json.load(open(f))
    for r in d.get("rows", []):
        if r.get("id") and r.get("moment", "").startswith("2026-05"):
            docs[r["id"]] = r
ts = lambda s: datetime.datetime.strptime(s[:19], "%Y-%m-%d %H:%M:%S")
late = [r for r in docs.values() if ts(r["updated"]) > LAST_WEEKLY]
cutoff = NEXT_WEEKLY - datetime.timedelta(days=WINDOW)
print(f"майских документов всего: {len(docs)}")
print(f"правлены ПОСЛЕ последнего успешного недельного прогона ({LAST_WEEKLY}): {len(late)}")
print(f"нижняя граница окна ближайшего прогона {NEXT_WEEKLY}: {cutoff}\n")
unreach = []
for r in sorted(late, key=lambda x: x["moment"]):
    m = ts(r["moment"]).date()
    ok = m >= cutoff
    if not ok:
        unreach.append(r)
    print(f"  №{r['name']}  moment={r['moment'][:16]}  updated={r['updated'][:16]}  "
          f"sum={r.get('sum', 0)/100:>14,.2f}  {'в окне' if ok else 'ВНЕ ОКНА — не догонится никогда'}")
print(f"\nиз них вне окна ближайшего прогона: {len(unreach)} документов, "
      f"сумма {sum(r.get('sum',0) for r in unreach)/100:,.2f} (в валюте документа, без курса)")
print(f"весь май выходит из окна {datetime.date(2026,5,31) + datetime.timedelta(days=WINDOW)}")
