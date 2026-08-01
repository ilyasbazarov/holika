# -*- coding: utf-8 -*-
"""Проверка реконструкции стороны отчёта из трёх слагаемых. Ноль сети."""
import json, glob, collections
BASE  = "reference/_scratch_PARITY-CHECK-SALES-RETURNS_2026-08-01/"
BASE2 = "reference/_scratch_PARITY-SALES-DISCRIMINATE-2NDSTEP_2026-08-02/"
cur = {}
for f in glob.glob(BASE + "currency_*.json"):
    d = json.load(open(f)); cur[d["meta"]["href"]] = (d.get("isoCode") or d.get("name"), d.get("rate", 1.0))
uid = lambda h: h.rsplit("/", 1)[-1].split("?")[0]
def kgs(doc):
    r = doc.get("rate", {}); v = r.get("value")
    if v is None:
        iso, rate = cur.get(r.get("currency", {}).get("meta", {}).get("href", ""), ("KGS", 1.0))
        v = rate if iso != "KGS" else 1.0
    return doc.get("sum", 0) / 100.0 * v

MP = {}   # uuid -> имя, три контрагента-маркетплейса из agent_split2
for row in json.load(open(BASE2 + "bycounterparty_sym_page_0.json"))["rows"]:
    n = row["counterparty"]["name"]
    if "UMAI WB" in n or "Bloom WB" in n or "РВБ" in n:
        MP[uid(row["counterparty"]["meta"]["href"])] = (n, row["sellSum"]/100.0, row["salesCount"])

dem = [d for f in [BASE+"demand_page_0.json", BASE+"demand_page_100.json"] for d in json.load(open(f))["rows"]]
ret = [d for f in sorted(glob.glob(BASE2+"retaildemand_page_*.json")) for d in json.load(open(f))["rows"]]

print("--- документы entity/demand, выписанные на контрагентов-маркетплейсов ---")
mp_dem = [d for d in dem if uid(d["agent"]["meta"]["href"]) in MP]
for d in mp_dem:
    print("  %s  moment=%s  name=%s  sum=%.2f KGS  applicable=%s"
          % (MP[uid(d["agent"]["meta"]["href"])][0][:28], d["moment"], d.get("name"), kgs(d), d.get("applicable")))
print("  документов: %d, сумма: %.2f" % (len(mp_dem), sum(kgs(d) for d in mp_dem)))
print()
print("--- документы entity/retaildemand на этих контрагентов ---")
mp_ret = [d for d in ret if uid(d["agent"]["meta"]["href"]) in MP]
print("  документов: %d, сумма: %.2f" % (len(mp_ret), sum(kgs(d) for d in mp_ret)))
print()
print("--- сторона отчёта по этим трём контрагентам ---")
for u,(n,s,c) in sorted(MP.items(), key=lambda kv:-kv[1][1]):
    print("  %-34s sellSum=%12.2f  salesCount=%.0f" % (n[:34], s, c))
mp_rep_sum = sum(v[1] for v in MP.values()); mp_rep_cnt = sum(v[2] for v in MP.values())
print("  итого: %.2f, salesCount=%.0f" % (mp_rep_sum, mp_rep_cnt))
print()

S_dem, S_ret = sum(kgs(d) for d in dem), sum(kgs(d) for d in ret)
S_rep = sum(row["sellSum"]/100.0 for row in json.load(open(BASE2+"bycounterparty_sym_page_0.json"))["rows"])
S_cnt = sum(row["salesCount"] for row in json.load(open(BASE2+"bycounterparty_sym_page_0.json"))["rows"])
mp_dem_sum = sum(kgs(d) for d in mp_dem)
resid = S_rep - (S_dem - mp_dem_sum) - S_ret

print("=== реконструкция суммы ===")
print("  отчёт  sellSum                                 = %14.2f" % S_rep)
print("  опт  Σ demand.sum                              = %14.2f" % S_dem)
print("  минус отгрузки контрагентам-маркетплейсам      = %14.2f" % (-mp_dem_sum))
print("  розница Σ retaildemand.sum                     = %14.2f" % S_ret)
print("  ------------------------------------------------------------")
print("  необъяснённый остаток (кандидат = комиссия)    = %14.2f" % resid)
print()
print("=== реконструкция счётчика ===")
print("  отчёт salesCount                               = %14.0f" % S_cnt)
print("  документов demand %d − отгрузок маркетплейсам %d = %12d" % (len(dem), len(mp_dem), len(dem)-len(mp_dem)))
print("  документов retaildemand                        = %14d" % len(ret))
print("  ------------------------------------------------------------")
print("  необъяснённый остаток документов               = %14.0f" % (S_cnt - (len(dem)-len(mp_dem)) - len(ret)))
