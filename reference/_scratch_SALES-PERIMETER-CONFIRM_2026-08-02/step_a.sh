#!/usr/bin/env bash
# SALES-PERIMETER-CONFIRM, часть A (класс A, read-only).
# Один скрипт на ШАГ (ADR-077 §6). Якоря date -u и gcloud auth list — первой И последней
# командой (ADR-055 §3/§4, ADR-063 §4). Печатаются СТРОКИ, не метка (ADR-044).
set -uo pipefail

P=msklad-bi-prod
UMAI=0276f431-2ff5-11ef-0a80-11d40019917f
BLOOM=3c080755-03ff-11f0-0a80-0c2c00104bbb
RVB=31d135bc-4df8-11f1-0a80-1c8a0053c5b4

echo "=== ЯКОРЬ НАЧАЛА ==="
date -u
gcloud auth list 2>&1
echo

echo "=== Q0. Контроль таблицы: всего строк в core.fact_commissionreportin ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson \
"SELECT COUNT(*) AS rows_total, COUNT(DISTINCT document_id) AS docs_total,
        MIN(moment) AS moment_min, MAX(moment) AS moment_max
 FROM \`$P.core.fact_commissionreportin\`"
echo

echo "=== Q1. Май-2026: документы commissionreportin в разрезе agent_id ==="
echo "--- окно: moment >= 2026-05-01 00:00:00 UTC AND moment < 2026-06-01 00:00:00 UTC"
echo "--- (дословно тот же фильтр, что у загрузчика, reference/code/cf-loss-commission/main.py:129)"
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson \
"SELECT agent_id,
        COUNT(DISTINCT document_id) AS docs,
        ROUND(SUM(reward_sum_kgs), 2)              AS reward_kgs,
        ROUND(SUM(commission_overhead_sum_kgs), 2) AS overhead_kgs,
        ROUND(SUM(sum_kgs), 2)                     AS total_kgs
 FROM \`$P.core.fact_commissionreportin\`
 WHERE moment >= TIMESTAMP('2026-05-01 00:00:00 UTC')
   AND moment <  TIMESTAMP('2026-06-01 00:00:00 UTC')
 GROUP BY agent_id
 ORDER BY docs DESC, agent_id"
echo

echo "=== Q2. Май-2026: построчно, документ за документом (провенанс, не агрегат) ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson \
"SELECT document_id, moment, agent_id, currency_code, rate_value,
        reward_sum_kgs, commission_overhead_sum_kgs, sum_kgs
 FROM \`$P.core.fact_commissionreportin\`
 WHERE moment >= TIMESTAMP('2026-05-01 00:00:00 UTC')
   AND moment <  TIMESTAMP('2026-06-01 00:00:00 UTC')
 ORDER BY moment"
echo

echo "=== Q3. Зона паритета (transaction_date >= 2026-05-01): отгрузки entity/demand,"
echo "===     выписанные на трёх контрагентов-маркетплейсов — масштаб дефекта признания выручки ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson \
"SELECT agent_id,
        COUNT(DISTINCT demand_id) AS demand_docs,
        COUNT(*)                  AS rows_cnt,
        MIN(transaction_date)     AS first_date,
        MAX(transaction_date)     AS last_date,
        ROUND(SUM(revenue_kgs), 2) AS revenue_kgs
 FROM \`$P.core.fact_sales_profit\`
 WHERE transaction_date >= DATE('2026-05-01')
   AND agent_id IN ('$UMAI', '$BLOOM', '$RVB')
 GROUP BY agent_id
 ORDER BY revenue_kgs DESC"
echo

echo "=== Q4. Та же выборка построчно по документам (провенанс) ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson \
"SELECT demand_id, order_name, agent_id, transaction_date,
        COUNT(*) AS positions, ROUND(SUM(revenue_kgs), 2) AS revenue_kgs
 FROM \`$P.core.fact_sales_profit\`
 WHERE transaction_date >= DATE('2026-05-01')
   AND agent_id IN ('$UMAI', '$BLOOM', '$RVB')
 GROUP BY demand_id, order_name, agent_id, transaction_date
 ORDER BY transaction_date"
echo

echo "=== Q5. Контроль зоны паритета: верхняя граница данных в core.fact_sales_profit ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson \
"SELECT MIN(transaction_date) AS min_date, MAX(transaction_date) AS max_date,
        COUNT(DISTINCT demand_id) AS demand_docs, COUNT(*) AS rows_cnt
 FROM \`$P.core.fact_sales_profit\`
 WHERE transaction_date >= DATE('2026-05-01')"
echo

echo "=== ЯКОРЬ КОНЦА ==="
date -u
gcloud auth list 2>&1
