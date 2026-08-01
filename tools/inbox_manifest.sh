#!/usr/bin/env bash
# FILE: tools/inbox_manifest.sh — инвентарь буфера session-блоков
# Основание: решение сессии PARITY-GAPS-ADJ (2026-08-01), мера (B) параграфа «Форма фикса»
# блока reference/_inbox/session_PARITY-GAPS-ADJ_2026-08-01.md; номер ADR присваивает сборка,
# поэтому здесь он не проставлен (номер — в 06_INDEX.md по этой дате и теме).
# Использование: bash tools/inbox_manifest.sh
# Печатает по каждому файлу reference/_inbox/ то, что в нём РЕАЛЬНО есть: задачу и дату из
# имени, первую строку, наличие четырёх разделов, пункты последствий без маркера времени.
# Смысл — превратить утверждение о содержимом буфера в напечатанный факт ДО первой правки
# (ADR-021 §2, ADR-044: вердикт печатает строки, а не метку; ADR-083 §4: счётчик, а не
# отсутствие вывода). Текст запуска сборки входом НЕ является (_ASSEMBLER.md §3 п.0).
# RC 0 = находок нет; RC 1 = есть находка, требующая остановки по _ASSEMBLER.md §10; RC 2 = среда.
set -uo pipefail
root=$(git rev-parse --show-toplevel 2>/dev/null) || true
[ -n "$root" ] || { echo "ИНВЕНТАРЬ: не git-репозиторий" >&2; exit 2; }
cd "$root" || exit 2
INBOX="reference/_inbox"
[ -d "$INBOX" ] || { echo "ИНВЕНТАРЬ: нет каталога $INBOX" >&2; exit 2; }

SECTIONS="SESSION_LOG STATE_PATCH NEW_DECISIONS NEW_CONVENTIONS"
fail=0
n_files=0
n_skipped=0

# Список файлов буфера кроме .gitkeep. Скрытые файлы (напр. .DS_Store) считаются отдельно:
# они не блоки, но и молчать о них нельзя — git их может игнорировать, глаз нет.
while IFS= read -r f; do
  base=$(basename "$f")
  [ "$base" = ".gitkeep" ] && continue
  case "$base" in
    .*) n_skipped=$((n_skipped+1)); echo "ПОСТОРОННИЙ ФАЙЛ: $f (не блок, не .gitkeep)"; fail=1; continue ;;
  esac
  n_files=$((n_files+1))
  echo "── файл: $f"

  # Шаблон имени: session_<TASK>_<YYYY-MM-DD>.md (ADR-080 §4)
  if [[ "$base" =~ ^session_(.+)_([0-9]{4}-[0-9]{2}-[0-9]{2})\.md$ ]]; then
    echo "   задача (из имени): ${BASH_REMATCH[1]}"
    echo "   дата   (из имени): ${BASH_REMATCH[2]}"
  else
    echo "   ИМЯ НЕ ПО ШАБЛОНУ session_<TASK>_<YYYY-MM-DD>.md — стоп-условие (_ASSEMBLER.md §10)"
    fail=1
  fi

  echo "   первая строка файла: $(head -n 1 "$f")"

  for s in $SECTIONS; do
    cnt=$(grep -c "^## $s" "$f" || true)
    if [ "$cnt" -eq 0 ]; then
      echo "   раздел $s: ОТСУТСТВУЕТ"
      fail=1
    else
      echo "   раздел $s: есть ($cnt)"
    fi
  done

  # Пункты блока «Последствия» без маркера времени прихода (ADR-083 §3).
  # Регион: от строки «Последствия:» до «Статус:» / нового заголовка / конца блока.
  unmarked=$(awk '
    /^[[:space:]]*Последствия:/            { inc=1; next }
    inc && /^[[:space:]]*Статус:/          { inc=0 }
    inc && /^## /                          { inc=0 }
    inc && /^=== END SESSION ===/          { inc=0 }
    inc && /^[[:space:]]*- / {
      item = $0
      sub(/^[[:space:]]*- /, "", item)
      if (item !~ /^\[сейчас\]/ && item !~ /^\[отдельным коммитом\]/ &&
          item !~ /^\[задачей / && item !~ /^\[без правок\]/)
        printf "%d:%s\n", NR, $0
    }
  ' "$f")
  if [ -n "$unmarked" ]; then
    echo "   пунктов последствий БЕЗ маркера времени: $(printf '%s\n' "$unmarked" | wc -l | tr -d ' ')"
    printf '%s\n' "$unmarked" | sed 's/^/     /'
    fail=1
  else
    echo "   пунктов последствий без маркера времени: 0"
  fi
done < <(find "$INBOX" -maxdepth 1 -type f | sort)

echo
echo "== итог инвентаря =="
echo "файлов-блоков: $n_files"
echo "посторонних файлов: $n_skipped"
if [ "$fail" -eq 0 ]; then
  echo "ВЕРДИКТ: находок нет — буфер разбирается по _ASSEMBLER.md §4"
else
  echo "ВЕРДИКТ: есть находка выше — остановка и вопрос владельцу (_ASSEMBLER.md §10)"
fi
exit "$fail"
