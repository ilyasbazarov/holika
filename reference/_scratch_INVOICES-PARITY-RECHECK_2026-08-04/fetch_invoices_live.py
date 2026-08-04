"""
Read-only снимок entity/invoiceout для INVOICES-PARITY-RECHECK (2026-08-04).

Форма запроса и формула конвертации — дословно из reference/code/cf-finance/invoices.py
(канон боевого загрузчика, ADR-110/INVOICES-LOADER-BUILD), не изобретаются заново:
  - пагинация: явный offset/limit (limit=100), не meta.nextHref
  - expand=state,agent,salesChannel,rate.currency
  - конвертация: sum/100 * rate.value; rate.value пуст + KGS -> 1.0;
    rate.value пуст + не-KGS -> текущий курс из entity/currency (ADR-029, без 1.0-заглушки)
  - sleep 0.25s между страницами, timeout=90 (ADR-055 §... / 02_ERP_CONTRACTS §поведение API)

Токен читается из переменной окружения MSKLAD_TOKEN, никогда не печатается.
"""

import os
import sys
import time
import json
import requests

MSKLAD_BASE = "https://api.moysklad.ru/api/remap/1.2"
LIMIT = 100
TIMEOUT = 90
SLEEP_S = 0.25
EXPAND = "state,agent,salesChannel,rate.currency"

_CURRENCY_RATE_CACHE = {}


def parse_href(meta_obj):
    href = (meta_obj or {}).get("meta", {}).get("href")
    return href.split("/")[-1].split("?")[0] if href else None


def api_get(session, headers, url, params):
    resp = session.get(url, headers=headers, params=params, timeout=TIMEOUT)
    resp.raise_for_status()
    return resp.json()


def fetch_current_rate(session, headers, iso_code):
    if iso_code in _CURRENCY_RATE_CACHE:
        return _CURRENCY_RATE_CACHE[iso_code]
    data = api_get(session, headers, f"{MSKLAD_BASE}/entity/currency", {})
    for c in data.get("rows", []):
        if c.get("isoCode") == iso_code:
            rate_field = c.get("rate")
            value = rate_field.get("value") if isinstance(rate_field, dict) else rate_field
            if value is None:
                raise RuntimeError(f"entity/currency: курс {iso_code} пуст, rate={rate_field!r}")
            _CURRENCY_RATE_CACHE[iso_code] = float(value)
            return _CURRENCY_RATE_CACHE[iso_code]
    raise RuntimeError(f"entity/currency: валюта {iso_code} не найдена")


def rate_and_currency(session, headers, doc):
    rate = doc.get("rate") or {}
    rate_value = rate.get("value")
    currency = rate.get("currency") or {}
    currency_code = currency.get("isoCode") or "KGS"

    if rate_value is not None:
        return float(rate_value), currency_code, False
    if currency_code == "KGS":
        return 1.0, currency_code, False
    rate_value = fetch_current_rate(session, headers, currency_code)
    return float(rate_value), currency_code, True


def main():
    token = os.environ.get("MSKLAD_TOKEN")
    if not token:
        print("MSKLAD_TOKEN не задан", file=sys.stderr)
        sys.exit(1)
    headers = {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}

    session = requests.Session()
    url = f"{MSKLAD_BASE}/entity/invoiceout"
    collected = []
    meta_size_first = None
    offset = 0

    while True:
        params = {"limit": LIMIT, "offset": offset, "expand": EXPAND}
        page = api_get(session, headers, url, params)
        rows = page.get("rows", [])
        if offset == 0:
            meta_size_first = page.get("meta", {}).get("size")
        collected.extend(rows)
        if len(rows) < LIMIT:
            break
        offset += LIMIT
        time.sleep(SLEEP_S)

    n = len(collected)
    print(f"G1 fetched={n} meta_size_first={meta_size_first}", file=sys.stderr)
    if n == 0:
        raise RuntimeError("G2 FAILED: fetched=0")
    if meta_size_first is not None and n < meta_size_first:
        raise RuntimeError(f"G1 FAILED: fetched={n} < meta_size_first={meta_size_first}")

    total_count = 0
    applicable_false = 0
    non_kgs_count = 0
    fallback_used_count = 0
    sum_kgs_total = 0.0
    payed_kgs_total = 0.0
    unpaid_kgs_total = 0.0
    state_breakdown = {}

    for doc in collected:
        if doc.get("applicable") is False:
            applicable_false += 1
            continue
        rate_value, currency_code, used_fallback = rate_and_currency(session, headers, doc)
        if currency_code != "KGS":
            non_kgs_count += 1
        if used_fallback:
            fallback_used_count += 1

        sum_minor = doc.get("sum") or 0
        payed_minor = doc.get("payedSum") or 0
        sum_kgs = round(sum_minor / 100.0 * rate_value, 2)
        payed_kgs = round(payed_minor / 100.0 * rate_value, 2)
        unpaid_kgs = round(sum_kgs - payed_kgs, 2)

        total_count += 1
        sum_kgs_total += sum_kgs
        payed_kgs_total += payed_kgs
        unpaid_kgs_total += unpaid_kgs

        state = (doc.get("state") or {}).get("name") or "(без статуса)"
        st = state_breakdown.setdefault(state, {"count": 0, "sum_kgs": 0.0})
        st["count"] += 1
        st["sum_kgs"] += sum_kgs

    result = {
        "fetched": n,
        "meta_size_first": meta_size_first,
        "applicable_false_excluded": applicable_false,
        "counted_documents": total_count,
        "non_kgs_documents": non_kgs_count,
        "fallback_rate_used_count": fallback_used_count,
        "sum_kgs_total": round(sum_kgs_total, 2),
        "payed_kgs_total": round(payed_kgs_total, 2),
        "unpaid_kgs_total": round(unpaid_kgs_total, 2),
        "state_breakdown": {
            k: {"count": v["count"], "sum_kgs": round(v["sum_kgs"], 2)}
            for k, v in sorted(state_breakdown.items())
        },
        "currency_rate_cache": _CURRENCY_RATE_CACHE,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
