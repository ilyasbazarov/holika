"""
helpers.py — shared utilities for CF-Facts.
Token retrieval, paginated МойСклад API calls, GCS NDJSON write, href parsing.
"""

import gzip
import json
import logging
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Generator, Optional

import requests
from google.cloud import secretmanager, storage
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from config import GCP_PROJECT, MSKLAD_BASE, MSKLAD_RPS, PAGE_SIZE, SECRET_TOKEN

log = logging.getLogger(__name__)


# ─── Secret Manager ───────────────────────────────────────────────────────────

def get_token() -> str:
    """Read МойСклад Bearer token from Secret Manager."""
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{GCP_PROJECT}/secrets/{SECRET_TOKEN}/versions/latest"
    return client.access_secret_version(request={"name": name}).payload.data.decode("utf-8").strip()


def build_headers(token: str) -> dict:
    return {
        "Authorization": f"Bearer {token}",
        "Accept-Encoding": "gzip",
    }


# ─── API ──────────────────────────────────────────────────────────────────────

class _RetryableError(Exception):
    pass


@retry(
    retry=retry_if_exception_type(_RetryableError),
    stop=stop_after_attempt(5),
    wait=wait_exponential(multiplier=1, min=1, max=60),
    before_sleep=before_sleep_log(log, logging.WARNING),
    reraise=True,
)
def _api_get(session: requests.Session, url: str, headers: dict, params: Optional[dict] = None) -> dict:
    """Single paginated GET with rate-limit guard and retry on 429/5xx."""
    time.sleep(1.0 / MSKLAD_RPS)  # rate budget: 4 req/s max
    resp = session.get(url, headers=headers, params=params, timeout=90)
    if resp.status_code == 429:
        log.warning("Rate limit hit on %s — backing off", url)
        raise _RetryableError("429 Too Many Requests")
    if resp.status_code >= 500:
        log.warning("Server error %s on %s — backing off", resp.status_code, url)
        raise _RetryableError(f"{resp.status_code} Server Error")
    resp.raise_for_status()
    return resp.json()


def paginate_entity(
    token: str,
    path: str,
    params: Optional[dict] = None,
    session: Optional[requests.Session] = None,
) -> list:
    """
    Collect all rows from a МойСклад paginated endpoint.
    Returns flat list. Handles offset/limit pagination automatically.
    """
    if session is None:
        session = requests.Session()

    headers = build_headers(token)
    url = f"{MSKLAD_BASE}/{path}"
    all_rows: list = []
    offset = 0
    meta_size = None
    pages = 0

    while True:
        page_params = {**(params or {}), "limit": PAGE_SIZE, "offset": offset}
        data = _api_get(session, url, headers, page_params)
        if offset == 0:
            # `or {}`, а не `.get("meta", {})`: второй вариант возвращает None, когда ключ
            # ЕСТЬ со значением null, и следующий `.get` роняет AttributeError. Здесь это
            # не мелочь — функция общая для всех двенадцати обходов ингеста cf-facts, и
            # исключение внутри неё валит прогон целиком. Стадия A обязана быть неспособной
            # что-либо сломать (ревью архитектора, VERIFY стадии A).
            meta_size = (data.get("meta") or {}).get("size")
        rows = data.get("rows", [])
        all_rows.extend(rows)
        pages += 1
        log.debug("Fetched %d rows from %s (offset=%d)", len(rows), path, offset)
        if len(rows) < PAGE_SIZE:
            break
        offset += PAGE_SIZE

    has_filter = "filter" in (params or {})
    log.info(
        "PAGINATE_PROBE path=%s fetched=%d meta_size=%s pages=%d has_filter=%s",
        path, len(all_rows), meta_size, pages, has_filter,
    )

    return all_rows


def fetch_one(
    token: str,
    path: str,
    session: Optional[requests.Session] = None,
) -> dict:
    """Fetch a single resource (no pagination)."""
    if session is None:
        session = requests.Session()
    return _api_get(session, f"{MSKLAD_BASE}/{path}", build_headers(token))


# ─── Href parsing ─────────────────────────────────────────────────────────────

def parse_href(href: str) -> Optional[str]:
    """Extract UUID (last path segment) from a МойСклад meta.href."""
    if not href:
        return None
    return href.rstrip("/").rsplit("/", 1)[-1] or None


# ─── GCS NDJSON ───────────────────────────────────────────────────────────────

def upload_ndjson_gz(
    gcs_client: storage.Client,
    bucket_name: str,
    blob_path: str,
    records: list[dict],
) -> str:
    """
    Write records as gzip-compressed NDJSON to GCS.
    Each dict is one line. Returns full gs:// URI.

    ⚠ P0: one line = one record (not a JSON array — required for BQ NDJSON load).
    """
    payload = b"\n".join(
        json.dumps(r, ensure_ascii=False, default=str).encode("utf-8")
        for r in records
    )
    compressed = gzip.compress(payload)

    bucket = gcs_client.bucket(bucket_name)
    blob = bucket.blob(blob_path)
    blob.upload_from_string(compressed, content_type="application/x-ndjson")

    uri = f"gs://{bucket_name}/{blob_path}"
    log.info("Uploaded %d records → %s (%d bytes compressed)", len(records), uri, len(compressed))
    return uri


# ─── Datetime utils ───────────────────────────────────────────────────────────

def now_utc_str() -> str:
    """ISO timestamp in UTC for _loaded_at fields."""
    return datetime.now(timezone.utc).isoformat()


def run_ts() -> str:
    """Compact timestamp string for run_id / file names: YYYYMMDDTHHMMSS."""
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")


def parse_moment_to_bishkek_date(moment_str: str) -> str:
    """
    Парсит moment МойСклада (UTC, '2026-01-15 14:30:00.000') в DATE-строку
    по Asia/Bishkek (UTC+6). Возвращает 'YYYY-MM-DD'.
    До фикса (Q-77 / ADR-088 §4): брались первые 10 символов строки — UTC-дата
    трактовалась как уже местная.
    """
    dt_utc = datetime.strptime(moment_str[:19], "%Y-%m-%d %H:%M:%S")
    return (dt_utc + timedelta(hours=6)).strftime("%Y-%m-%d")
