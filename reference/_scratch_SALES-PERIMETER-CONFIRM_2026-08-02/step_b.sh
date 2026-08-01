#!/usr/bin/env bash
# SALES-PERIMETER-CONFIRM, часть A, шаг 2 (класс A, read-only).
# Повтор Q3-Q5 первого прогона под ЖИВУЮ схему core.fact_sales_profit:
# колонки demand_id/order_name в ней нет (она есть только у STAGING_SCHEMA,
# reference/code/cf-facts/bq_ops.py:46-63, таблица stg_msklad.fact_sales_staging).
# Живая схема снята `bq show --schema` — live_schema.log.
set -uo pipefail

P=msklad-bi-prod
UMAI=0276f431-2ff5-11ef-0a80-11d40019917f
BLOOM=3c080755-03ff-11f0-0a80-0c2c00104bbb
RVB=31d135bc-4df8-11f1-0a80-1c8a0053c5b4

echo "=== ЯКОРЬ НАЧАЛА ==="
date -u
gcloud auth list 2>&1
echo

echo "=== Q3'. Зона паритета: строки core.fact_sales_profit по трём контрагентам-маркетплейсам ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson \
"SELECT agent_id,
        COUNT(*)                   AS rows_cnt,
        MIN(transaction_date)      AS first_date,
        MAX(transaction_date)      AS last_date,
        COUNT(DISTINCT transaction_date) AS days,
        ROUND(SUM(revenue_kgs), 2) AS revenue_kgs
 FROM \`$P.core.fact_sales_profit\`
 WHERE transaction_date >= DATE('2026-05-01')
   AND agent_id IN ('$UMAI', '$BLOOM', '$RVB')
 GROUP BY agent_id
 ORDER BY revenue_kgs DESC"
echo

echo "=== Q4'. Та же выборка в разрезе суток (провенанс, построчно по датам) ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson \
"SELECT transaction_date, agent_id,
        COUNT(*) AS rows_cnt, ROUND(SUM(revenue_kgs), 2) AS revenue_kgs
 FROM \`$P.core.fact_sales_profit\`
 WHERE transaction_date >= DATE('2026-05-01')
   AND agent_id IN ('$UMAI', '$BLOOM', '$RVB')
 GROUP BY transaction_date, agent_id
 ORDER BY transaction_date"
echo

echo "=== Q5'. Контроль зоны паритета целиком ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson \
"SELECT MIN(transaction_date) AS min_date, MAX(transaction_date) AS max_date,
        COUNT(*) AS rows_cnt, ROUND(SUM(revenue_kgs), 2) AS revenue_kgs
 FROM \`$P.core.fact_sales_profit\`
 WHERE transaction_date >= DATE('2026-05-01')"
echo

echo "=== Q6'. Доля трёх контрагентов в зоне паритета (та же выборка, один запрос) ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson \
"SELECT CASE WHEN agent_id IN ('$UMAI', '$BLOOM', '$RVB') THEN 'маркетплейсы' ELSE 'прочие' END AS grp,
        COUNT(*) AS rows_cnt, ROUND(SUM(revenue_kgs), 2) AS revenue_kgs
 FROM \`$P.core.fact_sales_profit\`
 WHERE transaction_date >= DATE('2026-05-01')
 GROUP BY grp
 ORDER BY revenue_kgs DESC"
echo

echo "=== ЯКОРЬ КОНЦА ==="
date -u
gcloud auth list 2>&1
