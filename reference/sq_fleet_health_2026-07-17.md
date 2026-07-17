# Reference: состояние прогонов SQ-флота `msklad-bi-prod`

**Назначение:** return-this задачи `SQ-FLEET-HEALTH`; закрывает Q-33 (`_METHOD §11` CAPTURE).
**Дата снятия:** 2026-07-17 · **Location:** `asia-east1` · **Инструмент:** `bq` 2.1.33
**Тип:** диагностический (evidence), **НЕ оракул** — вне `02 §оракул`. Снимок на дату; при расхождении с продом снимать заново.
**Команды:** `bq ls --transfer_config --transfer_location=asia-east1 --project_id=msklad-bi-prod --format=prettyjson` → `bq ls --transfer_run --max_results=50 --format=prettyjson <resource_name>` (по каждому из 13).

## Результат: 12/13 зелёные

| displayName | Последний прогон (UTC) | Состояние | не-OK / всего | Глубина покрытия |
|---|---|---|---|---|
| **`sq_audit_dim_products_snapshot`** | 2026-07-17 04:00 | **FAILED** | **45/50** | ~50 сут |
| `sq_audit_dim_counterparties_snapshot` | 2026-07-17 04:00 | SUCCEEDED | 0/50 | ~50 сут |
| `sq_audit_dim_employees_snapshot` | 2026-07-17 04:00 | SUCCEEDED | 0/50 | ~50 сут |
| `sq_marts_inventory_health` | 2026-07-17 11:00 | SUCCEEDED | 0/50 | ~50 сут |
| `sq_marts_sales_overview` | 2026-07-17 11:34 | SUCCEEDED | 0/50 | **~4 сут** (интервал 2ч) |
| `sq_marts_gmroi_by_folder` | 2026-07-17 12:02 | SUCCEEDED | 0/50 | ~50 сут |
| `sq_marts_gmroi` | 2026-07-17 08:03 | SUCCEEDED | 0/50 | ~50 сут |
| `sq_marts_abc_xyz` | 2026-07-17 08:04 | SUCCEEDED | 0/50 | ~50 сут |
| `sq_marts_in_transit` | 2026-07-16 13:09 | SUCCEEDED | 0/50 | ~50 сут |
| `sq_marts_supplier_price_history` | 2026-07-16 13:09 | SUCCEEDED | 0/50 | ~50 сут |
| `sq_marts_weight_flow` | 2026-07-16 23:30 | SUCCEEDED | 0/45 | вся история |
| `sq_marts_expenses` | 2026-07-17 11:10 | SUCCEEDED | 0/43 | вся история (creationTime 2026-06-05) |
| `sq_marts_customer_invoices_ar` | 2026-07-17 10:00 | SUCCEEDED | 0/43 | вся история |

**Читать с ограничением:** `0/50` = нет падений в **последних 50** прогонах, не «никогда». Три нижние строки не усечены (`docs=1`) ⇒ там 0 по всей удерживаемой истории. Даты 2026-07-16 у `in_transit`/`supplier_price_history`/`weight_flow` — не отставание: интервал 24ч, следующий прогон не наступил (последний момент лога — 12:02 UTC 07-17).

## Ф-1. `sq_audit_dim_products_snapshot`: 45/50 — третье подтверждение дыры

50 последних прогонов = 2026-05-29…2026-07-17: **5 SUCCEEDED** (05-29…06-02) + **45 FAILED** (06-03…07-17), ошибка неизменна — `Inserted row has wrong column count; Has 15, expected 14 at [2:1]`. Сходится с `MAX(snapshot_at)` = 2026-06-02 04:00:10 и с 71-прогонной историей (`/reference/sq_audit_dim_products_drift_2026-07-17.md`). ADR-021 §1 подтверждён трижды независимо.

## Ф-2. Якоря расписаний — независимые, порядок не задан

10 из 13 — `every 24 hours` (DTS-дефолт от собственного `creationTime`), якоря разбросаны: 04:00 · 08:03 · 08:04 · 10:00 · 11:00 · 11:10 · 12:02 · 13:09 · 23:30. Оркестрации нет. Значимо ровно для одной пары — см. Ф-3.

## Ф-3. Единственная март-на-март зависимость (Q-38)

`grep` по всем 13 SQL @ SHA `e7bd843` на `FROM`/`JOIN … marts.`:

| SQ | Читает |
|---|---|
| `sq_marts_gmroi_by_folder` | **`msklad-bi-prod.marts.gmroi`** |
| остальные 11 март-SQ | только `core.*` |
| 3 audit-SQ | `core.*` → `audit.*` |

Порядок 2026-07-17: `gmroi` 08:03 → `gmroi_by_folder` 12:02 (верный, запас ~4ч), но держится совпадением якорей `creationTime`, не конструкцией. Config ID зависимого `6a004e88-…` < источника `6a006664-…` ⇒ заведён раньше. Отказ порядка выглядит как `SUCCEEDED` на вчерашних данных; `_mart_refreshed_at = CURRENT_TIMESTAMP()` штампует свежесть агрегации, а не данных. → **Q-38**, DEFER.

## Ф-4. Инструментальное (→ `05` Часть II, proposed)

`bq ls --format=prettyjson` при усечении по `--max_results` печатает **два JSON-документа**: `[{"nextPageToken": "…"}]` (51 Б) + страница ⇒ `json.load()` падает с `Extra data: line 6 column 1 (char 51)`. Разбирать через `JSONDecoder().raw_decode()` в цикле либо задавать `--max_results` заведомо выше. Диагностика v1/v2 этой сессии дважды дала ложную картину (`NO_RUN ×13`, затем `JSON-PARSE-FAIL ×10`) при `rc=0` и пустом `stderr` — оба раза дефект скрипта, не прода.
