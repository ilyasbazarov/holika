#!/usr/bin/env python3
"""Таблица датированного снимка мая-2026 — наша сторона, состояние 2026-07-19."""
import json
SRC = "reference/_scratch_PARITY-SALES-DISCRIMINATE_2026-08-01"
core = json.load(open(f"{SRC}/step1b_by_date.json"))
api = json.load(open(f"{SRC}/step2_by_day.json"))
tr = tn = 0
ta = 0.0
tan = 0
print("| Сутки | Строк (наша сторона) | Сумма KGS (наша сторона) | Документов (источник) | Сумма KGS (источник) |")
print("|---|---:|---:|---:|---:|")
for r in core:
    d = r["transaction_date"]; n = int(r["n_rows"]); s = float(r["sum_revenue_kgs"])
    an = api.get(d, {}).get("n", 0); asum = float(api.get(d, {}).get("sum_kgs", 0.0))
    tn += n; tr += s; tan += an; ta += asum
    print(f"| `{d}` | {n} | {s:,.2f} | {an} | {asum:,.2f} |".replace(",", " "))
print(f"| **итого** | **{tn}** | **{tr:,.2f}** | **{tan}** | **{ta:,.2f}** |".replace(",", " "))
print(f"\nразность (наша − источник): {tr - ta:,.2f} KGS".replace(",", " "))
