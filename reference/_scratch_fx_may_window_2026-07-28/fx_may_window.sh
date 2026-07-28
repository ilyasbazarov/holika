#!/bin/bash
set -uo pipefail

WORKDIR="/private/tmp/claude-501/-Users-ilyasbazarov-Desktop-msklad-project-holika/5e4e79a4-f604-46f4-b31d-2789b2d68853/scratchpad/fx_may_window"
cd "$WORKDIR" || exit 1

echo "=================================================================="
echo "=== STEP 0 — UTC ANCHOR + IDENTITY (FIRST) ======================="
echo "=================================================================="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
gcloud config get-value project

echo
echo "=================================================================="
echo "=== STEP D1 — locate + read nbkr_dailyrus_raw.xls ================"
echo "=================================================================="
echo "--- gcloud storage ls -r (full bucket, filtering to nbkr) ---"
gcloud storage ls -r 'gs://msklad-raw-msklad-bi-prod/**' > "$WORKDIR/bucket_full_listing.txt" 2>&1
echo "full listing saved, $(wc -l < "$WORKDIR/bucket_full_listing.txt") lines"
grep -i "nbkr" "$WORKDIR/bucket_full_listing.txt" || echo "GREP_NBKR_NO_MATCH"

echo
echo "--- stat on candidate object (path from repo lead, verified above) ---"
gcloud storage ls -L 'gs://msklad-raw-msklad-bi-prod/fx-rates/nbkr_dailyrus_raw.xls' 2>&1

echo
echo "--- download candidate ---"
gcloud storage cp 'gs://msklad-raw-msklad-bi-prod/fx-rates/nbkr_dailyrus_raw.xls' "$WORKDIR/nbkr_dailyrus_raw.xls" 2>&1
ls -la "$WORKDIR/nbkr_dailyrus_raw.xls" 2>&1
echo "--- byte-level check (first 64 bytes, hex) ---"
od -An -tx1 "$WORKDIR/nbkr_dailyrus_raw.xls" 2>&1 | head -5
echo "--- file(1) type ---"
file "$WORKDIR/nbkr_dailyrus_raw.xls" 2>&1

echo
echo "--- reader attempt 1: python3 + pandas ---"
python3 - "$WORKDIR/nbkr_dailyrus_raw.xls" <<'PYEOF' 2>&1
import sys
path = sys.argv[1]
try:
    import pandas as pd
    print("pandas import OK, version", pd.__version__)
    try:
        xls = pd.ExcelFile(path)
        print("sheet_names:", xls.sheet_names)
        for sn in xls.sheet_names:
            df = xls.parse(sn, header=None, nrows=50)
            print(f"--- sheet {sn} shape (first 50 rows) ---", df.shape)
            print(df.to_string())
    except Exception as e:
        print("PANDAS_READ_FAIL:", repr(e))
except Exception as e:
    print("PANDAS_IMPORT_FAIL:", repr(e))
PYEOF

echo
echo "--- reader attempt 2: python3 + openpyxl (raw, no pandas) ---"
python3 - "$WORKDIR/nbkr_dailyrus_raw.xls" <<'PYEOF' 2>&1
import sys
path = sys.argv[1]
try:
    import openpyxl
    print("openpyxl import OK, version", openpyxl.__version__)
    wb = openpyxl.load_workbook(path, data_only=True)
    print("sheetnames:", wb.sheetnames)
except Exception as e:
    print("OPENPYXL_FAIL:", repr(e))
PYEOF

echo
echo "--- reader attempt 3: python3 + xlrd (legacy .xls) ---"
python3 - "$WORKDIR/nbkr_dailyrus_raw.xls" <<'PYEOF' 2>&1
import sys
path = sys.argv[1]
try:
    import xlrd
    print("xlrd import OK, version", xlrd.__VERSION__)
    book = xlrd.open_workbook(path)
    print("sheet_names:", book.sheet_names())
    sh = book.sheet_by_index(0)
    print("nrows", sh.nrows, "ncols", sh.ncols)
    for r in range(min(50, sh.nrows)):
        print(sh.row_values(r))
except Exception as e:
    print("XLRD_FAIL:", repr(e))
PYEOF

echo
echo "--- reader attempt 4: libreoffice --headless --convert-to csv ---"
if command -v libreoffice >/dev/null 2>&1; then
    libreoffice --headless --convert-to csv --outdir "$WORKDIR" "$WORKDIR/nbkr_dailyrus_raw.xls" 2>&1
    ls -la "$WORKDIR"/*.csv 2>&1
    if [ -f "$WORKDIR/nbkr_dailyrus_raw.csv" ]; then
        echo "--- csv head/tail ---"
        head -20 "$WORKDIR/nbkr_dailyrus_raw.csv"
        echo "..."
        tail -20 "$WORKDIR/nbkr_dailyrus_raw.csv"
    fi
else
    echo "LIBREOFFICE_NOT_FOUND"
fi

echo
echo "=================================================================="
echo "=== STEP D2 — BigQuery job history over dim_fx_rates window ======"
echo "=================================================================="
WIN_START_MS=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "2026-04-28T00:00:00Z" "+%s" 2>/dev/null)
if [ -z "${WIN_START_MS:-}" ]; then
  WIN_START_MS=$(date -u -d "2026-04-28T00:00:00Z" "+%s" 2>/dev/null)
fi
WIN_END_MS=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "2026-06-05T00:00:00Z" "+%s" 2>/dev/null)
if [ -z "${WIN_END_MS:-}" ]; then
  WIN_END_MS=$(date -u -d "2026-06-05T00:00:00Z" "+%s" 2>/dev/null)
fi
WIN_START_MS=$((WIN_START_MS * 1000))
WIN_END_MS=$((WIN_END_MS * 1000))
echo "window: 2026-04-28T00:00:00Z .. 2026-06-05T00:00:00Z"
echo "min_creation_time(ms)=$WIN_START_MS max_creation_time(ms)=$WIN_END_MS"

echo
echo "--- D2(a) bq ls -j --all_users over window ---"
bq --project_id=msklad-bi-prod ls -j --all_users \
  --min_creation_time="$WIN_START_MS" --max_creation_time="$WIN_END_MS" \
  -n 1000 --format=prettyjson > "$WORKDIR/d2a_bq_ls_jobs.json" 2>&1
echo "rc=$?"
wc -l "$WORKDIR/d2a_bq_ls_jobs.json"
cat "$WORKDIR/d2a_bq_ls_jobs.json"

echo
echo "--- D2(b) INFORMATION_SCHEMA.JOBS_BY_PROJECT (region asia-east1) ---"
bq --project_id=msklad-bi-prod query --use_legacy_sql=false --format=prettyjson "
SELECT job_id, user_email, creation_time, statement_type, query
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time BETWEEN TIMESTAMP('2026-04-28T00:00:00Z') AND TIMESTAMP('2026-06-05T00:00:00Z')
  AND destination_table.dataset_id = 'core'
  AND destination_table.table_id = 'dim_fx_rates'
ORDER BY creation_time
" > "$WORKDIR/d2b_information_schema.json" 2>&1
echo "rc=$?"
cat "$WORKDIR/d2b_information_schema.json"

echo
echo "=================================================================="
echo "=== STEP D3 — identify pre-migration rate loader =================="
echo "=================================================================="
echo "--- gcloud functions list ---"
gcloud functions list --format="table(name,status,region,updateTime)" 2>&1
echo
echo "--- gcloud run services list --region=asia-east1 ---"
gcloud run services list --platform=managed --region=asia-east1 --format="table(metadata.name,status.url,status.latestReadyRevisionName)" 2>&1
echo
echo "--- gcloud scheduler jobs list --location=asia-east1 ---"
gcloud scheduler jobs list --location=asia-east1 --format="table(name,schedule,state)" 2>&1
echo
echo "--- gcloud workflows list --location=asia-east1 ---"
gcloud workflows list --location=asia-east1 --format="table(name,state)" 2>&1

echo
echo "--- candidates by name pattern (fx|rate|nbkr) across above listings ---"
{
  gcloud functions list --format="value(name)" 2>/dev/null
  gcloud run services list --platform=managed --region=asia-east1 --format="value(metadata.name)" 2>/dev/null
  gcloud scheduler jobs list --location=asia-east1 --format="value(name)" 2>/dev/null
  gcloud workflows list --location=asia-east1 --format="value(name)" 2>/dev/null
} > "$WORKDIR/d3_all_names.txt" 2>&1
cat "$WORKDIR/d3_all_names.txt"
echo "--- grep -iE 'fx|rate|nbkr' over all names ---"
grep -iE 'fx|rate|nbkr' "$WORKDIR/d3_all_names.txt" || echo "GREP_D3_NO_MATCH"

echo
echo "=================================================================="
echo "=== STEP 4 — MIN/MAX/COUNT border on core.dim_fx_rates ==========="
echo "=================================================================="
bq --project_id=msklad-bi-prod query --use_legacy_sql=false --format=prettyjson "
SELECT
  MIN(date) AS min_date,
  MAX(date) AS max_date,
  COUNT(*) AS n_rows,
  COUNT(DISTINCT rate_kgs_per_usd) AS n_distinct_rates,
  MIN(rate_kgs_per_usd) AS min_rate,
  MAX(rate_kgs_per_usd) AS max_rate
FROM \`msklad-bi-prod.core.dim_fx_rates\`
" 2>&1

echo
echo "=================================================================="
echo "=== STEP 6 — UTC ANCHOR + IDENTITY (LAST) ========================="
echo "=================================================================="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'

echo
echo "WORKDIR: $WORKDIR"
