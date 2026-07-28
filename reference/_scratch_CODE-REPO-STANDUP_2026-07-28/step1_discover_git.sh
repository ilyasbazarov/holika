#!/usr/bin/env bash
set -euo pipefail

date -u
gcloud auth list 2>&1

TARGET="/home/ilyasbazarov4/cf-finance"

echo "=== существование каталога ==="
ls -la "$TARGET" 2>&1 || echo "КАТАЛОГ НЕ НАЙДЕН"

echo "=== существование .git ==="
if [ -d "$TARGET/.git" ]; then
  echo ".git ЕСТЬ"
  cd "$TARGET"

  echo "--- git status ---"
  git status 2>&1 || echo "git status УПАЛ"

  echo "--- git log (полная история, по одной строке на коммит) ---"
  git log --oneline --all 2>&1 || echo "git log ПУСТ ИЛИ УПАЛ"

  echo "--- git log -1 (последний коммит целиком) ---"
  git log -1 2>&1 || echo "git log -1 ПУСТ ИЛИ УПАЛ"

  echo "--- git rev-list --count --all (число коммитов) ---"
  git rev-list --count --all 2>&1 || echo "git rev-list ПУСТ ИЛИ УПАЛ"

  echo "--- git remote -v ---"
  git remote -v 2>&1 || echo "REMOTE НЕ ЗАДАН"

  echo "--- git branch -a ---"
  git branch -a 2>&1 || echo "git branch УПАЛ"

  echo "--- diff .git-состояния HEAD против прод-снапшота main.py (если файл там есть) ---"
  if [ -f "$TARGET/main.py" ]; then
    sha256sum "$TARGET/main.py" 2>&1
  else
    echo "main.py НЕ НАЙДЕН НА ВЕРХНЕМ УРОВНЕ КАТАЛОГА"
  fi
else
  echo ".git ОТСУТСТВУЕТ"
fi

echo "=== содержимое каталога верхнего уровня (на случай нестандартной структуры) ==="
find "$TARGET" -maxdepth 2 2>&1 || true

gcloud auth list 2>&1
date -u
