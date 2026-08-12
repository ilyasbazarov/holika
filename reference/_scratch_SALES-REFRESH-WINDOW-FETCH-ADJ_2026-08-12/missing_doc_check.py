#!/usr/bin/env python3
"""SALES-REFRESH-WINDOW-FETCH-ADJ — проверка того, что пропал ДОКУМЕНТ целиком.
Read-only по локальному архиву источника, облачных вызовов нет."""
import json, datetime
from collections import Counter, defaultdict
A = ("../../reference/_scratch_SALES-REFRESH-WINDOW-DELETE-DISCRIMINATE_2026-08-12/"
     "archive_106b.ndjson")
recs = [json.loads(l) for l in open(A) if l.strip()]
DOC = "4ec09bec-4df8-11f1-0a80-1c8a0053cab5"      # документ «04235», жив в источнике
AG  = "31d135bc-4df8-11f1-0a80-1c8a0053c5b4"      # К Глобал РФ Маркетплейсы

def bish(raw):                                     # правило суток ADR-088: UTC + 6ч
    dt = datetime.datetime.strptime(raw[:19], "%Y-%m-%d %H:%M:%S")
    return (dt + datetime.timedelta(hours=6)).date()

print(f"записей в архиве: {len(recs)}, документов: {len({r['demand_id'] for r in recs})}")
print(f"записей с demand_id пропавшего документа : {sum(1 for r in recs if r['demand_id']==DOC)}")
print(f"записей с agent_id за все 106 суток      : {sum(1 for r in recs if r['agent_id']==AG)}")
d = Counter(bish(r["transaction_date_raw"]) for r in recs)
print(f"сутки 2026-05-12 в архиве                : "
      f"{'ЕСТЬ, позиций ' + str(d[datetime.date(2026,5,12)]) if datetime.date(2026,5,12) in d else 'НЕТ'}")
print("\nвывод: не пропущенные сутки и не потеря позиций — документ не вернулся целиком")
