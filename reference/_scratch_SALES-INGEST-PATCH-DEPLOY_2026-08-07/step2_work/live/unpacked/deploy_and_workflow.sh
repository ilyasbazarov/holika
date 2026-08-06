#!/usr/bin/env bash
# ─── CF-Facts deploy ──────────────────────────────────────────────────────────

gcloud functions deploy cf-facts \
  --gen2 \
  --runtime=python312 \
  --region=asia-east1 \
  --source=cf/cf_facts \
  --entry-point=main \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=2048MB \
  --timeout=540s \
  --min-instances=1 \
  --set-secrets="MSKLAD_TOKEN=msklad-token:latest"

# ─── Smoke-test: hourly load (no promote) ─────────────────────────────────────
gcloud functions call cf-facts \
  --region=asia-east1 \
  --data='{"mode":"hourly","run_id":"smoke_test_hourly"}'

# ─── Smoke-test: promote (after DQ passes) ────────────────────────────────────
gcloud functions call cf-facts \
  --region=asia-east1 \
  --data='{"mode":"promote","window_days":7}'

# ─── IAM: убедиться что у etl-sa есть objectAdmin на архивном бакете ──────────
# (из Аппендикс Е — project-level objectAdmin не наследуется на бакеты с UBLA)
gcloud storage buckets add-iam-policy-binding gs://msklad-archive-msklad-bi-prod \
  --member="serviceAccount:etl-sa@msklad-bi-prod.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"


# ═══════════════════════════════════════════════════════════════════════════════
# workflow_hourly.yaml  — обновлённый YAML с mode=promote + window_days
# ═══════════════════════════════════════════════════════════════════════════════
cat > workflow_hourly.yaml << 'EOF'
main:
  steps:
    - init:
        assign:
          - project: "msklad-bi-prod"
          - region: "asia-east1"
          - run_id: ${sys.now()}
          - cf_base: ${"https://" + region + "-" + project + ".cloudfunctions.net"}

    - step_dim:
        call: http.post
        args:
          url: ${cf_base + "/cf-dim"}
          auth:
            type: OIDC
          body:
            run_id: ${run_id}
        result: dim_result

    - step_fx:
        call: http.post
        args:
          url: ${cf_base + "/cf-fx"}
          auth:
            type: OIDC
          body:
            run_id: ${run_id}
        result: fx_result

    - step_facts_load:
        call: http.post
        args:
          url: ${cf_base + "/cf-facts"}
          auth:
            type: OIDC
          body:
            run_id: ${run_id}
            mode: "hourly"
        result: facts_load_result

    - step_dq:
        call: http.post
        args:
          url: ${cf_base + "/cf-dq"}
          auth:
            type: OIDC
          body:
            run_id: ${run_id}
            window_days: 7
        result: dq_result

    - check_dq:
        switch:
          - condition: ${dq_result.body.passed == false}
            raise: ${"DQ Gate failed: " + dq_result.body.failed_checks}

    - step_promote:
        call: http.post
        args:
          url: ${cf_base + "/cf-facts"}
          auth:
            type: OIDC
          body:
            run_id: ${run_id}
            mode: "promote"
            window_days: 7
        result: promote_result

    - done:
        return: ${promote_result}
EOF


# ═══════════════════════════════════════════════════════════════════════════════
# workflow_weekly.yaml  — воскресная 90d перезагрузка
# ═══════════════════════════════════════════════════════════════════════════════
cat > workflow_weekly.yaml << 'EOF'
main:
  steps:
    - init:
        assign:
          - project: "msklad-bi-prod"
          - region: "asia-east1"
          - run_id: ${sys.now()}
          - cf_base: ${"https://" + region + "-" + project + ".cloudfunctions.net"}

    - step_dim:
        call: http.post
        args:
          url: ${cf_base + "/cf-dim"}
          auth:
            type: OIDC
          body:
            run_id: ${run_id}
        result: dim_result

    - step_fx:
        call: http.post
        args:
          url: ${cf_base + "/cf-fx"}
          auth:
            type: OIDC
          body:
            run_id: ${run_id}
        result: fx_result

    - step_facts_load:
        call: http.post
        args:
          url: ${cf_base + "/cf-facts"}
          auth:
            type: OIDC
          body:
            run_id: ${run_id}
            mode: "weekly"
        result: facts_load_result

    - step_dq:
        call: http.post
        args:
          url: ${cf_base + "/cf-dq"}
          auth:
            type: OIDC
          body:
            run_id: ${run_id}
            window_days: 90
        result: dq_result

    - check_dq:
        switch:
          - condition: ${dq_result.body.passed == false}
            raise: ${"DQ Gate failed: " + dq_result.body.failed_checks}

    - step_promote:
        call: http.post
        args:
          url: ${cf_base + "/cf-facts"}
          auth:
            type: OIDC
          body:
            run_id: ${run_id}
            mode: "promote"
            window_days: 90
        result: promote_result

    - done:
        return: ${promote_result}
EOF

# ─── Deploy Workflows ─────────────────────────────────────────────────────────
gcloud workflows deploy msklad-pipeline-hourly \
  --location=asia-east1 \
  --source=workflow_hourly.yaml \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com

gcloud workflows deploy msklad-pipeline-weekly \
  --location=asia-east1 \
  --source=workflow_weekly.yaml \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com

# ─── Cloud Scheduler ──────────────────────────────────────────────────────────
# Hourly (каждый час)
gcloud scheduler jobs create http msklad-pipeline-hourly \
  --location=asia-east1 \
  --schedule="0 * * * *" \
  --uri="https://workflowexecutions.googleapis.com/v1/projects/msklad-bi-prod/locations/asia-east1/workflows/msklad-pipeline-hourly/executions" \
  --message-body='{"argument": "{}"}' \
  --oauth-service-account-email=etl-sa@msklad-bi-prod.iam.gserviceaccount.com

# Weekly (воскресенье 01:00 UTC = 07:00 KGT)
gcloud scheduler jobs create http msklad-pipeline-weekly \
  --location=asia-east1 \
  --schedule="0 1 * * 0" \
  --uri="https://workflowexecutions.googleapis.com/v1/projects/msklad-bi-prod/locations/asia-east1/workflows/msklad-pipeline-weekly/executions" \
  --message-body='{"argument": "{}"}' \
  --oauth-service-account-email=etl-sa@msklad-bi-prod.iam.gserviceaccount.com
