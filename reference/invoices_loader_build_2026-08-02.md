# FILE: reference/invoices_loader_build_2026-08-02.md

# `INVOICES-LOADER-BUILD` — построение загрузчика счетов покупателям (T3 программы `ADR-110`)

**Дата:** 2026-08-02 (Бишкек) · **Класс задачи:** A · **Бриф:** `briefs/INVOICES-LOADER-BUILD.md`
**Дерево/ветка:** `worktrees/INVOICES-LOADER-BUIL` / `s/INVOICES-LOADER-BUIL`
**Вход:** `reference/invoices_loader_design_2026-08-02.md` (целиком, самодостаточен — не пересказывается)
**Провенанс:** `reference/_scratch_INVOICES-LOADER-BUILD_2026-08-02/` (не убирается, `ADR-043`)

**Назначение файла.** Самодостаточный вход для `T4` (`INVOICES-LOADER-DEPLOY`, класс B): что
построено, какими числами подтверждено каждое требование design §13, что осталось за границей
класса A и почему.

---

## 0. Что построено

- `reference/code/cf-finance/main.py` — патч диспетчера (`mode="payments"|"invoices"`, умолчание
  `payments`), `run_etl()`/`trigger_marts()`/`parse_href()` не тронуты (диф побайтовый —
  `MANIFEST.md`).
- `reference/code/cf-finance/invoices.py` — новый модуль, весь режим `invoices`: пагинация
  (явный `offset`/`limit`), `G1`/`G2`, конвертация валюты с обязательной fallback-веткой, схема
  staging на 19 колонок, текст `MERGE` с веткой удаления, тексты обеих проверок свежести, печать
  счётчиков прогона.
- `reference/code/cf-finance/requirements.txt` — добавлена строка `tenacity`.
- `reference/code/cf-finance/MANIFEST.md` — провенанс снапшота (ревизия `00012-cik`, sha256,
  сверка с независимой сессией `CODE-REPO-STANDUP`) + список патча.

Полный провенанс снятия снапшота, все тестовые скрипты и их логи — в
`reference/_scratch_INVOICES-LOADER-BUILD_2026-08-02/`.

---

## 1. Шаг 1 — свежий снапшот живого `cf-finance` (гэп 1 design §11.1)

`gcloud functions describe` → ревизия `cf-finance-00012-cik`, `updateTime
2026-07-30T10:04:58Z`, `storageSource` generation `1784560843778541`. Архив скачан `gsutil cp`
тем же generation, sha256 архива `04c337f4c31...` и sha256 `main.py`
`0cb4f6698a61cee96c90f9a14973ada38f5123418b54ff901f24ea2026ddab59` **совпали побайтово** с
независимой записью `reference/code_repo_standup_d2_2026-08-01.md §4/§6` (та же ревизия, снята
другой сессией на Cloud Shell 2026-08-01) — два независимых снятия одной ревизии дают
идентичный хэш.

**Наблюдение (обязательное по шагу 1 брифа):** диспетчер `mode` в живой ревизии `00012-cik`
**ОТСУТСТВОВАЛ** — `grep -n "mode" main.py` → 0 совпадений и до патча, точка входа была
`def main(request): run_etl(); return "OK", 200`. Разница с устаревшим снапшотом `00006-piv` в
этой части — нулевая; за шесть ревизий диспетчер не появился.

---

## 2. Приёмка — по чек-листу design §13, числами (`ADR-044`)

### п.1 — Диспетчер не ломает платежи

Скрипт `reference/_scratch_.../checks/dispatcher_test.py`, лог `checks/dispatcher_test.log`.
Патч испытан против СВЕЖЕГО снапшота (не устаревшего `00006-piv`). `run_etl`/`run_invoices_etl`
подменены счётчиками вызовов, `bigquery.Client` подменён заглушкой (сеть/креды не нужны для
проверки маршрутизации).

```
empty body      -> ('OK', 200)   run_etl_calls=1
{}              -> ('OK', 200)   run_etl_calls=2
{"mode":"payments"} -> ('OK', 200)   run_etl_calls=3
{"mode":"invoices"} -> ('OK', 200)   run_invoices_etl_calls=1
{"mode":"bogus"}    -> (400)
ВЕРДИКТ: run_etl_calls=3 run_invoices_etl_calls=1 unknown_mode_status=400 — ВСЕ ОЖИДАЕМЫЕ ЧИСЛА СОВПАЛИ
```

### п.2 — Профиль запроса (статическая часть, без секрета)

Чтением `invoices.py`: `LIMIT = 100`, `TIMEOUT = 90`, `SLEEP_S = 0.25`,
`EXPAND = "state,agent,salesChannel,rate.currency"` — **4** компонента (посчитано программно:
`expand.split(',') → 4`). Все четыре значения читаны из кода, не из памяти.

**Живая проверка непустоты `agent.name`/`state.name`/`salesChannel.name`/`rate.currency.isoCode`
на реальном документе — НЕ выполнена, требует секрет `msklad-token` (design gap 3).** Остаток
назван в §4 ниже, не имитирован.

### п.3 — Полнота обхода (G1/G2)

Скрипт `checks/g1_g2_test.py`, лог `checks/g1_g2_test.log`:

```
G2: fetched=0                       -> RuntimeError "G2 FAILED: fetched=0 documents..."
G1: fetched=47 meta_size_first=50   -> RuntimeError "G1 FAILED: fetched=47 < meta_size_first=50" (staging_write_calls=0)
G1: fetched=52 meta_size_first=50   -> продолжение разрешено (52 >= 50)
```

Обрыв обхода даёт `raise` ДО обращения к записи в staging (счётчик обращений к записи остаётся
`0` в обоих случаях провала).

### п.4 — Правило суток

Скрипт `checks/merge_moment_idempotency_delete_test.py`, лог одноимённый `.log`. Синтетический
документ `synt-usd-fallback` с `moment_raw = "2026-05-12 22:15:00.000"` (UTC, полоса
`[18:00;24:00)`) пропущен через staging → `MERGE` (текст — `invoices.build_merge_sql()`, дословно
design §7.5) → результат:

```
moment_rule_test: utc_date=2026-05-12 utc_time=22:15 -> core.moment=2026-05-13
```

Следующие бишкекские сутки относительно UTC-даты документа, как требует `DATE(M+6ч)`.

### п.5 — Конвертация

Скрипт `checks/currency_test.py`, лог одноимённый `.log`. Три ветви §8.2 проверены отдельно
(сеть к `entity/currency` подменена контролируемым fake — секрет не используется):

```
branch1_rate_value_present: rate=1.25 currency=USD fallback=False
branch2_kgs_no_rate:        rate=1.0  currency=KGS fallback=False
branch3_fallback_hit:       rate=89.5 currency=USD fallback=True
fetch_current_rate_success: rate=89.5
fetch_current_rate_missing_value_raised: RuntimeError (НЕ подставлен 1.0, ADR-029 §1)
```

Три синтетических документа (включая `synt-usd-fallback` — не-KGS без `rate.value`) собраны в
staging-строки и загружены в реальную `stg_msklad.fact_customer_invoices_staging`:

```
synthetic_rows_built=3 fallback_hits=1
staging_rows_loaded=3
bad_rows=0   (запрос design §6.2, реальный BigQuery)
```

### п.6 — C1 / текст MERGE (машинная проверка, не глазами)

Скрипт `checks/selfcheck_merge.py`, лог `checks/selfcheck_merge.log` (та же дисциплина, что
design §7.5.1 — строки-комментарии отброшены ДО поиска):

```
V1. строк исполнимого SQL с 'INSERT ROW': 0   (всего вхождений в файле, включая комментарии: 1)
V2. UPDATE SET присваиваний: 13 | INSERT имён колонок: 14 | VALUES значений: 14
    INSERT[i] <-> VALUES[i]: полное соответствие
    во всех UPDATE T.X = S.X: да
    живая схема core (14) == INSERT-набор: ДА
    UPDATE-набор == схема минус ключ invoice_id: ДА
    T.moment в UPDATE SET: ДА
    ветка удаления (C2): ДА
    окно/DATE_SUB в ON: НЕТ — верно
    срез moment_raw[:10]: НЕТ — верно
    вхождений 'Asia/Bishkek': 2
СВОДНЫЙ ВЕРДИКТ: ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ
```

Живая схема `core.fact_customer_invoices` (14 колонок, без партиционирования/кластеризации)
подтверждена ЭТОЙ сессией `bq show` (не унаследована из design без проверки) — совпадает с
design §5 дословно.

### п.7 — Идемпотентность и п.8 — ветка удаления

**Важное отступление от буквального прочтения, зафиксированное явно (не тихо).** Бриф запрещает
запись в живые прод-таблицы `core.*` в этой сессии, а чек-лист требует реально исполнить `MERGE`
и увидеть числовой эффект (вставка/удаление). Оба ограничения одновременно выполнимы только одним
способом: прогнать ТОТ ЖЕ САМЫЙ текст `MERGE` (`invoices.build_merge_sql()`, без изменений
логики) против непрод-таблицы с идентичной схемой (14 колонок, сверено `bq show` этой сессией) и
именем, буквально оканчивающимся на `_staging` — `stg_msklad.fact_customer_invoices_core_test_staging`
— что попадает под явно разрешённый мандатом шаблон `*_staging` (`07_STATE.md:432`), не под
`core.*`. Таблица создана и используется ТОЛЬКО этой сессией; она живёт в датасете `stg_msklad`
(TTL 14 суток, `02_ERP_CONTRACTS.md:11`) и самоочистится, отдельного удаления не требует.
**Живая `core.fact_customer_invoices` этой сессией НИ РАЗУ не записывалась** — только читана
(freshness-проверки, §3 ниже).

Числа веток `MERGE` считаются ДО его исполнения тем же предикатом (`applicable IS NOT FALSE`,
`ON invoice_id`), которым сам `MERGE` пользуется — `invoices.merge_predicted_stats()`; поскольку
staging не меняется между вызовом функции и запуском `MERGE` в рамках одного прогона, предсказание
и есть результат (числа сверены фактическим состоянием таблицы после каждого прогона, не только
предсказанием).

Лог `checks/merge_moment_idempotency_delete_test.log`:

```
Прогон 1 (первая загрузка): predicted={inserted:3, updated:0, deleted:0}
  n_rows_after_run1=3  sum_sum_kgs_after_run1=466600.0

Прогон 2 (тот же staging, без изменений) — п.7 идемпотентность:
  predicted={inserted:0, updated:3, deleted:0}
  n_rows_after_run2=3 (=run1)  sum_sum_kgs_after_run2=466600.0 (=run1)

Ручное удаление ОДНОЙ строки staging (synt-usd-withrate) + Прогон 3 — п.8 ветка удаления:
  predicted={inserted:0, updated:2, deleted:1}
  n_rows_after_run3=2  remaining_ids=['synt-kgs-1', 'synt-usd-fallback']
```

`merged_inserted=0`, `merged_deleted=0` на повторном прогоне без изменений (п.7); `merged_deleted=1`
и убрана РОВНО удалённая строка на прогоне после ручного удаления (п.8) — оба числа совпали с
ожиданием чек-листа.

### п.9 — Длительность

**Новый прогон счетов — НЕ замерен.** Требует деплой и живой вызов (`T4`), не выполнимо под
классом A этой строки; design §13 сам относит эту часть к `T4`.

**Текущая длительность прогона платежей ДО правки — снята read-only чтением Cloud Logging**
(без деплоя, без секрета — тот же метод, что `CODE-REPO-STANDUP`):

```
gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="cf-finance" httpRequest.status=200' --freshness=30d --limit=30
n_scheduled_runs_sampled=17 (суточные прогоны finance-daily-update, 21:00Z)
latency: min=785.6s max=874.5s avg=823.8s
```

Запас до потолка `1800s` — более чем двукратный на сегодняшнем объёме платежей; проектная оценка
design §3.1 (`~46` страниц счетов × `0.25с` ≈ `12с` сетевого времени) добавляет к этому бюджету
пренебрежимо мало относительно текущего среднего в `824с`.

### п.10 — Проверка свежести

Оба запроса §9.2 исполнены против ЖИВОЙ `core.fact_customer_invoices` (чтение, не запись, не
секрет). Лог `checks/freshness_test.log`:

```
(A) техническая: load_lag_hours=1401  distinct_load_stamps=1  n_rows=4058
(B) бизнес:      business_lag_days=59
ВЕРДИКТ: load_lag_hours=1401 (> порог 48 — КРАСНАЯ, как ожидалось: заморозка 58 суток)
```

`n_rows=4058` совпадает с задокументированной цифрой (`ADR-109 §3`/`07_STATE`); `1401` часов
≈ `58,4` суток — согласуется с зафиксированной заморозкой `2026-06-05…2026-08-02`.
`distinct_load_stamps=1` — единственный ручной прогон, ожидаемо для замороженной таблицы.

---

## 3. Что осталось за границей класса A (не имитировано)

По разделу брифа «Живые вызовы к МойСкладу — граница класса»:

1. **Гэп 3 (design §11.3) — не снят.** Проверка `expand=state,agent,salesChannel,rate.currency`
   на реальном документе (все четыре компонента непустые) требует живой `GET` с секретом
   `msklad-token`. Мандат этой строки (`07_STATE.md:432`) секрета не упоминает; по `ADR-076 §1`
   доступ к секретам — признак класса B. Design-документ называет это расхождение и НЕ решает
   его («работа архитектора») — эта сессия тоже его не решает.
2. **Часть п.2/п.9 чек-листа**, зависящая от того же секрета либо от живого деплоя — см. таблицу
   выше по каждому пункту отдельно.

Оба пункта — факт о границе класса, названный ещё до этой сессии (design §12,
«Процессное наблюдение»), не провал задачи.

---

## 4. Самодостаточность для T4

Документ содержит: провенанс снятия свежего снапшота с побайтовой сверкой против независимой
сессии (§1); числовой результат каждого из 10 пунктов чек-листа design §13 (§2), включая явно
названное и обоснованное отступление в методе проверки п.7/п.8 (тестовая copy-таблица вместо
живого `core.*`, ни разу не нарушающее запрет брифа); точный перечень того, что осталось за
границей класса A с адресом design-документа (§3). Патч (`reference/code/cf-finance/`) готов к
переносу — `MANIFEST.md` в той же директории несёт полный sha256-провенанс базового снапшота и
патча.

`T4` обязан: (а) снять СВОЙ свежий снапшот перед деплоем (ревизия могла измениться); (б) закрыть
гэп 3 живым `GET` с секретом (первое место, где класс B неизбежен); (в) выполнить деплой,
Scheduler job и живой прогон, замерить длительность НОВОГО прогона против потолка `1800с`.
