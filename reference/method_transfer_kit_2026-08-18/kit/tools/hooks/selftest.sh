#!/usr/bin/env bash
# FILE: tools/hooks/selftest.sh — фикстурный самотест pre-commit (ADR-072 §2; три оси — ADR-074 §4)
# Запуск: bash tools/hooks/selftest.sh   (из корня репо)
# Инвариант: КАЖДАЯ проверка хука обязана упасть на заведомо плохом входе
# и пропустить заведомо хороший. Верификация пер-проверка, не пер-хук (ADR-072 §3).
set -uo pipefail

HOOK="$(cd "$(dirname "$0")" && pwd)/pre-commit"
test -f "$HOOK" || { echo "SELFTEST FAIL: не найден $HOOK"; exit 1; }

# ADR-074 §4/§9, ось «локаль»: одна из осей дефекта — байтовая семантика класса символов,
# в многобайтной локали она невидима. Локаль подбирается ФУНКЦИОНАЛЬНО, а не по имени из
# locale -a: имя ничего не гарантирует (несуществующая локаль молча откатывается в C).
# Проба: bracket-выражение над кириллицей против «Q-» плюс кириллическая п. Совпало =>
# байтовая семантика.
probe_multibyte() { # $1=локаль; 0 = многобайтная семантика
  local f; f="$(mktemp)"; printf 'Q-\320\277\n' > "$f"
  if LC_ALL="$1" grep -qE '[МСЕАРОТНКВХ]' "$f"; then rm -f "$f"; return 1; else rm -f "$f"; return 0; fi
}
if [ -n "${SELFTEST_LOCALES:-}" ]; then
  LOCALES="$SELFTEST_LOCALES"
else
  LOCALES="C"; MB=""
  for cand in C.UTF-8 C.utf8 en_US.UTF-8 ru_RU.UTF-8 UTF-8; do
    if probe_multibyte "$cand"; then MB="$cand"; break; fi
  done
  if [ -n "$MB" ]; then
    LOCALES="C $MB"; echo "локали: C (байтовая) и $MB (многобайтная)"
  else
    echo "ПРИМЕЧАНИЕ: многобайтной локали не найдено, ось локали проверена только в C."
    echo "Это не провал: паттерн ADR-074 §2 не зависит от локали, ось проверяет именно независимость."
  fi
fi

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

sandbox_init() {
  git init -q . && git config user.email t@t && git config user.name t \
    && git config commit.gpgsign false \
    && mkdir -p .git/hooks && cp "$HOOK" .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
}

run_case() { # $1=имя $2=bad|good $3=функция подготовки
  SB="$(mktemp -d)"
  OUT="$( ( cd "$SB" && sandbox_init && "$3" && git add -A && git commit -q -m "selftest" ) 2>&1 )"
  RC=$?
  report "$1" "$2" "$RC" "$OUT"
  rm -rf "$SB"
}

# ADR-074 §7: проверка №4 требует ИСТОРИИ коммитов, одним снимком не покрывается (ADR-072 §4).
# Сид коммитится через --no-verify, чтобы судился только второй коммит.
run_case_hist() { # $1=имя $2=bad|good $3=функция сида $4=функция правки
  SB="$(mktemp -d)"
  OUT="$( ( cd "$SB" && sandbox_init && "$3" && git add -A && git commit -q --no-verify -m seed \
            && "$4" && git add -A && git commit -q -m "selftest" ) 2>&1 )"
  RC=$?
  report "$1" "$2" "$RC" "$OUT"
  rm -rf "$SB"
}

# --- фикстуры ---
# Кириллица задана ЛИТЕРАЛЬНО, не через \x: printf в dash/sh не понимает \x-экранирование
# и записал бы его как текст, обнулив кейс 2-bad. Проверка фикстуры — сразу за записью.
c1_bad()  { printf '# НЕ ТО ИМЯ\n\ntext\n'            > 09_GLOSSARY.md; }
c1_good() { printf '# FILE: 09_GLOSSARY.md\n\ntext\n'  > 09_GLOSSARY.md; }
# ADR-074 §8: подделка собирается ВОСЬМЕРИЧНЫМ escape (POSIX printf, работает в bash/sh/dash),
# а не литеральным символом. Литерал в коммитимом файле сам есть нарушение ADR-041 и попал в репо
# только потому, что проверка №2 была сломана. Урок ADR-072 §9 сохранён и усилен: фикстура
# проверяется сразу после записи И подтверждается дампом байтов.
CYR_O="$(printf '\320\236')"      # U+041E, кириллическая О
fixture_check() { # $1=файл
  grep -q "$CYR_O" "$1" || { echo "SELFTEST BROKEN: в фикстуре $1 нет кириллицы"; return 1; }
  # ADR-074 §9: пробелы и переносы строк удаляются целиком. Формат od различается между
  # GNU и BSD (macOS), а байт может оказаться последним в строке дампа — поиск 'd0 9e'
  # с пробелом был непереносим и падал на macOS при корректной фикстуре.
  od -An -tx1 "$1" | tr -d '[:space:]' | grep -q 'd09e' \
    || { echo "SELFTEST BROKEN: дамп $1 без байтов d0 9e"; return 1; }; }
c2_bad()  { printf '# FILE: 07_STATE.md\n\n**updated_at:** x\n\nADR-0%s1\n' "$CYR_O" > 07_STATE.md
            fixture_check 07_STATE.md; }
c2_good() { printf '# FILE: 07_STATE.md\n\n**updated_at:** x\n\nADR-071\n'        > 07_STATE.md; }
c3_bad()  { printf '# 06 · DECISIONS\n\n## ADR-999 x\n' > 06_DECISIONS_LOG.md; }
c3_good() { printf '# 06 · DECISIONS\n\n## ADR-999 x\n' > 06_DECISIONS_LOG.md
            printf '# FILE: 06_INDEX.md\n\n| ADR-999 | x |\n' > 06_INDEX.md; }
c5_bad()  { printf '# FILE: 07_STATE.md\n\nno anchor\n'              > 07_STATE.md; }
c5_good() { printf '# FILE: 07_STATE.md\n\n**updated_at:** 2026\n'   > 07_STATE.md; }

# ADR-074 §4, ось «размер»: файл больше буфера пайпа (64 КиБ) ловит дефект проверки №1
big_body() { awk 'BEGIN{for(i=0;i<1200;i++) printf "| Q-%d | наполнитель %s |\n", i, "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"}'; }
c6_good() { { printf '# FILE: 07_STATE.md\n\n**updated_at:** x\n\n'; big_body; } > 07_STATE.md
            test "$(wc -c < 07_STATE.md)" -gt 65536 || { echo "SELFTEST BROKEN: фикстура 6 меньше буфера пайпа"; return 1; }; }
c7_bad()  { c6_good && printf 'ADR-0%s1\n' "$CYR_O" >> 07_STATE.md
            fixture_check 07_STATE.md; }
# ADR-074 §4, ось «легитимный композит»: строки, дословно встречающиеся в репо, ложно срабатывать НЕ должны
c8_good() { printf '# FILE: 07_STATE.md\n\n**updated_at:** x\n\n| Q-20 | DQ-порог, BQ-выгрузка, ADR-кандидат, Q-номер, RUB-документ |\n' > 07_STATE.md; }

# ADR-074 §7: проверка №4, три кейса на истории коммитов
c4_seed()      { printf '# FILE: 07_STATE.md\n\n**updated_at:** 2026-01-01\n\n| Q-100 | первая |\n| Q-101 | вторая |\n' > 07_STATE.md; }
c4_bad_gone()  { printf '# FILE: 07_STATE.md\n\n**updated_at:** 2026-01-02\n\n| Q-100 | первая |\n' > 07_STATE.md; }
c4_good_ref()  { printf '# FILE: 07_STATE.md\n\n**updated_at:** 2026-01-02\n\n| Q-100 | первая |\n| Q-101 | вторая, ПЕРЕФОРМУЛИРОВАНА |\n' > 07_STATE.md; }
c4_good_arch() { printf '# FILE: 07_STATE.md\n\n**updated_at:** 2026-01-02\n\n| Q-100 | первая |\n' > 07_STATE.md
                 printf '# FILE: 07_ARCHIVE.md\n\n- Q-101 закрыт\n' > 07_ARCHIVE.md; }

# ADR-106 §1/§5vii: проверка 9 — множества ID индекса 07_STATE и полного текста 07_GAPS.
# Индекс задаётся ВНУТРИ раздела «Открытые вопросы»; строка вне раздела в множество не входит.
IDX_HDR='# FILE: 07_STATE.md\n\n**updated_at:** 2026-01-02\n\n## Открытые вопросы / GAP-реестр\n\n| ID | Статус |\n|---|---|\n'
GAPS_HDR='# FILE: 07_GAPS.md\n\n| ID | Вопрос |\n|---|---|\n'
c9_good() { printf "$IDX_HDR"'| `Q-100` | OPEN |\n| `Q-101` | DEFER |\n\n## Контрольные цифры\n' > 07_STATE.md
            printf "$GAPS_HDR"'| Q-100 | первая |\n| Q-101 | вторая |\n'                          > 07_GAPS.md; }
c9_bad()  { printf "$IDX_HDR"'| `Q-100` | OPEN |\n\n## Контрольные цифры\n'                       > 07_STATE.md
            printf "$GAPS_HDR"'| Q-100 | первая |\n| Q-101 | вторая |\n'                          > 07_GAPS.md; }
# проверка 4, расширенная на 07_GAPS: строка исчезла из полного текста без 07_ARCHIVE
c10_seed()     { c9_good; sed -i.bak 's/2026-01-02/2026-01-01/' 07_STATE.md; rm -f 07_STATE.md.bak; }
c10_bad_gone() { printf "$IDX_HDR"'| `Q-100` | OPEN |\n\n## Контрольные цифры\n' > 07_STATE.md
                 printf "$GAPS_HDR"'| Q-100 | первая |\n'                          > 07_GAPS.md; }
c10_good_arch(){ c10_bad_gone; printf '# FILE: 07_ARCHIVE.md\n\n- Q-101 закрыт\n' > 07_ARCHIVE.md; }

all_cases() {
  echo "проверка 1 (ADR-054, имя в первой строке):"
  run_case "1-bad$SFX"  bad  c1_bad
  run_case "1-good$SFX" good c1_good
  echo "проверка 2 (ADR-041, кириллица в ID):"
  run_case "2-bad$SFX"  bad  c2_bad
  run_case "2-good$SFX" good c2_good
  echo "проверка 3 (ADR-064, 06 без 06_INDEX):"
  run_case "3-bad$SFX"  bad  c3_bad
  run_case "3-good$SFX" good c3_good
  echo "проверка 4 (ADR-064/ADR-074 §7, исчезновение строки против переформулировки):"
  run_case_hist "4-bad-gone$SFX"   bad  c4_seed c4_bad_gone
  run_case_hist "4-good-reform$SFX" good c4_seed c4_good_ref
  run_case_hist "4-good-archive$SFX" good c4_seed c4_good_arch
  echo "проверка 5 (07_STATE без updated_at):"
  run_case "5-bad$SFX"  bad  c5_bad
  run_case "5-good$SFX" good c5_good
  echo "ADR-074 ось размера (файл больше буфера пайпа):"
  run_case "6-good$SFX" good c6_good
  run_case "7-bad$SFX"  bad  c7_bad
  echo "ADR-074 ось легитимного композита (ложное срабатывание проверки 2):"
  run_case "8-good$SFX" good c8_good
  echo "проверка 9 (ADR-106 §1, индекс 07_STATE против полного текста 07_GAPS):"
  run_case "9-good$SFX" good c9_good
  run_case "9-bad$SFX"  bad  c9_bad
  echo "проверка 4, расширенная на 07_GAPS (исчезновение строки из полного текста):"
  run_case_hist "10-bad-gone$SFX"    bad  c10_seed c10_bad_gone
  run_case_hist "10-good-archive$SFX" good c10_seed c10_good_arch
}

echo "SELFTEST pre-commit"
for L in $LOCALES; do
  echo "== локаль $L =="
  export LC_ALL="$L"; SFX=" [$L]"
  all_cases
done
unset LC_ALL

echo
echo "итог: пройдено $PASS, провалено $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
