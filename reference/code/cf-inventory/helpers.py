"""
Вспомогательные функции CF-Inventory.
Secret Manager, пагинация report/stock/all, GCS upload.
"""

import gzip
import time
import logging

import requests
from tenacity import retry, stop_after_attempt, wait_exponential
from google.cloud import secretmanager

from config import MSKLAD_BASE, MSKLAD_RPS, PAGE_SIZE

log = logging.getLogger(__name__)

# ─── Secret Manager ───────────────────────────────────────────────────────────

def get_token(project: str, secret_id: str) -> str:
    client = secretmanager.SecretManagerServiceClient()
    name   = f"projects/{project}/secrets/{secret_id}/versions/latest"
    return client.access_secret_version(
        request={"name": name}
    ).payload.data.decode("utf-8")

# ─── МойСклад API ─────────────────────────────────────────────────────────────

@retry(
    stop=stop_after_attempt(5),
    wait=wait_exponential(multiplier=1, min=1, max=60),
    reraise=True,
)
def _get_page(session: requests.Session, url: str, params: dict) -> dict:
    resp = session.get(url, params=params, timeout=60)
    if resp.status_code == 429:
        log.warning("429 Too Many Requests — tenacity will retry")
        raise requests.HTTPError("429", response=resp)
    resp.raise_for_status()
    return resp.json()


def paginate_report_stock(token: str):
    """
    Итератор по строкам report/stock/all.

    stockMode=all   — включая нулевые и отрицательные остатки
    quantityMode=all — включая товары с нулевым quantity (OOS),
                       иначе дефолт nonEmpty их отфильтрует
    """
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept-Encoding": "gzip",
    })

    url           = f"{MSKLAD_BASE}/report/stock/all"
    sleep_interval = 1.0 / MSKLAD_RPS   # 0.25 с при RPS=4
    offset        = 0

    while True:
        params = {
            "stockMode":    "all",
            "quantityMode": "all",
            "limit":        PAGE_SIZE,
            "offset":       offset,
        }

        data = _get_page(session, url, params)
        rows = data.get("rows", [])

        log.info("report/stock/all offset=%d → %d rows", offset, len(rows))

        yield from rows

        if len(rows) < PAGE_SIZE:
            break

        offset += PAGE_SIZE
        time.sleep(sleep_interval)

# ─── GCS ─────────────────────────────────────────────────────────────────────

def upload_ndjson_gz(
    gcs_client,
    bucket_name: str,
    gcs_path: str,
    payload: bytes,          # сырой NDJSON (не сжатый)
) -> str:
    """Сжать payload gzip, загрузить в GCS, вернуть gs:// URI."""
    bucket     = gcs_client.bucket(bucket_name)
    blob       = bucket.blob(gcs_path)
    compressed = gzip.compress(payload)
    blob.upload_from_string(compressed, content_type="application/gzip")
    uri = f"gs://{bucket_name}/{gcs_path}"
    log.info(
        "GCS upload: %s | raw=%d B | compressed=%d B",
        uri, len(payload), len(compressed),
    )
    return uri
