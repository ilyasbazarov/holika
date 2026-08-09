=== SESSION LOG · 2026-08-09 · PURCHASES-INTRANSIT-RECHECK-VERIFY ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: PURCHASES-INTRANSIT-RECHECK-VERIFY — подтвердить, что деплой `INGEST-MOMENT-ZONE-FIX`
  не сдвинул пару «Заказы поставщикам в пути» (`core.fact_purchases`, `ADR-124`, `Δ=0`)
- Сделано: класс A, read-only, без брифа (задача определена реестром `07_GAPS.md` строкой
  `PURCHASES-INTRANSIT-RECHECK-VERIFY`, класс и постоянный мандат подтверждены `07_STATE.md §Мандат
  Claude Code` той же строкой). Два независимых пути закрытия `CONTEXT GAP`, названного
  `INGEST-MOMENT-ZONE-FIX-DEPLOY`: (1) разбор диффа кода `cf-facts` (архивы до/после деплоя,
  `reference/_scratch_INGEST-MOMENT-ZONE-FIX-DEPLOY_2026-08-09/live_archive{,_post}/`) показал, что
  правка `_parse_date_kgt`/`_parse_moment_kgt` тронула только поля `order_date`/`planned_delivery_date`,
  ни одно из которых не входит в формулу/фильтр пары (`status_name`, `quantity_in_transit`,
  `price_kgs`, `in_transit_sum_kgs`) — вывод формулой, не наблюдением (`05_CONVENTIONS` Часть I ★);
  (2) тот же позиционный запрос нашей стороны, что `PARITY-STOCK-INTRANSIT-RECHECK` (2026-08-05)
  использовала для `core.fact_purchases`, перезапущен сегодня и построчно сопоставлен по ключу
  `(purchase_order_id, position_id)` с замороженным снимком `2026-08-05` — все `251` позиций из
  снимка `2026-08-05` (там `Δ=0` против живого источника, `ADR-124`) присутствуют сегодня без
  единого расхождения по всем четырём полям формулы; `+18` новых позиций объясняются естественным
  ростом таблицы (`211→214` заказов, `4398→4424` строк). Живых вызовов к МойСклад не было.
- Артефакт: `reference/purchases_intransit_recheck_verify_2026-08-09.md`.
- Команды/логи ключевые: `reference/_scratch_PURCHASES-INTRANSIT-RECHECK-VERIFY_2026-08-09/step1_our_side_now.sh`
  → `run_step1.log` (UTC `2026-08-09T14:54:40Z … 14:54:50Z`, личность `ilyasbazarov4@gmail.com`
  совпала в начале и в конце).
- Отклонения от плана: нет.

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача PURCHASES-INTRANSIT-RECHECK-VERIFY: READY → DONE. Строка `07_STATE.md §Открытые вопросы`
  (таблица мандата, строка 1715) и парная строка `07_GAPS.md` полностью закрыты — переносятся в
  `07_ARCHIVE.md` дословно тем же коммитом сборки.
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, НЕ дописывается, ровно пять строк):
  - Прошлый шаг: закрыт хвост деплоя `INGEST-MOMENT-ZONE-FIX-DEPLOY` — позиционная сверка нашей
    стороны подтвердила, что деплой не сдвинул пару «Заказы поставщикам в пути» (`ADR-124`),
    двумя независимыми путями (разбор диффа кода + перезапуск позиционного запроса), артефакт
    `reference/purchases_intransit_recheck_verify_2026-08-09.md`.
  - Где мы: счётчик реестра паритета остаётся `7/7`, теперь подтверждён числом на новом коде для
    ВСЕХ трёх пар, сверенных этим деплоем (было — для двух из трёх).
  - Следующий шаг: без изменений от предыдущего стенд-апа — `DQ-GATE-FAIL-OPEN-FIX` подготовка,
    `DQ-FRESHNESS-COVERAGE` подготовка, `INFRA-FACTS-LANDING`.
  - Развилки на владельце: без изменений от предыдущего стенд-апа — мандат класса B на
    `DQ-ALERT-FILTER-FIX`; предусловие мандата `SALES-REFRESH-WINDOW`; апрув
    `ERP-CONTRACTS-DAY-RULE-DOC`; подпись момента пересборки на странице «в пути» (исполнителя нет).
  - Счётчик: пары реестра `7/7` · обязательных задач передачи `10` (из них с выданным мандатом `3`)
    · Epic M — (Epic-1 завершён `ADR-140`).
- Подробности для модели: `INGEST-MOMENT-ZONE-FIX-DEPLOY` (`07_STATE.md:1547`) закрывается
  полностью — хвост «точная сверка `core.fact_purchases`/`ADR-124`» снят этой сессией; строка
  1547 может уезжать в `07_ARCHIVE.md` вместе с этим патчем, если сборка сочтёт её полностью
  закрытой (открытых пунктов у неё, кроме этого хвоста, не было по тексту строки).
- Новые открытые вопросы: нет.
- Блокеры: нет.
- updated_at: 2026-08-09
- обновил: executor (сессия: PURCHASES-INTRANSIT-RECHECK-VERIFY)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md; "нет" если нет)
- нет

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
- нет

=== END SESSION ===
