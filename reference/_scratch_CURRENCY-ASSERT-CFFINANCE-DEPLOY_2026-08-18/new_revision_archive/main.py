import os
import time
import requests
import datetime
from google.cloud import bigquery
from google.cloud import bigquery_datatransfer
from google.protobuf.timestamp_pb2 import Timestamp

import invoices

PROJECT = "msklad-bi-prod"
STG_TABLE = f"{PROJECT}.core.fact_payments_stg"

def parse_href(meta_obj):
    href = (meta_obj or {}).get("meta", {}).get("href")
    return href.split("/")[-1].split("?")[0] if href else None

def _fetch_currency_map(token):
    """Build {uuid: isoCode} map for all currencies (INGEST-CURRENCY-ASSERT Шаг 3).
    НЕ через expand=rate.currency — ловушка Q-49/02_ERP_CONTRACTS.md:425 (expand молча
    роняется в NULL при limit>100 в списочном ответе); отдельный запрос entity/currency.
    cf-finance не несёт helpers.py/paginate_entity — пагинация инлайн, тем же приёмом,
    что уже использует run_etl() ниже (nextHref)."""
    headers = {"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}
    url = "https://api.moysklad.ru/api/remap/1.2/entity/currency?limit=100"
    currency_map = {}
    while url:
        resp = requests.get(url, headers=headers, timeout=90)   # 02_ERP_CONTRACTS §поведение API
        time.sleep(0.25)
        resp.raise_for_status()
        resp_json = resp.json()
        for row in resp_json.get("rows", []):
            currency_map[parse_href(row)] = row.get("isoCode")
        url = (resp_json.get("meta") or {}).get("nextHref")     # канон ADR-171 §6 для нового кода
    return currency_map

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
    
    # INGEST-CURRENCY-ASSERT Шаг 3: карта валют для детекции ниже. Диагностика не имеет права
    # ронять загрузку, которую наблюдает: недоступность справочника гасит детекцию, не ETL.
    try:
        currency_map = _fetch_currency_map(token)
    except Exception as e:
        currency_map = None
        print(f"WARNING: карта валют недоступна ({type(e).__name__}: {e}) — "
              f"детекция INGEST-CURRENCY-ASSERT в этом прогоне НЕ выполнялась")
    currency_mismatch = 0

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

                # INGEST-CURRENCY-ASSERT Шаг 4 (ADR-101 §5): бинарная детекция «валюта=KGS
                # либо применён rate.value» — арифметика sum_kgs НЕ меняется, только лог.
                if currency_map is not None:
                    rate_obj    = row.get("rate") or {}
                    has_rate    = rate_obj.get("value") is not None
                    currency_id = parse_href(rate_obj.get("currency"))
                    iso_code    = currency_map.get(currency_id) if currency_id else None
                    if not (iso_code == "KGS" or has_rate):
                        currency_mismatch += 1
                        print(
                            f"WARNING: {entity_type} {row.get('id')}: currency={currency_id} "
                            f"(iso={iso_code}) без rate.value — класс ошибки ADR-101 §5"
                        )

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
                    "sum_kgs": float(
                        ((row.get("sum") or 0) / 100.0)
                        * ((row.get("rate") or {}).get("value") or 1.0)
                    ),
                    "_loaded_at": datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
                })
            url = resp_json.get("meta", {}).get("nextHref")

    if currency_map is None:
        print("WARNING: детекция INGEST-CURRENCY-ASSERT в этом прогоне НЕ выполнялась "
              "(карта валют недоступна)")
    elif currency_mismatch:
        print(f"WARNING: {currency_mismatch} платежей с валютой ≠ KGS без rate.value "
              f"(currency_mismatch, INGEST-CURRENCY-ASSERT)")

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

# design §2.2 (reference/invoices_loader_design_2026-08-02.md): диспетчер режимов.
# Умолчание mode="payments" — существующее поведение run_etl(), НЕ трогается: тело,
# которое шлёт finance-daily-update, в репо не задокументировано (11_INFRA_FACTS.md:26
# фиксирует тело только у loss-commission-daily-update), умолчание безопасно при ЛЮБОМ теле.
def main(request):
    body = request.get_json(force=True, silent=True) or {}
    mode = body.get("mode", "payments")
    if mode == "payments":
        run_etl()                      # существующее поведение, не трогается
    elif mode == "invoices":
        token = os.environ.get("MSKLAD_TOKEN") or os.environ.get("TOKEN")
        bq = bigquery.Client(project=invoices.PROJECT)
        session = requests.Session()
        invoices.run_invoices_etl(token, bq, session)
    else:
        return (f"Unknown mode: {mode!r}. Expected: payments | invoices", 400)
    return "OK", 200

if __name__ == "__main__":
    run_etl()
