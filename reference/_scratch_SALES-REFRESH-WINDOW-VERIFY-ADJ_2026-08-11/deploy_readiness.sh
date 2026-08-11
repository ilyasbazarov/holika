#!/usr/bin/env bash
# SALES-REFRESH-WINDOW-VERIFY-ADJ шаг 2 — проверка готовности к деплою, READ-ONLY по репо.
# Диагностика, действий нет (ADR-055 §2). Облачных вызовов нет.
set -u
echo "=== UTC начало ==="; date -u
cd /Users/ilyasbazarov/Desktop/msklad_project/holika

echo; echo "=== 1. Что и когда менялось в снапшоте cf-facts (последние 12 коммитов) ==="
git log --oneline -12 -- reference/code/cf-facts/

echo; echo "=== 2. Состав патча варианта 1 (коммит a336700) ==="
git show --stat --oneline a336700 -- reference/code/cf-facts/ | head -20

echo; echo "=== 3. Живой архив после деплоя 2026-08-09 (INGEST-MOMENT-ZONE-FIX) — есть ли ==="
ls -1 reference/_scratch_INGEST-MOMENT-ZONE-FIX-DEPLOY_2026-08-09/live_archive_post/ 2>/dev/null || echo "нет каталога"

echo; echo "=== 4. ДИФФ: снапшот main (bd8c733) против живого архива 2026-08-09 ==="
for f in main.py bq_ops.py config.py fetch_perimeter.py; do
  L="reference/_scratch_INGEST-MOMENT-ZONE-FIX-DEPLOY_2026-08-09/live_archive_post/$f"
  S="reference/code/cf-facts/$f"
  if [ -f "$L" ] && [ -f "$S" ]; then
    n=$(diff -u "$L" "$S" | grep -c '^[+-][^+-]' || true)
    echo "--- $f: различающихся строк $n ---"
    diff -u "$L" "$S" | grep '^@@' | head -20
  else
    echo "--- $f: нет одной из сторон (живой:$( [ -f "$L" ] && echo да || echo нет ) снапшот:$( [ -f "$S" ] && echo да || echo нет )) ---"
  fi
done

echo; echo "=== 5. Полный список файлов живого архива против снапшота ==="
echo "живой архив:"; ls -1 reference/_scratch_INGEST-MOMENT-ZONE-FIX-DEPLOY_2026-08-09/live_archive_post/ 2>/dev/null
echo "снапшот:";     ls -1 reference/code/cf-facts/

echo; echo "=== 6. .gcloudignore снапшота (ADR-040 — условие деплоя) ==="
if [ -f reference/code/cf-facts/.gcloudignore ]; then cat -n reference/code/cf-facts/.gcloudignore; else echo "ФАЙЛА НЕТ в снапшоте"; fi

echo; echo "=== 7. Секреты в патче — сплошной поиск с печатью строк (ADR-044) ==="
grep -rnE "AIza|-----BEGIN|api[_-]?key *=|token *= *[\"'][A-Za-z0-9_-]{16,}|secret *= *[\"']" reference/code/cf-facts/ || echo "0 совпадений (пустая выдача фактом не является — проверен и состав файлов выше)"

echo; echo "=== 8. MANIFEST снапшота — какая ревизия числится ==="
sed -n '1,40p' reference/code/cf-facts/MANIFEST.md 2>/dev/null || echo "MANIFEST.md нет"

echo; echo "=== UTC конец ==="; date -u
