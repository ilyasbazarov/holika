#!/usr/bin/env bash
# SALES-REFRESH-WINDOW-VERIFY-ADJ шаг 4 — состояние код-репо и условия ADR-040. READ-ONLY.
set -u
echo "=== UTC начало ==="; date -u
cd /Users/ilyasbazarov/Desktop/msklad_project/holika
R=reference/_scratch_SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY_2026-08-07/step3_work/repo

echo; echo "=== 1. Состав каталога cf-facts в клоне код-репо (что реально уедет в архив) ==="
ls -1a "$R/cf-facts/" 2>/dev/null

echo; echo "=== 2. .gcloudignore код-репо — содержимое (ADR-040: условие деплоя) ==="
cat -n "$R/cf-facts/.gcloudignore" 2>/dev/null || echo "НЕ НАЙДЕН"

echo; echo "=== 3. Провенанс-архив прошлого деплоя holika-prod — какие ветки в нём ==="
A=/Users/ilyasbazarov/Desktop/msklad_project/holika_provenance_archive/SALES-REFRESH-WINDOW-DEPLOY_2026-08-11_holika-prod
git -C "$A" branch -a 2>/dev/null | head -20
echo "--- последние коммиты ---"
git -C "$A" log --oneline -6 --all 2>/dev/null | head -12
echo "--- состав cf-facts в архиве код-репо ---"
ls -1a "$A/cf-facts/" 2>/dev/null | head -20

echo; echo "=== 4. Есть ли в архиве код-репо .gcloudignore и что в нём ==="
cat -n "$A/cf-facts/.gcloudignore" 2>/dev/null || echo "в архиве не найден"

echo; echo "=== 5. Живая ревизия по записи деплой-сессии (какая обслуживает СЕЙЧАС) ==="
grep -nE "cf-facts-000(11|12)|100 ?%|трафик" reference/sales_refresh_window_deploy_2026-08-11.md | head -12

echo; echo "=== 6. Снимок-откат: существует ли запись о нём и его дата ==="
grep -rn "fact_sales_profit_snap_20260811" reference/*.md 07_STATE.md | head -5

echo; echo "=== UTC конец ==="; date -u
