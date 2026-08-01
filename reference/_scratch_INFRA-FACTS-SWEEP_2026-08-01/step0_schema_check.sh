#!/bin/bash
set -euo pipefail
date -u
gcloud auth list
echo "=== bq show core.fact_loss ==="
bq show --format=prettyjson msklad-bi-prod:core.fact_loss
echo "=== bq show marts.abc_xyz ==="
bq show --format=prettyjson msklad-bi-prod:marts.abc_xyz
date -u
gcloud auth list
