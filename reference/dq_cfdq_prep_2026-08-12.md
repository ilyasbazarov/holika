# FILE: dq_cfdq_prep_2026-08-12.md

# Подготовка ОБЕИХ правок cf-dq одним заходом — `DQ-GATE-METRIC-REDESIGN` (ход 1) + `DQ-FRESHNESS-COVERAGE`, остаток (ход 2)

**Дата:** 2026-08-12 (Бишкек) · **Класс задачи:** A — подготовка патча, ничего не деплоит и не
подключает к живому гейту.
**Дерево/ветка:** `worktrees/DQ-GATE-METRIC-REDESIGN` / `s/DQ-GATE-METRIC-REDESIGN`
**Основание запуска без брифа (`ADR-086 §1`):** класс A; приёмка процитирована дословно из
`07_STATE.md` (`ADR-153`/`ADR-155`, строки `§Открытые вопросы`); полный набор файлов на запись
объявлен в тексте запуска (ровно два плюс артефакт); определение задачи процитировано, не
пересказано.

**Назначение файла.** Самодостаточный артефакт приёмки для обоих ходов ПЛЮС правки по ревью
архитектора (§9, второй заход того же дня): печать `py_compile`, дифф целиком (2 файла), `dry_run`
изменённых/новых SQL, грепы, подтверждающие состав `CHECKS` и дословную сохранность ветки
`ma7 == 0`, и таблица старое/новое поведение `drift_check` на ТРЁХ случаях (двух исходных плюс
найденном ревью).

---

## 0. Вход

Прочитано целиком: `_METHOD.md`, `00_CHARTER.md`, `04_ROADMAP.md`, `06_INDEX.md`,
`05_CONVENTIONS.md`; из `07_STATE.md` — `§Текущий фокус`, `§Мандат Claude Code` (строки
`DQ-GATE-METRIC-REDESIGN`, `DQ-FRESHNESS-COVERAGE, подготовка`), `§Открытые вопросы` (те же
две строки); `06_DECISIONS_LOG.md` ADR-153, ADR-154 (для контекста, не трогается), ADR-155
полным текстом; `reference/dq_gate_metric_redesign_2026-08-10.md` §3-§4 целиком;
`reference/dq_freshness_coverage_2026-08-09.md` целиком; `reference/code/cf-dq/main.py` и
`config.py` целиком (до правки); `11_INFRA_FACTS.md` строки 25-27 (каденция
`finance-daily-update`/`loss-commission-daily-update`, обе `0 3 * * *` Asia/Bishkek).

---

## 1. Приёмка (1) — `python3 -m py_compile`

```
$ cd reference/code/cf-dq && python3 -m py_compile main.py config.py && echo "PY_COMPILE_RC=0"
PY_COMPILE_RC=0
```

## 2. Приёмка (2) — `bq query --dry_run` двух новых SQL против живых схем

Скрипт с логом (правило CLAUDE.md — скрипт-файл, не россыпь вызовов):
`reference/_scratch_DQ-GATE-METRIC-REDESIGN_2026-08-12/dry_run_new_freshness_checks.sh` →
`.../dry_run_new_freshness_checks.log`. `date -u`/`gcloud auth list` первой И последней командой.

```
=== date -u (start) ===
Wed Aug 12 16:58:29 UTC 2026
=== gcloud auth list (start) ===
     Credentialed Accounts
ACTIVE  ACCOUNT
*       ilyasbazarov4@gmail.com
=== dry_run: fact_payments technical ===
Query successfully validated. Assuming the tables are not modified, running this query will process 41120 bytes of data.
=== dry_run: fact_commissionreportin technical ===
Query successfully validated. Assuming the tables are not modified, running this query will process 1552 bytes of data.
=== gcloud auth list (end) ===
     Credentialed Accounts
ACTIVE  ACCOUNT
*       ilyasbazarov4@gmail.com
=== date -u (end) ===
Wed Aug 12 16:58:34 UTC 2026
```

Обе новые проверки (A) синтаксически валидны против ЖИВЫХ схем `core.fact_payments` и
`core.fact_commissionreportin`; авторизация не деградировала между началом и концом прогона
(`ADR-055/063`); `--dry_run` ничего не читал и не писал.

## 3. Приёмка (3) — `git diff --stat`, дифф затронул ровно два файла

```
$ git diff --stat -- reference/code/cf-dq/main.py reference/code/cf-dq/config.py
 reference/code/cf-dq/config.py |  26 +++++---
 reference/code/cf-dq/main.py   | 138 ++++++++++++++++++++++++++++++++---------
 2 files changed, 128 insertions(+), 36 deletions(-)
```

Полный текст диффа целиком — `reference/_scratch_DQ-GATE-METRIC-REDESIGN_2026-08-12/full_diff.patch`
(231 строка), воспроизведён ниже дословно.

```diff
diff --git a/reference/code/cf-dq/config.py b/reference/code/cf-dq/config.py
index a1f31e6..d3ebcd9 100644
--- a/reference/code/cf-dq/config.py
+++ b/reference/code/cf-dq/config.py
@@ -39,11 +39,21 @@ DQ_FRESHNESS_INVOICES_MAX_HOURS = 48
 # core.fact_customer_invoices — перенесено без изменений из
 # reference/invoices_loader_design_2026-08-02.md §9.2 (суточный загрузчик → 2 × 24ч = 48ч).
 
-# DQ_FRESHNESS_PAYMENTS_MAX_HOURS / DQ_FRESHNESS_COMMISSIONREPORTIN_MAX_HOURS — НЕ заводятся.
-# Номинальная величина по формуле была бы 48ч (finance-daily-update / loss-commission-daily-update,
-# суточная каденция, "0 3 * * *" Asia/Bishkek, 11_INFRA_FACTS.md), но инвариант "один стамп
-# _loaded_at на прогон" ОПРОВЕРГНУТ чтением кода для обеих таблиц (cf-finance/main.py:72,
-# cf-loss-commission/main.py:149 — datetime.now()/utcnow() вызывается ОТДЕЛЬНО на каждую строку,
-# не один раз на прогон), см. reference/dq_freshness_coverage_2026-08-09.md §открытые вопросы.
-# Проверка (A) для этих двух таблиц не готова к переносу — константа порога не заводится, чтобы
-# не создавать видимость готовой проверки (05_CONVENTIONS ★ anti-improvisation).
+DQ_FRESHNESS_PAYMENTS_MAX_HOURS = 48
+# finance-daily-update, расписание "0 3 * * *" Asia/Bishkek (11_INFRA_FACTS.md:25)
+# → суточная каденция → 2 × 24ч = 48ч. Величина берётся как MAX(_loaded_at)
+# (ADR-155): дефект построчного стампа (cf-finance/main.py:72 — datetime.now()
+# вызывается отдельно на каждую строку, не один раз на прогон) не блокирует
+# готовность порогового значения — MAX по построчным стампам равен моменту
+# окончания прогона, отличие от единого стампа на прогон (минуты) пренебрежимо
+# мало относительно порога (48ч), направление ошибки безопасное (ADR-155 §2).
+# Поле distinct_load_stamps для этой таблицы неинформативно — построчный
+# стамп, не стамп прогона.
+
+DQ_FRESHNESS_COMMISSIONREPORTIN_MAX_HOURS = 48
+# loss-commission-daily-update, расписание "0 3 * * *" Asia/Bishkek
+# (11_INFRA_FACTS.md:26) → суточная каденция → 2 × 24ч = 48ч. Тот же вывод
+# порога и то же снятие дефекта построчного стампа (ADR-155), что у
+# DQ_FRESHNESS_PAYMENTS_MAX_HOURS выше (cf-loss-commission/main.py:149 —
+# datetime.utcnow() отдельно на каждую строку). Поле distinct_load_stamps для
+# этой таблицы неинформативно — построчный стамп, не стамп прогона.
diff --git a/reference/code/cf-dq/main.py b/reference/code/cf-dq/main.py
index 26bdb10..e37d4e1 100644
--- a/reference/code/cf-dq/main.py
+++ b/reference/code/cf-dq/main.py
@@ -5,6 +5,7 @@ from config import (
     DQ_CURRENCY_MAX_AVG_REV,
     DQ_FRESHNESS_PURCHASES_MAX_HOURS, DQ_FRESHNESS_RETURNS_MAX_HOURS,
     DQ_FRESHNESS_INVENTORY_MAX_HOURS, DQ_FRESHNESS_INVOICES_MAX_HOURS,
+    DQ_FRESHNESS_PAYMENTS_MAX_HOURS, DQ_FRESHNESS_COMMISSIONREPORTIN_MAX_HOURS,
 )
 from helpers import get_bq_client, run_scalar, run_row, write_dq_results
 
@@ -46,14 +47,22 @@ def check_drift(bq):
     
     if not row or row.get("target_date") is None:
         return False, "target_date=NULL"
-        
+
     target_rev  = float(row.get("target_rev", 0) or 0)
     day_of_week = int(row.get("day_of_week", 2) or 2)
     target_date = row.get("target_date", "")
     is_weekend  = day_of_week in (1, 7)
     threshold   = DQ_DRIFT_WEEKEND_THRESHOLD if is_weekend else DQ_DRIFT_THRESHOLD
     day_label   = "weekend" if is_weekend else "weekday"
-    
+
+    # DQ-GATE-METRIC-REDESIGN (ADR-153, кандидат 1): исход "документов не было
+    # вовсе" уходит в отдельную диагностическую функцию check_drift_zero_docs
+    # (всегда passed=True, notify, не блокирует promote). Здесь, в блокирующем
+    # чеке, остаётся только класс "документы есть, выручка ниже нормы".
+    if target_rev == 0:
+        return True, (f"yesterday_rev=0, target_date={target_date} "
+                       f"(документов не было — см. check_drift_zero_docs, notify)")
+
     # ma7 считаем за 7 полных дней ДО вчерашнего (T-8 до T-2)
     ma7 = run_scalar(bq, f"""
         SELECT COALESCE(AVG(daily_rev),0) FROM (
@@ -83,6 +92,45 @@ def check_drift(bq):
             f"yesterday_rev={target_rev:.0f}, ma7={float(ma7):.0f}, ratio={ratio:.2f}, "
             f"threshold={threshold} ({day_label}), target_date={target_date}")
 
+def check_drift_zero_docs(bq):
+    # DQ-GATE-METRIC-REDESIGN (ADR-153, кандидат 1): диагностика по исходу
+    # "документов не было вовсе" (target_rev == 0). ВСЕГДА passed=True — не
+    # блокирует promote. Механизм "две функции" по образцу пары
+    # technical/business блока freshness ниже. НЕ подключена к CHECKS —
+    # доставка исхода в telegram-канал notify — отдельная задача класса B
+    # (вторая лог-метрика, ADR-153 §Последствия).
+    row = run_row(bq, f"""
+        WITH target_d AS (
+            SELECT DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 1 DAY) AS d
+        )
+        SELECT
+            CAST(target_d.d AS STRING) AS target_date,
+            EXTRACT(DAYOFWEEK FROM target_d.d) AS day_of_week,
+            COALESCE(SUM(s.revenue_kgs), 0) AS target_rev
+        FROM target_d
+        LEFT JOIN `{STAGING}` s
+          ON DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek') = target_d.d
+        GROUP BY target_d.d
+    """)
+
+    if not row or row.get("target_date") is None:
+        return True, "target_date=NULL (notify-only, не блокирует)"
+
+    target_rev  = float(row.get("target_rev", 0) or 0)
+    target_date = row.get("target_date", "")
+
+    ma7 = run_scalar(bq, f"""
+        SELECT COALESCE(AVG(daily_rev),0) FROM (
+            SELECT transaction_date, SUM(revenue_kgs) AS daily_rev
+            FROM `{CORE_FACT}`
+            WHERE transaction_date >= DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 8 DAY)
+              AND transaction_date  <  DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 1 DAY)
+            GROUP BY 1)
+    """) or 0.0
+
+    return True, (f"yesterday_rev={target_rev:.0f}, ma7={float(ma7):.0f}, target_date={target_date} "
+                   f"(notify, не блокирует promote)")
+
 def check_fk_integrity(bq):
     orphans = run_scalar(bq, f"""
         SELECT COUNT(DISTINCT s.product_id) FROM `{STAGING}` s
@@ -137,18 +185,27 @@ CHECKS = [
 ]
 
 # ═══════════════════════════════════════════════════════════════════════════
-# DQ-FRESHNESS-COVERAGE (подготовка, класс A, 2026-08-09) — проверки свежести
-# для шести таблиц ядра без наблюдателя. НЕ включены в CHECKS выше — эта
-# задача не подключает проверки к живому гейту (подключение/деплой —
-# отдельная задача класса B, "DQ-FRESHNESS-COVERAGE, деплой", мандат не
-# выдан). Полное обоснование, вывод порогов и dry_run-логи —
-# reference/dq_freshness_coverage_2026-08-09.md.
+# DQ-FRESHNESS-COVERAGE (подготовка, класс A, 2026-08-09 + остаток 2026-08-12)
+# — проверки свежести для шести таблиц ядра без наблюдателя. НЕ включены в
+# CHECKS выше — эта задача не подключает проверки к живому гейту (подключение/
+# деплой — отдельная задача класса B, "DQ-FRESHNESS-COVERAGE, деплой", мандат
+# не выдан). Полное обоснование, вывод порогов и dry_run-логи —
+# reference/dq_freshness_coverage_2026-08-09.md (четыре таблицы) +
+# reference/dq_cfdq_prep_2026-08-12.md (остаток: fact_payments,
+# fact_commissionreportin, ADR-155).
 #
 # Форма (A)/(B) — reference/invoices_loader_design_2026-08-02.md §9.2:
 #   (A) техническая свежесть — блокирующая ПО ФОРМЕ (passed=False возможен),
 #       но нигде не подключена; порог = 2 × период каденции.
 #   (B) бизнес-свежесть — диагностика, ВСЕГДА passed=True, порога нет
 #       (осознанный отказ — нет эмпирики пауз между документами).
+#
+# Все шесть таблиц (fact_purchases/fact_returns/fact_inventory/
+# fact_customer_invoices/fact_payments/fact_commissionreportin) теперь несут
+# обе проверки (A)/(B). У последних двух построчный стамп _loaded_at
+# (cf-finance/main.py:72, cf-loss-commission/main.py:149) не мешает порогу
+# (A) — MAX(_loaded_at) остаётся верным, direction ошибки безопасное
+# (ADR-155); поле distinct_load_stamps для них неинформативно.
 # ═══════════════════════════════════════════════════════════════════════════
 
 # ─── core.fact_purchases — часовая каденция (step_purchases, NON-BLOCKING) ───
@@ -228,20 +285,30 @@ def check_freshness_inventory_business(bq):
 
 # ─── core.fact_payments — суточная каденция (finance-daily-update) ───
 #
-# ⚠ Проверка (A) НЕ ЗАВЕДЕНА. Инвариант "один стамп _loaded_at на прогон"
-# ОПРОВЕРГНУТ чтением reference/code/cf-finance/main.py:72 —
-# `"_loaded_at": datetime.datetime.now(datetime.timezone.utc).strftime(...)`
+# Построчный стамп _loaded_at (cf-finance/main.py:72 — datetime.now()
 # вызывается ОТДЕЛЬНО на каждую строку внутри цикла постранично, а не один
-# раз на прогон (форма, названная антипаттерном в
-# reference/invoices_loader_design_2026-08-02.md §6.4: "разброс по
-# микросекундам, который дал бы datetime.now() внутри цикла (форма
-# cf-finance/main.py:68)" — тот же файл, тот же класс дефекта). Без
-# единого стампа "MAX(_loaded_at)" остаётся вычислимым, но готовность-условие
-# "COUNT(DISTINCT _loaded_at) == 1 на прогон" не выполняется, а именно на
-# нём построена семантика проверки (A) по образцу invoices. Открытый вопрос
-# зафиксирован в reference/dq_freshness_coverage_2026-08-09.md, порог не
-# назначен (config.py), функция технической проверки не пишется как готовая
-# — только бизнес-диагностика ниже (она от инварианта не зависит).
+# раз на прогон) снят с критического пути этой проверки (ADR-155): MAX по
+# построчным стампам равен моменту окончания прогона, отличие от единого
+# стампа — минуты против порога 48ч, направление ошибки безопасное.
+# distinct_load_stamps для этой таблицы НЕ читать как число прогонов —
+# построчный стамп даёт разброс внутри одного прогона. Дефект самого
+# загрузчика остаётся отдельной строкой (LOADER-LOADED-AT-STAMP, ADR-155 §4),
+# фикс-форвардом в cf-finance, вне scope этой проверки.
+
+def check_freshness_payments_technical(bq):
+    row = run_row(bq, f"""
+        SELECT
+            TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
+            COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
+            COUNT(*) AS n_rows
+        FROM `{CORE_PAYMENTS}`
+    """)
+    if not row or row.get("load_lag_hours") is None:
+        return False, "load_lag_hours=NULL (таблица пустая)"
+    lag = row["load_lag_hours"]
+    return (lag <= DQ_FRESHNESS_PAYMENTS_MAX_HOURS,
+            f"load_lag_hours={lag}, distinct_load_stamps={row['distinct_load_stamps']} "
+            f"(построчный стамп, не стамп прогона), n_rows={row['n_rows']}")
 
 def check_freshness_payments_business(bq):
     row = run_row(bq, f"""
@@ -254,13 +321,28 @@ def check_freshness_payments_business(bq):
 
 # ─── core.fact_commissionreportin — суточная каденция (loss-commission-daily-update) ───
 #
-# ⚠ Проверка (A) НЕ ЗАВЕДЕНА. Тот же класс дефекта, что у fact_payments выше:
-# reference/code/cf-loss-commission/main.py:149 (fetch_commission) —
-# `"_loaded_at": datetime.datetime.utcnow().isoformat()` вызывается ОТДЕЛЬНО
-# на каждую строку (isoformat() несёт микросекунды, разброс гарантирован при
-# любом прогоне длиннее одной микросекунды). Тот же дефект пронаблюдён и в
-# соседней fetch_loss (main.py:123, вне scope этой задачи). Открытый вопрос —
-# reference/dq_freshness_coverage_2026-08-09.md.
+# Тот же класс дефекта построчного стампа, что у fact_payments выше
+# (cf-loss-commission/main.py:149, fetch_commission —
+# datetime.utcnow().isoformat() отдельно на каждую строку), снят с
+# критического пути этой проверки тем же основанием (ADR-155). Тот же дефект
+# пронаблюдён и в соседней fetch_loss (main.py:123, core.fact_loss, вне scope
+# этой задачи). distinct_load_stamps для этой таблицы НЕ читать как число
+# прогонов.
+
+def check_freshness_commissionreportin_technical(bq):
+    row = run_row(bq, f"""
+        SELECT
+            TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
+            COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
+            COUNT(*) AS n_rows
+        FROM `{CORE_COMMISSIONREPORTIN}`
+    """)
+    if not row or row.get("load_lag_hours") is None:
+        return False, "load_lag_hours=NULL (таблица пустая)"
+    lag = row["load_lag_hours"]
+    return (lag <= DQ_FRESHNESS_COMMISSIONREPORTIN_MAX_HOURS,
+            f"load_lag_hours={lag}, distinct_load_stamps={row['distinct_load_stamps']} "
+            f"(построчный стамп, не стамп прогона), n_rows={row['n_rows']}")
 
 def check_freshness_commissionreportin_business(bq):
     row = run_row(bq, f"""
```

## 4. Приёмка (4) — грепы: `CHECKS` не тронут, новые функции не подключены

```
$ grep -n "^CHECKS = \[\|(\"not_empty\"\|(\"drift_check\"\|(\"fk_integrity\"\|(\"freshness\"\|(\"margin_sanity\"\|(\"currency_normalization\"\|^\]" reference/code/cf-dq/main.py
178:CHECKS = [
179:    ("not_empty",              check_not_empty),
180:    ("drift_check",            check_drift),
181:    ("fk_integrity",           check_fk_integrity),
182:    ("freshness",              check_freshness),
183:    ("margin_sanity",          check_margin_sanity),
184:    ("currency_normalization", check_currency_normalization),
185:]
```

`CHECKS` несёт ровно шесть исходных пар `(имя, функция)`, дословно те же имена/функции, что до
правки. Ни `check_drift_zero_docs`, ни `check_freshness_payments_technical`, ни
`check_freshness_commissionreportin_technical` в списке не встречаются:

```
$ grep -n "check_drift_zero_docs\|check_freshness_payments_technical\|check_freshness_commissionreportin_technical" reference/code/cf-dq/main.py
59:    # вовсе" уходит в отдельную диагностическую функцию check_drift_zero_docs
64:                       f"(документов не было — см. check_drift_zero_docs, notify)")
95:def check_drift_zero_docs(bq):
298:def check_freshness_payments_technical(bq):
332:def check_freshness_commissionreportin_technical(bq):
```

Все пять совпадений — определения функций и комментарии-ссылки; ни одно не лежит внутри списка
`CHECKS` (строки 178-185).

## 5. Приёмка (4) — ветка `ma7 == 0` не изменена (побайтовое сравнение)

```
$ git show HEAD:reference/code/cf-dq/main.py | sed -n '/if ma7 == 0:/,/threshold={threshold} ({day_label}), target_date={target_date}"/p' > /tmp/ma7_old.txt
$ sed -n '/if ma7 == 0:/,/threshold={threshold} ({day_label}), target_date={target_date}"/p' reference/code/cf-dq/main.py > /tmp/ma7_new.txt
$ diff /tmp/ma7_old.txt /tmp/ma7_new.txt && echo "IDENTICAL"
IDENTICAL
```

Блок от `if ma7 == 0:` до конца `check_drift` (различитель `core_ever_rows`, закрытие fail-open,
`ADR-122`) — побайтово идентичен коду, уже выложенному в прод (ревизия `cf-dq-00008-cev`,
`07_STATE.md:1639`). Строки в новом файле:

```
76:    if ma7 == 0:
82:        ever_had_data = run_scalar(bq, f"SELECT COUNT(*) FROM `{CORE_FACT}`") or 0
83:        if ever_had_data == 0:
86:        return False, (f"yesterday_rev={target_rev:.0f}, ma7=0, core_ever_rows={ever_had_data} "
90:    ratio = target_rev / float(ma7)
```

## 6. Приёмка (5) — старое/новое поведение `drift_check` на двух случаях

### Случай А: сутки без документов (`target_rev = 0`)

| | **Старая форма** (задеплоена, `cf-dq-00008-cev`) | **Новая форма** (этот патч, не задеплоена) |
|---|---|---|
| Путь | `target_rev=0` → `ma7` считается → `ratio = 0/ma7 = 0` → `0 < threshold` (и `0,10`, и `0,03`) | `target_rev=0` → блокирующий чек `check_drift` возвращает `True` СРАЗУ, до расчёта `ma7` |
| Исход | `passed=False` — **блокирует promote** | `passed=True` — **НЕ блокирует promote** |
| Diagnostика | нет отдельного канала — то же `passed=False`, что и для «данные испорчены» | `check_drift_zero_docs` (не подключена к `CHECKS`) готова доложить `yesterday_rev=0, ma7=…, target_date=…` тем же числом, всегда `passed=True` |

Это ровно дефект, зафиксированный `ADR-122 §4`/`reference/dq_gate_metric_redesign_2026-08-10.md
§1`: 8,9 % суток истории (40/451) не имеют документов вовсе и раньше блокировали promote как
аномалию. Патч убирает это конкретное срабатывание из блокирующего пути (`ADR-153 §1`).

### Случай Б: `2026-08-11` (`target_rev=111739`, `ma7=5097826`, `ratio=0,02`)

`2026-08-11` — вторник (`day_of_week` не в `(1,7)`), будний день, `threshold = DQ_DRIFT_THRESHOLD =
0,10` (`config.py`, не менялся).

| | **Старая форма** | **Новая форма** |
|---|---|---|
| Путь | `target_rev=111739 > 0` → `ma7=5097826 ≠ 0` → `ratio = 111739/5097826 ≈ 0,02` → `0,02 < 0,10` | `target_rev=111739 > 0` → ветка `if target_rev == 0` НЕ срабатывает → тот же расчёт `ma7`/`ratio`, тот же порог `0,10` |
| Исход | `passed=False` — блокирует promote | `passed=False` — **блокирует promote, БЕЗ ИЗМЕНЕНИЙ** |

Этот случай **обязан остаться блокирующим** — он принадлежит классу «документы есть, выручка
ниже нормы», который `ADR-153 §1` оставляет блокирующим дословно, и это принятое решение
(`reference/dq_gate_metric_redesign_2026-08-10.md §4`: «класс… остаётся блокирующим, потому что
именно там, по замеру, живёт необъяснённый остаток»), не дефект патча. Патч сужает блокирующий
путь, но не меняет его для этого конкретного класса входа.

---

## 7. Что этой сессией НЕ делалось (по контракту брифа, первый заход)

- `check_freshness_payments_technical`/`check_freshness_commissionreportin_technical` НЕ
  добавлены в `CHECKS` — подтверждено §4. (`check_drift_zero_docs` на момент первого захода тоже
  не была добавлена; подключена вторым заходом по ревью архитектора — см. §9.)
- Контракт агрегации `main()` (`reference/code/cf-dq/main.py:410-438`, номера строк после §9)
  не тронут ни первым, ни вторым заходом — дифф §3/§9 не касается этих строк.
- Текст уведомления и лог-метрика `msklad_dq_gate_failed` не правились (класс B, отдельная
  задача — вторая лог-метрика, `ADR-153 §Последствия`).
- Пороги `DQ_DRIFT_THRESHOLD`/`DQ_DRIFT_WEEKEND_THRESHOLD` (`0,10`/`0,03`) не менялись
  (`ADR-153 §4`).
- Ничего не задеплоено, живой `cf-dq` не вызывался ни разу (только `bq query --dry_run`,
  read-only, `--dry_run` ничего не читает и не пишет).
- `reference/code/cf-finance/`, `reference/code/cf-loss-commission/` не трогались (`ADR-155 §Последствия`,
  «без правок»); дефект построчного `_loaded_at` остаётся отдельной строкой
  `LOADER-LOADED-AT-STAMP` (`ADR-155 §4`, не заводится этой сессией).

---

## 9. Правка по ревью архитектора (2026-08-12, второй заход)

### 9.1 Дефект своими словами

Ранний возврат `if target_rev == 0: return True, …` (первый заход, §3, строки диффа `62-64`) стоял
ВЫШЕ ветки `ma7 == 0`. Ветка `ma7 == 0` — единственное место, различающее «легитимный первый запуск
проекта» от «промоут остановлен при непустой истории `core`» (`ADR-152`, закрытие fail-open). При
`target_rev == 0` функция возвращалась ДО этого различителя — то есть КАЖДЫЙ нулевой день, включая
день, где `core` имеет историю, а окно `T-8..T-2` пусто (реальный признак остановленного промоута),
после первого захода тихо получал `passed=True`. Это отменяло защиту `ADR-152` молча — ровно тот
класс ошибки, который `00_CHARTER §главный принцип` и `05_CONVENTIONS ★ anti-improvisation`
запрещают (тихое послабление гейта без явного правила).

### 9.2 Правка

Внутри ветки `target_rev == 0`, ДО возврата `True`, теперь выполняется тот же различитель: считается
`ma7` за то же окно `T-8..T-2`; если `ma7 == 0` И `COUNT(*)` по `core.fact_sales_profit` больше нуля
— функция возвращает `False` с тем же по смыслу detail, что и существующая ветка `ma7 == 0` ниже по
функции (`окно T-8..T-2 пусто при непустой истории core — вероятная остановка промоута, блокирую
вместо тихого пропуска`). Порядок остальных условий не менялся. Запрос дублирован сознательно (по
формулировке правки — «дублирование допустимо, в помощник выносить не обязательно»); обе точки
вызова (различитель внутри `target_rev == 0` и штатная ветка `ma7 == 0` для `target_rev > 0`) читают
одну и ту же пару запросов (`AVG` по `daily_rev` за `T-8..T-2`, `COUNT(*)` без окна) и дают
одинаковый исход на одинаковом входе.

Дополнительно — `check_drift_zero_docs` подключена в `CHECKS` отдельной строкой
`("drift_zero_docs", check_drift_zero_docs)`. Функция всегда возвращает `passed=True` — заблокировать
`all_passed` не может по построению (`main()` не тронут). Без подключения нулевой день (после
возможного будущего деплоя) не оставлял бы в `checks`/`audit.dq_runs` вообще никакой строки для
класса «документов не было» — тихий пропуск, запрещённый тем же принципом.

### 9.3 Приёмка (1) — `py_compile`

```
$ python3 -m py_compile reference/code/cf-dq/main.py reference/code/cf-dq/config.py && echo "PY_COMPILE_RC=0"
PY_COMPILE_RC=0
```

### 9.4 Приёмка (2) — `dry_run` запросов различителя

Скрипт с логом:
`reference/_scratch_DQ-GATE-METRIC-REDESIGN_2026-08-12/dry_run_drift_zero_docs_guard.sh` →
`.../dry_run_drift_zero_docs_guard.log`. `date -u`/`gcloud auth list` первой и последней командой.

```
=== date -u (start) ===
Wed Aug 12 17:14:17 UTC 2026
=== gcloud auth list (start) ===
     Credentialed Accounts
ACTIVE  ACCOUNT
*       ilyasbazarov4@gmail.com
=== dry_run: ma7 (T-8..T-2) — используется внутри target_rev==0 различителя ===
Query successfully validated. Assuming the tables are not modified, running this query will process upper bound of 6224 bytes of data.
=== dry_run: COUNT(*) core.fact_sales_profit — used как ever_had_data ===
Query successfully validated. Assuming the tables are not modified, running this query will process upper bound of 0 bytes of data.
=== gcloud auth list (end) ===
     Credentialed Accounts
ACTIVE  ACCOUNT
*       ilyasbazarov4@gmail.com
=== date -u (end) ===
Wed Aug 12 17:14:22 UTC 2026
```

Оба запроса, использованные внутри нового различителя, — те же текстовые формы, что уже несёт
существующая ветка `ma7 == 0` (не переизобретены), синтаксически валидны против живых схем,
авторизация не деградировала между началом и концом.

### 9.5 Приёмка (3) — дифф второго захода целиком, ровно один изменённый файл

```
$ git diff --stat -- reference/code/cf-dq/main.py reference/code/cf-dq/config.py
 reference/code/cf-dq/main.py | 36 +++++++++++++++++++++++++++++++-----
 1 file changed, 31 insertions(+), 5 deletions(-)
```

`config.py` вторым заходом не тронут (правка касалась только `check_drift`/`CHECKS` в `main.py`).
Полный текст диффа второго захода —
`reference/_scratch_DQ-GATE-METRIC-REDESIGN_2026-08-12/round2_diff.patch`, воспроизведён дословно:

```diff
diff --git a/reference/code/cf-dq/main.py b/reference/code/cf-dq/main.py
index e37d4e1..7771aa7 100644
--- a/reference/code/cf-dq/main.py
+++ b/reference/code/cf-dq/main.py
@@ -58,8 +58,29 @@ def check_drift(bq):
     # DQ-GATE-METRIC-REDESIGN (ADR-153, кандидат 1): исход "документов не было
     # вовсе" уходит в отдельную диагностическую функцию check_drift_zero_docs
     # (всегда passed=True, notify, не блокирует promote). Здесь, в блокирующем
-    # чеке, остаётся только класс "документы есть, выручка ниже нормы".
+    # чеке, остаётся только класс "документы есть, выручка ниже нормы" —
+    # НО ПЕРЕД возвратом обязан пройти тот же различитель ADR-152, что и
+    # ветка ma7 == 0 ниже (ревью архитектора, 2026-08-12): нулевой день сам по
+    # себе не отличим от остановленного промоута (пустое окно T-8..T-2 при
+    # непустой истории core), а этот путь возвращался бы раньше проверки и
+    # молча снимал бы защиту ADR-152 для КАЖДОГО нулевого дня. Дублирует
+    # запрос ma7/COUNT(*) ниже по функции — так и задумано (ревью §правка):
+    # обе точки вызова обязаны дать тот же исход по тому же входу.
     if target_rev == 0:
+        ma7_zero_check = run_scalar(bq, f"""
+            SELECT COALESCE(AVG(daily_rev),0) FROM (
+                SELECT transaction_date, SUM(revenue_kgs) AS daily_rev
+                FROM `{CORE_FACT}`
+                WHERE transaction_date >= DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 8 DAY)
+                  AND transaction_date  <  DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 1 DAY)
+                GROUP BY 1)
+        """) or 0.0
+        if ma7_zero_check == 0:
+            ever_had_data = run_scalar(bq, f"SELECT COUNT(*) FROM `{CORE_FACT}`") or 0
+            if ever_had_data > 0:
+                return False, (f"yesterday_rev=0, ma7=0, core_ever_rows={ever_had_data} "
+                                f"(окно T-8..T-2 пусто при непустой истории core — вероятная "
+                                f"остановка промоута, блокирую вместо тихого пропуска)")
         return True, (f"yesterday_rev=0, target_date={target_date} "
                        f"(документов не было — см. check_drift_zero_docs, notify)")
 
@@ -95,10 +116,14 @@ def check_drift(bq):
 def check_drift_zero_docs(bq):
     # DQ-GATE-METRIC-REDESIGN (ADR-153, кандидат 1): диагностика по исходу
     # "документов не было вовсе" (target_rev == 0). ВСЕГДА passed=True — не
-    # блокирует promote. Механизм "две функции" по образцу пары
-    # technical/business блока freshness ниже. НЕ подключена к CHECKS —
-    # доставка исхода в telegram-канал notify — отдельная задача класса B
-    # (вторая лог-метрика, ADR-153 §Последствия).
+    # блокирует promote, не может провалить CHECKS. Механизм "две функции" по
+    # образцу пары technical/business блока freshness ниже. Подключена к
+    # CHECKS отдельной строкой "drift_zero_docs" (ревью архитектора,
+    # 2026-08-12) — иначе нулевой день после выезда не оставлял бы вообще
+    # никакого следа (тихий пропуск, запрещён). В фильтр лог-метрики
+    # msklad_dq_gate_failed этот исход не попадает, поскольку passed всегда
+    # True; доставка в telegram-канал notify отдельным каналом — вне scope,
+    # отдельная задача класса B (вторая лог-метрика, ADR-153 §Последствия).
     row = run_row(bq, f"""
         WITH target_d AS (
             SELECT DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 1 DAY) AS d
@@ -178,6 +203,7 @@ def check_currency_normalization(bq):
 CHECKS = [
     ("not_empty",              check_not_empty),
     ("drift_check",            check_drift),
+    ("drift_zero_docs",        check_drift_zero_docs),
     ("fk_integrity",           check_fk_integrity),
     ("freshness",              check_freshness),
     ("margin_sanity",          check_margin_sanity),
     ("currency_normalization", check_currency_normalization),
```

Совокупный дифф ветки против `main` (все три захода, оба файла) —
`reference/_scratch_DQ-GATE-METRIC-REDESIGN_2026-08-12/full_diff.patch` (обновлён после §11,
затрагивает ровно `reference/code/cf-dq/main.py` + `reference/code/cf-dq/config.py`,
`git diff --stat`: `main.py | 176 …`, `config.py | 26 …`).

### 9.6 Приёмка (4) — `CHECKS` несёт `drift_zero_docs` строго один раз, состав проверен построчно

```
$ grep -n "^CHECKS = \[\|(\"not_empty\"\|(\"drift_check\"\|(\"drift_zero_docs\"\|(\"fk_integrity\"\|(\"freshness\"\|(\"margin_sanity\"\|(\"currency_normalization\"\|^\]" reference/code/cf-dq/main.py
203:CHECKS = [
204:    ("not_empty",              check_not_empty),
205:    ("drift_check",            check_drift),
206:    ("drift_zero_docs",        check_drift_zero_docs),
207:    ("fk_integrity",           check_fk_integrity),
208:    ("freshness",              check_freshness),
209:    ("margin_sanity",          check_margin_sanity),
210:    ("currency_normalization", check_currency_normalization),
211:]
```

Семь пар — шесть исходных плюс ровно одна новая (`drift_zero_docs`). Ни одна из четырёх функций
свежести (`check_freshness_payments_technical`/`_business`,
`check_freshness_commissionreportin_technical`/`_business`) в списке не встречается — их подключение
не входило ни в первый, ни во второй заход (отдельная задача класса B «`DQ-FRESHNESS-COVERAGE`,
деплой»).

### 9.7 Приёмка (5) — ветка `ma7 == 0` внутри `check_drift` по-прежнему дословно как в проде

```
$ git show main:reference/code/cf-dq/main.py | sed -n '/if ma7 == 0:/,/threshold={threshold} ({day_label}), target_date={target_date}"/p' > /tmp/ma7_orig.txt
$ sed -n '/if ma7 == 0:/,/threshold={threshold} ({day_label}), target_date={target_date}"/p' reference/code/cf-dq/main.py > /tmp/ma7_now.txt
$ diff /tmp/ma7_orig.txt /tmp/ma7_now.txt && echo "IDENTICAL"
IDENTICAL
```

Сравнение — против `main` (задеплоенная ревизия `cf-dq-00008-cev`), после ОБОИХ заходов. Новый
различитель внутри `target_rev == 0` — отдельный блок кода с собственным (не дословно совпадающим,
но эквивалентным по смыслу) текстом detail; штатная ветка `ma7 == 0`, обслуживающая класс
`target_rev > 0`, не редактировалась ни разу.

### 9.8 Таблица старое/новое поведение — третий случай (найден ревью)

**Случай В: нулевой день ПРИ пустом окне ядра (`ma7 == 0`) и непустой истории `core`**
(например, если бы `2026-08-02` — день из наблюдения `07_STATE.md:172`/`DQ-DRIFT-SOURCE-CORRECTION`
— пришёлся на день с `target_rev=0` при остановленном промоуте).

| | **Форма первого захода этой сессии (дефект ревью)** | **Форма после правки ревью (эта версия)** | **Задеплоенная форма (`cf-dq-00008-cev`, для сравнения)** |
|---|---|---|---|
| Путь | `target_rev=0` → ранний `return True` СРАЗУ, ветка `ma7==0`/`core_ever_rows` НЕ достигается | `target_rev=0` → считается `ma7` → `ma7==0` И `COUNT(*)>0` → `return False` ДО достижения диагностического `return True` | `target_rev=0` → `ma7` считается → `ratio=0/ma7=0` (или отдельно `ma7==0` даёт свой `return False`) → блокирует |
| Исход | `passed=True` — **тихо пропускает остановленный промоут** (регресс `ADR-152`) | `passed=False` — **блокирует, как и было в проде** | `passed=False` — блокирует |
| Оценка | ДЕФЕКТ (найден ревью, не задеплоен) | Соответствует принятому решению `ADR-153 §1`+`ADR-152` — форма патча защиту не снимает | эталон поведения для этого класса входа |

Случай подтверждает: патч после правки НЕ отменяет `ADR-152` ни для одного класса входа — защита
от «остановленный промоут выглядит как нулевой день» сохранена И для `target_rev==0`, И для
`target_rev>0` (штатная ветка `ma7==0` ниже, случай не рассматривался отдельно в §6, но не менялась
ни разу — см. §9.7).

Случаи А и Б из §6 (сутки без документов при НЕПУСТОМ окне `ma7`; `2026-08-11`) поведением второго
захода не затронуты — правка ревью адресует ТОЛЬКО пересечение `target_rev==0` И `ma7==0`, которое
в случае А не возникает (`ma7` в случае А по построению отличен от нуля, иначе он не был бы указан
как «сутки без документов» на фоне обычной торговли), и не пересекается со случаем Б
(`target_rev>0`).

## 10. Самодостаточность (первые два захода)

Документ содержит: приёмку `py_compile` первого и второго заходов (§1, §9.3); `dry_run` всех
изменённых/новых SQL с байтовыми оценками и рамкой `date -u`/`gcloud auth list` (§2, §9.4); дифф
целиком для каждого захода плюс совокупный дифф ветки против `main`, во всех случаях ровно два
файла (`main.py`+`config.py`) (§3, §9.5); грепы, подтверждающие точный состав `CHECKS` строками с
номерами (§4, §9.6); побайтовое сравнение ветки `ma7 == 0` внутри `check_drift` против прода,
подтверждённое после обоих заходов (§5, §9.7); таблицы старое/новое поведение на ТРЁХ случаях —
двух исходных (§6) плюс найденном ревью (§9.8); явный список НЕ сделанного (§7).

---

## 11. Правка по ревью архитектора (2026-08-12, третий заход) — `check_drift_zero_docs` под `try/except`

### 11.1 Дефект своими словами

`check_drift_zero_docs` объявлена «ВСЕГДА `passed=True`» (§9.2), но эта гарантия держалась только
на отсутствии исключения внутри тела функции. Общий цикл `main()` (`reference/code/cf-dq/main.py`,
`for name, fn in CHECKS: … try: passed, detail = fn(bq) except Exception as e: passed, detail =
False, f"EXCEPTION: {e}"`) перехватывает исключение ЛЮБОЙ проверки и превращает его в
`passed=False`, что роняет `all_passed`. Оба запроса `check_drift_zero_docs` (запрос `target_d`/
`target_rev` и запрос `ma7`) способны бросить исключение (испорченный ответ BigQuery, таймаут,
что угодно) — то есть до правки функция была НОВЫМ источником ложной блокировки гейта, ровно тем
классом дефекта, который сама задача (§9.1, `ADR-152`) устраняла в другом месте той же функции.

### 11.2 Правка

Оба запроса (и производная от них ветвление) обёрнуты в `try/except Exception as e`; `except`
возвращает `True, f"EXCEPTION (notify-only, не блокирует): {e}"`. `main()` и остальные пять
исходных проверок (`not_empty`/`drift_check`/`fk_integrity`/`freshness`/`margin_sanity`/
`currency_normalization`) НЕ трогались — контракт агрегации меняться не должен (`ADR-153 §2`:
форма «две функции» выбрана архитектором именно для того, чтобы `main()` остался прежним).
Правка целиком локальна внутри тела `check_drift_zero_docs`.

### 11.3 Приёмка (1) — `py_compile`

```
$ python3 -m py_compile reference/code/cf-dq/main.py reference/code/cf-dq/config.py && echo "PY_COMPILE_RC=0"
PY_COMPILE_RC=0
```

### 11.4 Приёмка (2) — дифф целиком, затронут ровно один файл

```
$ git diff --stat -- reference/code/cf-dq/main.py reference/code/cf-dq/config.py
 reference/code/cf-dq/main.py | 72 ++++++++++++++++++++++++++------------------
 1 file changed, 42 insertions(+), 30 deletions(-)
```

`config.py` третьим заходом не затронут (правка не касается порогов). Дифф третьего захода —
`reference/_scratch_DQ-GATE-METRIC-REDESIGN_2026-08-12/round3_diff.patch`, воспроизведён дословно:

```diff
diff --git a/reference/code/cf-dq/main.py b/reference/code/cf-dq/main.py
index 7771aa7..5c49b2d 100644
--- a/reference/code/cf-dq/main.py
+++ b/reference/code/cf-dq/main.py
@@ -124,37 +124,49 @@ def check_drift_zero_docs(bq):
     # msklad_dq_gate_failed этот исход не попадает, поскольку passed всегда
     # True; доставка в telegram-канал notify отдельным каналом — вне scope,
     # отдельная задача класса B (вторая лог-метрика, ADR-153 §Последствия).
-    row = run_row(bq, f"""
-        WITH target_d AS (
-            SELECT DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 1 DAY) AS d
-        )
-        SELECT
-            CAST(target_d.d AS STRING) AS target_date,
-            EXTRACT(DAYOFWEEK FROM target_d.d) AS day_of_week,
-            COALESCE(SUM(s.revenue_kgs), 0) AS target_rev
-        FROM target_d
-        LEFT JOIN `{STAGING}` s
-          ON DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek') = target_d.d
-        GROUP BY target_d.d
-    """)
-
-    if not row or row.get("target_date") is None:
-        return True, "target_date=NULL (notify-only, не блокирует)"
-
-    target_rev  = float(row.get("target_rev", 0) or 0)
-    target_date = row.get("target_date", "")
-
-    ma7 = run_scalar(bq, f"""
-        SELECT COALESCE(AVG(daily_rev),0) FROM (
-            SELECT transaction_date, SUM(revenue_kgs) AS daily_rev
-            FROM `{CORE_FACT}`
-            WHERE transaction_date >= DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 8 DAY)
-              AND transaction_date  <  DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 1 DAY)
-            GROUP BY 1)
-    """) or 0.0
+    #
+    # Правка ревью (2026-08-12, третий заход): main() перехватывает
+    # исключение любой проверки в CHECKS и превращает его в passed=False
+    # (reference/code/cf-dq/main.py, цикл for name, fn in CHECKS) — контракт
+    # агрегации МЕНЯТЬ НЕЛЬЗЯ (ADR-153 §2: форма "две функции" выбрана именно
+    # чтобы не трогать main()). Значит гарантия "ВСЕГДА passed=True" обязана
+    # держаться ВНУТРИ этой функции: оба запроса обёрнуты в try/except,
+    # любое исключение (испорченный ответ BQ, таймаут, что угодно) уходит в
+    # notify-detail, а не в блок гейта.
+    try:
+        row = run_row(bq, f"""
+            WITH target_d AS (
+                SELECT DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 1 DAY) AS d
+            )
+            SELECT
+                CAST(target_d.d AS STRING) AS target_date,
+                EXTRACT(DAYOFWEEK FROM target_d.d) AS day_of_week,
+                COALESCE(SUM(s.revenue_kgs), 0) AS target_rev
+            FROM target_d
+            LEFT JOIN `{STAGING}` s
+              ON DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek') = target_d.d
+            GROUP BY target_d.d
+        """)
+
+        if not row or row.get("target_date") is None:
+            return True, "target_date=NULL (notify-only, не блокирует)"
+
+        target_rev  = float(row.get("target_rev", 0) or 0)
+        target_date = row.get("target_date", "")
+
+        ma7 = run_scalar(bq, f"""
+            SELECT COALESCE(AVG(daily_rev),0) FROM (
+                SELECT transaction_date, SUM(revenue_kgs) AS daily_rev
+                FROM `{CORE_FACT}`
+                WHERE transaction_date >= DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 8 DAY)
+                  AND transaction_date  <  DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 1 DAY)
+                GROUP BY 1)
+        """) or 0.0
 
-    return True, (f"yesterday_rev={target_rev:.0f}, ma7={float(ma7):.0f}, target_date={target_date} "
-                   f"(notify, не блокирует promote)")
+        return True, (f"yesterday_rev={target_rev:.0f}, ma7={float(ma7):.0f}, target_date={target_date} "
+                       f"(notify, не блокирует promote)")
+    except Exception as e:
+        return True, f"EXCEPTION (notify-only, не блокирует): {e}"
 
 def check_fk_integrity(bq):
     orphans = run_scalar(bq, f"""
```

Запросы внутри `try` — те же текстовые формы, что уже дважды прошли `--dry_run` (§9.4); новых
SQL-конструкций правка не вносит (только `try:`/`except:` вокруг существующего тела), повторный
`dry_run` не требуется по приёмке этого захода.

### 11.5 Приёмка (3) — печать совпавших строк: ни один путь функции не возвращает `False`

```
$ sed -n '/^def check_drift_zero_docs/,/^def check_fk_integrity/p' reference/code/cf-dq/main.py | grep -n "return "
37:            return True, "target_date=NULL (notify-only, не блокирует)"
51:        return True, (f"yesterday_rev={target_rev:.0f}, ma7={float(ma7):.0f}, target_date={target_date} "
54:        return True, f"EXCEPTION (notify-only, не блокирует): {e}"
```

Все ТРИ `return` внутри тела функции (от объявления `def check_drift_zero_docs` до следующего
`def check_fk_integrity`) — `True`. Путей, возвращающих `False`, нет: ранний выход при
`target_date IS NULL`, штатный путь с числами, аварийный путь по исключению — все три ветки
несут константу `True`. Гарантия «ВСЕГДА `passed=True`» теперь верна структурно, а не только по
отсутствию ошибок при чтении.

### 11.6 Приёмка (4) — `main()` не тронут

```
$ git diff -- reference/code/cf-dq/main.py | grep -n "def main(request)"
$ echo "выдача пуста — main() не в диффе"
выдача пуста — main() не в диффе
```

Единственный хунк диффа третьего захода (`@@ -124,37 +124,49 @@ def check_drift_zero_docs(bq):`)
лежит целиком внутри тела `check_drift_zero_docs`; строка объявления `def main(request):`
(`reference/code/cf-dq/main.py:410`) в дифф не попала.

### 11.7 Что этой правкой НЕ делалось

- `main()` и цикл агрегации `for name, fn in CHECKS` не менялись — контракт (`ADR-153 §2`)
  сохранён дословно.
- Остальные пять исходных проверок и четыре функции свежести (`fact_payments`/
  `fact_commissionreportin`) не трогались.
- `config.py` не трогался.
- Текст SQL внутри `try` не менялся — те же запросы, что уже проверены `--dry_run` (§9.4).
- Ничего не задеплоено.

## 12. Самодостаточность (итог, все три захода)

Документ содержит: приёмку `py_compile` всех трёх заходов (§1, §9.3, §11.3); `dry_run` всех
SQL-запросов, введённых первым и вторым заходом, с байтовыми оценками (§2, §9.4) — третий заход
новых SQL-конструкций не вносит (§11.4); дифф каждого захода по отдельности плюс совокупный дифф
ветки против `main`, во всех разрезах ровно два файла (`main.py`+`config.py`) (§3, §9.5, §11.4);
грепы, подтверждающие точный состав `CHECKS` (§4, §9.6) и отсутствие `return False` внутри
`check_drift_zero_docs` (§11.5); подтверждение, что `main()` не в диффе третьего захода (§11.6);
побайтовое сравнение ветки `ma7 == 0` против прода (§5, §9.7); таблицы старое/новое поведение на
трёх случаях (§6, §9.8); списки НЕ сделанного по каждому заходу (§7, §11.7).
