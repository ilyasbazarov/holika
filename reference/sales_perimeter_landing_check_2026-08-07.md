# FILE: sales_perimeter_landing_check_2026-08-07.md

**Задача:** `SALES-PERIMETER-LANDING-CHECK` (класс A, без брифа, `ADR-086 §1`).
**Провенанс:** `reference/_scratch_SALES-PERIMETER-LANDING-CHECK_2026-08-07/measure.sh` →
`reference/_scratch_SALES-PERIMETER-LANDING-CHECK_2026-08-07/run.log` (сырой вывод всех
шести запросов; UTC-якорь и подтверждение личности вызывающего в начале и в конце лога).

## Приёмка (дословно, `07_GAPS.md`, строка `SALES-PERIMETER-LANDING-CHECK`)

> Приёмка — артефакт `reference/sales_perimeter_landing_check_<date>.md`, несущий шесть
> измеренных величин с SQL и сырым выводом по каждой: (1) `MAX(_mart_refreshed_at)` в
> `marts.sales_overview` и `MAX(_loaded_at)` в `core.fact_sales_profit`; (2) `COUNT(*)` и
> `SUM(revenue_kgs)` за `2026-07-01…2026-07-31` в `core.fact_sales_profit`; (3) те же две
> величины за тот же период в `marts.sales_overview`; (4) помесячный разрез
> `COUNT(*)`/`SUM(revenue_kgs)` в `stg_msklad.fact_sales_perimeter_staging` по
> `DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek')` с
> разбивкой по `source_doc_type`; (5) разрез июля по `sales_channel_name` в
> `marts.sales_overview` — сколько суммы приходится на «Не указан»; (6) разрез июля по
> `manager_name` в `marts.sales_overview` — величина корзины сотрудника, названного
> клиентом. Вердикт артефакта — ровно один из двух: периметр доехал до июля (назвать
> величину прироста и назвать, какие из перечисленных гипотез он закрывает) либо не доехал
> (назвать, на каком слое обрывается: ядро / витрина / страница).

## Измерения

### (1) Окно наблюдения

```sql
SELECT
  (SELECT MAX(_mart_refreshed_at) FROM `msklad-bi-prod.marts.sales_overview`) AS mart_refreshed_at,
  (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_sales_profit`) AS core_loaded_at
```

```json
[{"core_loaded_at": "2026-08-07 12:05:50", "mart_refreshed_at": "2026-08-07 11:34:01"}]
```

Ядро загружено на 31 минуту позже последней пересборки витрины (витрина — `every 2 hours`,
`11_INFRA_FACTS.md:114`). Величины (2)/(3) сравниваются с учётом этого окна.

### (2) `core.fact_sales_profit`, июль-2026

```sql
SELECT COUNT(*) AS cnt, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
```

```json
[{"cnt": "4707", "sum_revenue_kgs": "1.125025818801E8"}]
```

### (3) `marts.sales_overview`, июль-2026

```sql
SELECT COUNT(*) AS cnt, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.marts.sales_overview`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
```

```json
[{"cnt": "4707", "sum_revenue_kgs": "1.125025819000001E8"}]
```

`cnt` совпадает точно (`4707` = `4707`); `sum_revenue_kgs` совпадает на уровне округления
(`112 502 581,8801` vs `112 502 581,9000001`, разница `0,02` KGS) — ядро и витрина видят
один и тот же июль.

### (4) `stg_msklad.fact_sales_perimeter_staging`, помесячный разрез по `source_doc_type`

```sql
SELECT
  FORMAT_DATE("%Y-%m", DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek")) AS month,
  source_doc_type, COUNT(*) AS cnt, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging`
GROUP BY month, source_doc_type
ORDER BY month, source_doc_type
```

```json
[
  {"cnt": "496",  "month": "2026-05", "source_doc_type": "commissionreportin_sale", "sum_revenue_kgs": "1760573.8800000008"},
  {"cnt": "1441", "month": "2026-05", "source_doc_type": "retaildemand",            "sum_revenue_kgs": "1188421.9999999995"},
  {"cnt": "1736", "month": "2026-06", "source_doc_type": "commissionreportin_sale", "sum_revenue_kgs": "6394683.369999989"},
  {"cnt": "1772", "month": "2026-07", "source_doc_type": "commissionreportin_sale", "sum_revenue_kgs": "3334723.580000003"},
  {"cnt": "22",   "month": "2026-08", "source_doc_type": "commissionreportin_sale", "sum_revenue_kgs": "24591.300000000003"}
]
```

Строки `commissionreportin_sale` идут непрерывно май → июнь → июль → август (частично,
проверка выполнена в середине августовских суток) — периметр не остановился на разовом
промоуте, продолжает пополняться штатным ходом. `retaildemand` присутствует только в мае —
это разовый охват первичного бэкафилла периметра, вне текущей проверки причина не
устанавливается (не входит в шесть измеряемых величин).

### (5) `marts.sales_overview`, июль-2026, разрез по `sales_channel_name`

```sql
SELECT sales_channel_name, COUNT(*) AS cnt, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.marts.sales_overview`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
GROUP BY sales_channel_name
ORDER BY sum_revenue_kgs DESC
```

```json
[
  {"cnt": "2895", "sales_channel_name": "Оптовая торговля", "sum_revenue_kgs": "1.0834633531999996E8"},
  {"cnt": "1812", "sales_channel_name": "Не указан",         "sum_revenue_kgs": "4156246.580000007"}
]
```

«Не указан» — `4 156 246,58` KGS из `112 502 581,90` KGS июля (`≈3,7 %`).

### (6) `marts.sales_overview`, июль-2026, разрез по `manager_name`

```sql
SELECT manager_name, COUNT(*) AS cnt, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.marts.sales_overview`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
GROUP BY manager_name
ORDER BY sum_revenue_kgs DESC
```

```json
[
  {"cnt": "2254", "manager_name": "Турдалиева А. М.",   "sum_revenue_kgs": "7.666554118999994E7"},
  {"cnt": "648",  "manager_name": "Турсунбекова М.",    "sum_revenue_kgs": "2.1303598380000003E7"},
  {"cnt": "1385", "manager_name": "Омурбекова Э. О.",   "sum_revenue_kgs": "1.1591560160000013E7"},
  {"cnt": "66",   "manager_name": null,                 "sum_revenue_kgs": "1964248.9000000001"},
  {"cnt": "337",  "manager_name": "Казакбаев Н. К.",    "sum_revenue_kgs": "623637.4599999998"},
  {"cnt": "14",   "manager_name": "Бейшеналиева К.",    "sum_revenue_kgs": "268909.5"},
  {"cnt": "3",    "manager_name": "Бактияр кызы Ч.",    "sum_revenue_kgs": "85086.31"}
]
```

Сотрудница, названная клиентом (`Q-78`/`ADR-127`, «отчёт МойСклада по Турдалиевой за
июль») — `Турдалиева А. М.`: `2254` строк, `76 665 541,19` KGS за июль на витрине.

## Вердикт

**Периметр доехал до июля-2026, до ядра и до витрины.** `core.fact_sales_profit` и
`marts.sales_overview` сходятся по июлю на уровне округления (`4707`=`4707` строк,
`112 502 581,88` vs `112 502 581,90` KGS), и питающая периметр стадийная таблица
(`stg_msklad.fact_sales_perimeter_staging`, `commissionreportin_sale`) показывает
непрерывный поток строк май→июнь→июль→август — промоут не был разовым провалившимся актом,
загрузка продолжает штатно пополнять июль и позже.

Это закрывает гипотезу «периметр застрял на бэкафилле и не идёт дальше промоута» — не
подтверждается: свежие июльские и августовские строки есть.

Это **не закрывает** и не адресует наблюдение владельца «прежняя картина расхождения» на
клиентской странице по конкретному сотруднику: атрибуция по `manager_name` на витрине идёт
через `dim_counterparties.owner_employee_id` (менеджера контрагента), а не через владельца
документа — тот же механизм, зафиксированный `ADR-127`/`ADR-128` и адресованный отдельной
задачей `SALES-DOCUMENT-OWNER-INGEST`/`SALES-DOCUMENT-OWNER-DEPLOY` (деплой ещё не
мандатирован, `07_GAPS.md` строка `SALES-DOCUMENT-OWNER-DEPLOY`, `OPEN`). Наблюдаемая
клиентом «прежняя картина» по сотруднику — ожидаемое следствие незавершённой второй
половины фикса, не признак того, что периметр не доехал.

Слой обрыва (если владелец имел в виду разрез по сотруднику, а не суммарный периметр) —
**клиентская страница/атрибуция**, а не ядро и не витрина в целом: суммарный периметр
(итоговая выручка) на витрине уже верен, разрез по сотруднику — ещё нет, до деплоя
`SALES-DOCUMENT-OWNER-DEPLOY`.
