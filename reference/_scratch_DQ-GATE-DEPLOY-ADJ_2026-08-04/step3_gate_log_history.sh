#!/bin/bash
# DQ-GATE-DEPLOY-ADJ · шаг 3 (класс A, read-only)
# Реконструкция шага 2 предсказывает 7 провалов drift_check за 2026-06-18…08-01, тогда как репо
# (`07_STATE.md:41`) знает ОДИН блок (07-25→07-26). Два предсказания (07-05, 07-06) попадают в
# окно retention Cloud Logging, четыре июньских — нет. Шаг различает «реконструкция
# переоценивает» и «прежний скан логов был ограничен окном retention».
# Пустая выдача фактом «провалов не было» НЕ является (05 Часть I, ★ Успех инструмента ≠ факт):
# при исчерпанном retention это гэп наблюдения. Печатаются совпавшие строки, не метка.
set -uo pipefail
SCRATCH="reference/_scratch_DQ-GATE-DEPLOY-ADJ_2026-08-04"
PROJ="msklad-bi-prod"

echo "=== date -u (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list

echo
echo "=== 1. Все записи drift_check от cf-dq за максимально доступное окно ==="
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="cf-dq" AND textPayload:"drift_check"' \
  --project=$PROJ --freshness=90d --limit=500 --order=asc \
  --format="value(timestamp,textPayload)" \
  > "$SCRATCH/step3_drift_entries.txt" 2>"$SCRATCH/step3_q1.err"
echo "строк получено: $(wc -l < "$SCRATCH/step3_drift_entries.txt")"
echo "--- первые 5 / последние 5 ---"
head -5 "$SCRATCH/step3_drift_entries.txt"; echo "  …"; tail -5 "$SCRATCH/step3_drift_entries.txt"

echo
echo "=== 2. Только ПРОВАЛЫ (❌) — совпавшие строки целиком ==="
grep -n "❌" "$SCRATCH/step3_drift_entries.txt" | tee "$SCRATCH/step3_drift_fails.txt" || echo "(нет совпадений — см. предупреждение о retention выше)"

echo
echo "=== 3. Границы фактически доступного окна логов (самая ранняя запись cf-dq любого рода) ==="
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="cf-dq"' \
  --project=$PROJ --freshness=90d --limit=1 --order=asc \
  --format="value(timestamp)" 2>"$SCRATCH/step3_q3.err" | tee "$SCRATCH/step3_earliest.txt"

echo
echo "=== stderr (непустой = смотреть) ==="
for f in "$SCRATCH"/step3_q*.err; do echo "--- $f"; cat "$f"; done

echo
echo "=== gcloud auth list (end) ==="; gcloud auth list
echo "=== date -u (end) ==="; date -u
echo "=== SCRATCH: $SCRATCH ==="
