#!/usr/bin/env bash
set -uo pipefail
echo "=== UTC anchor (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list
echo; echo "=== READ-ONLY: состояние функции после обрыва инструмента ==="
gcloud functions describe cf-finance --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --format="value(state, serviceConfig.revision, updateTime, buildConfig.source.storageSource.generation)"
echo; echo "=== READ-ONLY: последние сборки Cloud Build по этой функции ==="
gcloud builds list --project=msklad-bi-prod --region=asia-east1 --limit=3 \
  --format="table(id.slice(0:12), status, createTime, finishTime)" 2>/dev/null || echo "  (builds list недоступен в этом регионе)"
echo; echo "=== READ-ONLY: ревизии Cloud Run и трафик ==="
gcloud run services describe cf-finance --region=asia-east1 --project=msklad-bi-prod \
  --format="value(status.traffic)" 2>/dev/null
gcloud run revisions list --service=cf-finance --region=asia-east1 --project=msklad-bi-prod \
  --format="table(metadata.name, status.conditions[0].status, metadata.creationTimestamp)" --limit=4 2>/dev/null
echo "=== UTC anchor (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
