# ── CF-Dim / dim_counterparties.py ───────────────────────────────────────────
# Выгружает entity/counterparty → stg → SCD2 на owner_employee + SCD1 остальное
#
# Логика SCD2 (3 шага):
#   Шаг 1: UPDATE закрыть записи где owner_employee_id изменился
#   Шаг 2: INSERT новую версию для закрытых + вставить новых контрагентов
#   Шаг 3: UPDATE SCD1-поля (name, country) для активных неизменившихся
#
# Однократная миграция схемы: если scd2_valid_to в BQ — STRING (bootstrap),
# мигрируем в DATE перед первым прогоном CF.

import logging

from google.cloud import bigquery, storage

from config import BQ_CORE, BQ_STG, GCP_PROJECT, TZ_BISHKEK
from helpers import (
    get_custom_attr,
    now_utc,
    paginate_entity,
    parse_href_id,
    upload_json_gz,
)

log = logging.getLogger(__name__)

_STG_TABLE  = f"{BQ_STG}.counterparties_staging"
_CORE_TABLE = f"{BQ_CORE}.dim_counterparties"

_SCHEMA = [
    bigquery.SchemaField("agent_id",          "STRING", mode="REQUIRED"),
    bigquery.SchemaField("name",              "STRING", mode="NULLABLE"),
    bigquery.SchemaField("owner_employee_id", "STRING", mode="NULLABLE"),
    bigquery.SchemaField("country",           "STRING", mode="NULLABLE"),
    bigquery.SchemaField("_loaded_at",        "STRING", mode="NULLABLE"),
]


# ── Schema migration ──────────────────────────────────────────────────────────

def _migrate_schema_if_needed(bq_client: bigquery.Client) -> None:
    """
    Однократная миграция: scd2_valid_from / scd2_valid_to STRING → DATE.
    Bootstrap Недели 1 хранил эти поля как STRING из-за ограничений pandas.
    После миграции становится идемпотентной (тип уже DATE → пропускаем).
    """
    check_sql = f"""
    SELECT data_type
    FROM `{GCP_PROJECT}.core.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name  = 'dim_counterparties'
      AND column_name = 'scd2_valid_to'
    """
    rows      = list(bq_client.query(check_sql).result())
    data_type = rows[0].data_type if rows else None

    if data_type == "DATE":
        log.info("dim_counterparties: схема уже DATE — миграция не нужна")
        return

    if data_type is None:
        log.info("dim_counterparties: таблица не существует — миграция не нужна")
        return

    log.info("dim_counterparties: мигрируем схему %s → DATE", data_type)
    migration_sql = f"""
    CREATE OR REPLACE TABLE `{_CORE_TABLE}` AS
    SELECT
        agent_id,
        name,
        CAST(owner_employee_id  AS STRING)  AS owner_employee_id,
        COALESCE(
            CAST(owner_employee_skey AS STRING),
            GENERATE_UUID()
        )                                   AS owner_employee_skey,
        CAST(country AS STRING)             AS country,
        SAFE.PARSE_DATE(
            '%Y-%m-%d',
            CAST(scd2_valid_from AS STRING)
        )                                   AS scd2_valid_from,
        SAFE.PARSE_DATE(
            '%Y-%m-%d',
            CAST(scd2_valid_to AS STRING)
        )                                   AS scd2_valid_to,
        CAST(scd2_is_current AS BOOL)       AS scd2_is_current,
        _loaded_at
    FROM `{_CORE_TABLE}`
    """
    bq_client.query(migration_sql).result()
    log.info("dim_counterparties: миграция схемы завершена")


# ── Парсинг ───────────────────────────────────────────────────────────────────

def _parse_counterparty(entity: dict, country_uuid: str | None) -> dict:
    agent_id = entity.get("id", "")

    # owner_employee — менеджер-ответственный
    owner_href       = (entity.get("owner", {})
                              .get("meta", {})
                              .get("href", ""))
    owner_employee_id = parse_href_id(owner_href)

    # Страна — кастомное поле типа customentity
    # МойСклад возвращает: {"meta": {...}, "name": "Китай"} — НЕ строку
    country = None
    if country_uuid:
        val = get_custom_attr(entity.get("attributes", []), country_uuid)
        if isinstance(val, dict):
            country = val.get("name")
        elif isinstance(val, str) and val:
            country = val

    return {
        "agent_id":          agent_id,
        "name":              entity.get("name"),
        "owner_employee_id": owner_employee_id,
        "country":           country,
        "_loaded_at":        now_utc(),
    }


# ── SCD2 SQL ──────────────────────────────────────────────────────────────────

def _run_scd2(bq_client: bigquery.Client) -> None:
    today_expr = f"CURRENT_DATE('{TZ_BISHKEK}')"

    # ── Шаг 1: Закрыть записи где owner_employee_id изменился ────────────────
    step1_sql = f"""
    UPDATE `{_CORE_TABLE}` tgt
    SET
        tgt.scd2_valid_to   = {today_expr},
        tgt.scd2_is_current = false,
        tgt._loaded_at      = CURRENT_TIMESTAMP()
    FROM `{_STG_TABLE}` stg
    WHERE tgt.agent_id         = stg.agent_id
      AND tgt.scd2_is_current  = true
      AND COALESCE(tgt.owner_employee_id, '') !=
          COALESCE(stg.owner_employee_id, '')
    """
    bq_client.query(step1_sql).result()
    log.info("SCD2 Шаг 1: закрытие изменившихся записей — OK")

    # ── Шаг 2: INSERT новых версий для закрытых + вставить новых ─────────────
    # Условие: нет активной записи → либо только что закрыли, либо совсем новый
    step2_sql = f"""
    INSERT INTO `{_CORE_TABLE}` (
        agent_id, name, owner_employee_id, owner_employee_skey,
        country, scd2_valid_from, scd2_valid_to, scd2_is_current, _loaded_at
    )
    SELECT
        stg.agent_id,
        stg.name,
        stg.owner_employee_id,
        GENERATE_UUID()        AS owner_employee_skey,
        stg.country,
        {today_expr}           AS scd2_valid_from,
        DATE '9999-12-31'      AS scd2_valid_to,
        true                   AS scd2_is_current,
        CURRENT_TIMESTAMP()    AS _loaded_at
    FROM `{_STG_TABLE}` stg
    WHERE NOT EXISTS (
        SELECT 1 FROM `{_CORE_TABLE}` tgt
        WHERE tgt.agent_id        = stg.agent_id
          AND tgt.scd2_is_current = true
    )
    """
    bq_client.query(step2_sql).result()
    log.info("SCD2 Шаг 2: INSERT новых/изменившихся записей — OK")

    # ── Шаг 3: UPDATE SCD1-поля для неизменившихся активных ──────────────────
    step3_sql = f"""
    UPDATE `{_CORE_TABLE}` tgt
    SET
        tgt.name        = stg.name,
        tgt.country     = stg.country,
        tgt._loaded_at  = CURRENT_TIMESTAMP()
    FROM `{_STG_TABLE}` stg
    WHERE tgt.agent_id        = stg.agent_id
      AND tgt.scd2_is_current = true
    """
    bq_client.query(step3_sql).result()
    log.info("SCD2 Шаг 3: UPDATE SCD1-полей (name, country) — OK")


# ── Main ──────────────────────────────────────────────────────────────────────

def run(session, bq_client: bigquery.Client,
        gcs_client: storage.Client, uuids: dict, run_id: str) -> int:
    # Однократная миграция схемы если нужно
    _migrate_schema_if_needed(bq_client)

    log.info("dim_counterparties: выгрузка из entity/counterparty")
    country_uuid = uuids.get("country")

    records = []
    for entity in paginate_entity(session, "entity/counterparty"):
        records.append(_parse_counterparty(entity, country_uuid))

    log.info("dim_counterparties: получено %d записей", len(records))

    if not records:
        raise ValueError("dim_counterparties: пустой ответ от API — прерываем")

    # ── GCS raw ──────────────────────────────────────────────────────────────
    upload_json_gz(
        gcs_client, records,
        f"counterparties/incremental/run_{run_id}.json.gz",
    )

    # ── Staging (WRITE_TRUNCATE) ──────────────────────────────────────────────
    job_config = bigquery.LoadJobConfig(
        schema=_SCHEMA,
        write_disposition="WRITE_TRUNCATE",
    )
    job = bq_client.load_table_from_json(records, _STG_TABLE,
                                         job_config=job_config)
    job.result()
    log.info("dim_counterparties: staging загружен (%d строк)", len(records))

    # ── SCD2 логика ───────────────────────────────────────────────────────────
    _run_scd2(bq_client)
    log.info("dim_counterparties: SCD2 завершён")

    return len(records)