"""
step1_fetch_demands.py — SALES-JULY-K2K3-DISCRIMINATE, шаг (1) приёмки (ADR-141 §5).

Списочный GET entity/demand за пять локализованных суток БЕЗ фильтра applicable.
Границы суток — правило ADR-088/ADR-137 §8: суточная граница по DATE(moment, 'Asia/Bishkek'),
что при API-времени в UTC даёт окно [D-1 18:00:00, D 17:59:59] UTC для суток D.

Читает MSKLAD_TOKEN из окружения (передаётся вызывающим скриптом, не печатается).
Пишет: raw_<date>.json (полный ответ по каждой дате) и summary.json (агрегат).
"""
import json
import os
import sys
import time
from datetime import date, timedelta

import requests

BASE = "https://api.moysklad.ru/api/remap/1.2/entity/demand"
PAGE_SIZE = 100
RPS_SLEEP = 0.25  # ADR-016/02_ERP_CONTRACTS §поведение-API: 429 back-off budget

DATES = ["2026-07-20", "2026-07-21", "2026-07-27", "2026-07-29", "2026-07-30"]

OUT_DIR = os.path.dirname(os.path.abspath(__file__))


def bishkek_day_utc_window(d_str: str) -> tuple[str, str]:
    d = date.fromisoformat(d_str)
    prev = d - timedelta(days=1)
    moment_from = f"{prev.isoformat()} 18:00:00"
    moment_to = f"{d.isoformat()} 17:59:59"
    return moment_from, moment_to


def fetch_all(token: str, moment_from: str, moment_to: str) -> list[dict]:
    headers = {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}
    params = {
        "filter": f"moment>={moment_from};moment<={moment_to}",
        "order": "moment,asc",
        "expand": "agent",
        "limit": PAGE_SIZE,
        "offset": 0,
    }
    rows: list[dict] = []
    while True:
        time.sleep(RPS_SLEEP)
        resp = requests.get(BASE, headers=headers, params=params, timeout=90)
        resp.raise_for_status()
        payload = resp.json()
        batch = payload.get("rows", [])
        rows.extend(batch)
        meta = payload.get("meta", {})
        size = meta.get("size", len(rows))
        if params["offset"] + PAGE_SIZE >= size:
            break
        params["offset"] += PAGE_SIZE
    return rows


def main() -> None:
    token = os.environ.get("MSKLAD_TOKEN")
    if not token:
        print("CONTEXT GAP: MSKLAD_TOKEN не задан в окружении", file=sys.stderr)
        sys.exit(1)

    summary = {}
    for d_str in DATES:
        moment_from, moment_to = bishkek_day_utc_window(d_str)
        print(f"[{d_str}] окно UTC: {moment_from} .. {moment_to}", file=sys.stderr)
        rows = fetch_all(token, moment_from, moment_to)

        records = []
        for r in rows:
            agent = r.get("agent", {})
            agent_name = agent.get("name") if isinstance(agent, dict) else None
            records.append({
                "id": r.get("id"),
                "name": r.get("name"),
                "moment": r.get("moment"),
                "applicable": r.get("applicable"),
                "sum": r.get("sum"),
                "agent_name": agent_name,
            })

        out_path = os.path.join(OUT_DIR, f"raw_{d_str}.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(records, f, ensure_ascii=False, indent=2)

        n_total = len(records)
        n_not_applicable = sum(1 for x in records if x["applicable"] is False)
        summary[d_str] = {
            "moment_from_utc": moment_from,
            "moment_to_utc": moment_to,
            "n_documents": n_total,
            "n_not_applicable": n_not_applicable,
            "sum_all_minor": sum(x["sum"] or 0 for x in records),
            "sum_not_applicable_minor": sum(x["sum"] or 0 for x in records if x["applicable"] is False),
        }
        print(f"[{d_str}] документов: {n_total}, непроведённых: {n_not_applicable}", file=sys.stderr)

    summary_path = os.path.join(OUT_DIR, "summary.json")
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
