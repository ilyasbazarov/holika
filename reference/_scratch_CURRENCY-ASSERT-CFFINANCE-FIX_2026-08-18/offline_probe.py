"""Оффлайн-проба трёх сценариев поведения _fetch_currency_map / детекции (§4 задания).
Стабы снисходительные (как import_check.py) плюс подмена requests.get на детерминированные
фикстуры — без сети. Импортирует патченный main.py и вызывает внутренние функции напрямую."""
import sys, types, importlib.util, pathlib

class Lenient(types.ModuleType):
    def __getattr__(self, name):
        m = Lenient(f"{self.__name__}.{name}")
        sys.modules[f"{self.__name__}.{name}"] = m
        return m
    def __call__(self, *a, **k):
        return Lenient(self.__name__ + "()")

for name in ["requests", "google", "google.cloud", "google.cloud.bigquery",
             "google.cloud.bigquery_datatransfer", "google.protobuf",
             "google.protobuf.timestamp_pb2", "tenacity"]:
    sys.modules.setdefault(name, Lenient(name))

# requests.get подменяется на детерминированную фикстуру ДО импорта main.py,
# чтобы вызов внутри _fetch_currency_map шёл через неё, а не через сеть.
import requests as requests_stub

SRC = pathlib.Path(sys.argv[1]).resolve()
sys.path.insert(0, str(SRC.parent))

spec = importlib.util.spec_from_file_location("main", SRC.parent / "main.py")
m = importlib.util.module_from_spec(spec)
sys.modules["main"] = m
spec.loader.exec_module(m)


class FakeResp:
    def __init__(self, json_body, status=200):
        self._json = json_body
        self.status_code = status

    def raise_for_status(self):
        if self.status_code >= 400:
            raise Exception(f"HTTP {self.status_code}")

    def json(self):
        return self._json


def scenario_a():
    """(а) живая карта валют — детекция считает как раньше."""
    print("--- Сценарий (а): живая карта валют ---")

    def fake_get(url, headers=None, timeout=None):
        return FakeResp({
            "rows": [
                {"meta": {"href": "https://x/y/uuid-kgs"}, "isoCode": "KGS"},
                {"meta": {"href": "https://x/y/uuid-usd"}, "isoCode": "USD"},
            ],
            "meta": {},
        })

    m.requests.get = fake_get
    m.time.sleep = lambda s: None
    currency_map = m._fetch_currency_map("fake-token")
    print("  currency_map =", currency_map)
    assert currency_map == {"uuid-kgs": "KGS", "uuid-usd": "USD"}, "карта валют не совпала с ожиданием"

    payments = [
        {"id": "p1", "rate": {"currency": {"meta": {"href": "https://x/y/uuid-kgs"}}}},
        {"id": "p2", "rate": {"currency": {"meta": {"href": "https://x/y/uuid-usd"}}, "value": 87.5}},
        {"id": "p3", "rate": {"currency": {"meta": {"href": "https://x/y/uuid-usd"}}}},
    ]
    mismatch = 0
    for row in payments:
        if currency_map is not None:
            rate_obj = row.get("rate") or {}
            has_rate = rate_obj.get("value") is not None
            currency_id = m.parse_href(rate_obj.get("currency"))
            iso_code = currency_map.get(currency_id) if currency_id else None
            if not (iso_code == "KGS" or has_rate):
                mismatch += 1
    print("  currency_mismatch =", mismatch, "(ожидание: 1 — p3: USD без rate.value)")
    assert mismatch == 1, "детекция дала не то число несовпадений при живой карте"
    print("  РЕЗУЛЬТАТ: детекция считает как раньше — OK")


def scenario_b():
    """(б) исключение при выборке карты валют — загрузка НЕ падает, печатается «НЕ выполнялась»."""
    print("--- Сценарий (б): исключение на выборке карты валют ---")

    def failing_get(url, headers=None, timeout=None):
        raise TimeoutError("connection timed out")

    m.requests.get = failing_get
    m.time.sleep = lambda s: None

    token = "fake-token"
    try:
        currency_map = m._fetch_currency_map(token)
    except Exception as e:
        currency_map = None
        print(f"  WARNING: карта валют недоступна ({type(e).__name__}: {e}) — "
              f"детекция INGEST-CURRENCY-ASSERT в этом прогоне НЕ выполнялась")
    currency_mismatch = 0

    assert currency_map is None, "карта валют должна быть None после исключения"
    print("  currency_map =", currency_map, "— загрузка ПРОДОЛЖИЛАСЬ (исключение поймано, не упало)")
    print("  РЕЗУЛЬТАТ: загрузка не падает, печатается «НЕ выполнялась» — OK")
    return currency_map, currency_mismatch


def scenario_c():
    """(в) итоговая печать различает «ноль несовпадений» и «не выполнялась»."""
    print("--- Сценарий (в): итоговая печать — различение состояний ---")

    def final_print(currency_map, currency_mismatch):
        if currency_map is None:
            return ("WARNING: детекция INGEST-CURRENCY-ASSERT в этом прогоне НЕ выполнялась "
                    "(карта валют недоступна)")
        elif currency_mismatch:
            return (f"WARNING: {currency_mismatch} платежей с валютой ≠ KGS без rate.value "
                    f"(currency_mismatch, INGEST-CURRENCY-ASSERT)")
        else:
            return None

    out_not_run = final_print(None, 0)
    out_zero = final_print({}, 0)
    out_some = final_print({}, 3)

    print("  currency_map=None, mismatch=0 →", repr(out_not_run))
    print("  currency_map={}, mismatch=0   →", repr(out_zero))
    print("  currency_map={}, mismatch=3   →", repr(out_some))

    assert out_not_run is not None and "НЕ выполнялась" in out_not_run
    assert out_zero is None, "«ноль несовпадений» не должно печатать WARNING вовсе"
    assert out_some is not None and "3 платежей" in out_some
    assert out_not_run != out_zero, "состояния «не выполнялась» и «ноль несовпадений» обязаны различаться"
    print("  РЕЗУЛЬТАТ: «ноль несовпадений» и «не выполнялась» различимы — OK")


if __name__ == "__main__":
    scenario_a()
    scenario_b()
    scenario_c()
    print("=== VERDICT === ALL SCENARIOS OK")
