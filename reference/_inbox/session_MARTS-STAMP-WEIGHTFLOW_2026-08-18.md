=== SESSION LOG · 2026-08-18 · MARTS-STAMP-WEIGHTFLOW ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: `MARTS-STAMP-WEIGHTFLOW` — применение отметки времени сборки на `transferConfig`
  `sq_marts_weight_flow` (одна из трёх строк применения `MARTS-BUILD-STAMP-PREP`, объект `7г3`)
- Сделано: предусловие (i) свежий `bq show --transfer_config` сверен со снимком репо (расхождение
  ровно декоративное — буква в комментарии + перевод строки, длины `2546`/`2545` байт, сверх этого
  ничего); предусловие (ii) `bq query --dry_run` подготовленного текста, `rc=0`,
  `totalBytesProcessed=3245432`; объявление действия владельцу отдельным сообщением, дословное «да»
  получено; один вызов `bq update --transfer_config` подменил `params.query` на подготовленный
  текст `reference/sql/sq_marts_weight_flow_stamped_2026-08-13.sql` как есть; один ручной прогон
  (`bq mk --transfer_run`), завершился `SUCCEEDED`; приёмка трёх пунктов — read-back побайтово
  равен (sha256 совпадает), обе колонки в схеме, обе колонки непустые на всех `559` строках
  (`_marts_built_at`/`_source_max_loaded_at`, конкретные значения — в артефакте)
- Команды/логи ключевые: `reference/_scratch_MARTS-STAMP-WEIGHTFLOW_2026-08-18/step1_run.log`
  … `step7_run.log`; полный разбор — `reference/marts_stamp_weightflow_2026-08-18.md`
- Отклонения от плана: нет

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача `MARTS-BUILD-STAMP-PREP`: остаётся `PARTIAL` — применение на объекте
  `sq_marts_weight_flow` (`7г3`) исполнено и принято; применение на `sq_marts_customer_invoices_ar`
  (`7г1`) и `sq_marts_expenses` (`7г2`) остаётся не исполненным, две отдельные сессии, мандаты
  выданы (`ADR-193 §5`)
- Дописка к строке реестра `MARTS-BUILD-STAMP-PREP` (строка `2198`, добавить фактом, не
  переписывая существующий текст): «Применение на `sq_marts_weight_flow` (`7г3`) ИСПОЛНЕНО и
  ПРИНЯТО (`MARTS-STAMP-WEIGHTFLOW`, 2026-08-18): read-back побайтово равен, обе колонки в схеме,
  обе непусты на `559`/`559` строках. Форма/приёмка/откат — `reference/dq_deploy_accept_adj_2026-08-18.md §5/§7`;
  полный разбор — `reference/marts_stamp_weightflow_2026-08-18.md`. Остаются `7г1`
  (`sq_marts_customer_invoices_ar`) и `7г2` (`sq_marts_expenses`) — мандаты выданы, применение не
  исполнено, отдельные сессии (`ADR-115 §5`)».
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, НЕ дописывается, ровно пять строк):
  - Прошлый шаг: отметка времени сборки применена и принята на `sq_marts_weight_flow`
    (`MARTS-STAMP-WEIGHTFLOW`, `reference/marts_stamp_weightflow_2026-08-18.md`) — один из трёх
    объектов строки `7` списка закрытия
  - Где мы: строка `7` (`MARTS-BUILD-STAMP`) — `1` объект применения из `3` исполнен; строка `7`
    целиком не закрывается, пока не исполнены `sq_marts_customer_invoices_ar` и `sq_marts_expenses`
  - Следующий шаг: применение отметки времени сборки на `sq_marts_customer_invoices_ar` и на
    `sq_marts_expenses` (по одной сессии на объект, мандаты выданы, `ADR-193 §5`) · ступень 3
    различителя `SALES-REFRESH-WINDOW-DELETE-DISCRIMINATE` (мандат класса B выдан)
  - Развилки на владельце: нет
  - Счётчик: строк списка закрытия — `4` из `9` (без изменений этой сессией — строка `7` не
    закрыта целиком) · пары реестра `7`/`7` · Epic M `7` фаз (без изменений)
- Подробности для модели: применение на `weight_flow` доказано тремя фактами, не меткой успеха
  инструмента — read-back sha256 `ba18dc56cb20af7881480c503ecfecf89de760e4e2caae99c0fa262355cc3a45`
  на обеих сторонах, схема содержит обе колонки, `559`/`559` строк непустых по обеим. Финальная
  позиционная склейка `UNION ALL` подготовленного текста применена БЕЗ пересобирания — условие
  мандата `§7`; арность/типы подтверждены прохождением `dry_run` до правки, не чтением после.
  Следующая сессия на `customer_invoices_ar`/`expenses` может переиспользовать форму этого
  session-блока и скриптов `_scratch_MARTS-STAMP-WEIGHTFLOW_2026-08-18/` как шаблон шагов
  (адрес transferConfig и Config ID — свои для каждого объекта, см. `dq_deploy_accept_adj_2026-08-18.md §5`).
- Новые открытые вопросы: нет
- Блокеры: нет
- updated_at: 2026-08-18
- обновил: исполнитель (сессия: `MARTS-STAMP-WEIGHTFLOW`)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md как ADR; "нет" если нет)
нет

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
нет

=== END SESSION ===
