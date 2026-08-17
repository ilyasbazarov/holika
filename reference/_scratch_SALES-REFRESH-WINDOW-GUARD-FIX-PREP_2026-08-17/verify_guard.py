"""
SALES-REFRESH-WINDOW-GUARD-FIX-PREP — контроль ф3-точной формы верхнего края
предохранителя `_assert_staging_covers_merge_window` (bq_ops.py:403).

Не бьёт в живой BigQuery (класс A, read-only не требовался для этого контроля —
логика предохранителя детерминирована по входным датам). Числа взяты дословно из
`reference/sales_refresh_window_stage3_2026-08-17.md §3` (упавший прогон
2026-08-16) и `step1_run.log` того же каталога (`run_id=1786842001.2609222`).

Контроль (i): позитивный — на числах упавшего прогона новая проверка ДОЛЖНА пропустить.
Контроль (ii): отрицательный — тот же прогон, но `_loaded_at` искусственно состарен
до момента ДО начала прогона — проверка ДОЛЖНА отказать.
"""
import sys
import os
from datetime import datetime, timezone, timedelta
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "code", "cf-facts"))

import bq_ops  # noqa: E402

# ── Реальные числа упавшего прогона 2026-08-16 (stage3 §3, step1_run.log) ──────
RUN_STARTED_AT = datetime.fromtimestamp(1786842001.2609222, tz=timezone.utc)
assert RUN_STARTED_AT.isoformat() == "2026-08-16T01:00:01.260922+00:00", RUN_STARTED_AT.isoformat()

MIN_DATE = datetime(2026, 5, 18).date()           # MIN(transaction_date_raw), stage3 §3
WINDOW_START = datetime(2026, 5, 18).date()        # CURRENT_DATE()-90 на 2026-08-16
LAST_LOADED_AT_REAL = datetime(2026, 8, 16, 1, 18, 21, tzinfo=timezone.utc)  # stage3 §3


class _FakeRow:
    def __init__(self, min_date, window_start, max_loaded_at):
        self.min_date = min_date
        self.window_start = window_start
        self.max_loaded_at = max_loaded_at


class _FakeResult:
    def __init__(self, row):
        self._row = row

    def result(self):
        return iter([self._row])


class _FakeBQ:
    def __init__(self, row):
        self._row = row

    def query(self, sql):
        return _FakeResult(self._row)


def run_guard(max_loaded_at, run_started_at):
    fake_bq = _FakeBQ(_FakeRow(MIN_DATE, WINDOW_START, max_loaded_at))
    bq_ops._assert_staging_covers_merge_window(
        fake_bq, "stg_msklad.fact_sales_perimeter_staging", 90,
        "promote_perimeter_to_core", run_started_at,
    )


print("=== Контроль (i): позитивный — реальные числа упавшего прогона 2026-08-16 ===")
print(f"run_started_at = {RUN_STARTED_AT.isoformat()}")
print(f"max(_loaded_at) = {LAST_LOADED_AT_REAL.isoformat()}")
try:
    run_guard(LAST_LOADED_AT_REAL, RUN_STARTED_AT)
    print("РЕЗУЛЬТАТ: пройдено (новая проверка НЕ отказала) — ОЖИДАЕМО\n")
except ValueError as e:
    print(f"РЕЗУЛЬТАТ: отказ — НЕОЖИДАННО\n{e}\n")
    sys.exit(1)

print("=== Контроль (ii): отрицательный — _loaded_at состарен до-начала-прогона ===")
stale_loaded_at = RUN_STARTED_AT - timedelta(hours=1)
print(f"run_started_at = {RUN_STARTED_AT.isoformat()}")
print(f"max(_loaded_at) [искусственно состарен] = {stale_loaded_at.isoformat()}")
try:
    run_guard(stale_loaded_at, RUN_STARTED_AT)
    print("РЕЗУЛЬТАТ: пройдено — НЕОЖИДАННО (должен был отказать)\n")
    sys.exit(1)
except ValueError as e:
    print(f"РЕЗУЛЬТАТ: отказ (ОЖИДАЕМО) — {e}\n")

print("Оба контроля прошли как ожидалось.")
