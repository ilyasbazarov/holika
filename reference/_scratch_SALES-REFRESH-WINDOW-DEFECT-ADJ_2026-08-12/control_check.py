#!/usr/bin/env python3
"""SALES-REFRESH-WINDOW-DEFECT-ADJ — положительный контроль критерия различителя.

Критерий различителя (мой, `…delete_adj…§4a` п.2): «документ контрагента есть в архиве
выгрузки, а конкретная позиция отсутствует» => ДЕФЕКТ выгрузки.

Контроль: применить тот же критерий к СЕМИ строкам, про которые уже доказано независимо
(`ADR-100 §1`, три совпавших признака), что их удаление ЗАКОННО. Если критерий метит их
дефектом — он не разделяет гипотезы, и вердикт по 19 строкам не обоснован.

Read-only, локальный архив, облачных вызовов нет."""
import json, datetime
from collections import defaultdict

A = ("../SALES-REFRESH-WINDOW-DELETE-DISCRIMINATE/reference/"
     "_scratch_SALES-REFRESH-WINDOW-DELETE-DISCRIMINATE_2026-08-12/archive_106b.ndjson")
recs = [json.loads(l) for l in open(A) if l.strip()]

def bishkek(raw):                      # тот же приём, что _PARSE_DATE (UTC + 6ч, без DST)
    dt = datetime.datetime.strptime(raw[:19], "%Y-%m-%d %H:%M:%S")
    return (dt + datetime.timedelta(hours=6)).date().isoformat()

idx = defaultdict(lambda: {"docs": set(), "pos": 0})
for r in recs:
    k = (bishkek(r["transaction_date_raw"]), r["agent_id"])
    idx[k]["docs"].add(r["demand_id"]); idx[k]["pos"] += 1

print(f"записей в архиве: {len(recs)}")

# Семь сирот ADR-100 §1 — эталон «удаление законно» (подпись 2+2+3)
ORPHANS = [("2026-05-07", "b2c49334-f066-11f0-0a80-0c49000a9f1e", 2),
           ("2026-05-09", "deb32c34-990c-11ef-0a80-19eb00083704", 2),
           ("2026-05-26", "b2c49334-f066-11f0-0a80-0c49000a9f1e", 3)]

print("\n=== ПОЛОЖИТЕЛЬНЫЙ КОНТРОЛЬ: применяем критерий к ЗАВЕДОМО ЗАКОННЫМ удалениям ===")
fp = 0
for d, a, n in ORPHANS:
    v = idx.get((d, a), {"docs": set(), "pos": 0})
    hit = len(v["docs"]) > 0
    if hit: fp += n
    print(f"  {d}  агент {a[:8]}…  удалено {n}  документов в архиве {len(v['docs'])}  "
          f"позиций {v['pos']:>3}  -> критерий говорит: "
          f"{'ДЕФЕКТ (ложно!)' if hit else 'документ отсутствует'}")

print(f"\nложных срабатываний: {fp} из 7 строк заведомо ЗАКОННОГО удаления")
print("подпись критерия принимает ОБА значения на размеченном наборе =>")
print("признак 'документ есть, позиции нет' информации о дефекте НЕ несёт.")
print("\nПричина: ADR-100 §1 определяет механизм сирот дословно как «ПОЗИЦИЯ, удалённая в")
print("источнике задним числом» — то есть документ остаётся, а позиция исчезает. Это ровно")
print("та подпись, которую различитель объявил дефектом.")
