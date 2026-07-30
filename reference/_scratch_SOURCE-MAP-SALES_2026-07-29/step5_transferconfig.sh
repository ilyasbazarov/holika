#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

bq show --transfer_config --format=prettyjson \
  projects/420804682491/locations/asia-east1/transferConfigs/69ff34b4-0000-2b2b-a390-14c14ef7af10 2>&1

gcloud auth list
date -u
