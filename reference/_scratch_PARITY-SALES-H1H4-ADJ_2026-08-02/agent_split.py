# -*- coding: utf-8 -*-
"""Офлайн-сопоставление стороны отчёта и стороны документов ПО КОНТРАГЕНТАМ.
Ноль сетевых вызовов, ноль обращений к BigQuery: читаются только уже лежащие
в репо тела ответов (провенанс PARITY-CHECK-SALES-RETURNS + шаг 2 DISCRIMINATE).
"""
import json, glob, collections

BASE = "reference/_scratch_PARITY-CHECK-SALES-RETURNS_2026-08-01/"
BASE2 = "reference/_scratch_PARITY-SALES-DISCRIMINATE-2NDSTEP_2026-08-02/"

# --- курсы валют (ADR-010, как в шаге 1) ---
CUR = {"KGS": 1.0, "USD": 90.0, "RUB": 1.135}

def cur_of(doc):
    r = doc.get("rate", {})
    c = r.get("currency", {})
    name = c.get("name") or ""
    href = c.get("meta", {}).get("href", "")
    return r, href, name

# читаем справочники валют (уже скачаны)
cur_by_href = {}
for f in glob.glob(BASE + "currency_*.json"):
    d = json.load(open(f))
    cur_by_href[d["meta"]["href"]] = (d.get("isoCode") or d.get("name"), d.get("rate", 1.0))

def doc_kgs(doc):
    """sum документа в KGS по правилу ADR-010: minor/100 * rate.value,
    иначе текущий курс валюты документа."""
    r, href, _ = cur_of(doc)
    v = r.get("value")
    if v is None:
        iso, rate = cur_by_href.get(href, ("KGS", 1.0))
        v = rate if iso != "KGS" else 1.0
    return doc.get("sum", 0) / 100.0 * v

def agent_name(doc):
    a = doc.get("agent", {})
    return a.get("name") or a.get("meta", {}).get("href", "").rsplit("/", 1)[-1]

# --- сторона документов ---
demand, retail = collections.Counter(), collections.Counter()
dcnt, rcnt = collections.Counter(), collections.Counter()
for f in [BASE + "demand_page_0.json", BASE + "demand_page_100.json"]:
    for doc in json.load(open(f))["rows"]:
        demand[agent_name(doc)] += doc_kgs(doc); dcnt[agent_name(doc)] += 1
for f in sorted(glob.glob(BASE2 + "retaildemand_page_*.json")):
    for doc in json.load(open(f))["rows"]:
        retail[agent_name(doc)] += doc_kgs(doc); rcnt[agent_name(doc)] += 1

# --- сторона отчёта ---
rep, repcnt = collections.Counter(), collections.Counter()
d = json.load(open(BASE2 + "bycounterparty_sym_page_0.json"))
for row in d["rows"]:
    n = row["counterparty"]["name"]
    rep[n] += row["sellSum"] / 100.0
    repcnt[n] += row["salesCount"]

print("=== контроль сумм ===")
print("Σ demand   = %15.2f  (%d док.)" % (sum(demand.values()), sum(dcnt.values())))
print("Σ retail   = %15.2f  (%d док.)" % (sum(retail.values()), sum(rcnt.values())))
print("Σ report   = %15.2f  (salesCount=%.0f, контрагентов %d)"
      % (sum(rep.values()), sum(repcnt.values()), len(rep)))
print("report − (demand+retail) = %.2f" % (sum(rep.values()) - sum(demand.values()) - sum(retail.values())))
print()
print("=== расхождения по контрагентам (|Δ| >= 1 KGS), Δ = report − (demand+retail) ===")
names = set(rep) | set(demand) | set(retail)
rows = []
for n in names:
    delta = rep[n] - demand[n] - retail[n]
    if abs(delta) >= 1.0:
        rows.append((delta, n, rep[n], demand[n], retail[n], repcnt[n], dcnt[n], rcnt[n]))
rows.sort(key=lambda t: -abs(t[0]))
print("%-42s %14s %14s %13s %13s | %6s %5s %5s" %
      ("контрагент", "Δ", "report", "demand", "retail", "cnt_r", "cnt_d", "cnt_rt"))
for delta, n, r_, d_, rt_, cr, cd, crt in rows:
    print("%-42s %14.2f %14.2f %13.2f %13.2f | %6.0f %5d %5d" % (n[:42], delta, r_, d_, rt_, cr, cd, crt))
print()
print("сумма Δ по строкам выше = %.2f  (строк: %d)" % (sum(t[0] for t in rows), len(rows)))
