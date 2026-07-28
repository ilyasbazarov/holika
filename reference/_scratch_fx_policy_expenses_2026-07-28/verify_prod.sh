#!/usr/bin/env bash
# ШАГ 5 брифа: приёмка ПОСЛЕ пересборки прода. ТОЛЬКО ЧТЕНИЕ.
# Запуск:  bash verify_prod.sh > run8.log 2>&1; cat run8.log
set -uo pipefail
PROJ="msklad-bi-prod"
CFG="projects/420804682491/locations/asia-east1/transferConfigs/6a22a243-0000-20fd-a458-883d24f4cad4"
Q() { bq --project_id="$PROJ" query --nouse_legacy_sql --format=pretty --max_rows=200 "$1"; }

echo "########## ЯКОРЬ (начало) ##########"
date -u; gcloud auth list --filter=status:ACTIVE --format='value(account)'

echo
echo "########## 1. СОСТОЯНИЕ ПОСЛЕДНИХ ПРОГОНОВ КОНФИГУРАЦИИ ##########"
bq --project_id="$PROJ" ls --transfer_run --run_attempt=LATEST -n 5 --format=prettyjson "$CFG" \
   > /tmp/holika_runs.json 2>/tmp/holika_runs.err || { echo "!! не удалось:"; sed 's/^/   /' /tmp/holika_runs.err; }
python3 - /tmp/holika_runs.json <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as e:
    print("   !! парсинг не удался:", e, "-- гэп наблюдения"); sys.exit(0)
for r in d:
    print(f"   runTime={r.get('runTime')}  state={r.get('state')}  "
          f"endTime={r.get('endTime')}  error={(r.get('errorStatus') or {}).get('message')}")
PY

echo
echo "########## 2. КОГДА ПРОД-ВИТРИНА ОБНОВЛЯЛАСЬ ПОСЛЕДНИЙ РАЗ ##########"
Q "SELECT COUNT(*) AS strok, COUNT(DISTINCT year_month) AS mesyatsev,
          COUNT(DISTINCT payment_type) AS tipov,
          STRING_AGG(DISTINCT payment_type ORDER BY payment_type) AS spisok_tipov
   FROM \`$PROJ.marts.expenses\`"
echo "   ОЖИДАНИЕ: в списке типов должны появиться loss и commission."

echo
echo "########## 3. ЭТАЛОН: МАЙ-2026 НА ПРОДЕ = 10 232 903,20 ##########"
Q "SELECT ROUND(SUM(total_sum_kgs),2) AS may_2026_itogo,
          ROUND(SUM(total_sum_kgs) - 10232903.20, 2) AS razryv_s_etalonom
   FROM \`$PROJ.marts.expenses\` WHERE year_month = '2026-05'"

echo
echo "########## 4. МАЙ-2026 ПОСТАТЕЙНО НА ПРОДЕ ##########"
Q "SELECT expense_item_name, ROUND(SUM(total_sum_kgs),2) AS sum_kgs, SUM(payment_count) AS cnt
   FROM \`$PROJ.marts.expenses\` WHERE year_month = '2026-05'
   GROUP BY 1 ORDER BY sum_kgs DESC"

echo
echo "########## 5. ПРОД МИНУС STAGING ПО МЕСЯЦАМ ##########"
echo "   ОЖИДАНИЕ: ноль по всем месяцам до 2026-06 включительно."
echo "   По 2026-07 допустима разница — staging заморожен на 2026-07-26T19:39Z,"
echo "   а прод только что пересобран на свежих данных. Любая другая разница = дефект."
Q "WITH p AS (SELECT year_month, SUM(total_sum_kgs) v, SUM(payment_count) c FROM \`$PROJ.marts.expenses\`         GROUP BY 1),
        s AS (SELECT year_month, SUM(total_sum_kgs) v, SUM(payment_count) c FROM \`$PROJ.marts.expenses_staging\` GROUP BY 1)
   SELECT COALESCE(p.year_month, s.year_month) AS ym,
          ROUND(p.v,2) AS prod, ROUND(s.v,2) AS staging,
          ROUND(COALESCE(p.v,0) - COALESCE(s.v,0),2) AS delta,
          COALESCE(p.c,0) - COALESCE(s.c,0) AS delta_dokumentov
   FROM p FULL OUTER JOIN s ON p.year_month = s.year_month
   ORDER BY ym"

echo
echo "########## 6. СХЕМА ПРОДА ПОСЛЕ ПЕРЕСБОРКИ ##########"
bq --project_id="$PROJ" show --schema --format=prettyjson "$PROJ:marts.expenses" > /tmp/holika_schema_after.json 2>/dev/null
python3 - /tmp/holika_schema_after.json <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding='utf-8'))
f = s if isinstance(s, list) else s.get('fields', [])
print(f"   колонок: {len(f)} (ожидалось 17)")
print("   " + ", ".join(x.get('name') for x in f))
PY

echo
echo "########## ЯКОРЬ (конец) ##########"
date -u; gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "########## КОМАНД ЗАПИСИ НЕТ ##########"
