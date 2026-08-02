#!/usr/bin/env bash
# run_dryrun.sh — SALES-MERGE-DRYRUN, вопрос (а)
# CLAUDE.md §★ Исполнение облачных команд: date -u и gcloud auth list первой И последней командой.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== bq query --dry_run (test_merge.sql) ==="
bq query --use_legacy_sql=false --dry_run --project_id=msklad-bi-prod < "$SCRIPT_DIR/test_merge.sql"

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== date -u (end) ==="
date -u
