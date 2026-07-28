#!/usr/bin/env bash
# FILE: tools/hooks/selftest.sh — фикстурный самотест pre-commit (ADR-072 §2)
# Запуск: bash tools/hooks/selftest.sh   (из корня репо)
# Инвариант: КАЖДАЯ проверка хука обязана упасть на заведомо плохом входе
# и пропустить заведомо хороший. Верификация пер-проверка, не пер-хук (ADR-072 §3).
set -uo pipefail

HOOK="$(cd "$(dirname "$0")" && pwd)/pre-commit"
test -f "$HOOK" || { echo "SELFTEST FAIL: не найден $HOOK"; exit 1; }

PASS=0; FAIL=0
# ADR-072 §3: для кейса bad недостаточно "коммит не прошёл" — обязано быть падение
# ИМЕННО хука. Иначе посторонний сбой (нет git, нет прав) читается как успех проверки.
report() { # $1=имя $2=ожидание(bad|good) $3=rc $4=вывод
  if [ "$2" = bad ]; then
    if [ "$3" -eq 0 ]; then
      echo "  ПРОВАЛ $1 — коммит прошёл, хук не сработал"; FAIL=$((FAIL+1))
    elif printf '%s' "$4" | grep -q 'PRE-COMMIT FAIL'; then
      echo "  ok   $1 — упал на хуке, как должен"; PASS=$((PASS+1))
    else
      echo "  ПРОВАЛ $1 — упал НЕ на хуке (rc=$3), сбой окружения:"; FAIL=$((FAIL+1))
      printf '%s\n' "$4" | tail -3 | sed 's/^/         /'
    fi
  else
    if [ "$3" -eq 0 ]; then echo "  ok   $1 — прошёл, как должен"; PASS=$((PASS+1))
    else
      echo "  ПРОВАЛ $1 — ожидалось good, rc=$3:"; FAIL=$((FAIL+1))
      printf '%s\n' "$4" | tail -3 | sed 's/^/         /'
    fi
  fi
}

run_case() { # $1=имя $2=bad|good $3=функция подготовки
  SB="$(mktemp -d)"
  OUT="$( ( cd "$SB" && git init -q . && git config user.email t@t && git config user.name t \
    && git config commit.gpgsign false \
    && mkdir -p .git/hooks && cp "$HOOK" .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit \
    && "$3" && git add -A && git commit -q -m "selftest" ) 2>&1 )"
  RC=$?
  report "$1" "$2" "$RC" "$OUT"
  rm -rf "$SB"
}

# --- фикстуры ---
# Кириллица задана ЛИТЕРАЛЬНО, не через \x: printf в dash/sh не понимает \x-экранирование
# и записал бы его как текст, обнулив кейс 2-bad. Проверка фикстуры — сразу за записью.
c1_bad()  { printf '# НЕ ТО ИМЯ\n\ntext\n'            > 09_GLOSSARY.md; }
c1_good() { printf '# FILE: 09_GLOSSARY.md\n\ntext\n'  > 09_GLOSSARY.md; }
c2_bad()  { printf '# FILE: 07_STATE.md\n\n**updated_at:** x\n\nADR-0О1\n' > 07_STATE.md
            grep -q 'ADR-0О1' 07_STATE.md || { echo "SELFTEST BROKEN: фикстура 2-bad не содержит кириллицы"; return 1; }; }
c2_good() { printf '# FILE: 07_STATE.md\n\n**updated_at:** x\n\nADR-071\n'        > 07_STATE.md; }
c3_bad()  { printf '# 06 · DECISIONS\n\n## ADR-999 x\n' > 06_DECISIONS_LOG.md; }
c3_good() { printf '# 06 · DECISIONS\n\n## ADR-999 x\n' > 06_DECISIONS_LOG.md
            printf '# FILE: 06_INDEX.md\n\n| ADR-999 | x |\n' > 06_INDEX.md; }
c5_bad()  { printf '# FILE: 07_STATE.md\n\nno anchor\n'              > 07_STATE.md; }
c5_good() { printf '# FILE: 07_STATE.md\n\n**updated_at:** 2026\n'   > 07_STATE.md; }

echo "SELFTEST pre-commit"
echo "проверка 1 (ADR-054, имя в первой строке):"
run_case "1-bad"  bad  c1_bad
run_case "1-good" good c1_good
echo "проверка 2 (ADR-041, кириллица в ID):"
run_case "2-bad"  bad  c2_bad
run_case "2-good" good c2_good
echo "проверка 3 (ADR-064, 06 без 06_INDEX):"
run_case "3-bad"  bad  c3_bad
run_case "3-good" good c3_good
echo "проверка 5 (07_STATE без updated_at):"
run_case "5-bad"  bad  c5_bad
run_case "5-good" good c5_good

echo
echo "итог: пройдено $PASS, провалено $FAIL"
echo "ПРИМЕЧАНИЕ (ADR-072 §4): проверка 4 (удаление строки из 07_STATE => 07_ARCHIVE)"
echo "фикстурой не покрыта — требует истории коммитов, не одного снимка. Остаётся"
echo "на ревью владельца, как и полнота схемы session-блока (ADR-070 §4)."
[ "$FAIL" -eq 0 ] || exit 1
