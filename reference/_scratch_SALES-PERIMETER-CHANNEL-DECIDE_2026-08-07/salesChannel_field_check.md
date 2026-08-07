# Проверка поля salesChannel — офлайн, без живого GET

Шаг 1 задачи `SALES-PERIMETER-CHANNEL-DECIDE` (`07_GAPS.md:87`).

## entity/retaildemand

Дамп: `reference/_scratch_PARITY-SALES-DISCRIMINATE-2NDSTEP_2026-08-02/retaildemand_page_0.json`
(100 строк, `rows[]`).

```
python3 -c "
import json
d = json.load(open('reference/_scratch_PARITY-SALES-DISCRIMINATE-2NDSTEP_2026-08-02/retaildemand_page_0.json'))
print(sorted(d['rows'][0].keys()))
"
```

Ключи `rows[0]`:
```
['accountId', 'advancePaymentSum', 'agent', 'applicable', 'cashSum', 'cheque', 'created',
'externalCode', 'files', 'fiscal', 'group', 'id', 'meta', 'moment', 'name', 'noCashSum',
'organization', 'owner', 'payedSum', 'positions', 'prepaymentCashSum', 'prepaymentNoCashSum',
'prepaymentQrSum', 'printed', 'published', 'qrSum', 'rate', 'retailShift', 'retailStore',
'shared', 'state', 'store', 'sum', 'syncId', 'taxSystem', 'updated', 'vatEnabled', 'vatIncluded',
'vatSum']
```

`salesChannel` в списке ОТСУТСТВУЕТ. Сплошной `grep -in "saleschannel"` по файлу — 0 совпадений.
Это не `null`-значение поля, поле не приходит вовсе.

## entity/commissionreportin

Дамп: `reference/_scratch_SALES-PERIMETER-CONFIRM_2026-08-02/commissionreportin_may_page_0.json`
(7 строк, `rows[]`).

```
python3 -c "
import json
d = json.load(open('reference/_scratch_SALES-PERIMETER-CONFIRM_2026-08-02/commissionreportin_may_page_0.json'))
print(sorted(d['rows'][0].keys()))
"
```

Ключи `rows[0]` несут `salesChannel`. `grep -in "saleschannel"` даёт совпадения на всех 7 строках
выборки (ссылка `meta.href` на `entity/saleschannel/<uuid>`).

## Вывод

Поле различается по типу документа: у `retaildemand` его физически нет в ответе, у
`commissionreportin` — есть на 100% выборки. Развилка (07_STATE.md, «Развилки на владельце»)
снята владельцем в чате 2026-08-07: константа-метка типа документа для ОБОИХ типов
(«Розница» / «Комиссия»), реальный `salesChannel` из `commissionreportin` не читается.
