#!/usr/bin/env bash
# FILE: tools/parallel_check.sh — проверка пересечения наборов файлов на запись (ADR-083 §1)
# Использование: bash tools/parallel_check.sh TASK1 TASK2 [TASK3 ...]
# Читает поле «Файлы на запись» из briefs/<TASK>.md. Печатает извлечённые наборы
# ЦЕЛИКОМ (ADR-044: совпавшие строки, не метка) и пересечения. RC 1 = запускать вместе нельзя.
set -uo pipefail
root=$(git rev-parse --show-toplevel 2>/dev/null) || true
[ -n "$root" ] || { echo "ПРОВЕРКА: не git-репозиторий" >&2; exit 2; }
cd "$root" || exit 2
[ $# -ge 2 ] || { echo "ПРОВЕРКА: нужно минимум две задачи" >&2; exit 2; }
TMP=$(mktemp -d) || exit 2
trap 'rm -rf "$TMP"' EXIT   # временные файлы НЕ в рабочем дереве: они бы попали в git status

extract() { # $1=TASK -> пути по одному в строке
  local f="briefs/$1.md"
  [ -f "$f" ] || { echo "ПРОВЕРКА: нет файла $f" >&2; return 3; }
  awk '
    /^\*\*Файлы на запись\*\*/ { inblock=1; found=1; next }
    inblock && /^\*\*/         { inblock=0 }
    inblock && /^- `/          { match($0,/`[^`]+`/); print substr($0,RSTART+1,RLENGTH-2) }
    END { if (!found) exit 4 }
  ' "$f"
}

fail=0
declare -a NAMES
for t in "$@"; do
  set +e; out=$(extract "$t"); rc=$?; set -e
  if [ $rc -eq 4 ]; then echo "ПРОВЕРКА: в briefs/$t.md нет поля «Файлы на запись» — это ОТКАЗ, не пустой набор" >&2; exit 3; fi
  [ $rc -eq 0 ] || exit 3
  n=$(printf '%s' "$out" | grep -c . || true)
  if [ "$n" -eq 0 ]; then echo "ПРОВЕРКА: у $t поле есть, но набор пуст — ОТКАЗ (ADR-021 §2)" >&2; exit 3; fi
  printf '== %s: %s путей ==\n%s\n\n' "$t" "$n" "$out"
  printf '%s\n' "$out" | sed 's#/$##' | sort -u > "$TMP/$t"
  NAMES+=("$t")
done

echo "== пересечения =="
for ((i=0;i<${#NAMES[@]};i++)); do for ((j=i+1;j<${#NAMES[@]};j++)); do
  a=${NAMES[$i]}; b=${NAMES[$j]}
  # пересечение: равные пути ИЛИ один есть каталог-предок другого
  hit=$(awk 'NR==FNR{p[$0];next}{ for(q in p){ if($0==q || index($0,q "/")==1 || index(q,$0 "/")==1) print q" <-> "$0 } }' "$TMP/$a" "$TMP/$b" | sort -u)
  if [ -n "$hit" ]; then printf '%s x %s: ПЕРЕСЕЧЕНИЕ\n%s\n' "$a" "$b" "$hit"; fail=1
  else printf '%s x %s: пересечения нет\n' "$a" "$b"; fi
done; done
echo "== вердикт =="
if [ "$fail" -eq 0 ]; then echo "ПАРАЛЛЕЛЬ ДОПУСТИМА по файлам (класс задач проверяется отдельно по 07_STATE)"; exit 0
else echo "ПАРАЛЛЕЛЬ ЗАПРЕЩЕНА: наборы пересекаются (ADR-082 §1). Запускать по одной."; exit 1; fi
