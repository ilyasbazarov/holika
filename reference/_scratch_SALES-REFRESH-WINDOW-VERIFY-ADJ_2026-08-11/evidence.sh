#!/usr/bin/env bash
# SALES-REFRESH-WINDOW-VERIFY-ADJ — сбор доказательств адъюдикации (класс A, read-only по репо).
# ADR-055 §3/§4: UTC-якорь первой и последней командой. Облачных вызовов нет,
# поэтому подтверждение личности вызывающего (gcloud auth list) неприменимо — весь
# замер идёт по локальному клону.
set -u
echo "=== UTC начало ==="; date -u
cd "$(dirname "$0")/../.."

echo; echo "=== A. Ложное утверждение — где оно живёт (ADR-044: печатаем строки с номерами) ==="
grep -rn "workflow_weekly.yaml:70" --include="*.py" --include="*.md" . | grep -v "_scratch_SALES-REFRESH-WINDOW-VERIFY-ADJ"

echo; echo "=== B. Что на самом деле лежит в workflow_weekly.yaml:63-71 (шаг step_facts) ==="
sed -n '61,72p' reference/code/cf-facts/workflow_weekly.yaml | cat -n | awk '{printf "%d:%s\n", $1+60, substr($0, index($0,$2))}'

echo; echo "=== C. Все mode/window_days обоих конвейеров ==="
for f in reference/code/cf-facts/workflow_hourly.yaml reference/code/cf-facts/workflow_weekly.yaml; do
  echo "--- $f ---"; grep -n 'mode:\|window_days' "$f"
done

echo; echo "=== D. Разбор window_days в main.py (парсинг, лог, раздача по режимам) ==="
grep -n 'window_days = int(body.get\|log.info("CF-Facts start\|result = _run' reference/code/cf-facts/main.py

echo; echo "=== E. Сигнатуры режимов: кто принимает window_days, кто нет ==="
grep -n '^def _run_' reference/code/cf-facts/main.py

echo; echo "=== F. Предохранитель: объявление и все места вызова ==="
grep -n '_assert_staging_covers_merge_window' reference/code/cf-facts/bq_ops.py
grep -n '^GUARD_TOLERANCE_DAYS\|^WEEKLY_WINDOW_DAYS\|^HOURLY_WINDOW_DAYS\|^PERIMETER_WINDOW_DAYS' reference/code/cf-facts/config.py

echo; echo "=== G. Ветки удаления MERGE — обе ли под предохранителем ==="
grep -n 'THEN DELETE\|def promote_to_core\|def promote_perimeter_to_core' reference/code/cf-facts/bq_ops.py

echo; echo "=== UTC конец ==="; date -u
