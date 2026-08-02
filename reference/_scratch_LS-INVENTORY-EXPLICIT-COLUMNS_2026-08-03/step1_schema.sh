#!/bin/bash
set -euo pipefail
date -u
gcloud auth list
bq query --use_legacy_sql=false --format=json \
'SELECT column_name, ordinal_position FROM `msklad-bi-prod.marts.INFORMATION_SCHEMA.COLUMNS`
 WHERE table_name = "inventory_health" ORDER BY ordinal_position'
date -u
gcloud auth list
