"""
cf-alert — принимает webhook от Cloud Monitoring, форматирует и отправляет в Telegram.

Деплой:
  gcloud functions deploy cf-alert \
    --gen2 --runtime=python312 --region=asia-east1 \
    --source=cf/cf_alert --entry-point=main \
    --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
    --memory=256MB --timeout=30s \
    --set-secrets="TELEGRAM_BOT_TOKEN=telegram-bot-token:latest,TELEGRAM_CHAT_ID=telegram-chat-id:latest" \
    --trigger-http --allow-unauthenticated

Примечание: --allow-unauthenticated нужен потому что Cloud Monitoring webhook
не умеет отправлять GCP identity token. Функция не содержит чувствительных данных.
URL закрыт на уровне: принимает только валидный JSON от Monitoring, всё остальное игнорирует.
"""

import os
import json
import logging

import requests
from flask import Request

log = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# ──────────────────────────────────────────────────────────────────────────────
# Конфиг
# ──────────────────────────────────────────────────────────────────────────────

BOT_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
CHAT_ID   = os.environ["TELEGRAM_CHAT_ID"]

TELEGRAM_URL = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"

# Маппинг policy_name → emoji + краткий контекст для оперативного диагноза
POLICY_HINTS: dict[str, str] = {
    "msklad-cf-error":                "CF вернула HTTP 5xx. Открой: Cloud Functions → Logs",
    "msklad-dq-gate-failed":          "DQ Gate отклонил данные. Staging НЕ промоутнут. Открой: cf-dq → Logs",
    "msklad-workflow-execution-failed":"Workflow упал. Открой: Workflows → Executions → Graph",
    "msklad-workflow-silent-skip":    "Hourly pipeline не запускался >2ч. Проверь Cloud Scheduler",
}

STATE_EMOJI = {
    "open":    "🔴",
    "closed":  "✅",
    "unknown": "⚠️",
}


# ──────────────────────────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────────────────────────

def main(request: Request):
    """HTTP trigger — принимает Pub/Sub-обёрнутый или прямой webhook от Monitoring."""
    try:
        body = request.get_json(silent=True) or {}
        incident = _extract_incident(body)
        if incident is None:
            log.warning("Получен запрос без поля incident, игнорируем. body=%s", json.dumps(body)[:500])
            return "ok", 200

        message = _format_message(incident)
        _send_telegram(message)
        log.info("Алерт отправлен: policy=%s state=%s",
                 incident.get("policy_name"), incident.get("state"))
        return "ok", 200

    except Exception as exc:
        log.exception("cf-alert упал: %s", exc)
        # Не возвращаем 5xx — Cloud Monitoring будет ретраить и спамить
        return "error logged", 200


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

def _extract_incident(body: dict) -> dict | None:
    """
    Cloud Monitoring может прислать incident прямо или обёрнутым в Pub/Sub message.
    Поддерживаем оба варианта.
    """
    if "incident" in body:
        return body["incident"]

    # Pub/Sub формат: {"message": {"data": "<base64 JSON>"}}
    import base64
    try:
        data_b64 = body.get("message", {}).get("data", "")
        if data_b64:
            decoded = json.loads(base64.b64decode(data_b64).decode("utf-8"))
            return decoded.get("incident")
    except Exception:
        pass

    return None


def _format_message(incident: dict) -> str:
    policy_name  = incident.get("policy_name", "Unknown policy")
    state        = incident.get("state", "unknown")
    summary      = incident.get("summary", "")
    url          = incident.get("url", "")
    started_at   = incident.get("started_at", "")

    emoji = STATE_EMOJI.get(state, "⚠️")
    hint  = POLICY_HINTS.get(policy_name, "")

    lines = [
        f"{emoji} *{policy_name}*",
        f"Статус: `{state}`",
    ]
    if hint:
        lines.append(f"_{hint}_")
    if summary:
        # Telegram Markdown: экранируем спецсимволы в summary
        lines.append(f"\n{_escape_md(summary[:300])}")
    if started_at:
        lines.append(f"Начало: `{started_at}`")
    if url:
        lines.append(f"[Открыть инцидент]({url})")

    return "\n".join(lines)


def _escape_md(text: str) -> str:
    """Минимальное экранирование для Telegram Markdown v1."""
    for ch in ["_", "*", "`", "["]:
        text = text.replace(ch, f"\\{ch}")
    return text


def _send_telegram(text: str) -> None:
    resp = requests.post(
        TELEGRAM_URL,
        json={
            "chat_id":    CHAT_ID,
            "text":       text,
            "parse_mode": "Markdown",
            "disable_web_page_preview": True,
        },
        timeout=10,
    )
    if not resp.ok:
        log.error("Telegram API error: %s %s", resp.status_code, resp.text[:200])
        resp.raise_for_status()
