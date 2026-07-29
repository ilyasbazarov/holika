#!/usr/bin/env bash
# FILE: tools/session_status.sh — состояние старта сессии одной командой (ADR-083 §4)
# Печатает ФАКТЫ положительно: счётчик плюс совпавшие строки (ADR-044).
# Пустой вывод результатом не является: критерий — напечатанное число.
set -uo pipefail
root=$(git rev-parse --show-toplevel 2>/dev/null) || true
[ -n "$root" ] || { echo "СТАТУС: не git-репозиторий" >&2; exit 2; }
cd "$root" || exit 2
gd=$(git rev-parse --absolute-git-dir); gc=$(cd "$(git rev-parse --git-common-dir)" && pwd)
if [ "$gd" = "$gc" ]; then WHERE=основное; else WHERE=связанное; fi
printf 'дерево: %s (%s)\n' "$WHERE" "$root"

sec() { printf '\n== %s ==\n' "$1"; }

sec "рабочее дерево"
d=$(git status --short); n=$(printf '%s' "$d" | grep -c . || true)
printf 'изменённых файлов: %s\n' "$n"; [ "$n" -gt 0 ] && printf '%s\n' "$d"

sec "буфер reference/_inbox"
if [ ! -d reference/_inbox ]; then
  echo 'КАТАЛОГА НЕТ — это отказ, а не пустой буфер'; exit 2
fi
b=$(find reference/_inbox -maxdepth 1 -type f ! -name .gitkeep | sort)
nb=$(printf '%s' "$b" | grep -c . || true)
printf 'файлов кроме .gitkeep: %s\n' "$nb"; [ "$nb" -gt 0 ] && printf '%s\n' "$b"
[ -f reference/_inbox/.gitkeep ] || echo 'ВНИМАНИЕ: .gitkeep отсутствует (_ASSEMBLER §2)'

sec "рабочие деревья"
w=$(git worktree list); nw=$(printf '%s\n' "$w" | grep -c . || true)
printf 'деревьев: %s (норма вне сессий: 1)\n' "$nw"; printf '%s\n' "$w"

sec "ветки сессий"
br=$(git branch --list 's/*' --format='%(refname:short)')
nbr=$(printf '%s' "$br" | grep -c . || true)
printf 'веток s/*: %s\n' "$nbr"; [ "$nbr" -gt 0 ] && printf '%s\n' "$br"

sec "вердикт"
if [ "$WHERE" = связанное ]; then
  # В дереве сессии чужие деревья и ветки нормальны и стоп-условием не являются (ADR-081 §6).
  if [ "$nb" -eq 0 ]; then echo 'ЧИСТО для сессии в своём дереве: буфер пуст'; exit 0
  else echo 'НЕ ЧИСТО: буфер непуст — сначала режим С (ADR-080 §4v)'; exit 1; fi
fi
if [ "$n" -eq 0 ] && [ "$nb" -eq 0 ] && [ "$nw" -eq 1 ] && [ "$nbr" -eq 0 ]; then
  echo 'ЧИСТО: можно стартовать любую сессию'; exit 0
else
  echo 'НЕ ЧИСТО: см. счётчики выше. Непустой буфер либо ветки s/* = сначала режим С (ADR-080 §4v, ADR-081 §6)'
  exit 1
fi
