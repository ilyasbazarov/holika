#!/usr/bin/env bash
# Шаг 1 брифа E1-T1-MECH-CUTOVER: проверки ПЕРЕД подменой. ТОЛЬКО ЧТЕНИЕ, прод не касается.
# Запуск:  bash step1_verify.sh > run4.log 2>&1; cat run4.log
set -uo pipefail

PROJ="msklad-bi-prod"
LOC="asia-east1"
CFG="projects/420804682491/locations/asia-east1/transferConfigs/6a22a243-0000-20fd-a458-883d24f4cad4"
OUT="$HOME/holika_step1_$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"
Q() { bq --project_id="$PROJ" query --nouse_legacy_sql --format=pretty --max_rows=200 "$1"; }

echo "########## ЯКОРЬ (начало) ##########"
date -u; gcloud auth list --filter=status:ACTIVE --format='value(account)'; gcloud config get-value project

echo
echo "########## 1. ОТКАТНЫЙ ТЕКСТ: снимаем ДЕЙСТВУЮЩИЙ запрос из живой конфигурации ##########"
bq --project_id="$PROJ" show --format=prettyjson --transfer_config "$CFG" \
   > "$OUT/live_config_before.json" 2> "$OUT/cfg.err" \
  || { echo "!! не удалось:"; sed 's/^/   /' "$OUT/cfg.err"; }
python3 - "$OUT/live_config_before.json" "$OUT/rollback_query.sql" <<'PY'
import json, sys
try:
    c = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as e:
    print("   !! парсинг не удался:", e, "-- гэп наблюдения"); sys.exit(0)
q = (c.get('params') or {}).get('query')
if not q:
    print("   !! params.query в выдаче НЕТ. Ключи params:", sorted((c.get('params') or {}).keys()))
    sys.exit(0)
open(sys.argv[2],'w',encoding='utf-8').write(q)
print(f"   откатный текст сохранён: {sys.argv[2]} ({len(q.encode('utf-8'))} байт)")
print(f"   nextRunTime ДО правки: {c.get('nextRunTime')}")
print(f"   scheduleOptionsV2 ДО правки: {c.get('scheduleOptionsV2')}")
print("\n   ----- ДЕЙСТВУЮЩИЙ ЗАПРОС (начало) -----")
print(q)
print("   ----- ДЕЙСТВУЮЩИЙ ЗАПРОС (конец) -----")
PY

echo
echo "########## 2. ТИПЫ КОЛОНКИ moment В ТРЁХ ИСТОЧНИКАХ ##########"
echo "   (в проверяемом тексте у loss и commission стоит CAST(... AS DATE), у payments — нет;"
echo "    надо увидеть, что там за типы на самом деле)"
for T in core.fact_payments core.fact_loss core.fact_commissionreportin; do
  bq --project_id="$PROJ" show --schema --format=prettyjson "$PROJ:$T" > "$OUT/schema_${T#core.}.json" 2>/dev/null
  python3 - "$OUT/schema_${T#core.}.json" "$T" <<'PY'
import json, sys
try:
    s = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as e:
    print(f"   {sys.argv[2]}: схема не прочитана ({e}) -- гэп наблюдения"); sys.exit(0)
fields = s if isinstance(s, list) else s.get('fields', [])
hit = [f for f in fields if f.get('name') == 'moment']
if hit:
    print(f"   {sys.argv[2]:38s} moment: {hit[0].get('type')}  mode={hit[0].get('mode')}")
else:
    print(f"   {sys.argv[2]:38s} колонки moment НЕТ; есть: {[f.get('name') for f in fields][:12]}")
PY
done

echo
echo "########## 3. СХЕМЫ marts.expenses И marts.expenses_staging — ПОКОЛОНОЧНО ##########"
bq --project_id="$PROJ" show --schema --format=prettyjson "$PROJ:marts.expenses"         > "$OUT/schema_prod.json"    2>/dev/null
bq --project_id="$PROJ" show --schema --format=prettyjson "$PROJ:marts.expenses_staging" > "$OUT/schema_staging.json" 2>/dev/null
python3 - "$OUT/schema_prod.json" "$OUT/schema_staging.json" <<'PY'
import json, sys
def load(p):
    s = json.load(open(p, encoding='utf-8'))
    f = s if isinstance(s, list) else s.get('fields', [])
    return [(x.get('name'), x.get('type')) for x in f]
try:
    a, b = load(sys.argv[1]), load(sys.argv[2])
except Exception as e:
    print("   !! схемы не прочитаны:", e, "-- гэп наблюдения"); sys.exit(0)
print(f"   колонок: прод={len(a)} staging={len(b)}")
print(f"   {'#':>2}  {'ПРОД':32s} {'STAGING':32s} совпадение")
for i in range(max(len(a), len(b))):
    x = a[i] if i < len(a) else ('—','—')
    y = b[i] if i < len(b) else ('—','—')
    print(f"   {i+1:>2}  {x[0]+' '+x[1]:32s} {y[0]+' '+y[1]:32s} {'OK' if x==y else '<<< РАСХОЖДЕНИЕ'}")
print("   ИТОГ: " + ("схемы идентичны по составу, порядку и типам" if a==b else "СХЕМЫ РАСХОДЯТСЯ — см. строки выше"))
PY

echo
echo "########## 4. МАЙ-2026 НА STAGING: ПОСТАТЕЙНО ##########"
Q "SELECT expense_item_name, ROUND(SUM(total_sum_kgs),2) AS sum_kgs, SUM(payment_count) AS cnt
   FROM \`$PROJ.marts.expenses_staging\` WHERE year_month = '2026-05'
   GROUP BY expense_item_name ORDER BY sum_kgs DESC"

echo
echo "########## 5. МАЙ-2026 НА STAGING: АГРЕГАТЫ ДЛЯ СВЕРКИ С ЭТАЛОНОМ 10 232 903,20 ##########"
Q "SELECT
     ROUND(SUM(total_sum_kgs),2) AS vsego_vse_stati,
     ROUND(SUM(IF(expense_item_name <> 'Перемещение исходящий', total_sum_kgs, 0)),2) AS bez_peremescheniya,
     ROUND(SUM(IF(expense_item_name  = 'Перемещение исходящий', total_sum_kgs, 0)),2) AS peremeschenie,
     ROUND(SUM(IF(expense_item_name  = 'Налоги и сборы',        total_sum_kgs, 0)),2) AS nalogi,
     ROUND(SUM(IF(expense_item_name  = 'Списания',              total_sum_kgs, 0)),2) AS spisaniya,
     ROUND(SUM(IF(expense_item_name  = 'Маркетинг и реклама',   total_sum_kgs, 0)),2) AS marketing,
     ROUND(SUM(IF(expense_item_name  = 'Прочие расходы',        total_sum_kgs, 0)),2) AS prochie,
     ROUND(SUM(IF(expense_item_name IN ('Расходы маркетплейсов','Комиссия'), total_sum_kgs, 0)),2) AS mp_plus_komissiya
   FROM \`$PROJ.marts.expenses_staging\` WHERE year_month = '2026-05'"

echo
echo "########## 6. STAGING МИНУС ПРОД ПО МЕСЯЦАМ ##########"
echo "   ВАЖНО: staging собран 2026-07-26T19:39Z, прод пересобран 2026-07-27T11:10Z."
echo "   Расхождение по свежим месяцам (июль) ожидаемо и означает разницу в дате сборки, а не дефект."
Q "WITH s AS (SELECT year_month, SUM(total_sum_kgs) v FROM \`$PROJ.marts.expenses_staging\` GROUP BY 1),
        p AS (SELECT year_month, SUM(total_sum_kgs) v FROM \`$PROJ.marts.expenses\`         GROUP BY 1)
   SELECT COALESCE(s.year_month, p.year_month) AS ym,
          ROUND(s.v,2) AS staging, ROUND(p.v,2) AS prod,
          ROUND(COALESCE(s.v,0) - COALESCE(p.v,0),2) AS delta
   FROM s FULL OUTER JOIN p ON s.year_month = p.year_month
   ORDER BY ym"

echo
echo "########## 7. ЧТО ДАЛА ДЕЛЬТА: ТОЛЬКО НОВЫЕ ВЕТКИ, ПО МЕСЯЦАМ ##########"
Q "SELECT year_month, payment_type, ROUND(SUM(total_sum_kgs),2) AS sum_kgs
   FROM \`$PROJ.marts.expenses_staging\`
   WHERE payment_type IN ('loss','commission')
   GROUP BY 1,2 ORDER BY 1,2"

echo
echo "########## ЯКОРЬ (конец) ##########"
date -u; gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo
echo "########## КОМАНД ЗАПИСИ НЕТ: только show / query на чтение ##########"
echo "ФАЙЛЫ (включая откатный текст): $OUT"
