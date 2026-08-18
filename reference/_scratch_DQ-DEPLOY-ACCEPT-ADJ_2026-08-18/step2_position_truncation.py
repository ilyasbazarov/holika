# Ступень 3 различителя (класс A, локально): проверка механизма b1 — потеря позиций
# выгрузкой из-за постраничного предела. Вход — архив сырого ответа источника,
# уже закоммиченный сессией 2026-08-12. Облачных вызовов нет.
import json, collections, hashlib, csv, sys
base = "reference/_scratch_SALES-REFRESH-WINDOW-DELETE-DISCRIMINATE_2026-08-12"
rows = [json.loads(l) for l in open(f"{base}/archive_106b.ndjson", encoding="utf-8")]
print("записей архива:", len(rows))
per = collections.Counter(r["demand_id"] for r in rows)
print("уникальных документов:", len(per))
cnt = collections.Counter(per.values())
print("максимум позиций в одном документе:", max(per.values()))
print("документов ровно со 100 позициями:", cnt.get(100, 0))
print("документов с 99..101 позициями:", sum(cnt.get(k, 0) for k in (99, 100, 101)))
print("документов с числом позиций > 100:", sum(v for k, v in cnt.items() if k > 100))
print("распределение (топ-10 по размеру документа):")
for n in sorted(cnt, reverse=True)[:10]:
    print(f"   {n} позиций — документов: {cnt[n]}")
d29 = list(csv.DictReader(open(f"{base}/deleted_29.csv", encoding="utf-8")))
hashes = {hashlib.md5(f'{r["demand_id"]}|{r["position_id"]}'.encode()).hexdigest() for r in rows}
print("контроль ступени 1 (из 29 найдено в архиве):", sum(1 for r in d29 if r["transaction_id"] in hashes))
print("уникальных пар дата+контрагент среди 29:", len({(r["date"], r["agent_id"]) for r in d29}))
