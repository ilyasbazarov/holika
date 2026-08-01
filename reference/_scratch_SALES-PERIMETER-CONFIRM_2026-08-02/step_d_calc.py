# -*- coding: utf-8 -*-
"""Офлайн-расчёт по уже скачанному телу. Сети нет.
Печатаются ВСЕ кандидаты денежных величин документа, а не только совпавшая
(ADR-044: строки, не вердикт; ADR-021 §2: не подгонять под ожидание)."""
import json, collections

P = "reference/_scratch_SALES-PERIMETER-CONFIRM_2026-08-02/commissionreportin_may_page_0.json"
d = json.load(open(P))
rows = d["rows"]
print("meta.size =", d["meta"]["size"], "· rows =", len(rows))
print()

EXP = {  # ожидание из reference/sales_h1h4_adj_2026-08-02.md §1
    "0276f431-2ff5-11ef-0a80-11d40019917f": ("UMAI WB (Договор КР)", 2111374.17),
    "3c080755-03ff-11f0-0a80-0c2c00104bbb": ("Bloom WB (Договор)",     18870.91),
    "31d135bc-4df8-11f1-0a80-1c8a0053c5b4": ('ООО "РВБ"',                2783.00),
}

def uid(h): return h.rsplit("/", 1)[-1].split("?")[0]

print("=== документы ===")
print("%-38s %-19s %-6s %5s %13s %13s %13s %13s" %
      ("agent", "moment", "appl.", "поз.", "sum", "commitentSum", "Σ price×qty", "Σ reward"))
agg = collections.defaultdict(lambda: [0.0, 0.0, 0.0, 0.0, 0])
for r in rows:
    rate = (r.get("rate") or {}).get("value") or 1.0
    pos = (r.get("positions") or {}).get("rows") or []
    pq = sum(p.get("price", 0) / 100.0 * p.get("quantity", 0) for p in pos) * rate
    rw = sum(p.get("reward", 0) for p in pos) / 100.0 * rate
    s = r.get("sum", 0) / 100.0 * rate
    cs = (r.get("commitentSum") or 0) / 100.0 * rate
    a = uid((r.get("agent") or {}).get("meta", {}).get("href", ""))
    nm = EXP.get(a, (a, None))[0]
    print("%-38s %-19s %-6s %5d %13.2f %13.2f %13.2f %13.2f" %
          (nm[:38], r.get("moment"), str(r.get("applicable")), len(pos), s, cs, pq, rw))
    v = agg[a]; v[0] += s; v[1] += cs; v[2] += pq; v[3] += rw; v[4] += 1

print()
print("=== по контрагентам: кандидаты против ожидания ===")
print("%-38s %5s %13s %13s %13s | %13s" %
      ("agent", "док.", "sum", "commitentSum", "Σ price×qty", "ожидание"))
tot = [0.0, 0.0, 0.0]
for a, v in sorted(agg.items(), key=lambda kv: -kv[1][2]):
    nm, exp = EXP.get(a, (a, None))
    print("%-38s %5d %13.2f %13.2f %13.2f | %13s" %
          (nm[:38], v[4], v[0], v[1], v[2], ("%.2f" % exp) if exp else "—"))
    tot[0] += v[0]; tot[1] += v[1]; tot[2] += v[2]
print("%-38s %5d %13.2f %13.2f %13.2f | %13.2f" %
      ("ИТОГО", sum(v[4] for v in agg.values()), tot[0], tot[1], tot[2], sum(e[1] for e in EXP.values())))

print()
print("=== вердикт по каждому кандидату (ожидание 2 133 028,14) ===")
for nm, val in (("sum документа", tot[0]), ("commitentSum", tot[1]), ("Σ price×quantity", tot[2])):
    print("  %-18s = %13.2f   Δ к ожиданию = %+13.2f" % (nm, val, val - 2133028.14))
