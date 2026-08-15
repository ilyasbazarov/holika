-- §5(1) июль по manager_name (из витрины, после правки)
SELECT '1_jul_by_manager' AS check_id, manager_name, ROUND(SUM(revenue_kgs),2) AS revenue_kgs
FROM `msklad-bi-prod.marts.sales_overview`
WHERE transaction_date >= '2026-07-01' AND transaction_date < '2026-08-01'
GROUP BY manager_name ORDER BY revenue_kgs DESC;

-- §5(2) суммарная выручка по периодам (из витрины)
SELECT '2_jul' AS check_id, ROUND(SUM(revenue_kgs),2) AS revenue_kgs FROM `msklad-bi-prod.marts.sales_overview`
WHERE transaction_date >= '2026-07-01' AND transaction_date < '2026-08-01'
UNION ALL
SELECT '2_may', ROUND(SUM(revenue_kgs),2) FROM `msklad-bi-prod.marts.sales_overview`
WHERE transaction_date >= '2026-05-01' AND transaction_date < '2026-06-01'
UNION ALL
SELECT '2_apr', ROUND(SUM(revenue_kgs),2) FROM `msklad-bi-prod.marts.sales_overview`
WHERE transaction_date >= '2026-04-01' AND transaction_date < '2026-05-01'
UNION ALL
SELECT '2_all_history', ROUND(SUM(revenue_kgs),2) FROM `msklad-bi-prod.marts.sales_overview`;

-- §5(3) апрель по manager_name (историческая ветка, побайтово прежняя)
SELECT '3_apr_by_manager' AS check_id, manager_name, ROUND(SUM(revenue_kgs),2) AS revenue_kgs
FROM `msklad-bi-prod.marts.sales_overview`
WHERE transaction_date >= '2026-04-01' AND transaction_date < '2026-05-01'
GROUP BY manager_name ORDER BY revenue_kgs DESC;

-- §5(4) май по manager_name (новый разрез)
SELECT '4_may_by_manager' AS check_id, manager_name, ROUND(SUM(revenue_kgs),2) AS revenue_kgs
FROM `msklad-bi-prod.marts.sales_overview`
WHERE transaction_date >= '2026-05-01' AND transaction_date < '2026-06-01'
GROUP BY manager_name ORDER BY revenue_kgs DESC;
