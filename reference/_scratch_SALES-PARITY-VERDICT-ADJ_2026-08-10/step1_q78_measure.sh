#!/usr/bin/env bash
# SALES-PARITY-VERDICT-ADJ · шаг 1 · остаток Q-78: закрылся ли разрез по сотрудникам
# после деплоя SALES-DOCUMENT-OWNER-DEPLOY (2026-08-08, cf-facts-00010-mog).
# Класс A: read-only BigQuery. Ни одной записи, ни одного вызова к МойСкладу.
# ADR-055/063: date -u и gcloud auth list — первой И последней командой.
# BQ-QUERY-MAX-ROWS (proposed): -n задаётся явно, иначе json тихо режется до 100 строк.
set -u
P=msklad-bi-prod

echo "=== ЯКОРЬ НАЧАЛА ==="; date -u; gcloud auth list 2>&1 | head -5; echo

echo "=== Q1: покрытие document_owner_employee_id, июль-2026 ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 10 '
SELECT
  COUNT(*)                                                             AS n_rows,
  ROUND(SUM(revenue_kgs),2)                                            AS revenue_kgs,
  COUNTIF(document_owner_employee_id IS NULL)                          AS n_rows_no_owner,
  ROUND(SUM(IF(document_owner_employee_id IS NULL, revenue_kgs, 0)),2) AS revenue_no_owner,
  COUNT(DISTINCT document_owner_employee_id)                           AS n_owners
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date >= DATE("2026-07-01") AND transaction_date < DATE("2026-08-01")'
echo

echo "=== Q2: июльская выручка в разрезе ВЛАДЕЛЬЦА ДОКУМЕНТА ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 100 '
SELECT
  COALESCE(e.full_name, IF(f.document_owner_employee_id IS NULL,
           "(владелец документа не заполнен)", f.document_owner_employee_id)) AS employee,
  COUNT(*)                       AS n_rows,
  ROUND(SUM(f.revenue_kgs),2)    AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit` f
LEFT JOIN `msklad-bi-prod.core.dim_employees` e
  ON e.employee_id = f.document_owner_employee_id
WHERE f.transaction_date >= DATE("2026-07-01") AND f.transaction_date < DATE("2026-08-01")
GROUP BY employee
ORDER BY revenue_kgs DESC'
echo

echo "=== Q3: то же по владельцу документа, но с разбивкой по каналу продаж ==="
echo "(периметр — розница и комиссия — владельца документа не несёт по построению)"
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 100 '
SELECT
  IF(f.document_owner_employee_id IS NULL, "нет владельца", "есть владелец") AS owner_state,
  COALESCE(f.sales_channel_name, "(NULL)")                                   AS channel,
  COUNT(*)                                                                   AS n_rows,
  ROUND(SUM(f.revenue_kgs),2)                                                AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit` f
WHERE f.transaction_date >= DATE("2026-07-01") AND f.transaction_date < DATE("2026-08-01")
GROUP BY owner_state, channel
ORDER BY owner_state, revenue_kgs DESC'
echo

echo "=== ЯКОРЬ КОНЦА ==="; date -u; gcloud auth list 2>&1 | head -5
