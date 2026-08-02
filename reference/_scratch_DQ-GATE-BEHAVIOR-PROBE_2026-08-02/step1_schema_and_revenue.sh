#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Схема core.fact_sales_profit (INFORMATION_SCHEMA.COLUMNS) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT column_name, data_type
FROM \`msklad-bi-prod\`.\`core\`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'fact_sales_profit'
ORDER BY ordinal_position
"

echo "=== Схема stg_msklad.fact_sales_staging (INFORMATION_SCHEMA.COLUMNS) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT column_name, data_type
FROM \`msklad-bi-prod\`.\`stg_msklad\`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'fact_sales_staging'
ORDER BY ordinal_position
"

echo "=== core.fact_sales_profit: сумма revenue_kgs за 2026-08-01 (бишкекские сутки = дата столбца transaction_date, DATE) + независимый COUNT(*) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT
  COUNT(*) AS row_count,
  SUM(revenue_kgs) AS revenue_kgs_sum
FROM \`msklad-bi-prod\`.\`core\`.\`fact_sales_profit\`
WHERE transaction_date = '2026-08-01'
"

echo "=== stg_msklad.fact_sales_staging: сумма revenue_kgs за 2026-08-01 бишкекские сутки (parse transaction_date_raw как в bq_ops.py) + независимый COUNT(*) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT
  COUNT(*) AS row_count,
  SUM(revenue_kgs) AS revenue_kgs_sum
FROM \`msklad-bi-prod\`.\`stg_msklad\`.\`fact_sales_staging\`
WHERE DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek') = '2026-08-01'
"

echo "=== core.fact_sales_profit: среднедневная выручка за окно 2026-07-25..2026-07-31 (T-8..T-2 относительно target_date=2026-08-01) + независимый COUNT(*) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT
  COUNT(*) AS row_count,
  SUM(revenue_kgs) AS revenue_kgs_sum_window,
  SUM(revenue_kgs) / 7 AS avg_daily_revenue_kgs
FROM \`msklad-bi-prod\`.\`core\`.\`fact_sales_profit\`
WHERE transaction_date BETWEEN '2026-07-25' AND '2026-07-31'
"

echo "=== stg_msklad.fact_sales_staging: среднедневная выручка за окно 2026-07-25..2026-07-31 + независимый COUNT(*) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT
  COUNT(*) AS row_count,
  SUM(revenue_kgs) AS revenue_kgs_sum_window,
  SUM(revenue_kgs) / 7 AS avg_daily_revenue_kgs
FROM \`msklad-bi-prod\`.\`stg_msklad\`.\`fact_sales_staging\`
WHERE DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek') BETWEEN '2026-07-25' AND '2026-07-31'
"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
