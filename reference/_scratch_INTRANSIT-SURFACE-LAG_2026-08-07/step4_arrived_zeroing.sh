#!/bin/bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== core.fact_purchases status='Прибыл': zeroed vs non-zeroed counts/sums ==="
bq query --use_legacy_sql=false --format=json \
  'SELECT
     COUNTIF(quantity_in_transit > 0 OR in_transit_sum_kgs > 0) AS n_not_zeroed,
     COUNTIF(quantity_in_transit = 0 AND in_transit_sum_kgs = 0) AS n_zeroed,
     COUNT(*) AS n_total,
     SUM(IF(quantity_in_transit > 0 OR in_transit_sum_kgs > 0, in_transit_sum_kgs, 0)) AS sum_kgs_not_zeroed,
     SUM(IF(quantity_in_transit = 0 AND in_transit_sum_kgs = 0, in_transit_sum_kgs, 0)) AS sum_kgs_zeroed
   FROM `msklad-bi-prod.core.fact_purchases`
   WHERE status_name = "Прибыл"'

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== date -u (end) ==="
date -u
