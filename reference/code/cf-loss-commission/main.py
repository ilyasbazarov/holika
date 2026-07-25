import os
import time
import json
import datetime
import functions_framework
import requests
from google.cloud import bigquery

PROJECT = "msklad-bi-prod"
BQ_STG_LOSS = f"{PROJECT}.stg_msklad.fact_loss_stg"
BQ_STG_COMM = f"{PROJECT}.stg_msklad.fact_commissionreportin_stg"
BQ_CORE_LOSS = f"{PROJECT}.core.fact_loss"
BQ_CORE_COMM = f"{PROJECT}.core.fact_commissionreportin"

MSKLAD_BASE = "https://api.moysklad.ru/api/remap/1.2"
TOKEN = os.environ["MSKLAD_TOKEN"]
HEADERS = {"Authorization": f"Bearer {TOKEN}"}
LIMIT = 100
TIMEOUT = 90
SLEEP_S = 0.25

bq = bigquery.Client(project=PROJECT)
_CURRENCY_RATE_CACHE = {}


def _api_get(path, params):
    url = f"{MSKLAD_BASE}/{path}"
    for attempt in range(5):
        resp = requests.get(url, headers=HEADERS, params=params, timeout=TIMEOUT)
        if resp.status_code == 429:
            time.sleep(5 * (attempt + 1))
            continue
        if resp.status_code in (502, 503, 504):
            time.sleep(3 * (attempt + 1))
            continue
        resp.raise_for_status()
        return resp.json()
    resp.raise_for_status()


def _fetch_all(entity, filter_str, expand):
    rows, offset = [], 0
    while True:
        params = {"filter": filter_str, "expand": expand, "limit": LIMIT, "offset": offset}
        data = _api_get(f"entity/{entity}", params)
        page = data.get("rows", [])
        rows.extend(page)
        if len(page) < LIMIT:
            break
        offset += LIMIT
        time.sleep(SLEEP_S)
    return rows


def _fetch_current_rate(iso_code):
    """ADR-029 (Q-50): текущий курс валюты из entity/currency — замена хардкода 1.0.
    ВАЖНО: точная форма поля 'rate' в ответе entity/currency не была проверена на живых
    данных на момент этой правки (в проекте не было ни одного не-KGS документа для проверки,
    Q-51). Код обрабатывает и объектную {"value": ...}, и скалярную форму, но при первом
    реальном срабатывании этой ветки — проверь лог ниже глазами, не доверяй молча."""
    if iso_code in _CURRENCY_RATE_CACHE:
        return _CURRENCY_RATE_CACHE[iso_code]
    data = _api_get("entity/currency", {})
    for c in data.get("rows", []):
        if c.get("isoCode") == iso_code:
            rate_field = c.get("rate")
            value = rate_field.get("value") if isinstance(rate_field, dict) else rate_field
            if value is None:
                raise RuntimeError(
                    f"entity/currency: не удалось прочитать курс для {iso_code}, "
                    f"сырое поле rate={rate_field!r} — проверь вручную, не догадка"
                )
            _CURRENCY_RATE_CACHE[iso_code] = float(value)
            print(f"INFO: текущий курс {iso_code} = {value} (из entity/currency)")
            return _CURRENCY_RATE_CACHE[iso_code]
    raise RuntimeError(f"entity/currency: валюта {iso_code} не найдена в справочнике")


def _rate_and_currency(doc):
    """ADR-010 канон: minor_units ÷ 100 × rate.value документа, если задан;
    иначе — текущий курс валюты из entity/currency (ADR-029; было: хардкод 1.0).
    currency_code — isoCode (буквенный ISO), не code (числовой ISO)."""
    rate = doc.get("rate") or {}
    rate_value = rate.get("value")
    currency = (rate.get("currency") or {})
    currency_code = currency.get("isoCode") or currency.get("name") or "KGS"
    if rate_value is None:
        if currency_code == "KGS":
            rate_value = 1.0
        else:
            rate_value = _fetch_current_rate(currency_code)
            print(f"WARNING: doc {doc.get('id')} currency={currency_code} без rate.value — "
                  f"применён текущий курс {rate_value} (ADR-029, fallback).")
    return float(rate_value), currency_code


def _to_kgs(minor_units, rate_value):
    return (minor_units or 0) / 100.0 * rate_value


def fetch_loss(start_date, end_date):
    filter_str = f"moment>={start_date} 00:00:00;moment<{end_date} 00:00:00"
    docs = _fetch_all("loss", filter_str, expand="expenseItem,agent,rate.currency")
    rows = []
    for d in docs:
        rate_value, currency_code = _rate_and_currency(d)
        minor_units = d.get("sum")
        expense_item = d.get("expenseItem") or {}
        agent = d.get("agent") or {}
        rows.append({
            "document_id": d["id"],
            "moment": d.get("moment"),
            "expense_item_id": expense_item.get("id"),
            "expense_item_name": expense_item.get("name"),
            "agent_id": agent.get("id"),
            "agent_name": agent.get("name"),
            "project_id": (d.get("project") or {}).get("id"),
            "sales_channel_id": (d.get("salesChannel") or {}).get("id"),
            "currency_code": currency_code,
            "rate_value": rate_value,
            "applicable": d.get("applicable", True),
            "sum_kgs": round(_to_kgs(minor_units, rate_value), 2),
            "_loaded_at": datetime.datetime.utcnow().isoformat(),
        })
    return rows


def fetch_commission(start_date, end_date):
    filter_str = f"moment>={start_date} 00:00:00;moment<{end_date} 00:00:00"
    docs = _fetch_all("commissionreportin", filter_str, expand="agent,rate.currency,positions")
    rows = []
    for d in docs:
        rate_value, currency_code = _rate_and_currency(d)
        positions = (d.get("positions") or {}).get("rows", [])
        reward_raw = sum(p.get("reward", 0) for p in positions)
        overhead_raw = (d.get("commissionOverhead") or {}).get("sum")
        agent = d.get("agent") or {}
        reward_kgs = round(_to_kgs(reward_raw, rate_value), 2)
        overhead_kgs = round(_to_kgs(overhead_raw, rate_value), 2)
        rows.append({
            "document_id": d["id"],
            "moment": d.get("moment"),
            "agent_id": agent.get("id"),
            "currency_code": currency_code,
            "rate_value": rate_value,
            "reward_sum_kgs": reward_kgs,
            "commission_overhead_sum_kgs": overhead_kgs,
            "sum_kgs": round(reward_kgs + overhead_kgs, 2),
            "_loaded_at": datetime.datetime.utcnow().isoformat(),
        })
    return rows


LOSS_SCHEMA = [
    bigquery.SchemaField("document_id", "STRING"),
    bigquery.SchemaField("moment", "TIMESTAMP"),
    bigquery.SchemaField("expense_item_id", "STRING"),
    bigquery.SchemaField("expense_item_name", "STRING"),
    bigquery.SchemaField("agent_id", "STRING"),
    bigquery.SchemaField("agent_name", "STRING"),
    bigquery.SchemaField("project_id", "STRING"),
    bigquery.SchemaField("sales_channel_id", "STRING"),
    bigquery.SchemaField("currency_code", "STRING"),
    bigquery.SchemaField("rate_value", "FLOAT64"),
    bigquery.SchemaField("applicable", "BOOLEAN"),
    bigquery.SchemaField("sum_kgs", "FLOAT64"),
    bigquery.SchemaField("_loaded_at", "TIMESTAMP"),
]

COMM_SCHEMA = [
    bigquery.SchemaField("document_id", "STRING"),
    bigquery.SchemaField("moment", "TIMESTAMP"),
    bigquery.SchemaField("agent_id", "STRING"),
    bigquery.SchemaField("currency_code", "STRING"),
    bigquery.SchemaField("rate_value", "FLOAT64"),
    bigquery.SchemaField("reward_sum_kgs", "FLOAT64"),
    bigquery.SchemaField("commission_overhead_sum_kgs", "FLOAT64"),
    bigquery.SchemaField("sum_kgs", "FLOAT64"),
    bigquery.SchemaField("_loaded_at", "TIMESTAMP"),
]


def _load_staging(rows, table_id, schema):
    job_config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition="WRITE_TRUNCATE",
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
    )
    job = bq.load_table_from_json(rows or [], table_id, job_config=job_config)
    job.result()
    return len(rows)


def _merge_loss():
    sql = f"""
    MERGE `{BQ_CORE_LOSS}` T
    USING `{BQ_STG_LOSS}` S
    ON T.document_id = S.document_id
    WHEN MATCHED THEN UPDATE SET
      moment = S.moment, expense_item_id = S.expense_item_id, expense_item_name = S.expense_item_name,
      agent_id = S.agent_id, agent_name = S.agent_name, project_id = S.project_id,
      sales_channel_id = S.sales_channel_id, currency_code = S.currency_code,
      rate_value = S.rate_value, applicable = S.applicable, sum_kgs = S.sum_kgs,
      _loaded_at = S._loaded_at
    WHEN NOT MATCHED THEN INSERT (
      document_id, moment, expense_item_id, expense_item_name, agent_id, agent_name,
      project_id, sales_channel_id, currency_code, rate_value, applicable, sum_kgs, _loaded_at
    )
    VALUES (
      S.document_id, S.moment, S.expense_item_id, S.expense_item_name, S.agent_id, S.agent_name,
      S.project_id, S.sales_channel_id, S.currency_code, S.rate_value, S.applicable, S.sum_kgs, S._loaded_at
    )
    """
    bq.query(sql).result()


def _merge_commission():
    sql = f"""
    MERGE `{BQ_CORE_COMM}` T
    USING `{BQ_STG_COMM}` S
    ON T.document_id = S.document_id
    WHEN MATCHED THEN UPDATE SET
      moment = S.moment, agent_id = S.agent_id, currency_code = S.currency_code,
      rate_value = S.rate_value, reward_sum_kgs = S.reward_sum_kgs,
      commission_overhead_sum_kgs = S.commission_overhead_sum_kgs, sum_kgs = S.sum_kgs,
      _loaded_at = S._loaded_at
    WHEN NOT MATCHED THEN INSERT (
      document_id, moment, agent_id, currency_code, rate_value,
      reward_sum_kgs, commission_overhead_sum_kgs, sum_kgs, _loaded_at
    )
    VALUES (
      S.document_id, S.moment, S.agent_id, S.currency_code, S.rate_value,
      S.reward_sum_kgs, S.commission_overhead_sum_kgs, S.sum_kgs, S._loaded_at
    )
    """
    bq.query(sql).result()


@functions_framework.http
def main(request):
    body = request.get_json(silent=True) or {}
    start_date = body.get("start_date") or "2020-01-01"
    end_date = body.get("end_date") or (datetime.datetime.utcnow() + datetime.timedelta(days=1)).strftime("%Y-%m-%d")

    loss_rows = fetch_loss(start_date, end_date)
    n_loss = _load_staging(loss_rows, BQ_STG_LOSS, LOSS_SCHEMA)
    _merge_loss()

    comm_rows = fetch_commission(start_date, end_date)
    n_comm = _load_staging(comm_rows, BQ_STG_COMM, COMM_SCHEMA)
    _merge_commission()

    result = {"start_date": start_date, "end_date": end_date,
              "loss_staged": n_loss, "commission_staged": n_comm, "status": "ok"}
    print(json.dumps(result))
    return (json.dumps(result), 200)
