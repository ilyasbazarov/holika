# FX Outbound Coverage — покрытие core.dim_fx_rates + скан 13 SQ на latest_fx

**Дата (локальная, Бишкек, ADR-046 §1):** 2026-07-26
**Сессия:** FX-OUTBOUND-COVERAGE (discovery, ADR-039 §4/§5)

## §1 Покрытие core.dim_fx_rates

Источник: `bq query`, выполнено 2026-07-26T13:44:00Z (лог /tmp/fx_step12_*.log).

- min_date = 2025-04-29
- max_date = 2026-07-26
- rows_total = 454
- distinct_dates = 454
- span_days = 454

Независимая перепроверка (ADR-021 §2): distinct_dates = span_days = rows_total = 454 —
математически исключает дыры без доверия к единственному запросу.

Дыры внутри окна (Шаг 3, bq query, 2026-07-26T13:43:47Z,
лог /tmp/fx_step3_diag_20260726T134347Z.log): **список пуст — пропусков нет**,
подтверждено независимо совпадением чисел выше.

**Находка сверх задания брифа:** min_date = 2025-04-29 — на ~13 месяцев раньше
документированного начала источника Bakai OpenBanking (02 §core.dim_fx_rates:
«с 2026-06-03»). Причина не установлена (read-only, вне scope брифа) — факт
для архитектора, не решение.

### Помесячная разбивка (Шаг 2)

| Месяц | Дней в таблице | Календарных дней | Полное покрытие |
|---|---|---|---|
| 2025-04 | 2 | 30 | частично (окно началось 29-го) |
| 2025-05 | 31 | 31 | да |
| 2025-06 | 30 | 30 | да |
| 2025-07 | 31 | 31 | да |
| 2025-08 | 31 | 31 | да |
| 2025-09 | 30 | 30 | да |
| 2025-10 | 31 | 31 | да |
| 2025-11 | 30 | 30 | да |
| 2025-12 | 31 | 31 | да |
| 2026-01 | 31 | 31 | да |
| 2026-02 | 28 | 28 | да |
| 2026-03 | 31 | 31 | да |
| 2026-04 | 30 | 30 | да |
| 2026-05 | 31 | 31 | **да** |
| 2026-06 | 30 | 30 | да |
| 2026-07 | 26 | 26 (на дату выгрузки) | да, по 26 июля включительно |

## §2 Скан 13 SQ на паттерн latest_fx

Источник: grep -n + контекст ±5 строк на /tmp/holika_clone/reference/sql/*.sql,
2026-07-26T13:46:41Z (лог /tmp/fx_step4_20260726T134641Z.log). Вердикт по
прочитанному блоку, не по совпадению токена (ADR-044 §3).

| Файл | dim_fx_rates? | Паттерн | Вердикт | Строки |
|---|---|---|---|---|
| sq_audit_dim_counterparties_snapshot.sql | нет | — | НЕТ | — |
| sq_audit_dim_employees_snapshot.sql | нет | — | НЕТ | — |
| sq_audit_dim_products_snapshot.sql | нет | — | НЕТ | — |
| sq_marts_abc_xyz.sql | да | latest_fx (WHERE date=MAX(date), = ORDER BY DESC LIMIT 1 по смыслу) | **ДА** | 28-30, 34, 38 |
| sq_marts_customer_invoices_ar.sql | нет | — | НЕТ | — |
| sq_marts_expenses.sql | да | канонический ORDER BY date DESC LIMIT 1 | **ДА** | 19, 22-25, 33 |
| sq_marts_gmroi_by_folder.sql | нет (прямого запроса нет) | косвенно: MAX(rate_kgs_per_usd) из marts.gmroi | **КОСВЕННО** | 1 |
| sq_marts_gmroi.sql | да | latest_fx (WHERE date=MAX(date)) | **ДА** | 13-15, 21-22 |
| sq_marts_in_transit.sql | да | канонический ORDER BY date DESC LIMIT 1, документирован в 03 §marts как TO-BE канон | **ДА** | 4-8, 36-37 |
| sq_marts_inventory_health.sql | да | latest_fx (WHERE date=MAX(date)) | **ДА** | 73-76, 98, 180 |
| sq_marts_sales_overview.sql | да | НЕ latest_fx — LEFT JOIN dim_fx_rates fx ON f.transaction_date = fx.date | **НЕТ** (корректный per-date join) | 120-121 |
| sq_marts_supplier_price_history.sql | да | гибрид: основной join по дате заказа, ORDER BY DESC LIMIT 1 только как fallback при NULL | **ЧАСТИЧНО** | 15-21, 29-30 |
| sq_marts_weight_flow.sql | нет | — | НЕТ | — |

**Итог:** 5 файлов используют latest_fx как основной путь конвертации:
abc_xyz, expenses, gmroi, in_transit, inventory_health. 1 файл (supplier_price_history) —
как fallback. 1 файл (gmroi_by_folder) наследует эффект косвенно. 1 файл
(sales_overview) джойнит dim_fx_rates корректно, по дате. 5 файлов dim_fx_rates
не используют вовсе.

Сверх ранее известных expenses/in_transit (ADR-039 §5) — 4 дополнительных
точки экспозиции: abc_xyz, gmroi, inventory_health (полный latest_fx),
supplier_price_history (частичный, fallback).

## §3 Прямой ответ по май-2026

(i) Есть ли хотя бы одна дата мая-2026 в dim_fx_rates — **ДА**.
(ii) Покрыты ли все даты мая-2026 — **ДА**, все 31 (first_day=2026-05-01,
last_day=2026-05-31, days_cnt=31=rows_cnt).

## §4 Команды и сырой вывод

(см. /tmp/fx_step12_*.log и /tmp/fx_step4_*.log — полные логи приведены в
сессионной переписке; при коммите артефакта приложить как есть)
