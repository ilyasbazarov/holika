#!/bin/bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"
LOCATION="asia-east1"

echo ""
echo "=== core.* — MIN/MAX/COUNT(DISTINCT)/COUNT(*) по _loaded_at, все 15 таблиц ==="
bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --max_rows=1000 --format=prettyjson "
SELECT 'dim_counterparties' AS table_name, MIN(_loaded_at) AS min_loaded_at, MAX(_loaded_at) AS max_loaded_at, COUNT(DISTINCT _loaded_at) AS n_distinct, COUNT(*) AS n_rows FROM \`${PROJECT}.core.dim_counterparties\`
UNION ALL SELECT 'dim_employees', MIN(_loaded_at), MAX(_loaded_at), COUNT(DISTINCT _loaded_at), COUNT(*) FROM \`${PROJECT}.core.dim_employees\`
UNION ALL SELECT 'dim_products', MIN(_loaded_at), MAX(_loaded_at), COUNT(DISTINCT _loaded_at), COUNT(*) FROM \`${PROJECT}.core.dim_products\`
UNION ALL SELECT 'fact_commissionreportin', MIN(_loaded_at), MAX(_loaded_at), COUNT(DISTINCT _loaded_at), COUNT(*) FROM \`${PROJECT}.core.fact_commissionreportin\`
UNION ALL SELECT 'fact_customer_invoices', MIN(_loaded_at), MAX(_loaded_at), COUNT(DISTINCT _loaded_at), COUNT(*) FROM \`${PROJECT}.core.fact_customer_invoices\`
UNION ALL SELECT 'fact_inventory', MIN(_loaded_at), MAX(_loaded_at), COUNT(DISTINCT _loaded_at), COUNT(*) FROM \`${PROJECT}.core.fact_inventory\`
UNION ALL SELECT 'fact_loss', MIN(_loaded_at), MAX(_loaded_at), COUNT(DISTINCT _loaded_at), COUNT(*) FROM \`${PROJECT}.core.fact_loss\`
UNION ALL SELECT 'fact_payments', MIN(_loaded_at), MAX(_loaded_at), COUNT(DISTINCT _loaded_at), COUNT(*) FROM \`${PROJECT}.core.fact_payments\`
UNION ALL SELECT 'fact_payments_stg', MIN(_loaded_at), MAX(_loaded_at), COUNT(DISTINCT _loaded_at), COUNT(*) FROM \`${PROJECT}.core.fact_payments_stg\`
UNION ALL SELECT 'fact_purchases', MIN(_loaded_at), MAX(_loaded_at), COUNT(DISTINCT _loaded_at), COUNT(*) FROM \`${PROJECT}.core.fact_purchases\`
UNION ALL SELECT 'fact_returns', MIN(_loaded_at), MAX(_loaded_at), COUNT(DISTINCT _loaded_at), COUNT(*) FROM \`${PROJECT}.core.fact_returns\`
UNION ALL SELECT 'fact_sales_profit', MIN(_loaded_at), MAX(_loaded_at), COUNT(DISTINCT _loaded_at), COUNT(*) FROM \`${PROJECT}.core.fact_sales_profit\`
UNION ALL SELECT 'fact_sales_profit_byvariant_backup', MIN(_loaded_at), MAX(_loaded_at), COUNT(DISTINCT _loaded_at), COUNT(*) FROM \`${PROJECT}.core.fact_sales_profit_byvariant_backup\`
ORDER BY table_name
"

echo ""
echo "=== core.dim_employees / core.dim_products — вторая колонка времени updated_at ==="
bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --format=prettyjson "
SELECT 'dim_employees' AS table_name, MIN(updated_at) AS min_updated_at, MAX(updated_at) AS max_updated_at, COUNT(DISTINCT updated_at) AS n_distinct, COUNT(*) AS n_rows FROM \`${PROJECT}.core.dim_employees\`
UNION ALL SELECT 'dim_products', MIN(updated_at), MAX(updated_at), COUNT(DISTINCT updated_at), COUNT(*) FROM \`${PROJECT}.core.dim_products\`
"

echo ""
echo "=== core.dim_metadata_mappings — last_verified (единственная колонка времени) ==="
bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --format=prettyjson "
SELECT MIN(last_verified) AS min_v, MAX(last_verified) AS max_v, COUNT(DISTINCT last_verified) AS n_distinct, COUNT(*) AS n_rows
FROM \`${PROJECT}.core.dim_metadata_mappings\`
"

echo ""
echo "=== core.dim_fx_rates — колонки времени загрузки нет; бизнес-колонка date для контекста ==="
bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --format=prettyjson "
SELECT MIN(date) AS min_date, MAX(date) AS max_date, COUNT(DISTINCT date) AS n_distinct, COUNT(*) AS n_rows
FROM \`${PROJECT}.core.dim_fx_rates\`
"

echo ""
echo "=== marts.* — MIN/MAX/COUNT(DISTINCT)/COUNT(*) по _mart_refreshed_at, 7 таблиц ==="
bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --format=prettyjson "
SELECT 'abc_xyz' AS table_name, MIN(_mart_refreshed_at) AS min_r, MAX(_mart_refreshed_at) AS max_r, COUNT(DISTINCT _mart_refreshed_at) AS n_distinct, COUNT(*) AS n_rows FROM \`${PROJECT}.marts.abc_xyz\`
UNION ALL SELECT 'gmroi', MIN(_mart_refreshed_at), MAX(_mart_refreshed_at), COUNT(DISTINCT _mart_refreshed_at), COUNT(*) FROM \`${PROJECT}.marts.gmroi\`
UNION ALL SELECT 'gmroi_by_folder', MIN(_mart_refreshed_at), MAX(_mart_refreshed_at), COUNT(DISTINCT _mart_refreshed_at), COUNT(*) FROM \`${PROJECT}.marts.gmroi_by_folder\`
UNION ALL SELECT 'in_transit', MIN(_mart_refreshed_at), MAX(_mart_refreshed_at), COUNT(DISTINCT _mart_refreshed_at), COUNT(*) FROM \`${PROJECT}.marts.in_transit\`
UNION ALL SELECT 'inventory_health', MIN(_mart_refreshed_at), MAX(_mart_refreshed_at), COUNT(DISTINCT _mart_refreshed_at), COUNT(*) FROM \`${PROJECT}.marts.inventory_health\`
UNION ALL SELECT 'sales_overview', MIN(_mart_refreshed_at), MAX(_mart_refreshed_at), COUNT(DISTINCT _mart_refreshed_at), COUNT(*) FROM \`${PROJECT}.marts.sales_overview\`
UNION ALL SELECT 'supplier_price_history', MIN(_mart_refreshed_at), MAX(_mart_refreshed_at), COUNT(DISTINCT _mart_refreshed_at), COUNT(*) FROM \`${PROJECT}.marts.supplier_price_history\`
ORDER BY table_name
"

echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
