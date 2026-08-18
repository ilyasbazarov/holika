# FILE: currency_assert_cffinance_fix_2026-08-18.md

# Правка пункта 5 ревью `CURRENCY-ASSERT-CFFINANCE-REVIEW` — `_fetch_currency_map` терпимо снаружи, строго внутри

**Сессия:** `CURRENCY-ASSERT-CFFINANCE-FIX` (класс A, без брифа — `ADR-086 §1`; продолжение сессии
`CURRENCY-ASSERT-CFFINANCE-REVIEW`; текст запуска —
`reference/currency_assert_cffinance_fix_launch_2026-08-18.md §3`)
**Дата:** 2026-08-18 (Бишкек) · **База:** `049a2b5`
**Объект правки:** `reference/code/cf-finance/main.py` — и больше ничего (`Q-117`).
**Провенанс:** `reference/_scratch_CURRENCY-ASSERT-CFFINANCE-FIX_2026-08-18/`
(`main.py.diff`, `import_check.py`, `import_check_run.log`, `offline_probe.py`, `offline_probe_run.log`)

---

## Форма правки

Применены дословно четыре куска кода §2 (i)–(iv) `reference/currency_assert_cffinance_fix_launch_2026-08-18.md`:
вариант (B) «строго внутри `_fetch_currency_map`, терпимо на месте вызова» — отказ справочника валют
гасит только диагностику `INGEST-CURRENCY-ASSERT`, не суточную загрузку платежей. Отклонений от
формы §2 нет.

## Проверка 1 — `git diff`, полный текст

```diff
diff --git a/reference/code/cf-finance/main.py b/reference/code/cf-finance/main.py
index 1c90246..524b55e 100644
--- a/reference/code/cf-finance/main.py
+++ b/reference/code/cf-finance/main.py
@@ -25,12 +25,13 @@ def _fetch_currency_map(token):
     url = "https://api.moysklad.ru/api/remap/1.2/entity/currency?limit=100"
     currency_map = {}
     while url:
-        resp = requests.get(url, headers=headers)
+        resp = requests.get(url, headers=headers, timeout=90)   # 02_ERP_CONTRACTS §поведение API
         time.sleep(0.25)
+        resp.raise_for_status()
         resp_json = resp.json()
         for row in resp_json.get("rows", []):
             currency_map[parse_href(row)] = row.get("isoCode")
-        url = resp_json.get("meta", {}).get("nextHref")
+        url = (resp_json.get("meta") or {}).get("nextHref")     # канон ADR-171 §6 для нового кода
     return currency_map
 
 def trigger_marts():
@@ -53,8 +54,14 @@ def run_etl():
     token = os.environ.get("MSKLAD_TOKEN") or os.environ.get("TOKEN")
     bq = bigquery.Client(project=PROJECT)
     
-    # INGEST-CURRENCY-ASSERT Шаг 3: currency UUID → isoCode, для детекции ниже.
-    currency_map = _fetch_currency_map(token)
+    # INGEST-CURRENCY-ASSERT Шаг 3: карта валют для детекции ниже. Диагностика не имеет права
+    # ронять загрузку, которую наблюдает: недоступность справочника гасит детекцию, не ETL.
+    try:
+        currency_map = _fetch_currency_map(token)
+    except Exception as e:
+        currency_map = None
+        print(f"WARNING: карта валют недоступна ({type(e).__name__}: {e}) — "
+              f"детекция INGEST-CURRENCY-ASSERT в этом прогоне НЕ выполнялась")
     currency_mismatch = 0
 
     records = []
@@ -75,16 +82,17 @@ def run_etl():
 
                 # INGEST-CURRENCY-ASSERT Шаг 4 (ADR-101 §5): бинарная детекция «валюта=KGS
                 # либо применён rate.value» — арифметика sum_kgs НЕ меняется, только лог.
-                rate_obj    = row.get("rate") or {}
-                has_rate    = rate_obj.get("value") is not None
-                currency_id = parse_href(rate_obj.get("currency"))
-                iso_code    = currency_map.get(currency_id) if currency_id else None
-                if not (iso_code == "KGS" or has_rate):
-                    currency_mismatch += 1
-                    print(
-                        f"WARNING: {entity_type} {row.get('id')}: currency={currency_id} "
-                        f"(iso={iso_code}) без rate.value — класс ошибки ADR-101 §5"
-                    )
+                if currency_map is not None:
+                    rate_obj    = row.get("rate") or {}
+                    has_rate    = rate_obj.get("value") is not None
+                    currency_id = parse_href(rate_obj.get("currency"))
+                    iso_code    = currency_map.get(currency_id) if currency_id else None
+                    if not (iso_code == "KGS" or has_rate):
+                        currency_mismatch += 1
+                        print(
+                            f"WARNING: {entity_type} {row.get('id')}: currency={currency_id} "
+                            f"(iso={iso_code}) без rate.value — класс ошибки ADR-101 §5"
+                        )
 
                 records.append({
                     "payment_id": row.get("id"),
@@ -108,11 +116,12 @@ def run_etl():
                 })
             url = resp_json.get("meta", {}).get("nextHref")
 
-    if currency_mismatch:
-        print(
-            f"WARNING: {currency_mismatch} платежей с валютой ≠ KGS без rate.value "
-            f"(currency_mismatch, INGEST-CURRENCY-ASSERT)"
-        )
+    if currency_map is None:
+        print("WARNING: детекция INGEST-CURRENCY-ASSERT в этом прогоне НЕ выполнялась "
+              "(карта валют недоступна)")
+    elif currency_mismatch:
+        print(f"WARNING: {currency_mismatch} платежей с валютой ≠ KGS без rate.value "
+              f"(currency_mismatch, INGEST-CURRENCY-ASSERT)")
 
     if records:
         print(f"Loading {len(records)} records to STG...")
```

Строка расчёта суммы (`main.py:105` в базе, `* ((row.get("rate") or {}).get("value") or 1.0)`)
в диффе отсутствует — присутствует только как некотекстовая (не тронутая, не в hunk) строка
файла, что и требовалось: правка её не касается ни `+`, ни `-`.

## Проверка 2 — только один файл в диффе

```
$ git status --porcelain
 M reference/code/cf-finance/main.py
```

Ни одного другого файла в рабочем дереве не изменено.

## Проверка 3 — факт-проверка ИСПОЛНЕНИЕМ

Скрипт — тот же `import_check.py`, что использовался ревью (скопирован без изменений из
`reference/_scratch_CURRENCY-ASSERT-CFFINANCE-REVIEW_2026-08-18/import_check.py`), прогнан против
патченного `main.py`:

```
=== python3 --version ===
Python 3.9.6
=== import_check.py run ===
OK   импорт invoices.py
OK   импорт main.py
  имя parse_href: есть
  имя _fetch_currency_map: есть
  имя run_etl: есть
  имя trigger_marts: есть
  имя main: есть
  parse_href(None) = None
  parse_href({'meta':{'href':'https://x/y/uuid-1'}}) = uuid-1
  parse_href({'meta': None}) = ИСКЛЮЧЕНИЕ AttributeError: 'NoneType' object has no attribute 'get'
=== VERDICT ===
ALL IMPORTS OK
```

`rc=0`. Известное ограничение из ревью (`main.py:33` в старой нумерации — устаревшая форма
`.get("meta", {})` на строке ВНЕ `_fetch_currency_map`, пункт 4 ревью) сохраняется как было:
эта правка её не трогала (вне объёма пункта 5), `parse_href({'meta': None})` по-прежнему падает
исключением — то же поведение, что зафиксировано ревью.

## Проверка 4 — оффлайн-проба трёх сценариев

Скрипт `offline_probe.py`, `date -u` первой и последней командой, лог —
`reference/_scratch_CURRENCY-ASSERT-CFFINANCE-FIX_2026-08-18/offline_probe_run.log`:

```
Tue Aug 18 14:05:30 UTC 2026
=== offline_probe.py run ===
--- Сценарий (а): живая карта валют ---
  currency_map = {'uuid-kgs': 'KGS', 'uuid-usd': 'USD'}
  currency_mismatch = 1 (ожидание: 1 — p3: USD без rate.value)
  РЕЗУЛЬТАТ: детекция считает как раньше — OK
--- Сценарий (б): исключение на выборке карты валют ---
  WARNING: карта валют недоступна (TimeoutError: connection timed out) — детекция INGEST-CURRENCY-ASSERT в этом прогоне НЕ выполнялась
  currency_map = None — загрузка ПРОДОЛЖИЛАСЬ (исключение поймано, не упало)
  РЕЗУЛЬТАТ: загрузка не падает, печатается «НЕ выполнялась» — OK
--- Сценарий (в): итоговая печать — различение состояний ---
  currency_map=None, mismatch=0 → 'WARNING: детекция INGEST-CURRENCY-ASSERT в этом прогоне НЕ выполнялась (карта валют недоступна)'
  currency_map={}, mismatch=0   → None
  currency_map={}, mismatch=3   → 'WARNING: 3 платежей с валютой ≠ KGS без rate.value (currency_mismatch, INGEST-CURRENCY-ASSERT)'
  РЕЗУЛЬТАТ: «ноль несовпадений» и «не выполнялась» различимы — OK
=== VERDICT === ALL SCENARIOS OK
=== rc=0 ===
Tue Aug 18 14:05:30 UTC 2026
```

(а) при живой карте валют детекция даёт то же число несовпадений, что и старая форма (проверено
сравнением с ожидаемым значением `1`, вычисленным вручную по тем же трём фикстурным платежам).
(б) исключение при выборке карты (смоделирован `TimeoutError`) не роняет вызывающий код — карта
становится `None`, печатается предупреждение «НЕ выполнялась», выполнение продолжается.
(в) финальная печать для трёх состояний карты/счётчика различима: «не выполнялась» ≠ `None`
(нет вывода, то есть «ноль несовпадений» молчит) ≠ текст с ненулевым счётчиком.

## Отклонения от формы §2

Нет.

## Границы, соблюдённые этой сессией

Деплой не исполнялся и не запрашивался. `cf-facts` не тронут. `git push` не выполнялся. Мандат
класса B на выезд `cf-finance` этой правкой не выдаётся и не продлевается — по `ADR-163` он
выдаётся владельцем заново на изменённый объект.
