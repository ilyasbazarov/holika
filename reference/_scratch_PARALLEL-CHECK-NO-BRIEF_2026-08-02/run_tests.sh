#!/usr/bin/env bash
# FILE: run_tests.sh — приёмочный прогон tools/parallel_check.sh после правки ADR-102.
# Замер идёт по РЕАЛЬНОМУ содержимому репо, не по синтетической фикстуре (05 Часть I,
# расширение ADR-074). Каждый кейс печатает вывод целиком и код возврата (ADR-044).
cd "$(git rev-parse --show-toplevel)" || exit 2
date -u
echo "HEAD: $(git rev-parse HEAD)"
run() { echo; echo "########## $1"; shift; bash tools/parallel_check.sh "$@"; echo "RC=$?"; }
run "К1 обе без брифа, класс A, наборы разные -> ожидание RC 0" FX-MAY-WINDOW-D1-TAIL METHOD-PROMOTE-LOCAL-RULES
run "К2 задача целиком класса B -> ожидание RC 1" AUDIT-COUNTERPARTIES-SNAPSHOT-RETIRE FX-MAY-WINDOW-D1-TAIL
run "К3 смешанный класс + строка без «Пишет:» -> ожидание RC 3 (отказ, не тихий пропуск)" INGEST-CURRENCY-ASSERT INGEST-MOMENT-ZONE-FIX
run "К4 бриф имеет приоритет над таблицей -> ожидание RC 0" SOURCE-MAP-REST FX-MAY-WINDOW-D1-TAIL
run "К5 задачи нет нигде -> ожидание RC 3" NO-SUCH-TASK FX-MAY-WINDOW-D1-TAIL
run "К6 реальное пересечение по каталогу-предку reference/code/ -> ожидание RC 1" SOURCE-MAP-REST INGEST-CURRENCY-ASSERT
date -u
