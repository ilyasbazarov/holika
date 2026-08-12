#!/usr/bin/env python3
"""
SALES-REFRESH-WINDOW-SOURCE-PROBE — прямой запрос к api.moysklad.ru, форма ВПЕРЁД.

Мандат: reference/sales_refresh_window_rollback_probe_mandate_2026-08-12.md §3.
Только чтение. Ни одной записи в BigQuery. Секрет msklad-token читается один раз,
не печатается ни в лог, ни в артефакт.

Ловушка суток (ADR-088 §3): transaction_date продаж = DATE(moment + 6h, Asia/Bishkek).
Для бишкекской даты D истинное окно moment (UTC) есть [D-1 18:00:00Z ; D 18:00:00Z).

Q-93 (не закрыт репо): в какой зоне MoySklad интерпретирует momentFrom/momentTo фильтра —
не проверено. Обходится без гадания: фильтр запрашивается ЗАВЕДОМО ШИРЕ (±1 сутки с обеих
сторон истинного окна, в местных нотациях-кандидатах), а точная граница применяется ЛОКАЛЬНО
к полю moment каждого документа — а этот факт уже установлен (ADR-088 §1: MoySklad отдаёт
moment в UTC). Отсюда результат не зависит от того, как именно фильтр интерпретирует зону.

expand=positions на СПИСОЧНОМ entity/demand не используется: docstring fetch_demands.py
(«confirmed in bootstrap Аппендикс Е») фиксирует, что MoySklad не разворачивает MetaArray в
списочном режиме. Вместо этого — ровно тот механизм, что уже работает в проде: список
entity/demand по широкому окну (без фильтра agent — этот фильтр нигде в коде проекта не
использован и не проверен), локальная фильтрация по agent_id и точному окну, затем
entity/demand/{id}/positions отдельным вызовом на каждый совпавший документ.
"""

import hashlib
import json
import logging
import subprocess
import sys
import time
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import requests

MSKLAD_BASE = "https://api.moysklad.ru/api/remap/1.2"
GCP_PROJECT = "msklad-bi-prod"
SECRET_TOKEN = "msklad-token"
PAGE_LIMIT = 100  # 02_ERP_CONTRACTS §поведение API — limit <= 100
TIMEOUT = 90
SLEEP = 0.25

SCRATCH = Path(__file__).parent

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("probe")

# ─── 16 пар: 13 рабочих (…delete_adj…§4, …delete_discriminate…) + 3 контрольных (ADR-100 §1) ───

PAIRS = [
    ("G1", "2026-05-12", "31d135bc-4df8-11f1-0a80-1c8a0053c5b4", "рабочая"),
    ("G2", "2026-06-03", "b3667c34-3ca3-11f0-0a80-15ce0025d38d", "рабочая"),
    ("G3", "2026-06-04", "18a13a53-87c0-11ef-0a80-1568002f42aa", "рабочая"),
    ("G4", "2026-06-15", "b3667c34-3ca3-11f0-0a80-15ce0025d38d", "рабочая"),
    ("G5", "2026-07-02", "2db2c3dd-5f17-11f1-0a80-1d6500046ebf", "рабочая"),
    ("G6", "2026-07-11", "b3667c34-3ca3-11f0-0a80-15ce0025d38d", "рабочая"),
    ("G7", "2026-07-13", "4d4bb3c6-7396-11f1-0a80-1357002a9eb8", "рабочая"),
    ("G8", "2026-07-20", "a08652a8-5e52-11f1-0a80-0cb7000604b7", "рабочая"),
    ("G9", "2026-07-21", "356fb156-83ed-11f1-0a80-173600242e0d", "рабочая"),
    ("G10", "2026-07-27", "75d7c694-78f9-11f0-0a80-077d000b5e09", "рабочая"),
    ("G11", "2026-07-27", "f4201bf6-6390-11f0-0a80-0fa2000d75eb", "рабочая"),
    ("G12", "2026-07-29", "79dc242a-1baf-11f1-0a80-138a002eeb35", "рабочая"),
    ("G13", "2026-07-30", "b3667c34-3ca3-11f0-0a80-15ce0025d38d", "рабочая"),
    ("C1", "2026-05-07", "b2c49334-f066-11f0-0a80-0c49000a9f1e", "контрольная-сирота"),
    ("C2", "2026-05-09", "deb32c34-990c-11ef-0a80-19eb00083704", "контрольная-сирота"),
    ("C3", "2026-05-26", "b2c49334-f066-11f0-0a80-0c49000a9f1e", "контрольная-сирота"),
]

# 29 удалённых (…delete_adj…§4 / deleted_29.csv) + 7 сирот (…deploy_v2…§8) = 36 искомых.
TARGET_IDS = {
    "786f54b87f1e81ecf04efead3ab59250": "G1",
    "8e05d4b486a48d5b018df201217eb7f3": "G1",
    "143035c08bea9f9bf479465da01dd254": "G2",
    "2dd7b9fda0f4e372442019fde4bdb1f3": "G2",
    "df2d662ffe4189c916953d812391d381": "G3",
    "7339a844877d1d393033bc3e5ab545cf": "G4",
    "b4fb95a49cf529aec2f8c243001aaaa5": "G5",
    "117c9c069f920f1d87d550f755040ce2": "G6",
    "b52aba22dc70fed8a720cff790470ee9": "G7",
    "c5ba231dc86abad9b5aa75d77452c6ae": "G7",
    "844460b779964f97e1de571086dfeeef": "G7",
    "dd3e3bb9d3677ac6ee454a833bfd0284": "G7",
    "5981baeb9fa0cbcf2da68ff6f355762f": "G7",
    "41559c6b38b39dfcbffcfa726b131a8f": "G7",
    "95a69af832733a3601c244b913e3fb93": "G8",
    "b0878364dc7ef46e2e1d971aa18be751": "G9",
    "65d08e698b0541471dc772f3d6e91e33": "G9",
    "20d93da5fba41b9110bfecce95608aaf": "G9",
    "0b47b431aaef54236c0c24882a47e9e9": "G9",
    "c393fa3a9646c4cc699ac38c9fed8680": "G9",
    "a4e3b8435c8bada17b55c9cce8484ad6": "G9",
    "ab1ae815d0cf68034d9053606b5c3087": "G9",
    "b68dfe99b406e5709972520aa83b5899": "G9",
    "99e65fddd5719ed7d20095f820e33c0d": "G10",
    "86baf50a0682bc43d9536cf267010f58": "G11",
    "f79a38d440ea111ccb43e8047fb23a59": "G12",
    "48a33a41ddc9d429a533c0f1f0f21fb1": "G13",
    "4200c0b0d7184d80e1c98aba9d16660b": "G13",
    "961a459badd6e45493e4db351ca30d90": "G13",
    "d564a1906e5fd33ca375200be5da039b": "C1",
    "606576a8890ee120b127c09a25cafdfd": "C1",
    "40a28a8926d5110f8beb82e0a9952bca": "C2",
    "d257b8f9cca0c9e251ccfd052bfcc57b": "C2",
    "8ece1fa6771e0271522dce7b263f9283": "C3",
    "4c22df388e46d8141ba12fd1572f011c": "C3",
    "a28436b786066e7a886db6b86d59eae8": "C3",
}
ORPHAN_IDS = {k for k, v in TARGET_IDS.items() if v.startswith("C")}
DELETED_29_IDS = {k for k, v in TARGET_IDS.items() if not v.startswith("C")}
assert len(DELETED_29_IDS) == 29, len(DELETED_29_IDS)
assert len(ORPHAN_IDS) == 7, len(ORPHAN_IDS)

# Отрицательный контроль — заведомо живые позиции, взятые ЛОКАЛЬНО из archive_106b.ndjson
# (снимок источника на момент боевого прогона, 2026-08-12T05:02:06Z), НЕ из искомого множества.
# Обязаны найтись живыми в источнике СЕЙЧАС же, независимым запросом.
NEGATIVE_CONTROL_IDS = {
    "843325ca2e52cffddf00a786fb00ce3b": "G2",
    "c115921db66e589a92039354ca491dce": "G2",
    "5efec8d8054d05c801acf66414f18596": "G3",
    "f43a122ab13468f6deddfa8df4846409": "G3",
    "188b8d914e78cbbdfaeac34d2ff43684": "G4",
    "69ef08435e31a5452d3ffa6435752582": "G4",
    "230fde746b89630f976efdcb866ab86c": "G5",
    "da718c701385314275d097ed657e765c": "G5",
    "0a1041061f4a4c1974eefd4dab6a7c0b": "G6",
    "56c7d27f3f312ec4b750ae762256c6be": "G7",
    "843a773615d45b5a281f1218aa41952a": "G7",
    "edb3f4a7e8c47117139a0c71bd192fd4": "G8",
    "08819b78f1a5fa679af1ef3523c8deab": "G8",
    "d92f150e6837443cc3c6bcb662baf154": "G10",
    "1cd0fb44de17a4370b9b14e6b18c96a7": "G10",
    "d8ec7deabcbe6c2b7983373bbdd1f744": "G11",
    "70946ab1c1ef42b2b58bc158861915eb": "G11",
    "4dcb30d16132609ba0136a41b39e4b0a": "G12",
    "1f19951488bc6cc0eaa1f3825438cf18": "G12",
    "cd30134861ff166a92c9f556950ee8f5": "G13",
    "5d0c34c473dc24313f81d5842f9bdb8c": "G13",
    "d3d252f0b7fc45eb9de8967b2144e72f": "C1",
    "87d529f8479825c72e620ee0ec1127c3": "C1",
    "a49005c6e0b06b4e6d2f7ee3b770e700": "C2",
    "2ee40d52c1dcae3294329de545dbc2bb": "C2",
}
assert len(NEGATIVE_CONTROL_IDS) >= 10, len(NEGATIVE_CONTROL_IDS)


def run(cmd):
    log.info("$ %s", " ".join(cmd))
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    sys.stdout.write(out.stdout)
    sys.stderr.write(out.stderr)
    return out


def get_token() -> str:
    out = subprocess.run(
        [
            "gcloud", "secrets", "versions", "access", "latest",
            f"--secret={SECRET_TOKEN}", f"--project={GCP_PROJECT}",
        ],
        capture_output=True, text=True, timeout=60,
    )
    if out.returncode != 0:
        log.error("gcloud secrets access failed rc=%s stderr=%s", out.returncode, out.stderr)
        raise SystemExit(2)
    return out.stdout.strip()


def build_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}


def api_get(session, url, headers, params=None, attempt=1):
    time.sleep(SLEEP)
    resp = session.get(url, headers=headers, params=params, timeout=TIMEOUT)
    if resp.status_code == 429:
        if attempt > 5:
            log.error("429 persisted after 5 attempts on %s", url)
            raise SystemExit(3)
        wait = min(60, 2 ** attempt)
        log.warning("429 on %s — backing off %ss (attempt %d)", url, wait, attempt)
        time.sleep(wait)
        return api_get(session, url, headers, params, attempt + 1)
    if resp.status_code >= 500:
        if attempt > 5:
            log.error("5xx persisted after 5 attempts on %s", url)
            raise SystemExit(3)
        wait = min(60, 2 ** attempt)
        log.warning("%s on %s — backing off %ss (attempt %d)", resp.status_code, url, wait, attempt)
        time.sleep(wait)
        return api_get(session, url, headers, params, attempt + 1)
    resp.raise_for_status()
    return resp.json()


def parse_href(href: str):
    if not href:
        return None
    return href.rstrip("/").rsplit("/", 1)[-1] or None


def fmt_naive(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def true_window_utc(d: date):
    """ADR-088 §3: истинное окно бишкекских суток D в UTC-времени moment."""
    start = datetime(d.year, d.month, d.day, tzinfo=timezone.utc) - timedelta(hours=6)
    end = start + timedelta(hours=24)
    return start, end


def wide_query_window(d: date):
    """Q-93 не закрыт: зона фильтра не проверена. Запрашиваем ЗАВЕДОМО шире (±1 сутки от
    истинного окна) и фильтруем точно локально по known-UTC полю moment."""
    return fmt_naive(datetime(d.year, d.month, d.day) - timedelta(days=2)), \
        fmt_naive(datetime(d.year, d.month, d.day) + timedelta(days=2))


def fetch_demand_headers(session, headers, moment_from, moment_to, tag):
    rows = []
    offset = 0
    page = 0
    while True:
        params = {
            "filter": f"moment>={moment_from};moment<{moment_to}",
            "order": "moment,asc",
            "limit": PAGE_LIMIT,
            "offset": offset,
        }
        data = api_get(session, f"{MSKLAD_BASE}/entity/demand", headers, params)
        batch = data.get("rows", [])
        rows.extend(batch)
        page += 1
        log.info("[%s] entity/demand headers page=%d offset=%d got=%d total_so_far=%d",
                  tag, page, offset, len(batch), len(rows))
        if len(batch) < PAGE_LIMIT:
            break
        offset += PAGE_LIMIT
    return rows


def fetch_positions(session, headers, demand_id, tag):
    rows = []
    offset = 0
    page = 0
    while True:
        params = {"limit": PAGE_LIMIT, "offset": offset}
        data = api_get(
            session, f"{MSKLAD_BASE}/entity/demand/{demand_id}/positions", headers, params
        )
        batch = data.get("rows", [])
        rows.extend(batch)
        page += 1
        log.info("[%s] demand=%s positions page=%d offset=%d got=%d total_so_far=%d",
                  tag, demand_id, page, offset, len(batch), len(rows))
        if len(batch) < PAGE_LIMIT:
            break
        offset += PAGE_LIMIT
    return rows


def main():
    run(["date", "-u"])
    run(["gcloud", "auth", "list"])

    token = get_token()
    session = requests.Session()
    headers = build_headers(token)

    found_ids = {}  # transaction_id -> (pair_tag, demand_id, position_id)
    all_matched_demands = {}  # pair_tag -> [demand summaries]

    for tag, date_str, agent_id, kind in PAIRS:
        d = date.fromisoformat(date_str)
        true_start, true_end = true_window_utc(d)
        wide_from, wide_to = wide_query_window(d)

        log.info("=== pair %s (%s) date=%s agent=%s true_window=[%s;%s) ===",
                  tag, kind, date_str, agent_id, true_start.isoformat(), true_end.isoformat())

        headers_rows = fetch_demand_headers(session, headers, wide_from, wide_to, tag)

        raw_path = SCRATCH / f"raw_{tag}_demand_headers.ndjson"
        with raw_path.open("w") as f:
            for r in headers_rows:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")

        matched = []
        for dm in headers_rows:
            agent_href = dm.get("agent", {}).get("meta", {}).get("href", "")
            dm_agent_id = parse_href(agent_href)
            moment_str = dm.get("moment", "")
            try:
                moment_dt = datetime.strptime(moment_str, "%Y-%m-%d %H:%M:%S.%f").replace(
                    tzinfo=timezone.utc
                )
            except ValueError:
                log.warning("[%s] unparsable moment %r on demand %s — skipping", tag, moment_str, dm.get("id"))
                continue
            if dm_agent_id == agent_id and true_start <= moment_dt < true_end:
                matched.append(dm)

        log.info("[%s] headers_fetched=%d matched_demands=%d", tag, len(headers_rows), len(matched))
        all_matched_demands[tag] = [
            {"id": m.get("id"), "moment": m.get("moment"), "name": m.get("name")} for m in matched
        ]

        for dm in matched:
            demand_id = dm.get("id")
            positions = fetch_positions(session, headers, demand_id, tag)
            pos_path = SCRATCH / f"raw_{tag}_positions_{demand_id}.ndjson"
            with pos_path.open("w") as f:
                for p in positions:
                    f.write(json.dumps(p, ensure_ascii=False) + "\n")
            for p in positions:
                position_id = p.get("id")
                if not position_id:
                    continue
                tid = hashlib.md5(f"{demand_id}|{position_id}".encode()).hexdigest()
                found_ids[tid] = (tag, demand_id, position_id)

    # ─── Вердикт ───

    print("\n" + "=" * 70)
    print("КОНТРОЛЬ 1 (положительный) — 7 сирот ADR-100 §1, обязаны быть НЕ НАЙДЕНЫ")
    print("=" * 70)
    pos_control_ok = True
    for tid in sorted(ORPHAN_IDS):
        status = "НАЙДЕН (МЕТОД НЕВЕРЕН)" if tid in found_ids else "не найден"
        if tid in found_ids:
            pos_control_ok = False
        print(f"  {tid} [{TARGET_IDS[tid]}] -> {status}")
    print(f"ВЕРДИКТ КОНТРОЛЯ 1: {'PASS' if pos_control_ok else 'FAIL'}")

    print("\n" + "=" * 70)
    print("КОНТРОЛЬ 2 (отрицательный) — заведомо живые позиции, обязаны НАЙТИСЬ (>=10)")
    print("=" * 70)
    neg_found = 0
    for tid in sorted(NEGATIVE_CONTROL_IDS):
        status = "найден" if tid in found_ids else "НЕ НАЙДЕН"
        if tid in found_ids:
            neg_found += 1
        print(f"  {tid} [{NEGATIVE_CONTROL_IDS[tid]}] -> {status}")
    neg_control_ok = neg_found >= 10
    print(f"Найдено живых: {neg_found}/{len(NEGATIVE_CONTROL_IDS)} (нужно >=10)")
    print(f"ВЕРДИКТ КОНТРОЛЯ 2: {'PASS' if neg_control_ok else 'FAIL'}")

    trust_verdict = pos_control_ok and neg_control_ok
    print("\n" + "=" * 70)
    print(f"ДОВЕРИЕ К МЕТОДУ: {'ПОДТВЕРЖДЕНО' if trust_verdict else 'НЕ ПОДТВЕРЖДЕНО'}")
    print("=" * 70)

    print("\n" + "=" * 70)
    print("ВЕРДИКТ ПО 29 УДАЛЁННЫМ ПОЗИЦИЯМ" + ("" if trust_verdict else " — НЕ ВЫНОСИТСЯ, метод не прошёл контроль"))
    print("=" * 70)
    defect_ids = []
    legit_ids = []
    if trust_verdict:
        for tid in sorted(DELETED_29_IDS):
            if tid in found_ids:
                tag2, demand_id, position_id = found_ids[tid]
                print(f"  {tid} [{TARGET_IDS[tid]}] -> ЖИВА в источнике (demand={demand_id}, position={position_id}) => ДЕФЕКТ (b1)")
                defect_ids.append(tid)
            else:
                print(f"  {tid} [{TARGET_IDS[tid]}] -> не найдена ни в одном документе пары => УДАЛЕНИЕ ЗАКОННО (b2)")
                legit_ids.append(tid)
        print(f"\nИтог: дефект (b1) = {len(defect_ids)} строк; законно (b2) = {len(legit_ids)} строк.")

    result = {
        "trust_verdict": trust_verdict,
        "positive_control_ok": pos_control_ok,
        "negative_control_found": neg_found,
        "negative_control_total": len(NEGATIVE_CONTROL_IDS),
        "defect_ids": defect_ids,
        "legit_ids": legit_ids,
        "matched_demands_by_pair": all_matched_demands,
        "found_ids_full": {k: list(v) for k, v in found_ids.items()},
    }
    with (SCRATCH / "verdict.json").open("w") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    log.info("verdict written to %s", SCRATCH / "verdict.json")

    run(["date", "-u"])
    run(["gcloud", "auth", "list"])


if __name__ == "__main__":
    main()
