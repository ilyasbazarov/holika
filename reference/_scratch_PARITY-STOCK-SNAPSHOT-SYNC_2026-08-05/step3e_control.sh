#!/usr/bin/env bash
# PARITY-STOCK-SNAPSHOT-SYNC · ШАГ 3e — КОНТРОЛЬ к находке шага 3b.
# Находка: все семь сирот несут updated = 2026-08-03 15:15:17.683 (совпадение до миллисекунды).
# Без контроля это НЕ факт о сиротах: та же отметка могла стоять у всех товаров подряд
# (05_CONVENTIONS Часть I ★ «Успех инструмента ≠ факт»). Контроль — три товара из
# СОВПАВШЕГО множества (diffs, ключ найден с обеих сторон), те же read-only GET.
set -uo pipefail

SCRATCH="reference/_scratch_PARITY-STOCK-SNAPSHOT-SYNC_2026-08-05"
SRC_JSON="reference/_scratch_PARITY-STOCK-ROWWISE_2026-08-04/step6_join_result.json"
BASE="https://api.moysklad.ru/api/remap/1.2/entity/product"

echo "=== UTC-якорь НАЧАЛО ==="; date -u
echo "=== Личность НАЧАЛО ==="; gcloud auth list

echo
echo "=== Шаг 3e-1: три контрольных UUID из совпавшего множества (не сироты) ==="
python3 - "$SRC_JSON" "$SCRATCH/step3e_control_uuids.txt" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
diffs = d.get("diffs", [])
print("  элементов в diffs (совпавший ключ, разный stock):", len(diffs))
if diffs:
    print("  форма элемента:", json.dumps(diffs[0], ensure_ascii=False)[:300])
ids = []
for it in diffs:
    if isinstance(it, str):
        ids.append(it)
    elif isinstance(it, dict):
        for k in ("product_id", "uuid", "id", "key"):
            if k in it:
                ids.append(it[k]); break
    elif isinstance(it, (list, tuple)) and it:
        # фактическая форма замера: [uuid, name, stock_src, stock_our, delta]
        ids.append(it[0])
ids = ids[:3]
if not ids:
    print("  ГЭП НАБЛЮДЕНИЯ: идентификаторы не извлечены, форма элемента не распознана")
with open(sys.argv[2], "w") as f:
    for u in ids:
        f.write(u + "\n")
print("  взято контрольных:", len(ids))
PYEOF

TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)
if [ -z "${TOKEN}" ]; then echo "CONTEXT GAP: токен пуст"; exit 1; fi

echo
echo "=== Шаг 3e-2: GET по контрольным товарам ==="
printf "%-38s %-6s %s\n" "UUID" "HTTP" "updated / archived"
while read -r uuid; do
  [ -z "$uuid" ] && continue
  body="${SCRATCH}/step3e_control_${uuid}.json"
  code=$(curl -sS --compressed -o "${body}" -w "%{http_code}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept-Encoding: gzip" \
    "${BASE}/${uuid}")
  python3 - "${body}" "${uuid}" "${code}" <<'PYEOF'
import json, sys
path, uuid, code = sys.argv[1:4]
try:
    d = json.load(open(path))
except Exception as e:
    print(f"{uuid:<38} {code:<6} НЕПАРСИМО: {e}"); sys.exit(0)
if code != "200":
    print(f"{uuid:<38} {code:<6} errors={json.dumps(d.get('errors'), ensure_ascii=False)[:200]}"); sys.exit(0)
print(f"{uuid:<38} {code:<6} updated={d.get('updated')} archived={d.get('archived')}")
print(f"       name={d.get('name')!r}")
PYEOF
  sleep 0.25
done < "${SCRATCH}/step3e_control_uuids.txt"

echo
echo "=== Шаг 3e-3: вердикт различителя ==="
echo "Если контрольные несут ТУ ЖЕ отметку 2026-08-03 15:15:17.683 — совпадение у сирот"
echo "фактом о сиротах НЕ является (массовая правка всего справочника)."
echo "Если контрольные несут ДРУГИЕ отметки — совпадение у семи есть находка."

echo
echo "=== Шаг 3e-4: проверка утечки токена (токен и grep ОДНОЙ командой) ==="
grep -rF -- "${TOKEN}" "${SCRATCH}" > "${SCRATCH}/step3e_token_leak.log" 2>&1
echo "grep rc=$? (1 = утечки нет), строк: $(wc -l < "${SCRATCH}/step3e_token_leak.log" | tr -d ' ')"

echo
echo "=== Личность КОНЕЦ ==="; gcloud auth list
echo "=== UTC-якорь КОНЕЦ ==="; date -u
echo "SCRATCH_PATH=${SCRATCH}"
