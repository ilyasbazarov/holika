#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== ЯКОРЬ НАЧАЛА ==="; date -u; gcloud auth list 2>&1 | head -4; echo
echo "=== Снимок до деплоя против текущей таблицы, окно 90 суток ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 20 '
WITH now_t AS (
  SELECT COALESCE(sales_channel_name,"(NULL)") ch, COUNT(*) n, ROUND(SUM(revenue_kgs),2) rev
  FROM `msklad-bi-prod.core.fact_sales_profit`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) GROUP BY 1),
snap AS (
  SELECT COALESCE(sales_channel_name,"(NULL)") ch, COUNT(*) n, ROUND(SUM(revenue_kgs),2) rev
  FROM `msklad-bi-prod.core.fact_sales_profit_snap_20260811`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) GROUP BY 1)
SELECT COALESCE(now_t.ch, snap.ch) AS channel,
       snap.n AS rows_snapshot, now_t.n AS rows_now, now_t.n - snap.n AS delta_rows,
       snap.rev AS revenue_snapshot, now_t.rev AS revenue_now,
       ROUND(now_t.rev - snap.rev, 2) AS delta_revenue
FROM now_t FULL JOIN snap USING (ch) ORDER BY channel'
echo "=== ЯКОРЬ КОНЦА ==="; date -u
