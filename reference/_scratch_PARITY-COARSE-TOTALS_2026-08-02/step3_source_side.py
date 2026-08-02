#!/usr/bin/env python3
"""
step3_source_side.py — живые GET к МойСклад для трёх пар PARITY-COARSE-TOTALS.
Токен читается ТОЛЬКО из переменной окружения MSKLAD_TOKEN (не печатается).
Форма заголовка авторизации — дословно reference/code/cf-finance/main.py:39.
"""
import json
import os
import sys
import time

import requests

MSKLAD_BASE = "https://api.moysklad.ru/api/remap/1.2"
SCRATCH = "reference/_scratch_PARITY-COARSE-TOTALS_2026-08-02"

TOKEN = os.environ.get("MSKLAD_TOKEN")
if not TOKEN:
    print("CONTEXT GAP: MSKLAD_TOKEN не задан в окружении", file=sys.stderr)
    sys.exit(2)

HEADERS = {"Authorization": f"Bearer {TOKEN}", "Accept-Encoding": "gzip"}

# Известные статусы заказов поставщику (reference/code/cf-facts/fetch_purchases.py:20-26)
PURCHASE_ORDER_STATES = {
    "491d6da5-8b37-11ef-0a80-0762000253a8": "В пути",
    "491d62b6-8b37-11ef-0a80-0762000253a7": "Прибыл",
    "87b7a192-349f-11f1-0a80-1a0f000384c2": "Прибыл частично",
    "87b7a5e5-349f-11f1-0a80-1a0f000384c3": "Отменен",
}
TARGET_STATUS_IDS = {
    "491d6da5-8b37-11ef-0a80-0762000253a8",  # В пути
    "87b7a192-349f-11f1-0a80-1a0f000384c2",  # Прибыл частично
}

session = requests.Session()


def api_get(path, params=None):
    url = f"{MSKLAD_BASE}/{path}"
    time.sleep(0.25)
    resp = session.get(url, headers=HEADERS, params=params, timeout=90)
    return resp


def parse_href(href):
    if not href:
        return None
    return href.rstrip("/").rsplit("/", 1)[-1] or None


def save_raw(name, obj):
    path = f"{SCRATCH}/{name}"
    with open(path, "w") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
    return path


def log_keys(label, row):
    if row:
        print(f"  {label} — ключи первой строки данных: {sorted(row.keys())}")
    else:
        print(f"  {label} — строк данных нет (пустой массив)")


# ── 1) report/stock/all ──────────────────────────────────────────────────────
print("=== report/stock/all ===")
all_stock_rows = []
offset = 0
page_no = 0
while True:
    resp = api_get("report/stock/all", params={"limit": 1000, "offset": offset})
    print(f"  page offset={offset} HTTP={resp.status_code}")
    if resp.status_code != 200:
        print(f"  CONTEXT GAP: report/stock/all вернул {resp.status_code}, тело: {resp.text[:500]}")
        sys.exit(3)
    data = resp.json()
    page_no += 1
    save_raw(f"step3_stock_all_page{page_no}.json", data)
    rows = data.get("rows", [])
    if page_no == 1:
        log_keys("report/stock/all", rows[0] if rows else None)
        print(f"  meta: {data.get('meta')}")
    all_stock_rows.extend(rows)
    if len(rows) < 1000:
        break
    offset += 1000

sum_stock_source = sum(r.get("stock", 0) or 0 for r in all_stock_rows)
n_stock_rows = len(all_stock_rows)
print(f"  ИТОГО report/stock/all: строк={n_stock_rows}, sum(stock)={sum_stock_source}")

# ── 2) entity/purchaseorder — фильтр по статусам «В пути»/«Прибыл частично» ──
print("=== entity/purchaseorder ===")
all_orders = []
offset = 0
page_no = 0
while True:
    resp = api_get("entity/purchaseorder", params={"limit": 1000, "offset": offset})
    print(f"  page offset={offset} HTTP={resp.status_code}")
    if resp.status_code != 200:
        print(f"  CONTEXT GAP: entity/purchaseorder вернул {resp.status_code}, тело: {resp.text[:500]}")
        sys.exit(3)
    data = resp.json()
    page_no += 1
    save_raw(f"step3_purchaseorder_page{page_no}.json", data)
    rows = data.get("rows", [])
    if page_no == 1:
        log_keys("entity/purchaseorder", rows[0] if rows else None)
        print(f"  meta: {data.get('meta')}")
    all_orders.extend(rows)
    if len(rows) < 1000:
        break
    offset += 1000

print(f"  всего заказов (без фильтра статуса): {len(all_orders)}")

matched_orders = []
for order in all_orders:
    state_href = order.get("state", {}).get("meta", {}).get("href", "")
    status_id = parse_href(state_href)
    if status_id in TARGET_STATUS_IDS:
        matched_orders.append(order)

print(f"  заказов в статусах «В пути»/«Прибыл частично»: {len(matched_orders)}")
by_status_count = {}
for o in matched_orders:
    sid = parse_href(o.get("state", {}).get("meta", {}).get("href", ""))
    name = PURCHASE_ORDER_STATES.get(sid, "?")
    by_status_count[name] = by_status_count.get(name, 0) + 1
print(f"  разбивка по статусу: {by_status_count}")

# Позиции по каждому совпавшему заказу — формула fetch_purchases.py:141/147
total_in_transit_sum_kgs = 0.0
non_kgs_orders = []
positions_log = []
for i, order in enumerate(matched_orders):
    order_id = order.get("id")
    order_name = order.get("name")
    currency_rate = order.get("rate", {}).get("value") or 1.0
    currency_href = order.get("rate", {}).get("currency", {}).get("meta", {}).get("href", "")

    pos_all = []
    pos_offset = 0
    while True:
        presp = api_get(f"entity/purchaseorder/{order_id}/positions", params={"limit": 1000, "offset": pos_offset})
        if presp.status_code != 200:
            print(f"  CONTEXT GAP: positions {order_id} вернул {presp.status_code}")
            sys.exit(3)
        pdata = presp.json()
        prows = pdata.get("rows", [])
        pos_all.extend(prows)
        if len(prows) < 1000:
            break
        pos_offset += 1000

    if i == 0:
        save_raw(f"step3_purchaseorder_{order_id}_positions.json", {"rows": pos_all})
        log_keys("entity/purchaseorder/{id}/positions (первый совпавший заказ)", pos_all[0] if pos_all else None)

    order_in_transit_sum = 0.0
    for pos in pos_all:
        quantity_in_transit = pos.get("inTransit", 0.0) or 0.0
        price = pos.get("price") or 0
        discount = pos.get("discount", 0.0) or 0.0
        price_kgs = (price / 100.0) * currency_rate
        in_transit_sum_kgs = price_kgs * quantity_in_transit * (1.0 - discount / 100.0)
        order_in_transit_sum += in_transit_sum_kgs

    total_in_transit_sum_kgs += order_in_transit_sum
    if currency_rate != 1.0 or "usd" in currency_href.lower() or "rub" in currency_href.lower():
        non_kgs_orders.append({"order_name": order_name, "order_id": order_id, "rate": currency_rate, "currency_href": currency_href, "order_in_transit_sum_kgs": order_in_transit_sum})

print(f"  ИТОГО источник in_transit_sum_kgs (позиционная формула fetch_purchases.py): {total_in_transit_sum_kgs}")
print(f"  заказов с курсом != 1.0 (потенциально не-KGS): {len(non_kgs_orders)}")
if non_kgs_orders:
    print(f"  детали не-KGS заказов: {json.dumps(non_kgs_orders, ensure_ascii=False)}")

# ── 3) entity/invoiceout — sum/payedSum, разрез по currency ──────────────────
print("=== entity/invoiceout ===")
all_invoices = []
offset = 0
page_no = 0
while True:
    resp = api_get("entity/invoiceout", params={"limit": 100, "offset": offset, "expand": "rate.currency"})
    print(f"  page offset={offset} HTTP={resp.status_code}")
    if resp.status_code != 200:
        print(f"  CONTEXT GAP: entity/invoiceout вернул {resp.status_code}, тело: {resp.text[:500]}")
        sys.exit(3)
    data = resp.json()
    page_no += 1
    if page_no <= 2:
        save_raw(f"step3_invoiceout_page{page_no}.json", data)
    rows = data.get("rows", [])
    if page_no == 1:
        log_keys("entity/invoiceout", rows[0] if rows else None)
        print(f"  meta: {data.get('meta')}")
    all_invoices.extend(rows)
    if len(rows) < 100:
        break
    offset += 100

n_invoices = len(all_invoices)
sum_invoiced = 0.0
sum_payed = 0.0
non_kgs_invoices = []
for inv in all_invoices:
    s = (inv.get("sum") or 0) / 100.0
    p = (inv.get("payedSum") or 0) / 100.0
    sum_invoiced += s
    sum_payed += p
    iso = inv.get("rate", {}).get("currency", {}).get("isoCode")
    if iso and iso != "KGS":
        non_kgs_invoices.append({"id": inv.get("id"), "name": inv.get("name"), "isoCode": iso, "sum_minor_units_native": s, "payedSum_minor_units_native": p})

print(f"  ИТОГО entity/invoiceout: строк={n_invoices}, sum (raw, /100, без rate)={sum_invoiced}, payedSum (raw)={sum_payed}")
print(f"  документов не-KGS: {len(non_kgs_invoices)}")
if non_kgs_invoices:
    non_kgs_sum = sum(x["sum_minor_units_native"] for x in non_kgs_invoices)
    print(f"  сумма не-KGS документов (в их нативной валюте, НЕ приведено к сому)={non_kgs_sum}")
    save_raw("step3_invoiceout_non_kgs.json", non_kgs_invoices)

# ── Итог для артефакта ───────────────────────────────────────────────────────
summary = {
    "stock": {"n_rows": n_stock_rows, "sum_stock": sum_stock_source},
    "in_transit": {
        "n_orders_total": len(all_orders),
        "n_orders_matched_status": len(matched_orders),
        "by_status_count": by_status_count,
        "sum_in_transit_kgs": total_in_transit_sum_kgs,
        "non_kgs_orders_count": len(non_kgs_orders),
    },
    "invoiceout": {
        "n_rows": n_invoices,
        "sum_invoiced_raw": sum_invoiced,
        "sum_payed_raw": sum_payed,
        "non_kgs_count": len(non_kgs_invoices),
    },
}
save_raw("step3_summary.json", summary)
print("=== SUMMARY ===")
print(json.dumps(summary, ensure_ascii=False, indent=2))
