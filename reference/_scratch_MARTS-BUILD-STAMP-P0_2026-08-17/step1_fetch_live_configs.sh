#!/usr/bin/env bash
set -uo pipefail
OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$OUT"

date -u
gcloud auth list

NAMES="customer_invoices_ar expenses weight_flow"
ID_customer_invoices_ar="6a23f3ea-0000-2952-853d-582429be7ecc"
ID_expenses="6a22a243-0000-20fd-a458-883d24f4cad4"
ID_weight_flow="6a1f9418-0000-276f-a1e4-d4f547ee7418"

for name in $NAMES; do
  var="ID_${name}"
  id="${!var}"
  echo "-- bq show --transfer_config : sq_marts_${name} (${id})"
  bq show --transfer_config --format=prettyjson \
    "projects/420804682491/locations/asia-east1/transferConfigs/${id}" \
    > "step1_${name}_config.json" 2> "step1_${name}_config.err"
  echo "rc=$? for ${name}"
done

gcloud auth list
date -u
