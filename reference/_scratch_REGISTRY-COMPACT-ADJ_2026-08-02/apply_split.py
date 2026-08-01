#!/usr/bin/env python3
"""Разрез GAP-реестра на индекс (07_STATE) и полный текст (07_GAPS.md). ADR-0NN §1/§2, вариант C.

Применяется ИМЕНОВАННЫМ коммитом того же прохода, СРАЗУ ПОСЛЕ коммита сборки (ADR-0NN §7/§8).
Форма коммита — прецедент 519e71d, пришедший следом за 9461bf5. Порядок обязателен: строку
REGISTRY-COLUMN-SPLIT в реестр заводит коммит сборки, и без неё скрипт откажет по расхождению
множеств ID.
    python3 reference/_scratch_REGISTRY-COMPACT-ADJ_2026-08-02/apply_split.py --check
    python3 reference/_scratch_REGISTRY-COMPACT-ADJ_2026-08-02/apply_split.py --apply

Переезд ДОСЛОВНЫЙ: все 62 строки уходят в 07_GAPS.md байт в байт. Индекс — НОВЫЙ текст,
добавляемый поверх, а не замена содержания: оригинал сохраняется целиком, поэтому неточная
формулировка индекса материала не теряет и правится без археологии.

Отказ (RC 2), если: 07_STATE.md изменён относительно базы · множества ID индекса и реестра
не совпадают · порядок ID разошёлся · 07_GAPS.md уже существует.
"""
import sys, os, re, subprocess

BASE_SHA   = "519e71de958652b5508bdaabe3272af2bf950324"   # база, на которой снят индекс
ROWHASH = "row_hashes.tsv"                                # ID -> sha256 строки на момент снимка
HERE = os.path.dirname(os.path.abspath(__file__))
MODE = sys.argv[1] if len(sys.argv) > 1 else "--check"
if MODE not in ("--check", "--apply"):
    print("неизвестный режим: %s" % MODE); sys.exit(2)

# Предохранитель привязан к СТРОКАМ РЕЕСТРА, а не к blob всего 07_STATE.md: между снимком
# индекса и применением файл законно правит проход сборки (абзац деталей, шапка, новая строка
# задачи). Хэш всего файла ловил бы эти правки как порчу и делал скрипт неприменимым в реальном
# порядке работ. Проверяется то, что действительно обязано быть неизменным: дословный текст
# каждой снятой строки. Строка, добавленная ПОСЛЕ снимка, допускается, но обязана быть в индексе
# и печатается отдельной строкой отчёта — молчаливого расширения набора нет.

lines = open("07_STATE.md").read().split("\n")
st = [i for i, l in enumerate(lines, 1) if l.startswith("## Открытые вопросы")][0]
en = [i for i, l in enumerate(lines, 1) if l.startswith("## Контрольные цифры")][0] - 1
tbl = [(i, l) for i, l in enumerate(lines[st-1:en], start=st) if l.startswith("|")]
head_i, sep_i = tbl[0][0], tbl[1][0]
rows = [(i, l) for i, l in tbl[2:] if not set(l) <= set("|- ")]
reg_ids = [l.strip("|").split("|")[0].strip().strip("`") for _, l in rows]

import hashlib
want = {}
for ln in open(os.path.join(HERE, ROWHASH)):
    if ln.strip():
        k, v = ln.rstrip("\n").split("\t")
        want[k] = v
changed, added = [], []
for _, l in rows:
    rid = l.strip("|").split("|")[0].strip().strip("`")
    h = hashlib.sha256(l.encode()).hexdigest()
    if rid not in want:
        added.append(rid)
    elif want[rid] != h:
        changed.append(rid)
missing = [k for k in want if k not in reg_ids]
if changed or missing:
    print("ОТКАЗ: строки реестра изменились после снимка индекса (база %s)." % BASE_SHA[:7])
    if changed: print("  текст изменён: %s" % " ".join(changed))
    if missing: print("  строка исчезла: %s" % " ".join(missing))
    print("Пересними индекс — он описывает уже не то, что лежит в файле."); sys.exit(2)
if added:
    print("строки, добавленные после снимка (допустимо, обязаны быть в индексе): %s" % " ".join(added))

idx_all = [l.rstrip("\n") for l in open(os.path.join(HERE, "index_draft.md")) if l.startswith("| `")]
idx_ids = [l.strip("|").split("|")[0].strip().strip("` ") for l in idx_all]

if set(idx_ids) != set(reg_ids):
    print("ОТКАЗ: множества ID расходятся.")
    print("  нет в индексе: %s" % [i for i in reg_ids if i not in idx_ids])
    print("  лишние       : %s" % [i for i in idx_ids if i not in reg_ids]); sys.exit(2)
if idx_ids != reg_ids:
    print("ОТКАЗ: порядок ID индекса не совпадает с реестром."); sys.exit(2)

reg_chars = sum(len(l) for _, l in rows)
idx_chars = sum(len(l) for l in idx_all)
txt = "\n".join(lines)

INDEX_HEAD = [
    "| ID | Статус | Вопрос | Гейт |",
    "|---|---|---|---|",
]
# старая врезка раздела заменяется целиком: она перечисляет статусы «IN PROGRESS / READY»,
# которых нет в закрытом словаре §2, то есть оставленная — противоречила бы новому правилу
NOTE = [
    "> **Индекс, не реестр (`ADR-0NN §1`).** Полный текст всех строк — `07_GAPS.md`, читается",
    "> ТОЧЕЧНО по ID (приём `ADR-064`, как `06_INDEX` против `06_DECISIONS_LOG`). Здесь — только",
    "> `ID · статус · вопрос одной фразой · гейт`. Словарь статусов закрытый: `OPEN` (открыт, работа",
    "> не назначена либо идёт) · `READY` (исполнимо сейчас, форма задана) · `DEFER` (отложен, триггер",
    "> назван) · `PARTIAL` (частично закрыт, остаток назван). Новая строка заводится В ОБА файла",
    "> одним коммитом; полностью закрытая строка уезжает из `07_GAPS.md` в `07_ARCHIVE.md`",
    "> дословно (`ADR-064`), и тем же коммитом снимается её строка отсюда. Расхождение множеств",
    "> ID между этим индексом и `07_GAPS.md` валит хук.",
    "",
]
new_block = NOTE + INDEX_HEAD + idx_all
new_lines = lines[:st] + [""] + new_block + lines[rows[-1][0]:]   # st = строка заголовка раздела
new_txt = "\n".join(new_lines)

print("база: %s" % BASE_SHA)
print("строк реестра: %d, строк индекса: %d, ID совпадают и порядок сохранён" % (len(rows), len(idx_all)))
print()
print("реестр в 07_STATE : %d → %d симв. (−%d)" % (reg_chars, idx_chars, reg_chars - idx_chars))
print("07_STATE.md       : %d → %d симв. (−%d, −%.1f%%)"
      % (len(txt), len(new_txt), len(txt) - len(new_txt), 100*(len(txt)-len(new_txt))/len(txt)))
print("07_GAPS.md        : новый файл, %d строк дословно" % len(rows))
print("доля реестра в файле: %.1f%% → %.1f%%"
      % (100*reg_chars/len(txt), 100*idx_chars/len(new_txt)))

if MODE == "--check":
    print("\nрежим --check: файлы не тронуты."); sys.exit(0)

if os.path.exists("07_GAPS.md"):
    print("ОТКАЗ: 07_GAPS.md уже существует — повторное применение запрещено."); sys.exit(2)

gaps = [
    "# FILE: 07_GAPS.md",
    "",
    "# 07_GAPS · GAP-реестр discovery-петли — полный текст строк",
    "",
    "**Статус:** LIVING · **Заведён:** `ADR-0NN §1` (2026-08-02), перенос из `07_STATE` ДОСЛОВНЫЙ.",
    "",
    "> Индекс этих же строк (`ID · статус · вопрос одной фразой · гейт`) живёт в",
    "> `07_STATE §Открытые вопросы` и входит в обязательный контекст сессии. Этот файл читается",
    "> ТОЧЕЧНО по ID и в обязательный контекст НЕ входит (приём `ADR-064`).",
    "> Новая строка заводится в ОБА файла одним коммитом. Полностью закрытая строка уезжает",
    "> отсюда в `07_ARCHIVE.md` дословно, и тем же коммитом снимается её строка индекса.",
    "",
    "---",
    "",
    lines[head_i-1],
    lines[sep_i-1],
]
gaps += [l for _, l in rows]
gaps += ["", "--- END 07_GAPS.md ---", ""]
open("07_GAPS.md", "w").write("\n".join(gaps))
open("07_STATE.md", "w").write(new_txt)
print("\nПРИМЕНЕНО: заведён 07_GAPS.md, реестр в 07_STATE.md заменён индексом.")
