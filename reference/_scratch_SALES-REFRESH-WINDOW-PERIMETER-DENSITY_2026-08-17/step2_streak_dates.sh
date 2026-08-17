#!/usr/bin/env bash
# Шаг 2 (класс A, read-only) — уточнение: какие именно календарные даты покрывает
# максимальная серия пустых суток в core.fact_sales_profit (объединённо и по Комиссии),
# чтобы отличить реальный разрыв потока от артефакта старта промоута периметра.
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"

streak_dates_query() {
  local FILTER="$1"
  bq query --use_legacy_sql=false --project_id="$PROJECT" "
WITH days AS (
  SELECT day
  FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY), CURRENT_DATE())) AS day
),
doc_counts AS (
  SELECT transaction_date AS day, COUNT(*) AS n_rows
  FROM \`msklad-bi-prod.core.fact_sales_profit\`
  WHERE sales_channel_id IS NULL
    AND $FILTER
    AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
  GROUP BY day
),
joined AS (
  SELECT d.day, COALESCE(c.n_rows, 0) AS n_rows,
         IF(COALESCE(c.n_rows, 0) = 0, 1, 0) AS is_empty
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
echo "=== §1. core — максимальные серии, ОБЪЕДИНЁННО (Розница+Комиссия), топ-5 ==="
streak_dates_query 'COALESCE(sales_channel_name, "") IN ("Розница", "Комиссия")'

echo
echo "=== §2. core — максимальные серии, только Комиссия, топ-5 ==="
streak_dates_query 'sales_channel_name = "Комиссия"'

echo
echo "=== §3. core — максимальные серии, только Розница, топ-5 ==="
streak_dates_query 'sales_channel_name = "Розница"'

echo
echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
