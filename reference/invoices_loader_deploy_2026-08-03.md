# FILE: reference/invoices_loader_deploy_2026-08-03.md

# `INVOICES-LOADER-DEPLOY` — деплой загрузчика счетов покупателям (T4 программы `ADR-110`)

**ЗАДЕПЛОЕНО. Прод стоит на ревизии `cf-finance-00013-jaq`.** Заморозка `core.fact_customer_invoices`
(58 суток) снята: боевой прогон дал `4526` строк, `load_lag_hours=0`. Расписание `invoices-daily-update`
создано и включено. Режим платежей проверен и не пострадал.

**Дата:** 2026-08-03 (Бишкек) · **Класс задачи:** B, мандат `ADR-115 §12` · **Бриф:** `briefs/INVOICES-LOADER-DEPLOY.md`
**Дерево/ветка:** `worktrees/INVOICES-LOADER-DEPLOY` / `s/INVOICES-LOADER-DEPLOY`
**Провенанс:** `reference/_scratch_INVOICES-LOADER-DEPLOY_2026-08-03/` (скрипты, логи, JSON-снимки; `venv/`
и клон код-репо `holika-prod-master/` исключены локальным `.gitignore` — не провенанс, воспроизводимы)

---

## 1. Шаг 1 — проверка `expand` (гэп 3 design §11.3, закрыт)

Живой `GET entity/invoiceout`, `limit=100`, `expand=state,agent,salesChannel,rate.currency`.
Лог `step1_run.log`, тело ответа `step1_invoiceout_response.json`.

**Вердикт: тихой деградации нет.** На выборке 5 документов `agent.name`, `state.name`,
`rate.currency.isoCode` присутствуют у всех; `salesChannel` легитимно `null` там, где документ его
не несёт (не деградация — отсутствие значения в источнике, ср. row `002bf41f-e1f7-11ef-…`).
Одного прохода достаточно, двухпроходная схема (design §11.3) не нужна.

## 2. Шаг 2 — снапшот и сверка с `master`

`gcloud functions describe cf-finance` → ревизия `cf-finance-00012-cik`, generation
`1784560843778541`. Скачан, sha256 по файлам — `step2_run.log`.

**Расхождение с `master` (@ `81812f4d06fccb5ea0500b565269b07755831fb0`) — только в мусоре**:
`main.py.bak`, `main.py.pre-e1t3-mech-fx.bak`, `patch_main_finance.py`, `__pycache__/` — все четыре
исключены `.gitignore` код-репо осознанно (`ADR-094 §4`, подтверждено чтением `.gitignore` ветки).
`main.py` и `requirements.txt` совпали с `master` побайтово. **Реального дрейфа нет.**

## 3. Шаг 3 — ветка и перенос патча

Ветка `deploy/cf-finance-2026-08-03-invoices` от `master`. Патч перенесён **по diff**
(`main_py.diff`/`requirements_txt.diff` против базового снапшота, не копированием файлов
построенного патча) — sha256 после переноса совпал с построенным патчем (`INVOICES-LOADER-BUILD`)
побайтово:
- `main.py`: `1afbaa3707182b54fc0c14600682d0220fe94a257f92093a862e55da27a2c6df`
- `invoices.py`: `dc1768d973c2898addf5ee92116e831272437e3a9140683c92eb09cd74701886`
- `requirements.txt`: `f986310a048c5c90c93e511ec3ef0eeacf71feb2ecf591d45b001097e6707164`

`.gitignore` ветки чист (наследован от `master`). Сплошной поиск секретов
(`grep -rniE "bearer|msklad-token|secret|api[_-]?key|password|BEGIN"`) дал только имя переменной
токена (`os.environ.get("MSKLAD_TOKEN")`) и шаблон заголовка (`f"Bearer {token}"`) — значений нет.
**Этот деплой закрывает `RQ-3`** (см. §7 read-back — мусора в развёрнутом архиве нет).

## 4. Шаг 4 — коммит и push ветки (подтверждено владельцем)

Коммит `e6b9627` в ветку, `push` в `github.com/ilyasbazarov/holika-prod`. `master` не тронут.

## 5. Шаг 5 — прогон в staging (подтверждено владельцем)

Прогон `run_invoices_etl()` против тестовой таблицы `stg_msklad.fact_customer_invoices_core_test_staging`
вместо `core.fact_customer_invoices` — реальный `GET` к МойСкладу, реальная запись только в
`*_staging`. Логи: `step5_run.log` (первая попытка, сеть), `step5_run_retry1.log` (успех).

**Первая попытка упала на сетевом таймауте `read timeout=90`** на одной из страниц пагинации —
до записи в staging (обход не завершён, `check_completeness` не вызывался, ничего не записано).
Повтор безопасен (read-only обход, идемпотентен по построению). **Находка для архитектора:**
декоратор `tenacity` в `invoices.py` (`_api_get`) ретраит только `_RetryableError` (429/5xx), а
`requests.exceptions.ReadTimeout` под него не подпадает и падает наружу необработанным — это
расходится с design §3.4, где сетевой таймаут заявлен как «ретраится общим механизмом». На проде
ничем не грозит (Scheduler не ретраит, `maxRetryDuration=0s`, падение просто пропускает сутки и
видно по `load_lag_hours` на следующий день), но сам факт расхождения кода с design стоит
зафиксировать архитектору отдельной строкой.

**Итог успешного прогона:** `fetched=4526 meta_size=4526` (= источнику), `staged=4526`,
`bad_rows=0` (запрос design §6.2 по реальной staging), `currency_fallback_hits=0`. Ручная проверка
на не-KGS документах (USD, `rate_value=90.0`) — `sum_kgs`/`payed_sum_kgs`/`unpaid_sum_kgs` совпали
с арифметикой `sum_minor/100×rate` до копейки на выборке 5 документов. Правило суток проверено на
реальном документе с `moment` в полосе `[18:00;24:00)` UTC (`2026-07-14 21:07:00 UTC`) →
бишкекская дата `2026-07-15` (следующие сутки, как требует `DATE(M+6ч)`). Тестовая таблица после
`MERGE` — `4526` строк, `merged_deleted=2` (синтетические строки прежней тестовой сессии, законно
удалены как отсутствующие в источнике).

## 6. Шаг 6 — деплой (подтверждено владельцем)

`gcloud functions deploy cf-finance --gen2 --runtime=python312 --region=asia-east1
--source=<ветка>/cf-finance --entry-point=main --service-account=etl-sa@... --memory=512MB
--timeout=1800s --max-instances=16 --set-secrets=MSKLAD_TOKEN=msklad-token:latest`. Параметры —
из живой `describe` (§2), не с соседней функции. Лог `step6_run.log`.

**Новая ревизия: `cf-finance-00013-jaq`**, generation `1785767015791249`, `updateTime
2026-08-03T14:24:36Z`.

## 7. Шаг 7 — read-back (класс A)

Развёрнутый архив скачан и распакован, sha256 по файлам сверен с веткой — **полное побайтовое
совпадение** (`main.py`, `invoices.py`, `requirements.txt`). **Мусора в архиве нет вообще**
(проверено программно: единственные три файла в архиве — исполняемый код). Лог `step7_run.log`.

## 8. Шаг 8 — функциональная проверка на проде (подтверждено владельцем дважды)

**(а) Вызов без параметров (режим платежей).** `HTTP 200`, `OK`, длительность ≈857с — в пределах
исторического диапазона (`785,6–874,5с`, `INVOICES-LOADER-BUILD §2 п.9`). Cloud Logging: `Loading
6537 records to STG… Running MERGE… Cleaning up excluded system expenses…` — прежнее поведение
не изменилось. `core.fact_payments`: `max_loaded_at=2026-08-03 14:42:07`, `n_rows=5026`.

**Процессная находка (не дефект этой задачи).** Первый вызов (без параметров) был оборван по
таймауту клиентского инструмента (2 мин), но **сервер продолжил обработку независимо от разрыва
клиентского соединения** — это дало ДВА полных прогона платежей подряд (видно по двум блокам
`Loading … STG` в логе, `14:40` и `14:42`). Оба безопасны (`MERGE` идемпотентен), но при повторных
проверках такого рода стоит сразу задавать клиенту таймаут с запасом (сделано для шага 8б —
`curl --max-time 1750`).

**Отдельно замечено (не новое, не эта задача):** `trigger_marts()` в обоих прогонах платежей упал
с `403 User does not have sufficient permissions` на `transferConfigs/6a22a243-…` — код ловит это
исключение как non-fatal (`WARNING`, не прерывает прогон), поведение соответствует коду, но факт
403 (а не тихий успех) стоит назвать архитектору отдельно — вне scope этой задачи, не разбирался.

**(б) Вызов `mode=invoices` (боевой прогон, подтверждено владельцем отдельно).** `HTTP 200`, `OK`,
≈11,5 мин. Cloud Logging: `G1 fetched=4526 meta_size_first=4526`,
`merge_predicted {merged_inserted: 484, merged_updated: 4042, merged_deleted: 16}`.
**Итог в `core.fact_customer_invoices`: `4526` строк, `load_lag_hours=0`,
`distinct_load_stamps=1`, `total_sum_kgs=1 279 111 083,57`.** Заморозка (58 суток, `4058` строк)
снята первым же боевым прогоном.

## 9. Шаг 9 — расписание (подтверждено владельцем)

`gcloud scheduler jobs create http invoices-daily-update --location=asia-east1
--schedule="0 4 * * *" --time-zone=Asia/Bishkek --uri=<URI cf-finance> --http-method=POST
--message-body='{"mode":"invoices"}' --oidc-service-account-email=etl-sa@...
--attempt-deadline=1800s --max-retry-attempts=0`.

**Read-back:** `state: ENABLED`, `scheduleTime: 2026-08-03T22:00:00Z` (= `04:00` Бишкек, 04.08).
Инвентарь Scheduler после создания (`step9_run.log` + отдельная проверка): `finance-daily-update`
(`0 3 * * *`) и остальные четыре существующих джоба — без изменений.

## 10. Шаг 10 — слияние и запись соответствия (подтверждено владельцем)

`git checkout master && git merge --no-ff deploy/cf-finance-2026-08-03-invoices` → коммит
`db02a89`, `git push origin master` подтверждён. Запись ревизия↔коммит —
`reference/code/cf-finance/MANIFEST.md` (раздел «Деплой (`INVOICES-LOADER-DEPLOY`…»`).

---

## Итог по критериям приёмки брифа

| Критерий | Результат |
|---|---|
| Тело ответа шага 1 напечатано дословно, вердикт по `expand` явный | ✅ `step1_run.log` |
| Побайтовая сверка снапшота с `master` напечатана | ✅ только мусор, реальный код совпал |
| Staging-прогон: число документов + три величины арифметикой | ✅ `4526=4526`, `bad_rows=0`, ручная проверка |
| Read-back: ревизия, generation, sha256, мусор | ✅ `cf-finance-00013-jaq`, `1785767015791249`, полное совпадение, мусора нет |
| Прогон без параметров подтверждает неизменность режима платежей | ✅ `HTTP 200`, `MERGE` отработал как раньше |
| `MANIFEST.md` несёт запись ревизия↔коммит | ✅ |
| `master` содержит патч ТОЛЬКО после успешного read-back | ✅ (шаг 10 — после шага 7) |
| Ни одной записи в `core.fact_customer_invoices` до шага 8 | ✅ шаг 5 — только `*_staging` |

## Что осталось за границей этой задачи (не решалось, названо)

- **Найденное расхождение `tenacity`-ретраев с design §3.4** (§5 выше) — архитектору, не чинится
  этой сессией (вне мандата, код уже задеплоен и работает через повтор).
- **`403` на `trigger_marts()`** (§8а) — существующее поведение, не новое, не разбиралось.
- `INVOICES-BACKFILL`, `INVOICES-PARITY-RECHECK` — вне scope (брифом названы отдельными задачами);
  первый боевой прогон, вероятно, уже свёл `INVOICES-BACKFILL` к проверке (полная история без
  фильтра по дате, design §6.6), но вердикт — не эта задача.
- Наблюдаемость (пятое условие готовности `ADR-110 §4`) — гейтится `DQ-GATE-SCOPE-SPLIT`, не
  входила в scope.
