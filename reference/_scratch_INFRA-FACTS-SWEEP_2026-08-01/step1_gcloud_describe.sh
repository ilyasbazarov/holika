#!/bin/bash
set -uo pipefail
date -u
gcloud auth list
echo "=== Q-6: gcloud functions describe cf-dq (gen2) ==="
gcloud functions describe cf-dq --project=msklad-bi-prod --region=asia-east1 --gen2
echo "RC_Q6_GEN2=$?"
echo "=== Q-6 fallback: gcloud functions describe cf-dq (no --gen2, if above failed) ==="
gcloud functions describe cf-dq --project=msklad-bi-prod --region=asia-east1
echo "RC_Q6_NOFLAG=$?"

echo "=== Q-12: gcloud functions describe cf-alert (gen2) ==="
gcloud functions describe cf-alert --project=msklad-bi-prod --region=asia-east1 --gen2
echo "RC_Q12_GEN2=$?"
echo "=== Q-12 fallback: gcloud functions describe cf-alert (no --gen2) ==="
gcloud functions describe cf-alert --project=msklad-bi-prod --region=asia-east1
echo "RC_Q12_NOFLAG=$?"

echo "=== Q-13: gcloud workflows describe msklad-pipeline-weekly ==="
gcloud workflows describe msklad-pipeline-weekly --project=msklad-bi-prod --location=asia-east1
echo "RC_Q13=$?"

date -u
gcloud auth list
