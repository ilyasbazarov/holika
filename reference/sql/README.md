# Reference: канонический SQL scheduled queries (BigQuery Data Transfer)

**Назначение:** дословный снапшот SQL всех BigQuery scheduled queries (transferConfigs) проекта
`msklad-bi-prod`, выгруженный как референс-провенанс (`_METHOD` §11) для закрытия **Q-5**
(`07_STATE`). Файлы — эталон-снимок на дату выгрузки, **не** живой источник истины; при
расхождении с продом сверяться заново через `bq show --transfer_config`.

- **Дата выгрузки:** 2026-07-07
- **SHA брифа:** `805450a9a8d513031029445d91dc90172d6b80c9` (M-P4-D5)
- **Проект:** `msklad-bi-prod`
- **Location:** `asia-east1`
- **Команда источника:** `bq ls --transfer_config --transfer_location=asia-east1 --project_id=msklad-bi-prod --format=prettyjson`
- **Покрытие:** 13/13 transferConfigs (100%, см. «Наблюдения» ниже по составу)

## Индекс

| Config ID | displayName | Файл | Целевая таблица | Schedule | Состояние (на дату выгрузки) |
|---|---|---|---|---|---|
| `69fc93d1-0000-2d64-bdd1-30fd381336b4` | `sq_audit_dim_products_snapshot` | [sq_audit_dim_products_snapshot.sql](./sq_audit_dim_products_snapshot.sql) | `msklad-bi-prod.audit.dim_products_snapshots` | every day 04:00 | ⚠ FAILED |
| `69fc9c75-0000-2ab4-91b3-883d24f4db64` | `sq_audit_dim_counterparties_snapshot` | [sq_audit_dim_counterparties_snapshot.sql](./sq_audit_dim_counterparties_snapshot.sql) | `msklad-bi-prod.audit.dim_counterparties_snapshots` | every day 04:00 | SUCCEEDED |
| `69fc9d6e-0000-2ab4-91b3-883d24f4db64` | `sq_audit_dim_employees_snapshot` | [sq_audit_dim_employees_snapshot.sql](./sq_audit_dim_employees_snapshot.sql) | `msklad-bi-prod.audit.dim_employees_snapshots` | every day 04:00 | SUCCEEDED |
| `69fd92d9-0000-2372-ad37-582429aca3ec` | `sq_marts_inventory_health` | [sq_marts_inventory_health.sql](./sq_marts_inventory_health.sql) | `msklad-bi-prod.marts.inventory_health` | every 24 hours | SUCCEEDED |
| `69ff34b4-0000-2b2b-a390-14c14ef7af10` | `sq_marts_sales_overview` | [sq_marts_sales_overview.sql](./sq_marts_sales_overview.sql) | `msklad-bi-prod.marts.sales_overview` | every 2 hours | SUCCEEDED |
| `6a004e88-0000-2e7d-bf20-9898fbb40f95` | `sq_marts_gmroi_by_folder` | [sq_marts_gmroi_by_folder.sql](./sq_marts_gmroi_by_folder.sql) | `msklad-bi-prod.marts.gmroi_by_folder` | every 24 hours | SUCCEEDED |
| `6a006664-0000-2739-86f5-7474463a7ac5` | `sq_marts_gmroi` | [sq_marts_gmroi.sql](./sq_marts_gmroi.sql) | `msklad-bi-prod.marts.gmroi` | every 24 hours | SUCCEEDED |
| `6a020b2c-0000-2dd6-96d2-883d24f52bd4` | `sq_marts_abc_xyz` | [sq_marts_abc_xyz.sql](./sq_marts_abc_xyz.sql) | `msklad-bi-prod.marts.abc_xyz` | every 24 hours | SUCCEEDED |
| `6a0aa537-0000-260f-b391-d43a2cee6b87` | `sq_marts_in_transit` | [sq_marts_in_transit.sql](./sq_marts_in_transit.sql) | `msklad-bi-prod.marts.in_transit` | every 24 hours | SUCCEEDED · уже канон в `03_PIPELINE_SPEC` §marts (PR-29) — здесь для полноты набора |
| `6a0b0f25-0000-2893-be44-d43a2cc31f97` | `sq_marts_supplier_price_history` | [sq_marts_supplier_price_history.sql](./sq_marts_supplier_price_history.sql) | `msklad-bi-prod.marts.supplier_price_history` | every 24 hours | SUCCEEDED |
| `6a1f9418-0000-276f-a1e4-d4f547ee7418` | `sq_marts_weight_flow` | [sq_marts_weight_flow.sql](./sq_marts_weight_flow.sql) | `msklad-bi-prod.marts.weight_flow` | every 24 hours | SUCCEEDED |
| `6a22a243-0000-20fd-a458-883d24f4cad4` | `sq_marts_expenses` | [sq_marts_expenses.sql](./sq_marts_expenses.sql) | `msklad-bi-prod.marts.expenses` | ⚠ не задан в transferConfig (см. наблюдения) | SUCCEEDED |
| `6a23f3ea-0000-2952-853d-582429be7ecc` | `sq_marts_customer_invoices_ar` | [sq_marts_customer_invoices_ar.sql](./sq_marts_customer_invoices_ar.sql) | `msklad-bi-prod.marts.customer_invoices_ar` | ⚠ не задан в transferConfig (см. наблюдения) | SUCCEEDED |

## Наблюдения (не решения — для человека/архитектора)

1. **Состав выборки шире, чем оценка в `07_STATE`/`04_ROADMAP`.** Q-5 сформулирован как «канонические
   SQL мартов» (~11 SQ + `in_transit`), но живой `bq ls` вернул **13** transferConfigs: 3 из них —
   `sq_audit_dim_*_snapshot` (аудит-снэпшоты `audit.*`, не марты). Я выгрузил **все 13** дословно
   (акцептанс-критерий брифа — «число `.sql`-файлов = числу transferConfigs из шага 1», без
   ограничения доменом), но правку `07_STATE`/`03_PIPELINE_SPEC` §marts предлагаю ограничить
   10 март-SQ — audit-снэпшоты домом не в §marts, а в отдельном будущем адресате (кандидат: новый
   GAP или §audit в `03_PIPELINE_SPEC`, решает архитектор).
2. **`sq_audit_dim_products_snapshot` в состоянии `FAILED`** на момент выгрузки (`updateTime`
   2026-05-07). SQL зафиксирован как есть (конфигурация, а не гарантированно рабочий код) —
   не патчить и не чинить в рамках этого discovery-брифа (вне scope D5).
3. **`sq_marts_expenses` и `sq_marts_customer_invoices_ar` не имеют поля `schedule`** в
   transferConfig (`scheduleOptionsV2.timeBasedSchedule` пустой) — то есть расписание не
   зафиксировано на уровне конфига (вероятно ручной/on-demand запуск через `destination_table_name_template`
   + `write_disposition: WRITE_TRUNCATE`). Не домысливаю периодичность — факт для отдельной
   фиксации, если это важно для §marts/§DQ.
4. **`sq_marts_expenses`** — целевая таблица `marts.expenses` реализует агрегацию **по
   `fact_payments`** (payment-based), тогда как ADR-006 (M-P3c, принят 2026-07-06) описывает
   методологию через `paymentout+cashout+loss` + `commissionreportin`. Это **не обязательно
   противоречие** (может быть разными слоями: сырой payment-фид vs. агрегированный dashboard-март),
   но стоит на глаз архитектора сверить с ADR-006 при заполнении §marts.expenses прозой —
   не блокирует Q-5, фиксирую как наблюдение, не тяну самостоятельный вывод.
