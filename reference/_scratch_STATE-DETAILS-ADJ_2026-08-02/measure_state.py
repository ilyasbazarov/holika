#!/usr/bin/env python3
# Провенанс замера STATE-DETAILS-ADJ (2026-08-02). Запуск из корня рабочего дерева:
#   python3 reference/_scratch_STATE-DETAILS-ADJ_2026-08-02/measure_state.py
# Все числа артефакта reference/state_details_bloat_adj_2026-08-02.md печатаются этим скриптом.
import re, subprocess
from collections import Counter

txt = open('07_STATE.md').read()
lines = txt.split('\n')

print("== 1. РАЗМЕР ФАЙЛА ==")
print("строк: %d  символов: %d  байт: %d" % (len(lines), len(txt), len(txt.encode())))

SEC = [(1,'шапка'),(15,'Текущий фокус'),(17,'Стенд-ап'),(27,'Подробности для модели'),
       (415,'Мандат'),(465,'Epic M'),(482,'Epic 1'),(491,'GAP-реестр'),
       (561,'Контрольные цифры'),(596,'Блокеры'),(606,'Артефакты-источники')]
print("\n== 2. ДОЛИ РАЗДЕЛОВ ==")
tot = len(txt)
for i,(st,name) in enumerate(SEC):
    en = SEC[i+1][0]-1 if i+1 < len(SEC) else len(lines)
    b = '\n'.join(lines[st-1:en])
    print("%-24s стр.%4d-%-4d %7d симв. %5.1f%%" % (name, st, en, len(b), 100*len(b)/tot))

body = '\n'.join(lines[29:412])
paras = [p for p in re.split(r'\n\s*\n', body) if p.strip() and p.strip() != '---']

def cls(t):
    h = t[:150]
    if re.search(r'Стенд-ап блока', h): return 'A. отброшенный стенд-ап другого блока'
    if re.search(r'Генерац(ия|ор)\b', h): return 'B. запись о генерации брифа'
    if re.search(r'Адъюдикация|Закрепление|Ревизия|Решения владельца', h): return 'C. адъюдикация / решение (есть ADR)'
    if re.search(r'[Пп]роцессное наблюдение|[Рр]етроспектива|[Вв]нимание для читателя', h): return 'D. процессное наблюдение'
    if re.search(r'Триаж|План последовательности|Волна|Риски|Механизм|Что это делает|Границы вывода|Blast radius|Дефект описания|Мандат класса|Факт, от которого|Решение уровня', h): return 'E. план / разбор (продолжение блока)'
    return 'F. ход задачи / замер'

c, sz = Counter(), Counter()
for p in paras: k = cls(p); c[k] += 1; sz[k] += len(p)
print("\n== 3. СОСТАВ «ПОДРОБНОСТЕЙ» (%d абзацев, %d симв.) ==" % (len(paras), sum(sz.values())))
for k in sorted(sz):
    print("%-40s %3d абз. %6d симв. %5.1f%%" % (k, c[k], sz[k], 100*sz[k]/sum(sz.values())))

print("\n== 4. УКАЗАТЕЛИ НА КАНОНИЧЕСКИЙ ИСТОЧНИК ==")
PAT = re.compile(r'reference/|ADR-\d+|07_ARCHIVE|briefs/')
print("со ссылкой на reference/... : %d/%d" % (sum(1 for p in paras if re.search(r'reference/[\w./-]+', p)), len(paras)))
print("со ссылкой на ADR-NNN       : %d/%d" % (sum(1 for p in paras if re.search(r'ADR-\d+', p)), len(paras)))
print("со ссылкой на архив/бриф    : %d/%d" % (sum(1 for p in paras if re.search(r'07_ARCHIVE|briefs/', p)), len(paras)))
print("без единого указателя       : %d/%d" % (sum(1 for p in paras if not PAT.search(p)), len(paras)))

print("\n== 5. ПРЕДМЕТ АБЗАЦА: ОТКРЫТО ИЛИ УЖЕ В АРХИВЕ (эвристика по ID в шапке) ==")
ar = open('07_ARCHIVE.md').read()
reg = '\n'.join(lines[490:560])
IDRE = re.compile(r'\b(Q-\d+|E1-[A-Z0-9-]+|M-P\d+|[A-Z][A-Z0-9]+(?:-[A-Z0-9]+){1,4})\b')
STOP = {'ADR','FILE','KGS','MD5','API','SQL','GET','BI','DONE','UTC','RC','STATE','CONTEXT','GAP'}
open_ids, arch_ids = set(IDRE.findall(reg)), set(IDRE.findall(ar))
cat, size = Counter(), Counter()
for p in paras:
    ids = {i for i in IDRE.findall(p[:170]) if i not in STOP and not i.startswith('ADR')}
    k = ('ID не опознан' if not ids else
         'есть в открытом реестре' if ids & open_ids else
         'только в архиве (закрыто)' if ids & arch_ids else 'ID не опознан')
    cat[k] += 1; size[k] += len(p)
for k in sorted(size):
    print("%-28s %3d абз. %6d симв. %5.1f%%" % (k, cat[k], size[k], 100*size[k]/sum(size.values())))

print("\n== 6. ДАТА В ШАПКЕ АБЗАЦА ==")
c2, s2 = Counter(), Counter()
for p in paras:
    d = re.findall(r'2026-0[78]-\d\d', p[:200])
    k = max(d) if d else 'без даты в шапке'
    c2[k] += 1; s2[k] += len(p)
for k in sorted(s2, reverse=True):
    print("%-18s %3d абз. %6d симв. %5.1f%%" % (k, c2[k], s2[k], 100*s2[k]/sum(s2.values())))

print("\n== 7. GAP-РЕЕСТР: РАСПРЕДЕЛЕНИЕ ДЛИН СТРОК ==")
rows = [l for l in lines[490:560] if l.startswith('|') and not set(l) <= set('|- ')]
ln = sorted((len(l) for l in rows), reverse=True)
print("строк: %d  суммарно: %d симв.  максимум: %d  медиана: %d" % (len(rows), sum(ln), ln[0], ln[len(ln)//2]))

print("\n== 8. РОСТ ПО КОММИТАМ (байт) ==")
shas = subprocess.run(['git','log','--format=%H','--reverse','--','07_STATE.md'],
                      capture_output=True, text=True).stdout.split()
for sha in shas:
    d = subprocess.run(['git','show','-s','--format=%ad','--date=short',sha], capture_output=True, text=True).stdout.strip()
    n = len(subprocess.run(['git','show',sha+':07_STATE.md'], capture_output=True).stdout)
    s = subprocess.run(['git','show','-s','--format=%s',sha], capture_output=True, text=True).stdout.strip()[:46]
    print("%s %7d  %s" % (d, n, s))
