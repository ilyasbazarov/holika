#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== ЯКОРЬ НАЧАЛА ==="; date -u; gcloud auth list 2>&1 | head -4; echo
echo "=== A. Состав ядра за последние 7 суток (окно часового promote) ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 20 '
SELECT COALESCE(sales_channel_name,"(NULL)") AS channel, COUNT(*) n_rows,
       ROUND(SUM(revenue_kgs),2) revenue_kgs, MIN(transaction_date) min_d, MAX(transaction_date) max_d
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY channel ORDER BY n_rows DESC'
echo
echo "=== B. Задания MERGE к ядру за последние 12 часов (сработал ли промоут после деплоя) ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 20 '
SELECT creation_time, user_email, statement_type,
       total_slot_ms, cache_hit,
       SUBSTR(REGEXP_REPLACE(query, r"\s+", " "), 1, 90) AS q_head
FROM `msklad-bi-prod`.`region-asia-east1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR)
  AND statement_type = "MERGE"
ORDER BY creation_time DESC'
echo "=== ЯКОРЬ КОНЦА ==="; date -u; gcloud auth list 2>&1 | head -4
