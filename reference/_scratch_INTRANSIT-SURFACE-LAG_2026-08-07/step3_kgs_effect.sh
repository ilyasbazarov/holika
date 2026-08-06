#!/bin/bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== marts.in_transit: SUM(in_transit_sum_kgs), COUNT(*) ==="
bq query --use_legacy_sql=false --format=json \
  'SELECT SUM(in_transit_sum_kgs) AS sum_kgs_mart, COUNT(*) AS n_rows_mart,
          COUNT(DISTINCT CONCAT(purchase_order_id, "|", position_id)) AS n_keys_mart
   FROM `msklad-bi-prod.marts.in_transit`'

echo "=== core.fact_purchases recomputed with canonical filter: SUM(in_transit_sum_kgs), COUNT(*) ==="
bq query --use_legacy_sql=false --format=json \
  'SELECT SUM(in_transit_sum_kgs) AS sum_kgs_core, COUNT(*) AS n_rows_core,
          COUNT(DISTINCT CONCAT(purchase_order_id, "|", position_id)) AS n_keys_core
   FROM `msklad-bi-prod.core.fact_purchases`
   WHERE status_name IN ("В пути", "Прибыл частично")
     AND in_transit_sum_kgs > 0'

echo "=== Symmetric key difference: mart-only keys ==="
bq query --use_legacy_sql=false --format=json \
  'WITH mart_keys AS (
     SELECT CONCAT(purchase_order_id, "|", position_id) AS k, in_transit_sum_kgs
     FROM `msklad-bi-prod.marts.in_transit`
   ),
   core_keys AS (
     SELECT CONCAT(purchase_order_id, "|", position_id) AS k, in_transit_sum_kgs
     FROM `msklad-bi-prod.core.fact_purchases`
     WHERE status_name IN ("В пути", "Прибыл частично")
       AND in_transit_sum_kgs > 0
   )
   SELECT
     (SELECT COUNT(*) FROM mart_keys m WHERE m.k NOT IN (SELECT k FROM core_keys)) AS mart_only_n,
     (SELECT IFNULL(SUM(m.in_transit_sum_kgs),0) FROM mart_keys m WHERE m.k NOT IN (SELECT k FROM core_keys)) AS mart_only_sum_kgs,
     (SELECT COUNT(*) FROM core_keys c WHERE c.k NOT IN (SELECT k FROM mart_keys)) AS core_only_n,
     (SELECT IFNULL(SUM(c.in_transit_sum_kgs),0) FROM core_keys c WHERE c.k NOT IN (SELECT k FROM mart_keys)) AS core_only_sum_kgs,
     (SELECT COUNT(*) FROM mart_keys m JOIN core_keys c ON m.k = c.k WHERE m.in_transit_sum_kgs != c.in_transit_sum_kgs) AS matched_key_diff_n,
     (SELECT IFNULL(SUM(c.in_transit_sum_kgs - m.in_transit_sum_kgs),0) FROM mart_keys m JOIN core_keys c ON m.k = c.k) AS matched_key_delta_kgs
  '

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== date -u (end) ==="
date -u
