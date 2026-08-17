"""
SALES-REFRESH-WINDOW-GUARD-FIX-PREP2 — контроль обвязки run_id → run_started_at
через ПОЛНУЮ цепочку main() → _run_promote/_run_perimeter_promote →
promote_to_core/promote_perimeter_to_core → _assert_staging_covers_merge_window.

Не бьёт в живой BigQuery, Flask, requests — эти модули стабятся фейками в
sys.modules ДО импорта main.py (не установлены в окружении сессии; класс A,
облачных вызовов не требуется). Числа реального инцидента 2026-08-16 — из
reference/sales_refresh_window_stage3_2026-08-17.md §3 и
reference/_scratch_SALES-REFRESH-WINDOW-GUARD-FIX-PREP_2026-08-17/verify_guard.py
(та же сессия, тот же провенанс).

Три контроля из приёмки (guard_fixes_review_2026-08-17.md §7 п.5):
  (i)   позитивный  — run_id=1786842001.2609222 (float), _loaded_at=2026-08-16 01:18:21 → проходит
  (ii)  отрицательный — тот же run_id, _loaded_at состарен на 1 час → отказывает
  (iii) разбор форм run_id — "20260816T011821" разбирается и проходит теми же числами;
        "abc" даёт названный отказ ДО запроса к BQ (fail-closed).
Все три идут через main(fake_request), не через promote_to_core напрямую.
"""
import sys
import os
import json
import types
from datetime import datetime, timezone, timedelta

UTC_START = datetime.now(timezone.utc).isoformat()
print(f"date -u (старт скрипта): {UTC_START}")

CF_FACTS_DIR = os.path.join(os.path.dirname(__file__), "..", "code", "cf-facts")
sys.path.insert(0, CF_FACTS_DIR)

# ── Реальные числа инцидента 2026-08-16 (stage3 §3, step1_run.log) ─────────────
RUN_ID_FLOAT = 1786842001.2609222
RUN_STARTED_AT_EXPECTED = datetime.fromtimestamp(RUN_ID_FLOAT, tz=timezone.utc)
assert RUN_STARTED_AT_EXPECTED.isoformat() == "2026-08-16T01:00:01.260922+00:00", \
    RUN_STARTED_AT_EXPECTED.isoformat()

MIN_DATE = datetime(2026, 5, 18).date()
WINDOW_START = datetime(2026, 5, 18).date()
LAST_LOADED_AT_REAL = datetime(2026, 8, 16, 1, 18, 21, tzinfo=timezone.utc)  # stage3 §3
WINDOW_DAYS = 90


# ── Фейковые google-cloud-bigquery / storage / flask / requests ────────────────
# Только то, что main.py импортирует на уровне модуля и реально исполняет по
# пути promote/perimeter_promote — не полная эмуляция SDK.

class _FakeRow:
    def __init__(self, **kw):
        self.__dict__.update(kw)


class _FakeResult:
    def __init__(self, row):
        self._row = row

    def result(self):
        return iter([self._row])


class _FakeJob:
    num_dml_affected_rows = 0

    def result(self):
        return self


class _FakeBQClient:
    """Диспетчер по содержимому SQL — тот же приём, что verify_guard.py 2026-08-17."""

    def __init__(self, project=None, max_loaded_at=LAST_LOADED_AT_REAL):
        self.project = project
        self.max_loaded_at = max_loaded_at

    def query(self, sql):
        s = sql.upper()
        if "SELECT COUNT(*)" in s:
            return _FakeResult(_FakeRow(cnt=1))
        if "MAX(_LOADED_AT)" in s:
            return _FakeResult(_FakeRow(
                min_date=MIN_DATE, window_start=WINDOW_START,
                max_loaded_at=self.max_loaded_at,
            ))
        if "AGENT_COVERAGE" in s:
            return _FakeResult(_FakeRow(
                agent_coverage=1.0, cogs_coverage=1.0, usd_coverage=1.0,
                total_rows=1, total_revenue_kgs=1.0,
            ))
        if "MERGE" in s:
            return _FakeJob()
        raise AssertionError(f"неожиданный SQL в фейковом BQ-клиенте:\n{sql}")


bigquery_mod = types.ModuleType("google.cloud.bigquery")
bigquery_mod.Client = _FakeBQClient
bigquery_mod.SchemaField = lambda *a, **kw: None  # bq_ops.py объявляет схемы на уровне модуля

storage_mod = types.ModuleType("google.cloud.storage")
storage_mod.Client = lambda *a, **kw: None

secretmanager_mod = types.ModuleType("google.cloud.secretmanager")
secretmanager_mod.SecretManagerServiceClient = lambda *a, **kw: None

google_mod = types.ModuleType("google")
google_cloud_mod = types.ModuleType("google.cloud")
google_cloud_mod.bigquery = bigquery_mod
google_cloud_mod.storage = storage_mod
google_cloud_mod.secretmanager = secretmanager_mod
google_mod.cloud = google_cloud_mod

flask_mod = types.ModuleType("flask")


class _FakeRequest:
    pass


flask_mod.Request = _FakeRequest
flask_mod.Response = object
flask_mod.make_response = lambda body, code: (body, code)
flask_mod.jsonify = lambda d: d

requests_mod = types.ModuleType("requests")


class _FakeSession:
    pass


requests_mod.Session = _FakeSession

# helpers.py декорирует функции пагинации `@retry(...)` — не исполняется по пути
# promote/perimeter_promote, но импортируется модулем; нужен no-op-декоратор.
tenacity_mod = types.ModuleType("tenacity")
tenacity_mod.retry = lambda *a, **kw: (lambda fn: fn)
tenacity_mod.stop_after_attempt = lambda *a, **kw: None
tenacity_mod.wait_exponential = lambda *a, **kw: None
tenacity_mod.retry_if_exception_type = lambda *a, **kw: None
tenacity_mod.before_sleep_log = lambda *a, **kw: None

sys.modules["google"] = google_mod
sys.modules["google.cloud"] = google_cloud_mod
sys.modules["google.cloud.bigquery"] = bigquery_mod
sys.modules["google.cloud.storage"] = storage_mod
sys.modules["google.cloud.secretmanager"] = secretmanager_mod
sys.modules["flask"] = flask_mod
sys.modules["requests"] = requests_mod
sys.modules["tenacity"] = tenacity_mod

import main  # noqa: E402  (после подмены sys.modules)

# Подменяем bigquery.Client() внутри main/bq_ops на фейк с нужным max_loaded_at
_current_max_loaded_at = {"value": LAST_LOADED_AT_REAL}


class _FakeBQClientBound(_FakeBQClient):
    def __init__(self, project=None):
        super().__init__(project=project, max_loaded_at=_current_max_loaded_at["value"])


main.bigquery.Client = _FakeBQClientBound


class _FakeFlaskRequest:
    def __init__(self, body):
        self._body = body

    def get_json(self, force=True, silent=True):
        return self._body


def call_main(mode, run_id, window_days=WINDOW_DAYS):
    body = {"mode": mode, "window_days": window_days}
    if run_id is not None:
        body["run_id"] = run_id
    resp_body, status = main.main(_FakeFlaskRequest(body))
    return status, resp_body


failures = []


def check(label, cond):
    mark = "ok" if cond else "FAIL"
    print(f"  {mark}  {label}")
    if not cond:
        failures.append(label)


print("\n=== Контроль (i): позитивный — run_id float, staging свежее старта прогона ===")
_current_max_loaded_at["value"] = LAST_LOADED_AT_REAL
status, body = call_main("promote", RUN_ID_FLOAT)
print(f"  run_id={RUN_ID_FLOAT!r} → status={status} body={body}")
check("HTTP 200 (MERGE исполнен через main())", status == 200)
check("status=ok", body.get("status") == "ok")

print("\n=== Контроль (i-perimeter): тот же позитивный, mode=perimeter_promote ===")
status, body = call_main("perimeter_promote", RUN_ID_FLOAT)
print(f"  run_id={RUN_ID_FLOAT!r} → status={status} body={body}")
check("HTTP 200 (perimeter MERGE исполнен через main())", status == 200)

print("\n=== Контроль (ii): отрицательный — _loaded_at состарен на 1ч до старта прогона ===")
_current_max_loaded_at["value"] = RUN_STARTED_AT_EXPECTED - timedelta(hours=1)
status, body = call_main("promote", RUN_ID_FLOAT)
print(f"  run_id={RUN_ID_FLOAT!r}, _loaded_at состарен → status={status} error={body.get('error')}")
check("HTTP 500 (MERGE отказал)", status == 500)
check("причина — предохранитель свежести ADR-145 §4", "свежесть" in (body.get("error") or ""))

print("\n=== Контроль (iii): разбор форм run_id ===")
_current_max_loaded_at["value"] = LAST_LOADED_AT_REAL

status, body = call_main("promote", "20260816T011821")
print(f'  run_id="20260816T011821" (строка run_ts()) → status={status} body={body}')
check("строка %Y%m%dT%H%M%S разбирается, HTTP 200", status == 200)

status, body = call_main("promote", "abc")
print(f'  run_id="abc" (неразбираемое) → status={status} error={body.get("error")}')
check("HTTP 500 на неразбираемом run_id", status == 500)
check("названная ошибка — 'Неразбираемый run_id'", "Неразбираемый run_id" in (body.get("error") or ""))

print()
if failures:
    print(f"ИТОГ: {len(failures)} провал(ов): {failures}")
    sys.exit(1)
print("ИТОГ: все контроли прошли как ожидалось.")

UTC_END = datetime.now(timezone.utc).isoformat()
print(f"date -u (конец скрипта): {UTC_END}")
