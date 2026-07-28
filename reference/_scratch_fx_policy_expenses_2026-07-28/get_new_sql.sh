#!/usr/bin/env bash
# Достать ТОЧНЫЙ текст нового SQL из задания BigQuery, которое собрало marts.expenses_staging.
# Источник — сам BigQuery, а не чья-то память. ТОЛЬКО ЧТЕНИЕ.
# Запуск:  bash get_new_sql.sh > run3.log 2>&1; cat run3.log
set -uo pipefail

PROJ="msklad-bi-prod"
LOC="asia-east1"
JOB="bqjob_r4a62e606d0d607b2_0000019f9ff0aa48_1"   # 2026-07-26T19:39:37Z -> marts.expenses_staging
OUT="$HOME/holika_newsql_$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"

echo "########## ЯКОРЬ (начало) ##########"
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
gcloud config get-value project

echo
echo "########## 1. ВСЕ ЗАДАНИЯ, ПИСАВШИЕ В marts.expenses_staging (за доступное окно) ##########"
MIN_MS=$(( ( $(date -u +%s) - 259200 ) * 1000 ))   # трое суток
bq --project_id="$PROJ" ls -j --all_jobs --min_creation_time="$MIN_MS" -n 2000 \
   --format=prettyjson > "$OUT/jobs3d.json" 2> "$OUT/jobs3d.err" \
  || { echo "!! листинг не удался:"; sed 's/^/   /' "$OUT/jobs3d.err"; }

python3 - "$OUT/jobs3d.json" <<'PY'
import json, sys, datetime
try:
    data = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as e:
    print("   !! парсинг не удался:", e, "-- гэп наблюдения"); sys.exit(0)
hits = []
for j in data:
    q = (j.get('configuration') or {}).get('query') or {}
    d = q.get('destinationTable') or {}
    if d.get('tableId','').startswith('expenses'):
        ct = (j.get('statistics') or {}).get('creationTime')
        try:
            ts = datetime.datetime.fromtimestamp(int(ct)/1000, datetime.timezone.utc)\
                         .strftime('%Y-%m-%dT%H:%M:%SZ')
        except Exception:
            ts = f"?({ct})"
        hits.append((ts, f"{d.get('datasetId')}.{d.get('tableId')}",
                     (j.get('jobReference') or {}).get('jobId','?'),
                     j.get('user_email','?')))
for h in sorted(hits):
    print("   " + "  ".join(h))
if not hits:
    print("   ничего не найдено — при непустом листинге это факт, при пустом гэп наблюдения")
PY

echo
echo "########## 2. ТЕКСТ ЗАПРОСА ИЗ ЗАДАНИЯ $JOB ##########"
bq --project_id="$PROJ" --location="$LOC" show --format=prettyjson -j "$JOB" \
   > "$OUT/job_staging.json" 2> "$OUT/job_staging.err" \
  || { echo "!! show -j не удался:"; sed 's/^/   /' "$OUT/job_staging.err"; }

python3 - "$OUT/job_staging.json" "$OUT/new_query_from_job.sql" <<'PY'
import json, sys
try:
    j = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as e:
    print("   !! парсинг не удался:", e, "-- гэп наблюдения"); sys.exit(0)
q = ((j.get('configuration') or {}).get('query') or {})
sql = q.get('query')
if not sql:
    print("   !! поля configuration.query.query в выдаче НЕТ — гэп наблюдения, не 'запроса не было'")
    print("   ключи configuration:", sorted((j.get('configuration') or {}).keys()))
    sys.exit(0)
open(sys.argv[2], 'w', encoding='utf-8').write(sql)
d = q.get('destinationTable') or {}
print(f"   цель записи: {d.get('datasetId')}.{d.get('tableId')}")
print(f"   writeDisposition: {q.get('writeDisposition')}")
print(f"   состояние: {(j.get('status') or {}).get('state')}  ошибка: {(j.get('status') or {}).get('errorResult')}")
print(f"   байт текста запроса: {len(sql.encode('utf-8'))}")
print(f"   сохранён в: {sys.argv[2]}")
print("\n----- НАЧАЛО ТЕКСТА ЗАПРОСА -----")
print(sql)
print("----- КОНЕЦ ТЕКСТА ЗАПРОСА -----")
PY

echo
echo "########## ЯКОРЬ (конец) ##########"
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "ФАЙЛЫ: $OUT"
