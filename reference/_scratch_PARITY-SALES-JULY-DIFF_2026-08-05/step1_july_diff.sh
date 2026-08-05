#!/usr/bin/env bash
# PARITY-SALES-JULY-DIFF, шаги 1-4. Класс A: только read-only bq query к нашим таблицам.
# Ни одного живого вызова к МойСкладу, ни одного чтения секретов, ни одной записи.
set -u
P=msklad-bi-prod
D=reference/_scratch_PARITY-SALES-JULY-DIFF_2026-08-05
Q() { bq query --project_id=$P --use_legacy_sql=false --format=prettyjson --max_rows=1000 "$1"; }

echo "=== UTC ЯКОРЬ (начало) ==="; date -u
echo "=== ЛИЧНОСТЬ (начало) ==="; gcloud auth list 2>&1 | head -5

echo; echo "=== Q1a ядро core.fact_sales_profit, июль-2026 ==="
Q "SELECT COUNT(*) AS n_rows, COUNT(DISTINCT transaction_date) AS n_days,
   ROUND(SUM(revenue_kgs),2) AS sum_revenue_kgs,
   MIN(transaction_date) AS d_min, MAX(transaction_date) AS d_max,
   CAST(MAX(_loaded_at) AS STRING) AS max_loaded_at
   FROM \`$P.core.fact_sales_profit\`
   WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'" | tee $D/q1a_core_july.json

echo; echo "=== Q1b витрина marts.sales_overview, июль-2026 ==="
Q "SELECT COUNT(*) AS n_rows, ROUND(SUM(revenue_kgs),2) AS sum_revenue_kgs,
   CAST(MAX(_mart_refreshed_at) AS STRING) AS mart_refreshed_at
   FROM \`$P.marts.sales_overview\`
   WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'" | tee $D/q1b_mart_july.json

echo; echo "=== Q2 разрез по каналам продаж, ядро, июль-2026 ==="
Q "SELECT COALESCE(sales_channel_name,'(NULL)') AS channel, COUNT(*) AS n_rows,
   ROUND(SUM(revenue_kgs),2) AS sum_revenue_kgs
   FROM \`$P.core.fact_sales_profit\`
   WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
   GROUP BY 1 ORDER BY sum_revenue_kgs DESC" | tee $D/q2_channels.json

echo; echo "=== Q3 разрез по менеджеру ТЕМ ЖЕ джойном, что и витрина, июль-2026 ==="
Q "SELECT COALESCE(e.full_name,'(менеджер не назначен)') AS manager, COUNT(*) AS n_rows,
   ROUND(SUM(f.revenue_kgs),2) AS sum_revenue_kgs
   FROM \`$P.core.fact_sales_profit\` f
   LEFT JOIN \`$P.core.dim_counterparties\` c
     ON f.agent_id = c.agent_id AND c.scd2_is_current = TRUE
   LEFT JOIN \`$P.core.dim_employees\` e ON c.owner_employee_id = e.employee_id
   WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
   GROUP BY 1 ORDER BY sum_revenue_kgs DESC" | tee $D/q3_managers.json

echo; echo "=== Q4 замыкание разреза: сумма по менеджерам против итога ядра + непроатрибутированное ==="
Q "SELECT ROUND(SUM(f.revenue_kgs),2) AS total_core,
   ROUND(SUM(CASE WHEN f.agent_id IS NULL THEN f.revenue_kgs ELSE 0 END),2) AS no_agent_id,
   ROUND(SUM(CASE WHEN f.agent_id IS NOT NULL AND c.agent_id IS NULL THEN f.revenue_kgs ELSE 0 END),2) AS agent_not_in_dim,
   ROUND(SUM(CASE WHEN c.agent_id IS NOT NULL AND c.owner_employee_id IS NULL THEN f.revenue_kgs ELSE 0 END),2) AS no_owner,
   ROUND(SUM(CASE WHEN c.owner_employee_id IS NOT NULL AND e.employee_id IS NULL THEN f.revenue_kgs ELSE 0 END),2) AS owner_not_in_dim,
   COUNT(*) AS n_rows_after_join
   FROM \`$P.core.fact_sales_profit\` f
   LEFT JOIN \`$P.core.dim_counterparties\` c
     ON f.agent_id = c.agent_id AND c.scd2_is_current = TRUE
   LEFT JOIN \`$P.core.dim_employees\` e ON c.owner_employee_id = e.employee_id
   WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'" | tee $D/q4_closure.json

echo; echo "=== Q5 контроль размножения строк джойном (дубли scd2_is_current) ==="
Q "SELECT COUNT(*) AS agents_with_multiple_current_rows FROM (
     SELECT agent_id FROM \`$P.core.dim_counterparties\`
     WHERE scd2_is_current = TRUE GROUP BY agent_id HAVING COUNT(*) > 1)" | tee $D/q5_fanout.json

echo; echo "=== UTC ЯКОРЬ (конец) ==="; date -u
echo "=== ЛИЧНОСТЬ (конец) ==="; gcloud auth list 2>&1 | head -5
echo "АРТЕФАКТЫ: $D"
