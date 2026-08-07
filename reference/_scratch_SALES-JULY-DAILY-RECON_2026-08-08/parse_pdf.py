import re, sys
from collections import defaultdict

fname = "reference/_scratch_SALES-JULY-DAILY-RECON_2026-08-08/pdf_pages_1-7.txt"
lines = open(fname, encoding="utf-8").read().splitlines()

row_re = re.compile(
    r'^(?P<name>.+?)\s{2,}(?P<doctype>Отгрузка|Возврат покупателя)\s+(?P<num>\S+)\s+(?P<date>\d{2}\.\d{2}\.\d{4})\s+(?P<time>\d{2}:\d{2}:\d{2})\s+(?P<sum>[\d\s]+,\d{2})\s*$'
)

rows = []
unmatched = []
for ln in lines:
    if not ln.strip():
        continue
    m = row_re.match(ln)
    if m:
        d = m.groupdict()
        s = d['sum'].replace(' ', '').replace(',', '.')
        rows.append({
            'name': d['name'].strip(),
            'doctype': d['doctype'],
            'num': d['num'],
            'date': d['date'],
            'time': d['time'],
            'sum': float(s),
        })
    else:
        # skip header/footer lines
        if re.search(r'\d{2}\.\d{2}\.\d{4}', ln) and ('Отгрузка' in ln or 'Возврат' in ln):
            unmatched.append(ln)

print(f"Всего распознано строк: {len(rows)}")
print(f"Не распознано (похоже на строку данных, но не сматчилось): {len(unmatched)}")
for u in unmatched:
    print("UNMATCHED:", repr(u))

shipments = [r for r in rows if r['doctype'] == 'Отгрузка']
returns = [r for r in rows if r['doctype'] == 'Возврат покупателя']
print(f"Отгрузок: {len(shipments)}")
print(f"Возвратов: {len(returns)}")
print(f"Сумма отгрузок: {sum(r['sum'] for r in shipments):.2f}")
print(f"Сумма возвратов: {sum(r['sum'] for r in returns):.2f}")

for r in returns:
    print("RETURN:", r)

# Daily series in UTC: date.time is UTC+3 per ADR-137 §3. Subtract 3 hours, take UTC date.
from datetime import datetime, timedelta

daily = defaultdict(lambda: {'n': 0, 'sum': 0.0})
for r in shipments:
    dt = datetime.strptime(r['date'] + ' ' + r['time'], '%d.%m.%Y %H:%M:%S')
    dt_utc = dt - timedelta(hours=3)
    key = dt_utc.strftime('%Y-%m-%d')
    daily[key]['n'] += 1
    daily[key]['sum'] += r['sum']

print("\nDaily (UTC transaction_date) shipments only:")
for k in sorted(daily.keys()):
    print(f"{k}\t{daily[k]['n']}\t{daily[k]['sum']:.4f}")

print(f"\nTotal daily n={sum(v['n'] for v in daily.values())} sum={sum(v['sum'] for v in daily.values()):.2f}")
