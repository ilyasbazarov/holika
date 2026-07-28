# FILE: schema_dump_2026-07-28.md

# Schema dump — INFORMATION_SCHEMA.COLUMNS, msklad-bi-prod (region-asia-east1)

**Задача:** Q-4 (discovery). **Сессия:** executor, `briefs/Q-4.md`. **SHA сессии:** `dfe182d613687d79ec928c83de5161ba5e31da7b`.

**UTC-якорь начала:** `2026-07-28T17:37:57Z` · **UTC-якорь конца:** `2026-07-28T17:38:08Z` (полный прогон `dump_schema_v3.sh`, финальный, с `--max_rows=100000`).

**Личность:** `ilyasbazarov4@gmail.com` (подтверждена `gcloud auth list` в начале и конце скрипта).

**Метод:** дамп-скоуп — датасет-локальный `INFORMATION_SCHEMA.COLUMNS` (`` `msklad-bi-prod`.<dataset>.INFORMATION_SCHEMA.COLUMNS ``), не project/region-level. Причина: region-level запрос (`` `msklad-bi-prod`.`region-asia-east1`.INFORMATION_SCHEMA.COLUMNS ``, как в тексте брифа) вернул `Access Denied` (нет `bigquery.tables.list`/`bigquery.tables.get` на уровне проекта у `ilyasbazarov4@gmail.com`) — лог `run.log`. Датасет-скоупный запрос того же содержимого сработал под той же личностью (датасет-уровня прав достаточно) — эквивалентный охват, тот же источник данных, тот же режим read-only.

**Пойманный гэп наблюдения (закрыт этой же сессией, `05_CONVENTIONS` ★ «Успех инструмента ≠ факт»):** первый прогон дамп-запроса без `--max_rows` вернул `rc=0` и внешне валидный JSON, но `core`/`marts` были молча усечены до 100 строк каждый (дефолтный `--max_rows` CLI `bq`) — из `core` пропали 5 таблиц (`fact_purchases`, `fact_returns`, `fact_sales_profit`, `fact_payments_stg`, `fact_sales_profit_byvariant_backup`), полностью совпадающих по алфавиту с концом списка. Обнаружено сверкой с `INFORMATION_SCHEMA.TABLES` (полный список объектов датасета) и точечным запросом `COLUMNS` по каждой пропавшей таблице — все пять существуют и имеют полную схему. Финальный прогон — с `--max_rows=100000`, счётчик строк (542 по всем 4 датасетам) меньше лимита ⇒ усечения нет. Провенанс: `run.log` (region-level отказ), `run_v2.log` (усечённый прогон, диагностика), `run_tables_check.log` (сверка TABLES), `run_missing_tables_check.log` (точечная проверка 5 пропавших таблиц), `run_v3.log` (финальный полный прогон, источник таблиц ниже).

**Итог охвата:** 4 датасета, 40 таблиц, 542 колонки.

---

## Датасет `core` (15 таблиц, 183 колонок)

### `core.dim_counterparties`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | agent_id | STRING | YES |
| 2 | name | STRING | YES |
| 3 | owner_employee_id | STRING | YES |
| 4 | owner_employee_skey | STRING | YES |
| 5 | country | STRING | YES |
| 6 | scd2_valid_from | DATE | YES |
| 7 | scd2_valid_to | DATE | YES |
| 8 | scd2_is_current | BOOL | YES |
| 9 | _loaded_at | TIMESTAMP | YES |

### `core.dim_employees`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | employee_id | STRING | NO |
| 2 | full_name | STRING | YES |
| 3 | position | STRING | YES |
| 4 | email | STRING | YES |
| 5 | phone | STRING | YES |
| 6 | updated_at | TIMESTAMP | YES |
| 7 | _loaded_at | TIMESTAMP | NO |

### `core.dim_fx_rates`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | date | DATE | NO |
| 2 | rate_kgs_per_usd | FLOAT64 | NO |

### `core.dim_metadata_mappings`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | field_name | STRING | NO |
| 2 | entity_type | STRING | NO |
| 3 | current_uuid | STRING | NO |
| 4 | field_type | STRING | NO |
| 5 | last_verified | TIMESTAMP | NO |
| 6 | notes | STRING | YES |

### `core.dim_products`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | product_id | STRING | NO |
| 2 | name | STRING | YES |
| 3 | article | STRING | YES |
| 4 | product_folder | STRING | YES |
| 5 | parent_product_id | STRING | YES |
| 6 | entity_type | STRING | NO |
| 7 | created | DATE | YES |
| 8 | shelf_life | TIMESTAMP | YES |
| 9 | qty_per_box | INT64 | YES |
| 10 | is_exclusive | BOOL | YES |
| 11 | is_sunscreen | BOOL | YES |
| 12 | updated_at | TIMESTAMP | YES |
| 13 | _loaded_at | TIMESTAMP | NO |
| 14 | weight | FLOAT64 | YES |

### `core.fact_commissionreportin`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | document_id | STRING | YES |
| 2 | moment | TIMESTAMP | YES |
| 3 | agent_id | STRING | YES |
| 4 | currency_code | STRING | YES |
| 5 | rate_value | FLOAT64 | YES |
| 6 | reward_sum_kgs | FLOAT64 | YES |
| 7 | commission_overhead_sum_kgs | FLOAT64 | YES |
| 8 | sum_kgs | FLOAT64 | YES |
| 9 | _loaded_at | TIMESTAMP | YES |

### `core.fact_customer_invoices`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | invoice_id | STRING | NO |
| 2 | invoice_name | STRING | YES |
| 3 | moment | DATE | YES |
| 4 | agent_id | STRING | YES |
| 5 | agent_name | STRING | YES |
| 6 | state_id | STRING | YES |
| 7 | state_name | STRING | YES |
| 8 | sum_kgs | FLOAT64 | YES |
| 9 | payed_sum_kgs | FLOAT64 | YES |
| 10 | unpaid_sum_kgs | FLOAT64 | YES |
| 11 | payment_planned | DATE | YES |
| 12 | sales_channel_id | STRING | YES |
| 13 | sales_channel_name | STRING | YES |
| 14 | _loaded_at | TIMESTAMP | YES |

### `core.fact_inventory`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | date_snapshot | DATE | NO |
| 2 | product_id | STRING | NO |
| 3 | entity_type | STRING | YES |
| 4 | name | STRING | YES |
| 5 | stock | FLOAT64 | YES |
| 6 | reserve | FLOAT64 | YES |
| 7 | in_transit | FLOAT64 | YES |
| 8 | quantity_available | FLOAT64 | YES |
| 9 | stock_days | FLOAT64 | YES |
| 10 | cost_kgs | FLOAT64 | YES |
| 11 | _loaded_at | TIMESTAMP | NO |

### `core.fact_loss`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | document_id | STRING | YES |
| 2 | moment | TIMESTAMP | YES |
| 3 | expense_item_id | STRING | YES |
| 4 | expense_item_name | STRING | YES |
| 5 | agent_id | STRING | YES |
| 6 | agent_name | STRING | YES |
| 7 | project_id | STRING | YES |
| 8 | sales_channel_id | STRING | YES |
| 9 | currency_code | STRING | YES |
| 10 | rate_value | FLOAT64 | YES |
| 11 | sum_kgs | FLOAT64 | YES |
| 12 | _loaded_at | TIMESTAMP | YES |
| 13 | applicable | BOOL | YES |

### `core.fact_payments`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | payment_id | STRING | NO |
| 2 | payment_name | STRING | YES |
| 3 | payment_type | STRING | YES |
| 4 | moment | DATE | YES |
| 5 | expense_item_id | STRING | YES |
| 6 | expense_item_name | STRING | YES |
| 7 | agent_id | STRING | YES |
| 8 | agent_name | STRING | YES |
| 9 | project_id | STRING | YES |
| 10 | project_name | STRING | YES |
| 11 | sales_channel_id | STRING | YES |
| 12 | sales_channel_name | STRING | YES |
| 13 | payment_purpose | STRING | YES |
| 14 | sum_kgs | FLOAT64 | YES |
| 15 | _loaded_at | TIMESTAMP | YES |

### `core.fact_payments_stg`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | payment_id | STRING | YES |
| 2 | payment_name | STRING | YES |
| 3 | payment_type | STRING | YES |
| 4 | moment | DATE | YES |
| 5 | expense_item_id | STRING | YES |
| 6 | expense_item_name | STRING | YES |
| 7 | agent_id | STRING | YES |
| 8 | agent_name | STRING | YES |
| 9 | project_id | STRING | YES |
| 10 | project_name | STRING | YES |
| 11 | sales_channel_id | STRING | YES |
| 12 | sales_channel_name | STRING | YES |
| 13 | payment_purpose | STRING | YES |
| 14 | sum_kgs | FLOAT64 | YES |
| 15 | _loaded_at | TIMESTAMP | YES |

### `core.fact_purchases`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | purchase_order_id | STRING | NO |
| 2 | order_name | STRING | YES |
| 3 | position_id | STRING | YES |
| 4 | order_date | DATE | NO |
| 5 | planned_delivery_date | DATE | YES |
| 6 | product_id | STRING | YES |
| 7 | supplier_id | STRING | YES |
| 8 | quantity_ordered | FLOAT64 | YES |
| 9 | quantity_shipped | FLOAT64 | YES |
| 10 | quantity_in_transit | FLOAT64 | YES |
| 11 | price_kgs | FLOAT64 | YES |
| 12 | discount | FLOAT64 | YES |
| 13 | sum_kgs | FLOAT64 | YES |
| 14 | in_transit_sum_kgs | FLOAT64 | YES |
| 15 | currency_rate | FLOAT64 | YES |
| 16 | status_id | STRING | YES |
| 17 | status_name | STRING | YES |
| 18 | is_in_transit | BOOL | YES |
| 19 | _loaded_at | TIMESTAMP | YES |

### `core.fact_returns`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | return_id | STRING | NO |
| 2 | return_type | STRING | NO |
| 3 | return_date | DATE | NO |
| 4 | product_id | STRING | YES |
| 5 | agent_id | STRING | YES |
| 6 | quantity | FLOAT64 | YES |
| 7 | sum_kgs | FLOAT64 | YES |
| 8 | cost_kgs | FLOAT64 | YES |
| 9 | has_basis | BOOL | YES |
| 10 | _loaded_at | TIMESTAMP | NO |

### `core.fact_sales_profit`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | transaction_id | STRING | YES |
| 2 | transaction_date | DATE | YES |
| 3 | product_id | STRING | YES |
| 4 | entity_type | STRING | YES |
| 5 | agent_id | STRING | YES |
| 6 | sell_quantity | FLOAT64 | YES |
| 7 | return_quantity | FLOAT64 | YES |
| 8 | revenue_kgs | FLOAT64 | YES |
| 9 | cogs_kgs | FLOAT64 | YES |
| 10 | margin_kgs | FLOAT64 | YES |
| 11 | revenue_usd | FLOAT64 | YES |
| 12 | cogs_usd | FLOAT64 | YES |
| 13 | margin_usd | FLOAT64 | YES |
| 14 | _week_start | DATE | YES |
| 15 | _loaded_at | TIMESTAMP | YES |
| 16 | sell_sum_kgs | FLOAT64 | YES |
| 17 | return_sum_kgs | FLOAT64 | YES |
| 18 | discount | FLOAT64 | YES |
| 19 | sales_channel_id | STRING | YES |
| 20 | sales_channel_name | STRING | YES |
| 21 | project_id | STRING | YES |
| 22 | project_name | STRING | YES |

### `core.fact_sales_profit_byvariant_backup`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | transaction_id | STRING | YES |
| 2 | transaction_date | DATE | YES |
| 3 | product_id | STRING | YES |
| 4 | entity_type | STRING | YES |
| 5 | agent_id | STRING | YES |
| 6 | sell_quantity | FLOAT64 | YES |
| 7 | return_quantity | FLOAT64 | YES |
| 8 | sell_sum_kgs | FLOAT64 | YES |
| 9 | return_sum_kgs | FLOAT64 | YES |
| 10 | revenue_kgs | FLOAT64 | YES |
| 11 | cogs_kgs | FLOAT64 | YES |
| 12 | margin_kgs | FLOAT64 | YES |
| 13 | revenue_usd | FLOAT64 | YES |
| 14 | cogs_usd | FLOAT64 | YES |
| 15 | margin_usd | FLOAT64 | YES |
| 16 | _week_start | DATE | YES |
| 17 | _loaded_at | TIMESTAMP | YES |

---

## Датасет `marts` (11 таблиц, 212 колонок)

### `marts.abc_xyz`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | product_id | STRING | YES |
| 2 | product_name | STRING | YES |
| 3 | article | STRING | YES |
| 4 | product_folder | STRING | YES |
| 5 | entity_type | STRING | YES |
| 6 | parent_product_id | STRING | YES |
| 7 | abc_class | STRING | YES |
| 8 | revenue_90d_kgs | FLOAT64 | YES |
| 9 | margin_90d_kgs | FLOAT64 | YES |
| 10 | quantity_90d | FLOAT64 | YES |
| 11 | active_days_90d | INT64 | YES |
| 12 | revenue_90d_usd | FLOAT64 | YES |
| 13 | xyz_class | STRING | YES |
| 14 | cov | FLOAT64 | YES |
| 15 | weeks_with_sales | INT64 | YES |
| 16 | avg_weekly_qty | FLOAT64 | YES |
| 17 | abc_xyz | STRING | YES |
| 18 | rate_kgs_per_usd | FLOAT64 | YES |
| 19 | _mart_refreshed_at | TIMESTAMP | YES |

### `marts.customer_invoices_ar`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | agent_id | STRING | YES |
| 2 | agent_name | STRING | YES |
| 3 | country | STRING | YES |
| 4 | state_name | STRING | YES |
| 5 | state_id | STRING | YES |
| 6 | invoice_count | INT64 | YES |
| 7 | total_invoiced_kgs | FLOAT64 | YES |
| 8 | total_paid_kgs | FLOAT64 | YES |
| 9 | total_unpaid_kgs | FLOAT64 | YES |
| 10 | earliest_invoice_date | DATE | YES |
| 11 | latest_invoice_date | DATE | YES |
| 12 | overdue_count | INT64 | YES |

### `marts.expenses`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | moment | DATE | YES |
| 2 | month_start | DATE | YES |
| 3 | week_start | DATE | YES |
| 4 | year_num | INT64 | YES |
| 5 | year_month | STRING | YES |
| 6 | payment_type | STRING | YES |
| 7 | expense_item_id | STRING | YES |
| 8 | expense_item_name | STRING | YES |
| 9 | agent_id | STRING | YES |
| 10 | agent_name | STRING | YES |
| 11 | project_id | STRING | YES |
| 12 | project_name | STRING | YES |
| 13 | sales_channel_id | STRING | YES |
| 14 | sales_channel_name | STRING | YES |
| 15 | payment_count | INT64 | YES |
| 16 | total_sum_kgs | FLOAT64 | YES |
| 17 | total_sum_usd | FLOAT64 | YES |

### `marts.expenses_staging`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | moment | DATE | YES |
| 2 | month_start | DATE | YES |
| 3 | week_start | DATE | YES |
| 4 | year_num | INT64 | YES |
| 5 | year_month | STRING | YES |
| 6 | payment_type | STRING | YES |
| 7 | expense_item_id | STRING | YES |
| 8 | expense_item_name | STRING | YES |
| 9 | agent_id | STRING | YES |
| 10 | agent_name | STRING | YES |
| 11 | project_id | STRING | YES |
| 12 | project_name | STRING | YES |
| 13 | sales_channel_id | STRING | YES |
| 14 | sales_channel_name | STRING | YES |
| 15 | payment_count | INT64 | YES |
| 16 | total_sum_kgs | FLOAT64 | YES |
| 17 | total_sum_usd | FLOAT64 | YES |

### `marts.gmroi`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | period_days | INT64 | YES |
| 2 | product_id | STRING | YES |
| 3 | product_name | STRING | YES |
| 4 | product_folder | STRING | YES |
| 5 | parent_product_id | STRING | YES |
| 6 | revenue_kgs | FLOAT64 | YES |
| 7 | cogs_kgs | FLOAT64 | YES |
| 8 | gross_profit_kgs | FLOAT64 | YES |
| 9 | gross_margin_pct | FLOAT64 | YES |
| 10 | avg_inventory_kgs | FLOAT64 | YES |
| 11 | snapshot_count | INT64 | YES |
| 12 | gmroi | FLOAT64 | YES |
| 13 | revenue_usd | FLOAT64 | YES |
| 14 | gross_profit_usd | FLOAT64 | YES |
| 15 | avg_inventory_usd | FLOAT64 | YES |
| 16 | rate_kgs_per_usd | FLOAT64 | YES |
| 17 | is_inventory_missing | BOOL | YES |
| 18 | is_cogs_zero | BOOL | YES |
| 19 | _mart_refreshed_at | TIMESTAMP | YES |

### `marts.gmroi_by_folder`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | period_days | INT64 | YES |
| 2 | product_folder | STRING | YES |
| 3 | product_count | INT64 | YES |
| 4 | revenue_kgs | FLOAT64 | YES |
| 5 | cogs_kgs | FLOAT64 | YES |
| 6 | gross_profit_kgs | FLOAT64 | YES |
| 7 | total_avg_inventory_kgs | FLOAT64 | YES |
| 8 | gmroi_weighted | FLOAT64 | YES |
| 9 | gross_profit_usd | FLOAT64 | YES |
| 10 | avg_inventory_usd | FLOAT64 | YES |
| 11 | products_no_inventory | INT64 | YES |
| 12 | products_no_cogs | INT64 | YES |
| 13 | rate_kgs_per_usd | FLOAT64 | YES |
| 14 | _mart_refreshed_at | TIMESTAMP | YES |

### `marts.in_transit`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | order_name | STRING | YES |
| 2 | purchase_order_id | STRING | YES |
| 3 | position_id | STRING | YES |
| 4 | order_date | DATE | YES |
| 5 | planned_delivery_date | DATE | YES |
| 6 | days_until_delivery | INT64 | YES |
| 7 | is_overdue | BOOL | YES |
| 8 | product_id | STRING | YES |
| 9 | product_name | STRING | YES |
| 10 | product_folder | STRING | YES |
| 11 | supplier_id | STRING | YES |
| 12 | supplier_name | STRING | YES |
| 13 | status_name | STRING | YES |
| 14 | quantity_ordered | FLOAT64 | YES |
| 15 | quantity_shipped | FLOAT64 | YES |
| 16 | quantity_in_transit | FLOAT64 | YES |
| 17 | price_kgs | FLOAT64 | YES |
| 18 | in_transit_sum_kgs | FLOAT64 | YES |
| 19 | in_transit_sum_usd | FLOAT64 | YES |
| 20 | fx_rate_used | FLOAT64 | YES |
| 21 | _mart_refreshed_at | TIMESTAMP | YES |

### `marts.inventory_health`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | date_snapshot | DATE | YES |
| 2 | product_id | STRING | YES |
| 3 | product_name | STRING | YES |
| 4 | article | STRING | YES |
| 5 | product_folder | STRING | YES |
| 6 | entity_type | STRING | YES |
| 7 | parent_product_id | STRING | YES |
| 8 | stock | FLOAT64 | YES |
| 9 | reserve | FLOAT64 | YES |
| 10 | quantity_available | FLOAT64 | YES |
| 11 | stock_days | FLOAT64 | YES |
| 12 | cost_kgs | FLOAT64 | YES |
| 13 | frozen_capital_kgs | FLOAT64 | YES |
| 14 | frozen_capital_usd | FLOAT64 | YES |
| 15 | sold_quantity_30d | FLOAT64 | YES |
| 16 | revenue_30d_kgs | FLOAT64 | YES |
| 17 | active_days_30d | INT64 | YES |
| 18 | true_adt | FLOAT64 | YES |
| 19 | calendar_adt | FLOAT64 | YES |
| 20 | sold_quantity_7d | FLOAT64 | YES |
| 21 | sold_quantity_90d | FLOAT64 | YES |
| 22 | calendar_adt_90d | FLOAT64 | YES |
| 23 | coverage_days_true_adt | FLOAT64 | YES |
| 24 | coverage_days_90d_calendar | FLOAT64 | YES |
| 25 | is_oos | BOOL | YES |
| 26 | is_toxic | BOOL | YES |
| 27 | is_stagnant | BOOL | YES |
| 28 | is_low_stock | BOOL | YES |
| 29 | is_overstock | BOOL | YES |
| 30 | is_zero_cost | BOOL | YES |
| 31 | rate_kgs_per_usd | FLOAT64 | YES |
| 32 | _mart_refreshed_at | TIMESTAMP | YES |

### `marts.sales_overview`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | transaction_date | DATE | YES |
| 2 | week_start | DATE | YES |
| 3 | month_start | DATE | YES |
| 4 | iso_week_label | STRING | YES |
| 5 | product_id | STRING | YES |
| 6 | product_name | STRING | YES |
| 7 | article | STRING | YES |
| 8 | product_folder | STRING | YES |
| 9 | entity_type | STRING | YES |
| 10 | parent_product_id | STRING | YES |
| 11 | parent_product_name | STRING | YES |
| 12 | agent_id | STRING | YES |
| 13 | counterparty_name | STRING | YES |
| 14 | country | STRING | YES |
| 15 | owner_employee_id | STRING | YES |
| 16 | manager_name | STRING | YES |
| 17 | manager_position | STRING | YES |
| 18 | sales_channel_name | STRING | YES |
| 19 | project_name | STRING | YES |
| 20 | sell_quantity | FLOAT64 | YES |
| 21 | revenue_kgs | FLOAT64 | YES |
| 22 | cogs_kgs | FLOAT64 | YES |
| 23 | margin_kgs | FLOAT64 | YES |
| 24 | margin_kgs_adjusted | FLOAT64 | YES |
| 25 | margin_pct | FLOAT64 | YES |
| 26 | discount_percent | FLOAT64 | YES |
| 27 | return_quantity | FLOAT64 | YES |
| 28 | return_sum_kgs | FLOAT64 | YES |
| 29 | return_no_basis_sum_kgs | FLOAT64 | YES |
| 30 | return_doc_count | INT64 | YES |
| 31 | net_revenue_kgs | FLOAT64 | YES |
| 32 | net_quantity | FLOAT64 | YES |
| 33 | revenue_usd | FLOAT64 | YES |
| 34 | cogs_usd | FLOAT64 | YES |
| 35 | margin_usd | FLOAT64 | YES |
| 36 | return_sum_usd | FLOAT64 | YES |
| 37 | rate_kgs_per_usd | FLOAT64 | YES |
| 38 | is_cogs_missing | BOOL | YES |
| 39 | is_agent_missing | BOOL | YES |
| 40 | _mart_refreshed_at | TIMESTAMP | YES |

### `marts.supplier_price_history`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | order_date | DATE | YES |
| 2 | product_id | STRING | YES |
| 3 | product_name | STRING | YES |
| 4 | product_folder | STRING | YES |
| 5 | supplier_id | STRING | YES |
| 6 | supplier_name | STRING | YES |
| 7 | status_name | STRING | YES |
| 8 | quantity_ordered | FLOAT64 | YES |
| 9 | price_kgs | FLOAT64 | YES |
| 10 | price_usd | FLOAT64 | YES |
| 11 | sum_kgs | FLOAT64 | YES |
| 12 | fx_rate_used | FLOAT64 | YES |
| 13 | _mart_refreshed_at | TIMESTAMP | YES |

### `marts.weight_flow`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | flow_date | DATE | YES |
| 2 | week_start | DATE | YES |
| 3 | month_start | DATE | YES |
| 4 | flow_direction | STRING | YES |
| 5 | weight_kg | FLOAT64 | YES |
| 6 | positions_total | INT64 | YES |
| 7 | positions_with_weight | INT64 | YES |
| 8 | weight_coverage_pct | FLOAT64 | YES |

---

## Датасет `audit` (7 таблиц, 80 колонок)

### `audit.dim_counterparties_initial`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | agent_id | STRING | YES |
| 2 | name | STRING | YES |
| 3 | owner_employee_id | STRING | YES |
| 4 | country | STRING | YES |
| 5 | instagram | STRING | YES |
| 6 | telegram_username | STRING | YES |
| 7 | telegram_id | STRING | YES |
| 8 | vk | STRING | YES |
| 9 | avito | STRING | YES |
| 10 | max_id | STRING | YES |
| 11 | max_username | STRING | YES |
| 12 | responsible_employee_id | STRING | YES |
| 13 | allowed_debt_sum | STRING | YES |
| 14 | created_by_fintablo | BOOL | YES |
| 15 | updated_at | TIMESTAMP | YES |
| 16 | _loaded_at | TIMESTAMP | YES |
| 17 | owner_employee_skey | STRING | YES |
| 18 | scd2_valid_from | STRING | YES |
| 19 | scd2_valid_to | STRING | YES |
| 20 | scd2_is_current | BOOL | YES |
| 21 | snapshot_at | TIMESTAMP | YES |

### `audit.dim_counterparties_snapshots`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | agent_id | STRING | YES |
| 2 | name | STRING | YES |
| 3 | owner_employee_id | STRING | YES |
| 4 | owner_employee_skey | STRING | YES |
| 5 | country | STRING | YES |
| 6 | scd2_valid_from | DATE | YES |
| 7 | scd2_valid_to | DATE | YES |
| 8 | scd2_is_current | BOOL | YES |
| 9 | _loaded_at | TIMESTAMP | YES |
| 10 | snapshot_at | TIMESTAMP | YES |

### `audit.dim_employees_initial`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | employee_id | STRING | YES |
| 2 | full_name | STRING | YES |
| 3 | position | STRING | YES |
| 4 | email | STRING | YES |
| 5 | phone | STRING | YES |
| 6 | updated_at | TIMESTAMP | YES |
| 7 | _loaded_at | TIMESTAMP | YES |
| 8 | snapshot_at | TIMESTAMP | YES |

### `audit.dim_employees_snapshots`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | employee_id | STRING | YES |
| 2 | full_name | STRING | YES |
| 3 | position | STRING | YES |
| 4 | email | STRING | YES |
| 5 | phone | STRING | YES |
| 6 | updated_at | TIMESTAMP | YES |
| 7 | _loaded_at | TIMESTAMP | YES |
| 8 | snapshot_at | TIMESTAMP | YES |

### `audit.dim_products_initial`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | product_id | STRING | YES |
| 2 | name | STRING | YES |
| 3 | article | STRING | YES |
| 4 | product_folder | STRING | YES |
| 5 | parent_product_id | STRING | YES |
| 6 | entity_type | STRING | YES |
| 7 | created | DATE | YES |
| 8 | shelf_life | TIMESTAMP | YES |
| 9 | qty_per_box | INT64 | YES |
| 10 | is_exclusive | BOOL | YES |
| 11 | is_sunscreen | BOOL | YES |
| 12 | updated_at | TIMESTAMP | YES |
| 13 | _loaded_at | TIMESTAMP | YES |
| 14 | snapshot_at | TIMESTAMP | YES |

### `audit.dim_products_snapshots`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | product_id | STRING | YES |
| 2 | name | STRING | YES |
| 3 | article | STRING | YES |
| 4 | product_folder | STRING | YES |
| 5 | parent_product_id | STRING | YES |
| 6 | entity_type | STRING | YES |
| 7 | created | DATE | YES |
| 8 | shelf_life | TIMESTAMP | YES |
| 9 | qty_per_box | INT64 | YES |
| 10 | is_exclusive | BOOL | YES |
| 11 | is_sunscreen | BOOL | YES |
| 12 | updated_at | TIMESTAMP | YES |
| 13 | _loaded_at | TIMESTAMP | YES |
| 14 | snapshot_at | TIMESTAMP | YES |

### `audit.dq_runs`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | run_id | STRING | YES |
| 2 | check_name | STRING | YES |
| 3 | passed | BOOL | YES |
| 4 | detail | STRING | YES |
| 5 | checked_at | TIMESTAMP | YES |

---

## Датасет `stg_msklad` (7 таблиц, 67 колонок)

### `stg_msklad.byvariant_staging`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | product_id | STRING | YES |
| 2 | _week_start | DATE | YES |
| 3 | sell_quantity | FLOAT64 | YES |
| 4 | sell_sum_kgs | FLOAT64 | YES |
| 5 | cogs_kgs | FLOAT64 | YES |
| 6 | return_sum_kgs | FLOAT64 | YES |
| 7 | return_cost_kgs | FLOAT64 | YES |
| 8 | profit_kgs | FLOAT64 | YES |
| 9 | _loaded_at | TIMESTAMP | YES |

### `stg_msklad.counterparties_staging`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | agent_id | STRING | NO |
| 2 | name | STRING | YES |
| 3 | owner_employee_id | STRING | YES |
| 4 | country | STRING | YES |
| 5 | _loaded_at | STRING | YES |

### `stg_msklad.employees_staging`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | employee_id | STRING | NO |
| 2 | full_name | STRING | YES |
| 3 | position | STRING | YES |
| 4 | _loaded_at | STRING | YES |

### `stg_msklad.fact_commissionreportin_stg`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | document_id | STRING | YES |
| 2 | moment | TIMESTAMP | YES |
| 3 | agent_id | STRING | YES |
| 4 | currency_code | STRING | YES |
| 5 | rate_value | FLOAT64 | YES |
| 6 | reward_sum_kgs | FLOAT64 | YES |
| 7 | commission_overhead_sum_kgs | FLOAT64 | YES |
| 8 | sum_kgs | FLOAT64 | YES |
| 9 | _loaded_at | TIMESTAMP | YES |

### `stg_msklad.fact_loss_stg`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | document_id | STRING | YES |
| 2 | moment | TIMESTAMP | YES |
| 3 | expense_item_id | STRING | YES |
| 4 | expense_item_name | STRING | YES |
| 5 | agent_id | STRING | YES |
| 6 | agent_name | STRING | YES |
| 7 | project_id | STRING | YES |
| 8 | sales_channel_id | STRING | YES |
| 9 | currency_code | STRING | YES |
| 10 | rate_value | FLOAT64 | YES |
| 11 | applicable | BOOL | YES |
| 12 | sum_kgs | FLOAT64 | YES |
| 13 | _loaded_at | TIMESTAMP | YES |

### `stg_msklad.fact_sales_staging`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | run_id | STRING | YES |
| 2 | demand_id | STRING | YES |
| 3 | order_name | STRING | YES |
| 4 | position_id | STRING | YES |
| 5 | transaction_date_raw | STRING | YES |
| 6 | product_id | STRING | YES |
| 7 | agent_id | STRING | YES |
| 8 | quantity | FLOAT64 | YES |
| 9 | price_kgs | FLOAT64 | YES |
| 10 | discount | FLOAT64 | YES |
| 11 | revenue_kgs | FLOAT64 | YES |
| 12 | entity_type | STRING | YES |
| 13 | _loaded_at | TIMESTAMP | YES |
| 14 | sales_channel_id | STRING | YES |
| 15 | sales_channel_name | STRING | YES |
| 16 | project_id | STRING | YES |
| 17 | project_name | STRING | YES |

### `stg_msklad.products_staging`

| Позиция | Колонка | Тип | Nullable |
|---|---|---|---|
| 1 | product_id | STRING | NO |
| 2 | name | STRING | YES |
| 3 | article | STRING | YES |
| 4 | product_folder | STRING | YES |
| 5 | parent_product_id | STRING | YES |
| 6 | entity_type | STRING | YES |
| 7 | created | STRING | YES |
| 8 | shelf_life | TIMESTAMP | YES |
| 9 | weight | FLOAT64 | YES |
| 10 | _loaded_at | TIMESTAMP | YES |

---

## Провенанс — команда

```bash
bq query --use_legacy_sql=false --format=prettyjson --max_rows=100000 "
SELECT table_schema, table_name, column_name, data_type, is_nullable, ordinal_position
FROM \`msklad-bi-prod\`.<dataset>.INFORMATION_SCHEMA.COLUMNS
ORDER BY table_name, ordinal_position
"
```

Прогнано по одному разу на каждый из 4 датасетов (`core`, `marts`, `audit`, `stg_msklad`) в одном скрипте `reference/_scratch_Q-4_2026-07-28/dump_schema_v3.sh`. Полный лог: `reference/_scratch_Q-4_2026-07-28/run_v3.log`.
