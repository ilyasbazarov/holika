#!/usr/bin/env python3
"""
SALES-REFRESH-WINDOW-DELETE-DISCRIMINATE, ступень 3.
Read-only проверка: существует ли на стороне МойСклад документ отгрузки за
2026-05-12 по контрагенту agent_id=31d135bc-4df8-11f1-0a80-1c8a0053c5b4, и
содержит ли он позиции, дающие 1 980 000,00 KGS.

Мандат: reference/dq_deploy_accept_adj_2026-08-18.md §10.
Форма секрета/логирования: ADR-076 §5, ADR-079 §6.
Только чтение. Ни одной записи ни в МойСклад, ни в BigQuery.
"""
import json
import subprocess
import sys
import time
from datetime import datetime, timezone

import requests

MSKLAD_BASE = "https://api.moysklad.ru/api/remap/1.2"
MSKLAD_RPS = 4
SECRET_TOKEN = "msklad-token"
GCP_PROJECT = "msklad-bi-prod"
AGENT_ID = "31d135bc-4df8-11f1-0a80-1c8a0053c5b4"
MOMENT_FROM = "2026-05-12 00:00:00"
MOMENT_TO = "2026-05-12 23:59:59"
SCRATCH = "reference/_scratch_SALES-REFRESH-WINDOW-DELETE-STAGE3_2026-08-18"
EXPECTED_SUM_KGS = 1_980_000.00


def utc_anchor(label):
    print(f"=== UTC anchor ({label}) ===")
    print(datetime.now(timezone.utc).isoformat())


def caller_identity(label):
    print(f"=== caller identity ({label}) ===")
    out = subprocess.run(
        ["gcloud", "auth", "list"], capture_output=True, text=True, check=False
    )
    print(out.stdout)
    if out.returncode != 0:
        print(out.stderr, file=sys.stderr)


def get_token():
    # Секрет резолвится inline через gcloud (ADR-014), не печатается (ADR-076 §5.1).
    out = subprocess.run(
        [
            "gcloud", "secrets", "versions", "access", "latest",
            f"--secret={SECRET_TOKEN}", f"--project={GCP_PROJECT}",
        ],
        capture_output=True, text=True, check=True,
    )
    return out.stdout.strip()


def build_headers(token):
    # Форма — reference/code/cf-finance/main.py:24 (снапшот, не изобретена).
    return {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}


def api_get(session, url, headers, params=None):
    time.sleep(1.0 / MSKLAD_RPS)
    resp = session.get(url, headers=headers, params=params, timeout=90)
    resp.raise_for_status()
    return resp.json()


def log_field_names(label, data):
    # ADR-079 §6: логируются ИМЕНА полей строки данных, а не первые N символов тела.
    rows = data.get("rows", [])
    print(f"--- {label}: meta.size={data.get('meta', {}).get('size')} rows_returned={len(rows)}")
    if rows:
        print(f"--- {label}: поля первой строки: {sorted(rows[0].keys())}")


def main():
    utc_anchor("start")
    caller_identity("start")

    token = get_token()
    session = requests.Session()
    headers = build_headers(token)

    calls_made = 0

    # Шаг 1: список entity/demand за 2026-05-12 (один календарный день).
    url1 = f"{MSKLAD_BASE}/entity/demand"
    params1 = {
        "filter": f"moment>={MOMENT_FROM};moment<={MOMENT_TO}",
        "order": "moment,asc",
        "limit": 1000,
        "offset": 0,
    }
    data1 = api_get(session, url1, headers, params1)
    calls_made += 1
    log_field_names("шаг1 entity/demand", data1)
    with open(f"{SCRATCH}/step1_demands_raw.json", "w") as f:
        json.dump(data1, f, ensure_ascii=False, indent=2)

    rows = data1.get("rows", [])
    print(f"Всего документов entity/demand за 2026-05-12: {len(rows)}")

    matches = []
    for row in rows:
        agent_href = row.get("agent", {}).get("meta", {}).get("href", "")
        if agent_href.rstrip("/").endswith(AGENT_ID):
            matches.append(row)

    print(f"Документов с agent_id={AGENT_ID}: {len(matches)}")
    for m in matches:
        print(f"  demand id={m.get('id')} name={m.get('name')} moment={m.get('moment')}")

    if not matches:
        print("РЕЗУЛЬТАТ: документ по паре (2026-05-12, agent_id) в источнике ОТСУТСТВУЕТ.")
        print("Гипотеза (a) подтверждена для этой пары: удаление законно.")
        utc_anchor("end")
        caller_identity("end")
        print(f"Всего живых вызовов API: {calls_made}")
        return

    # Шаг 2: позиции каждого найденного документа (expand не работает в списке — helpers.py).
    total_sum = 0.0
    position_rows_all = []
    for m in matches:
        demand_id = m.get("id")
        rate_obj = m.get("rate", {}) or {}
        currency_rate = rate_obj.get("value") or 1.0
        url2 = f"{MSKLAD_BASE}/entity/demand/{demand_id}/positions"
        data2 = api_get(session, url2, headers, {"limit": 1000, "offset": 0})
        calls_made += 1
        log_field_names(f"шаг2 positions demand={demand_id}", data2)
        with open(f"{SCRATCH}/step2_positions_{demand_id}.json", "w") as f:
            json.dump(data2, f, ensure_ascii=False, indent=2)

        for pos in data2.get("rows", []):
            price_kgs = pos.get("price", 0) / 100.0 * currency_rate
            quantity = pos.get("quantity", 0.0)
            discount = pos.get("discount", 0.0)
            revenue_kgs = round(price_kgs * quantity * (1.0 - discount / 100.0), 2)
            total_sum += revenue_kgs
            position_rows_all.append(
                {"demand_id": demand_id, "position_id": pos.get("id"), "revenue_kgs": revenue_kgs}
            )

    print(f"Сумма позиций найденных документов: {round(total_sum, 2)} KGS")
    print(f"Ожидаемая сумма остатка (ступень 2): {EXPECTED_SUM_KGS} KGS")
    print(f"Совпадение (допуск 0,01 KGS): {abs(round(total_sum, 2) - EXPECTED_SUM_KGS) <= 0.01}")

    print("РЕЗУЛЬТАТ: документ по паре (2026-05-12, agent_id) в источнике НАЙДЕН.")
    print("Гипотеза (b) подтверждена для этой пары: удаление было дефектом выгрузки/загрузки.")

    utc_anchor("end")
    caller_identity("end")
    print(f"Всего живых вызовов API: {calls_made}")


if __name__ == "__main__":
    main()
