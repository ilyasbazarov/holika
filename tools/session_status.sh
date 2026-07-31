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
cand=$(find reference/_inbox -maxdepth 1 -type f ! -name .gitkeep | sort)
b=""; ign=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if git check-ignore -q -- "$f"; then
    ign="${ign:+$ign
}$f"
  else
    b="${b:+$b
}$f"
  fi
done <<< "$cand"
nb=$(printf '%s' "$b" | grep -c . || true)
printf 'файлов кроме .gitkeep: %s\n' "$nb"; [ "$nb" -gt 0 ] && printf '%s\n' "$b"
ni=$(printf '%s' "$ign" | grep -c . || true)
if [ "$ni" -gt 0 ]; then
  printf 'ВНИМАНИЕ: git-игнорируемых файлов в буфере (не входят в счётчик выше): %s\n' "$ni"
  printf '%s\n' "$ign"
fi
[ -f reference/_inbox/.gitkeep ] || echo 'ВНИМАНИЕ: .gitkeep отсутствует (_ASSEMBLER §2)'

sec "рабочие деревья"
w=$(git worktree list); nw=$(printf '%s\n' "$w" | grep -c . || true)
printf 'деревьев: %s (норма вне сессий: 1)\n' "$nw"; printf '%s\n' "$w"

sec "ветки сессий"
br=$(git branch --list 's/*' --format='%(refname:short)')
nbr=$(printf '%s' "$br" | grep -c . || true)
printf 'веток s/*: %s\n' "$nbr"; [ "$nbr" -gt 0 ] && printf '%s\n' "$br"

sec "отставание от origin/main"
fetch_out=$(git fetch 2>&1); fetch_rc=$?
if [ "$fetch_rc" -ne 0 ]; then
  printf 'ВНИМАНИЕ: git fetch не удался (rc=%s) — счётчик ниже посчитан по устаревшему origin/main:\n' "$fetch_rc"
  printf '%s\n' "$fetch_out"
fi
lag=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
printf 'отставание от origin/main: %s\n' "$lag"

sec "вердикт"
if [ "$WHERE" = связанное ]; then
  # В дереве сессии чужие деревья и ветки нормальны и стоп-условием не являются (ADR-081 §6).
  if [ "$nb" -eq 0 ] && [ "$lag" -eq 0 ]; then echo 'ЧИСТО для сессии в своём дереве: буфер пуст, отставания от origin/main нет'; exit 0
  else
    [ "$nb" -gt 0 ] && echo 'НЕ ЧИСТО: буфер непуст — сначала режим С (ADR-080 §4v)'
    [ "$lag" -gt 0 ] && echo 'НЕ ЧИСТО: локальная база отстаёт от origin/main (ADR-086 §4)'
    exit 1
  fi
fi
if [ "$n" -eq 0 ] && [ "$nb" -eq 0 ] && [ "$nw" -eq 1 ] && [ "$nbr" -eq 0 ] && [ "$lag" -eq 0 ]; then
  echo 'ЧИСТО: можно стартовать любую сессию'; exit 0
else
  echo 'НЕ ЧИСТО: см. счётчики выше. Непустой буфер, ветки s/* либо отставание от origin/main = сначала режим С (ADR-080 §4v, ADR-081 §6, ADR-086 §4)'
  exit 1
fi
