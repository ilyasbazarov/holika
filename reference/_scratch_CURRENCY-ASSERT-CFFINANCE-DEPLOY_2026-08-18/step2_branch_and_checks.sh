#!/usr/bin/env bash
set -uo pipefail
echo "=== UTC anchor (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list
SCRATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$SCRATCH/holika-prod"
PROD_COMMIT=e6b9627
BRANCH=deploy/cf-finance-2026-08-18-currency-assert
SNAP="$(cd "$SCRATCH/../.." && pwd)/reference/code/cf-finance/main.py"

cd "$REPO"
echo; echo "=== База: сверяю cf-finance в голове master с архивом прода ==="
MASTER=$(git rev-parse master)
ok=1
for f in main.py invoices.py requirements.txt; do
  a=$(shasum -a 256 "$SCRATCH/serving_archive/$f" | cut -d' ' -f1)
  b=$(git show "master:cf-finance/$f" | shasum -a 256 | cut -d' ' -f1)
  if [ "$a" = "$b" ]; then echo "  master:cf-finance/$f == архив прода"; else echo "  РАСХОЖДЕНИЕ $f — СТОП"; ok=0; fi
done
[ $ok -eq 1 ] || { echo "СТОП: дрейф между master и продом"; exit 1; }
echo "  ⇒ база ветки = master $MASTER (содержимое cf-finance равно проду)"

echo; echo "=== Ветка деплоя от master ==="
git checkout -q -b "$BRANCH" master && echo "  создана $BRANCH, HEAD $(git rev-parse HEAD)"

echo; echo "=== Перенос патча: ОДИН файл из снапшота репо ==="
cp "$SNAP" cf-finance/main.py
git add cf-finance/main.py
git -c user.name=ilyasbazarov -c user.email=ilyasbazarov4@gmail.com \
    commit -q -m "cf-finance: INGEST-CURRENCY-ASSERT currency detection (task CURRENCY-ASSERT-CFFINANCE-DEPLOY)" \
  && echo "  коммит $(git rev-parse --short HEAD)"

echo; echo "=== П4. Счёт файлов ПРОТИВ БАЗЫ ВЕТКИ (ожидание: ровно 1) ==="
git diff --stat "$MASTER" HEAD | cat
N=$(git diff --name-only "$MASTER" HEAD | wc -l | tr -d ' ')
echo "  файлов в диффе: $N"
[ "$N" = "1" ] || { echo "СТОП: ожидался ровно 1 файл"; exit 1; }
git diff --name-only "$MASTER" HEAD | sed 's/^/    /'

echo; echo "=== П10. Прод-коммит обязан быть ПРЕДКОМ головы ветки ==="
if git merge-base --is-ancestor "$PROD_COMMIT" HEAD; then echo "  OK: $PROD_COMMIT предок HEAD"; else echo "  СТОП: не предок"; exit 1; fi

echo; echo "=== П7. Секреты в патче — сплошной поиск с печатью совпавших строк ==="
git diff "$MASTER" HEAD | grep -nEi 'token *= *["'"'"']|secret|password|api[_-]?key|BEGIN [A-Z ]*PRIVATE KEY|Bearer [A-Za-z0-9._-]{20,}' \
  && { echo "  СТОП: совпадения выше"; exit 1; } || echo "  совпадений 0 (при непустом диффе $(git diff "$MASTER" HEAD | wc -l | tr -d ' ') строк — ADR-044)"

echo; echo "=== П4-гигиена. .gcloudignore и мусор в каталоге функции ==="
[ -f .gcloudignore ] && { echo "  .gcloudignore есть:"; sed 's/^/    /' .gcloudignore; } || echo "  .gcloudignore в корне репо отсутствует"
echo "  состав cf-finance/ (то, что уедет через --source):"; ls -a cf-finance/ | sed 's/^/    /'
find cf-finance -name '*.bak' -o -name '__pycache__' -o -name '*.pyc' | sed 's/^/    МУСОР: /'

echo; echo "=== П5. Факт-проверка ИСПОЛНЕНИЕМ по содержимому ВЕТКИ (не снапшота) ==="
python3 --version
python3 "$(cd "$SCRATCH/../.." && pwd)/reference/_scratch_CURRENCY-ASSERT-CFFINANCE-REVIEW_2026-08-18/import_check.py" "$REPO/cf-finance/main.py"
echo "  rc_import=$?"

echo; echo "=== Контроль: sha256 файла ветки против снапшота репо ==="
shasum -a 256 cf-finance/main.py "$SNAP"

echo "=== UTC anchor (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
