import os
import time
import requests
import datetime
from google.cloud import bigquery
from google.cloud import bigquery_datatransfer
from google.protobuf.timestamp_pb2 import Timestamp

PROJECT = "msklad-bi-prod"
STG_TABLE = f"{PROJECT}.core.fact_payments_stg"

def parse_href(meta_obj):
    href = (meta_obj or {}).get("meta", {}).get("href")
    return href.split("/")[-1].split("?")[0] if href else None

def trigger_marts():
    print("Triggering scheduled query via API...")
    client = bigquery_datatransfer.DataTransferServiceClient()
    parent = "projects/420804682491/locations/asia-east1/transferConfigs/6a22a243-0000-20fd-a458-883d24f4cad4"
    
    now = datetime.datetime.now(datetime.timezone.utc)
    start_time = Timestamp()
    start_time.FromDatetime(now)
    
    request = bigquery_datatransfer.StartManualTransferRunsRequest(
        parent=parent,
        requested_run_time=start_time
    )
    client.start_manual_transfer_runs(request=request)
    print("Marts trigger successful.")

def run_etl():
    token = os.environ.get("MSKLAD_TOKEN") or os.environ.get("TOKEN")
    bq = bigquery.Client(project=PROJECT)
    
    records = []
    for entity_type in ["paymentout", "cashout"]:
        url = f"https://api.moysklad.ru/api/remap/1.2/entity/{entity_type}?expand=expenseItem,agent,project,salesChannel&limit=100"
        headers = {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}
        
        while url:
            resp = requests.get(url, headers=headers)
            time.sleep(0.25)
            resp_json = resp.json()
            
            for row in resp_json.get("rows", []):
                if row.get("applicable") is False:
                    continue
                
                expense_id = parse_href(row.get("expenseItem"))
                
                # Забираем ВСЕ транзакции, чтобы MERGE увидел изменения статусов
                records.append({
                    "payment_id": row.get("id"),
                    "payment_name": str(row.get("name")) if row.get("name") is not None else None,
                    "payment_type": entity_type,
                    "moment": row.get("moment")[:10] if row.get("moment") else None,
                    "expense_item_id": expense_id,
                    "expense_item_name": row.get("expenseItem", {}).get("name"),
                    "agent_id": parse_href(row.get("agent")),
                    "agent_name": row.get("agent", {}).get("name"),
                    "project_id": parse_href(row.get("project")),
                    "project_name": row.get("project", {}).get("name"),
                    "sales_channel_id": parse_href(row.get("salesChannel")),
                    "sales_channel_name": row.get("salesChannel", {}).get("name"),
                    "payment_purpose": row.get("paymentPurpose"),
                    "sum_kgs": float((row.get("sum") or 0) / 100.0),
                    "_loaded_at": datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
                })
            url = resp_json.get("meta", {}).get("nextHref")

    if records:
        print(f"Loading {len(records)} records to STG...")
        
        job_config = bigquery.LoadJobConfig(
            write_disposition="WRITE_TRUNCATE",
            schema=[
                bigquery.SchemaField("payment_id", "STRING"),
                bigquery.SchemaField("payment_name", "STRING"),
                bigquery.SchemaField("payment_type", "STRING"),
                bigquery.SchemaField("moment", "DATE"),
                bigquery.SchemaField("expense_item_id", "STRING"),
                bigquery.SchemaField("expense_item_name", "STRING"),
                bigquery.SchemaField("agent_id", "STRING"),
                bigquery.SchemaField("agent_name", "STRING"),
                bigquery.SchemaField("project_id", "STRING"),
                bigquery.SchemaField("project_name", "STRING"),
                bigquery.SchemaField("sales_channel_id", "STRING"),
                bigquery.SchemaField("sales_channel_name", "STRING"),
                bigquery.SchemaField("payment_purpose", "STRING"),
                bigquery.SchemaField("sum_kgs", "FLOAT64"),
                bigquery.SchemaField("_loaded_at", "TIMESTAMP"),
            ]
        )
        bq.load_table_from_json(records, STG_TABLE, job_config=job_config).result()
        
        print("Running MERGE...")
        merge_sql = """
        MERGE `msklad-bi-prod.core.fact_payments` T
        USING `msklad-bi-prod.core.fact_payments_stg` S
        ON T.payment_id = S.payment_id
        WHEN MATCHED THEN UPDATE SET
           T.payment_name = S.payment_name, T.payment_type = S.payment_type, T.moment = S.moment,
           T.expense_item_id = S.expense_item_id, T.expense_item_name = S.expense_item_name,
           T.agent_id = S.agent_id, T.agent_name = S.agent_name,
           T.project_id = S.project_id, T.project_name = S.project_name,
           T.sales_channel_id = S.sales_channel_id, T.sales_channel_name = S.sales_channel_name,
           T.payment_purpose = S.payment_purpose, T.sum_kgs = S.sum_kgs, T._loaded_at = S._loaded_at
        WHEN NOT MATCHED THEN INSERT (
           payment_id, payment_name, payment_type, moment, expense_item_id, expense_item_name,
           agent_id, agent_name, project_id, project_name, sales_channel_id, sales_channel_name,
           payment_purpose, sum_kgs, _loaded_at
        ) VALUES (
           S.payment_id, S.payment_name, S.payment_type, S.moment, S.expense_item_id, S.expense_item_name,
           S.agent_id, S.agent_name, S.project_id, S.project_name, S.sales_channel_id, S.sales_channel_name,
           S.payment_purpose, S.sum_kgs, S._loaded_at
        )
        """
        bq.query(merge_sql).result()
        
        print("Cleaning up excluded system expenses (ghosts removal)...")
        delete_sql = """
        DELETE FROM `msklad-bi-prod.core.fact_payments`
        WHERE expense_item_id IN (
            '24c0e914-2d8c-11f1-0a80-11b0000c7043',
            '4e1c05f2-0673-11e6-a655-0cc47a342ca4',
            '8dbf9374-0a01-11e4-b9bf-002590a32f46',
            '8dbf99a0-0a01-11e4-a743-002590a32f46'
        )
        """
        bq.query(delete_sql).result()
        
        try:
            trigger_marts()
        except Exception as e:
            print(f"WARNING: trigger_marts() failed (non-fatal, marts have their own schedule): {e}")

def main(request):
    run_etl()
    return "OK", 200

if __name__ == "__main__":
    run_etl()
