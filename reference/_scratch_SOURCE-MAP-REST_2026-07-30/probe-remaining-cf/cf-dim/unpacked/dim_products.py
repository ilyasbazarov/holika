# ── CF-Dim / dim_products.py ─────────────────────────────────────────────────
# Выгружает entity/assortment → stg → SCD1 MERGE в core.dim_products
# Парсит product / variant / bundle
# Кастомное поле: shelf_life (type=time)

import logging
from datetime import datetime, timezone

from google.cloud import bigquery, storage

from config import BQ_CORE, BQ_STG, GCP_PROJECT
from helpers import (
    get_custom_attr,
    now_utc,
    paginate_entity,
    parse_href_id,
    upload_json_gz,
)

log = logging.getLogger(__name__)

# Заголовок для включения архивных товаров через assortmentWithoutStock
_ASSORTMENT_HEADER = {
    "X-Lognex-Remap-Beta-Feature": "assortmentWithoutStock"
}

# Фильтр: archived=false И archived=true — обязательно, иначе архивные выпадут
_ASSORTMENT_PARAMS = {
    "filter": "archived=false;archived=true",
    "expand": "productFolder",
}

_STG_TABLE  = f"{BQ_STG}.products_staging"
_CORE_TABLE = f"{BQ_CORE}.dim_products"

_SCHEMA = [
    bigquery.SchemaField("product_id",       "STRING",    mode="REQUIRED"),
    bigquery.SchemaField("name",             "STRING",    mode="NULLABLE"),
    bigquery.SchemaField("article",          "STRING",    mode="NULLABLE"),
    bigquery.SchemaField("product_folder",   "STRING",    mode="NULLABLE"),
    bigquery.SchemaField("parent_product_id","STRING",    mode="NULLABLE"),
    bigquery.SchemaField("entity_type",      "STRING",    mode="NULLABLE"),
    bigquery.SchemaField("created",          "STRING",    mode="NULLABLE"),
    bigquery.SchemaField("shelf_life",       "TIMESTAMP", mode="NULLABLE"),
    bigquery.SchemaField("weight",           "FLOAT64",   mode="NULLABLE"),
    bigquery.SchemaField("_loaded_at",       "TIMESTAMP", mode="NULLABLE"),
]

def _fetch_folder_map(session) -> dict:
    """Загружает все productFolder → возвращает {uuid: name}."""
    result = {}
    offset = 0
    while True:
        resp = session.get(
            "https://api.moysklad.ru/api/remap/1.2/entity/productfolder",
            params={"limit": 100, "offset": offset},
        )
        resp.raise_for_status()
        data = resp.json()
        rows = data.get("rows", [])
        for r in rows:
            result[r["id"]] = r.get("name")
        if len(rows) < 100:
            break
        offset += 100
    log.info("_fetch_folder_map: загружено %d папок", len(result))
    return result


def _parse_product(entity: dict, uuids: dict, folder_map: dict) -> dict | None:
    """
    Парсит одну запись из assortment.
    Возвращает None для entity_type=service (не храним).
    """
    meta        = entity.get("meta", {})
    entity_type = meta.get("type", "unknown")

    # Пропускаем услуги — в аналитике не участвуют (см. Аппендикс Д)
    if entity_type == "service":
        return None

    product_id = entity.get("id")
    if not product_id:
        return None

    # parent_product_id:
    #   variant → id родительского product из entity["product"]["meta"]["href"]
    #   product / bundle → собственный id (для единообразия JOIN'ов)
    if entity_type == "variant":
        parent_href       = entity.get("product", {}).get("meta", {}).get("href", "")
        parent_product_id = parse_href_id(parent_href) or product_id
    else:
        parent_product_id = product_id

    # product_folder — название папки через предварительно загруженный folder_map
    folder_href    = entity.get("productFolder", {}).get("meta", {}).get("href", "")
    folder_uuid    = parse_href_id(folder_href) if folder_href else None
    product_folder = folder_map.get(folder_uuid) if folder_uuid else None

    # Кастомное поле shelf_life (type=time → ISO datetime string)
    shelf_life_uuid = uuids.get("shelf_life")
    shelf_life_raw  = get_custom_attr(entity.get("attributes", []), shelf_life_uuid) \
                      if shelf_life_uuid else None

    shelf_life = None
    if shelf_life_raw:
        try:
            # МойСклад возвращает "2026-12-31T00:00:00.000+06:00"
            shelf_life = datetime.fromisoformat(
                str(shelf_life_raw).replace("Z", "+00:00")
            ).astimezone(timezone.utc).isoformat()
        except (ValueError, TypeError):
            log.warning("Не удалось распарсить shelf_life=%r для %s",
                        shelf_life_raw, product_id)

    return {
        "product_id":        product_id,
        "name":              entity.get("name"),
        "article":           entity.get("article"),
        "product_folder":    product_folder,
        "parent_product_id": parent_product_id,
        "entity_type":       entity_type,
        "created":           entity.get("created"),
        "shelf_life":        shelf_life,
        "weight":            entity.get("weight"),
        "_loaded_at":        now_utc(),
    }


def run(session, bq_client: bigquery.Client,
        gcs_client: storage.Client, uuids: dict, run_id: str) -> int:
    """
    Полный цикл обновления dim_products.
    Возвращает количество обработанных записей.
    """
    log.info("dim_products: выгрузка из entity/assortment")

    records = []
    skipped = 0

    folder_map = _fetch_folder_map(session)

    for entity in paginate_entity(
        session,
        endpoint="entity/assortment",
        extra_params=_ASSORTMENT_PARAMS,
        extra_headers=_ASSORTMENT_HEADER,
    ):
        parsed = _parse_product(entity, uuids, folder_map)
        if parsed is None:
            skipped += 1
            continue
        records.append(parsed)

    log.info("dim_products: получено %d записей, пропущено %d (service)",
             len(records), skipped)

    if not records:
        raise ValueError("dim_products: пустой ответ от API — прерываем")

    # ── GCS raw ──────────────────────────────────────────────────────────────
    upload_json_gz(
        gcs_client, records,
        f"products/incremental/run_{run_id}.json.gz",
    )

    # ── Staging (WRITE_TRUNCATE) ──────────────────────────────────────────────
    job_config = bigquery.LoadJobConfig(
        schema=_SCHEMA,
        write_disposition="WRITE_TRUNCATE",
    )
    job = bq_client.load_table_from_json(records, _STG_TABLE,
                                         job_config=job_config)
    job.result()
    log.info("dim_products: staging загружен (%d строк)", len(records))

    # ── MERGE → core.dim_products (SCD1) ─────────────────────────────────────
    merge_sql = f"""
    MERGE `{_CORE_TABLE}` T
    USING `{_STG_TABLE}` S
    ON T.product_id = S.product_id

    WHEN MATCHED THEN UPDATE SET
        T.name              = S.name,
        T.article           = S.article,
        T.product_folder    = S.product_folder,
        T.parent_product_id = S.parent_product_id,
        T.entity_type       = S.entity_type,
        T.created           = SAFE.PARSE_DATE('%Y-%m-%d', LEFT(S.created, 10)),
        T.shelf_life        = S.shelf_life,
        T.weight            = S.weight,
        T._loaded_at        = CAST(S._loaded_at AS TIMESTAMP)

    WHEN NOT MATCHED THEN INSERT (
        product_id, name, article, product_folder,
        parent_product_id, entity_type, created,
        shelf_life, weight, _loaded_at
    ) VALUES (
        S.product_id, S.name, S.article, S.product_folder,
        S.parent_product_id, S.entity_type,
        SAFE.PARSE_DATE('%Y-%m-%d', LEFT(S.created, 10)),
        S.shelf_life,
        S.weight,
        CAST(S._loaded_at AS TIMESTAMP)
    )
    """
    bq_client.query(merge_sql).result()
    log.info("dim_products: MERGE в core завершён")

    return len(records)