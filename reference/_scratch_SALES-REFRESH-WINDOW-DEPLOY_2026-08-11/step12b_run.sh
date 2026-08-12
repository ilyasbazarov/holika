#!/usr/bin/env bash
set -uo pipefail
URL="https://cf-facts-xw5u2boozq-de.a.run.app"
WINDOW_DAYS=106
RUN_ID="salesrefreshwindowdeploy106b"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

call() {
  local mode="$1"
  local TOKEN
  TOKEN="$(gcloud auth print-identity-token)"
  echo "=== POST mode=${mode} window_days=${WINDOW_DAYS} run_id=${RUN_ID} ($(date -u)) ==="
  curl -sS -w '\nHTTP_STATUS:%{http_code}\n' -X POST "$URL" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"run_id\":\"${RUN_ID}\",\"mode\":\"${mode}\",\"window_days\":${WINDOW_DAYS}}" \
    --max-time 550
  echo
  echo "=== конец mode=${mode} ($(date -u)) rc=$? ==="
}

echo "### 2/4 perimeter (staging периметра) ###"
call perimeter

echo "### 3/4 promote (MERGE продажи) ###"
call promote

echo "### 4/4 perimeter_promote (MERGE периметр) ###"
call perimeter_promote

echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
