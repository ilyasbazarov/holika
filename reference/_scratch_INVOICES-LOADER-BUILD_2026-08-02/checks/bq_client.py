"""Общий клиент BigQuery для проверочных скриптов сессии — пользовательские креды
gcloud (ADC внутри venv недоступен), тот же принципал, что уже гоняет bq CLI."""
import subprocess

from google.cloud import bigquery
from google.oauth2.credentials import Credentials


def get_client(project="msklad-bi-prod"):
    token = subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()
    creds = Credentials(token)
    return bigquery.Client(project=project, credentials=creds)
