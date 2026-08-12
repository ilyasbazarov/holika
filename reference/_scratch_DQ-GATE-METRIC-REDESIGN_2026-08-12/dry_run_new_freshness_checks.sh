#!/bin/bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== dry_run: fact_payments technical ==="
bq query --use_legacy_sql=false --dry_run '
SELECT
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
    COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
    COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_payments`
'

echo "=== dry_run: fact_commissionreportin technical ==="
bq query --use_legacy_sql=false --dry_run '
SELECT
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
    COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
    COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_commissionreportin`
'

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== date -u (end) ==="
date -u
