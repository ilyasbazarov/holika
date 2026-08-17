#!/usr/bin/env bash
# Шаг 3 (класс A, read-only) — то же уточнение дат серий, но для staging
# (документ-уровень, окно = фактическое покрытие staging, без бутстрап-артефакта).
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"

streak_dates_query() {
  local FILTER="$1"
  bq query --use_legacy_sql=false --project_id="$PROJECT" "
WITH bounds AS (
  SELECT
    MIN(DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek')) AS min_date,
    MAX(DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek')) AS max_date
  FROM \`msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging\`
),
days AS (
  SELECT day FROM bounds, UNNEST(GENERATE_DATE_ARRAY(bounds.min_date, bounds.max_date)) AS day
),
doc_counts AS (
  SELECT
    DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek') AS day,
    COUNT(DISTINCT doc_id) AS n_docs
  FROM \`msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging\`
  WHERE $FILTER
  GROUP BY day
),
joined AS (
  SELECT d.day, COALESCE(c.n_docs, 0) AS n_docs,
         IF(COALESCE(c.n_docs, 0) = 0, 1, 0) AS is_empty
  FROM days d LEFT JOIN doc_counts c USING (day)
),
streaks AS (
  SELECT day, is_empty,
    ROW_NUMBER() OVER (ORDER BY day) - ROW_NUMBER() OVER (PARTITION BY is_empty ORDER BY day) AS grp
  FROM joined
),
streak_lens AS (
  SELECT grp, MIN(day) AS streak_start, MAX(day) AS streak_end, COUNT(*) AS streak_len
  FROM streaks
  WHERE is_empty = 1
  GROUP BY grp
)
SELECT streak_start, streak_end, streak_len
FROM streak_lens
ORDER BY streak_len DESC
LIMIT 5
"
}

echo
echo "=== §1. staging — максимальные серии, ОБЪЕДИНЁННО, топ-5 ==="
streak_dates_query 'TRUE'

echo
echo "=== §2. staging — максимальные серии, retaildemand, топ-5 ==="
streak_dates_query "source_doc_type = 'retaildemand'"

echo
echo "=== §3. staging — максимальные серии, commissionreportin_sale, топ-5 ==="
streak_dates_query "source_doc_type = 'commissionreportin_sale'"

echo
echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
