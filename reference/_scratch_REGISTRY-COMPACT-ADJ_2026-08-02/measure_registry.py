#!/usr/bin/env python3
# Провенанс замера REGISTRY-COMPACT-ADJ (2026-08-02). Запуск из корня рабочего дерева:
#   python3 reference/_scratch_REGISTRY-COMPACT-ADJ_2026-08-02/measure_registry.py
import re
from collections import Counter

lines = open('07_STATE.md').read().split('\n')
txt = '\n'.join(lines)
st = [i for i, l in enumerate(lines, 1) if l.startswith('## Открытые вопросы')][0]
en = [i for i, l in enumerate(lines, 1) if l.startswith('## Контрольные цифры')][0] - 1
rows = [l for l in lines[st-1:en] if l.startswith('|') and not set(l) <= set('|- ')][1:]
cols = [[c.strip() for c in r.strip('|').split('|')] for r in rows]

print("== 1. МЕСТО РЕЕСТРА В ФАЙЛЕ ==")
print("07_STATE.md: %d симв.  реестр: %d симв. (%.1f%%), строк данных: %d"
      % (len(txt), sum(len(r) for r in rows), 100*sum(len(r) for r in rows)/len(txt), len(rows)))

print("\n== 2. ДОЛИ КОЛОНОК ==")
names = ['ID', 'Вопрос', 'Тип', 'Как закрывается']
w = [sum(len(c[i]) for c in cols if len(c) > i) for i in range(4)]
for n, x in zip(names, w):
    print("  %-18s %6d симв. %5.1f%%" % (n, x, 100*x/sum(w)))

print("\n== 3. ДЛИНА СТРОКИ ==")
ln = sorted(((len(r), c[0]) for r, c in zip(rows, cols)), reverse=True)
print("max %d (%s) · медиана %d · min %d" % (ln[0][0], ln[0][1], ln[len(ln)//2][0], ln[-1][0]))
big = [x for x, _ in ln if x > 1500]
print("строк длиннее 1500 симв.: %d (%d симв. = %.0f%% реестра)"
      % (len(big), sum(big), 100*sum(big)/sum(x for x, _ in ln)))

print("\n== 4. КОЛОНКА «КАК ЗАКРЫВАЕТСЯ» КАК ЖУРНАЛ ДОПИСОК ==")
APPEND = re.compile(r'Дописка|Дополнение|ВТОРОЙ ИНСТАНС|ТРЕТИЙ|ПЕРЕФОРМУЛИРОВАН|УТОЧНЕН|ПЕРЕСМОТРЕН'
                    r'|СУЖЕН|обновлено|superseded|Уточнение|Переклассифиц|ДОПОЛНЕНО|Правка ')
DATED = re.compile(r'20\d\d-\d\d-\d\d')
SRC = re.compile(r'reference/|ADR-\d+|briefs/')
k4 = [c[3] for c in cols if len(c) > 3]
tot4 = sum(len(k) for k in k4)
app = [k for k in k4 if APPEND.search(k)]
print("колонка целиком              : %d симв." % tot4)
print("строк с маркером дописки     : %d из %d, %d симв. (%.0f%% колонки)"
      % (len(app), len(k4), sum(len(k) for k in app), 100*sum(len(k) for k in app)/tot4))
print("строк с 2+ датами внутри     : %d" % sum(1 for k in k4 if len(DATED.findall(k)) >= 2))
print("строк со ссылкой ADR/артефакт: %d" % sum(1 for k in k4 if SRC.search(k)))

def status(k):
    h = k[:120].upper()
    for s in ['CLOSED', 'ЗАКРЫТ', 'ОТКРЫТ', 'DEFER', 'СУЖЕН', 'ПЕРЕФОРМУЛИРОВАН']:
        if s in h:
            return s
    return '(статус не назван в начале)'
c2, s2 = Counter(), Counter()
for k in k4:
    c2[status(k)] += 1
    s2[status(k)] += len(k)
print("\n== 5. НАЗВАН ЛИ СТАТУС В НАЧАЛЕ КОЛОНКИ ==")
for k in sorted(s2, key=lambda x: -s2[x]):
    print("  %-28s %2d строк %6d симв." % (k, c2[k], s2[k]))

print("\n== 6. КОЛОНКА «ТИП» КАК КЛАССИФИКАТОР ==")
t = Counter(c[2] for c in cols if len(c) > 2)
print("различных значений: %d на %d строк; встречается однажды: %d значений"
      % (len(t), len(rows), sum(1 for v in t.values() if v == 1)))

print("\n== 7. СМЕТА ИНДЕКСА (вариант C) ==")
def clean(s):
    return re.sub(r'[*`]', '', re.sub(r'\(.*?\)', '', s)).strip()
idx = sum(len("| %s | OPEN | %s | гейт |" % (c[0], clean(c[1])[:90])) + 1 for c in cols)
save = sum(len(r) for r in rows) - idx
print("индекс (ID + статус + 90 симв. вопроса + признак гейта): %d симв." % idx)
print("экономия в 07_STATE: %d симв.; файл %d → %d (−%.0f%%)"
      % (save, len(txt), len(txt) - save, 100*save/len(txt)))
