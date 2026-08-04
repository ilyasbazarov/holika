#!/bin/bash
# DQ-GATE-DEPLOY-ADJ · шаг 3b (класс A, read-only) — ПЕРЕЗАПУСК шага 3 с исправленным фильтром.
# Шаг 3 дал 0 строк при `rc=0`, но соседний запрос показал живые записи `cf-dq` с 2026-05-07,
# то есть retention не исчерпан и ноль есть гэп наблюдения (`05` Часть I, ★ Успех инструмента ≠ факт),
# а не факт «провалов не было». Вероятная причина — тело записи лежит в `jsonPayload`, а не в
# `textPayload`, и подстрочный оператор по `textPayload` не совпадает ни с чем.
# Порядок: СНАЧАЛА посмотреть на форму одной записи, ПОТОМ фильтровать по ней.
set -uo pipefail
SCRATCH="reference/_scratch_DQ-GATE-DEPLOY-ADJ_2026-08-04"
PROJ="msklad-bi-prod"
FILT_BASE='resource.type="cloud_run_revision" AND resource.labels.service_name="cf-dq"'

echo "=== date -u (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list

echo
echo "=== 1. Форма записи: три сырых entry за узкое окно вокруг известного провала 2026-08-01 ==="
gcloud logging read \
  "$FILT_BASE AND timestamp>=\"2026-08-01T18:00:00Z\" AND timestamp<=\"2026-08-01T18:10:00Z\"" \
  --project=$PROJ --limit=3 --order=asc --format=json \
  > "$SCRATCH/step3b_shape.json" 2>"$SCRATCH/step3b_q1.err"
python3 - <<'PY'
import json
d = json.load(open('reference/_scratch_DQ-GATE-DEPLOY-ADJ_2026-08-04/step3b_shape.json'))
print('записей:', len(d))
for e in d[:3]:
    print('  ключи:', sorted(k for k in e if k in ('textPayload','jsonPayload','protoPayload')))
    print('  textPayload:', repr(e.get('textPayload'))[:200])
    print('  jsonPayload:', repr(e.get('jsonPayload'))[:200])
PY

echo
echo "=== 2. Все провалы DQ Gate по маркеру ❌ за доступное окно (оба payload-поля) ==="
gcloud logging read \
  "$FILT_BASE AND (textPayload:\"❌\" OR jsonPayload.message:\"❌\")" \
  --project=$PROJ --freshness=90d --limit=1000 --order=asc \
  --format="value(timestamp,textPayload,jsonPayload.message)" \
  > "$SCRATCH/step3b_fails.txt" 2>"$SCRATCH/step3b_q2.err"
echo "строк получено: $(wc -l < "$SCRATCH/step3b_fails.txt")"
echo "--- совпавшие строки, только drift_check, по одной на дату target_date ---"
grep "drift_check" "$SCRATCH/step3b_fails.txt" | sed 's/.*target_date=//' | sort | uniq -c || echo "(нет drift_check среди провалов)"
echo "--- первые 15 совпавших строк целиком ---"
grep -n "drift_check" "$SCRATCH/step3b_fails.txt" | head -15 || true

echo
echo "=== 3. Суточная сводка ВСЕХ провалов по имени чека ==="
grep -o "❌ [a-z_]*" "$SCRATCH/step3b_fails.txt" | sort | uniq -c || echo "(нет совпадений)"

echo
echo "=== stderr (непустой = смотреть) ==="
for f in "$SCRATCH"/step3b_q*.err; do echo "--- $f"; cat "$f"; done

echo
echo "=== gcloud auth list (end) ==="; gcloud auth list
echo "=== date -u (end) ==="; date -u
echo "=== SCRATCH: $SCRATCH ==="
