#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC-якорь (начало) ==="
date -u
echo "=== личность вызывающего (начало) ==="
gcloud auth list

echo
echo "=== gcloud scheduler jobs list (asia-east1) ==="
gcloud scheduler jobs list --location=asia-east1 --project=msklad-bi-prod \
  --format="table(name,schedule,timeZone,state)"

echo
echo "=== gcloud workflows describe msklad-pipeline-weekly ==="
gcloud workflows describe msklad-pipeline-weekly --location=asia-east1 --project=msklad-bi-prod \
  --format="value(name,updateTime,revisionId)"

echo
echo "=== source сontents (weekly) — поиск подстроки perimeter ==="
gcloud workflows describe msklad-pipeline-weekly --location=asia-east1 --project=msklad-bi-prod \
  --format="value(sourceContents)" > /tmp/msklad_weekly_source_live.yaml
grep -n "perimeter" /tmp/msklad_weekly_source_live.yaml || echo "0 совпадений perimeter в живом weekly"

echo
echo "=== gcloud workflows describe msklad-pipeline-hourly ==="
gcloud workflows describe msklad-pipeline-hourly --location=asia-east1 --project=msklad-bi-prod \
  --format="value(name,updateTime,revisionId)" || echo "msklad-pipeline-hourly: describe FAILED (rc=$?)"

echo
echo "=== source contents (hourly) — поиск подстроки perimeter ==="
gcloud workflows describe msklad-pipeline-hourly --location=asia-east1 --project=msklad-bi-prod \
  --format="value(sourceContents)" > /tmp/msklad_hourly_source_live.yaml || true
grep -n "perimeter" /tmp/msklad_hourly_source_live.yaml || echo "0 совпадений perimeter в живом hourly"

echo
echo "=== diff живой weekly source vs репо-снапшот ==="
diff -u reference/code/cf-facts/workflow_weekly.yaml /tmp/msklad_weekly_source_live.yaml && echo "IDENTICAL" || echo "DIFF найден (см. выше)"

echo
echo "=== личность вызывающего (конец) ==="
gcloud auth list
echo "=== UTC-якорь (конец) ==="
date -u
