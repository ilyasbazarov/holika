#!/usr/bin/env bash
# Замер каденции мартов + расписаний двух transferConfig. ТОЛЬКО ЧТЕНИЕ.
# Запуск:  bash sq_cadence_measure.sh > run.log 2>&1; cat run.log
set -uo pipefail

PROJ="msklad-bi-prod"
LOC="asia-east1"
CFG_EXP="6a22a243-0000-20fd-a458-883d24f4cad4"       # sq_marts_expenses
CFG_AR="6a23f3ea-0000-2952-853d-582429be7ecc"        # sq_marts_customer_invoices_ar
OUT="$HOME/holika_cadence_$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"

echo "########## 1. ЯКОРЬ (начало) ##########"
echo "-- date -u:"        ; date -u
echo "-- активный аккаунт:"; gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "-- проект:"          ; gcloud config get-value project

echo
echo "########## 2. ЗАДАНИЯ BIGQUERY ЗА СУТКИ, ВСЕ ПОЛЬЗОВАТЕЛИ ##########"
MIN_MS=$(( ( $(date -u +%s) - 86400 ) * 1000 ))
echo "-- окно с (epoch ms): $MIN_MS"
bq --project_id="$PROJ" ls -j --all_users --min_creation_time="$MIN_MS" -n 1000 \
   --format=prettyjson > "$OUT/jobs.json"
echo "-- размер выдачи: $(wc -c < "$OUT/jobs.json") байт"

python3 - "$OUT/jobs.json" <<'PY'
import json, sys, datetime
p = sys.argv[1]
try:
    data = json.load(open(p, encoding='utf-8'))
except Exception as e:
    print("!! ПАРСИНГ НЕ УДАЛСЯ:", e, "-- это гэп наблюдения, не 'заданий нет'")
    sys.exit(0)
if not isinstance(data, list):
    print("!! ОЖИДАЛСЯ СПИСОК, ПРИШЛО:", type(data).__name__, "-- гэп наблюдения")
    sys.exit(0)
print(f"-- всего заданий в выдаче: {len(data)}")
rows = []
for j in data:
    cfg  = (j.get('configuration') or {}).get('query') or {}
    dest = cfg.get('destinationTable') or {}
    tbl  = f"{dest.get('datasetId','')}.{dest.get('tableId','')}".strip('.')
    ct   = ((j.get('statistics') or {}).get('creationTime'))
    try:
        ts = datetime.datetime.fromtimestamp(int(ct)/1000, datetime.timezone.utc)\
                     .strftime('%Y-%m-%dT%H:%M:%SZ')
    except Exception:
        ts = f"?({ct})"
    rows.append((ts, tbl,
                 j.get('user_email', '?'),
                 (j.get('status') or {}).get('state', '?'),
                 cfg.get('writeDisposition', ''),
                 (j.get('jobReference') or {}).get('jobId', '?')))
rows.sort()
print("\n-- ВСЕ задания с целевой таблицей в marts.* :")
n = 0
for ts, tbl, who, st, wd, jid in rows:
    if tbl.startswith('marts.'):
        n += 1
        print(f"   {ts}  {tbl:34s}  {st:10s} {wd:14s} {who}  {jid}")
if n == 0:
    print("   (ни одного задания с целью в marts.* — если выдача выше непуста, это факт;")
    print("    если выдача пуста или не распарсилась — это гэп наблюдения)")
print("\n-- ВСЕ задания вообще (для контроля полноты выдачи):")
for ts, tbl, who, st, wd, jid in rows:
    print(f"   {ts}  {tbl or '(без цели)':34s}  {st:10s} {who}")
PY

echo
echo "########## 3. РАСПИСАНИЯ ДВУХ TRANSFERCONFIG ##########"
bq ls --transfer_config --transfer_location="$LOC" --format=prettyjson > "$OUT/tc_list.json"
echo "-- размер листинга конфигураций: $(wc -c < "$OUT/tc_list.json") байт"

python3 - "$OUT/tc_list.json" "$CFG_EXP" "$CFG_AR" <<'PY'
import json, sys
p, want = sys.argv[1], sys.argv[2:]
try:
    data = json.load(open(p, encoding='utf-8'))
except Exception as e:
    print("!! ПАРСИНГ НЕ УДАЛСЯ:", e, "-- гэп наблюдения"); sys.exit(0)
print(f"-- конфигураций в листинге: {len(data)}")
found = {}
for c in data:
    name = c.get('name', '')
    for w in want:
        if name.endswith(w):
            found[w] = name
for w in want:
    print(f"   {w} -> {found.get(w, 'НЕ НАЙДЕН В ЛИСТИНГЕ (гэп: проверить location)')}" )
open('/tmp/holika_tc_names.txt', 'w').write('\n'.join(found.get(w, '') for w in want))
PY

i=0
while IFS= read -r NAME; do
  i=$((i+1))
  if [ -z "$NAME" ]; then
    echo "-- конфигурация #$i: полное имя не получено, bq show пропущен (гэп наблюдения)"
    continue
  fi
  echo
  echo "-- bq show --transfer_config #$i : $NAME"
  bq show --format=prettyjson --transfer_config "$NAME" > "$OUT/tc_$i.json"
  python3 - "$OUT/tc_$i.json" <<'PY'
import json, sys
try:
    c = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as e:
    print("   !! ПАРСИНГ НЕ УДАЛСЯ:", e, "-- гэп наблюдения"); sys.exit(0)
for k in ('displayName','schedule','scheduleOptions','nextRunTime','state','disabled',
          'destinationDatasetId','dataSourceId','updateTime','userId'):
    if k in c:
        v = c[k]
        if k == 'schedule' and v == '':
            v = "(поле присутствует и ПУСТО)"
        print(f"   {k}: {v}")
    else:
        print(f"   {k}: (поля в выдаче нет)")
PY
done < /tmp/holika_tc_names.txt

echo
echo "########## 4. ЯКОРЬ (конец) ##########"
echo "-- date -u:"        ; date -u
echo "-- активный аккаунт:"; gcloud auth list --filter=status:ACTIVE --format='value(account)'

echo
echo "########## КОМАНД ЗАПИСИ В СКРИПТЕ НЕТ: только ls / show / select-free чтение ##########"
echo "СЫРЫЕ ВЫГРУЗКИ ЛЕЖАТ ЗДЕСЬ: $OUT"
