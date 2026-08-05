#!/usr/bin/env python3
"""Офлайн-перепроверка разложения PARITY-STOCK-INTRANSIT-RECHECK (2026-08-05).

Ничего не измеряет: читает ТОЛЬКО уже лежащие в репо датированные артефакты.
Три независимые проверки:
  A. Точная (Decimal) сверка 251 ключа: наша сторона (BigQuery) против разбора источника.
  B. Пересчёт величины источника из СЫРЫХ тел ответов по формуле fetch_purchases.py:141/147
     — не полагается на разбор, сделанный сессией-исполнителем.
  C. Замыкание перехода между двумя замерами (2026-08-04 -> 2026-08-05):
     совпадает ли прежнее пересечение 15 заказов с сегодняшним минус вошедший заказ.
"""
import json, glob, os
from decimal import Decimal, getcontext
getcontext().prec = 40
D = lambda x: Decimal(str(x))

R = "reference/_scratch_PARITY-STOCK-INTRANSIT-RECHECK_2026-08-05"
our = json.load(open(f"{R}/step2b_our_side_rows.json"))
src = json.load(open(f"{R}/step3_all_positions.json"))
K = lambda r: (r["purchase_order_id"], r["position_id"])

print("== A. точная сверка 251 ключа ==")
src_nz = [r for r in src if D(r["in_transit_sum_kgs"]) > 0]
mo = {K(r): D(r["in_transit_sum_kgs"]) for r in our}
ms = {K(r): D(r["in_transit_sum_kgs"]) for r in src_nz}
print(f"  наша сторона: {len(mo)} ключей, Σ = {sum(mo.values())}")
print(f"  источник:     {len(ms)} ключей, Σ = {sum(ms.values())}")
print(f"  только у нас: {len(set(mo)-set(ms))}   только у источника: {len(set(ms)-set(mo))}")
print(f"  ключей с ненулевой разностью (ТОЧНОЕ сравнение, без допуска): "
      f"{sum(1 for k in set(mo)&set(ms) if mo[k] != ms[k])}")
print(f"  Delta = {sum(mo.values()) - sum(ms.values())}")

print("== B. пересчёт источника из сырых тел ==")
rate = {r["purchase_order_id"]: D(r["currency_rate"]) for r in src}
raw_tot, raw_n, bad = Decimal(0), 0, 0
for f in glob.glob(f"{R}/step3_positions_order_*.json"):
    oid = os.path.basename(f)[len("step3_positions_order_"):-len(".json")]
    body = json.load(open(f))
    rows = body if isinstance(body, list) else body.get("rows", [])
    for p in rows:
        it = D(p.get("inTransit", 0) or 0)
        if it <= 0:
            continue
        price_kgs = D(p.get("price") or 0) / 100 * rate[oid]
        v = round(price_kgs * it * (1 - D(p.get("discount", 0) or 0) / 100), 4)
        raw_tot += v; raw_n += 1
        pid = p["id"]
        if (oid, pid) in mo and mo[(oid, pid)] != v:
            bad += 1
print(f"  позиций с inTransit>0 в сырых телах: {raw_n}, Σ = {raw_tot}")
print(f"  позиций, где пересчёт из сырого тела != нашей стороне: {bad}")

print("== C. замыкание перехода 2026-08-04 -> 2026-08-05 ==")
NEW = "04a41f62-826b-11f1-0a80-14070015f6ec"   # вошёл в периметр к 08-05
tot = sum(mo.values())
new = sum(v for k, v in mo.items() if k[0] == NEW)
print(f"  сегодня всего:              {tot}  ({len(mo)} позиций)")
print(f"  из них заказ 04a41f62:      {new}  ({sum(1 for k in mo if k[0]==NEW)} позиций)")
print(f"  прочие 15 заказов:          {tot-new}  ({sum(1 for k in mo if k[0]!=NEW)} позиций)")
print(f"  пересечение 15 заказов 2026-08-04 (parity_intransit_close_2026-08-04.md): 76514274.30 / 241 позиция")
print(f"  разность: {tot - new - D('76514274.30')}")
print(f"  прежний хвост: 1197000.00 + 1037268.75 = {D('1197000.00')+D('1037268.75')}"
      f"  против записанной Delta 2026-08-04: 2234268.75")
