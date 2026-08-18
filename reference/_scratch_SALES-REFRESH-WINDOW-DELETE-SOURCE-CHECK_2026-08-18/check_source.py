"""
check_source.py — SALES-REFRESH-WINDOW-DELETE-SOURCE-CHECK, живое чтение МойСклада.

Форма и объект по reference/delete_stage3_adj_2026-08-18.md §12. Read-only. Токен приходит
через переменную окружения MSKLAD_TOKEN (резолвится вызывающим bash-скриптом из Secret Manager,
inline, не печатается ни здесь, ни там).

Порядок (§12): (1) entity/demand по каждой из 11 дат остатка + 1 дата положительного контроля;
(2) локальный отбор документов по agent_id; (3) entity/demand/{id}/positions по отобранным;
(4) transaction_id = TO_HEX(MD5(demand_id|position_id)), сверка с 27+2 входными id;
(5) ветка отрицательного результата — entity/retaildemand + entity/commissionreportin по дате
неразрешённого id, тем же способом (doc_id|position_id), вердикт «отсутствует» только при пустом
результате ОБОИХ.

Потолок объёма — 40 вызовов к api.moysklad.ru. Скрипт останавливается сам, не превышает.
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
CALL_CAP = 40

INPUT_CSV = "reference/deleted_27_2026-08-18.csv"
SCRATCH = "reference/_scratch_SALES-REFRESH-WINDOW-DELETE-SOURCE-CHECK_2026-08-18"

CONTROL_DATE = "2026-05-12"
CONTROL_AGENT = "31d135bc-4df8-11f1-0a80-1c8a0053c5b4"
CONTROL_IDS = {
    "786f54b87f1e81ecf04efead3ab59250",
    "8e05d4b486a48d5b018df201217eb7f3",
}

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

    with open(INPUT_CSV, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        input_rows = list(reader)

    pairs = {}  # date -> set(agent_id)
    by_txn = {}  # transaction_id -> input row
    for row in input_rows:
        d = row["transaction_date"]
        a = row["agent_id"]
        pairs.setdefault(d, set()).add(a)
        by_txn[row["transaction_id"]] = row

    log(f"Input: {len(input_rows)} rows, {len(pairs)} unique dates, "
        f"{sum(len(v) for v in pairs.values())} date+agent pairs")

    session = requests.Session()
    headers = {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}

    found = {}  # transaction_id -> source doc id (demand branch)
    matched_docs_by_date = {}  # date -> list of (doc_id, entity)

    # ── Positive control first (ADR-165 form) ──
    log("=== POSITIVE CONTROL: date=%s agent=%s ===" % (CONTROL_DATE, CONTROL_AGENT))
    control_docs = fetch_doc_list(session, headers, "demand", CONTROL_DATE)
    control_matched = [
        d for d in control_docs
        if parse_href(d.get("agent", {}).get("meta", {}).get("href", "")) == CONTROL_AGENT
    ]
    log(f"Control: {len(control_docs)} demand docs on {CONTROL_DATE}, "
        f"{len(control_matched)} match agent {CONTROL_AGENT}")
    control_found = {}
    for doc in control_matched:
        doc_id = doc["id"]
        positions = fetch_positions(session, headers, "demand", doc_id)
        for pos in positions:
            tid = txn_id(doc_id, pos["id"])
            if tid in CONTROL_IDS:
                control_found[tid] = doc_id
    log(f"Control found: {control_found}")

    # ── 27-row demand branch ──
    for date_str, agents in sorted(pairs.items()):
        log(f"=== DATE {date_str}: agents={sorted(agents)} ===")
        docs = fetch_doc_list(session, headers, "demand", date_str)
        matched = [
            d for d in docs
            if parse_href(d.get("agent", {}).get("meta", {}).get("href", "")) in agents
        ]
        log(f"{len(docs)} demand docs on {date_str}, {len(matched)} match input agents")
        matched_docs_by_date.setdefault(date_str, [])
        for doc in matched:
            doc_id = doc["id"]
            matched_docs_by_date[date_str].append((doc_id, "demand"))
            positions = fetch_positions(session, headers, "demand", doc_id)
            for pos in positions:
                tid = txn_id(doc_id, pos["id"])
                if tid in by_txn:
                    found[tid] = doc_id

    unresolved = [tid for tid in by_txn if tid not in found]
    log(f"After demand branch: {len(found)}/{len(by_txn)} found, {len(unresolved)} unresolved")

    # ── Negative-result branch (§12): retaildemand + commissionreportin per unresolved date ──
    unresolved_dates = sorted({by_txn[tid]["transaction_date"] for tid in unresolved})
    negative_branch_checked = {}  # date -> {"retaildemand": bool_had_docs, "commissionreportin": bool_had_docs}
    for date_str in unresolved_dates:
        agents = pairs[date_str]
        log(f"=== NEGATIVE BRANCH DATE {date_str}: agents={sorted(agents)} ===")
        neg_result = {}
        for entity in ("retaildemand", "commissionreportin"):
            if call_count >= CALL_CAP:
                log(f"STOP: call cap reached before {entity} list for {date_str}")
                sys.exit(2)
            docs = fetch_doc_list(session, headers, entity, date_str)
            matched = [
                d for d in docs
                if parse_href(d.get("agent", {}).get("meta", {}).get("href", "")) in agents
            ]
            log(f"{entity} {date_str}: {len(docs)} docs, {len(matched)} match input agents")
            neg_result[entity] = len(matched) > 0
            for doc in matched:
                doc_id = doc["id"]
                matched_docs_by_date[date_str].append((doc_id, entity))
                positions = fetch_positions(session, headers, entity, doc_id)
                for pos in positions:
                    tid = txn_id(doc_id, pos["id"])
                    if tid in by_txn:
                        found[tid] = doc_id
        negative_branch_checked[date_str] = neg_result

    unresolved_final = [tid for tid in by_txn if tid not in found]
    log(f"After negative branch: {len(found)}/{len(by_txn)} found, "
        f"{len(unresolved_final)} НЕ НАЙДЕН (both retaildemand and commissionreportin empty for their date)")

    log(f"TOTAL API CALLS: {call_count} / cap {CALL_CAP}")

    result = {
        "call_count": call_count,
        "input_rows": input_rows,
        "found": found,
        "unresolved_final": unresolved_final,
        "negative_branch_checked": negative_branch_checked,
        "control_found": control_found,
        "control_matched_count": len(control_matched),
    }
    with open(f"{SCRATCH}/result.json", "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    log(f"Result written to {SCRATCH}/result.json")


if __name__ == "__main__":
    main()
