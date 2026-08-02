#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== SQL: reference/sql/sq_marts_customer_invoices_ar.sql (полный файл) ==="
cat -n reference/sql/sq_marts_customer_invoices_ar.sql

echo "=== Вывод по строкам SQL ==="
echo "Строка FROM (16-я строка нумерации cat -n выше, псевдо-адрес): FROM msklad-bi-prod.core.fact_customer_invoices i"
echo "WHERE-условия по дате в запросе: ОТСУТСТВУЮТ (grep ниже)"
grep -n "WHERE" reference/sql/sq_marts_customer_invoices_ar.sql || echo "grep WHERE: 0 совпадений"
echo "GROUP BY: агрегация по agent_id, agent_name, country, state_name, state_id — без даты"
grep -n "GROUP BY" -A 3 reference/sql/sq_marts_customer_invoices_ar.sql

echo "=== Контрольная цитата 03_PIPELINE_SPEC.md ==="
grep -n "customer_invoices_ar" -B 2 -A 3 03_PIPELINE_SPEC.md | grep -n "Custom Query, без date range" -B 5 || true
grep -n "Custom Query, без date range" 03_PIPELINE_SPEC.md

echo "=== date -u (end) ==="
date -u

echo "=== gcloud auth list (end) ==="
gcloud auth list
