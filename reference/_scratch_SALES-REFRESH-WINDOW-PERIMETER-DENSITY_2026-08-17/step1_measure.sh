#!/usr/bin/env bash
# SALES-REFRESH-WINDOW-PERIMETER-DENSITY — Шаг 1 (класс A, read-only)
# Замер плотности потока периметра (entity/retaildemand + entity/commissionreportin)
# по методике reference/sales_refresh_window_mandate_adj_2026-08-11.md §C, скопированной
# дословно на ветку периметра вместо ветки продаж.
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"

echo
echo "=== §0. Текущее состояние stg_msklad.fact_sales_perimeter_staging (WRITE_TRUNCATE, live) ==="
bq query --use_legacy_sql=false --project_id="$PROJECT" '
SELECT
  MIN(DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek")) AS min_date,
  MAX(DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek")) AS max_date,
  COUNT(*)                     AS n_positions,
  COUNT(DISTINCT doc_id)       AS n_docs,
  COUNT(DISTINCT source_doc_type) AS n_types
FROM `msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging`
'

echo
echo "=== §0b. Staging — распределение по типу документа (COUNT DISTINCT doc_id) ==="
bq query --use_legacy_sql=false --project_id="$PROJECT" '
SELECT
  source_doc_type,
  MIN(DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek")) AS min_date,
  MAX(DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek")) AS max_date,
  COUNT(*) AS n_positions,
  COUNT(DISTINCT doc_id) AS n_docs
FROM `msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging`
GROUP BY source_doc_type
ORDER BY source_doc_type
'

echo
echo "=== §1. core.fact_sales_profit — экстент строк периметра (sales_channel_id IS NULL, name IN Розница/Комиссия) ==="
bq query --use_legacy_sql=false --project_id="$PROJECT" '
SELECT
  sales_channel_name,
  MIN(transaction_date) AS min_date,
  MAX(transaction_date) AS max_date,
  COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE sales_channel_id IS NULL
  AND COALESCE(sales_channel_name, "") IN ("Розница", "Комиссия")
GROUP BY sales_channel_name
ORDER BY sales_channel_name
'

echo
echo "=== §2. core.fact_sales_profit — величина 1+2 объединённо (окно 180 суток, оба типа периметра вместе) ==="
bq query --use_legacy_sql=false --project_id="$PROJECT" '
WITH days AS (
  SELECT day
  FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY), CURRENT_DATE())) AS day
),
doc_counts AS (
  SELECT transaction_date AS day, COUNT(*) AS n_rows
  FROM `msklad-bi-prod.core.fact_sales_profit`
  WHERE sales_channel_id IS NULL
    AND COALESCE(sales_channel_name, "") IN ("Розница", "Комиссия")
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
  SELECT grp, COUNT(*) AS streak_len
  FROM streaks
  WHERE is_empty = 1
  GROUP BY grp
)
SELECT
  (SELECT COUNT(*) FROM joined) AS total_days,
  (SELECT SUM(is_empty) FROM joined) AS empty_days,
  ROUND(SAFE_DIVIDE((SELECT SUM(is_empty) FROM joined), (SELECT COUNT(*) FROM joined)) * 100, 2) AS pct_empty,
  (SELECT MAX(streak_len) FROM streak_lens) AS max_empty_streak
'

echo
echo "=== §3. core.fact_sales_profit — то же самое РАЗДЕЛЬНО по типу документа (Розница) ==="
bq query --use_legacy_sql=false --project_id="$PROJECT" '
WITH days AS (
  SELECT day
  FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY), CURRENT_DATE())) AS day
),
doc_counts AS (
  SELECT transaction_date AS day, COUNT(*) AS n_rows
  FROM `msklad-bi-prod.core.fact_sales_profit`
  WHERE sales_channel_id IS NULL
    AND sales_channel_name = "Розница"
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
  SELECT grp, COUNT(*) AS streak_len
  FROM streaks
  WHERE is_empty = 1
  GROUP BY grp
)
SELECT
  (SELECT COUNT(*) FROM joined) AS total_days,
  (SELECT SUM(is_empty) FROM joined) AS empty_days,
  ROUND(SAFE_DIVIDE((SELECT SUM(is_empty) FROM joined), (SELECT COUNT(*) FROM joined)) * 100, 2) AS pct_empty,
  (SELECT MAX(streak_len) FROM streak_lens) AS max_empty_streak
'

echo
echo "=== §4. core.fact_sales_profit — то же самое РАЗДЕЛЬНО по типу документа (Комиссия) ==="
bq query --use_legacy_sql=false --project_id="$PROJECT" '
WITH days AS (
  SELECT day
  FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY), CURRENT_DATE())) AS day
),
doc_counts AS (
  SELECT transaction_date AS day, COUNT(*) AS n_rows
  FROM `msklad-bi-prod.core.fact_sales_profit`
  WHERE sales_channel_id IS NULL
    AND sales_channel_name = "Комиссия"
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
  SELECT grp, COUNT(*) AS streak_len
  FROM streaks
  WHERE is_empty = 1
  GROUP BY grp
)
SELECT
  (SELECT COUNT(*) FROM joined) AS total_days,
  (SELECT SUM(is_empty) FROM joined) AS empty_days,
  ROUND(SAFE_DIVIDE((SELECT SUM(is_empty) FROM joined), (SELECT COUNT(*) FROM joined)) * 100, 2) AS pct_empty,
  (SELECT MAX(streak_len) FROM streak_lens) AS max_empty_streak
'

echo
echo "=== §5. Staging — тот же замер (документ-уровень, distinct doc_id), окно = фактическое покрытие staging ==="
bq query --use_legacy_sql=false --project_id="$PROJECT" '
WITH bounds AS (
  SELECT
    MIN(DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek")) AS min_date,
    MAX(DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek")) AS max_date
  FROM `msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging`
),
days AS (
  SELECT day FROM bounds, UNNEST(GENERATE_DATE_ARRAY(bounds.min_date, bounds.max_date)) AS day
),
doc_counts AS (
  SELECT
    DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek") AS day,
    COUNT(DISTINCT doc_id) AS n_docs
  FROM `msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging`
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
  SELECT grp, COUNT(*) AS streak_len
  FROM streaks
  WHERE is_empty = 1
  GROUP BY grp
)
SELECT
  (SELECT min_date FROM bounds) AS window_start,
  (SELECT max_date FROM bounds) AS window_end,
  (SELECT COUNT(*) FROM joined) AS total_days,
  (SELECT SUM(is_empty) FROM joined) AS empty_days,
  ROUND(SAFE_DIVIDE((SELECT SUM(is_empty) FROM joined), (SELECT COUNT(*) FROM joined)) * 100, 2) AS pct_empty,
  (SELECT MAX(streak_len) FROM streak_lens) AS max_empty_streak
'

echo
echo "=== §5b. Staging — то же, раздельно по типу документа (distinct doc_id) ==="
for T in retaildemand commissionreportin_sale; do
  echo "--- source_doc_type = $T ---"
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
  WHERE source_doc_type = '$T'
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
  SELECT grp, COUNT(*) AS streak_len
  FROM streaks
  WHERE is_empty = 1
  GROUP BY grp
)
SELECT
  (SELECT min_date FROM bounds) AS window_start,
  (SELECT max_date FROM bounds) AS window_end,
  (SELECT COUNT(*) FROM joined) AS total_days,
  (SELECT SUM(is_empty) FROM joined) AS empty_days,
  ROUND(SAFE_DIVIDE((SELECT SUM(is_empty) FROM joined), (SELECT COUNT(*) FROM joined)) * 100, 2) AS pct_empty,
  (SELECT MAX(streak_len) FROM streak_lens) AS max_empty_streak
"
done

echo
echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
