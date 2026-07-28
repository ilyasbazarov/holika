#!/usr/bin/env bash
# ШАГ 3 брифа: read-back ДО любого прогона. ТОЛЬКО ЧТЕНИЕ.
# Запуск:  bash readback.sh > run7.log 2>&1; cat run7.log
set -uo pipefail
PROJ="msklad-bi-prod"
CFG="projects/420804682491/locations/asia-east1/transferConfigs/6a22a243-0000-20fd-a458-883d24f4cad4"
NEWSQL_DIR="$HOME/holika_newsql_20260727T153004Z"
STEP1_DIR="$HOME/holika_step1_20260727T153556Z"

echo "########## ЯКОРЬ (начало) ##########"
date -u; gcloud auth list --filter=status:ACTIVE --format='value(account)'

bq --project_id="$PROJ" show --format=prettyjson --transfer_config "$CFG" \
   > "$STEP1_DIR/live_config_after.json" 2> "$STEP1_DIR/after.err" \
  || { echo "!! не удалось прочитать конфигурацию:"; sed 's/^/   /' "$STEP1_DIR/after.err"; exit 1; }

python3 - "$STEP1_DIR/live_config_before.json" "$STEP1_DIR/live_config_after.json" "$NEWSQL_DIR/install_query.sql" <<'PY'
import json, sys
before = json.load(open(sys.argv[1], encoding='utf-8'))
after  = json.load(open(sys.argv[2], encoding='utf-8'))
want   = open(sys.argv[3], encoding='utf-8').read()

pb, pa = before.get('params') or {}, after.get('params') or {}
ok = {}

got = pa.get('query', '')
ok["текст запроса совпадает с установочным байт в байт"] = (got == want)
print(f"-- байт в конфигурации: {len(got.encode('utf-8'))}, ожидалось: {len(want.encode('utf-8'))}")
if got != want:
    gl, wl = got.split('\n'), want.split('\n')
    print(f"   строк: в конфигурации {len(gl)}, ожидалось {len(wl)}")
    for i in range(max(len(gl), len(wl))):
        a = gl[i] if i < len(gl) else '<нет строки>'
        b = wl[i] if i < len(wl) else '<нет строки>'
        if a != b:
            print(f"   первая расходящаяся строка {i+1}:")
            print(f"     в конфигурации: {a!r}")
            print(f"     ожидалось:      {b!r}")
            break

for k in ('destination_table_name_template', 'write_disposition', 'partitioning_field'):
    ok[f"параметр {k} не изменился"] = (pb.get(k) == pa.get(k))
    print(f"-- {k}: было {pb.get(k)!r} -> стало {pa.get(k)!r}")

for k in ('nextRunTime', 'scheduleOptionsV2', 'scheduleOptions', 'state',
          'destinationDatasetId', 'dataSourceId', 'ownerInfo'):
    same = before.get(k) == after.get(k)
    ok[f"{k} не изменился"] = same
    print(f"-- {k}: было {before.get(k)!r} -> стало {after.get(k)!r}")

lost = set(pb) - set(pa)
ok["ни один параметр не пропал"] = not lost
if lost:
    print(f"!! ПОТЕРЯНЫ ПАРАМЕТРЫ: {lost}")

print("\n-- итог:")
for k, v in ok.items():
    print(f"   {'OK ' if v else 'НЕТ'}  {k}")
print("\n" + ("ГОТОВО — можно запускать пересборку." if all(ok.values())
              else "СТОП — откатывать. Текст отката: " + sys.argv[1].rsplit('/',1)[0] + "/rollback_query.sql"))
sys.exit(0 if all(ok.values()) else 1)
PY

echo
echo "########## ЯКОРЬ (конец) ##########"
date -u; gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "########## КОМАНД ЗАПИСИ НЕТ ##########"
