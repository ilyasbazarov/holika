# SALES-PERIMETER-CADENCE — шаг 1 (переснятие живых объектов) + шаг 2 (патч снапшота)

**Дата:** 2026-08-07 · **Класс:** A (read-only + правка снапшота `reference/code/`, ничего не деплоит)
**Сессия:** `SALES-PERIMETER-CADENCE` · **Провенанс:** `reference/_scratch_SALES-PERIMETER-CADENCE_2026-08-07/step1_resnap.sh` + `step1_resnap.log`

## Шаг 1 — read-only переснятие живых объектов (обязателен по `07_GAPS.md` строке `SALES-PERIMETER-CADENCE`)

`gcloud auth list` в начале и в конце скрипта — тот же аккаунт (`ilyasbazarov4@gmail.com`), деградации нет.
`date -u` в начале и в конце — прогон `2026-08-07T13:03:55Z` … `2026-08-07T13:04:09Z`.

- **`gcloud scheduler jobs list --location=asia-east1`** — шесть джобов, все `ENABLED`:
  `msklad-pipeline-hourly` (`0 * * * *`, UTC) · `cf-inventory-trigger` (`0 21 * * *`, UTC) ·
  `invoices-daily-update` (`0 4 * * *`, Asia/Bishkek) · `loss-commission-daily-update`
  (`0 3 * * *`, Asia/Bishkek) · `finance-daily-update` (`0 3 * * *`, Asia/Bishkek) ·
  `msklad-pipeline-weekly` (`0 1 * * 0`, UTC). Ни один джоб не называет режимы
  `perimeter`/`perimeter_promote` явно (Cloud Scheduler джобы триггерят Workflows целиком,
  не отдельные шаги) — это ожидаемо, вопрос решается содержимым Workflow, не Scheduler.
  **Наблюдение вне scope этой задачи:** список джобов вырос до шести против пяти,
  зафиксированных `11_INFRA_FACTS.md:27` (снимок `2026-07-25T19:44:52Z`) — новый джоб
  `invoices-daily-update` не документирован в `11_INFRA_FACTS.md`. Правка `11_INFRA_FACTS.md`
  не входит в набор файлов на запись этой задачи (`07_STATE.md:1193`); наблюдение оставлено
  здесь как факт для следующей сессии, не как GAP-строка (задача read-only и не открывает
  новых объектов правки).
- **`gcloud workflows describe msklad-pipeline-weekly`** — ревизия `000004-6bf`,
  `updateTime=2026-08-05T05:17:59.298028382Z`. `sourceContents` живого воркфлоу против
  `reference/code/cf-facts/workflow_weekly.yaml` (снапшот ДО этой сессии) — побайтовое
  совпадение содержимого, единственное расхождение — конечный перевод строки, добавляемый
  `gcloud` при выгрузке (та же ловушка формы read-back, что описана `DQ-GATE-SCOPE-SPLIT-DEPLOY`,
  2026-08-05); содержательного расхождения нет.
- **Поиск подстроки `perimeter` в живом `sourceContents`:** **0 совпадений** — режимы
  `perimeter`/`perimeter_promote` не вызываются ни одним шагом `msklad-pipeline-weekly`.
- **`gcloud workflows describe msklad-pipeline-hourly`** — ревизия `000004-5fc`,
  `updateTime=2026-08-05T05:16:54.045332507Z`. Поиск `perimeter` в живом `sourceContents` —
  **0 совпадений**, как и ожидалось (периметр — недельный режим, `PERIMETER_WINDOW_DAYS = 90`
  по конструкции, часовая каденция не заводилась).

**Вывод шага 1:** каденция периметра продаж НЕ подключена ни в одном живом Workflow на момент
`2026-08-07T13:04Z`. Задача НЕ закрывается фактом — шаг 2 (патч снапшота) обязателен.

## Шаг 2 — патч снапшота `reference/code/cf-facts/workflow_weekly.yaml`

Добавлены два шага, позиция задана архитектурно (`07_GAPS.md`, задача `SALES-PERIMETER-CADENCE`),
не выбиралась этой сессией:

- **`step_perimeter`** (`mode: "perimeter"`, `window_days: 90`, `timeout: 600`) — вставлен
  ПОСЛЕ `step_facts` (сразу после `step_returns`, в блоке staging-шагов, вместе с
  `step_purchases`/`step_returns`) и ДО `step_dq`. Пишет только в
  `stg_msklad.fact_sales_perimeter_staging` — под гейт продаж не подпадает по тому же
  основанию, по которому туда вынесены закупки и возвраты (`DQ-GATE-SCOPE-SPLIT`, `ADR-122`).
  `timeout=600` — с запасом над измеренной длительностью реального прогона `368,9с`
  (`reference/code/cf-facts/MANIFEST.md` шаг 9а), сопоставимо с `step_facts` (тоже 90d rolling
  fetch, `timeout=600`).
- **`step_perimeter_promote`** (`mode: "perimeter_promote"`, `window_days: 90`, `timeout: 540`) —
  вставлен ПОСЛЕ `step_promote` (последний шаг перед `done`). Пишет в `core.fact_sales_profit` —
  ту самую таблицу, которую гейт защищает, поэтому не может стоять рядом со `step_perimeter`.
  `timeout=540` — по образцу `step_promote` (тот же класс операции — `MERGE` в `core`, тоже
  `window_days=90`).

Синтаксис YAML проверен (`python3 -c "import yaml; yaml.safe_load(...)"` — парсится без ошибок),
порядок шагов подтверждён программно: `... step_facts, step_purchases, step_returns,
step_perimeter, step_dq, ..., step_promote, step_perimeter_promote, done`.

## Что НЕ сделано этой сессией (класс B, за пределами мандата)

Шаг 3 (деплой `msklad-pipeline-weekly` с патчем) в мандат этой сессии не входит
(`07_STATE.md:1194` — отдельная строка класса B, мандат выдан вторым ADR блока
`SALES-PERIMETER-QUEUE-ADJ`). Патч лежит в снапшоте, не задеплоен; живой Workflow не изменён.
