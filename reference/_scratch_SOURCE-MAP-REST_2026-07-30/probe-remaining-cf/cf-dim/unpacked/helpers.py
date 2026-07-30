# ── CF-Dim / helpers.py ──────────────────────────────────────────────────────

import gzip
import io
import json
import logging
import time
from datetime import datetime, timezone
from typing import Iterator

import requests
from google.cloud import secretmanager, storage

from config import GCS_RAW, MSKLAD_BASE, PAGE_SIZE, RPS_DELAY, SECRET_TOKEN

log = logging.getLogger(__name__)


# ── Auth / Secret ─────────────────────────────────────────────────────────────

def get_token(project: str) -> str:
    client = secretmanager.SecretManagerServiceClient()
    name   = f"projects/{project}/secrets/{SECRET_TOKEN}/versions/latest"
    return client.access_secret_version(
        request={"name": name}
    ).payload.data.decode()


def make_session(token: str) -> requests.Session:
    s = requests.Session()
    s.headers.update({
        "Authorization":   f"Bearer {token}",
        "Accept-Encoding": "gzip",
        "Content-Type":    "application/json",
    })
    return s


# ── HTTP ──────────────────────────────────────────────────────────────────────

def _get_with_retry(session: requests.Session, url: str,
                    params: dict | None = None,
                    headers: dict | None = None,
                    max_retries: int = 5) -> dict:
    delay = 1.0
    for attempt in range(max_retries):
        time.sleep(RPS_DELAY)
        try:
            r = session.get(url, params=params, headers=headers, timeout=90)
            if r.status_code == 429:
                wait = delay * (2 ** attempt)
                log.warning("429 rate-limit — ждём %.1fs", wait)
                time.sleep(wait)
                continue
            r.raise_for_status()
            return r.json()
        except requests.RequestException as exc:
            if attempt == max_retries - 1:
                raise RuntimeError(
                    f"Все {max_retries} попыток исчерпаны для {url}: {exc}"
                ) from exc
            log.warning("Попытка %d/%d — %s", attempt + 1, max_retries, exc)
            time.sleep(delay * (2 ** attempt))
    raise RuntimeError("Недостижимый код")  # для линтера


def paginate_entity(session: requests.Session, endpoint: str,
                    extra_params: dict | None = None,
                    extra_headers: dict | None = None) -> Iterator[dict]:
    """
    Постраничная выгрузка любого entity-endpoint МойСклад.
    Возвращает объекты по одному (генератор).
    """
    url    = f"{MSKLAD_BASE}/{endpoint}"
    params = {**(extra_params or {}), "limit": PAGE_SIZE, "offset": 0}
    while True:
        data = _get_with_retry(session, url, params=params,
                               headers=extra_headers)
        rows = data.get("rows", [])
        yield from rows
        if len(rows) < PAGE_SIZE:
            break
        params["offset"] += PAGE_SIZE


# ── UUID helpers ──────────────────────────────────────────────────────────────

def parse_href_id(href: str) -> str | None:
    """UUID из последнего сегмента href."""
    return href.rsplit("/", 1)[-1] if href else None


def get_custom_attr(attrs: list, uuid: str) -> object:
    """Возвращает value кастомного поля по UUID или None."""
    for attr in attrs:
        if attr.get("id") == uuid:
            return attr.get("value")
    return None


# ── GCS ───────────────────────────────────────────────────────────────────────

def upload_json_gz(gcs_client: storage.Client,
                   records: list[dict],
                   blob_name: str) -> None:
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb") as gz:
        gz.write(
            json.dumps(records, ensure_ascii=False, default=str).encode("utf-8")
        )
    bucket = gcs_client.bucket(GCS_RAW)
    blob   = bucket.blob(blob_name)
    blob.upload_from_string(buf.getvalue(), content_type="application/json")
    log.info("GCS ↑ gs://%s/%s (%d записей)", GCS_RAW, blob_name, len(records))


# ── Загрузка метаданных UUID ──────────────────────────────────────────────────

def load_uuids(bq_client) -> dict[str, str]:
    """
    Читает dim_metadata_mappings → {field_name: current_uuid}.
    Падает если таблица недоступна — CF не должен работать без неё.
    """
    sql  = "SELECT field_name, current_uuid FROM `msklad-bi-prod.core.dim_metadata_mappings`"
    rows = bq_client.query(sql).result()
    result = {row.field_name: row.current_uuid for row in rows}
    if not result:
        raise RuntimeError("dim_metadata_mappings пуста — невозможно продолжить")
    log.info("Загружено %d UUID из dim_metadata_mappings", len(result))
    return result


# ── Timestamp ─────────────────────────────────────────────────────────────────

def now_utc() -> str:
    return datetime.now(timezone.utc).isoformat()
