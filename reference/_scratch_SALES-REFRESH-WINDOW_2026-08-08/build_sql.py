"""
Строит РЕАЛЬНЫЕ тексты MERGE (обе функции, узкая форма) из снапшота
reference/code/cf-facts/bq_ops.py БЕЗ транскрипции — импортом самого модуля.

google-cloud-bigquery не установлен локально; bq_ops.py использует
`from google.cloud import bigquery` только за конструкторами SchemaField/Table/
TimePartitioning на МОДУЛЬНОМ уровне (не внутри _build_merge_sql/_build_perimeter_merge_sql,
где строится сам SQL) — подставляется заглушка ровно с этими именами, дерево вызовов
функций-строителей SQL не тронуто.
"""
import sys
import types
import pathlib

SNAPSHOT_DIR = pathlib.Path(__file__).resolve().parents[1] / "code" / "cf-facts"
sys.path.insert(0, str(SNAPSHOT_DIR))

fake_bigquery = types.ModuleType("google.cloud.bigquery")


class _Stub:
    def __init__(self, *a, **k):
        pass


fake_bigquery.SchemaField = _Stub
fake_bigquery.Table = _Stub
fake_bigquery.TimePartitioning = _Stub
fake_bigquery.TimePartitioningType = types.SimpleNamespace(DAY="DAY")
fake_bigquery.LoadJobConfig = _Stub
fake_bigquery.SourceFormat = types.SimpleNamespace(NEWLINE_DELIMITED_JSON="NEWLINE_DELIMITED_JSON")
fake_bigquery.WriteDisposition = types.SimpleNamespace(WRITE_TRUNCATE="WRITE_TRUNCATE")
fake_bigquery.Client = _Stub

fake_google = types.ModuleType("google")
fake_google_cloud = types.ModuleType("google.cloud")
fake_google.cloud = fake_google_cloud
fake_google_cloud.bigquery = fake_bigquery

sys.modules["google"] = fake_google
sys.modules["google.cloud"] = fake_google_cloud
sys.modules["google.cloud.bigquery"] = fake_bigquery

import config          # noqa: E402
import bq_ops          # noqa: E402

out_dir = pathlib.Path(__file__).resolve().parent

# hourly (7d) — COGS = CORE_BYVARIANT_BCK, как в promote_to_core при window_days<90
sql_hourly = bq_ops._build_merge_sql(config.CORE_BYVARIANT_BCK, config.HOURLY_WINDOW_DAYS)
(out_dir / "merge_sql_hourly.sql").write_text(sql_hourly)

# weekly (90d) — COGS = STG_BYVARIANT, как в promote_to_core при window_days>=90
sql_weekly = bq_ops._build_merge_sql(config.STG_BYVARIANT, config.WEEKLY_WINDOW_DAYS)
(out_dir / "merge_sql_weekly.sql").write_text(sql_weekly)

# perimeter — единственный вызывающий код промоутит с PERIMETER_WINDOW_DAYS (=WEEKLY_WINDOW_DAYS)
sql_perimeter = bq_ops._build_perimeter_merge_sql(config.PERIMETER_WINDOW_DAYS)
(out_dir / "merge_sql_perimeter.sql").write_text(sql_perimeter)

print("wrote merge_sql_hourly.sql, merge_sql_weekly.sql, merge_sql_perimeter.sql")
print(f"HOURLY_WINDOW_DAYS={config.HOURLY_WINDOW_DAYS}  WEEKLY_WINDOW_DAYS={config.WEEKLY_WINDOW_DAYS}  PERIMETER_WINDOW_DAYS={config.PERIMETER_WINDOW_DAYS}")
print(f"CORE_FACT_SALES={config.CORE_FACT_SALES}")
