#!/usr/bin/env bash
# PARITY-STOCK-SNAPSHOT-SYNC — Шаг 1: принимает ли report/stock/all ретроспективный момент.
# Один скрипт на шаг (ADR-077 §6). Диагностика (выбор кандидата момента) и read-only GET
# объединены в одном скрипте, т.к. не-идемпотентных действий здесь нет (ADR-055 §2 не нарушается).
set -euo pipefail

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRATCH_DIR"

echo "=== UTC-якорь НАЧАЛО ==="
date -u
echo "=== Личность НАЧАЛО ==="
gcloud auth list

echo
echo "=== Шаг 1a: выбор кандидата ретроспективного момента (bq, read-only) ==="
bq query --use_legacy_sql=false --format=prettyjson --max_rows=20 '
SELECT
  date_snapshot,
  MIN(_loaded_at) AS min_loaded_at,
  MAX(_loaded_at) AS max_loaded_at,
  COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_inventory`
WHERE date_snapshot = DATE_SUB(CURRENT_DATE("Asia/Bishkek"), INTERVAL 7 DAY)
GROUP BY date_snapshot
' | tee step1a_candidate_partition.json

CANDIDATE_LOADED_AT=$(python3 -c "
import json
with open('step1a_candidate_partition.json') as f:
    rows = json.load(f)
if not rows:
    raise SystemExit('NO_PARTITION_FOUND')
print(rows[0]['min_loaded_at'])
")
echo "Партиция 7 суток назад, min(_loaded_at) (UTC) = ${CANDIDATE_LOADED_AT}"

# Кандидат-параметр момента: формат 'YYYY-MM-DD HH:MM:SS' (аналогия report/profit/*, см.
# reference/report_fields_2026-07-31.md §2/§3), время берётся из _loaded_at той партиции —
# заведомо дальше суточной амплитуды оборота (несколько суток, не "вчера").
CANDIDATE_MOMENT=$(python3 -c "
import sys
raw = sys.argv[1]
# BQ отдаёт вида '2026-07-28 21:00:04+00:00' или '2026-07-28T21:00:04Z' в зависимости от формата
raw = raw.replace('T', ' ').replace('Z', '').split('+')[0].split('.')[0]
print(raw)
" "${CANDIDATE_LOADED_AT}")
echo "Кандидат moment (сырое значение из BQ, без преобразования зоны) = ${CANDIDATE_MOMENT}"
echo "${CANDIDATE_MOMENT}" > step1a_candidate_moment.txt

echo
echo "=== Шаг 1b: секрет msklad-token — чтение в переменную окружения (не печатается) ==="
MSKLAD_TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)
echo "Токен прочитан, длина=${#MSKLAD_TOKEN} символов (значение не печатается)"

BASE="https://api.moysklad.ru/api/remap/1.2/report/stock/all"

do_call() {
  local label="$1"
  local extra_params="$2"
  local out_body="$3"
  local out_meta="$4"

  local url="${BASE}?stockMode=all&quantityMode=all&limit=1000${extra_params}"
  echo "--- ${label} ---"
  echo "URL: ${url}"

  local http_code
  http_code=$(curl -sS --compressed -o "${out_body}" -w "%{http_code}" \
    -H "Authorization: Bearer ${MSKLAD_TOKEN}" \
    -H "Accept-Encoding: gzip" \
    "${url}")
  echo "HTTP: ${http_code}" | tee "${out_meta}"

  python3 - "${out_body}" "${out_meta}" <<'PYEOF'
import json, sys
body_path, meta_path = sys.argv[1], sys.argv[2]
with open(body_path, "r", encoding="utf-8") as f:
    raw = f.read()
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    with open(meta_path, "a") as m:
        m.write("BODY_NOT_JSON\n")
    sys.exit(0)
with open(meta_path, "a") as m:
    if "errors" in data:
        m.write(f"errors={json.dumps(data['errors'], ensure_ascii=False)}\n")
    if "meta" in data and isinstance(data["meta"], dict):
        m.write(f"meta.size={data['meta'].get('size')}\n")
    rows = data.get("rows")
    if isinstance(rows, list):
        total_stock = sum(float(r.get("stock") or 0) for r in rows)
        m.write(f"rows_count={len(rows)}\n")
        m.write(f"SUM(stock)={total_stock}\n")
        if rows:
            m.write(f"row0_fields={sorted(rows[0].keys())}\n")
PYEOF
  cat "${out_meta}"
  echo
}

echo
echo "=== Шаг 1c: три вызова в одну минуту ==="
date -u

do_call "1: КОНТРОЛЬ (без временного параметра)" "" "step1_control1_body.json" "step1_control1_meta.txt"
do_call "2: ПРОБА (кандидат-параметр moment=${CANDIDATE_MOMENT})" "&moment=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "${CANDIDATE_MOMENT}")" "step1_probe_body.json" "step1_probe_meta.txt"
do_call "3: ПОВТОР КОНТРОЛЯ (без временного параметра)" "" "step1_control2_body.json" "step1_control2_meta.txt"

date -u

echo
echo "=== Шаг 1d: сравнение тел ответов ==="
echo "-- control1 vs control2 (ожидание: идентичны или почти идентичны, малый естественный оборот) --"
if diff -q step1_control1_body.json step1_control2_body.json > /dev/null; then
  echo "IDENTICAL"
else
  echo "DIFFERENT (см. step1_control_diff.txt)"
  diff step1_control1_body.json step1_control2_body.json > step1_control_diff.txt || true
fi

echo "-- probe vs control1 --"
if diff -q step1_probe_body.json step1_control1_body.json > /dev/null; then
  echo "IDENTICAL (параметр, вероятно, проигнорирован — ТРАКТОВКА, не факт «не менялось»)"
else
  echo "DIFFERENT"
fi

echo
echo "=== Проверка утечки токена (токен + grep ОДНОЙ командой, ADR-077 §6/§5.3) ==="
grep -rF -- "${MSKLAD_TOKEN}" "${SCRATCH_DIR}" > step1_token_leak_check.log 2>&1 || true
echo "rc=$? (ожидание: 0 совпадений, файл ниже пуст при отсутствии утечки)"
wc -l step1_token_leak_check.log
unset MSKLAD_TOKEN

echo
echo "=== UTC-якорь КОНЕЦ ==="
date -u
echo "=== Личность КОНЕЦ ==="
gcloud auth list

echo
echo "Артефакты в: ${SCRATCH_DIR}"
