#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

gcloud functions list --project=msklad-bi-prod --format="table(name,serviceConfig.serviceAccountEmail)" 2>&1

gcloud auth list
date -u
