#!/usr/bin/env bash
# =============================================================================
# setup_alerts.sh — Cloud Monitoring алерты для msklad-bi-prod
# Запуск: bash alerts/setup_alerts.sh
# Предусловие: cf-alert задеплоен, BOT_TOKEN и CHAT_ID в Secret Manager
# =============================================================================
set -euo pipefail

PROJECT="msklad-bi-prod"
REGION="asia-east1"
ALERT_EMAIL="ilyas@domprorab.com"   # ← заменить на реальный

# CF-alert URL (заменить после деплоя cf-alert)
CF_ALERT_URL="https://cf-alert-xw5u2boozq-${REGION}.a.run.app"

echo "=== [0/6] Получаем токен идентификации ==="
IDENTITY_TOKEN=$(gcloud auth print-identity-token)

# =============================================================================
# [1/6] Notification Channel — email
# =============================================================================
echo "=== [1/6] Создаём email notification channel ==="

EMAIL_CHANNEL_NAME=$(gcloud beta monitoring channels create \
  --display-name="msklad-alerts-email" \
  --type=email \
  --channel-labels="email_address=${ALERT_EMAIL}" \
  --project="${PROJECT}" \
  --format="value(name)")

echo "    Email channel: ${EMAIL_CHANNEL_NAME}"

# =============================================================================
# [2/6] Notification Channel — Telegram webhook (cf-alert)
# =============================================================================
echo "=== [2/6] Создаём Telegram webhook channel ==="

TG_CHANNEL_NAME=$(gcloud beta monitoring channels create \
  --display-name="msklad-alerts-telegram" \
  --type=webhook_tokenauth \
  --channel-labels="url=${CF_ALERT_URL}" \
  --project="${PROJECT}" \
  --format="value(name)")

echo "    Telegram channel: ${TG_CHANNEL_NAME}"

# =============================================================================
# [3/6] Log-based metrics
# =============================================================================
echo "=== [3/6] Создаём log-based metrics ==="

# --- 3a. DQ Gate failed ---
gcloud logging metrics create msklad_dq_gate_failed \
  --project="${PROJECT}" \
  --description="DQ Gate провалил проверку качества данных" \
  --log-filter='resource.type="cloud_run_revision"
resource.labels.service_name="cf-dq"
jsonPayload.message=~"DQ.*FAILED|dq_gate.*fail|check failed"
severity>=ERROR' \
  2>/dev/null || echo "    (msklad_dq_gate_failed уже существует, пропускаем)"

# --- 3b. Workflow failed/cancelled ---
gcloud logging metrics create msklad_workflow_execution_failed \
  --project="${PROJECT}" \
  --description="Cloud Workflow завершился со статусом FAILED или CANCELLED" \
  --log-filter='resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id=~"^msklad-pipeline"
jsonPayload.state=~"FAILED|CANCELLED"' \
  2>/dev/null || echo "    (msklad_workflow_execution_failed уже существует, пропускаем)"

# --- 3c. Workflow any execution completed (для silent-skip detection) ---
gcloud logging metrics create msklad_workflow_execution_any \
  --project="${PROJECT}" \
  --description="Любое завершение workflow msklad-pipeline-hourly" \
  --log-filter='resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id="msklad-pipeline-hourly"
jsonPayload.state=~"SUCCEEDED|FAILED|CANCELLED"' \
  2>/dev/null || echo "    (msklad_workflow_execution_any уже существует, пропускаем)"

echo "    Log-based metrics созданы."

# =============================================================================
# [4/6] Alert policy: CF 5xx > 0
# =============================================================================
echo "=== [4/6] Alert: msklad-cf-error (CF 5xx) ==="

cat > /tmp/alert_cf_error.json << EOF
{
  "displayName": "msklad-cf-error",
  "documentation": {
    "content": "Cloud Run (CF) вернул HTTP 5xx. Проверь логи упавшей функции: Cloud Functions → [имя] → Logs. Раздел Runbook: §1 Cloud Function упала.",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "CF 5xx request count > 0",
      "conditionThreshold": {
        "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=monitoring.regex.full_match(\"cf-.*\") AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0,
        "duration": "0s",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_SUM",
            "crossSeriesReducer": "REDUCE_SUM",
            "groupByFields": ["resource.labels.service_name"]
          }
        ]
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "3600s",
    "notificationRateLimit": {"period": "3600s"}
  },
  "combiner": "OR",
  "notificationChannels": ["${EMAIL_CHANNEL_NAME}", "${TG_CHANNEL_NAME}"]
}
EOF

gcloud alpha monitoring policies create \
  --policy-from-file=/tmp/alert_cf_error.json \
  --project="${PROJECT}"
echo "    msklad-cf-error создан."

# =============================================================================
# [5/6] Alert policy: DQ Gate failed
# =============================================================================
echo "=== [5/6] Alert: msklad-dq-gate-failed ==="

cat > /tmp/alert_dq_gate.json << EOF
{
  "displayName": "msklad-dq-gate-failed",
  "documentation": {
    "content": "DQ Gate отклонил данные — staging не был промоутнут в core. Раздел Runbook: §2 DQ Gate провалился. Проверь логи cf-dq.",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "DQ Gate failed log count > 0",
      "conditionThreshold": {
        "filter": "metric.type=\"logging.googleapis.com/user/msklad_dq_gate_failed\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0,
        "duration": "0s",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_COUNT",
            "crossSeriesReducer": "REDUCE_SUM"
          }
        ]
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "7200s",
    "notificationRateLimit": {"period": "3600s"}
  },
  "combiner": "OR",
  "notificationChannels": ["${EMAIL_CHANNEL_NAME}", "${TG_CHANNEL_NAME}"]
}
EOF

gcloud alpha monitoring policies create \
  --policy-from-file=/tmp/alert_dq_gate.json \
  --project="${PROJECT}"
echo "    msklad-dq-gate-failed создан."

# =============================================================================
# [5b/6] Alert policy: Workflow FAILED/CANCELLED
# =============================================================================
echo "=== [5b/6] Alert: msklad-workflow-execution-failed ==="

cat > /tmp/alert_workflow_failed.json << EOF
{
  "displayName": "msklad-workflow-execution-failed",
  "documentation": {
    "content": "Cloud Workflow завершился с ошибкой. Открой: Workflows → msklad-pipeline → Executions → последний execution → Graph. Раздел Runbook: §7 Workflows упал.",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "Workflow FAILED/CANCELLED log count > 0",
      "conditionThreshold": {
        "filter": "metric.type=\"logging.googleapis.com/user/msklad_workflow_execution_failed\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0,
        "duration": "0s",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_COUNT",
            "crossSeriesReducer": "REDUCE_SUM"
          }
        ]
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "3600s",
    "notificationRateLimit": {"period": "3600s"}
  },
  "combiner": "OR",
  "notificationChannels": ["${EMAIL_CHANNEL_NAME}", "${TG_CHANNEL_NAME}"]
}
EOF

gcloud alpha monitoring policies create \
  --policy-from-file=/tmp/alert_workflow_failed.json \
  --project="${PROJECT}"
echo "    msklad-workflow-execution-failed создан."

# =============================================================================
# [6/6] Alert policy: Silent skip — нет executions msklad-pipeline-hourly за 2 часа
# =============================================================================
echo "=== [6/6] Alert: msklad-workflow-silent-skip ==="

cat > /tmp/alert_workflow_silent.json << EOF
{
  "displayName": "msklad-workflow-silent-skip",
  "documentation": {
    "content": "msklad-pipeline-hourly не запускался более 2 часов. Проверь Cloud Scheduler: gcloud scheduler jobs list. Возможно, scheduler упал или отключён. Раздел Runbook: §7 Workflows упал → шаг 7.5.",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "No hourly workflow executions in 2h",
      "conditionAbsent": {
        "filter": "metric.type=\"logging.googleapis.com/user/msklad_workflow_execution_any\"",
        "duration": "7200s",
        "aggregations": [
          {
            "alignmentPeriod": "3600s",
            "perSeriesAligner": "ALIGN_COUNT",
            "crossSeriesReducer": "REDUCE_SUM"
          }
        ]
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "14400s",
    "notificationRateLimit": {"period": "7200s"}
  },
  "combiner": "OR",
  "notificationChannels": ["${EMAIL_CHANNEL_NAME}", "${TG_CHANNEL_NAME}"]
}
EOF

gcloud alpha monitoring policies create \
  --policy-from-file=/tmp/alert_workflow_silent.json \
  --project="${PROJECT}"
echo "    msklad-workflow-silent-skip создан."

# =============================================================================
# Итог
# =============================================================================
echo ""
echo "=== ✅ Все алерты настроены ==="
echo ""
echo "Email channel:    ${EMAIL_CHANNEL_NAME}"
echo "Telegram channel: ${TG_CHANNEL_NAME}"
echo ""
echo "Следующий шаг: тест алертов."
echo "  CF 5xx: вызови CF с некорректным payload и проверь что пришёл алерт."
echo "  Silent skip: временно выключи scheduler job и подожди 2ч (или уменьши duration до 10m для теста)."
echo ""
echo "Проверить созданные политики:"
echo "  gcloud alpha monitoring policies list --project=${PROJECT} --filter='displayName:msklad'"
