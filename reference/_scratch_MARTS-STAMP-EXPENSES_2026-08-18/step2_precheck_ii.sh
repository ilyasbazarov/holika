#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/../.."

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

OUT_DIR="reference/_scratch_MARTS-STAMP-EXPENSES_2026-08-18"
SQL_FILE="reference/sql/sq_marts_expenses_stamped_2026-08-13.sql"

echo "=== bq query --dry_run (подготовленный текст) ==="
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --dry_run --format=prettyjson \
  < "${SQL_FILE}" > "${OUT_DIR}/dryrun_2026-08-18.json" 2> "${OUT_DIR}/dryrun_2026-08-18.err"
echo "rc=$?"
cat "${OUT_DIR}/dryrun_2026-08-18.err"
echo "--- totalBytesProcessed ---"
grep -A1 "totalBytesProcessed" "${OUT_DIR}/dryrun_2026-08-18.json" | head -4

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
