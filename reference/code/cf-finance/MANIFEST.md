# MANIFEST · /reference/code/cf-finance/ — снапшот + патч диспетчера/счетов (`INVOICES-LOADER-BUILD`)

**Тип:** снапшот живой ревизии (свежий, снят этой сессией) + внесённый патч, готовый к переносу
на `T4` (`INVOICES-LOADER-DEPLOY`, класс B, не эта задача).
**Заменяет предыдущий манифест этой директории** (снапшот ревизии `00006-piv`, устаревший на
шесть ревизий, диспетчера не имел вовсе — `reference/invoices_loader_design_2026-08-02.md §11`
гэп 1).

---

## Базовый снапшот (ДО патча) — сверка с задеплоенной ревизией

`gcloud functions describe cf-finance --gen2 --region=asia-east1 --project=msklad-bi-prod`
→ `reference/_scratch_INVOICES-LOADER-BUILD_2026-08-02/cf_finance_describe.json`.

| Поле | Значение |
|---|---|
| `serviceConfig.revision` | `cf-finance-00012-cik` |
| `updateTime` | `2026-07-30T10:04:58.604346800Z` |
| `buildConfig.source.storageSource` | `gs://gcf-v2-sources-420804682491-asia-east1/cf-finance/function-source.zip`, generation `1784560843778541` |

Архив скачан `gsutil cp` тем же generation, распакован в
`reference/_scratch_INVOICES-LOADER-BUILD_2026-08-02/live_source/`.

sha256 архива: `04c337f4c31cfa3bb63a7c6ffc913f9f52ef387d4001d89ee2ff494fa2d0b202` — **совпадает** с
записью `reference/code_repo_standup_d2_2026-08-01.md §4` (та же ревизия, снята независимо
другой сессией на Cloud Shell). sha256 `main.py` (до патча):
`0cb4f6698a61cee96c90f9a14973ada38f5123418b54ff901f24ea2026ddab59` — **совпадает** с
`reference/code_repo_standup_d2_2026-08-01.md §6`. Оба совпадения проверены скриптом
(`shasum -a 256`), не на глаз.

**Наблюдение по гэпу 1 (design §11.1):** в живой ревизии `00012-cik` диспетчер режимов (`mode`)
**ОТСУТСТВОВАЛ** — точка входа была `def main(request): run_etl(); return "OK", 200`
(идентично снапшоту `00006-piv`, разница ревизий в этой части нулевая). Патч ниже вносит его
впервые.

## Патч, внесённый этой сессией

| Файл | Действие | sha256 (после патча) |
|---|---|---|
| `main.py` | добавлен диспетчер `mode` (`payments`\|`invoices`), `run_etl()` не тронут | `1afbaa3707182b54fc0c14600682d0220fe94a257f92093a862e55da27a2c6df` |
| `invoices.py` | НОВЫЙ модуль — весь режим `invoices` (design §2-§10) | `dc1768d973c2898addf5ee92116e831272437e3a9140683c92eb09cd74701886` |
| `requirements.txt` | добавлена строка `tenacity` (ретраи 429/5xx, design §3.4) | `f986310a048c5c90c93e511ec3ef0eeacf71feb2ecf591d45b001097e6707164` |
| `patch_main_finance.py` | **УДАЛЁН из снапшота** — junk-файл прошлой ревизии (не про конвертер, про `try/except` на `trigger_marts()`), тот же класс мусора, что `ADR-040`/`ADR-094 §4` уже исключали из код-репо; не относится к загрузчику счетов | — |

`main.py` вырос со 145 строк (живая ревизия) до 161 (+16: импорт `invoices`, дублирующий
дефолт-комментарий, тело диспетчера); `run_etl()`/`trigger_marts()`/`parse_href()` — байт-в-байт
как в живой ревизии (проверено диффом, см. `reference/_scratch_INVOICES-LOADER-BUILD_2026-08-02/checks/`).

**Не является финальным деплойным артефактом.** `T4` обязан снять СВОЙ свежий снапшот перед
переносом (ревизия могла измениться между этой сессией и деплоем) и перенести патч по diff,
не скопировать файлы этой директории вслепую.

---

## Деплой (`INVOICES-LOADER-DEPLOY`, T4, 2026-08-03) — ревизия ↔ коммит

**Процедура:** `05_CONVENTIONS.md` Часть II «Процедура деплоя Cloud Function — только из код-репо,
вариант Б», первое применение (приёмка процедуры `DEPLOY-PROCEDURE`).

| Поле | Значение |
|---|---|
| Ревизия ДО деплоя | `cf-finance-00012-cik` (generation `1784560843778541`) — сверена побайтово с `master` @ `81812f4d06fccb5ea0500b565269b07755831fb0` (расхождение только в мусоре, исключённом `.gitignore`: `.bak`, `__pycache__/`, `patch_main_finance.py`) |
| Ветка переноса | `deploy/cf-finance-2026-08-03-invoices`, коммит `e6b9627` |
| Новая ревизия | **`cf-finance-00013-jaq`** |
| Generation архива | `1785767015791249` |
| Время деплоя (UTC) | `2026-08-03T14:24:36Z` (`updateTime` из `describe`) |
| Read-back | побайтовая сверка развёрнутого архива с веткой — **полное совпадение** (`main.py`, `invoices.py`, `requirements.txt`); мусора в архиве НЕТ (закрывает `RQ-3`) |
| Merge в master | коммит `db02a89`, `git push origin master` подтверждён (2026-08-03) |
| SHA коммита код-репо | `db02a89` (merge), `e6b9627` (патч) |

**sha256 файлов деплоя:**
- `main.py`: `1afbaa3707182b54fc0c14600682d0220fe94a257f92093a862e55da27a2c6df`
- `invoices.py`: `dc1768d973c2898addf5ee92116e831272437e3a9140683c92eb09cd74701886`
- `requirements.txt`: `f986310a048c5c90c93e511ec3ef0eeacf71feb2ecf591d45b001097e6707164`

**Функциональная проверка на проде:**
- Режим `payments` (без параметров) — `HTTP 200`, `MERGE` в `core.fact_payments` отработал
  (`_loaded_at` обновился, `n_rows=5026`), поведение не изменилось.
- Режим `invoices` — `HTTP 200`, `fetched=4526 meta_size=4526`, `merged_inserted=484
  merged_updated=4042 merged_deleted=16`, `currency_fallback_hits=0`. Итог в `core`:
  `4526` строк, `load_lag_hours=0` — заморозка 58 суток снята.

**Расписание:** `invoices-daily-update`, `asia-east1`, `0 4 * * *` Asia/Bishkek, OIDC `etl-sa`,
`attemptDeadline=1800s`, `maxRetryDuration=0s`. `finance-daily-update` не изменён.

Полный ход, лог и провенанс — `reference/invoices_loader_deploy_2026-08-03.md`.

---

## Деплой (`CURRENCY-ASSERT-CFFINANCE-DEPLOY`, 2026-08-18) — ревизия ↔ коммит

**Процедура:** `05_CONVENTIONS.md` Часть II «Процедура деплоя Cloud Function — вариант Б», со всеми
добавленными пунктами (`is-ancestor`, счёт файлов от базы, факт-проверка исполнением по ветке).
**Предмет:** детекция `INGEST-CURRENCY-ASSERT` (`ADR-101 §5`) плюс правка пункта 5 ревью
(`timeout=90`, `raise_for_status`, `(x or {})`, `try/except` на месте вызова).

| Поле | Значение |
|---|---|
| Ревизия ДО деплоя | `cf-finance-00013-jaq` (generation `1785767015791249`) |
| Прод-коммит | `e6b9627` — установлен ПОБАЙТОВОЙ сверкой скачанного архива обслуживающей ревизии с коммитами код-репо, не по записи манифеста |
| База ветки | `master` `9d9ecbadc2166d66670996de34c8703d053bad26` — содержимое `cf-finance` равно архиву прода по всем трём файлам (дрейфа нет) |
| Ветка переноса | `deploy/cf-finance-2026-08-18-currency-assert`, коммит `1636de1` (ровно один файл: `cf-finance/main.py`) |
| Новая ревизия | **`cf-finance-00014-gub`** |
| Generation архива | `1787077910394011` |
| Время деплоя (UTC) | `2026-08-18T18:32:45Z` |
| Read-back | побайтовая сверка развёрнутого архива с веткой — **полное совпадение** (`ALL_MATCH=1`): `main.py` `d87db5ed…`, `invoices.py` `dc1768d9…`, `requirements.txt` `f986310a…`; мусора в архиве нет |
| Трафик | `100 %` на `cf-finance-00014-gub` (подтверждено `gcloud run services describe`) |
| Merge в master | **НЕ выполнен** — требует подтверждения владельца (`ADR-081`, форма `launch §3`) |
| Откат | трафик на `cf-finance-00013-jaq`; данные не затрагиваются |

**Отклонение процедуры, записанное наравне с удачей (`05 §Процедура деплоя` п.8).** Первый заход
деплоя оборван таймаутом инструмента исполнителя (2 минуты) — не облаком. Read-only диагностика
ДО повтора (`step5_run.log`): ревизия оставалась `cf-finance-00013-jaq`, новых сборок и ревизий
нет, трафик на старой — прод не задет. Хвост доисполнен без повторного `push` (`ADR-055`,
запрет слепого retry соблюдён).

**Функциональная проверка на проде (вызов режима `payments` с OIDC `etl-sa`):** прогон прошёл
полностью — `34` предупреждения детекции, `Loading 6750 records to STG`, `Running MERGE`,
`Cleaning up excluded system expenses`. `core.fact_payments`: `5175` → `5199` строк,
`_loaded_at` `2026-08-17 21:14:33` → `2026-08-18 18:47:34`. HTTP-код не снят (curl оборван
таймаутом инструмента) — пункт закрыт журналом и состоянием таблицы, а не кодом ответа.
`trigger_marts()` отдал `403 PermissionDenied` — задокументированное существующее поведение
(`03_PIPELINE_SPEC §cf-finance`, non-fatal), патчем не создано и им не лечится.
