#!/usr/bin/env bash
# DEPLOY-REVISION-PROBE, второй заход. Только чтение локальных файлов, полученных первым заходом.
# Причина второго захода: греп первого захода напечатал «совпадений нет» при фактическом наличии
# умножения на курс — шаблон `rate\.value` не покрывает форму `(row.get("rate") or {}).get("value")`.
# Это ровно класс ADR-021 §2 / ADR-044: вердикт грепа без напечатанных строк недостоверен.
set -u

S="$(cd "$(dirname "$0")" && pwd)"
REPO="/Users/ilyasbazarov/Desktop/msklad_project/holika"
DEP="$S/src/main.py"
BAK="$S/src/main.py.pre-e1t3-mech-fx.bak"
OLDBAK="$S/src/main.py.bak"
SNAP="$REPO/reference/code/cf-finance/main.py"

echo "=== ЯКОРЬ НАЧАЛА ==="
date -u
gcloud auth list 2>&1

echo
echo "=== A. sha256 всех четырёх версий файла ==="
for f in "$DEP" "$BAK" "$OLDBAK" "$SNAP"; do
  printf '%-58s ' "$(basename "$(dirname "$f")")/$(basename "$f")"
  shasum -a 256 "$f" 2>&1 | awk '{print $1}'
done

echo
echo "=== B. Умножение на курс — ПЕЧАТАЕМ СТРОКИ, не метку (ADR-044) ==="
for f in "$DEP" "$BAK" "$OLDBAK" "$SNAP"; do
  echo "--- $f ---"
  grep -n 'get("rate")\|get(.rate.)\|rate.*value\|"value"' "$f" 2>&1 || echo "  (нет ни одного совпадения)"
done

echo
echo "=== C. Все места вычисления sum_kgs в задеплоенном файле ==="
grep -n 'sum_kgs' "$DEP" 2>&1 || echo "  (нет совпадений)"
echo "--- каждое место с контекстом 6 строк ---"
grep -n -A6 '"sum_kgs"' "$DEP" 2>&1 || echo "  (нет совпадений)"

echo
echo "=== D. Чем задеплоенный main.py отличается от .pre-e1t3-mech-fx.bak ==="
if diff -u "$BAK" "$DEP" > "$S/diff_bak_vs_deployed.txt" 2>&1; then
  echo "РАЗЛИЧИЙ НЕТ — файлы идентичны"
else
  echo "различия есть, полный текст в diff_bak_vs_deployed.txt:"
  cat "$S/diff_bak_vs_deployed.txt"
fi

echo
echo "=== E. Чем задеплоенный main.py отличается от снимка-провенанса в репо ==="
if diff -u "$SNAP" "$DEP" > "$S/diff_snapshot_vs_deployed.txt" 2>&1; then
  echo "РАЗЛИЧИЙ НЕТ — файлы идентичны"
else
  echo "различий строк: $(grep -c '^[+-]' "$S/diff_snapshot_vs_deployed.txt")"
  echo "--- первые 60 строк diff ---"
  head -60 "$S/diff_snapshot_vs_deployed.txt"
fi

echo
echo "=== F. Расхождение метаданных: ревизия от 07-20, updateTime функции 07-30 ==="
echo "--- сборки Cloud Build за период (кто и когда собирал) ---"
gcloud builds list --project=msklad-bi-prod --region=asia-east1 --limit=10 \
  --format="table(id, createTime, status, source.storageSource.generation)" 2>&1 \
  || echo "  (список сборок недоступен — не факт, а гэп наблюдения)"

echo
echo "=== ЯКОРЬ КОНЦА ==="
date -u
gcloud auth list 2>&1
