=== SESSION LOG · 2026-08-03 · INGEST-CURRENCY-ASSERT-GEN ===

## SESSION_LOG
- Задача: INGEST-CURRENCY-ASSERT-GEN — генерация брифа `INGEST-CURRENCY-ASSERT` (шаги 1-2)
- Сделано:
  - Прочитан обязательный контекст (`_METHOD`, `00_CHARTER`, `04_ROADMAP`, `06_INDEX`, `07_STATE`,
    `05_CONVENTIONS`, `08_TASK_BRIEF_TEMPLATE`); класс/параллель/мандат взяты из строк
    `07_STATE.md` §«Мандат Claude Code: класс задач» (`INGEST-CURRENCY-ASSERT, шаги 1-2` — A, нет,
    постоянный) и из `07_GAPS.md:67`.
  - Найдено и включено в бриф расхождение: шаг 1 GAP-строки (снять исходник/ревизию `cf-dq`,
    напечатать текст проверки `currency_normalization`) фактически уже исполнен сессией
    `DQ-SOURCE-CAPTURE` (2026-08-02, `07_ARCHIVE.md`, закрыла `Q-6`) — снапшот `reference/code/cf-dq/`
    и текст `check_currency_normalization` (`main.py:100-104`) уже в репо; GAP-строка это не отражает.
    Бриф требует от исполнителя переподтвердить свежесть ревизии и явно закрыть расхождение в
    артефакте, не пересобирать снапшот вслепую.
  - Сплошным поиском (`grep -rn "rate.get\|get(\"rate\""`) по `reference/code/cf-facts/*.py` и
    `reference/code/cf-finance/*.py` найдены шесть точек конвертации `minor_units × rate.value`
    (`fetch_demands.py:137`, `fetch_returns.py:79`, `fetch_purchases.py:101`, `fetch_perimeter.py:107`,
    `cf-finance/main.py:70`, `cf-loss-commission/main.py:83-85`) — включены в бриф как вход,
    с явным решением по каждой (пять в scope шага 2, `cf-loss-commission` вне scope, причина названа).
  - Подтверждён факт (реальным API-дампом `retaildemand_page_0.json`): `rate.currency` в списочном
    ответе несёт только `meta.href`, без `isoCode` — карта валют обязана строиться отдельным запросом
    `entity/currency`, не через `expand` (ловушка `Q-49`/`02_ERP_CONTRACTS.md:425`, `limit=1000` в
    обоих CF). Внесено в бриф как обязательный факт Шага 3.
  - Найден и внесён в бриф (Шаг 5/находка, не решение) факт: действующий паттерн `... or 1.0` во всех
    пяти точках в scope нарушает уже принятый `ADR-029 §1` («fallback обязан падать исключением, не
    `1.0`»); в проекте уже есть задеплоенный образец правильной формы —
    `reference/code/cf-finance/invoices.py::rate_and_currency`/`_fetch_current_rate`
    (`INVOICES-LOADER-DEPLOY`, DONE 2026-08-03). Бриф явно ограничивает scope детекцией (не меняет
    арифметику revenue_kgs/sum_kgs) и называет замену fallback-логики отдельным решением/задачей вне
    этой сессии.
  - Бриф `briefs/INGEST-CURRENCY-ASSERT.md` собран по шаблону `08`, класс A, параллель «нет», поле
    «Файлы на запись» заполнено маркированным списком.
- Команды/логи ключевые: только чтение репо (`Read`/`Bash grep`/`ls`) и один offline-разбор живого
  API-дампа, ранее сохранённого другой сессией (`python3 -c "json.load(...)"` над
  `reference/_scratch_PARITY-SALES-DISCRIMINATE-2NDSTEP_2026-08-02/retaildemand_page_0.json`) — без
  сети, без секретов, без записи куда-либо, кроме `briefs/` и `reference/_inbox/`.
- Отклонения от плана: нет — задача была прямо названа владельцем в тексте запуска
  («Задача: INGEST-CURRENCY-ASSERT (шаги 1–2)»), не выведена из «Текущего фокуса» `07_STATE`.

## STATE_PATCH
- Задача INGEST-CURRENCY-ASSERT, шаги 1-2: READY → READY, бриф собран (`briefs/INGEST-CURRENCY-ASSERT.md`), не взят
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, НЕ дописывается, ровно пять строк):
  - Прошлый шаг: бриф `INGEST-CURRENCY-ASSERT` (шаги 1-2) собран сессией `INGEST-CURRENCY-ASSERT-GEN`; найдено и внесено в бриф, что шаг 1 (снапшот `cf-dq`/текст проверки) фактически уже закрыт `DQ-SOURCE-CAPTURE` — GAP-строка это не отражала.
  - Где мы: без изменений относительно прошлой сборки (`SALES-INGEST-PATCH`, готово к деплою) — эта сессия только подготовила бриф, задачу не исполняла.
  - Следующий шаг: деплой `cf-facts` (класс B, `DEPLOY-PROCEDURE`, `ADR-115`) остаётся приоритетным по прошлой сборке; параллельно взять `INGEST-CURRENCY-ASSERT` (класс A, бриф готов, не взят).
  - Развилки на владельце: без изменений (объединять ли деплой `SALES-INGEST-PATCH`/`SALES-REFRESH-WINDOW` — не решено этой сессией).
  - Счётчик: без изменений — пары реестра 2/7 · измерено 7/7 · Epic M 6/7 фаз.
- Подробности для модели: Бриф `briefs/INGEST-CURRENCY-ASSERT.md` (шаги 1-2, класс A) собран.
  Ключевое для исполнителя: шаг 1 буквально по `07_GAPS.md:67` уже фактически исполнен сессией
  `DQ-SOURCE-CAPTURE` (2026-08-02) — снапшот `reference/code/cf-dq/` и текст
  `check_currency_normalization` (`main.py:100-104`) в репо; бриф требует переподтвердить свежесть
  ревизии, не пересобирать вслепую. Шаг 2 расширен сплошным поиском с одной находки
  (`fetch_demands.py:137`, единственная, названная `ADR-101 §5`) до шести точек конвертации в двух CF
  (`cf-facts`, `cf-finance`); `cf-loss-commission` явно исключён (governed `ADR-026`, другая величина).
  Найдено (не решено): пять точек в scope нарушают уже принятый `ADR-029 §1` (`or 1.0` вместо
  падения/fallback-fetch); в проекте уже есть задеплоенный образец правильной формы
  (`cf-finance/invoices.py::rate_and_currency`, `INVOICES-LOADER-DEPLOY` DONE 2026-08-03) — бриф
  сознательно ограничивает scope детекцией (без смены арифметики выхода) и оставляет замену
  fallback-логики отдельным решением архитектора/владельца. Карта валюта→`isoCode` обязана строиться
  отдельным запросом `entity/currency`, не через `expand=rate.currency` — подтверждено живым дампом
  `retaildemand_page_0.json` (`rate.currency` в списочном ответе несёт только `meta.href`), совпадает
  с известной ловушкой `Q-49`.
- Новые открытые вопросы: нет (бриф фиксирует находку `ADR-029 §1` как материал для исполнителя/
  архитектора внутри самого брифа, не заводит отдельную строку реестра — решение по ней не принято,
  заведение строки было бы преждевременным до факта её разбора)
- Блокеры: нет
- updated_at: 2026-08-03
- обновил: generator (сессия: INGEST-CURRENCY-ASSERT-GEN)

## NEW_DECISIONS
нет

## NEW_CONVENTIONS
нет

=== END SESSION ===
