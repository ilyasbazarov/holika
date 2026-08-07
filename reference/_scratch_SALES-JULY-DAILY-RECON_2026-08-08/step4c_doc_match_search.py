import re
from decimal import Decimal
from itertools import combinations

fname = "reference/_scratch_SALES-JULY-DAILY-RECON_2026-08-08/pdf_pages_1-7.txt"
lines = open(fname, encoding="utf-8").read().splitlines()
row_re = re.compile(
    r'^(?P<name>.+?)\s{2,}(?P<doctype>Отгрузка|Возврат покупателя)\s+(?P<num>\S+)\s+(?P<date>\d{2}\.\d{2}\.\d{4})\s+(?P<time>\d{2}:\d{2}:\d{2})\s+(?P<sum>[\d\s]+,\d{2})\s*$'
)
docs = []
for ln in lines:
    m = row_re.match(ln)
    if m:
        d = m.groupdict()
        s = Decimal(d['sum'].replace(' ', '').replace(',', '.'))
        if d['doctype'] == 'Отгрузка':
            docs.append((d['num'], d['date'], s))

targets = {
    '2026-07-20': Decimal('1457.3001'),
    '2026-07-21': Decimal('27019.2010'),
    '2026-07-27': Decimal('22543.9241'),
    '2026-07-29': Decimal('3833.9833'),
    '2026-07-30': Decimal('100601.9970'),
}

TOL = Decimal('0.05')

for date, target in targets.items():
    print(f"\n=== {date}: искомая разность = {target} ===")
    found_single = [d for d in docs if abs(d[2] - target) <= TOL]
    for f in found_single:
        print("  ОДИН документ совпал:", f)
    if not found_single:
        print("  Одиночных совпадений нет.")
    # pairs (limit search to avoid huge O(n^2) print spam; only report matches)
    matches = 0
    for a, b in combinations(docs, 2):
        if abs((a[2] + b[2]) - target) <= TOL:
            print("  ПАРА документов совпала:", a, b)
            matches += 1
            if matches >= 5:
                print("  ... (ограничение печати 5 совпадений)")
                break
    if matches == 0:
        print("  Пар из двух документов, дающих эту сумму, не найдено.")
