# FILE: sq_cadence_2026-07-27.md

# Замер каденции мартов + расписаний transferConfig · провенанс cutover `E1-T1-MECH`

**Дата (Бишкек):** 2026-07-27 · **Роль:** владелец (терминал macOS) + генератор-чат
**Основание:** `ADR-045 §3/§5` — жёсткое предусловие генерации брифа `E1-T1-MECH-CUTOVER`.
**Класс:** read-only замер. Команд записи в разделах §1–§4 нет.

---

## §1 Якоря и личность вызывающего (`ADR-055 §3`, `ADR-063 §4`)

| Прогон | Начало (`date -u`) | Конец (`date -u`) | Аккаунт начала = конца | Проект |
|---|---|---|---|---|
| 1 (частичный) | `2026-07-27T15:09:18Z` | `2026-07-27T15:09:25Z` | `ilyasbazarov4@gmail.com` | `msklad-bi-prod` |
| 2 (полный) | `2026-07-27T15:13:14Z` | `2026-07-27T15:13:35Z` | `ilyasbazarov4@gmail.com` | `msklad-bi-prod` |

Расхождения личности между началом и концом ни в одном прогоне нет.
**Версия инструмента:** BigQuery CLI 2.1.35.

## §2 Отказ первого прогона — факт, а не «данных нет»

`bq ls -j --all_users` отклонён: `FATAL Flags parsing error: Unknown command line flag 'all_users'`.
`bq help ls` на этой установке печатает `--[no]all_jobs: DEPRECATED. Use --all instead`. Форма замера,
записанная в `ADR-045 §5`, на текущей версии `bq` неисполнима дословно; сработавший флаг — `--all_jobs`.
Пустая выдача первого прогона зафиксирована как гэп наблюдения (`05` Часть I ★, `ADR-021 §2`), не как
отсутствие заданий. Второй прогон отработал: 5 982 400 байт, 640 заданий.

Тем же прогоном выявлен и исправлен дефект скрипта: цикл терял последнюю строку списка, из-за чего вторая
конфигурация не снималась. Обе конфигурации сняты во втором прогоне.

## §3 Фактическая каденция `marts.*` за окно `2026-07-26T15:13Z … 2026-07-27T15:13Z`

Все задания исполнены под `ilyasbazarov4@gmail.com` — DTS запускает scheduled query под учётной записью
создателя конфигурации, что подтверждает довод `ADR-045 §1` (отсутствие `--all_users` гипотезы не различало).

| Время (UTC) | Целевая таблица | Задание |
|---|---|---|
| `2026-07-26T15:34:03Z` | `marts.sales_overview` | `scheduled_query_6a65b5e8-…` |
| `2026-07-26T17:34:02Z` | `marts.sales_overview` | `scheduled_query_6a65d2c5-…` |
| `2026-07-26T19:34:01Z` | `marts.sales_overview` | `scheduled_query_6a666567-…` |
| `2026-07-26T19:39:37Z` | `marts.expenses_staging` | `bqjob_r4a62e606d0d607b2_…` (ручной, сессия `E1-T1-MECH`) |
| `2026-07-26T21:34:02Z` | `marts.sales_overview` | `scheduled_query_6a669055-…` |
| `2026-07-26T23:30:02Z` | `marts.weight_flow` | `scheduled_query_6a65de19-…` |
| `2026-07-26T23:34:01Z` | `marts.sales_overview` | `scheduled_query_6a66ffa0-…` |
| `2026-07-27T01:34:03Z` | `marts.sales_overview` | `scheduled_query_6a66cf8a-…` |
| `2026-07-27T03:34:02Z` | `marts.sales_overview` | `scheduled_query_6a66c187-…` |
| `2026-07-27T05:34:02Z` | `marts.sales_overview` | `scheduled_query_6a671a03-…` |
| `2026-07-27T07:34:03Z` | `marts.sales_overview` | `scheduled_query_6a6724f4-…` |
| `2026-07-27T08:03:03Z` | `marts.gmroi` | `scheduled_query_6a672d01-…` |
| `2026-07-27T08:04:02Z` | `marts.abc_xyz` | `scheduled_query_6a6720a8-…` |
| `2026-07-27T09:34:01Z` | `marts.sales_overview` | `scheduled_query_6a69c16e-…` |
| `2026-07-27T10:00:05Z` | `marts.customer_invoices_ar` | `scheduled_query_6a66b6c7-…` (`WRITE_TRUNCATE`) |
| `2026-07-27T11:00:05Z` | `marts.inventory_health` | `scheduled_query_6a667088-…` |
| **`2026-07-27T11:10:01Z`** | **`marts.expenses`** | `scheduled_query_6a66c595-…` (`WRITE_TRUNCATE`) |
| `2026-07-27T11:34:05Z` | `marts.sales_overview` | `scheduled_query_6a674913-…` |
| `2026-07-27T12:02:03Z` | `marts.gmroi_by_folder` | `scheduled_query_6a674146-…` |
| `2026-07-27T13:09:03Z` | `marts.in_transit` | `scheduled_query_6a6780d0-…` |
| `2026-07-27T13:09:04Z` | `marts.supplier_price_history` | `scheduled_query_6a67d19e-…` |
| `2026-07-27T13:34:03Z` | `marts.sales_overview` | `scheduled_query_6a66915a-…` |

**Расширенное окно по `marts.expenses` (трое суток, отдельный прогон 2026-07-27T15:30Z):**
`2026-07-25T11:10:09Z`, `2026-07-26T11:10:03Z`, `2026-07-27T11:10:01Z` — ровно один прогон в сутки, якорь
`11:10 UTC`, других прогонов нет.

**Второй путь пересборки (`ADR-038`: `cf-finance.trigger_marts()` в конце ночного прогона, ~21:00 UTC) в
наблюдённом окне НЕ проявился ни разу за трое суток.** Наблюдение не интерпретируется (`ADR-045 §1`):
ни «путь отсутствует», ни «путь есть» настоящим артефактом не утверждается. Зафиксировано как факт
наблюдения; квалификация — за архитектором.

## §4 Расписания флота (13 конфигураций, location `asia-east1`, проект `420804682491`)

| displayName | Config ID | schedule | nextRunTime | state |
|---|---|---|---|---|
| `sq_audit_dim_counterparties_snapshot` | `69fc9c75-…` | `every day 04:00` | `2026-07-28T04:00:00Z` | SUCCEEDED |
| `sq_audit_dim_employees_snapshot` | `69fc9d6e-…` | `every day 04:00` | `2026-07-28T04:00:00Z` | SUCCEEDED |
| `sq_audit_dim_products_snapshot` | `69fc93d1-…` | `every day 04:00` | `2026-07-28T04:00:00Z` | **FAILED** (`ADR-019`) |
| `sq_marts_abc_xyz` | `6a020b2c-…` | `every 24 hours` | `2026-07-28T08:04:00Z` | SUCCEEDED |
| `sq_marts_customer_invoices_ar` | `6a23f3ea-…` | **поля нет** | `2026-07-28T10:00:00Z` | SUCCEEDED |
| `sq_marts_expenses` | `6a22a243-…` | **поля нет** | `2026-07-28T11:10:00Z` | SUCCEEDED |
| `sq_marts_gmroi` | `6a006664-…` | `every 24 hours` | `2026-07-28T08:03:00Z` | SUCCEEDED |
| `sq_marts_gmroi_by_folder` | `6a004e88-…` | `every 24 hours` | `2026-07-28T12:02:00Z` | SUCCEEDED |
| `sq_marts_in_transit` | `6a0aa537-…` | `every 24 hours` | `2026-07-28T13:09:00Z` | SUCCEEDED |
| `sq_marts_inventory_health` | `69fd92d9-…` | `every 24 hours` | `2026-07-28T11:00:00Z` | SUCCEEDED |
| **`sq_marts_sales_overview`** | `69ff34b4-0000-2b2b-a390-14c14ef7af10` | **`every 2 hours`** | `2026-07-27T15:34:00Z` | SUCCEEDED |
| `sq_marts_supplier_price_history` | `6a0b0f25-…` | `every 24 hours` | `2026-07-28T13:09:00Z` | SUCCEEDED |
| `sq_marts_weight_flow` | `6a1f9418-…` | `every 24 hours` | `2026-07-27T23:30:00Z` | SUCCEEDED |

**Полные выдачи двух целевых конфигураций.** Набор ключей у обеих:
`dataSourceId, datasetRegion, destinationDatasetId, displayName, emailPreferences, name, nextRunTime,
ownerInfo, params, scheduleOptions, scheduleOptionsV2, state, updateTime, userId`.

- `sq_marts_expenses` (`6a22a243-0000-20fd-a458-883d24f4cad4`): `scheduleOptions: {}`,
  `scheduleOptionsV2: {'timeBasedSchedule': {}}`, `nextRunTime: 2026-07-28T11:10:00Z`,
  `updateTime: 2026-06-05T11:10:23.201634Z`, `userId: 8522307959247193051`,
  `ownerInfo: {'email': 'ilyasbazarov4@gmail.com'}`, `destinationDatasetId: marts`.
  `params`: `destination_table_name_template='expenses'`, `write_disposition='WRITE_TRUNCATE'`,
  `partitioning_field=''`, `query` (1359 байт до правки).
- `sq_marts_customer_invoices_ar` (`6a23f3ea-0000-2952-853d-582429be7ecc`): `scheduleOptions: {}`,
  `nextRunTime: 2026-07-28T10:00:00Z`, `updateTime: 2026-06-05T10:00:27.182221Z`,
  `userId: 8522307959247193051`, `destinationDatasetId: marts`.

**Ключевой факт для `11 §SQ`:** поле `schedule` у обеих конфигураций в выдаче **отсутствует**, а не пусто.
Формулировка `11 §SQ` стр.49 «schedule-поле пустое» неточна: расписание живёт в `scheduleOptionsV2`, где
`timeBasedSchedule` пуст ⇒ суточный интервал по умолчанию, якорь совпадает с `updateTime` конфигурации
(`11:10` и `10:00` UTC соответственно, обе обновлены 2026-06-05). Это закрывает остаток `Q-21`.

## §5 Побочная находка: приведение времени к дате у новых источников (`Q-77`)

Замер 2026-07-27T15:45:53Z…15:46:06Z, read-only.

| Таблица | Тип `moment` | Строк | В интервале 18:00–23:59 UTC | Часы (мин…макс UTC) |
|---|---|---|---|---|
| `core.fact_payments` | **DATE** | — | — | — |
| `core.fact_loss` | **TIMESTAMP** | 128 | 7 | 6 … 21 |
| `core.fact_commissionreportin` | **TIMESTAMP** | 191 | 14 | 0 … 23 |

`CAST(... AS DATE)` берёт календарный день по UTC; Бишкек — UTC+6, поэтому разъезд возможен только у строк
интервала 18:00–23:59 UTC. Фактически месяц меняют **три документа за всю историю**:

| Месяц по UTC | Месяц по Бишкеку | Строк | Сумма KGS |
|---|---|---|---|
| `2024-08` | `2024-09` | 1 | 175 751,19 |
| `2025-02` | `2025-03` | 2 | 9 312,97 |

Май-2026 идентичен при обоих способах счёта: новые ветки дают `1 631 984,19` и так и так.
Оба затронутых периода лежат ДО якоря паритета `2026-05-01` (`ADR-069`) ⇒ cutover не гейтят.
Распределение по часам различить «настоящий UTC» и «местное время без пересчёта» не позволяет: у списаний
часы 6–21, у комиссий 124 записи из 191 стоят на 16 часах (похоже на автоматическую отметку отчёта
маркетплейса). Гипотеза не назначается (`_METHOD §6`); различитель — сверка с ответом API МойСклада.

## §6 Cutover `E1-T1-MECH` — исполнен в тот же день

| Событие | Время (UTC) | Результат |
|---|---|---|
| Откатный текст снят до первого касания | `2026-07-27T15:35:56Z` | 1359 байт, совпал по размеру со снимком `/reference/sql/sq_marts_expenses.sql` |
| Подмена `params` | `~2026-07-27T15:52Z` | `successfully updated` |
| Read-back до прогона | `2026-07-27T15:53:20Z` | 12/12 проверок OK: текст 3114 байт байт-в-байт, все 4 параметра, `nextRunTime`, `scheduleOptionsV2`, `state`, `ownerInfo` не изменились |
| Ручная пересборка | `runTime 2026-07-27T15:53:44Z` | run `6a6770e8-0000-2b13-9b3e-089e082b4104` |
| Приёмка | `2026-07-27T15:55:10Z…15:55:26Z` | см. ниже |

**Приёмка:** май-2026 на проде = **10 232 903,20**, разрыв с эталоном **0,00**. Постатейно совпало полностью,
включая `Списания` 411 838,94, `Маркетинг и реклама` 1 026 901,54, `Прочие расходы` 83 985,29,
`Расходы маркетплейсов` 580 674,98. Прод минус staging — **0,00 по всем 28 месяцам**, разница в количестве
документов — **0 везде**. Схема — 17 колонок, состав и порядок не изменились. `payment_type` теперь несёт
четыре значения: `cashout, commission, loss, paymentout`. Витрина: 3172 строки, 28 месяцев.

Дефект скрипта приёмки: `bq ls --transfer_run --format=prettyjson` вернул не-JSON («Extra data: line 6»),
состояние прогона из него не прочиталось. Гэп наблюдения, не отказ прогона: факт исполнения подтверждён
содержимым самой витрины (новые типы и совпадение со staging), что является более сильным свидетельством.

## Провенанс

Локальные сырые выгрузки на машине владельца: `~/holika_cadence_20260727T150918Z`,
`~/holika_cadence_20260727T151314Z`, `~/holika_newsql_20260727T153004Z`, `~/holika_step1_20260727T153556Z`
(включая `rollback_query.sql`, `live_config_before.json`, `live_config_after.json`).
