#!/usr/bin/env python3
"""Механический перенос абзацев 07_STATE §Подробности для модели в 07_ARCHIVE.

Применяется ПРОХОДОМ СБОРКИ, не сессией (CLAUDE.md §Конец сессии: 07_STATE правит сборка).
Запуск из корня рабочего дерева:
    python3 reference/_scratch_STATE-DETAILS-ADJ_2026-08-02/apply_evict.py --check   # только проверка
    python3 reference/_scratch_STATE-DETAILS-ADJ_2026-08-02/apply_evict.py --apply   # правит файлы

Вход: evict_list.tsv рядом со скриптом (start<TAB>end<TAB>основание<TAB>пояснение),
      номера строк — по базе BASE_SHA.
Скрипт ОТКАЗЫВАЕТ (RC 2), если:
  - HEAD не равен BASE_SHA (номера строк протухли);
  - диапазон не является ровно одним абзацем (границы не пустые строки);
  - в 07_ARCHIVE.md уже есть целевой раздел с непустым телом при --apply.
Перенос ДОСЛОВНЫЙ: ни один символ переносимого текста не меняется (ADR-064).
"""
import sys, os, re, subprocess

# Привязка к СОДЕРЖИМОМУ 07_STATE.md, а не к HEAD: номера строк зависят от файла,
# а HEAD двигают любые посторонние коммиты (в т.ч. коммит самой этой сессии).
BASE_SHA = "7dc7d99982e41663db05a746f2fce1bd4c5e79a0"   # база, на которой сняты номера строк
STATE_BLOB = "e102d2eec4a7e6452de9aa2c1c48b144efb08017"  # git hash-object 07_STATE.md, подставляется ниже
SEC = "## Подробности для модели — снятые абзацы (полный текст)"
HERE = os.path.dirname(os.path.abspath(__file__))
MODE = sys.argv[1] if len(sys.argv) > 1 else "--check"

blob = subprocess.run(["git", "hash-object", "07_STATE.md"], capture_output=True, text=True).stdout.strip()
if blob != STATE_BLOB:
    print("ОТКАЗ: 07_STATE.md изменён (blob=%s, ожидался %s)." % (blob, STATE_BLOB))
    print("Номера строк списка сняты на базе %s и протухли — пересними список." % BASE_SHA[:7])
    sys.exit(2)

state = open("07_STATE.md").read().split("\n")
ranges = []
for ln in open(os.path.join(HERE, "evict_list.tsv")):
    if not ln.strip():
        continue
    a, b, why, note = ln.rstrip("\n").split("\t")
    ranges.append((int(a), int(b), why, note))

# --- проверка границ: диапазон обязан быть ровно одним абзацем ---
bad = []
for a, b, _, _ in ranges:
    before = state[a - 2] if a >= 2 else ""
    after = state[b] if b < len(state) else ""
    if before.strip() != "" or after.strip() != "":
        bad.append((a, b, repr(before[:40]), repr(after[:40])))
if bad:
    print("ОТКАЗ: %d диапазонов не являются целым абзацем:" % len(bad))
    for x in bad:
        print("  стр.%d-%d  до=%s  после=%s" % x)
    sys.exit(2)

# --- пересечения ---
flat = sorted((a, b) for a, b, _, _ in ranges)
for i in range(1, len(flat)):
    if flat[i][0] <= flat[i - 1][1]:
        print("ОТКАЗ: диапазоны пересекаются: %s и %s" % (flat[i - 1], flat[i]))
        sys.exit(2)

evicted = set()
for a, b, _, _ in ranges:
    evicted.update(range(a, b + 1))

blocks = [(a, b, why, note, "\n".join(state[a - 1:b])) for a, b, why, note in ranges]
moved_chars = sum(len(t) for *_, t in blocks)

# новый 07_STATE: убираем строки абзаца И одну пустую строку-разделитель после него
drop = set(evicted)
for a, b, _, _ in ranges:
    if b < len(state) and state[b].strip() == "":
        drop.add(b + 1)
new_state = [l for i, l in enumerate(state, start=1) if i not in drop]

sec_lo, sec_hi = 27, 414
old_sec = "\n".join(state[sec_lo - 1:sec_hi])
new_sec_lines = [l for i, l in enumerate(state[sec_lo - 1:sec_hi], start=sec_lo) if i not in drop]
new_sec = "\n".join(new_sec_lines)

print("база: %s" % BASE_SHA)
print("абзацев к переносу: %d (строк: %d)" % (len(ranges), len(evicted)))
print()
print("07_STATE.md целиком : %d → %d симв. (−%d, −%.1f%%)"
      % (len("\n".join(state)), len("\n".join(new_state)),
         len("\n".join(state)) - len("\n".join(new_state)),
         100 * (len("\n".join(state)) - len("\n".join(new_state))) / len("\n".join(state))))
print("§Подробности       : %d → %d симв. (−%d, −%.1f%%)"
      % (len(old_sec), len(new_sec), len(old_sec) - len(new_sec),
         100 * (len(old_sec) - len(new_sec)) / len(old_sec)))
# одно окно на оба счёта: тело раздела без заголовка, врезки и хвостового ---
def _count(lines_slice, skip):
    body = "\n".join(l for i, l in enumerate(lines_slice, start=30) if i not in skip)
    return len([p for p in re.split(r"\n\s*\n", body) if p.strip() and p.strip() != "---"])
n_before = _count(state[29:412], set())
n_after = _count(state[29:412], drop)
print("абзацев в разделе   : %d → %d" % (n_before, n_after))
print("переносится дословно: %d симв." % moved_chars)

by = {}
for a, b, why, _, t in [(a, b, w, n, t) for (a, b, w, n, t) in blocks]:
    by.setdefault(why, [0, 0])
    by[why][0] += 1
    by[why][1] += len(t)
print()
for w in sorted(by):
    print("  %-22s %2d абз. %6d симв." % (w, by[w][0], by[w][1]))

if MODE == "--check":
    print("\nрежим --check: файлы не тронуты.")
    sys.exit(0)

if MODE != "--apply":
    print("неизвестный режим: %s" % MODE)
    sys.exit(2)

arch = open("07_ARCHIVE.md").read()
if SEC in arch:
    print("ОТКАЗ: раздел уже есть в 07_ARCHIVE.md — повторное применение запрещено.")
    sys.exit(2)

parts = [SEC, "",
         "> Абзацы `07_STATE §Подробности для модели`, снятые по правилу вытеснения "
         "(перенос ДОСЛОВНЫЙ). Порядок — как в `07_STATE` на момент снятия; "
         "у каждого назван номер строки базы и основание.", ""]
for a, b, why, note, text in blocks:
    parts.append("**[снято %s · база `%s` стр.%d%s · основание: %s]** %s"
                 % ("2026-08-02", BASE_SHA[:7], a, ("-%d" % b) if b != a else "", why, note))
    parts.append("")
    parts.append(text)
    parts.append("")
open("07_ARCHIVE.md", "w").write(arch.rstrip("\n") + "\n\n" + "\n".join(parts).rstrip("\n") + "\n")
open("07_STATE.md", "w").write("\n".join(new_state))
print("\nПРИМЕНЕНО: 07_STATE.md и 07_ARCHIVE.md переписаны.")
