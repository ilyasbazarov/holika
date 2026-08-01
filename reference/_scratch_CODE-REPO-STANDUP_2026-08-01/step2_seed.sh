#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list 2>&1

NEWREPO="$HOME/cf-finance-coderepo"     # поменять здесь, если выбрано другое имя
OLDDIR="$HOME/cf-finance"               # заготовка — НЕ трогать
PROJECT="msklad-bi-prod"
GEN="1784560843778541"
SRC="gs://gcf-v2-sources-420804682491-asia-east1/cf-finance/function-source.zip#${GEN}"
EXPECT_ZIP_SHA="04c337f4c31cfa3bb63a7c6ffc913f9f52ef387d4001d89ee2ff494fa2d0b202"
EXPECT_MAINPY_SHA="0cb4f6698a61cee96c90f9a14973ada38f5123418b54ff901f24ea2026ddab59"

echo "=== существующая заготовка (только чтение, не трогаем) ==="
ls -la "$OLDDIR/.git" 2>&1 || echo "(не найдено или недоступно)"

echo "=== новый каталог ==="
mkdir -p "$NEWREPO/archive"
cd "$NEWREPO"

echo "=== скачать архив по generation ==="
gcloud storage cp "$SRC" "$NEWREPO/function-source.zip" --project="$PROJECT" 2>&1
ACTUAL_ZIP_SHA=$(sha256sum "$NEWREPO/function-source.zip" | awk '{print $1}')
echo "sha256 архива: $ACTUAL_ZIP_SHA (ожидалось $EXPECT_ZIP_SHA)"
if [ "$ACTUAL_ZIP_SHA" != "$EXPECT_ZIP_SHA" ]; then
  echo "СТОП: sha256 архива не совпал с зафиксированным в reference/deploy_revision_probe_2026-08-01.md — это CONTEXT GAP, не продолжать молча"
  exit 1
fi

echo "=== распаковать во временный каталог, проверить main.py ==="
unzip -o -q "$NEWREPO/function-source.zip" -d "$NEWREPO/archive"
find "$NEWREPO/archive" -maxdepth 2
ACTUAL_MAINPY_SHA=$(sha256sum "$NEWREPO/archive/main.py" | awk '{print $1}')
echo "sha256 main.py: $ACTUAL_MAINPY_SHA (ожидалось $EXPECT_MAINPY_SHA)"
if [ "$ACTUAL_MAINPY_SHA" != "$EXPECT_MAINPY_SHA" ]; then
  echo "СТОП: sha256 main.py не совпал — CONTEXT GAP"
  exit 1
fi

echo "=== .gitignore (ADR-094 §4 / ADR-040: *.bak, __pycache__/, разовые patch-скрипты) ==="
cat > "$NEWREPO/.gitignore" <<'EOF'
*.bak
__pycache__/
patch_main_finance.py
function-source.zip
archive/
EOF
cat "$NEWREPO/.gitignore"

echo "=== копируем только легитимное содержимое в корень репо ==="
cp "$NEWREPO/archive/main.py" "$NEWREPO/main.py"
cp "$NEWREPO/archive/requirements.txt" "$NEWREPO/requirements.txt"

echo "=== git init + первый коммит (byte-for-byte архив минус игнор) ==="
git init 2>&1
git add .gitignore main.py requirements.txt
git status 2>&1
git commit -m "Seed from deployed revision cf-finance-00012-cik (generation ${GEN})" 2>&1
git log --oneline --all 2>&1
git show --stat HEAD 2>&1

echo "=== ПЕРВЫЙ КОММИТ: сверка sha256 закоммиченных файлов против архива ==="
sha256sum "$NEWREPO/main.py" "$NEWREPO/requirements.txt" 2>&1

echo "=== расхождение рабочей копии disk vs архив (ADR-094 §4) ==="
if [ -f "$OLDDIR/main.py" ]; then
  DISK_SHA=$(sha256sum "$OLDDIR/main.py" | awk '{print $1}')
  echo "sha256 $OLDDIR/main.py = $DISK_SHA"
  if [ "$DISK_SHA" = "$ACTUAL_MAINPY_SHA" ]; then
    echo "СОВПАДАЕТ с архивом — расхождений в main.py нет, второй коммит по main.py не нужен"
  else
    echo "РАСХОДИТСЯ с архивом — diff ниже, второй коммит потребуется"
    diff -u "$NEWREPO/archive/main.py" "$OLDDIR/main.py" 2>&1 || true
  fi
else
  echo "$OLDDIR/main.py недоступен для сравнения — гэп наблюдения, не факт «совпадает»"
fi
if [ -f "$OLDDIR/requirements.txt" ]; then
  DISK_REQ_SHA=$(sha256sum "$OLDDIR/requirements.txt" | awk '{print $1}')
  ARCH_REQ_SHA=$(sha256sum "$NEWREPO/archive/requirements.txt" | awk '{print $1}')
  echo "sha256 $OLDDIR/requirements.txt = $DISK_REQ_SHA (архив: $ARCH_REQ_SHA)"
fi

echo "=== заготовка $OLDDIR/.git — подтверждение, что не тронута ==="
ls -la "$OLDDIR/.git" 2>&1 || echo "(недоступно повторно)"

date -u
gcloud auth list 2>&1
