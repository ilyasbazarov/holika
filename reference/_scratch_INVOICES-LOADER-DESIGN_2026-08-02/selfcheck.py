import re,sys
t=open(sys.argv[1],encoding='utf-8').read()
sql=re.search(r'```sql\nMERGE `msklad-bi-prod\.core\.fact_customer_invoices` T.*?\n```', t, re.S).group(0)
code=[l for l in sql.split('\n') if not l.strip().startswith('--')]
bad=[l for l in code if 'INSERT ROW' in l]
print("V1. строки исполнимого SQL с 'INSERT ROW':", bad if bad else "НЕТ НИ ОДНОЙ")
print("    (совпадения в файле — цитаты запрета: комментарий SQL, проза §7.5, чек-лист §13)")
print()
print("V2. Пересчёт колонок")
upd=re.search(r'WHEN MATCHED THEN UPDATE SET(.*?)\n\n', sql, re.S).group(1)
upd_cols=re.findall(r'^\s*T\.(\w+)\s*=\s*S\.(\w+),?\s*$', upd, re.M)
ins=re.search(r'WHEN NOT MATCHED BY TARGET THEN INSERT \((.*?)\n\) VALUES \((.*?)\n\)', sql, re.S)
cols=[c.strip() for c in ins.group(1).split(',') if c.strip()]
vals=[v.strip() for v in ins.group(2).split(',') if v.strip()]
mism=[(c,v) for c,v in zip(cols,vals) if 'S.'+c!=v]
live=['invoice_id','invoice_name','moment','agent_id','agent_name','state_id','state_name','sum_kgs','payed_sum_kgs','unpaid_sum_kgs','payment_planned','sales_channel_id','sales_channel_name','_loaded_at']
zone="'Asia/Bishkek'"
print("    UPDATE SET присваиваний:", len(upd_cols))
print("    INSERT имён колонок:    ", len(cols))
print("    VALUES значений:        ", len(vals))
print("    INSERT[i] <-> VALUES[i]:", "полное соответствие" if not mism else mism)
print("    во всех UPDATE T.X = S.X:", "да" if all(a==b for a,b in upd_cols) else [p for p in upd_cols if p[0]!=p[1]])
print("    живая схема core (14) == INSERT-набор:", "ДА" if sorted(live)==sorted(cols) else "НЕТ: "+str(set(live)^set(cols)))
print("    UPDATE-набор == схема минус ключ invoice_id:", "ДА" if sorted(a for a,_ in upd_cols)==sorted(c for c in live if c!='invoice_id') else "НЕТ")
print("    T.moment (дефект ADR-100 §2) в UPDATE SET:", "ДА" if 'moment' in [a for a,_ in upd_cols] else "НЕТ")
print("    ветка удаления (C2 / ADR-100 §1):", "ДА" if 'WHEN NOT MATCHED BY SOURCE THEN DELETE' in sql else "НЕТ")
on=sql.split('WHEN MATCHED')[0]
print("    окно/DATE_SUB в ON (ловушка ADR-100 §7 ii):", "ЕСТЬ — ДЕФЕКТ" if 'DATE_SUB' in on else "НЕТ — верно")
print("    правило суток в USING, вхождений зоны:", sql.count(zone))
code_only="\n".join(code)
print("    срез moment_raw[:10] в ИСПОЛНИМОМ SQL (дефект ADR-088 §4):", "ЕСТЬ" if '[:10]' in code_only else "НЕТ — верно (единственное вхождение — комментарий-запрет)")
print("    вхождений зоны в исполнимом SQL:", code_only.count(zone))
