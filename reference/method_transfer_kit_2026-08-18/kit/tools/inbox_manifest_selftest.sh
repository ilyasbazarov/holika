#!/usr/bin/env bash
# FILE: tools/inbox_manifest_selftest.sh — фикстурный самотест inbox_manifest.sh
# Запуск: bash tools/inbox_manifest_selftest.sh   (из корня репо)
# Инвариант тот же, что у самотеста хука (ADR-072 §3): КАЖДАЯ проверка обязана упасть на
# заведомо плохом входе и пропустить заведомо хороший. Верификация пер-проверка, не пер-скрипт:
# «сломанная проверка хуже отсутствующей» — её отказ тихий.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/inbox_manifest.sh"
test -f "$SCRIPT" || { echo "SELFTEST FAIL: не найден $SCRIPT"; exit 1; }

PASS=0; FAIL=0
report() { # $1=имя $2=ожидание(bad|good) $3=rc $4=вывод
  if [ "$2" = bad ]; then
    if [ "$3" -eq 0 ]; then
      echo "  ПРОВАЛ $1 — находки нет, скрипт не сработал"; FAIL=$((FAIL+1))
    elif [ "$3" -eq 1 ]; then
      echo "  ok   $1 — находка, как должно"; PASS=$((PASS+1))
    else
      echo "  ПРОВАЛ $1 — rc=$3, это сбой среды, а не находка:"; FAIL=$((FAIL+1))
      printf '%s\n' "$4" | tail -3 | sed 's/^/         /'
    fi
  else
    if [ "$3" -eq 0 ]; then echo "  ok   $1 — прошёл, как должен"; PASS=$((PASS+1))
    else
      echo "  ПРОВАЛ $1 — ожидалось good, rc=$3:"; FAIL=$((FAIL+1))
      printf '%s\n' "$4" | grep -E 'ПОСТОРОННИЙ|ВНЕ четырёх|без маркера|ОТСУТСТВУЕТ|ИМЯ НЕ' | sed 's/^/         /'
    fi
  fi
}

# Каркас блока: четыре обязательных раздела плюс регион последствий.
# $1 — форма заголовка последствий, $2 — строки пунктов.
block() {
  printf '# FILE: x.md\n\n## SESSION_LOG\n- x\n\n## STATE_PATCH\n- x\n\n'
  printf '## NEW_DECISIONS\n- ADR-0NN: x\n\n  %s\n\n%s\n\n  **Статус:** accepted\n\n' "$1" "$2"
  printf '## NEW_CONVENTIONS\n- нет\n\n=== END SESSION ===\n'
}

run_case() { # $1=имя $2=bad|good $3=функция подготовки буфера
  SB="$(mktemp -d)"
  OUT="$( ( cd "$SB" && git init -q . && mkdir -p reference/_inbox tools \
            && cp "$SCRIPT" tools/ && touch reference/_inbox/.gitkeep \
            && "$3" && bash tools/inbox_manifest.sh ) 2>&1 )"
  RC=$?
  report "$1" "$2" "$RC" "$OUT"
  rm -rf "$SB"
}

F=reference/_inbox/session_SELFTEST_2026-01-01.md

# 1. Пункт [сейчас] адресован файлу ВНУТРИ четырёх файлов сборки — не находка.
c_scope_good() { block '**Последствия.**' '  * [сейчас] `07_STATE.md` — абзац
  * [сейчас] `06_INDEX.md` — строка' > "$F"; }
# 2. Тот же пункт на файле ВНЕ четвёрки — находка (главный кейс этой проверки).
c_scope_bad()  { block '**Последствия.**' '  * [сейчас] `_METHOD.md` §11 — правка канона' > "$F"; }
# 3. Тот же файл под правильным маркером — не находка.
c_scope_marked() { block '**Последствия.**' '  * [отдельным коммитом] `_METHOD.md` §11 — правка канона' > "$F"; }
# 4. reference/** исключён сознательно: сессия коммитит артефакт сама (CLAUDE.md §Конец сессии).
c_scope_ref()  { block '**Последствия.**' '  * [сейчас] `reference/x_2026-01-01.md` — артефакт сессии, закоммичен ею же' > "$F"; }
# 5. Регрессия формы заголовка: «Последствия:» — та единственная форма, которую скрипт понимал
#    до правки; остальные три (замер по 43 блокам: 9/7/7/4) были ему невидимы.
c_hdr_colon()  { block 'Последствия:' '  * [сейчас] `_METHOD.md` §11 — правка канона' > "$F"; }
# 6. Регрессия буллета: пункты через «*» составляли 56 из 110 в истории и не проверялись вовсе.
c_bullet_star(){ block '**Последствия.**' '  * без маркера времени, звёздочкой' > "$F"; }
# 7. Тот же пункт через «-» — форма, которую скрипт понимал и раньше.
c_bullet_dash(){ block '**Последствия.**' '  - без маркера времени, дефисом' > "$F"; }
# 8. Посторонний файл в буфере (напр. .DS_Store): git его игнорирует, глаз нет.
c_stray()      { block '**Последствия.**' '  * [сейчас] `07_STATE.md` — абзац' > "$F"
                 printf 'x' > reference/_inbox/.DS_Store; }

echo "SELFTEST inbox_manifest"
echo "проверка «[сейчас] вне четырёх файлов сборки»:"
run_case scope-good      good c_scope_good
run_case scope-bad       bad  c_scope_bad
run_case scope-marked    good c_scope_marked
run_case scope-reference good c_scope_ref
echo "регрессия формы заголовка последствий:"
run_case hdr-colon       bad  c_hdr_colon
echo "регрессия формы буллета (пункт без маркера времени):"
run_case bullet-star     bad  c_bullet_star
run_case bullet-dash     bad  c_bullet_dash
echo "посторонний файл в буфере:"
run_case stray-dotfile   bad  c_stray

echo
echo "итог: пройдено $PASS, провалено $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
