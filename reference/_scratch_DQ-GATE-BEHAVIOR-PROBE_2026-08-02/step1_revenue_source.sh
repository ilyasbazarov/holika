#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Схема core.fact_sales_profit (INFORMATION_SCHEMA.COLUMNS) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT column_name, data_type, ordinal_position
FROM \`msklad-bi-prod\`.\`core\`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'fact_sales_profit'
ORDER BY ordinal_position
"

echo "=== Схема stg_msklad.fact_sales_staging (INFORMATION_SCHEMA.COLUMNS) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT column_name, data_type, ordinal_position
FROM \`msklad-bi-prod\`.\`stg_msklad\`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'fact_sales_staging'
ORDER BY ordinal_position
"

echo "=== COUNT(*) core.fact_sales_profit, transaction_date = 2026-08-01 ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT COUNT(*) AS row_count
FROM \`msklad-bi-prod\`.\`core\`.\`fact_sales_profit\`
WHERE transaction_date = DATE('2026-08-01')
"

echo "=== СУММА revenue_kgs core.fact_sales_profit, 2026-08-01 (бишкекские сутки, transaction_date уже Asia/Bishkek по контракту 02_ERP_CONTRACTS) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT
  SUM(revenue_kgs) AS sum_revenue_kgs,
  SUM(sell_sum_kgs) AS sum_sell_sum_kgs,
  COUNT(*) AS row_count
FROM \`msklad-bi-prod\`.\`core\`.\`fact_sales_profit\`
WHERE transaction_date = DATE('2026-08-01')
"

echo "=== COUNT(*) stg_msklad.fact_sales_staging, DATE(transaction_date_raw) = 2026-08-01 (контракт 02_ERP_CONTRACTS.md:404 предписывает DATE(transaction_date_raw) без доп. приведения часового пояса) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT COUNT(*) AS row_count
FROM \`msklad-bi-prod\`.\`stg_msklad\`.\`fact_sales_staging\`
WHERE DATE(transaction_date_raw) = DATE('2026-08-01')
"

echo "=== СУММА revenue_kgs stg_msklad.fact_sales_staging, DATE(transaction_date_raw) = 2026-08-01 ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT
  SUM(revenue_kgs) AS sum_revenue_kgs,
  COUNT(*) AS row_count
FROM \`msklad-bi-prod\`.\`stg_msklad\`.\`fact_sales_staging\`
WHERE DATE(transaction_date_raw) = DATE('2026-08-01')
"

echo "=== СРЕДНЕДНЕВНАЯ выручка core.fact_sales_profit за окно 2026-07-25..2026-07-31 (MA7 T-8..T-2 относительно target_date=2026-08-01) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT
  AVG(daily_rev) AS avg_daily_revenue_kgs,
  COUNT(*) AS days_present
FROM (
  SELECT transaction_date, SUM(revenue_kgs) AS daily_rev
  FROM \`msklad-bi-prod\`.\`core\`.\`fact_sales_profit\`
  WHERE transaction_date BETWEEN DATE('2026-07-25') AND DATE('2026-07-31')
  GROUP BY transaction_date
)
"

echo "=== СРЕДНЕДНЕВНАЯ выручка stg_msklad.fact_sales_staging за то же окно 2026-07-25..2026-07-31 (DATE(transaction_date_raw), TTL 14 дней — окно может быть частично вытеснено) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT
  AVG(daily_rev) AS avg_daily_revenue_kgs,
  COUNT(*) AS days_present
FROM (
  SELECT
    DATE(transaction_date_raw) AS staging_date,
    SUM(revenue_kgs) AS daily_rev
  FROM \`msklad-bi-prod\`.\`stg_msklad\`.\`fact_sales_staging\`
  WHERE DATE(transaction_date_raw) BETWEEN DATE('2026-07-25') AND DATE('2026-07-31')
  GROUP BY staging_date
)
"

echo "=== Разбивка по дням core.fact_sales_profit, 2026-07-25..2026-07-31 (для проверки полноты окна) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=100 "
SELECT transaction_date, SUM(revenue_kgs) AS daily_rev, COUNT(*) AS row_count
FROM \`msklad-bi-prod\`.\`core\`.\`fact_sales_profit\`
WHERE transaction_date BETWEEN DATE('2026-07-25') AND DATE('2026-07-31')
GROUP BY transaction_date
ORDER BY transaction_date
"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
