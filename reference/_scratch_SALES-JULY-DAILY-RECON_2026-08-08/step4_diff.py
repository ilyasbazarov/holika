import re, json
from decimal import Decimal
from datetime import datetime, timedelta
from collections import defaultdict

fname = "reference/_scratch_SALES-JULY-DAILY-RECON_2026-08-08/pdf_pages_1-7.txt"
lines = open(fname, encoding="utf-8").read().splitlines()

row_re = re.compile(
    r'^(?P<name>.+?)\s{2,}(?P<doctype>Отгрузка|Возврат покупателя)\s+(?P<num>\S+)\s+(?P<date>\d{2}\.\d{2}\.\d{4})\s+(?P<time>\d{2}:\d{2}:\d{2})\s+(?P<sum>[\d\s]+,\d{2})\s*$'
)

rows = []
for ln in lines:
    m = row_re.match(ln)
    if m:
        d = m.groupdict()
        s = Decimal(d['sum'].replace(' ', '').replace(',', '.'))
        rows.append({'name': d['name'].strip(), 'doctype': d['doctype'], 'num': d['num'],
                     'date': d['date'], 'time': d['time'], 'sum': s})

shipments = [r for r in rows if r['doctype'] == 'Отгрузка']

pdf_daily = defaultdict(lambda: {'n': 0, 'sum': Decimal('0'), 'docs': []})
for r in shipments:
    dt = datetime.strptime(r['date'] + ' ' + r['time'], '%d.%m.%Y %H:%M:%S')
    dt_utc = dt - timedelta(hours=3)
    key = dt_utc.strftime('%Y-%m-%d')
    pdf_daily[key]['n'] += 1
    pdf_daily[key]['sum'] += r['sum']
    pdf_daily[key]['docs'].append((r['num'], r['sum']))

# our side, from step3_run.log
our_raw = json.load(open("reference/_scratch_SALES-JULY-DAILY-RECON_2026-08-08/step3_our.json"))
our_daily = {}
for row in our_raw:
    our_daily[row['transaction_date']] = {'n': int(row['n_rows']), 'sum': Decimal(str(row['sum_revenue_kgs']))}

all_dates = sorted(set(list(pdf_daily.keys()) + list(our_daily.keys())))

print(f"{'date':12}{'pdf_n':>8}{'pdf_sum':>16}{'our_n':>8}{'our_sum':>16}{'diff(our-pdf)':>16}")
total_diff = Decimal('0')
total_pdf_n = 0
total_our_n = 0
total_pdf_sum = Decimal('0')
total_our_sum = Decimal('0')
diffs = []
for d in all_dates:
    p = pdf_daily.get(d, {'n':0,'sum':Decimal('0'),'docs':[]})
    o = our_daily.get(d, {'n':0,'sum':Decimal('0')})
    diff = o['sum'] - p['sum']
    total_diff += diff
    total_pdf_n += p['n']; total_our_n += o['n']
    total_pdf_sum += p['sum']; total_our_sum += o['sum']
    diffs.append((d, diff, p, o))
    print(f"{d:12}{p['n']:>8}{str(p['sum']):>16}{o['n']:>8}{str(o['sum']):>16}{str(diff):>16}")

print(f"\nTOTAL pdf_n={total_pdf_n} pdf_sum={total_pdf_sum} our_n={total_our_n} our_sum={total_our_sum} diff={total_diff}")

print("\nTop absolute diffs:")
for d, diff, p, o in sorted(diffs, key=lambda x: -abs(x[1]))[:10]:
    print(d, diff, "pdf_docs:", p['docs'] if abs(diff) > 1 else '')
