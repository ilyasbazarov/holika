# FILE: dq_cfdq_prep_2026-08-12.md

# Подготовка ОБЕИХ правок cf-dq одним заходом — `DQ-GATE-METRIC-REDESIGN` (ход 1) + `DQ-FRESHNESS-COVERAGE`, остаток (ход 2)

**Дата:** 2026-08-12 (Бишкек) · **Класс задачи:** A — подготовка патча, ничего не деплоит и не
подключает к живому гейту.
**Дерево/ветка:** `worktrees/DQ-GATE-METRIC-REDESIGN` / `s/DQ-GATE-METRIC-REDESIGN`
**Основание запуска без брифа (`ADR-086 §1`):** класс A; приёмка процитирована дословно из
`07_STATE.md` (`ADR-153`/`ADR-155`, строки `§Открытые вопросы`); полный набор файлов на запись
объявлен в тексте запуска (ровно два плюс артефакт); определение задачи процитировано, не
пересказано.

**Назначение файла.** Самодостаточный артефакт приёмки для обоих ходов: печать
`py_compile`, дифф целиком (2 файла), `dry_run` двух новых SQL, грепы, подтверждающие
неподключение к `CHECKS` и дословную сохранность ветки `ma7 == 0`, и таблица
старое/новое поведение `drift_check` на двух заданных случаях.

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

## 7. Что этой сессией НЕ делалось (по контракту брифа)

- Новые функции (`check_drift_zero_docs`, `check_freshness_payments_technical`,
  `check_freshness_commissionreportin_technical`) НЕ добавлены в `CHECKS` — подтверждено §4.
- Контракт агрегации `main()` (`reference/code/cf-dq/main.py:384-413`) не тронут — дифф §3 не
  касается этих строк.
- Текст уведомления и лог-метрика `msklad_dq_gate_failed` не правились (класс B, отдельная
  задача — вторая лог-метрика, `ADR-153 §Последствия`).
- Пороги `DQ_DRIFT_THRESHOLD`/`DQ_DRIFT_WEEKEND_THRESHOLD` (`0,10`/`0,03`) не менялись
  (`ADR-153 §4`).
- Ничего не задеплоено, живой `cf-dq` не вызывался ни разу (только `bq query --dry_run`,
  read-only, `--dry_run` ничего не читает и не пишет).
- `reference/code/cf-finance/`, `reference/code/cf-loss-commission/` не трогались (`ADR-155 §Последствия`,
  «без правок»); дефект построчного `_loaded_at` остаётся отдельной строкой
  `LOADER-LOADED-AT-STAMP` (`ADR-155 §4`, не заводится этой сессией).

## 8. Самодостаточность

Документ содержит: приёмку `py_compile` (§1); `dry_run` двух новых SQL с байтовыми оценками и
рамкой `date -u`/`gcloud auth list` (§2); дифф целиком, ровно два файла (§3); грепы,
подтверждающие неподключение к `CHECKS` строками с номерами (§4); побайтовое сравнение ветки
`ma7 == 0` до/после (§5); таблицы старое/новое поведение на двух заданных случаях (§6); явный
список НЕ сделанного (§7).
