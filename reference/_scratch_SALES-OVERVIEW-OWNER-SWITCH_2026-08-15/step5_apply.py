#!/usr/bin/env python3
"""
SALES-OVERVIEW-OWNER-SWITCH: подмена params (текста запроса) живого transferConfig
sq_marts_sales_overview. Python вместо heredoc — прецедент M-22 (обрезанный SQL
через heredoc), форма подтверждена прецедентами fx_policy_expenses_2026-07-28,
ingest_moment_zone_fix_deploy_2026-08-09.
"""
import json
import subprocess
import sys

CONFIG = "projects/420804682491/locations/asia-east1/transferConfigs/69ff34b4-0000-2b2b-a390-14c14ef7af10"
SQL_PATH = "reference/sql/sq_marts_sales_overview.sql"

with open(SQL_PATH, "r", encoding="utf-8") as f:
    query = f.read()

params = json.dumps({"query": query})

cmd = [
    "bq", "update", "--transfer_config",
    "--params", params,
    CONFIG,
]

print("=== date -u (start) ===")
subprocess.run(["date", "-u"], check=True)
print("=== gcloud auth list (start) ===")
subprocess.run(["gcloud", "auth", "list"], check=True)

print("=== bq update --transfer_config ===")
result = subprocess.run(cmd, capture_output=True, text=True)
print("rc:", result.returncode)
print("stdout:", result.stdout)
print("stderr:", result.stderr)
if result.returncode != 0:
    sys.exit(result.returncode)

print("=== date -u (end) ===")
subprocess.run(["date", "-u"], check=True)
print("=== gcloud auth list (end) ===")
subprocess.run(["gcloud", "auth", "list"], check=True)
