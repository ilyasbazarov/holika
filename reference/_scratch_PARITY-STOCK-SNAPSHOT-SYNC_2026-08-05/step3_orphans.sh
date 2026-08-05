#!/usr/bin/env bash
# PARITY-STOCK-SNAPSHOT-SYNC · ШАГ 3 — природа семи строк-сирот (бриф §Шаг 3).
# Класс B, мандат ADR-123 §8 (владелец, чат 2026-08-04). ТОЛЬКО ЧТЕНИЕ:
# семь GET entity/product/<uuid>. Записи нет нигде, откат не требуется.
# Шаг от окна 21:00Z НЕ зависит — исполняется в любой час (бриф, развилка после шага 1).
set -uo pipefail

SCRATCH="reference/_scratch_PARITY-STOCK-SNAPSHOT-SYNC_2026-08-05"
SRC_JSON="reference/_scratch_PARITY-STOCK-ROWWISE_2026-08-04/step6_join_result.json"
BASE="https://api.moysklad.ru/api/remap/1.2/entity/product"
RPS_SLEEP=0.25   # MSKLAD_RPS=4, форма cf-inventory/helpers.py

echo "=== UTC-якорь НАЧАЛО ==="; date -u
echo "=== Личность НАЧАЛО ==="; gcloud auth list

echo
echo "=== Шаг 3a: извлечение семи UUID программно из сохранённого результата замера ==="
echo "Источник: ${SRC_JSON} (переписывание глазами запрещено брифом)"
python3 - "$SRC_JSON" "$SCRATCH/step3_uuids.txt" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
src = d.get("orphans_src", [])
our = d.get("orphans_our", [])
print(f"  orphans_src (есть у источника, нет у нас): {len(src)}")
print(f"  orphans_our (есть у нас, нет у источника): {len(our)}")
with open(sys.argv[2], "w") as f:
    for u in src:
        f.write(f"src\t{u}\n")
    for u in our:
        f.write(f"our\t{u}\n")
print(f"  всего к опросу: {len(src)+len(our)}")
PYEOF

TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)
if [ -z "${TOKEN}" ]; then echo "CONTEXT GAP: токен пуст, замер не выполняется"; exit 1; fi

echo
echo "=== Шаг 3b: семь GET entity/product/<uuid> (read-only) ==="
printf "%-6s %-38s %-6s %s\n" "СТОР" "UUID" "HTTP" "ПОЛЯ"
while IFS=$'\t' read -r side uuid; do
  body="${SCRATCH}/step3_product_${uuid}.json"
  code=$(curl -sS --compressed -o "${body}" -w "%{http_code}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept-Encoding: gzip" \
    "${BASE}/${uuid}")
  python3 - "${body}" "${side}" "${uuid}" "${code}" <<'PYEOF'
import json, sys
path, side, uuid, code = sys.argv[1:5]
try:
    d = json.load(open(path))
except Exception as e:
    print(f"{side:<6} {uuid:<38} {code:<6} НЕПАРСИМО: {e}")
    sys.exit(0)
if code != "200":
    errs = d.get("errors")
    print(f"{side:<6} {uuid:<38} {code:<6} errors={json.dumps(errs, ensure_ascii=False)[:200]}")
    sys.exit(0)
# ADR-079 §6: в лог идут ИМЕНА полей плюс явно выбранные значения, не сырое тело
sel = {k: d.get(k) for k in ("name", "archived", "updated", "pathName", "code")}
print(f"{side:<6} {uuid:<38} {code:<6} archived={sel['archived']} updated={sel['updated']}")
print(f"       name={sel['name']!r} folder={sel['pathName']!r} code={sel['code']!r}")
PYEOF
  sleep "${RPS_SLEEP}"
done < "${SCRATCH}/step3_uuids.txt"

echo
echo "=== Шаг 3c: ключи ответа (форма логирования ADR-079 §6, по первому файлу) ==="
python3 - "${SCRATCH}" <<'PYEOF'
import json, glob, sys, os
files = sorted(glob.glob(os.path.join(sys.argv[1], "step3_product_*.json")))
if files:
    d = json.load(open(files[0]))
    print(" ", os.path.basename(files[0]))
    print("  ключи:", ", ".join(sorted(d.keys())))
else:
    print("  ГЭП НАБЛЮДЕНИЯ: ни одного файла ответа не создано")
PYEOF

echo
echo "=== Шаг 3d: проверка утечки токена в файлы сессии (токен и grep ОДНОЙ командой) ==="
echo "Ловушка PARITY-STOCK-ROWWISE: переменная окружения не переживает переход между"
echo "отдельными вызовами инструмента, поэтому проверка обязана идти внутри этого же процесса."
grep -rF -- "${TOKEN}" "${SCRATCH}" > "${SCRATCH}/step3_token_leak.log" 2>&1
rc=$?
echo "grep rc=${rc} (1 = совпадений нет, то есть утечки нет), строк в логе: $(wc -l < "${SCRATCH}/step3_token_leak.log" | tr -d ' ')"

echo
echo "=== Личность КОНЕЦ ==="; gcloud auth list
echo "=== UTC-якорь КОНЕЦ ==="; date -u
echo "SCRATCH_PATH=${SCRATCH}"
