"""
Шаг 5 брифа INVOICES-LOADER-DEPLOY: полный прогон загрузчика счетов против
тестовой staging-таблицы вместо core.fact_customer_invoices.
Ничего не пишет в core.* — только в *_staging (мандат ADR-115 §12, шесть оговорок ADR-076 §5).
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "code", "cf-finance"))
import invoices  # noqa: E402
import requests
from google.cloud import bigquery
from google.oauth2.credentials import Credentials as OAuthCredentials

TEST_CORE_TABLE = "msklad-bi-prod.stg_msklad.fact_customer_invoices_core_test_staging"

token = os.environ["MSKLAD_TOKEN"]
gcloud_access_token = os.environ["GCLOUD_ACCESS_TOKEN"]
gcp_credentials = OAuthCredentials(gcloud_access_token)
bq = bigquery.Client(project=invoices.PROJECT, credentials=gcp_credentials)
session = requests.Session()

result = invoices.run_invoices_etl(token, bq, session, core_table=TEST_CORE_TABLE)

print("=== ИТОГ (числа, не метка) ===")
for k, v in result.items():
    print(f"{k} = {v}")
