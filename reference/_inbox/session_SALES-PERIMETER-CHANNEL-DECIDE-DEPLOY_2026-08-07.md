# FILE: session_SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY_2026-08-07.md

=== SESSION LOG · 2026-08-07 · SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY ===

## SESSION_LOG
- Задача: `SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY` — деплой метки канала периметра продаж в
  `cf-facts` (шаги 5–10 брифа; шаги 1–4 исполнены и закоммичены предыдущей сессией, не
  переделывались).
- Сделано:
  - Мандат класса B подтверждён фактом: `07_STATE.md §Мандат Claude Code`, строка
    `SALES-PERIMETER-CHANNEL-DECIDE, деплой | B | нет | выдан поимённо ADR-135`; `06_INDEX.md`
    ADR-135 accepted, владелец, чат 2026-08-07.
  - Повторный read-only `describe` (часть шага 2, не переделка): живая ревизия перед деплоем —
    та же `cf-facts-00008-zen`, дрейфа между сессиями нет.
  - Шаг 5: объявление действия отдельным сообщением, владелец подтвердил.
  - Шаг 6 (деплой): `cf-facts-00008-zen` → `cf-facts-00009-tul`, `generation
    1786115536540209`, `updateTime 2026-08-07T15:13:10Z`.
  - Шаг 7 (read-back): sha256 всех 11 файлов архива побайтово совпал с веткой
    `deploy/cf-facts-2026-08-07-channel` (кроме `.gcloudignore`, закономерно отсутствующего в
    архиве); мусора нет.
  - Шаг 8 (незатронутые режимы): прогон `hourly` — `status=ok`, без ошибок; sha256
    незатронутых файлов не изменился.
  - Шаг 9а (`perimeter`, staging, первым): периметр отбора НЕ изменился — точное совпадение с
    прошлым измерением (506 док/1441 строка/1 188 422,00 KGS розница; 24 док/4026 строк/
    11 514 572,13 KGS комиссия); `sales_channel_name` заполнено верно, `sales_channel_id` = NULL.
  - Шаг 9б (`perimeter_promote`, core, после 9а): `MERGE` только обновил существующие строки
    (итого `core.fact_sales_profit` не изменился — 42 784 строки / 691 376 392,83 KGS до и
    после). **Главное число:** `NULL` у 5 467 строк периметра упал до 0 (4 026 «Комиссия» +
    1 441 «Розница»). Сумма периметра 12 702 994,13 KGS не изменилась.
  - Шаг 10 (слияние): `deploy/cf-facts-2026-08-07-channel` (`84d6f71`) слит в `master`
    `holika-prod` (`merge --no-ff`, коммит `7e039bd`), запушено. Запись ревизия↔коммит —
    `reference/code/cf-facts/MANIFEST.md`.
  - Артефакт `reference/sales_perimeter_channel_decide_deploy_2026-08-07.md` переписан с
    «деплой не выполнен» (состояние предыдущей сессии) на итоговый факт деплоя.
  - Коммит в свою ветку `s/SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY`: `17d5215`.
- Команды/логи ключевые: `reference/_scratch_SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY_2026-08-07/`
  (`step0_*`, `step6_*`, `step7_*`, `step8_*`, `step9a_*`, `step9b_*`, `branch_check/`).
- Отклонения от плана: шаг 9а — клиент `gcloud functions call` дважды обрывался по клиентскому
  таймауту (сервер отрабатывал ~370–400с); слепой повтор НЕ делался — завершение подтверждено
  read-only опросом `stg_msklad.fact_sales_perimeter_staging` (прецедент из прошлого деплоя
  периметра, `ADR-055 §2`/§не-идемпотентные операции соблюдены — вызов один, ожидание
  read-only). В остальном — без отклонений.

## STATE_PATCH
- Задача `SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY`: READY (мандат выдан) → **DONE**. Прод
  `cf-facts` стоит на ревизии `cf-facts-00009-tul`.
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, НЕ дописывается, ровно пять строк):
  - Прошлый шаг: деплой метки канала периметра продаж в `cf-facts` завершён (ревизия
    `cf-facts-00009-tul`), `NULL` у 5 467 строк периметра `core.fact_sales_profit` заменён на
    «Розница»/«Комиссия» — `reference/sales_perimeter_channel_decide_deploy_2026-08-07.md`.
  - Где мы: счётчик реестра паритета `7/7`; из очереди `SALES-PERIMETER-QUEUE-ADJ`
    (`ADR-131`) закрыты `SALES-PERIMETER-LANDING-CHECK`, `SALES-PERIMETER-CADENCE`,
    `SALES-PERIMETER-CHANNEL-DECIDE` (подготовка+деплой); остаются
    `SALES-DOCUMENT-OWNER-DEPLOY` (готовность блокирует правка `WHEN MATCHED UPDATE SET`,
    `ADR-135 §4`) и `SALES-PERIMETER-PARITY-RECHECK` (мандат выдан, бриф готов, не взята).
  - Следующий шаг: `SALES-PERIMETER-PARITY-RECHECK` (пересверка пары «Продажи» после деплоя
    периметра) параллельно с доработкой `SALES-DOCUMENT-OWNER-INGEST` по `ADR-135 §4`.
  - Развилки на владельце: нет.
  - Счётчик: пары реестра паритета 7/7 · Epic-1 очередь финиша — 2/4 задач очереди
    `SALES-PERIMETER-QUEUE-ADJ` остаются открытыми.
- Подробности для модели: `SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY` закрыта DONE, session-блок и
  артефакт `reference/sales_perimeter_channel_decide_deploy_2026-08-07.md` несут полную
  провенанс-цепочку (шаги 0, 5–10, все числа с арифметикой). Join периметра с `core` для будущих
  сверок — по `transaction_id = TO_HEX(MD5(CONCAT(doc_id,'|',position_id)))` против снимка
  `stg_msklad.fact_sales_perimeter_staging` (в `core.fact_sales_profit` нет колонки
  `source_doc_type`, только `entity_type` = product/service — не путать с типом документа МойСклад).
- Новые открытые вопросы: нет.
- Блокеры: нет.
- updated_at: 2026-08-07
- обновил: исполнитель (сессия: SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY)

## NEW_DECISIONS
- нет

## NEW_CONVENTIONS
- нет

=== END SESSION ===
