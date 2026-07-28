#!/usr/bin/env bash
# Замер каденции мартов + расписаний двух transferConfig, ВЕРСИЯ 2. ТОЛЬКО ЧТЕНИЕ.
# Исправлено против v1: (1) флаг листинга заданий подбирается по факту, а не наугад;
#                       (2) вторая конфигурация больше не теряется циклом.
# Запуск:  bash sq_cadence_measure_v2.sh > run2.log 2>&1; cat run2.log
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
echo "-- версия bq:"       ; bq version

echo
echo "########## 2. ЗАДАНИЯ BIGQUERY ЗА СУТКИ, ВСЕ ПОЛЬЗОВАТЕЛИ ##########"
MIN_MS=$(( ( $(date -u +%s) - 86400 ) * 1000 ))
echo "-- окно с (epoch ms): $MIN_MS"
echo "-- какие флаги 'все пользователи' знает эта установка bq:"
bq help ls 2>&1 | grep -iE 'all_jobs|all_users' || echo "   (в help такого флага не нашлось)"

JOBS_OK=0
for FLAG in "--all_jobs" "-a" "--all_users"; do
  echo "-- пробую: bq ls -j $FLAG"
  if bq --project_id="$PROJ" ls -j "$FLAG" --min_creation_time="$MIN_MS" -n 1000 \
        --format=prettyjson > "$OUT/jobs.json" 2> "$OUT/jobs.err"; then
    if [ -s "$OUT/jobs.json" ]; then
      echo "   OK, флаг сработал: $FLAG ; байт выдачи: $(wc -c < "$OUT/jobs.json")"
      echo "$FLAG" > "$OUT/jobs_flag.txt"
      JOBS_OK=1
      break
    else
      echo "   команда прошла, но выдача ПУСТА — это гэп наблюдения, пробую следующий флаг"
    fi
  else
    echo "   не принят, stderr:"; sed 's/^/     /' "$OUT/jobs.err"
  fi
done
if [ "$JOBS_OK" -eq 0 ]; then
  echo "!! НИ ОДИН ФЛАГ НЕ ДАЛ ВЫДАЧУ. Это гэп наблюдения, а НЕ 'заданий не было'."
fi

if [ "$JOBS_OK" -eq 1 ]; then
python3 - "$OUT/jobs.json" <<'PY'
import json, sys, datetime
try:
    data = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as e:
    print("!! ПАРСИНГ НЕ УДАЛСЯ:", e, "-- гэп наблюдения, не 'заданий нет'"); sys.exit(0)
if not isinstance(data, list):
    print("!! ОЖИДАЛСЯ СПИСОК, ПРИШЛО:", type(data).__name__, "-- гэп наблюдения"); sys.exit(0)
print(f"-- всего заданий в выдаче: {len(data)}")
rows = []
for j in data:
    cfg  = (j.get('configuration') or {}).get('query') or {}
    dest = cfg.get('destinationTable') or {}
    tbl  = f"{dest.get('datasetId','')}.{dest.get('tableId','')}".strip('.')
    ct   = (j.get('statistics') or {}).get('creationTime')
    try:
        ts = datetime.datetime.fromtimestamp(int(ct)/1000, datetime.timezone.utc)\
                     .strftime('%Y-%m-%dT%H:%M:%SZ')
    except Exception:
        ts = f"?({ct})"
    rows.append((ts, tbl, j.get('user_email','?'),
                 (j.get('status') or {}).get('state','?'),
                 cfg.get('writeDisposition',''),
                 (j.get('jobReference') or {}).get('jobId','?')))
rows.sort()
print("\n-- задания с целью в marts.* (это и есть фактическая каденция):")
n=0
for ts,tbl,who,st,wd,jid in rows:
    if tbl.startswith('marts.'):
        n+=1; print(f"   {ts}  {tbl:34s} {st:10s} {wd:14s} {who}  {jid}")
if n==0:
    print("   ни одного — при непустой выдаче это факт, при пустой это гэп")
print("\n-- все задания (контроль полноты выдачи):")
for ts,tbl,who,st,wd,jid in rows:
    print(f"   {ts}  {tbl or '(без цели)':34s} {st:10s} {who}")
PY
fi

echo
echo "########## 3. РАСПИСАНИЯ TRANSFERCONFIG ##########"
bq ls --transfer_config --transfer_location="$LOC" --format=prettyjson > "$OUT/tc_list.json"
echo "-- байт листинга: $(wc -c < "$OUT/tc_list.json")"

echo
echo "-- ПОБОЧНЫЕ ФАКТЫ: все конфигурации флота из уже полученного листинга (новых вызовов нет)"
python3 - "$OUT/tc_list.json" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as e:
    print("   !! ПАРСИНГ НЕ УДАЛСЯ:", e); sys.exit(0)
print(f"   конфигураций: {len(data)}")
for c in sorted(data, key=lambda x: x.get('displayName','')):
    print(f"   {c.get('displayName','?'):42s} id={c.get('name','?').split('/')[-1]}")
    print(f"      schedule={c.get('schedule','(поля нет)')!r} "
          f"nextRunTime={c.get('nextRunTime','(поля нет)')} "
          f"state={c.get('state','(поля нет)')} "
          f"dataset={c.get('destinationDatasetId','?')}")
PY

# полные resource-name двух целевых конфигураций; печать построчно, цикл больше не теряет последнюю
NAMES=$(python3 - "$OUT/tc_list.json" "$CFG_EXP" "$CFG_AR" <<'PY'
import json, sys
p, want = sys.argv[1], sys.argv[2:]
try:
    data = json.load(open(p, encoding='utf-8'))
except Exception:
    for w in want: print("NOTFOUND:"+w)
    sys.exit(0)
idx = {c.get('name','').split('/')[-1]: c.get('name','') for c in data}
for w in want:
    print(idx.get(w) or ("NOTFOUND:"+w))
PY
)

i=0
for NAME in $NAMES; do
  i=$((i+1))
  case "$NAME" in
    NOTFOUND:*) echo; echo "-- конфигурация #$i (${NAME#NOTFOUND:}) в листинге НЕ найдена — гэп, проверить location"; continue ;;
  esac
  echo
  echo "-- bq show --transfer_config #$i : $NAME"
  bq show --format=prettyjson --transfer_config "$NAME" > "$OUT/tc_$i.json" 2> "$OUT/tc_$i.err" \
    || { echo "   ОШИБКА, stderr:"; sed 's/^/     /' "$OUT/tc_$i.err"; continue; }
  python3 - "$OUT/tc_$i.json" <<'PY'
import json, sys
try:
    c = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as e:
    print("   !! ПАРСИНГ НЕ УДАЛСЯ:", e, "-- гэп наблюдения"); sys.exit(0)
for k in ('displayName','schedule','scheduleOptions','nextRunTime','state','disabled',
          'destinationDatasetId','dataSourceId','updateTime','userId','emailPreferences',
          'ownerInfo','notificationPubsubTopic'):
    if k in c:
        v = c[k]
        if k=='schedule' and v=='': v = "(поле ПРИСУТСТВУЕТ и пусто)"
        print(f"   {k}: {v}")
    else:
        print(f"   {k}: (поля в выдаче НЕТ — это не то же, что пустое)")
print("\n   -- полный набор ключей выдачи (для протокола):")
print("   " + ", ".join(sorted(c.keys())))
PY
done

echo
echo "########## 4. ЯКОРЬ (конец) ##########"
echo "-- date -u:"        ; date -u
echo "-- активный аккаунт:"; gcloud auth list --filter=status:ACTIVE --format='value(account)'

echo
echo "########## КОМАНД ЗАПИСИ НЕТ: только ls / show / help / version ##########"
echo "СЫРЫЕ ВЫГРУЗКИ: $OUT"
