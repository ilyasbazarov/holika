import os
import requests
import datetime
from google.cloud import bigquery

TOKEN = os.environ.get("TOKEN")
PROJECT = "msklad-bi-prod"
STG_TABLE = f"{PROJECT}.core.fact_payments_stg"
BQ = bigquery.Client(project=PROJECT)

def parse_href(meta_obj):
    href = (meta_obj or {}).get("meta", {}).get("href")
    return href.split("/")[-1].split("?")[0] if href else None

records = []
for entity_type in ["paymentout", "cashout"]:
    print(f"Fetching {entity_type}...")
    url = f"https://api.moysklad.ru/api/remap/1.2/entity/{entity_type}?expand=expenseItem,agent,project,salesChannel&limit=1000"
    headers = {"Authorization": f"Bearer {TOKEN}"}
    
    while url:
        resp = requests.get(url, headers=headers).json()
        for row in resp.get("rows", []):
            records.append({
                "payment_id": row.get("id"),
                "payment_name": str(row.get("name")) if row.get("name") is not None else None,
                "payment_type": entity_type,
                "moment": row.get("moment"),
                "expense_item_id": parse_href(row.get("expenseItem")),
                "expense_item_name": row.get("expenseItem", {}).get("name"),
                "agent_id": parse_href(row.get("agent")),
                "agent_name": row.get("agent", {}).get("name"),
                "project_id": parse_href(row.get("project")),
                "project_name": row.get("project", {}).get("name"),
                "sales_channel_id": parse_href(row.get("salesChannel")),
                "sales_channel_name": row.get("salesChannel", {}).get("name"),
                "payment_purpose": row.get("paymentPurpose"),
                "sum_kgs": (row.get("sum") or 0) / 100.0,
                "_loaded_at": datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
            })
        url = resp.get("meta", {}).get("nextHref")

print(f"Total records fetched: {len(records)}")

if records:
    print("Loading to STG table...")
    job_config = bigquery.LoadJobConfig(
        write_disposition="WRITE_TRUNCATE",
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON
    )
    BQ.load_table_from_json(records, STG_TABLE, job_config=job_config).result()
    
    print("Executing MERGE into core table...")
    merge_sql = """
    MERGE `msklad-bi-prod.core.fact_payments` T
    USING `msklad-bi-prod.core.fact_payments_stg` S
    ON T.payment_id = S.payment_id
    WHEN MATCHED THEN UPDATE SET
       T.payment_name        = S.payment_name,
       T.payment_type        = S.payment_type,
       T.moment              = S.moment,
       T.expense_item_id     = S.expense_item_id,
       T.expense_item_name   = S.expense_item_name,
       T.agent_id            = S.agent_id,
       T.agent_name          = S.agent_name,
       T.project_id          = S.project_id,
       T.project_name        = S.project_name,
       T.sales_channel_id    = S.sales_channel_id,
       T.sales_channel_name  = S.sales_channel_name,
       T.payment_purpose     = S.payment_purpose,
       T.sum_kgs             = S.sum_kgs,
       T._loaded_at          = S._loaded_at
    WHEN NOT MATCHED THEN INSERT (
       payment_id, payment_name, payment_type, moment,
       expense_item_id, expense_item_name, agent_id, agent_name,
       project_id, project_name, sales_channel_id, sales_channel_name,
       payment_purpose, sum_kgs, _loaded_at
    ) VALUES (
       S.payment_id, S.payment_name, S.payment_type, S.moment,
       S.expense_item_id, S.expense_item_name, S.agent_id, S.agent_name,
       S.project_id, S.project_name, S.sales_channel_id, S.sales_channel_name,
       S.payment_purpose, S.sum_kgs, S._loaded_at
    )
    """
    BQ.query(merge_sql).result()
    print("MERGE complete.")
