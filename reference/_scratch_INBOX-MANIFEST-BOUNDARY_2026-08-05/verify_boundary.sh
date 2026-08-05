#!/usr/bin/env bash
# Замер фикса границы региона «Последствия» в tools/inbox_manifest.sh ПО РЕАЛЬНОМУ содержимому
# репо (ADR-074): все блоки буфера за всю историю git плюс текущий, старый awk против нового.
set -u
D=reference/_scratch_INBOX-MANIFEST-BOUNDARY_2026-08-05
T=$(mktemp -d); echo "временные копии блоков: $T"

cat > $T/old.awk <<'AWK'
/^[[:space:]]*[*_]*Последствия/        { inc=1; next }
inc && /^[[:space:]]*[*_]*Статус/      { inc=0 }
inc && /^## /                          { inc=0 }
inc && /^=== END SESSION ===/          { inc=0 }
inc && /^[[:space:]]*[*-] / {
  item = $0; sub(/^[[:space:]]*[*-] /, "", item)
  if (item !~ /^\[сейчас\]/ && item !~ /^\[отдельным коммитом\]/ &&
      item !~ /^\[задачей / && item !~ /^\[без правок\]/) printf "%d:%s\n", NR, $0
}
AWK
cat > $T/new.awk <<'AWK'
/^[[:space:]]*[*_]*Последствия/        { inc=1; next }
inc && /^[[:space:]]*[*_]*Статус/      { inc=0 }
inc && /^[[:space:]]*[*-][[:space:]]+ADR-/ { inc=0 }
inc && /^## /                          { inc=0 }
inc && /^=== END SESSION ===/          { inc=0 }
inc && /^[[:space:]]*[*-] / {
  item = $0; sub(/^[[:space:]]*[*-] /, "", item)
  if (item !~ /^\[сейчас\]/ && item !~ /^\[отдельным коммитом\]/ &&
      item !~ /^\[задачей / && item !~ /^\[без правок\]/) printf "%d:%s\n", NR, $0
}
AWK

# Все блоки буфера за всю историю (файлы удаляются сборкой, поэтому берём из git).
git log --all --diff-filter=A --format="C %H" --name-only -- 'reference/_inbox/session_*.md' \
 | awk '/^C /{sha=$2} /^reference\/_inbox\/session_/{print sha" "$0}' | sort -u > $T/list.txt

n=0; changed=0; still=0
while read -r sha path; do
  n=$((n+1))
  base=$(basename "$path"); f="$T/${n}_${base}"
  git show "$sha:$path" > "$f" 2>/dev/null || continue
  o=$(awk -f $T/old.awk "$f" | wc -l | tr -d ' ')
  w=$(awk -f $T/new.awk "$f" | wc -l | tr -d ' ')
  if [ "$o" != "$w" ]; then
    changed=$((changed+1))
    echo "ИЗМЕНИЛСЯ ВЕРДИКТ: $base ($sha) старый=$o новый=$w"
    echo "  — что перестало ловиться:"
    diff <(awk -f $T/old.awk "$f") <(awk -f $T/new.awk "$f") | grep '^<' | sed 's/^/    /'
  fi
  [ "$w" != "0" ] && still=$((still+1))
done < $T/list.txt

echo; echo "исторических блоков проверено: $n"
echo "блоков со сменой вердикта: $changed"
echo "блоков, где новый awk всё ещё что-то находит: $still"

echo; echo "=== текущий буфер ==="
for f in reference/_inbox/session_*.md; do
  [ -e "$f" ] || continue
  echo "$f: старый=$(awk -f $T/old.awk "$f" | wc -l | tr -d ' ') новый=$(awk -f $T/new.awk "$f" | wc -l | tr -d ' ')"
  awk -f $T/old.awk "$f" | sed 's/^/  старый ловит: /'
done
echo "ВРЕМЕННЫЙ КАТАЛОГ (не убирается, ADR-043): $T"
