#!/usr/bin/env python3
# PARITY-STOCK-INTRANSIT-CLOSE · шаг 2 — офлайн-сопоставление множеств заказов.
# Облачных вызовов нет: читает лог шага 1 (наша сторона) и уже лежащие в репо сырые тела
# ответов источника, снятые сессией PARITY-INTRANSIT-ROWWISE 2026-08-04T05:31Z.
import json, re, sys, os

SCR_NEW = "reference/_scratch_PARITY-STOCK-INTRANSIT-CLOSE_2026-08-04"
SCR_OLD = "reference/_scratch_PARITY-STOCK-INTRANSIT_2026-08-04"

log = open(f"{SCR_NEW}/step1_run.log", encoding="utf-8").read()

def block(marker):
    """JSON-массив, идущий сразу после строки-маркера в логе."""
    i = log.index(marker)
    j = log.index("[", i)
    depth, k = 0, j
    while True:
        if log[k] == "[":
            depth += 1
        elif log[k] == "]":
            depth -= 1
            if depth == 0:
                break
        k += 1
    return json.loads(log[j:k + 1])

ours = block("=== step1c:")
mart = block("=== step1d:")
agg_pos = block("=== step1a:")[0]
agg_all = block("=== step1b:")[0]

src_ids = set(json.load(open(f"{SCR_OLD}/step2_target_order_ids.json", encoding="utf-8")))
# ВАЖНО: `step2_purchaseorder_all.json` прежней сессии содержит только счётчики
# (`meta_size`, `n_fetched`), а не тела 211 заказов — состояние конкретного заказа в источнике
# офлайн не восстанавливается. Это ограничение метода, не факт об источнике (★ Успех инструмента ≠ факт).
src_all = json.load(open(f"{SCR_OLD}/step2_purchaseorder_all.json", encoding="utf-8"))
assert set(src_all) == {"meta_size", "n_fetched"}, src_all
src_state = {}
print(f"сырые тела заказов источника в репо отсутствуют — сохранены только счётчики {src_all}")

our_ids = {r["purchase_order_id"] for r in ours}
mart_ids = {r["purchase_order_id"] for r in mart}
our_by_id = {r["purchase_order_id"]: r for r in ours}

print(f"источник (живой GET 2026-08-04T05:31Z), заказов в целевых статусах: {len(src_ids)}")
print(f"наша сторона core.fact_purchases, целевые статусы И in_transit>0:   {len(our_ids)}"
      f"  ({agg_pos['n_positions']} позиций, {agg_pos['sum_in_transit_kgs']} KGS)")
print(f"наша сторона, целевые статусы БЕЗ фильтра суммы:                    "
      f"{agg_all['n_orders']} заказов, {agg_all['n_positions']} позиций")
print(f"marts.in_transit, заказов:                                          {len(mart_ids)}")
print()

only_src = sorted(src_ids - our_ids)
only_our = sorted(our_ids - src_ids)
print(f"(а) есть у источника, нет у нас в целевых статусах: {len(only_src)}")
for i in only_src:
    print(f"    {i}  состояние в источнике сейчас: {src_state.get(i, '(нет в выгрузке)')}")
print(f"(б) есть у нас в целевых статусах, нет у источника: {len(only_our)}")
tail_sum = 0.0
for i in only_our:
    r = our_by_id[i]
    tail_sum += float(r["sum_in_transit_kgs"])
    print(f"    {i}  {r['order_name']}  наш статус: {r['status_name']}  "
          f"позиций {r['n_positions']}  сумма {r['sum_in_transit_kgs']}  "
          f"| состояние в источнике сейчас: {src_state.get(i, '(нет в выгрузке 211 заказов)')}")
print(f"    сумма одностороннего хвоста (б): {tail_sum:,.2f} KGS".replace(",", " "))
print()

print("сверка совпавшего ядра (id, присутствующие с обеих сторон):", len(src_ids & our_ids))
print("marts.in_transit минус core (целевые статусы):", sorted(mart_ids - our_ids))
print("core (целевые статусы) минус marts.in_transit:", sorted(our_ids - mart_ids))
