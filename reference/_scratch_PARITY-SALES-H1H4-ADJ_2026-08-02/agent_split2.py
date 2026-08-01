# -*- coding: utf-8 -*-
"""То же сопоставление, но матч по UUID контрагента (в телах документов
поле agent приходит без name — только meta.href, expand не запрашивался)."""
import json, glob, collections

BASE = "reference/_scratch_PARITY-CHECK-SALES-RETURNS_2026-08-01/"
BASE2 = "reference/_scratch_PARITY-SALES-DISCRIMINATE-2NDSTEP_2026-08-02/"

cur_by_href = {}
for f in glob.glob(BASE + "currency_*.json"):
    d = json.load(open(f))
    cur_by_href[d["meta"]["href"]] = (d.get("isoCode") or d.get("name"), d.get("rate", 1.0))

def uid(href):
    return href.rsplit("/", 1)[-1].split("?")[0]

def doc_kgs(doc):
    r = doc.get("rate", {})
    v = r.get("value")
    if v is None:
        iso, rate = cur_by_href.get(r.get("currency", {}).get("meta", {}).get("href", ""), ("KGS", 1.0))
        v = rate if iso != "KGS" else 1.0
    return doc.get("sum", 0) / 100.0 * v

docs = collections.Counter(); dcnt = collections.Counter()
kind = collections.defaultdict(set)
for f, tag in [(BASE + "demand_page_0.json", "demand"), (BASE + "demand_page_100.json", "demand")] + \
              [(p, "retail") for p in sorted(glob.glob(BASE2 + "retaildemand_page_*.json"))]:
    for doc in json.load(open(f))["rows"]:
        u = uid(doc["agent"]["meta"]["href"])
        docs[u] += doc_kgs(doc); dcnt[u] += 1; kind[u].add(tag)

rep = collections.Counter(); repcnt = collections.Counter(); name = {}
for row in json.load(open(BASE2 + "bycounterparty_sym_page_0.json"))["rows"]:
    u = uid(row["counterparty"]["meta"]["href"])
    rep[u] += row["sellSum"] / 100.0; repcnt[u] += row["salesCount"]
    name[u] = row["counterparty"]["name"]

print("Σ report = %.2f (salesCount %.0f, контрагентов %d)" % (sum(rep.values()), sum(repcnt.values()), len(rep)))
print("Σ docs   = %.2f (документов %d, контрагентов %d)" % (sum(docs.values()), sum(dcnt.values()), len(docs)))
print("Δ итого  = %.2f" % (sum(rep.values()) - sum(docs.values())))
print()
print("=== контрагенты с |Δ| >= 0,005 KGS, Δ = report − документы ===")
print("%-46s %13s %13s %13s | %6s %5s %s" % ("контрагент", "Δ", "report", "docs", "cnt_rep", "cnt_d", "типы"))
rows = []
for u in set(rep) | set(docs):
    d = rep[u] - docs[u]
    if abs(d) >= 0.005:
        rows.append((d, u))
rows.sort(key=lambda t: -abs(t[0]))
for d, u in rows:
    print("%-46s %13.2f %13.2f %13.2f | %6.0f %5d %s" %
          ((name.get(u) or u)[:46], d, rep[u], docs[u], repcnt[u], dcnt[u], ",".join(sorted(kind[u])) or "—"))
print()
print("строк: %d · сумма Δ = %.2f" % (len(rows), sum(t[0] for t in rows)))
print()
print("=== контрагенты, которых нет на стороне документов вовсе ===")
for u in sorted(set(rep) - set(docs), key=lambda x: -rep[x]):
    print("%-46s report=%13.2f salesCount=%.0f" % ((name.get(u) or u)[:46], rep[u], repcnt[u]))
print()
print("=== контрагенты, которых нет в отчёте вовсе ===")
for u in sorted(set(docs) - set(rep), key=lambda x: -docs[x]):
    print("%-46s docs=%13.2f документов=%d типы=%s" % (u, docs[u], dcnt[u], ",".join(sorted(kind[u]))))
