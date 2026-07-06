# 03 · PIPELINE_SPEC — Доменная логика ядра

**Версия:** 0.1 (скелет, M-P3a) · **Статус:** SEMI-STABLE
**Назначение:** доменная логика пайплайна — режимы Cloud Functions, DQ-чеки/пороги, семантика загрузок (MERGE/DELETE, Ghost Records), логика мартов, ABC/XYZ, инварианты данных.
Секции — скелет: заголовок + указатель трассировки. Прод-наполнение прозой — P4.

---

## §режимы cf-facts

<!-- P4: из PR-09 (hourly/promote/weekly/returns/purchases + window_days) + PR-17 (окна, имена таблиц, IN_TRANSIT_STATUS_ID; UUID статусов — DROP-DUP, см. §справочные данные 02). -->

## §cf-finance

<!-- P4: из PR-14 (канонический порядок run_etl, 5 шагов), PR-13 (поведение: полный re-fetch без окна, trigger_marts/PermissionDenied), PR-35 правило 41 (re-fetch всей истории, риск таймаута; DROP-DUP c PR-13). -->

## §cf-fx

<!-- P4: из PR-18 (топология/поведение: MERGE-идемпотентность, graceful degradation 401→forward-fill, GCS-архив). URL/секрет — в 11_INFRA_FACTS; TTL токена — GAP Q-7. -->

## §DQ — чеки и пороги

<!-- P4: из PR-31 (6 чеков + пороги), PR-19 (DRIFT 0.10/0.03, FRESHNESS 3, CURRENCY 10M), PR-34 правило 25 (стандарт T-1). ⚠ GAP Q-6: актуальная ревизия cf-dq после T-1-фикса. ⚠ Противоречие источника: пороги свежести разбросаны (DQ 3д / алерт 6ч / проверка 2ч) — свести в одну таблицу с указанием механизма (P4). -->

## §marts — логика мартов и ABC/XYZ

<!-- P4: из PR-29 (sales_overview, inventory_health, in_transit + канонический SQL in_transit), PR-30 (supplier_price_history, weight_flow, customer_invoices_ar, expenses, abc_xyz + пороги ABC/XYZ). ⚠ GAP Q-5: канонические SQL остальных ~11 SQ только в живых transferConfigs → выгрузка в /reference/sql/. -->

## §fact_payments — семантика загрузки (Ghost Records)

<!-- P4: из PR-27 (applicable=False, отказ от EXCLUDE на Python, DELETE после MERGE), PR-34 правило 26 (фильтрация статей ТОЛЬКО через DELETE после MERGE) + кандидат в ретро-ADR (06, P5). Счётчики записей — в 07_STATE. -->

## §операционные инварианты

<!-- P4: из PR-33 правила 18–20 (в т.ч. условия manual promote — доменное правило). -->

## §инварианты данных

<!-- P4: из RB-20 (FIFO пересчитывается, 90д — норма), RB-30 (>50 кг = ошибка ввода weight), RB-22 (SCD2-семантика dim_counterparties, дополняет PR-26). -->

## §конвертация валют (доменная логика)

<!-- P4: из RB-38 п.26.6 (различение входящей/исходящей конвертации). Термин — в 09_GLOSSARY; контрактный факт минорных единиц — в 02 §валюты. -->
