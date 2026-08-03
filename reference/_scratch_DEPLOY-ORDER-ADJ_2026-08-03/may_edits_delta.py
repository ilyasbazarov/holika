#!/usr/bin/env python3
"""Менялись ли суммы трёх недосягаемых майских документов — офлайн, без живого запроса.

Приём: наша сторона (core) заморожена состоянием 2026-07-19; сторона источника скачана 2026-08-01,
то есть УЖЕ после правок 07-21/07-22/07-25. Значит посуточная разность двух сторон, посчитанная
2026-08-01, обязана показать эффект этих правок — если он в суммах есть.
Оба входа уже лежат в репо и в новых замерах не нуждаются.
"""
import json, datetime
SRC = "reference/_scratch_PARITY-SALES-DISCRIMINATE_2026-08-01"
core = {r["transaction_date"]: (int(r["n_rows"]), float(r["sum_revenue_kgs"]))
        for r in json.load(open(f"{SRC}/step1b_by_date.json"))}
api = {d: (v["n"], float(v["sum_kgs"]))
       for d, v in json.load(open(f"{SRC}/step2_by_day.json")).items()}
TARGET = {"2026-05-03": "№04195 (337 838,40 KGS, правлен 2026-07-22)",
          "2026-05-09": "№04456x (12 513 033,52 KGS, правлен 2026-07-21)",
          "2026-05-10": "№04227 (146 665,80 KGS, правлен 2026-07-25)"}
print("наша сторона — core.fact_sales_profit, состояние 2026-07-19 (промоут с тех пор заблокирован)")
print("сторона источника — заголовки entity/demand, скачаны 2026-08-01, ПОСЛЕ правок\n")
print(f"{'сутки':<12}{'строк core':>11}{'док. API':>10}{'сумма core':>18}{'сумма API':>18}{'разность':>16}   пометка")
tot = 0.0
for d in sorted(set(core) | set(api)):
    cn, cs = core.get(d, (0, 0.0))
    an, asum = api.get(d, (0, 0.0))
    diff = cs - asum
    tot += diff
    mark = ""
    if abs(diff) >= 0.01:
        mark = "РАСХОЖДЕНИЕ"
    if d in TARGET:
        mark = (mark + "  ← " + TARGET[d]).strip()
    print(f"{d:<12}{cn:>11}{an:>10}{cs:>18,.2f}{asum:>18,.2f}{diff:>16,.2f}   {mark}")
print(f"\nсумма разностей по всем суткам: {tot:,.2f}")
print("\nвывод по трём целевым суткам:")
for d, who in TARGET.items():
    cn, cs = core.get(d, (0, 0.0)); an, asum = api.get(d, (0, 0.0))
    diff = cs - asum
    verdict = ("суммы совпадают до копейки — правка НЕ изменила денежный итог суток"
               if abs(diff) < 0.01 else f"расхождение {diff:,.2f} KGS — разбирать отдельно")
    print(f"  {d}  {who}\n      {verdict}")
