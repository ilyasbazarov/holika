#!/usr/bin/env bash
# FILE: tools/parallel_check.sh — проверка пересечения наборов файлов на запись (ADR-083 §1)
# Использование: bash tools/parallel_check.sh TASK1 TASK2 [TASK3 ...]
# Источник набора — два, в порядке приоритета (ADR-102):
#   1) поле «Файлы на запись» в briefs/<TASK>.md;
#   2) поле «Пишет:» в строках таблицы 07_STATE §Мандат Claude Code — для задач,
#      исполняемых БЕЗ брифа (ADR-086 §1). Берутся ВСЕ строки задачи, включая её шаги
#      («<TASK>, шаг 2a»), потому что набор задачи есть объединение наборов её шагов.
# Печатает извлечённые наборы ЦЕЛИКОМ и с указанием источника (ADR-044: совпавшие
# строки, не метка), затем пересечения. RC 1 = запускать вместе нельзя.
# Класс задачи читается из той же таблицы: класс B не параллелится никогда (ADR-082 §1),
# положительно установленный класс B даёт RC 1. Класс, который установить не удалось,
# печатается как неустановленный и вердикт по файлам НЕ меняет: отсутствие данных
# фактом не является (ADR-021 §2).
set -uo pipefail
root=$(git rev-parse --show-toplevel 2>/dev/null) || true
[ -n "$root" ] || { echo "ПРОВЕРКА: не git-репозиторий" >&2; exit 2; }
cd "$root" || exit 2
[ $# -ge 2 ] || { echo "ПРОВЕРКА: нужно минимум две задачи" >&2; exit 2; }
STATE="07_STATE.md"
TMP=$(mktemp -d) || exit 2
trap 'rm -rf "$TMP"' EXIT   # временные файлы НЕ в рабочем дереве: они бы попали в git status

extract_brief() { # $1=TASK -> пути по одному в строке; RC 3 нет файла, RC 4 нет поля
  local f="briefs/$1.md"
  [ -f "$f" ] || return 3
  awk '
    /^\*\*Файлы на запись\*\*/ { inblock=1; found=1; next }
    inblock && /^\*\*/         { inblock=0 }
    inblock && /^- `/          { match($0,/`[^`]+`/); print substr($0,RSTART+1,RLENGTH-2) }
    END { if (!found) exit 4 }
  ' "$f"
}

extract_state() { # $1=TASK -> строки «PATH<TAB>путь» и «CLASS<TAB>класс»; RC 3 строк задачи нет
  [ -f "$STATE" ] || return 3
  awk -v task="$1" -F'|' '
    /^## Мандат Claude Code/ { insec=1; next }
    insec && /^## /          { insec=0 }
    !insec                   { next }
    /^\| / {
      name=$2; gsub(/^[ \t]+|[ \t]+$/,"",name)
      if (name!=task && index(name, task ",")!=1) next
      rows++
      cls=$3; gsub(/^[ \t]+|[ \t]+$/,"",cls)
      if (cls!="") print "CLASS\t" cls
      osn=""
      for (i=6;i<NF;i++) osn = osn (i>6 ? "|" : "") $i
      p=index(osn,"Пишет:")
      if (p==0) next
      tail=substr(osn,p)
      while (match(tail,/`[^`]+`/)) {
        tok=substr(tail,RSTART+1,RLENGTH-2)
        tail=substr(tail,RSTART+RLENGTH)
        # в хвосте «Пишет:» рядом с путями стоят ссылки вида `ADR-081 §8` — они не пути.
        # Отсекаются по пробелу и по знаку параграфа; иначе две задачи, цитирующие один
        # и тот же ADR, дали бы ЛОЖНОЕ пересечение и заблокировали законный запуск.
        if (tok ~ /[[:space:]]/ || tok ~ /§/) continue
        print "PATH\t" tok
      }
    }
    END { if (!rows) exit 3 }
  ' "$STATE"
}

class_of() { # $1=TASK -> классы через «/», пусто если строк задачи нет
  set +e
  extract_state "$1" 2>/dev/null | awk -F'\t' '$1=="CLASS"{print $2}' | sort -u | paste -sd'/' -
  set -e
}

fail=0
declare -a NAMES
for t in "$@"; do
  src=""; out=""

  # класс — до наборов: задача, все строки которой класса B, не параллелится ни при каких
  # файлах (ADR-082 §1), и отвечать про неё «набор пуст» было бы ответом не на тот вопрос.
  cls=$(class_of "$t")
  [ -n "$cls" ] || cls="не установлен по 07_STATE"
  case "$cls" in
    *A*) : ;;                                  # есть хотя бы один шаг класса A — разбираем файлы
    *B*) printf '== %s: класс %s ==\nКЛАСС B НЕ ПАРАЛЛЕЛИТСЯ НИКОГДА (ADR-082 §1)\n' "$t" "$cls"
         echo "== вердикт =="
         echo "ПАРАЛЛЕЛЬ ЗАПРЕЩЕНА: $t есть задача класса B (ADR-082 §1). Запускать по одной."
         exit 1 ;;
  esac
  case "$cls" in
    *A*B*|*B*A*) printf '== %s: ВНИМАНИЕ, класс смешанный (%s) ==\nПараллель допустима ТОЛЬКО для шагов класса A; шаги класса B не параллелятся (ADR-082 §1).\n\n' "$t" "$cls" ;;
  esac

  set +e; out=$(extract_brief "$t"); rc=$?; set -e
  if [ $rc -eq 4 ]; then
    echo "ПРОВЕРКА: в briefs/$t.md нет поля «Файлы на запись» — это ОТКАЗ, не пустой набор" >&2; exit 3
  elif [ $rc -eq 0 ]; then
    src="briefs/$t.md"
  else
    set +e; raw=$(extract_state "$t"); rc2=$?; set -e
    if [ $rc2 -ne 0 ]; then
      echo "ПРОВЕРКА: у $t нет ни briefs/$t.md, ни строк в 07_STATE §Мандат — ОТКАЗ (ADR-102)" >&2; exit 3
    fi
    out=$(printf '%s\n' "$raw" | awk -F'\t' '$1=="PATH"{print $2}')
    src="07_STATE §Мандат (задача без брифа, ADR-086 §1)"
  fi

  # подстановка плейсхолдеров: <TASK> раскрывается в имя задачи, иначе любые две задачи
  # ложно пересекались бы на общем шаблоне reference/_scratch_<TASK>_<date>/
  out=$(printf '%s\n' "$out" | sed "s#<TASK>#$t#g")

  n=$(printf '%s' "$out" | grep -c . || true)
  if [ "$n" -eq 0 ]; then
    echo "ПРОВЕРКА: у $t источник найден ($src), но набор пуст — ОТКАЗ (ADR-021 §2)" >&2; exit 3
  fi

  printf '== %s: %s путей · класс %s · источник: %s ==\n%s\n\n' "$t" "$n" "$cls" "$src" "$out"
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
if [ "$fail" -eq 0 ]; then echo "ПАРАЛЛЕЛЬ ДОПУСТИМА по файлам и по классу"; exit 0
else echo "ПАРАЛЛЕЛЬ ЗАПРЕЩЕНА: пересечение наборов либо класс B (ADR-082 §1). Запускать по одной."; exit 1; fi
