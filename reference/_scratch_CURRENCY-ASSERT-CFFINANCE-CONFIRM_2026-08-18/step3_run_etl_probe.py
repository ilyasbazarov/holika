"""Независимая проба: исполняется НАСТОЯЩАЯ run_etl() целиком, а не копия её логики.
Проверяются два состояния пункта 5: справочник валют жив / справочник отказал."""
import sys, types, io, contextlib, importlib.util, pathlib

class Lenient(types.ModuleType):
    def __getattr__(self, n):
        m = Lenient(f"{self.__name__}.{n}"); sys.modules[f"{self.__name__}.{n}"] = m; return m
    def __call__(self, *a, **k): return Lenient(self.__name__ + "()")

for n in ["google","google.cloud","google.cloud.bigquery","google.cloud.bigquery_datatransfer",
          "google.protobuf","google.protobuf.timestamp_pb2","tenacity"]:
    sys.modules.setdefault(n, Lenient(n))

req = Lenient("requests"); sys.modules["requests"] = req

class Resp:
    def __init__(self, body, status=200): self._b, self.status_code = body, status
    def raise_for_status(self):
        if self.status_code >= 400: raise Exception(f"HTTP {self.status_code}")
    def json(self): return self._b

CURRENCIES = {"rows":[{"meta":{"href":"https://x/entity/currency/uuid-kgs"},"isoCode":"KGS"},
                      {"meta":{"href":"https://x/entity/currency/uuid-usd"},"isoCode":"USD"}],"meta":{}}
def payment(pid, cur, rate):
    r = {"id":pid,"name":pid,"sum":10000,"moment":"2026-05-01 10:00:00.000",
         "expenseItem":{"meta":{"href":"https://x/entity/expenseitem/e1"}},
         "agent":{"meta":{"href":"https://x/entity/counterparty/a1"}},"applicable":True}
    if cur: r["rate"] = {"currency":{"meta":{"href":f"https://x/entity/currency/{cur}"}}}
    if rate is not None: r.setdefault("rate", {})["value"] = rate
    return r
PAYMENTS = {"rows":[payment("p1","uuid-kgs",None), payment("p2","uuid-usd",87.5),
                    payment("p3","uuid-usd",None)],"meta":{}}

def make_get(currency_fails):
    def get(url, headers=None, timeout=None, **kw):
        if "entity/currency" in url:
            if currency_fails: raise TimeoutError("connection timed out")
            return Resp(CURRENCIES)
        return Resp(PAYMENTS)
    return get

src = pathlib.Path("reference/code/cf-finance/main.py").resolve()
sys.path.insert(0, str(src.parent))
spec = importlib.util.spec_from_file_location("main", src)
main = importlib.util.module_from_spec(spec); sys.modules["main"] = main; spec.loader.exec_module(main)
main.trigger_marts = lambda: print("  [стаб] trigger_marts пропущен")

for label, fails in [("СПРАВОЧНИК ЖИВ", False), ("СПРАВОЧНИК ОТКАЗАЛ", True)]:
    req.get = make_get(fails)
    buf = io.StringIO()
    print(f"--- {label} ---")
    try:
        with contextlib.redirect_stdout(buf): main.run_etl()
        crashed = None
    except Exception as e:
        crashed = f"{type(e).__name__}: {e}"
    out = buf.getvalue()
    print(f"  run_etl упала: {crashed if crashed else 'НЕТ'}")
    for line in out.splitlines():
        if "WARNING" in line or "Loading" in line: print("  |", line.strip())
print("=== VERDICT ===")
