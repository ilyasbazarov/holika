#!/usr/bin/env python3
"""Кривая застывания документов зоны паритета.

Вход — уже лежащие в репо сырые ответы МойСклада (снимок 2026-08-01, сессия
PARITY-CHECK-SALES-RETURNS). Считает, как долго после даты документа его ещё правят.
Ничего не скачивает, к облаку не обращается.
"""
import json, glob, datetime, collections, os, sys

SRC = "reference/_scratch_PARITY-CHECK-SALES-RETURNS_2026-08-01"

def load(patterns):
    seen = {}
    files = []
    for p in patterns:
        files += sorted(glob.glob(os.path.join(SRC, p)))
    for f in files:
        try:
            d = json.load(open(f))
        except Exception as e:
            print(f"  ПРОПУЩЕН {f}: {e}"); continue
        rows = d.get("rows") if isinstance(d, dict) else d
        if not isinstance(rows, list):
            continue
        for r in rows:
            if isinstance(r, dict) and r.get("id") and r.get("moment") and r.get("updated"):
                seen[r["id"]] = r
    return files, seen

def ts(s):
    return datetime.datetime.strptime(s[:19], "%Y-%m-%d %H:%M:%S")

def report(label, patterns, month_end):
    files, docs = load(patterns)
    print(f"\n=== {label} ===")
    print(f"файлов прочитано: {len(files)}")
    for f in files:
        print(f"   {f}")
    may = {i: r for i, r in docs.items() if r["moment"][:7] == "2026-05"}
    print(f"уникальных документов всего: {len(docs)}; из них с moment в 2026-05: {len(may)}")
    if not may:
        return
    lags, upds = [], []
    for r in may.values():
        m, u = ts(r["moment"]), ts(r["updated"])
        lags.append((u - m).total_seconds() / 86400.0)
        upds.append(u)
    lags.sort(); upds.sort()
    n = len(lags)
    def pct(p):
        return lags[min(n - 1, int(round(p / 100.0 * (n - 1))))]
    print(f"lag = updated - moment, суток: min={lags[0]:.2f}  медиана={pct(50):.2f}  "
          f"p90={pct(90):.2f}  p95={pct(95):.2f}  max={lags[-1]:.2f}")
    print(f"последняя правка любого майского документа: {upds[-1]}")
    print(f"первая дата документа: {min(ts(r['moment']) for r in may.values())}; "
          f"последняя: {max(ts(r['moment']) for r in may.values())}")
    me = ts(month_end)
    print("\n  доля документов, у которых ВСЕ правки закончились к моменту T после конца месяца:")
    for days in (0, 1, 3, 7, 10, 14, 21, 30, 45, 60):
        cut = me + datetime.timedelta(days=days)
        k = sum(1 for u in upds if u <= cut)
        print(f"    конец мая +{days:>2} сут ({cut:%Y-%m-%d}): {k:>4}/{n}  = {100.0*k/n:6.2f} %")
    print("\n  распределение правок по календарным месяцам (когда документ трогали последний раз):")
    for mo, k in sorted(collections.Counter(u.strftime("%Y-%m") for u in upds).items()):
        print(f"    {mo}: {k:>4}  ({100.0*k/n:5.2f} %)")

report("Продажи — entity/demand, май-2026",
       ["demand_page_*.json", "demand_cur_page_*.json", "demand_cursum_page_*.json",
        "demand_all_page_*.json", "sales_may_page_*.json"],
       "2026-05-31 23:59:59")
report("Возвраты покупателей — розничные и обычные, май-2026",
       ["retail_returns_may_full.json", "retail_returns_may.json", "returns_all.json"],
       "2026-05-31 23:59:59")
print("\nПредел замера: поле updated отражает состояние на момент СНЯТИЯ этих ответов "
      "(2026-08-01). Правки, сделанные после этой даты, здесь не видны.")
