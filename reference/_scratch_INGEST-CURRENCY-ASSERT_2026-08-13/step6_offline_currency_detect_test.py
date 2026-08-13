"""
Step 6 — offline-тест детекции «валюта=KGS либо применён rate.value» (ADR-101 §5),
БЕЗ секрета msklad-token и БЕЗ живого GET/bq query. Импортирует правленые модули
напрямую и подменяет сетевые функции (`paginate_entity`/`requests.get`) фиктивными
данными — тестирует ТОЛЬКО логику детекции и то, что арифметика revenue_kgs/sum_kgs/
price_kgs не изменилась, не факт доступности живого API.

Три синтетические позиции на каждую правленую точку:
  1. KGS без rate.value                -> ok (currency_mismatch не растёт)
  2. не-KGS с rate.value                -> ok (currency_mismatch не растёт)
  3. не-KGS без rate.value              -> детектор срабатывает (currency_mismatch == 1)
"""
import sys
import types

# ── Стабы облачных SDK, не установленных в этом окружении (google-cloud-*/tenacity/
#    bigquery) — нужны ТОЛЬКО чтобы модули импортировались; ни одна из их функций
#    этим тестом не вызывается (нет живого GET/bq query, есть fake bigquery.Client).


def _stub_submodule(dotted_name, **attrs):
    mod = types.ModuleType(dotted_name)
    for k, v in attrs.items():
        setattr(mod, k, v)
    sys.modules[dotted_name] = mod
    parent_name, _, leaf = dotted_name.rpartition(".")
    if parent_name in sys.modules:
        setattr(sys.modules[parent_name], leaf, mod)
    return mod


_stub_submodule("google")
_stub_submodule("google.cloud")


class _DummyClient:
    def __init__(self, *a, **k):
        pass


_stub_submodule("google.cloud.secretmanager", SecretManagerServiceClient=_DummyClient)
_stub_submodule("google.cloud.storage", Client=_DummyClient)
_stub_submodule(
    "google.cloud.bigquery_datatransfer",
    DataTransferServiceClient=_DummyClient,
    StartManualTransferRunsRequest=_DummyClient,
)


class _DummySourceFormat:
    NEWLINE_DELIMITED_JSON = "NEWLINE_DELIMITED_JSON"


_stub_submodule(
    "google.cloud.bigquery",
    Client=_DummyClient,
    SchemaField=lambda *a, **k: None,
    LoadJobConfig=lambda *a, **k: None,
    SourceFormat=_DummySourceFormat,
)


class _DummyTimestamp:
    def FromDatetime(self, *a, **k):
        pass


_stub_submodule("google.protobuf")
_stub_submodule("google.protobuf.timestamp_pb2", Timestamp=_DummyTimestamp)


def _tenacity_retry(*a, **k):
    def deco(fn):
        return fn
    return deco


_stub_submodule(
    "tenacity",
    retry=_tenacity_retry,
    retry_if_exception_type=lambda *a, **k: None,
    stop_after_attempt=lambda *a, **k: None,
    wait_exponential=lambda *a, **k: None,
    before_sleep_log=lambda *a, **k: None,
)

sys.path.insert(0, "reference/code/cf-facts")

FAKE_CURRENCY_ROWS = [
    {"meta": {"href": ".../entity/currency/kgs-uuid"}, "isoCode": "KGS"},
    {"meta": {"href": ".../entity/currency/usd-uuid"}, "isoCode": "USD"},
]

results = {}


def _fake_paginate_entity(token, path, params=None, session=None):
    if path == "entity/currency":
        return FAKE_CURRENCY_ROWS
    if path == "entity/saleschannel":
        return []
    if path == "entity/project":
        return []
    raise AssertionError(f"unexpected paginate_entity path in offline test: {path}")


# ═══════════════════════════════════════════════════════════════════════════
# 1. fetch_demands.py — position-level detection, currency_rate = demand.rate
# ═══════════════════════════════════════════════════════════════════════════
import fetch_demands  # noqa: E402
fetch_demands.paginate_entity = _fake_paginate_entity


def _fake_positions_demand(token, path, session=None):
    # entity/demand/{id}/positions — по одной позиции на демонстрационный документ
    return [{"id": "pos-1", "assortment": {"meta": {"href": ".../product/p1", "type": "product"}},
             "price": 10000, "quantity": 2.0, "discount": 0.0}]


class _FakeSession:
    pass


def _run_demands_case(rate_obj, expect_mismatch):
    fetch_demands.paginate_entity = _fake_paginate_entity
    demand = {"id": "demand-1", "agent": {}, "owner": {}, "moment": "2026-05-10 12:00:00.000",
              "rate": rate_obj}
    orig_paginate = fetch_demands.paginate_entity

    def paginate_dispatch(token, path, params=None, session=None):
        if path == "entity/demand":
            return [demand]
        if path.startswith("entity/demand/"):
            return _fake_positions_demand(token, path, session)
        return orig_paginate(token, path, params=params, session=session)

    fetch_demands.paginate_entity = paginate_dispatch
    from datetime import date
    records = fetch_demands.fetch_demand_positions(
        token="unused", date_from=date(2026, 5, 1), date_to=date(2026, 5, 31),
        run_id="test", session=_FakeSession()
    )
    assert len(records) == 1, f"expected 1 record, got {len(records)}"
    # revenue_kgs must equal price/100 * qty * rate, unaffected by detection
    expected_rate = rate_obj.get("value") or 1.0
    expected_revenue = round((10000 / 100.0) * expected_rate * 2.0, 4)
    assert records[0]["revenue_kgs"] == expected_revenue, records[0]
    return records[0]


# case 1: KGS, no rate.value -> ok
_run_demands_case({"currency": {"meta": {"href": ".../currency/kgs-uuid"}}}, expect_mismatch=False)
results["demands_kgs_no_rate"] = "OK (no mismatch expected, arithmetic verified)"

# case 2: USD with rate.value -> ok
_run_demands_case({"value": 88.0, "currency": {"meta": {"href": ".../currency/usd-uuid"}}}, expect_mismatch=False)
results["demands_usd_with_rate"] = "OK (no mismatch expected, arithmetic verified)"

# case 3: USD without rate.value -> mismatch=1 (captured via caplog-style warning count)
import logging  # noqa: E402


class _CountHandler(logging.Handler):
    def __init__(self):
        super().__init__()
        self.count = 0

    def emit(self, record):
        if "класс ошибки ADR-101" in record.getMessage():
            self.count += 1


handler = _CountHandler()
fetch_demands.log.addHandler(handler)
fetch_demands.log.setLevel(logging.WARNING)
_run_demands_case({"currency": {"meta": {"href": ".../currency/usd-uuid"}}}, expect_mismatch=True)
fetch_demands.log.removeHandler(handler)
assert handler.count == 1, f"expected 1 mismatch warning, got {handler.count}"
results["demands_usd_no_rate_detected"] = f"OK mismatch_count={handler.count}"


# ═══════════════════════════════════════════════════════════════════════════
# 2. fetch_returns.py — document-level detection
# ═══════════════════════════════════════════════════════════════════════════
import fetch_returns  # noqa: E402


def _run_returns_case(rate_obj):
    def paginate_dispatch(token, path, params=None, session=None):
        if path == "entity/currency":
            return FAKE_CURRENCY_ROWS
        if path in ("entity/salesreturn", "entity/retailsalesreturn"):
            return [{"id": "ret-1", "moment": "2026-05-10 12:00:00.000", "agent": {}, "rate": rate_obj}]
        if path.startswith("entity/salesreturn/") or path.startswith("entity/retailsalesreturn/"):
            return [{"id": "pos-1", "price": 5000, "quantity": 1.0, "discount": 0.0,
                     "assortment": {"meta": {"href": ".../product/p1"}}}]
        raise AssertionError(f"unexpected path {path}")

    fetch_returns.paginate_entity = paginate_dispatch
    import time as _t
    orig_sleep = _t.sleep
    fetch_returns.time.sleep = lambda *_a, **_k: None
    try:
        from datetime import date
        records = fetch_returns.fetch_return_positions(
            token="unused", date_from=date(2026, 5, 1), date_to=date(2026, 5, 31), session=_FakeSession()
        )
    finally:
        fetch_returns.time.sleep = orig_sleep
    # два entity_type (salesreturn, retailsalesreturn), по 1 позиции каждый
    assert len(records) == 2, f"expected 2 records, got {len(records)}"
    expected_rate = rate_obj.get("value") or 1.0
    expected_sum = round(5000 / 100.0 * 1.0 * 1.0 * expected_rate, 4)
    for r in records:
        assert r["sum_kgs"] == expected_sum, r
    return records


handler2 = _CountHandler()
fetch_returns.log.addHandler(handler2)
fetch_returns.log.setLevel(logging.WARNING)

_run_returns_case({"currency": {"meta": {"href": ".../currency/kgs-uuid"}}})
results["returns_kgs_no_rate"] = "OK (arithmetic verified)"
_run_returns_case({"value": 88.0, "currency": {"meta": {"href": ".../currency/usd-uuid"}}})
results["returns_usd_with_rate"] = "OK (arithmetic verified)"

handler2.count = 0
_run_returns_case({"currency": {"meta": {"href": ".../currency/usd-uuid"}}})
# document-level: 1 warning per entity_type (2 documents total, both non-KGS w/o rate)
assert handler2.count == 2, f"expected 2 mismatch warnings (one per entity_type doc), got {handler2.count}"
fetch_returns.log.removeHandler(handler2)
results["returns_usd_no_rate_detected"] = f"OK mismatch_count={handler2.count}"


# ═══════════════════════════════════════════════════════════════════════════
# 3. fetch_purchases.py — order-level detection
# ═══════════════════════════════════════════════════════════════════════════
import fetch_purchases  # noqa: E402


def _run_purchases_case(rate_obj):
    def paginate_dispatch(token, path, params=None, session=None):
        if path == "entity/currency":
            return FAKE_CURRENCY_ROWS
        if path == "entity/purchaseorder":
            return [{"id": "po-1", "name": "PO-1", "moment": "2026-05-10 12:00:00.000",
                     "agent": {}, "rate": rate_obj, "sum": 100000,
                     "state": {"meta": {"href": ".../state/x"}}}]
        if path.startswith("entity/purchaseorder/"):
            return [{"id": "pos-1", "assortment": {"meta": {"href": ".../product/p1"}},
                     "quantity": 3.0, "shipped": 0.0, "inTransit": 3.0, "price": 20000, "discount": 0.0}]
        raise AssertionError(f"unexpected path {path}")

    fetch_purchases.paginate_entity = paginate_dispatch
    records = fetch_purchases.fetch_purchase_positions(
        token="unused", date_from=None, date_to=None, session=_FakeSession()
    )
    assert len(records) == 1, f"expected 1 record, got {len(records)}"
    expected_rate = rate_obj.get("value") or 1.0
    expected_price_kgs = 20000 / 100.0 * expected_rate
    expected_sum_kgs = round(expected_price_kgs * 3.0 * 1.0, 4)
    assert records[0]["sum_kgs"] == expected_sum_kgs, records[0]
    return records


handler3 = _CountHandler()
fetch_purchases.log.addHandler(handler3)
fetch_purchases.log.setLevel(logging.WARNING)

_run_purchases_case({"currency": {"meta": {"href": ".../currency/kgs-uuid"}}})
results["purchases_kgs_no_rate"] = "OK (arithmetic verified)"
_run_purchases_case({"value": 88.0, "currency": {"meta": {"href": ".../currency/usd-uuid"}}})
results["purchases_usd_with_rate"] = "OK (arithmetic verified)"

handler3.count = 0
_run_purchases_case({"currency": {"meta": {"href": ".../currency/usd-uuid"}}})
assert handler3.count == 1, f"expected 1 mismatch warning, got {handler3.count}"
fetch_purchases.log.removeHandler(handler3)
results["purchases_usd_no_rate_detected"] = f"OK mismatch_count={handler3.count}"


# ═══════════════════════════════════════════════════════════════════════════
# 4. fetch_perimeter.py — position-level detection, shared _fetch_positions_for
# ═══════════════════════════════════════════════════════════════════════════
import fetch_perimeter  # noqa: E402


def _run_perimeter_case(rate_obj):
    fetch_perimeter._CURRENCY_MAP_CACHE.clear()

    def paginate_dispatch(token, path, params=None, session=None):
        if path == "entity/currency":
            return FAKE_CURRENCY_ROWS
        if path == "entity/retaildemand":
            return [{"id": "rd-1", "moment": "2026-05-10 12:00:00.000", "agent": {}, "rate": rate_obj}]
        if path.startswith("entity/retaildemand/"):
            return [{"id": "pos-1", "assortment": {"meta": {"href": ".../product/p1"}},
                     "price": 15000, "quantity": 1.0, "discount": 0.0}]
        raise AssertionError(f"unexpected path {path}")

    fetch_perimeter.paginate_entity = paginate_dispatch
    from datetime import date
    records = fetch_perimeter.fetch_retaildemand_positions(
        token="unused", date_from=date(2026, 5, 1), date_to=date(2026, 5, 31),
        run_id="test", session=_FakeSession()
    )
    assert len(records) == 1, f"expected 1 record, got {len(records)}"
    expected_rate = rate_obj.get("value") or 1.0
    expected_revenue = round((15000 / 100.0) * expected_rate * 1.0, 4)
    assert records[0]["revenue_kgs"] == expected_revenue, records[0]
    return records


handler4 = _CountHandler()
fetch_perimeter.log.addHandler(handler4)
fetch_perimeter.log.setLevel(logging.WARNING)

_run_perimeter_case({"currency": {"meta": {"href": ".../currency/kgs-uuid"}}})
results["perimeter_kgs_no_rate"] = "OK (arithmetic verified)"
_run_perimeter_case({"value": 88.0, "currency": {"meta": {"href": ".../currency/usd-uuid"}}})
results["perimeter_usd_with_rate"] = "OK (arithmetic verified)"

handler4.count = 0
_run_perimeter_case({"currency": {"meta": {"href": ".../currency/usd-uuid"}}})
assert handler4.count == 1, f"expected 1 mismatch warning, got {handler4.count}"
fetch_perimeter.log.removeHandler(handler4)
results["perimeter_usd_no_rate_detected"] = f"OK mismatch_count={handler4.count}"


# ═══════════════════════════════════════════════════════════════════════════
# 5. cf-finance/main.py — per-row detection (payments loop)
# ═══════════════════════════════════════════════════════════════════════════
sys.path.insert(0, "reference/code/cf-finance")
import main as cf_finance_main  # noqa: E402


class _FakeResp:
    def __init__(self, payload):
        self._payload = payload

    def json(self):
        return self._payload


def _run_finance_case(rate_obj, capture):
    call_state = {"n": 0}

    def fake_get(url, headers=None):
        call_state["n"] += 1
        if "entity/currency" in url:
            return _FakeResp({"rows": FAKE_CURRENCY_ROWS, "meta": {}})
        # paymentout / cashout page — one row then stop (no nextHref), then empty for second entity_type call
        if call_state["n"] <= 2:  # currency call already counted as #1; this branch may fire more than once
            pass
        return _FakeResp({
            "rows": [{
                "id": "pay-1", "name": "П-1", "moment": "2026-05-10 12:00:00",
                "applicable": True, "sum": 30000, "rate": rate_obj,
                "expenseItem": {}, "agent": {}, "project": {}, "salesChannel": {},
            }],
            "meta": {},
        })

    orig_get = cf_finance_main.requests.get
    orig_sleep = cf_finance_main.time.sleep
    cf_finance_main.requests.get = fake_get
    cf_finance_main.time.sleep = lambda *_a, **_k: None

    # переопределяем entity_type-цикл на один тип, чтобы не задваивать вызовы —
    # run_etl() сам не параметризован по типам, зовём его как есть, но подменяем
    # bigquery.Client, чтобы не требовать живых креденшлов
    class _FakeJob:
        def result(self):
            return None

    class _FakeBQ:
        def load_table_from_json(self, *a, **k):
            return _FakeJob()

        def query(self, *a, **k):
            return _FakeJob()

    cf_finance_main.bigquery.Client = lambda project: _FakeBQ()
    os_environ_backup = dict(cf_finance_main.os.environ)
    cf_finance_main.os.environ["MSKLAD_TOKEN"] = "unused-token"

    handler = _CountHandler()
    import io
    import contextlib
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            cf_finance_main.run_etl()
    finally:
        cf_finance_main.requests.get = orig_get
        cf_finance_main.time.sleep = orig_sleep
        cf_finance_main.os.environ.clear()
        cf_finance_main.os.environ.update(os_environ_backup)

    out = buf.getvalue()
    capture["mismatch_lines"] = out.count("класс ошибки ADR-101")
    capture["expected_rate"] = rate_obj.get("value") or 1.0
    capture["stdout"] = out


cap1 = {}
_run_finance_case({"currency": {"meta": {"href": ".../currency/kgs-uuid"}}}, cap1)
assert cap1["mismatch_lines"] == 0, cap1["stdout"]
results["finance_kgs_no_rate"] = "OK (no mismatch, run_etl completed)"

cap2 = {}
_run_finance_case({"value": 88.0, "currency": {"meta": {"href": ".../currency/usd-uuid"}}}, cap2)
assert cap2["mismatch_lines"] == 0, cap2["stdout"]
results["finance_usd_with_rate"] = "OK (no mismatch, run_etl completed)"

cap3 = {}
_run_finance_case({"currency": {"meta": {"href": ".../currency/usd-uuid"}}}, cap3)
# два entity_type (paymentout, cashout) -> по одной "странице" на каждый -> 2 попадания
assert cap3["mismatch_lines"] == 2, cap3["stdout"]
results["finance_usd_no_rate_detected"] = f"OK mismatch_lines={cap3['mismatch_lines']}"


# ═══════════════════════════════════════════════════════════════════════════
print("=== VERDICT ===")
for k, v in results.items():
    print(f"{k}: {v}")
print("ALL OFFLINE CURRENCY-DETECT TESTS PASSED")
