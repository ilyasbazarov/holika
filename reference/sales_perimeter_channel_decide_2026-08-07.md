# SALES-PERIMETER-CHANNEL-DECIDE — подготовка (класс A), 2026-08-07

Задача: `07_GAPS.md:87`. Приёмка дословно:

> **READY.** Класс A (разбор и текст правки), деплой — класс B, мандат НЕ выдан, заводится по
> факту готовности правки. **Шаг 1 — различитель офлайн, живого `GET` НЕ требует:** несут ли
> `entity/retaildemand` и `entity/commissionreportin` поле `salesChannel` — проверяется по уже
> лежащему в репо дампу `retaildemand_page_0.json` (упомянут в `07_STATE.md:532`) и по ключам
> ответа, зафиксированным `reference/sales_perimeter_confirm_2026-08-02.md §6`; если дампа по
> `commissionreportin` в репо нет, это `CONTEXT GAP`, закрываемый одним живым `GET` (класс B) —
> назвать, не домысливать. **Шаг 2 — форма правки по исходу шага 1:** поле есть в источнике →
> правка `fetch_perimeter.py` по образцу уже читаемых `sales_channel_id`/`sales_channel_name` в
> `fetch_demands.py`; поля нет → константная метка типа документа вместо `NULL`, потому что «Не
> указан» уже занят другим смыслом и слияние двух разных причин в одну корзину есть тихая потеря
> различения. **Рекомендация архитектора, если решает владелец:** метить константой в обоих
> случаях — разрез по каналу на клиентской странице обязан различать опт, розницу и комиссию, а
> не показывать «Не указан» на треть суммы. Правка `sq_marts_sales_overview.sql` в scope НЕ
> входит: `COALESCE(f.sales_channel_name, 'Не указан')`
> (`reference/sql/sq_marts_sales_overview.sql:58`) корректен при любом исходе, чинить надо
> ингест, не витрину (`00_CHARTER §главный принцип`, фикс-форвард в нужный слой). Пишет:
> `reference/code/cf-facts/`, `reference/sales_perimeter_channel_decide_<date>.md`,
> `reference/_scratch_SALES-PERIMETER-CHANNEL-DECIDE_<date>/`.

## Шаг 1 — результат (офлайн, дампы в репо, живых `GET` не было)

Полный ход — `reference/_scratch_SALES-PERIMETER-CHANNEL-DECIDE_2026-08-07/salesChannel_field_check.md`.

- `entity/retaildemand` (100 строк дампа): поле `salesChannel` **отсутствует в ключах документа
  целиком** — не `null`.
- `entity/commissionreportin` (7 строк дампа): поле `salesChannel` **присутствует на всех 7
  строках выборки** (ссылка на `entity/saleschannel`).

`CONTEXT GAP` из приёмки НЕ наступил — дамп по `commissionreportin` в репо уже был
(`reference/_scratch_SALES-PERIMETER-CONFIRM_2026-08-02/commissionreportin_may_page_0.json`),
живой `GET` не понадобился.

## Шаг 2 — развилка и решение

Результат шага 1 смешанный (поле есть у одного типа документа, нет у другого) — это ровно
развилка, уже названная в `07_STATE.md` («Развилки на владельце»: «метка канала для розницы и
комиссии, если поле `salesChannel` в источнике отсутствует»). Владелец выбрал (чат
2026-08-07): **константа для обоих типов** (рекомендация архитектора), реальный `salesChannel`
из `commissionreportin` НЕ читается.

Метки взяты из уже принятой классификации типов документа в докстринге `fetch_perimeter.py`
(строки 9–10, добавлены `SALES-PERIMETER-EXTEND`): `entity/retaildemand` = «Розница»,
`entity/commissionreportin` = «Комиссия». Не изобретены заново.

## Правка

Файлы: `reference/code/cf-facts/fetch_perimeter.py`, `reference/code/cf-facts/bq_ops.py`.

- `fetch_perimeter.py`: `_fetch_positions_for` получает параметр `sales_channel_name` (константа
  по вызывающей функции); каждая запись позиции несёт `sales_channel_id: None`,
  `sales_channel_name: "Розница"` либо `"Комиссия"`.
- `bq_ops.py`:
  - `PERIMETER_STAGING_SCHEMA` получает поля `sales_channel_id`/`sales_channel_name` (STRING) —
    без них `load_table_from_json(..., ignore_unknown_values=False)` упал бы на неизвестных
    ключах записи.
  - `_build_perimeter_merge_sql`: `SELECT` читает `s.sales_channel_id`/`s.sales_channel_name` из
    staging вместо `CAST(NULL AS STRING)`; `WHEN MATCHED THEN UPDATE SET` теперь тоже обновляет
    оба поля — уже промоутнутые строки (из прежних прогонов, когда правки не было) получат метку
    на следующем `perimeter_promote`, не только новые строки.
  - `sales_channel_id` остаётся `NULL` — синтетической строки-справочника `entity/saleschannel`
    для константных меток не существует, изобретать UUID не стал; клиентская страница читает
    только `sales_channel_name` (`COALESCE` в `sq_marts_sales_overview.sql:58`).

Деплой этой сессией НЕ исполняется (класс B, мандат не выдан, заводится по факту готовности
правки — этим коммитом готовность зафиксирована).

## Проверка (офлайн)

```
python3 -m py_compile reference/code/cf-facts/fetch_perimeter.py reference/code/cf-facts/bq_ops.py
```
→ `COMPILE OK` (без ошибок синтаксиса и импортов на уровне модуля).

Живых вызовов к МойСкладу, записи в BigQuery, деплоя CF в этой сессии не было — тест на
живых данных лежит за пределами мандата класса A этой подзадачи и является частью
`SALES-PERIMETER-CHANNEL-DECIDE, деплой` (класс B).
