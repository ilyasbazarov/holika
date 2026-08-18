"""
check_source_resume.py — продолжение SALES-REFRESH-WINDOW-DELETE-SOURCE-CHECK после остановки
на потолке 40 вызовов (владелец подтвердил продолжение, чат 2026-08-18).

Не повторяет уже исполненные вызовы (result.json первого прогона). Докрывает ветку отрицательного
результата (§12) для 5 дат, оставшихся непроверенными: 2026-07-20 (не хватило только
commissionreportin), 2026-07-21, 2026-07-27, 2026-07-29, 2026-07-30. Read-only, тот же метод.
"""

import csv
import hashlib
import json
import os
import sys
import time

import requests

MSKLAD_BASE = "https://api.moysklad.ru/api/remap/1.2"
TIMEOUT = 90
SLEEP_S = 0.25
CALL_CAP = 20  # новый пакет, объявлен отдельно владельцу

INPUT_CSV = "reference/deleted_27_2026-08-18.csv"
SCRATCH = "reference/_scratch_SALES-REFRESH-WINDOW-DELETE-SOURCE-CHECK_2026-08-18"

call_count = 0


def log(msg):
    print(msg, flush=True)


def parse_href(href):
    if not href:
        return None
    return href.rstrip("/").split("/")[-1]


def api_get(session, headers, path, params=None):
    global call_count
    call_count += 1
    if call_count > CALL_CAP:
        log(f"STOP: call cap {CALL_CAP} exceeded at call #{call_count} ({path})")
        sys.exit(2)
    url = f"{MSKLAD_BASE}/{path}"
    log(f"CALL #{call_count}: GET {path} params={params}")
    resp = session.get(url, headers=headers, params=params, timeout=TIMEOUT)
    time.sleep(SLEEP_S)
    if resp.status_code == 429:
        log("429 Too Many Requests — one retry after 5s")
        time.sleep(5)
        call_count += 1
        if call_count > CALL_CAP:
            log(f"STOP: call cap {CALL_CAP} exceeded on retry")
            sys.exit(2)
        resp = session.get(url, headers=headers, params=params, timeout=TIMEOUT)
        time.sleep(SLEEP_S)
    resp.raise_for_status()
    return resp.json()


def fetch_doc_list(session, headers, entity, date_str):
    moment_from = f"{date_str} 00:00:00"
    moment_to = f"{date_str} 23:59:59"
    data = api_get(
        session,
        headers,
        f"entity/{entity}",
        params={"filter": f"moment>={moment_from};moment<={moment_to}", "limit": 100},
    )
    rows = data.get("rows", [])
    meta = data.get("meta") or {}
    size = meta.get("size", len(rows))
    if size > len(rows):
        log(f"WARNING: entity/{entity} {date_str} meta.size={size} > fetched={len(rows)} — pagination gap, not handled (out of scope §12)")
    return rows


def fetch_positions(session, headers, entity, doc_id):
    data = api_get(session, headers, f"entity/{entity}/{doc_id}/positions")
    return data.get("rows", [])


def txn_id(a, b):
    return hashlib.md5(f"{a}|{b}".encode("utf-8")).hexdigest()


def main():
    token = os.environ.get("MSKLAD_TOKEN")
    if not token:
        log("CONTEXT GAP: MSKLAD_TOKEN not set in environment")
        sys.exit(1)

    # Первый прогон остановился на потолке 40 ДО записи result.json (sys.exit внутри
    # api_get). Состояние восстановлено из run_check.log (закоммичен, тот же прогон):
    # demand-ветка дала 0/27 совпадений; ветка отрицательного результата дала ОБА
    # эндпоинта пустыми (retaildemand=0 match, commissionreportin=0 match) для шести дат;
    # для 2026-07-20 retaildemand уже проверен (0 match), commissionreportin — нет.
    prev = {
        "call_count": 40,
        "found": {},
        "negative_branch_checked": {
            "2026-06-03": {"retaildemand": False, "commissionreportin": False},
            "2026-06-04": {"retaildemand": False, "commissionreportin": False},
            "2026-06-15": {"retaildemand": False, "commissionreportin": False},
            "2026-07-02": {"retaildemand": False, "commissionreportin": False},
            "2026-07-11": {"retaildemand": False, "commissionreportin": False},
            "2026-07-13": {"retaildemand": False, "commissionreportin": False},
            "2026-07-20": {"retaildemand": False},
        },
        "control_found": {
            "786f54b87f1e81ecf04efead3ab59250": "4ec09bec-4df8-11f1-0a80-1c8a0053cab5",
            "8e05d4b486a48d5b018df201217eb7f3": "4ec09bec-4df8-11f1-0a80-1c8a0053cab5",
        },
        "control_matched_count": 1,
    }

    with open(INPUT_CSV, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        input_rows = list(reader)

    pairs = {}
    by_txn = {}
    for row in input_rows:
        d = row["transaction_date"]
        a = row["agent_id"]
        pairs.setdefault(d, set()).add(a)
        by_txn[row["transaction_id"]] = row

    found = dict(prev["found"])
    negative_branch_checked = dict(prev["negative_branch_checked"])

    session = requests.Session()
    headers = {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}

    # ── Remaining work: finish 2026-07-20 (commissionreportin only), then full negative
    #    branch for 2026-07-21 / 2026-07-27 / 2026-07-29 / 2026-07-30 ──
    remaining_plan = [
        ("2026-07-20", ["commissionreportin"]),
        ("2026-07-21", ["retaildemand", "commissionreportin"]),
        ("2026-07-27", ["retaildemand", "commissionreportin"]),
        ("2026-07-29", ["retaildemand", "commissionreportin"]),
        ("2026-07-30", ["retaildemand", "commissionreportin"]),
    ]

    for date_str, entities in remaining_plan:
        agents = pairs[date_str]
        log(f"=== NEGATIVE BRANCH (resume) DATE {date_str}: agents={sorted(agents)} ===")
        neg_result = dict(negative_branch_checked.get(date_str, {}))
        for entity in entities:
            docs = fetch_doc_list(session, headers, entity, date_str)
            matched = [
                d for d in docs
                if parse_href(d.get("agent", {}).get("meta", {}).get("href", "")) in agents
            ]
            log(f"{entity} {date_str}: {len(docs)} docs, {len(matched)} match input agents")
            neg_result[entity] = len(matched) > 0
            for doc in matched:
                doc_id = doc["id"]
                positions = fetch_positions(session, headers, entity, doc_id)
                for pos in positions:
                    tid = txn_id(doc_id, pos["id"])
                    if tid in by_txn:
                        found[tid] = doc_id
        negative_branch_checked[date_str] = neg_result

    unresolved_final = [tid for tid in by_txn if tid not in found]
    log(f"FINAL: {len(found)}/{len(by_txn)} found, {len(unresolved_final)} НЕ НАЙДЕН")
    log(f"TOTAL API CALLS THIS RESUME: {call_count} / cap {CALL_CAP}")
    log(f"TOTAL API CALLS COMBINED (first run {prev['call_count']} + this {call_count}): "
        f"{prev['call_count'] + call_count}")

    result = {
        "call_count_first_run": prev["call_count"],
        "call_count_resume": call_count,
        "call_count_total": prev["call_count"] + call_count,
        "input_rows": input_rows,
        "found": found,
        "unresolved_final": unresolved_final,
        "negative_branch_checked": negative_branch_checked,
        "control_found": prev["control_found"],
        "control_matched_count": prev["control_matched_count"],
    }
    with open(f"{SCRATCH}/result_final.json", "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    log(f"Result written to {SCRATCH}/result_final.json")


if __name__ == "__main__":
    main()
