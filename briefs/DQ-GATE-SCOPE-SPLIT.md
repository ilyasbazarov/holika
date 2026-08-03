# TASK BRIEF · DQ-GATE-SCOPE-SPLIT (подготовка)

**Класс задачи (ADR-076):** A — правка снапшота `reference/code/` и текста `workflow.yaml`
(hourly + weekly), ничего не деплоит. Строка мандата (`07_STATE.md` §Мандат Claude Code):
`DQ-GATE-SCOPE-SPLIT, подготовка | A | нет | постоянный`. Деплой (правка живых Cloud Workflows
и/или CF) — отдельная строка `DQ-GATE-SCOPE-SPLIT, деплой | B | нет | НЕ выдан`, этим брифом
не покрывается, дополнительно гейтится `ADR-065`.

**Параллель (ADR-082 §1):** нет (совпадает с колонкой «Параллель» таблицы мандата).

**Файлы на запись** (полный список; форма проверяется `tools/parallel_check.sh`):
- `reference/code/` — правка снапшота (текст патченных `workflow_hourly.yaml`/`workflow_weekly.yaml`
  внутри `reference/code/cf-facts/`), ничего не деплоит
- `reference/dq_gate_scope_split_2026-08-03.md` — артефакт задачи (самодостаточный, с провенансом)
- `reference/_scratch_DQ-GATE-SCOPE-SPLIT_2026-08-03/`
- `reference/_inbox/session_DQ-GATE-SCOPE-SPLIT_2026-08-03.md`

## Роль

Ты — исполнитель проекта. Законы — `CLAUDE.md`, стандарты — `05_CONVENTIONS.md` Части I и II.
Модель исполнения: ты исполняешь сам (`ADR-082 §2`). Ничего не деплоишь — ни `gcloud workflows
deploy`, ни `gcloud functions deploy`; живых `GET`/`gcloud`-команд к живым сервисам эта задача не
требует вовсе (все нужные факты уже сняты предыдущими сессиями и лежат в репо, см. «Входы»).
Работаешь в СВОЁМ рабочем дереве и коммитишь в СВОЮ ветку (`ADR-081 §6`). `07_STATE`,
`06_DECISIONS_LOG` и `06_INDEX` не правишь: session-блок кладёшь файлом в `reference/_inbox/`.

## Цель

Подготовить (текстом, без деплоя) исправленную версию `workflow_hourly.yaml` и
`workflow_weekly.yaml`, в которой провал DQ-чека по домену продаж (`drift_check` в `cf-dq`)
перестаёт останавливать загрузку закупок (`step_purchases`) и возвратов (`step_returns`) — двух
доменов, которые этим чеком не проверяются вовсе. Результат — патченный текст в снапшоте
`reference/code/cf-facts/` плюс артефакт с полным диффом, обоснованием и явным перечнем того, что
эта подготовка НЕ включает (деплой, новые DQ-чеки для закупок/возвратов).

## Context-to-load (обязательно прочитать перед работой)

- `_METHOD`, `00_CHARTER`, `05_CONVENTIONS`, `07_STATE` (всегда, читаются с диска по именам)
- `01_ARCHITECTURE.md` §DAG (порядок шагов hourly; `raise_*`-маппинг), §топология (роль `cf-dq`)
- `03_PIPELINE_SPEC.md` §DQ — 6 чеков `cf-dq`, домен `drift_check`/`freshness` (обе колонки —
  `STAGING`/`CORE_FACT` = `stg_msklad.fact_sales_staging`/`core.fact_sales_profit`, **только продажи**)
- `06_DECISIONS_LOG.md` точечно: `ADR-112` (эта строка заведена диагностикой периметра гейта),
  `ADR-113`/`DQ-DRIFT-SOURCE-CORRECTION` (источники величин чека, самоподдержание опровергнуто —
  не относится к предмету этой задачи напрямую, но объясняет, почему починка порога/логики
  `drift_check` — вне scope, см. ниже)
- `07_GAPS.md` точечно: `DQ-GATE-SCOPE-SPLIT`, `DQ-FRESHNESS-COVERAGE` (гейтится этой задачей)
- `reference/code/cf-dq/main.py` — все 6 чеков, видно, что ВСЕ читают только `stg_msklad.fact_sales_staging`
  / `core.fact_sales_profit` / `core.dim_products` (константы `STAGING`/`CORE_FACT`/`DIM_PRODUCT`
  в начале файла) — закупки/возвраты этим кодом не затрагиваются вообще
- `reference/code/cf-facts/main.py` — docstring + модовый диспетчер (`hourly`/`weekly`/`promote`/
  `purchases`/`returns`/`perimeter`/`perimeter_promote`); закупки и возвраты — независимые от
  `fact_sales_profit` пути записи (`ensure_fact_purchases`/`load_purchases`,
  `load_returns` из `bq_ops.py`, вызовы `fetch_purchase_positions`/`fetch_return_positions`)
- `reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02/step2_hourly_workflow.yaml` — **живой** текст
  `msklad-pipeline-hourly` (снят `gcloud workflows describe`, 2026-08-02); это и есть текущее
  состояние продакшена, а не черновик
- `reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02/step2_weekly_workflow.yaml` — то же для
  `msklad-pipeline-weekly`
- `reference/facts_workflow_stop_diag_2026-08-02.md` §5/§6 — наблюдённый факт (не гипотеза):
  `check_dq`/`raise_dq_failed` останавливает выполнение workflow ДО `step_promote`/`step_purchases`
  (hourly) и ДО `step_promote`/`step_purchases`/`step_returns` (weekly); при провале `drift_check`
  задание на загрузку `fact_returns` физически не порождается (не «падает», а не создаётся)
- `reference/facts_stop_diag_adj_2026-08-02.md` §1 — архитекторское подтверждение того же вывода
- `reference/infra_facts_sweep_2026-08-01.md` (раздел Q-13) — расхождение, которое НЕ примирять
  молча: комментарий внутри самого `sourceContents` weekly-workflow называет `step_purchases`/
  `step_returns` «non-blocking», но это верно только про ИХ СОБСТВЕННЫЕ ошибки (у них `except`
  логирует и не роняет workflow) — к их insert НЕ верно: `check_dq`/`raise_dq_failed` стоит РАНЬШЕ
  них в последовательности шагов и останавливает workflow целиком при провале, до того как
  `step_purchases`/`step_returns` вообще начнут выполняться. Комментарий описывает одно свойство
  (устойчивость к своей ошибке), а не другое (независимость от чужого гейта) — это и есть
  предметный дефект, а не переоткрытие уже закрытого вопроса.

## Входы — установлено, не переустанавливается

1. **DQ Gate (`cf-dq`) проверяет только домен продаж.** Все 6 чеков (`not_empty`, `drift_check`,
   `fk_integrity`, `freshness`, `margin_sanity`, `currency_normalization`) читают исключительно
   `stg_msklad.fact_sales_staging` / `core.fact_sales_profit` / `core.dim_products`
   (`reference/code/cf-dq/main.py:9-11`). Ни закупки, ни возвраты этими чеками не наблюдаются.
2. **Оба workflow ставят `check_dq`/`raise_dq_failed` ДО закупок/возвратов в последовательности
   шагов**, а не параллельно и не после них:
   - hourly (`step2_hourly_workflow.yaml`): `step_dim → step_fx → step_facts(hourly) → step_dq →
     parse_dq_result → check_dq → step_promote(window=7) → step_purchases(window=90)`.
   - weekly (`step2_weekly_workflow.yaml`): `step_dim → step_fx → step_facts(weekly) → step_dq →
     parse_dq_result → check_dq → step_promote(window=90) → step_purchases → step_returns(window=90)
     → done`.
3. **Наблюдённое (не гипотетическое) следствие:** авария 2026-08-01…08-03 (`drift_check` FAILED)
   остановила ОБА workflow целиком — закупки не грузились (hourly), возвраты не грузились (weekly)
   — при том что причина отказа (просадка выручки продаж) к этим двум доменам отношения не имеет.
   Провенанс — `reference/facts_workflow_stop_diag_2026-08-02.md` §5 (прямой BQ-запрос: заданий
   с целью `fact_returns` за сутки аварии — 0).
4. **`step_purchases`/`step_returns` не имеют зависимости по данным от `step_promote`/`step_dq`.**
   Это отдельные вызовы `cf-facts` с `mode="purchases"`/`mode="returns"`, читающие из МойСклад API
   (`entity/purchaseorder`/возвраты) и пишущие в `core.fact_purchases`/`core.fact_returns` —
   таблицы, не пересекающиеся со `stg_msklad.fact_sales_staging`/`core.fact_sales_profit`.
   Единственная реальная зависимость каждого шага workflow — от `step_dim`/`step_fx` (справочники и
   курс), которые стоят раньше и провалом DQ не затрагиваются.
5. **Что уже закрыто и не переоткрывается этой задачей:** гипотеза «самоподдерживающийся отказ»
   опровергнута (`ADR-113`); порог `drift_check` (`0,03` выходные / `0,10` будни) не пересматривается;
   само наличие/логика `drift_check` не меняется — меняется только МЕСТО закупок/возвратов в
   последовательности шагов workflow относительно этого чека.

## Шаги

1. Прочитать оба живых YAML (`step2_hourly_workflow.yaml`, `step2_weekly_workflow.yaml`) и
   подтвердить (сплошным чтением, не по памяти брифа) точный порядок шагов и имена
   `try`/`except`/`raise_*` блоков — это канон, от которого патч отсчитывается.
2. Спроектировать минимальный текстовый патч: `step_purchases` (оба workflow) и `step_returns`
   (weekly) перестают зависеть от исхода `check_dq` — то есть перестают стоять в последовательности
   ПОСЛЕ шага `check_dq`/`raise_dq_failed`. Сохранить для каждого шага его СОБСТВЕННУЮ
   `try`/`except`-обработку (закупки — `severity: WARNING`, не блокирует; возвраты в weekly сейчас
   `raise_purchases`/`raise_returns` при своей ошибке — этот выбор патчем не пересматривается,
   переносится как есть). Не трогать `step_dim`, `step_fx`, `step_facts`, `step_dq`,
   `parse_dq_result`, `check_dq`, `step_promote` — ни текст, ни порядок между ними.
3. Явно решить и записать в артефакт (это решение сессии, не архитектора — оно укладывается в
   объявленный мандат «правка текста workflow.yaml, ничего не деплоит»): либо (а) переставить
   закупки/возвраты РАНЬШЕ `step_dq` (сразу после `step_facts`), либо (б) вынести их в отдельную
   независимую ветку выполнения. Критерий выбора — минимальность диффа и сохранение семантики
   логирования/имён шагов из живого YAML. Если во время проектирования обнаружится зависимость,
   не названная во «Входах» (например, порядок важен для квоты/rate-limit МойСклад API, или
   `step_promote` меняет состояние, которое читает `step_purchases`) — это `CONTEXT GAP`, не
   домысливать, остановиться и назвать находку явно в артефакте.
4. Записать патченный текст ОБОИХ workflow в `reference/code/cf-facts/` (новые файлы snapshot'а:
   `workflow_hourly.yaml`, `workflow_weekly.yaml` — этих файлов в снапшоте раньше не было, только
   живые копии в scratch предыдущей сессии; текущий `reference/code/cf-facts/deploy_and_workflow.sh`
   — устаревший черновик с ДРУГИМ составом шагов, не редактировать его как часть этой задачи,
   расхождение только назвать).
5. Собрать `reference/dq_gate_scope_split_2026-08-03.md`: постановка (со ссылками на входы 1-4
   выше), выбор (а)/(б) с обоснованием, полный дифф (было → стало) для обоих workflow, явный список
   «что НЕ меняется» (сам `drift_check`, его порог, chek_dq для продаж, весь путь `step_promote`).
6. Не деплоить ничего. Не вызывать `gcloud workflows deploy`/`gcloud functions deploy`. Не делать
   живых `GET`/`gcloud describe` — вся фактура уже в репо (пункт «Входы»); если чего-то не хватает,
   это `CONTEXT GAP`, а не повод снимать факт заново живым вызовом.

## Критерии приёмки (Acceptance)

- Патченный текст обоих workflow лежит в `reference/code/cf-facts/`, дифф против живых копий
  (`reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02/step2_*_workflow.yaml`) показан построчно в
  артефакте.
- В патче `step_purchases`/`step_returns` достижимы НЕЗАВИСИМО от исхода `check_dq` (провал
  `drift_check` продолжает блокировать `step_promote`, но не блокирует закупки/возвраты).
- Ни один нетронутый шаг (`step_dim`, `step_fx`, `step_facts`, `step_dq`, `parse_dq_result`,
  `check_dq`, `step_promote`) не изменён текстуально ни на символ сверх переноса позиции соседних
  шагов.
- Артефакт `reference/dq_gate_scope_split_2026-08-03.md` самодостаточен: провенанс, дифф,
  обоснование выбора (а)/(б), явный список вне-scope пунктов.
- Ничего не задеплоено — ни один `gcloud … deploy`/`gcloud … update` не выполнялся (это проверяемо
  по отсутствию таких команд в логах сессии).

## Что вернуть человеку (Return-this)

- Патченные `reference/code/cf-facts/workflow_hourly.yaml` и `workflow_hourly.yaml`/`workflow_weekly.yaml`
  (текстом, для чтения).
- `reference/dq_gate_scope_split_2026-08-03.md`.
- Session-блок по `05_CONVENTIONS` Часть III, файлом в `reference/_inbox/`.

## Вне scope этой задачи

- Любой деплой (`DQ-GATE-SCOPE-SPLIT, деплой` — класс B, мандат не выдан, отдельная задача).
- Правка логики/порога `drift_check` или любого из 6 чеков `cf-dq`.
- Добавление новых DQ-чеков для закупок/возвратов (это `DQ-FRESHNESS-COVERAGE`, которая ГЕЙТИТСЯ
  этой задачей, а не наоборот — не выполнять её попутно).
- Починка `msklad-dq-gate-failed` алерта (`DQ-ALERT-FILTER-FIX`, отдельная строка).
- Правка устаревшего `reference/code/cf-facts/deploy_and_workflow.sh` (расхождение только назвать).
- Живые `gcloud`/`GET`-вызовы любого рода.

## В конце сессии

Выдай SESSION-блок по формату `05_CONVENTIONS` Часть III
(`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`), файлом в
`reference/_inbox/session_DQ-GATE-SCOPE-SPLIT_2026-08-03.md`.
