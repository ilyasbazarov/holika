#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

gcloud storage cp "gs://gcf-v2-sources-420804682491-asia-east1/cf-facts/function-source.zip#1782334223015697" \
  reference/_scratch_SOURCE-MAP-SALES_2026-07-29/cf-facts-archive/function-source.zip 2>&1

gcloud auth list
date -u
