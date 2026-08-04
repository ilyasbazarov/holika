# DQ-GATE-SCOPE-SPLIT (подготовка) — патч периметра DQ Gate для закупок/возвратов

**Дата подготовки текста:** 2026-08-04 (сессия исполнена 2026-08-04; имя файла и бриф датированы
2026-08-03 генератором — расхождение только называется, filename не переименовывается, см.
«Файлы на запись» брифа `briefs/DQ-GATE-SCOPE-SPLIT.md`).
**Класс задачи:** A — правка снапшота `reference/code/` и текста `workflow.yaml`, ничего не деплоит.
**Провенанс постановки:** `ADR-112 §5` (заводит `DQ-GATE-SCOPE-SPLIT`), бриф `briefs/DQ-GATE-SCOPE-SPLIT.md`.

---

## 1. Постановка

DQ Gate (`cf-dq`) проверяет ТОЛЬКО домен продаж. Все 6 чеков читают исключительно
`stg_msklad.fact_sales_staging` / `core.fact_sales_profit` / `core.dim_products`
(`reference/code/cf-dq/main.py:9-11`, подтверждено сплошным чтением файла этой сессией — константы
`STAGING`/`CORE_FACT`/`DIM_PRODUCT` используются во всех шести функциях `CHECKS`). Закупки и возвраты
этими чеками не наблюдаются вообще.

Оба живых workflow (`reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02/step2_hourly_workflow.yaml`,
`.../step2_weekly_workflow.yaml`) ставят `check_dq`/`raise_dq_failed` ДО закупок/возвратов в
последовательности шагов:
- hourly: `step_dim → step_fx → step_facts(hourly) → step_dq → parse_dq_result → check_dq →
  step_promote(window=7) → step_purchases(window=90) → done`.
- weekly: `step_dim → step_fx → step_facts(weekly) → step_dq → parse_dq_result → check_dq →
  step_promote(window=90) → step_purchases → step_returns(window=90) → done`.

Наблюдённое (не гипотетическое) следствие — `reference/facts_workflow_stop_diag_2026-08-02.md`
§5/§6: провал `drift_check` останавливает ОБА workflow целиком. Часовой простаивал минимум с
`2026-08-01T17:00Z…18:00Z`, недельный — минимум с `2026-07-26T01:00Z` (два пропущенных воскресенья на
момент замера `2026-08-02T13:49:47Z`). За сутки аварии `2026-08-01…08-02` заданий с целью
`fact_returns` — 0 (прямой BQ-запрос, `§5`). `step_purchases`/`step_returns` не порождаются, а не
падают с ошибкой — задание физически не создаётся.

Комментарий внутри `sourceContents` weekly-workflow называет `step_purchases`/`step_returns`
«non-blocking» — это верно только про ИХ СОБСТВЕННЫЕ ошибки (свой `except`, не роняет workflow), но
НЕ верно про их достижимость: `check_dq`/`raise_dq_failed` стоит раньше них и останавливает workflow
целиком до того, как они вообще начнут исполняться
(`reference/infra_facts_sweep_2026-08-01.md` Q-13, строки 103-105). Это предметный дефект периметра
гейта, а не переоткрытие уже закрытого вопроса о самоподдерживающемся отказе (`ADR-113`).

## 2. Выбор формы патча — вариант (а): переставить раньше `step_dq`

**Решение:** `step_purchases` (оба workflow) и `step_returns` (weekly) переносятся в
последовательности шагов на позицию СРАЗУ ПОСЛЕ `step_facts`, ПЕРЕД `step_dq`. Никакой другой текст
не редактируется — чистая релокация блока шага (cut-paste), 0 байт правки внутри самого блока
(в hourly) либо только позиционная релокация с сохранением исходных inline-комментариев (в weekly,
см. §5 «Что не меняется»).

**Почему (а), не (б) (независимая ветвь `parallel:`):**
- Критерий брифа — минимальность диффа и сохранение семантики логирования/имён шагов живого YAML.
- Вариант (б) требует ввести новую конструкцию Google Cloud Workflows (`parallel: branches:` либо
  `for`/`call: sys.log` внутри отдельной ветки), которой в живом YAML сейчас нет вообще — это не
  правка существующего текста, а добавление новой формы шага, то есть дифф ШИРЕ и семантика (что
  значит «шаг» в этом workflow) меняется для читателя.
- Вариант (а) — чистая перестановка позиции в линейном списке `steps:` (Google Cloud Workflows
  исполняет шаги последовательно в порядке списка, если явного `next`/`switch`-перехода нет; переходов
  на `step_purchases`/`step_returns` по имени нигде в файле нет — проверено сплошным чтением обоих
  YAML этой сессией). Переставить строки в списке — значит изменить порядок исполнения, не добавляя
  новых языковых конструкций.
- Обе формы одинаково достигают цели (недостижимость `step_purchases`/`step_returns` от исхода
  `check_dq`), поэтому применяется критерий минимальности → выбрана (а).

**Проверка на незаявленную зависимость (шаг 3 брифа, обязательный).** Проверено сплошным чтением
обоих живых YAML и `reference/code/cf-facts/main.py`:
- `step_purchases`/`step_returns` не читают `facts_result`/`promote_result`/`dq_result`/`dq_parsed` —
  их HTTP-тело содержит только `run_id`, `mode`, `window_days` (константы/переменные из `init`).
  Данных, произведённых `step_facts`/`step_dq`/`step_promote`, они не потребляют.
- Единственная переменная, от которой они технически зависят — `run_id` (из `init`) и `cf_facts`
  (URL, из `init`) — обе уже присутствуют на позиции ПЕРЕД `step_facts`, перестановка их не трогает.
- Rate-limit/квота МойСклад API: ни в одном из прочитанных источников (`reference/code/cf-facts/*.py`,
  `03_PIPELINE_SPEC.md §режимы cf-facts`, `01_ARCHITECTURE.md`) не найдено утверждения, что порядок
  вызовов `cf-facts` в РАМКАХ ОДНОГО workflow-прогона важен для квоты — каждый шаг есть отдельный HTTP
  POST к отдельно масштабируемой Cloud Function, вызовы не параллельны и не пакетны. `CONTEXT GAP` не
  найден.
- `step_promote` не меняет состояние, которое читает `step_purchases`/`step_returns`: `step_promote`
  пишет в `core.fact_sales_profit` (домен продаж), `step_purchases`/`step_returns` пишут в
  `core.fact_purchases`/`core.fact_returns` — разные таблицы (Вход 4 брифа, подтверждено чтением
  `bq_ops.py` в рамках этой сессии не производилось повторно — факт уже установлен предыдущей
  диагностикой `reference/facts_workflow_stop_diag_2026-08-02.md`, здесь не переоткрывается).

Незаявленных зависимостей не найдено. `CONTEXT GAP` не заводится.

## 3. Дифф — hourly (`workflow_hourly.yaml` против живого `step2_hourly_workflow.yaml`)

Форма: unified diff, `reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02/step2_hourly_workflow.yaml`
(живая копия) → `reference/code/cf-facts/workflow_hourly.yaml` (патч этой сессии).

```diff
--- живой (step2_hourly_workflow.yaml)
+++ патч (workflow_hourly.yaml)
@@ -72,6 +72,27 @@
                   severity: ERROR
             - raise_facts:
                 raise: ${e}
+    - step_purchases:
+        try:
+          call: http.post
+          args:
+            url: ${cf_facts}
+            auth:
+              type: OIDC
+            body:
+              run_id: ${run_id}
+              mode: "purchases"
+              window_days: 90
+            timeout: 300
+          result: purchases_result
+        except:
+          as: e
+          steps:
+            - log_purchases_warning:
+                call: sys.log
+                args:
+                  text: ${"[HOURLY] step_purchases FAILED (non-blocking) run_id=" + run_id + " error=" + json.encode_to_string(e)}
+                  severity: WARNING
     - step_dq:
         try:
           call: http.post
@@ -130,27 +151,6 @@
                   severity: ERROR
             - raise_promote:
                 raise: ${e}
-    - step_purchases:
-        try:
-          call: http.post
-          args:
-            url: ${cf_facts}
-            auth:
-              type: OIDC
-            body:
-              run_id: ${run_id}
-              mode: "purchases"
-              window_days: 90
-            timeout: 300
-          result: purchases_result
-        except:
-          as: e
-          steps:
-            - log_purchases_warning:
-                call: sys.log
-                args:
-                  text: ${"[HOURLY] step_purchases FAILED (non-blocking) run_id=" + run_id + " error=" + json.encode_to_string(e)}
-                  severity: WARNING
     - done:
         steps:
           - log_success:
```

**Итог для hourly:** блок `step_purchases` вырезан из позиции между `step_promote` и `done`,
вставлен дословно (побайтово, без единой правки) между `step_facts` и `step_dq`. Новый порядок:
`init → step_dim → step_fx → step_facts → step_purchases → step_dq → parse_dq_result → check_dq →
step_promote → done`.

## 4. Дифф — weekly (`workflow_weekly.yaml` против живого `step2_weekly_workflow.yaml`)

```diff
--- живой (step2_weekly_workflow.yaml)
+++ патч (workflow_weekly.yaml)
@@ -81,6 +81,59 @@
             - raise_facts:
                 raise: ${e}
 
+    # ── STEP 8: закупки — полный refresh ──────────────────────────────────────
+    # WRITE_TRUNCATE: ~173 заказа × ~30 позиций. Статусы (В пути / Прибыл)
+    # захватываются на каждом прогоне. Не блокирует promote при ошибке.
+    - step_purchases:
+        try:
+          call: http.post
+          args:
+            url: ${cf_facts}
+            auth:
+              type: OIDC
+            body:
+              run_id: ${run_id}
+              mode: "purchases"
+            timeout: 300
+          result: purchases_result
+        except:
+          as: e
+          steps:
+            - log_purchases_error:
+                call: sys.log
+                args:
+                  text: ${"[WEEKLY] step_purchases FAILED run_id=" + run_id + " error=" + json.encode_to_string(e)}
+                  severity: ERROR
+            - raise_purchases:
+                raise: ${e}
+
+    # ── STEP 9: возвраты покупателей (90d rolling) ────────────────────────────
+    # После promote — независимая таблица, вне DQ-цепочки продаж.
+    # 0 записей за окно — не ошибка (early return guard в CF-Facts).
+    - step_returns:
+        try:
+          call: http.post
+          args:
+            url: ${cf_facts}
+            auth:
+              type: OIDC
+            body:
+              run_id: ${run_id}
+              mode: "returns"
+              window_days: 90
+            timeout: 300
+          result: returns_result
+        except:
+          as: e
+          steps:
+            - log_returns_error:
+                call: sys.log
+                args:
+                  text: ${"[WEEKLY] step_returns FAILED run_id=" + run_id + " error=" + json.encode_to_string(e)}
+                  severity: ERROR
+            - raise_returns:
+                raise: ${e}
+
     # ── STEP 4: DQ Gate ───────────────────────────────────────────────────────
     - step_dq:
         try:
@@ -147,59 +200,6 @@
             - raise_promote:
                 raise: ${e}
 
-    # ── STEP 8: закупки — полный refresh ──────────────────────────────────────
-    # WRITE_TRUNCATE: ~173 заказа × ~30 позиций. Статусы (В пути / Прибыл)
-    # захватываются на каждом прогоне. Не блокирует promote при ошибке.
-    - step_purchases:
-        try:
-          call: http.post
-          args:
-            url: ${cf_facts}
-            auth:
-              type: OIDC
-            body:
-              run_id: ${run_id}
-              mode: "purchases"
-            timeout: 300
-          result: purchases_result
-        except:
-          as: e
-          steps:
-            - log_purchases_error:
-                call: sys.log
-                args:
-                  text: ${"[WEEKLY] step_purchases FAILED run_id=" + run_id + " error=" + json.encode_to_string(e)}
-                  severity: ERROR
-            - raise_purchases:
-                raise: ${e}
-
-    # ── STEP 9: возвраты покупателей (90d rolling) ────────────────────────────
-    # После promote — независимая таблица, вне DQ-цепочки продаж.
-    # 0 записей за окно — не ошибка (early return guard в CF-Facts).
-    - step_returns:
-        try:
-          call: http.post
-          args:
-            url: ${cf_facts}
-            auth:
-              type: OIDC
-            body:
-              run_id: ${run_id}
-              mode: "returns"
-              window_days: 90
-            timeout: 300
-          result: returns_result
-        except:
-          as: e
-          steps:
-            - log_returns_error:
-                call: sys.log
-                args:
-                  text: ${"[WEEKLY] step_returns FAILED run_id=" + run_id + " error=" + json.encode_to_string(e)}
-                  severity: ERROR
-            - raise_returns:
-                raise: ${e}
-
     # ── DONE ──────────────────────────────────────────────────────────────────
     - done:
         steps:
@@ -209,4 +209,4 @@
                 text: ${"[WEEKLY] Pipeline COMPLETED run_id=" + run_id}
                 severity: INFO
           - return_result:
-              return: ${promote_result.body}
+              return: ${promote_result.body}
```

(Последняя строка живого файла не оканчивается переводом строки — `\ No newline at end of file`
у живой копии; патч оканчивается переводом строки. Это байтовое отличие вне scope смысловой правки —
называется, не примиряется тихо.)

**Итог для weekly:** блоки `step_purchases`+`step_returns` (вместе с их исходными inline-комментариями
`# ── STEP 8 …`/`# ── STEP 9 …`) вырезаны из позиции между `step_promote` и `done`, вставлены дословно
между `step_facts` и `# ── STEP 4: DQ Gate` (комментарий `step_dq`). Новый порядок: `init → step_dim →
step_fx → step_facts → step_purchases → step_returns → step_dq → parse_dq_result → check_dq →
step_promote → done`.

**Побочный эффект переноса, названный явно (не примиряется тихо).** Инлайн-комментарии
`# ── STEP 8 …`/`# ── STEP 9 …` перенесены дословно вместе со своими шагами и теперь физически стоят
ПЕРЕД `# ── STEP 4: DQ Gate` — числовая нумерация комментариев (`STEP 8`/`STEP 9` до `STEP 4`) больше
не отражает физический порядок исполнения. Комментарий `step_returns`, «После promote — независимая
таблица, вне DQ-цепочки продаж», после патча физически неточен (`step_returns` теперь ДО `step_promote`,
а не после) — по смыслу утверждение «независимая таблица, вне DQ-цепочки продаж» остаётся верным и
даже усилено патчем (это и есть цель задачи), но фраза «После promote» больше не описывает позицию.
Текст комментариев не редактировался умышленно: шаг 2 брифа требует перенос позиции без правки текста
шагов; переписывание комментария было бы правкой текста сверх позиции. Если это расхождение
нежелательно, правка текста комментариев (не смысла) — предмет отдельного минимального патча,
владелец решает.

## 5. Что НЕ меняется (полный список)

- Сам `drift_check` (логика, порог `0,10` будни / `0,03` выходные) — не тронут, ни строки.
- `check_dq` для продаж — исполняется так же, останавливает workflow целиком при провале, как и
  раньше; изменилось только то, ЧТО физически стоит после него в списке (`step_promote` вместо
  `step_promote` + `step_purchases`/`step_returns`).
- Весь путь `step_promote` — не тронут, ни строки, ни позиции относительно `step_dq`/`check_dq`.
- `step_dim`, `step_fx`, `step_facts`, `parse_dq_result` — не тронуты, ни символа, ни позиции друг
  относительно друга.
- Собственная `try`/`except`-обработка каждого перенесённого шага сохранена ДОСЛОВНО: закупки
  (`severity: WARNING` в hourly, не блокирует; `raise_purchases` в weekly, блокирует СВОЙ шаг) и
  возвраты (`raise_returns` в weekly, блокирует СВОЙ шаг) — этот выбор патчем не пересматривается.
- `reference/code/cf-facts/deploy_and_workflow.sh` — не редактировался. Расхождение называется явно:
  файл несёт ДРУГОЙ состав шагов (устаревший черновик), не совпадающий ни с живым YAML, ни с этим
  патчем; правка вне scope этой задачи (см. бриф, «Вне scope этой задачи»).
- Ни один `gcloud workflows deploy`/`gcloud functions deploy`/`gcloud … update` не вызывался в этой
  сессии — патч существует только текстом в `reference/code/cf-facts/`.

## 6. Что эта подготовка НЕ включает (вне scope, явно)

- **Деплой.** `DQ-GATE-SCOPE-SPLIT, деплой` — класс B, мандат НЕ выдан (`ADR-076`), отдельная строка
  мандата, гейтится `ADR-065` (деплой CF/Workflows только из код-репо). Этот патч — снапшот-текст,
  готовый к переносу в код-репо ПОСЛЕ выдачи мандата и решения владельца о процедуре.
- **Правка логики/порога `drift_check` или любого из 6 чеков `cf-dq`.** Не рассматривалась, не
  предлагается.
- **Новые DQ-чеки для закупок/возвратов.** Это `DQ-FRESHNESS-COVERAGE` (`ADR-115`, гейтится ЭТОЙ
  задачей, не наоборот) — не выполнялась попутно.
- **Починка `msklad-dq-gate-failed` алерта.** Это `DQ-ALERT-FILTER-FIX`, отдельная строка мандата.
- **Правка `deploy_and_workflow.sh`.** Расхождение состава шагов только названо (§5 выше).
- **Живые `gcloud`/`GET`-вызовы.** Не выполнялись — вся фактура уже была в репо (см. §1, провенанс).

## 7. Приёмка (самопроверка по критериям брифа)

- Патченный текст обоих workflow лежит в `reference/code/cf-facts/workflow_hourly.yaml` /
  `workflow_weekly.yaml` — ✅, файлы этой сессией созданы (в снапшоте их раньше не было).
- Дифф против живых копий показан построчно (§3, §4) — ✅.
- `step_purchases`/`step_returns` достижимы независимо от исхода `check_dq`; `step_promote`
  по-прежнему блокируется провалом `drift_check` — ✅ по построению нового порядка шагов (§3, §4).
- Ни один нетронутый шаг (`step_dim`, `step_fx`, `step_facts`, `step_dq`, `parse_dq_result`,
  `check_dq`, `step_promote`) не изменён текстуально сверх переноса позиции соседних шагов — ✅,
  подтверждено самим диффом (§3, §4): единственные добавленные/удалённые ханки — блоки
  `step_purchases`/`step_returns`.
- Ничего не задеплоено — ✅, в сессии не исполнялась ни одна команда `gcloud`.
