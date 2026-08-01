#!/bin/bash
set -uo pipefail
date -u
gcloud auth list

echo "=== Q-47a: total rows core.fact_loss ==="
bq query --use_legacy_sql=false --format=prettyjson \
'SELECT COUNT(*) AS total_rows FROM `msklad-bi-prod.core.fact_loss`'

echo "=== Q-47b: non-KGS rows core.fact_loss (currency_code column, confirmed by live schema step0) ==="
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT COUNT(*) AS non_kgs_rows FROM \`msklad-bi-prod.core.fact_loss\` WHERE currency_code != 'KGS'"

echo "=== Q-55: three COUNTIF on core.fact_loss ==="
bq query --use_legacy_sql=false --format=prettyjson \
'SELECT
   COUNTIF(project_id IS NOT NULL) AS project_id_nn,
   COUNTIF(sales_channel_id IS NOT NULL) AS sales_channel_id_nn,
   COUNTIF(agent_name IS NOT NULL) AS agent_name_nn,
   COUNT(*) AS total
 FROM `msklad-bi-prod.core.fact_loss`'

echo "=== Q-11: marts.abc_xyz distribution by xyz_class ==="
bq query --use_legacy_sql=false --format=prettyjson \
'SELECT xyz_class, COUNT(*) AS cnt FROM `msklad-bi-prod.marts.abc_xyz` GROUP BY xyz_class ORDER BY xyz_class'

echo "=== Q-11: marts.abc_xyz distribution by abc_class ==="
bq query --use_legacy_sql=false --format=prettyjson \
'SELECT abc_class, COUNT(*) AS cnt FROM `msklad-bi-prod.marts.abc_xyz` GROUP BY abc_class ORDER BY abc_class'

echo "=== Q-11: marts.abc_xyz total rows (coverage) ==="
bq query --use_legacy_sql=false --format=prettyjson \
'SELECT COUNT(*) AS total_rows FROM `msklad-bi-prod.marts.abc_xyz`'

date -u
gcloud auth list
