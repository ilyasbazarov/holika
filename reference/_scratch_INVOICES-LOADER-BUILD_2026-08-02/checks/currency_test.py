"""
Проверка конвертации (design §8) — БЕЗ секрета msklad-token и БЕЗ живого GET.
Сетевая зависимость (_api_get к entity/currency) подменяется контролируемым fake —
это тестирует логику трёх ветвей и арифметику, а не факт доступности живого API
(живая проверка entity/currency секретом инструменту недоступна под классом A этой
строки, см. брифа §«Живые вызовы к МойСкладу»).
"""
import sys

sys.path.insert(0, "reference/code/cf-finance")
sys.path.insert(0, "reference/_scratch_INVOICES-LOADER-BUILD_2026-08-02/checks")
import invoices as inv
from bq_client import get_client

# ── 1. Юнит-проверка трёх ветвей rate_and_currency (design §8.2) ──────────────

class FakeSession:
    pass

session = FakeSession()
token = "unused-in-this-test"

# Ветвь 1: rate.value задан
doc1 = {"id": "doc-1", "rate": {"value": 1.25, "currency": {"isoCode": "USD"}}}
rv1, cc1, fb1 = inv.rate_and_currency(session, token, doc1)
assert (rv1, cc1, fb1) == (1.25, "USD", False), f"ветвь 1: {rv1, cc1, fb1}"
print(f"branch1_rate_value_present: rate={rv1} currency={cc1} fallback={fb1}")

# Ветвь 2: rate.value пуст, currency=KGS -> 1.0
doc2 = {"id": "doc-2", "rate": {"currency": {"isoCode": "KGS"}}}
rv2, cc2, fb2 = inv.rate_and_currency(session, token, doc2)
assert (rv2, cc2, fb2) == (1.0, "KGS", False), f"ветвь 2: {rv2, cc2, fb2}"
print(f"branch2_kgs_no_rate: rate={rv2} currency={cc2} fallback={fb2}")

# Ветвь 3: rate.value пуст, currency=USD -> fallback, _fetch_current_rate подменена
orig_fetch = inv._fetch_current_rate
inv._fetch_current_rate = lambda session, token, iso_code: 89.5
doc3 = {"id": "doc-3", "rate": {"currency": {"isoCode": "USD"}}}
rv3, cc3, fb3 = inv.rate_and_currency(session, token, doc3)
assert (rv3, cc3, fb3) == (89.5, "USD", True), f"ветвь 3: {rv3, cc3, fb3}"
print(f"branch3_fallback_hit: rate={rv3} currency={cc3} fallback={fb3}")
inv._fetch_current_rate = orig_fetch

# ── 2. _fetch_current_rate сам по себе — успех и падение, сеть подменена ──────

class FakeResp:
    def __init__(self, payload):
        self._payload = payload
        self.status_code = 200
    def raise_for_status(self):
        pass
    def json(self):
        return self._payload

class FakeSessionCurrency:
    def __init__(self, payload):
        self._payload = payload
    def get(self, url, headers=None, params=None, timeout=None):
        return FakeResp(self._payload)

inv._CURRENCY_RATE_CACHE.clear()
ok_session = FakeSessionCurrency({"rows": [{"isoCode": "USD", "rate": {"value": 89.5}}]})
rate = inv._fetch_current_rate(ok_session, token, "USD")
assert rate == 89.5, f"_fetch_current_rate success: {rate}"
print(f"fetch_current_rate_success: rate={rate}")

inv._CURRENCY_RATE_CACHE.clear()
bad_session = FakeSessionCurrency({"rows": [{"isoCode": "USD", "rate": None}]})
try:
    inv._fetch_current_rate(bad_session, token, "USD")
    print("fetch_current_rate_missing_value: FAIL — не упало")
except RuntimeError as e:
    print(f"fetch_current_rate_missing_value_raised: {e}")

# ── 3. build_staging_row + реальная запись в staging + bad_rows (design §6.2) ─

inv._CURRENCY_RATE_CACHE.clear()
inv._fetch_current_rate = lambda session, token, iso_code: 89.5  # фиксированный курс для теста

synthetic_docs = [
    {  # KGS документ, rate.value отсутствует -> 1.0
        "id": "synt-kgs-1", "name": "СФ-0001",
        "moment": "2026-05-10 12:00:00.000",
        "sum": 150000, "payedSum": 50000,
        "agent": {"meta": {"href": ".../agent/aaa"}, "name": "ООО Ромашка"},
        "state": {"meta": {"href": ".../state/bbb"}, "name": "Оплачен частично"},
        "salesChannel": {"meta": {"href": ".../saleschannel/ccc"}, "name": "Опт"},
        "applicable": True,
        "rate": {"currency": {"isoCode": "KGS"}},
    },
    {  # USD документ С rate.value
        "id": "synt-usd-withrate", "name": "СФ-0002",
        "moment": "2026-05-11 09:30:00.000",
        "sum": 20000, "payedSum": 0,
        "agent": {"meta": {"href": ".../agent/ddd"}, "name": "Bloom WB"},
        "state": {"meta": {"href": ".../state/eee"}, "name": "Не оплачен"},
        "salesChannel": None,
        "applicable": True,
        "rate": {"value": 88.0, "currency": {"isoCode": "USD"}},
    },
    {  # USD документ БЕЗ rate.value -> fallback (третья ветвь)
        "id": "synt-usd-fallback", "name": "СФ-0003",
        "moment": "2026-05-12 22:15:00.000",  # полоса [18:00;24:00) UTC — используется отдельным тестом суток
        "sum": 500000, "payedSum": 500000,
        "agent": {"meta": {"href": ".../agent/fff"}, "name": "UMAI WB"},
        "state": {"meta": {"href": ".../state/ggg"}, "name": "Оплачен"},
        "salesChannel": {"meta": {"href": ".../saleschannel/hhh"}, "name": "Комиссия"},
        "applicable": True,
        "rate": {"currency": {"isoCode": "USD"}},
    },
]

loaded_at_iso = "2026-08-02T18:58:00+00:00"
rows = []
fallback_hits = 0
for d in synthetic_docs:
    row, used_fb = inv.build_staging_row(session, token, d, loaded_at_iso)
    if used_fb:
        fallback_hits += 1
    rows.append(row)

print(f"synthetic_rows_built={len(rows)} fallback_hits={fallback_hits}")
assert fallback_hits == 1, f"ожидался ровно 1 fallback-hit (synt-usd-fallback), получено {fallback_hits}"

bq = get_client()
n_loaded = inv.load_staging(bq, rows)
print(f"staging_rows_loaded={n_loaded}")

bad_rows_sql = f"""
SELECT COUNT(*) AS bad_rows
FROM `{inv.STG_INVOICES}`
WHERE invoice_id IN ({",".join(f"'{d['id']}'" for d in synthetic_docs)})
  AND (
    ABS(sum_kgs - sum_minor / 100.0 * rate_value) > 0.01
    OR ABS(payed_sum_kgs - payed_sum_minor / 100.0 * rate_value) > 0.01
    OR ABS(unpaid_sum_kgs - (sum_kgs - payed_sum_kgs)) > 0.01
  )
"""
bad_rows = list(bq.query(bad_rows_sql).result())[0].bad_rows
print(f"bad_rows={bad_rows}")
assert bad_rows == 0, f"ожидалось bad_rows=0, получено {bad_rows}"

inv._fetch_current_rate = orig_fetch

print(
    "VERDICT: branch1=OK branch2=OK branch3_fallback=OK "
    "fetch_current_rate_success=OK fetch_current_rate_raise_on_missing=OK "
    f"synthetic_rows={len(rows)} fallback_hits={fallback_hits} bad_rows={bad_rows}"
)
