#!/usr/bin/env bash
# SALES-REFRESH-WINDOW-VERIFY-ADJ шаг 3 — атрибуция ПОЛЕЗНОЙ НАГРУЗКИ деплоя.
# Вопрос: равен ли дифф «живое → снапшот» РОВНО известным коммитам этой задачи,
# или в него затесалось что-то чужое (ADR-145 §1 — разделение по хункам).
# READ-ONLY, облачных вызовов нет.
set -u
echo "=== UTC начало ==="; date -u
cd /Users/ilyasbazarov/Desktop/msklad_project/holika
LIVE=reference/_scratch_INGEST-MOMENT-ZONE-FIX-DEPLOY_2026-08-09/live_archive_post
BASE=5738a4c   # коммит, зафиксировавший деплой ревизии cf-facts-00011-mab (живая сейчас)

echo; echo "=== 1. РЕШАЮЩЕЕ: равен ли живой архив снапшоту НА коммите деплоя $BASE ==="
echo "(если да — всё, что после, и есть ровно полезная нагрузка; чужого в ней нет по построению)"
TMP=$(mktemp -d); echo "temp: $TMP"
for f in main.py bq_ops.py config.py fetch_perimeter.py fetch_byvariant.py fetch_demands.py fetch_purchases.py fetch_returns.py helpers.py requirements.txt deploy_and_workflow.sh; do
  git show "$BASE:reference/code/cf-facts/$f" > "$TMP/$f" 2>/dev/null || { echo "  $f: НЕТ в снапшоте на $BASE"; continue; }
  if diff -q "$LIVE/$f" "$TMP/$f" >/dev/null 2>&1; then
    echo "  $f: ИДЕНТИЧНЫ"
  else
    echo "  $f: РАЗЛИЧАЮТСЯ  ← требует объяснения"
    diff -u "$LIVE/$f" "$TMP/$f" | head -30
  fi
done

echo; echo "=== 2. Полезная нагрузка = коммиты снапшота ПОСЛЕ $BASE ==="
git log --oneline "$BASE"..HEAD -- reference/code/cf-facts/
echo "--- плюс не слитая ветка адъюдикации ---"
git log --oneline main..s/SALES-REFRESH-WINDOW-VERIFY-ADJ -- reference/code/cf-facts/

echo; echo "=== 3. Файлы, затронутые полезной нагрузкой (все коммиты после $BASE) ==="
git diff --stat "$BASE"..HEAD -- reference/code/cf-facts/
echo "--- с учётом ветки адъюдикации ---"
git diff --stat "$BASE"..s/SALES-REFRESH-WINDOW-VERIFY-ADJ -- reference/code/cf-facts/

echo; echo "=== 4. Есть ли среди коммитов после $BASE ЧУЖИЕ задачи (не SALES-REFRESH-WINDOW) ==="
git log --format='%h %s' "$BASE"..s/SALES-REFRESH-WINDOW-VERIFY-ADJ -- reference/code/cf-facts/ \
  | grep -viE 'SALES-REFRESH-WINDOW' && echo "^^^ ЧУЖИЕ КОММИТЫ ЕСТЬ" || echo "чужих коммитов нет — все относятся к SALES-REFRESH-WINDOW"

echo; echo "=== 5. Локальный клон код-репо holika-prod — есть ли на машине ==="
ls -d ~/Desktop/msklad_project/*/ 2>/dev/null
find ~/Desktop/msklad_project -maxdepth 3 -name ".git" -type d 2>/dev/null | head

echo; echo "=== 6. .gcloudignore: есть ли где-либо в репо (ADR-040 — условие деплоя) ==="
find . -name ".gcloudignore" -not -path "./.git/*" 2>/dev/null | head || echo "не найден"

echo; echo "=== 7. Не-кодовые файлы в каталоге снапшота (поедут в архив, если не исключены) ==="
ls -1 reference/code/cf-facts/ | grep -vE '\.py$|requirements.txt'

rm -rf "$TMP"
echo; echo "=== UTC конец ==="; date -u
