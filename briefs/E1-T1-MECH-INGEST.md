# TASK BRIEF · E1-T1-MECH-INGEST

> Сгенерирован по `_GENERATOR.md` @ SHA `cb5c6167a7e8bd992e524234a5f13372ab794786`.
> Управляющее решение: **ADR-024 accepted** (Q-31, сессия RQ-6-E1T1-ADJ, 2026-07-22). Тип: прод-артефакт (не discovery).
> **Пин-нота:** raw-URL ниже пиннены на `cb5c616`. При старте рабочего чата человек прикладывает СВЕЖИЙ SHA —
> перечитывай по нему (правило доступа `_GENERATOR`/`_ARCHITECT §3`), а не по `cb5c616`.

## Роль
Ты — разработчик проекта. Сначала прочитай `_METHOD` + `05_CONVENTIONS` (правила агента), затем действуй.
Модель исполнения: ты ПИШЕШЬ код/артефакты, человек ЗАПУСКАЕТ и возвращает логи. Ты не исполняешь сам.
Два пункта дизайна (§schema, §имя CF) — owner-гейтные: ты ПРЕДЛАГАЕШЬ, человек/архитектор РАТИФИЦИРУЕТ до деплой-кода.

## Цель
Поднять **новый независимый ингест** (отдельная CF/механизм, НЕ расширение `cf-finance` — ADR-024 §1) двух
источников МойСклад `entity/loss` и `entity/commissionreportin` в две новые core-таблицы
`core.fact_loss` и `core.fact_commissionreportin`, реализующие конвертацию валют по ADR-010 (`sum_kgs =
minor_units ÷ 100 × rate.value`) **корректно с первого дня** (не fix-forward, ADR-024 §2). Эти таблицы затем
читает существующий `sq_marts_expenses` через SQL-дельту (E1-T1-MECH — отдельная задача). Данные мая-2026,
загруженные новым ингестом, обязаны сойтись с loss/commission-компонентами оракула `pnl_2026-05` до копейки.

## Context-to-load (обязательно прочитать перед работой; при отсутствии любого → `CONTEXT GAP`, стоп)
Всегда:
- `_METHOD` — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/_METHOD.md
- `00_CHARTER` — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/00_CHARTER.md
- `05_CONVENTIONS` — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/05_CONVENTIONS.md
- `07_STATE` — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/07_STATE.md

Под задачу:
- `02_ERP_CONTRACTS` (§семантика П&Л/ADR-006, §Источник #2 `commissionreportin`, §валюты, §поведение API, §справочные-данные UUID, §оракул) — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/02_ERP_CONTRACTS.md
- `03_PIPELINE_SPEC` (§режимы cf-facts — паттерн `staging→MERGE`; §cf-finance; §fact_payments — инвариант Ghost Records; §DQ) — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/03_PIPELINE_SPEC.md
- `06_DECISIONS_LOG` (ADR-024, ADR-006, ADR-010, ADR-011, ADR-016, ADR-022, ADR-012, ADR-014) — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/06_DECISIONS_LOG.md
- `09_GLOSSARY` (§конвертация валют вх/исх) — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/09_GLOSSARY.md
- `11_INFRA_FACTS` (§CF — конфиг/секреты/ревизии; §SQ) — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/11_INFRA_FACTS.md

Эталон/диагностика:
- `/reference/pnl_2026-05.md` (оракул, seed #2) — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/reference/pnl_2026-05.md
- `/reference/recon_expenses_2026-05.md` (построчные Δ + NAME_CASE-варианты) — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/reference/recon_expenses_2026-05.md
- `/reference/design_sq_marts_expenses_E1-T1-MECH.md` (Часть A — ингест, Часть B — SQL-дельта) — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/reference/design_sq_marts_expenses_E1-T1-MECH.md
- `/reference/expense_articles_client.md` (27 статей verbatim, фильтр по имени, регистр критичен) — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/reference/expense_articles_client.md
- `/reference/code/cf-finance/MANIFEST.md` (прецедент снапшот-провенанса, ADR-017 §2) — https://raw.githubusercontent.com/ilyasbazarov/holika/cb5c6167a7e8bd992e524234a5f13372ab794786/reference/code/cf-finance/MANIFEST.md

## Входы (существуют / доступны)
- **Реальные датасеты проекта:** `audit`, `core`, `marts`, `stg_msklad` (других нет). **`raw.moysklad_loss` /
  `raw.moysklad_commissionreportin` не существуют нигде** — grounded Q-31 (recon §Провенанс). Обе core-таблицы
  создаются этой задачей с нуля.
- **`core.fact_payments`** — несёт `paymentout`/`cashout`; **НЕ трогается** этой задачей. Она — `base`-часть
  SQL-дельты (E1-T1-MECH), несёт баг ADR-016 до `E1-T3-MECH-FX`.
- **МойСклад API:** эндпоинты `entity/loss`, `entity/commissionreportin` (поведение API — `02 §поведение API`:
  `expand`, `limit≤100`, sleep 0.25 на 429, timeout 90).
- **Секрет токена МойСклад** — по паттерну `11 §секреты`/`cf-finance`. ⚠ Учти Q-28 (`Regional Access Boundary`
  на `gcloud secrets versions access` в не-интерактивном/SA-прогоне — задокументирован в `11 §IAM`).
- **Оракул-компоненты (loss/commission), май-2026** — из `recon_expenses_2026-05.md`:
  «Списания» 411 838,94 (100% на `loss`); «Прочие расходы» loss-часть 29 977,29 (1 документ); «Расходы
  маркетплейсов» commission-часть 438 729,42 (= оракул-«Комиссия»); «Маркетинг и реклама» — MISSING_SOURCE
  доминирует, но остаточный FX-компонент НЕ исключён (Δ −751 438,54 не разложена).

## Шаги
1. **[owner-гейт] Финализировать schema + имя CF.** Предложи финальную schema `core.fact_loss` и
   `core.fact_commissionreportin` (стартуй от PROPOSED-формы design-doc Часть A — она grounded в `fact_payments`
   и `02 §Источник #2`). Предложи **имя CF из фактов проекта** по конвенции нейминга (`05 Часть II`); имя
   `cf-finance-ext` из дизайна — **условное и под вопросом** (ADR-024 §6 — родство с cf-finance намеренно
   нежелательно): переопредели, не наследуй. **Верни предложения и ОСТАНОВИСЬ на ратификацию человека/архитектора
   до написания деплой-кода.** (Если ратификация приходит короткой репликой — трактуй как выбор формы, не как
   утверждение каждой колонки; зафиксируй ратифицированное в SESSION-блоке.)
2. **Написать ингест-CF** (после ратификации Шага 1). Паттерн `staging→MERGE` как `cf-finance`/`cf-facts`
   (`03_PIPELINE_SPEC`). Конвертация (ADR-010/ADR-024 §2), обязательна с первого дня:
   `sum_kgs = minor_units ÷ 100 × rate.value` (`rate.value` документа если задан; иначе текущий курс).
   **Никаких `÷100` без `× rate` — это класс бага ADR-016; новый ингест обязан быть чист.**
   - `loss`: `expense_item_name` — из статьи документа, фильтр/сопоставление **по имени** (ADR-006, регистр и
     формат критичны — нормализуй под 27-статейный список; известные варианты в recon: «Банк (комиссия)»↔
     «Банк-комиссия», «Мой Склад»↔«Мой склад», «Неразнесенное списание»↔«неразнесенные списания», «Топливо»↔
     «ТОпливо»).
   - `commissionreportin`: категория **жёстко** «Расходы маркетплейсов» (ADR-006 §2, не из источника);
     `sum = reward + commissionOverhead` (каждое `÷100 × rate`).
   - **Инвариант Ghost Records (ADR-011):** на этапе выгрузки — никаких `if/continue`; если к `loss` применима
     фильтрация системных статей, делай её `DELETE`-после-`MERGE`, не пропуском на выгрузке.
3. **Деплой-обвязка (для человека).** Деплой **locked-down: БЕЗ `--allow-unauthenticated`** (ADR-022/TD-SEC-01
   — публичный write-эндпоинт уже давал инцидент); вызов через OIDC (по образцу `finance-daily-update`). Если
   Scheduler-driven — `attemptDeadline` = серверный `--timeout` (прецедент ADR-023, значение владельца 1800s),
   не оставляй клиентский дефолт короче серверного.
4. **Загрузить май-2026** (окно, покрывающее месяц) в обе core-таблицы.
5. **Провенанс-снапшот** задеплоенной ревизии → `/reference/code/<cf>/` + `MANIFEST.md` (ADR-024 §3 →
   ADR-017 §2/§6): **байт-точно из `function-source.zip`/on-disk, НЕ транскрипция лога**; sha256-дерево;
   зафиксировать `disk==deployed`.
6. **Верификация на staging (прод-март НЕ трогать).** Сгруппируй загруженные `core.fact_loss` /
   `core.fact_commissionreportin` за май по статье и сверь с оракул-компонентами (см. Приёмку). Это
   верификация ингеста, НЕ SQL-дельта в прод (та — E1-T1-MECH, отдельно).

## Критерии приёмки (Acceptance — только проверяемые)
- **`core.fact_loss` (май, GROUP BY `expense_item_name`)** воспроизводит полностью-атрибутируемые loss-Δ **до
  копейки:** «Списания» = **411 838,94**; loss-часть «Прочие расходы» = **29 977,29**. loss-часть «Маркетинг и
  реклама» — **измерена и зафиксирована числом** (не пред-утверждается; остаток против 751 438,54, если есть, —
  территория FX/`paymentout`, вне этой задачи, см. Вне scope).
- **`core.fact_commissionreportin` (май)** итого = **438 729,42** (= оракул-«Комиссия»), 100% отнесено к
  «Расходы маркетплейсов».
- **Конвертация проверена на ≥1 не-KGS документе:** `sum_kgs = minor_units ÷ 100 × rate.value`; регрессии
  `÷100`-без-`×rate` (класс ADR-016) **нет**.
- **Провенанс:** `/reference/code/<cf>/` снапшот + `MANIFEST` закоммичены, sha256-трассируемы, байт-точны
  задеплоенной ревизии (`disk==deployed` подтверждён).
- **Auth-конформность:** `gcloud functions describe <cf>` — **нет** `allUsers`-binding / unauthenticated
  выключен (ADR-022).
- **Ghost Records:** в коде выгрузки нет `if/continue` (ADR-011).

## Что вернуть человеку (Return-this)
- **Шаг 1 (первым, до кода):** предложенная финальная schema обеих таблиц + предложенное имя CF (с обоснованием
  из фактов, не намекающее на cf-finance) → ждать `апрув schema+имя`.
- **После апрува:** исходник CF **одним вставляемым артефактом** (ADR-014 §single-paste, self-resolving secret,
  redirect-to-file) + точные команды: (а) `gcloud functions deploy …` **locked-down** (без `--allow-unauthenticated`);
  (б) вызов бэкофилла мая; (в) `bq query` GROUP-BY-статье для обеих таблиц (для сверки); (г) `gcloud functions
  describe <cf>` (read-back auth); (д) команда sha256/MANIFEST для снапшота. Указать, какие логи/числа прислать назад.
- **Явно раскрыть смешанное состояние (ADR-024 §5)** в возврате: `loss`/`commission` корректны сразу;
  `paymentout`/`cashout` в `base` остаются под ADR-016 до `E1-T3-MECH-FX` — заморозка «не финально инвестору»
  сохраняется на buggy-долю; раскрытие — на реальном cutover (E1-T1-MECH-CUTOVER), не здесь.

## Вне scope этой задачи
- **`sq_marts_expenses` / `transferConfig 6a22a243-…`** — не трогать ни in-place, ни иначе. SQL-дельта в прод =
  `E1-T1-MECH` / прод-cutover = `E1-T1-MECH-CUTOVER` (отдельные задачи).
- **`E1-T3-MECH-FX`** (FX-фикс `paymentout`/`cashout` в cf-finance) — развязан (ADR-016 §5, ADR-024 §2/§3);
  этой задачей не касаешься.
- **Разложение остатка «Маркетинг и реклама»** на loss-часть vs FX-компонент (ADR-016 §2) — не здесь.
- **«Налоги»/«Вывод прибыли»-аномалии** (E1-T2-MECH-TAX / Q-46 / `architect_review_queue_2026-07-21-1.md`) —
  не связаны.
- **`CODE-REPO-STANDUP`** (живой VC-репо исходников) — отдельная низкоприоритетная задача (ADR-017 §4/§5).
- **UUID-резолвинг статей** (Q-9, DEFER) — старт по имени валиден (ADR-009); UUID не резолвить.

## В конце сессии
Выдай SESSION-блок по формату `05_CONVENTIONS` Часть III (`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` /
`NEW_CONVENTIONS`). В `STATE_PATCH` — обязательное поле `- обновил: <роль> (сессия: E1-T1-MECH-INGEST)`
(ADR-025 §1). Заведи/обнови задача-строку `E1-T1-MECH-INGEST` в **GAP-реестре** `07_STATE` (не в «Статусы
задач» — ADR-025 §2). Статус `DONE` ставится ТОЛЬКО при возвращённом артефакте (лог/число/снапшот), метка без
артефакта = claim, не факт (ADR-021 §2 / Q-41).
