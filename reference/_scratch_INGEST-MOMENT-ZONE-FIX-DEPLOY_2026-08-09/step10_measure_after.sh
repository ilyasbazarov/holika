#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== marts.expenses после — май-2026, эталон 10 232 903.20 ==="
bq query --use_legacy_sql=false --format=prettyjson '
SELECT ROUND(SUM(total_sum_kgs),2) AS total_kgs_may2026, COUNT(*) AS row_count
FROM `msklad-bi-prod.marts.expenses`
WHERE year_month = "2026-05"
'

echo "=== marts.expenses после — полная сумма и число строк (для протокола) ==="
bq query --use_legacy_sql=false --format=prettyjson '
SELECT COUNT(*) AS row_count, ROUND(SUM(total_sum_kgs),2) AS total_kgs
FROM `msklad-bi-prod.marts.expenses`
'

echo "=== разность payment_type=loss/commission по июлю (месяц, где реально есть строки в полосе 18:00-24:00 UTC) ==="
bq query --use_legacy_sql=false --format=prettyjson '
SELECT payment_type, year_month, ROUND(SUM(total_sum_kgs),2) AS sum_kgs, SUM(payment_count) AS rows
FROM `msklad-bi-prod.marts.expenses`
WHERE payment_type IN ("loss","commission") AND year_month IN ("2026-05","2026-07")
GROUP BY payment_type, year_month
ORDER BY payment_type, year_month
'

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
