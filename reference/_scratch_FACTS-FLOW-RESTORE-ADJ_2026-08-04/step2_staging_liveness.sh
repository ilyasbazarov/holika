#!/usr/bin/env bash
# FACTS-FLOW-RESTORE-ADJ · шаг 2 — жив ли staging и проходит ли гейт на ближайшем прогоне.
#
# Опорный факт под рекомендацию: staging перезаливается каждый час шагом, стоящим в DAG ДО гейта
# (`ADR-113`), поэтому он есть свежая копия источника, а не замороженный снимок. Проверяется прямо.
# Второй вопрос: сколько выручки должны набрать сутки 2026-08-04, чтобы прогон 18:00Z прошёл чек.
# Класс A: только read-only `bq query`.
set -uo pipefail
PROJECT=msklad-bi-prod

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo
echo "=== step2a: свежесть staging (техническая) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=10 '
SELECT
  MAX(_loaded_at)                      AS max_loaded_at,
  MIN(_loaded_at)                      AS min_loaded_at,
  COUNT(DISTINCT _loaded_at)           AS n_distinct_loaded_at,
  COUNT(*)                             AS n_rows
FROM `msklad-bi-prod.stg_msklad.fact_sales_staging`
'

echo
echo "=== step2b: порог прохождения чека на прогоне 2026-08-04T18:00Z ==="
echo "    (target_date = 2026-08-04, будни → threshold = 0.10; ma7 = окно 2026-07-28…2026-08-03)"
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=10 '
WITH ma AS (
  SELECT COALESCE(AVG(daily_rev), 0) AS ma7 FROM (
    SELECT transaction_date, SUM(revenue_kgs) AS daily_rev
    FROM `msklad-bi-prod.core.fact_sales_profit`
    WHERE transaction_date >= DATE("2026-07-28")
      AND transaction_date <= DATE("2026-08-03")
    GROUP BY 1)
),
tgt AS (
  SELECT COALESCE(SUM(revenue_kgs), 0) AS target_rev
  FROM `msklad-bi-prod.stg_msklad.fact_sales_staging`
  WHERE DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek") = DATE("2026-08-04")
)
SELECT
  ROUND(ma.ma7, 2)                        AS ma7,
  ROUND(tgt.target_rev, 2)                AS target_rev_now,
  ROUND(ma.ma7 * 0.10, 2)                 AS needed_for_pass,
  ROUND(tgt.target_rev / ma.ma7, 4)       AS ratio_now,
  tgt.target_rev / ma.ma7 >= 0.10         AS would_pass_now
FROM ma, tgt
'

echo
echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u
echo "SCRATCH_PATH=reference/_scratch_FACTS-FLOW-RESTORE-ADJ_2026-08-04"
