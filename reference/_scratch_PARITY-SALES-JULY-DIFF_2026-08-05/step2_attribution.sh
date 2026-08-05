#!/usr/bin/env bash
# PARITY-SALES-JULY-DIFF, уточнение: пропущенные сутки июля и состав корзины «менеджер не назначен».
# Класс A: только read-only bq query. Ни секретов, ни живых вызовов, ни записи.
set -u
P=msklad-bi-prod
D=reference/_scratch_PARITY-SALES-JULY-DIFF_2026-08-05
Q() { bq query --project_id=$P --use_legacy_sql=false --format=prettyjson --max_rows=1000 "$1"; }

echo "=== UTC ЯКОРЬ (начало) ==="; date -u
echo "=== ЛИЧНОСТЬ (начало) ==="; gcloud auth list 2>&1 | head -3

echo; echo "=== Q6 какие сутки июля отсутствуют в ядре ==="
Q "WITH d AS (SELECT day FROM UNNEST(GENERATE_DATE_ARRAY('2026-07-01','2026-07-31')) AS day),
   have AS (SELECT DISTINCT transaction_date AS day FROM \`$P.core.fact_sales_profit\`
            WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31')
   SELECT d.day AS missing_day, FORMAT_DATE('%A', d.day) AS weekday
   FROM d LEFT JOIN have USING(day) WHERE have.day IS NULL ORDER BY 1" | tee $D/q6_missing_days.json

echo; echo "=== Q7 контрагенты корзины «менеджер не назначен», июль-2026 ==="
Q "SELECT c.name AS counterparty, f.agent_id, COUNT(*) AS n_rows,
   ROUND(SUM(f.revenue_kgs),2) AS sum_revenue_kgs
   FROM \`$P.core.fact_sales_profit\` f
   JOIN \`$P.core.dim_counterparties\` c
     ON f.agent_id = c.agent_id AND c.scd2_is_current = TRUE
   WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
     AND c.owner_employee_id IS NULL
   GROUP BY 1,2 ORDER BY sum_revenue_kgs DESC" | tee $D/q7_no_owner_agents.json

echo; echo "=== Q8 канал продаж в разрезе менеджера (июль): где сидят 40 строк без канала ==="
Q "SELECT COALESCE(e.full_name,'(менеджер не назначен)') AS manager,
   COALESCE(f.sales_channel_name,'(NULL)') AS channel,
   COUNT(*) AS n_rows, ROUND(SUM(f.revenue_kgs),2) AS sum_revenue_kgs
   FROM \`$P.core.fact_sales_profit\` f
   LEFT JOIN \`$P.core.dim_counterparties\` c
     ON f.agent_id = c.agent_id AND c.scd2_is_current = TRUE
   LEFT JOIN \`$P.core.dim_employees\` e ON c.owner_employee_id = e.employee_id
   WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
     AND f.sales_channel_name IS NULL
   GROUP BY 1,2 ORDER BY sum_revenue_kgs DESC" | tee $D/q8_null_channel_by_manager.json

echo; echo "=== UTC ЯКОРЬ (конец) ==="; date -u
echo "=== ЛИЧНОСТЬ (конец) ==="; gcloud auth list 2>&1 | head -3
echo "АРТЕФАКТЫ: $D"
