# MANIFEST · /reference/code/cf-facts/ — снапшот исходника (CODE-REPO-SEED-REST)

**Тип:** discovery-снапшот (`_METHOD §11`), не оракул, не прод-код.
**Источник:** прямое снятие `gcloud functions describe cf-facts --gen2` — на этой сессии команда
**отработала без `403`** (прежнее ограничение `07_STATE.md` про обходной путь для `cf-facts` этой
попыткой НЕ воспроизведено; см. «Первый замер равенства» ниже). Архив скачан по `storageSource` с
**закреплённым `generation`** (`gcloud storage cp <uri>#<generation>`), не текущим объектом бакета.
**Дата съёма (UTC):** `2026-08-02T20:49:36Z…20:50:05Z` (`step1_run.log`).
**Скрипт:** `reference/_scratch_CODE-REPO-SEED-REST_2026-08-03/step1_capture_source.sh`, лог
`step1_run.log`.

---

## Ревизия и провенанс (`gcloud functions describe cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod`)

| Поле | Значение |
|---|---|
| `serviceConfig.revision` | `cf-facts-00007-xir` |
| `buildConfig.entryPoint` | `main` |
| `buildConfig.source.storageSource.bucket` | `gcf-v2-sources-420804682491-asia-east1` |
| `buildConfig.source.storageSource.object` | `cf-facts/function-source.zip` |
| `buildConfig.source.storageSource.generation` | `1782334223015697` |
| Полный URI архива (закреплённый) | `gs://gcf-v2-sources-420804682491-asia-east1/cf-facts/function-source.zip#1782334223015697` |

Сырой JSON ответа — `reference/_scratch_CODE-REPO-SEED-REST_2026-08-03/cf-facts_describe.json`.
Кросс-проверка `gcloud run services describe cf-facts` исполнена той же сессией как параллельный
источник (не как замена) — `reference/_scratch_CODE-REPO-SEED-REST_2026-08-03/cf-facts_run_describe.json`.

## Первый замер равенства снапшот↔деплой (`ADR-021 §2`: успех команды ≠ факт)

**Это ПЕРВЫЙ замер равенства для `cf-facts`.** Предыдущего не было: снапшот, ранее лежавший в этом
каталоге, был снят обходным путём (`gcloud run services describe`, прямой `functions describe`
возвращал `403` — зафиксировано `07_STATE.md`, `SALES-REFRESH-WINDOW-GEN` 2026-08-01) без закреплённого
`generation`, то есть без гарантии побайтового совпадения с конкретной задеплоенной ревизией.

**Побочный факт, полезный для доверия к прежнему снапшоту (не входит в критерий приёмки этой задачи):**
9 из 10 файлов прежнего снапшота (все, кроме `deploy_and_workflow.sh`, которого в прежнем снапшоте не
было вовсе) sha256-идентичны файлам этого свежего съёма — см. таблицу ниже, колонка «Прежний снапшот
(2026-08-01, обходной путь)». Совпадение НЕ заменяет замер (обходной путь не давал закреплённого
`generation`, совпадение могло быть случайным или отражать отсутствие изменений между двумя разными
съёмами), но задним числом снижает вероятность того, что прежний снапшот отражал не ту ревизию.

## Состав задеплоенного архива

Распакованный `function-source.zip` несёт 17 записей. Из них **10 включены в seed** (исполняемый код,
его прямые зависимости, deploy-скрипт), **7 исключены как мусор** (Шаг 3, гигиена — `ADR-040`).

| Файл | sha256 (свежий съём) | Совпало с прежним снапшотом (2026-08-01) | В seed | Роль / причина исключения |
|---|---|---|---|---|
| `main.py` | `2b1e4519523dbe0e78520b035f5c047b18e4f348730c98de19dbe54c8b9e4da5` | да | да | Точка входа (`entryPoint=main`) |
| `bq_ops.py` | `dad48a6eec2d80b5a3373beb5463cdd3d94ac71cef481d89f389e8a2308dc4e3` | да | да | BQ-операции, схемы, `MERGE`/`WRITE_TRUNCATE` загрузчиков |
| `config.py` | `977fd82813d3487a1eb9c8cd297312d6e542be3b45fe65b45d73cc143ca3289b` | да | да | Константы: окна, имена таблиц, пороги |
| `fetch_byvariant.py` | `88e1a13881103e0faa5ec21a5a07ddd2fc83e9cc9eb4fb9fe67a0da25fb60ff1` | да | да | COGS-фетчер (`fetch_byvariant_cogs`) |
| `fetch_demands.py` | `637f25dba1a87a412bde7feac32a0b56a052e99c9bb8a5246e13b266b7648770` | да | да | Фетчер продаж (`entity/demand`) |
| `fetch_purchases.py` | `5db807fee2da21c31c5fa3aeed77e16d1a4ae04193f55831534b89c5e9158486` | да | да | Фетчер закупок |
| `fetch_returns.py` | `7ce9373aa084258e45d2ba12c8f1bc2812b249958eec400c4181e4802793ae56` | да | да | Фетчер возвратов |
| `helpers.py` | `aac5dee5add76513f52e8909a32925f261ad25d09ef55a1a6013f5262cd01c48` | да | да | Общие утилиты (HTTP, ретраи, курсы) |
| `requirements.txt` | `0c041a8d50f4731ad71aabcf678f388c13d8ba9af6ccb6548af9ccb6fc514051` | да | да | Зависимости |
| `deploy_and_workflow.sh` | `2e9391517c772a03a22f6751135888796778ea0889e15f97d63ba9bafcab9d07` | **отсутствовал в прежнем снапшоте** | да | Deploy-команда + smoke-test, задокументированный вызов `gcloud functions deploy` (не мусор — не `.bak`, не разовый патч, не кэш) |
| `.DS_Store` | — | — | **нет** | macOS filesystem-мусор, случайно попавший в архив при упаковке |
| `fetch_demands.py.bak` | — | — | **нет** | резервная копия, класс `ADR-040` |
| `fetch_purchases.py.bak` | — | — | **нет** | резервная копия, класс `ADR-040` |
| `fetch_returns.py.bak` | — | — | **нет** | резервная копия, класс `ADR-040` |
| `patch_code.py` | — | — | **нет** | разовый patch-скрипт (правит `fetch_purchases.py`/`bq_ops.py` на месте, добавляет `order_name`) — тот же класс, что `patch_main_finance.py` у `cf-finance` (исключён там же основанием, `ADR-040`) |
| `patch_timeout.py` | — | — | **нет** | разовый patch-скрипт (правит `timeout=30→90` в `helpers.py` на месте) — тот же класс |
| `src.zip` | — | — | **нет** | самореференциальный вложенный архив-остаток упаковки (11 файлов, датирован смесью 2026-05-06…2026-06-03), тот же класс аномалии, что три вложенных zip у `cf-dq` (`reference/code/cf-dq/MANIFEST.md §Известная аномалия`) — не исполняется рантаймом, оставлен как найден в архиве облака, не переносится в seed |

**Отличие `patch_dq.py` от `patch_code.py`/`patch_timeout.py`:** `patch_dq.py` у `cf-dq` включён в seed
этой же сессией (см. `reference/code/cf-dq/MANIFEST.md`) как **провенанс уже применённого T-1-фикса**,
явно опознанный отдельным discovery (`DQ-SOURCE-CAPTURE`, `reference/dq_source_capture_2026-08-02.md §6`).
Для `patch_code.py`/`patch_timeout.py` cf-facts такого документированного статуса провенанса нет —
это неотличимо от разового рабочего скрипта правки на месте, поэтому применено правило по умолчанию
(`ADR-040`, «разовые patch-скрипты» = мусор), не исключение.

## Итог по критерию приёмки

Снята точка входа (`main.py`) и все прямые зависимости (`bq_ops.py`, `config.py`, `fetch_byvariant.py`,
`fetch_demands.py`, `fetch_purchases.py`, `fetch_returns.py`, `helpers.py`, `requirements.txt`) плюс
deploy-документация (`deploy_and_workflow.sh`). sha256 — прямой с диска после распаковки, не
транскрипция. Способ снятия — **прямой** (`gcloud functions describe` без `403` в этой попытке), архив
скачан с закреплённым `generation`. Мусор (`.DS_Store`, три `.bak`, два разовых patch-скрипта,
самореференциальный `src.zip`) в seed не включён, перечислен полностью выше.

---

## Cloud Workflows — `DQ-GATE-SCOPE-SPLIT-DEPLOY` (2026-08-05, класс B, мандат `ADR-122 §5`)

**Что зафиксировано:** соответствие «ревизия ↔ коммит» для деплоя патча периметра DQ Gate (перенос
`step_purchases`/`step_returns` на позицию сразу после `step_facts`, перед `step_dq`) на два живых
Cloud Workflows. Процедура — `05_CONVENTIONS §Процедура деплоя … вариант Б`, распространённая на
Workflows двумя подстановками (`reference/dq_gate_deploy_adj_2026-08-04.md §5`): read-back —
`describe --format=json` → поле `sourceContents` (не `--format="value(sourceContents)"`, тот
добавляет собственный перевод строки в конце потока — не факт о содержимом объекта, найдено этой
сессией при первой сверке hourly).

| Объект | Ревизия до | Ревизия после | `updateTime` (UTC) | sha256 `sourceContents` (после) |
|---|---|---|---|---|
| `msklad-pipeline-hourly` | `000003-f02` | **`000004-5fc`** | `2026-08-05T05:16:54.045332507Z` | `821edbeef502d786b2345219a01f0f7c2cee36d8d0b184a7ac63b85395eac47f` |
| `msklad-pipeline-weekly` | `000003-fa9` | **`000004-6bf`** | `2026-08-05T05:17:59.298028382Z` | `9b7fcee08a2f2b46704c3b7aa8d83a26317260c6e79bb675e712ae76884d1647` |

Оба sha256 совпали с заранее объявленными в мандате (`ADR-122 §5`, `reference/dq_gate_deploy_adj_2026-08-04.md §3`)
до деплоя — read-back точный, не приблизительный.

**Код-репозиторий `holika-prod`:**
- Seed (исходный текст задеплоенных ревизий `000003-f02`/`000003-fa9`, форма `ADR-094 §1`) —
  коммит `f293555` в `master`.
- Патч (перенос позиции шагов, перенесён по diff против снимка `2026-08-02`, не копированием) —
  коммит `e79bef6` в ветке `deploy/workflows-2026-08-05-dq-scope-split`.
- Слияние в `master` — коммит `6a581bf` (`merge --no-ff`), после успешного read-back и функциональной
  проверки на живом прогоне hourly.
- Каталог `workflows/` — верхнего уровня, не внутри `cf-facts/` (`ADR-040`, во избежание захвата YAML
  следующим `--source=cf-facts/`).

**Функциональная проверка (Шаг 7, живой прогон hourly, execution `a28be854-7211-42e4-a723-a1aa70c8752e`):**
`startTime=2026-08-05T06:00:02Z`, `endTime=2026-08-05T06:05:57Z`, `state=SUCCEEDED`. Прикладной лог
`mode=` от `cf-facts` в этом окне отсутствует (гэп наблюдения, `★ Успех инструмента ≠ факт` —
не выдаётся за факт). Порядок исполнения восстановлен по HTTP-логам `cloud_run_revision` (запись
`step7_http_calls_check.log`): `cf-dim 06:00:02 → cf-fx 06:01:03 → cf-facts 06:01:07 (55s, step_facts)
→ cf-facts 06:02:02 (219s, единственный оставшийся кандидат на step_purchases по числу и позиции
вызовов в уже read-back-подтверждённом YAML) → cf-dq 06:05:41 (4s) → cf-facts 06:05:46 (11s,
step_promote) → done`. Третий вызов `cf-facts` (`step_purchases`) заканчивается в `06:05:41`, ровно
когда начинается `cf-dq` — то есть **до** `step_dq`, что и требовалось патчем. Полные логи —
`reference/_scratch_DQ-GATE-SCOPE-SPLIT-DEPLOY_2026-08-05/step7_*`.

**Откат (не понадобился):** повторный `gcloud workflows deploy` исходным текстом ревизий
`000003-f02`/`000003-fa9` — текст сохранён в seed-коммите `f293555` и в снимке `2026-08-02`
(`reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02/step2_{hourly,weekly}_workflow.yaml`).

---

## Деплой `cf-facts` — периметр продаж (2026-08-07, класс B, мандат владельца в чате)

**Что зафиксировано:** соответствие «ревизия ↔ коммит» для патча периметра продаж (`entity/retaildemand`
+ `entity/commissionreportin`, режимы `perimeter`/`perimeter_promote`; исключение выручки по отгрузке
комиссионеру в `fetch_demand_positions`), задача `SALES-INGEST-PATCH-DEPLOY`. Процедура —
`05_CONVENTIONS §Процедура деплоя … вариант Б` (`reference/deploy_procedure_2026-08-03.md`).

| Поле | До | После |
|---|---|---|
| Ревизия `cf-facts` | `cf-facts-00007-xir` | **`cf-facts-00008-zen`** |
| `generation` архива | `1782334223015697` | **`1786093276804812`** |
| `updateTime` (UTC) | `2026-07-30T10:04:58.768334396Z` | **`2026-08-07T09:02:36.835840920Z`** |

**Read-back (шаг 7):** архив новой ревизии скачан по закреплённому `generation`, распакован, sha256
всех 11 файлов сверен побайтово с веткой `deploy/cf-facts-2026-08-07-perimeter` — совпадение полное
(единственное отличие — `.gcloudignore`, который в развёрнутый архив закономерно не попадает). Мусора
(`.bak`/`__pycache__`/`.DS_Store`/`src.zip`/разовые patch-скрипты) в новом архиве нет. Полный лог —
`reference/_scratch_SALES-INGEST-PATCH-DEPLOY_2026-08-07/step7_run.log`.

sha256 изменённых файлов (новая ревизия):

| Файл | sha256 |
|---|---|
| `bq_ops.py` | `8ba26524bab9fc01cb9e6ee77f7d6e65f1bc21062f1160812749461d02c7f5aa` |
| `config.py` | `56e77eff536ce8fe2a1c3a015c2633ed1317e8a9cbbd9729165d5a7af38de63a` |
| `fetch_demands.py` | `a7f2c9042828fcf2143027fe9292b3f7995f3e7a5364e711fb39e79166bddf72` |
| `fetch_perimeter.py` (новый) | `2afc6a62ed7e52d1c7756135fc950d7519b286bb2c8fb996b353e920a008815c` |
| `main.py` | `97b9ce3aa54085aab0739fd315890db22be8c837e829a9170ebce385ba6642d8` |

**Функциональная проверка (шаг 8, существующие режимы):** живой прогон `hourly`
(`run_id=verify_deploy_2026-08-07_hourly`) — `status=ok`, `demand_positions_fetched=375`,
`staging_rows_loaded=375`, ни одной ошибки. Лог исключения комиссионных отгрузок в этом окне
(2026-07-31…2026-08-07) не появился, потому что в сыром ответе МойСклада за это окно нет ни одной
позиции трёх комиссионных контрагентов (проверено прямым поиском по скачанному
`run_verify_deploy_2026-08-07_hourly.ndjson.gz`) — гэп наблюдения, не признак поломки: событие редкое
(единицы документов на всю историю). Остальные режимы (`promote`/`weekly`/`returns`/`purchases`)
кодово не тронуты патчем (sha256 `fetch_purchases.py`/`fetch_returns.py`/`helpers.py` не изменился) —
не прогонялись отдельно.

**Функциональная проверка (шаг 9, новые режимы, порядок staging → core соблюдён):**

- **9а, `perimeter` (staging).** `run_id=verify_deploy_2026-08-07_perimeter`, окно 90 суток
  (`2026-05-09…2026-08-07`). Клиент `gcloud` оборвался по таймауту (300с), сервер отработал успешно
  (`200`, `368,9s`, подтверждено `gcloud logging read` по `httpRequest`) — слепой повтор не делался,
  дождались подтверждения. Загружено в `stg_msklad.fact_sales_perimeter_staging`: `retaildemand` —
  506 документов / 1441 строка / `1 188 422,00` KGS (**точное совпадение** с ранее измеренным
  `reference/parity_sales_discriminate_step2_2026-08-02.md`); `commissionreportin_sale` — 24 документа
  / 4026 строк / `11 514 572,13` KGS (маштаб пропорционален измеренному маю: 7 док/`2 133 028,08` KGS
  за месяц против 24 док за три месяца — самостоятельного полнозонного эталона для этой величины в
  реестре нет, отдельного расхождения не найдено).
- **9б, `perimeter_promote` (core), ТОЛЬКО после 9а.** До MERGE: `core.fact_sales_profit` за 90 суток —
  `7 062` строки / `293 325 096,84` KGS. Команда отчиталась `affected_rows=5467`. Read-back прямым
  запросом (не по отчёту команды): после MERGE — `12 529` строк / `306 028 090,97` KGS; арифметика
  `7 062 + 5 467 = 12 529` и `293 325 096,84 + 12 702 994,13 = 306 028 090,97` сходится. Отдельно
  подтверждено джойном по `transaction_id`: ровно `5 467` новых строк в `core` соответствуют
  `stg_msklad.fact_sales_perimeter_staging`, их сумма `12 702 994,13` KGS совпадает с суммой staging
  копейка в копейку. Полные логи и запросы —
  `reference/_scratch_SALES-INGEST-PATCH-DEPLOY_2026-08-07/step9a_*`, `step9b_*`.

**Код-репозиторий `holika-prod`:**
- Ветка `deploy/cf-facts-2026-08-07-perimeter` — коммит `bfa74d4`, запушена, содержит патч,
  перенесённый по diff против `master`.
- Слияние в `master` — коммит `fbf351f` (`merge --no-ff`), выполнено и запушено ПОСЛЕ успешного
  read-back (шаг 7) и функциональных проверок (шаги 8-9), как требует процедура.

**Откат (не понадобился):** повторный деплой именем ревизии `cf-facts-00007-xir`
(`gcloud functions deploy cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod
--source=gs://gcf-v2-sources-420804682491-asia-east1/cf-facts/function-source.zip#1782334223015697 ...`)
плюс, если понадобится откатить данные, удаление строк `core.fact_sales_profit` по
`transaction_id IN (SELECT TO_HEX(MD5(CONCAT(doc_id,'|',position_id))) FROM
stg_msklad.fact_sales_perimeter_staging)`.

---

## Cloud Workflows — `SALES-PERIMETER-CADENCE-DEPLOY` (2026-08-07, класс B, мандат `ADR-132`)

**Что зафиксировано:** соответствие «ревизия ↔ коммит» для подключения каденции периметра продаж
(`step_perimeter` между `step_facts` и `step_dq`; `step_perimeter_promote` после `step_promote`) к
живому `msklad-pipeline-weekly`. `msklad-pipeline-hourly` этой сессией не трогался. Процедура —
`05_CONVENTIONS §Процедура деплоя … вариант Б`, форма read-back для Workflows —
`describe --format=json` → программное извлечение `sourceContents` (прецедент
`DQ-GATE-SCOPE-SPLIT-DEPLOY`).

| Объект | Ревизия до | Ревизия после | `updateTime` (UTC) | sha256 `sourceContents` (после) |
|---|---|---|---|---|
| `msklad-pipeline-weekly` | `000004-6bf` | **`000005-124`** | `2026-08-07T14:07:30.884386952Z` | `a1a58a2f385ac1d32c488cae45134c08ed9f3e1097bb808eb2d0253527115ff8` |
| `msklad-pipeline-hourly` | `000004-5fc` | `000004-5fc` (не тронут) | `2026-08-05T05:16:54.045332507Z` | не менялся |

**Шаг 1 (снимок ДО правки, побайтовая сверка с `master`):** живая `sourceContents` ревизии
`000004-6bf` (sha256 `9b7fcee08a2f2b46704c3b7aa8d83a26317260c6e79bb675e712ae76884d1647`) побайтово
совпала с `workflows/msklad-pipeline-weekly.yaml` в `master` код-репо на момент `2026-08-07T14:04Z` —
дрейфа не найдено. Полный лог — `reference/_scratch_SALES-PERIMETER-CADENCE-DEPLOY_2026-08-07/step1_snapshot_and_diff.log`.

**Шаг 6 (read-back после деплоя):** sha256 read-back'а sourceContents ревизии `000005-124`
(`a1a58a2f...`) побайтово совпал с текстом ветки `deploy/workflows-2026-08-07-perimeter-cadence`.
Порядок шагов подтверждён программно: `step_dim → step_fx → step_facts → step_purchases →
step_returns → step_perimeter → step_dq → parse_dq_result → check_dq → step_promote →
step_perimeter_promote → done`. YAML валиден (`pyyaml`). `msklad-pipeline-hourly` подтверждён
неизменённым (`describe` вернул ту же ревизию/`updateTime`, что и до деплоя). Полный лог —
`reference/_scratch_SALES-PERIMETER-CADENCE-DEPLOY_2026-08-07/step6_readback.log`.

**Функциональная проверка (шаг 7).** Мандат `ADR-132 §5` не покрывает принудительный ручной прогон
`perimeter`/`perimeter_promote` — не выполнялся. Проверка ограничена тем, что не требует ручного
вызова: подтверждён синтаксис/структура/порядок развёрнутого текста программно (см. шаг 6 выше).
Живой прогон новых шагов дождётся штатного расписания (`msklad-pipeline-weekly`, `0 1 * * 0`, UTC) —
следующий прогон и его лог остаются задачей следующей сессии, не этой.

**Код-репозиторий `holika-prod`:**
- Ветка `deploy/workflows-2026-08-07-perimeter-cadence` — коммит `1ef452c`, запушена, патч перенесён
  копированием полного файла-снапшота (снапшот на шаге 1 подтверждён идентичным живому тексту плюс
  ровно два новых шага — дрейфа между копированием и diff нет).
- Слияние в `master` — коммит `0c5f68e` (`merge --no-ff`), выполнено и запушено ПОСЛЕ успешного
  read-back (шаг 6).
- Каталог `workflows/` — верхнего уровня код-репо, как у прецедента `DQ-GATE-SCOPE-SPLIT-DEPLOY`.

**Откат (не понадобился):** повторный `gcloud workflows deploy msklad-pipeline-weekly` текстом
ревизии `000004-6bf`, сохранённым до деплоя в
`reference/_scratch_SALES-PERIMETER-CADENCE-DEPLOY_2026-08-07/step1_weekly_live_source.yaml`
(sha256 `9b7fcee0...`).

---

## Деплой `cf-facts` — метка канала периметра продаж (2026-08-07, класс B, мандат `ADR-135`)

**Что зафиксировано:** соответствие «ревизия ↔ коммит» для патча метки канала периметра продаж
(`entity/retaildemand` → «Розница», `entity/commissionreportin` → «Комиссия», константа по типу
документа, `ADR-134`), задача `SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY`. Деплой ПОВЕРХ базы
`cf-facts-00008-zen` (периметр продаж уже был расширен предыдущим деплоем
`SALES-INGEST-PATCH-DEPLOY`). Процедура — `05_CONVENTIONS §Процедура деплоя … вариант Б`
(`reference/deploy_procedure_2026-08-03.md`).

| Поле | До | После |
|---|---|---|
| Ревизия `cf-facts` | `cf-facts-00008-zen` | **`cf-facts-00009-tul`** |
| `generation` архива | `1786093276804812` | **`1786115536540209`** |
| `updateTime` (UTC) | `2026-08-07T09:02:36.835840920Z` | **`2026-08-07T15:13:10.253085704Z`** |

**Шаг 1 (свежая сверка перед деплоем):** живая ревизия перед деплоем подтверждена той же
(`cf-facts-00008-zen`, `generation 1786093276804812`, `updateTime` не изменился) — дрейфа между
сессиями нет. Лог — `reference/_scratch_SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY_2026-08-07/step0_run.log`.

**Read-back (шаг 7):** архив новой ревизии скачан по закреплённому `generation`, распакован, sha256
всех 11 файлов сверен побайтово с веткой `deploy/cf-facts-2026-08-07-channel` — совпадение полное
(единственное отличие — `.gcloudignore`, который в развёрнутый архив закономерно не попадает). Мусора
(`.bak`/`__pycache__`/`.DS_Store`/`src.zip`/разовые patch-скрипты) в новом архиве нет. Полный лог —
`reference/_scratch_SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY_2026-08-07/step7_run.log`.

sha256 изменённых файлов (новая ревизия):

| Файл | sha256 |
|---|---|
| `bq_ops.py` | `637074e5b2d75cea647e3e65acd952b84593e8eb2cf2807c9b4cd4123d9f7e6b` |
| `fetch_perimeter.py` | `f609d5656fe6cf79941ffb3c904a122afabe2f5b7633a846a7f5ae713314275e` |

Незатронутые файлы (`config.py`/`main.py`/`fetch_demands.py`/`fetch_purchases.py`/`fetch_returns.py`/
`helpers.py`/`requirements.txt`/`deploy_and_workflow.sh`) — sha256 идентичен предыдущей ревизии
`cf-facts-00008-zen`, кодово не тронуты.

**Функциональная проверка (шаг 8, существующие режимы):** живой прогон `hourly`
(`run_id=verify_deploy_2026-08-07_channel_hourly`) — `status=ok`, `demand_positions_fetched=403`,
`staging_rows_loaded=403`, ни одной ошибки. Лог —
`reference/_scratch_SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY_2026-08-07/step8_run.log`.

**Функциональная проверка (шаг 9, новые режимы, порядок staging → core соблюдён):**

- **9а, `perimeter` (staging).** `run_id=verify_deploy_2026-08-07_channel_perimeter`. Клиент `gcloud`
  оборвался по таймауту (client-side), сервер отработал успешно — подтверждено прямым опросом
  `stg_msklad.fact_sales_perimeter_staging`, слепой повтор не делался. Загружено: `retaildemand` —
  506 документов / 1441 строка / `1 188 422,00` KGS; `commissionreportin_sale` — 24 документа / 4026
  строк / `11 514 572,13` KGS. **Точное совпадение** с `MANIFEST.md` §«Деплой `cf-facts` — периметр
  продаж (2026-08-07)» §9а — периметр отбора документов не изменился, эта задача его не расширяет.
  `sales_channel_name` заполнено «Розница»/«Комиссия» по типу документа, `sales_channel_id` = `NULL`
  у обоих типов — подтверждено прямым запросом. Полные логи и запросы —
  `reference/_scratch_SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY_2026-08-07/step9a_*`.
- **9б, `perimeter_promote` (core), ТОЛЬКО после 9а.** До MERGE: `core.fact_sales_profit` итого —
  `42 784` строки / `691 376 392,83` KGS; строк периметра (join по
  `transaction_id = TO_HEX(MD5(CONCAT(doc_id,'|',position_id)))` против свежего снимка staging) —
  `5 467`, у всех `sales_channel_name = NULL` (наследие прошлого прогона `SALES-INGEST-PATCH-DEPLOY`,
  когда метки не было). Команда отчиталась `affected_rows=5467`. Read-back прямым запросом (не по
  отчёту команды): после MERGE — итого `core.fact_sales_profit` не изменился (`42 784` строки /
  `691 376 392,83` KGS — MERGE только обновил существующие строки, новых не добавил).
  **ГЛАВНОЕ ЧИСЛО:** разрез `sales_channel_name` по периметру ПОСЛЕ — `4 026` строк «Комиссия» +
  `1 441` строка «Розница» = `5 467`; `NULL` упал **с 5 467 до 0**. Сумма периметра
  `12 702 994,13` KGS не изменилась до/после. Полные логи и запросы —
  `reference/_scratch_SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY_2026-08-07/step9b_*`.

**Код-репозиторий `holika-prod`:**
- Ветка `deploy/cf-facts-2026-08-07-channel` — коммит `84d6f71` (подготовлена и запушена предыдущей
  сессией), содержит патч, перенесённый по diff против `master`.
- Слияние в `master` — коммит `7e039bd` (`merge --no-ff`), выполнено и запушено ПОСЛЕ успешного
  read-back (шаг 7) и функциональных проверок (шаги 8-9), как требует процедура.

**Откат (не понадобился):** повторный деплой именем ревизии `cf-facts-00008-zen`
(`gcloud functions deploy cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod
--source=gs://gcf-v2-sources-420804682491-asia-east1/cf-facts/function-source.zip#1786093276804812 ...`)
плюс, если понадобится откатить данные, `UPDATE core.fact_sales_profit SET sales_channel_id=NULL,
sales_channel_name=NULL WHERE transaction_id IN (SELECT TO_HEX(MD5(CONCAT(doc_id,'|',position_id)))
FROM stg_msklad.fact_sales_perimeter_staging WHERE run_id='verify_deploy_2026-08-07_channel_perimeter')`
(строки не создавались этим патчем, только помечались — откат данных не требует DELETE).

---

## Деплой `cf-facts` — сотрудник-владелец документа (2026-08-08, класс B, мандат `ADR-146`)

**Что зафиксировано:** соответствие «ревизия ↔ коммит» для патча `document_owner_employee_id`
(`ADR-128` база + `ADR-136 §2` доработка `UPDATE SET`), задача `SALES-DOCUMENT-OWNER-DEPLOY`. Деплой
ПОВЕРХ базы `cf-facts-00009-tul`. Предусловие — `ALTER TABLE core.fact_sales_profit ADD COLUMN
document_owner_employee_id STRING` (`ADR-136 §4(1)`). Процедура — `05_CONVENTIONS §Процедура деплоя …
вариант Б` (`reference/deploy_procedure_2026-08-03.md`).

| Поле | До | После |
|---|---|---|
| Ревизия `cf-facts` | `cf-facts-00009-tul` | **`cf-facts-00010-mog`** |
| `generation` архива | `1786115536540209` | **`1786194676108292`** |
| `updateTime` (UTC) | `2026-08-07T15:13:10.253085704Z` | **`2026-08-08T13:12:55.988390080Z`** |

**Разделение двух патчей одного файла (`ADR-145`):** снапшот `cf-facts/bq_ops.py` нёс вперемешку эту
задачу и незадеплоенный `SALES-REFRESH-WINDOW` (`ADR-144 §8`). Разделение — механическое по хункам, не
редакторское (`ADR-145 §1`): в ветку деплоя вошли ровно 5 хунков `bq_ops.py` + весь `fetch_demands.py`
(3 места правки), хунки `SALES-REFRESH-WINDOW` (ветки `WHEN NOT MATCHED BY SOURCE … THEN DELETE` в
обоих `MERGE`) в ветку не попали — подтверждено sha256-сверкой и прямым `grep` архива после деплоя
(`WHEN NOT MATCHED BY SOURCE` в развёрнутом `bq_ops.py` отсутствует).

**Шаг 1 (свежая сверка перед деплоем):** живая ревизия перед деплоем подтверждена той же
(`cf-facts-00009-tul`, `generation 1786115536540209`) — дрейфа между сессиями нет.

**`ALTER TABLE` (шаг 6a-6b):** отсутствие колонки в `core.fact_sales_profit` подтверждено ДО (22
колонки, `document_owner_employee_id` отсутствует), `ALTER TABLE … ADD COLUMN document_owner_employee_id
STRING` исполнен, колонка присутствует ПОСЛЕ (23 колонки, тип `STRING`). Логи —
`reference/_scratch_SALES-DOCUMENT-OWNER-DEPLOY_2026-08-08/step6a.log`, `step6b.log`.

**Read-back (шаг 8):** архив новой ревизии скачан по закреплённому `generation`, распакован, sha256
всех 11 файлов сверен побайтово с веткой `master` (после слияния) — совпадение полное (два изменённых
файла — `bq_ops.py`, `fetch_demands.py` — идентичны ветке деплоя `deploy/cf-facts-2026-08-08-document-
owner`; девять незатронутых файлов идентичны предыдущей ревизии). Мусора в архиве нет. Логи —
`reference/_scratch_SALES-DOCUMENT-OWNER-DEPLOY_2026-08-08/step7_deploy.log`, `step8_readback.log`.

sha256 изменённых файлов (новая ревизия):

| Файл | sha256 |
|---|---|
| `bq_ops.py` | `e8bb06596bc64a22889890cff583a2d8ed8325ef4c5941d48a8769c2e18c90d8` |
| `fetch_demands.py` | `b092863efa75346208ee4aa8aa7cde60be42024415638386f76ec6fc96bcf358` |

Незатронутые файлы (`config.py`/`main.py`/`fetch_byvariant.py`/`fetch_perimeter.py`/
`fetch_purchases.py`/`fetch_returns.py`/`helpers.py`/`requirements.txt`/`deploy_and_workflow.sh`) —
sha256 идентичен предыдущей ревизии `cf-facts-00009-tul`, кодово не тронуты.

**Функциональная проверка (шаг 9, существующие режимы):** живой прогон `hourly`
(`run_id=verify_deploy_2026-08-08_document_owner_hourly`) — `status=ok`, `demand_positions_fetched=350`,
`staging_rows_loaded=350`, все 350 строк staging несут `document_owner_employee_id`. Незатронутые
режимы (`returns`/`purchases`/`perimeter`/`perimeter_promote`) отдельно не прогонялись — их файлы
кодово не менялись (sha256 идентичен). Лог — `step9_hourly.log`, `step9b_staging_check.log`.

**Функциональная проверка (шаг 10, обязательный `weekly`/`window_days=90`):** первая попытка
(`run_id=…_weekly`) — клиент `gcloud` оборвался по таймауту (`ReadTimeout`, 300с), сервер по логам
`httpRequest` отработал `status=200`/`latency=465.97s`, но staging был перезаписан штатным часовым
пайплайном (`WRITE_TRUNCATE`, общая таблица) раньше, чем эта сессия успела промоутнуть — гонка, не
порча данных (у этого патча нет ветки удаления). Вторая попытка (`run_id=…_weekly_retry2`) —
тот же клиентский таймаут, сервер подтверждён `status=200`/`latency=460.15s` (`receiveTimestamp
2026-08-08T14:22:47Z`), staging проверен read-only ДО промоута — `7 033` строки, окно
`2026-05-10…2026-08-08`, все с `document_owner_employee_id`. `promote` (`window_days=90`,
`run_id=verify_deploy_2026-08-08_document_owner_promote`) исполнен сразу после подтверждения —
`status=ok`, `affected_rows=7033`, `staging_rows=7033`. Логи —
`step10b_weekly_load.log`…`step10l_after.log` (полная цепочка диагностики и повтора).

**Прямые запросы приёмки (до/после `promote`):**
- **Июль-2026, `document_owner_employee_id`:** `4 707` строк итого, заполнено `0` → **`2 912`**.
- **Май-2026 (условие 3 мандата, `ADR-146 §5(3)`):** `3 300` строк / `96 471 991,41` KGS — **до и после
  идентично**, разность `0,00`. Датированный снимок мая не затронут.
- **Свод `core.fact_sales_profit` после:** `42 789` строк / `691 534 086,33` KGS.

**Код-репозиторий `holika-prod`:**
- Ветка `deploy/cf-facts-2026-08-08-document-owner` — коммит `3248e62` (два патч-коммита `f88c355` +
  правка комментария `df26233`→`3248e62` по каноническому тексту снапшота, `ADR-146 §5(1)`), содержит
  ровно 5 хунков `bq_ops.py` + весь `fetch_demands.py`, перенесённые механически по хункам (`ADR-145`).
- Слияние в `master` — коммит `e9a4cbb` (`merge --no-ff`), выполнено ПОСЛЕ успешного read-back (шаг 8)
  и функциональных проверок (шаги 9-10), как требует процедура.

**Откат (не понадобился):** код — повторный деплой именем ревизии `cf-facts-00009-tul`. Схема —
`ALTER TABLE core.fact_sales_profit DROP COLUMN document_owner_employee_id` (колонка новая,
потребителей нет, откат безопасен и независим от отката кода) — только по отдельному решению
владельца (`ADR-146 §3`), этим деплоем не исполнялся.

---

## Деплой `cf-facts` — дата документа по Asia/Bishkek, возвраты и закупки (2026-08-09, класс B, мандат `ADR-147`)

**Что зафиксировано:** соответствие «ревизия ↔ коммит» для патча `INGEST-MOMENT-ZONE-FIX` (объект A):
`_parse_moment_kgt`/`_parse_date_kgt` в `fetch_returns.py`/`fetch_purchases.py` заменены на
`parse_moment_to_bishkek_date` (`helpers.py`) — UTC-время документа МойСклада конвертируется в
бишкекские сутки (`+6ч`), а не берётся срезом первых 10 символов строки (`Q-77`/`ADR-088 §4`).
Деплой ПОВЕРХ базы `cf-facts-00010-mog`. Процедура — `05_CONVENTIONS §Процедура деплоя … вариант Б`
(`reference/deploy_procedure_2026-08-03.md`); полный разбор гейтов и объём — `reference/ingest_moment_zone_fix_mandate_2026-08-09.md`.

| Поле | До | После |
|---|---|---|
| Ревизия `cf-facts` | `cf-facts-00010-mog` | **`cf-facts-00011-mab`** |
| `generation` архива | `1786194676108292` | **`1786273160918659`** |
| `updateTime` (UTC) | `2026-08-08T13:12:55.988390080Z` | **`2026-08-09T11:00:22.511597469Z`** |

**Шаг 1 (свежая сверка перед деплоем):** живая ревизия перед деплоем подтверждена той же
(`cf-facts-00010-mog`, `generation 1786194676108292`) — дрейфа между сессиями нет; sha256 всех
шести затронутых/смежных файлов (`helpers.py`, `fetch_returns.py`, `fetch_purchases.py`, `main.py`,
`bq_ops.py`, `config.py`) живой ревизии совпал побайтово с `master` код-репо ДО начала работы
(`step1_run.log`) — ловушка §2 мандата (недеплоенный `SALES-REFRESH-WINDOW` в `bq_ops.py`) не
сработала: `bq_ops.py` в ветку не переносился, sha256 не менялся.

**Read-back (шаг 6):** архив новой ревизии скачан по закреплённому `generation`, распакован, sha256
всех семи файлов сверен побайтово с веткой `deploy/cf-facts-2026-08-09-moment-zone` — совпадение
полное. Мусора (`.bak`/`__pycache__`/`.DS_Store`/`src.zip`/разовые patch-скрипты) в архиве нет.
Логи — `reference/_scratch_INGEST-MOMENT-ZONE-FIX-DEPLOY_2026-08-09/step5_run.log`, `step6_run.log`.

sha256 изменённых файлов (новая ревизия):

| Файл | sha256 |
|---|---|
| `helpers.py` | `c1d5f0594a46f176dad33afffb3944fae378148cd7d27b0bd2c81230d020dd21` |
| `fetch_returns.py` | `7f3dcefadb0de4782d9f09964f5c5baf5d423375406c1f6f2846356ddd663bd1` |
| `fetch_purchases.py` | `159e498789168b0206beca15bf719e3541a2564ec93d786abec8ed7860befafb` |

Незатронутые файлы (`main.py`/`bq_ops.py`/`config.py`/`requirements.txt`) — sha256 идентичен
предыдущей ревизии `cf-facts-00010-mog`, кодово не тронуты.

**Функциональная проверка (шаг 7, режимы `returns`/`purchases`, прямая запись в `core`, не
staging).** Клиент `gcloud functions call` оборвался клиентским `ReadTimeout` (300с) на вызове
`purchases` — слепой retry не делался: факт завершения проверен read-only по целевым таблицам, не
по логу клиента (`★ Успех инструмента ≠ факт`).

- `mode=returns`, `window_days=100` (окно `2026-05-01…2026-08-09`, покрывает зону паритета):
  ответ функции `status=ok`, `return_positions_fetched=104`, `rows_loaded=104`. Read-back —
  `core.fact_returns._loaded_at = 2026-08-09 11:14:59`, `104` строки.
- `mode=purchases` (полный рефреш): клиентский таймаут, сервер подтверждён `httpRequest status=200`
  (`gcloud logging read`). Read-back — `core.fact_purchases._loaded_at = 2026-08-09 11:15:08`,
  `4 424` строки (порядок величины совпадает с докстрингом функции, `~2-5К` строк).

**Замер «до/после» по трём сверенным парам реестра (Условие 2 мандата):**

| Пара | До | После | Вывод |
|---|---|---|---|
| `marts.expenses`, май-2026 (`ADR-006`) | `10 232 903,20` KGS | не пересчитывался (объект B, отдельный деплой) | без изменений, как и ожидалось |
| `core.fact_returns`, май-2026, `SUM(sum_kgs)` (`ADR-114 §2`, эталон `570,00`) | `570,00` KGS, 8 строк | `570,00` KGS, 8 строк | **без изменений** — ни один майский документ не попал в полосу `UTC [18:00;24:00)` на границе месяца |
| `core.fact_purchases`, «Заказы поставщикам в пути» (`ADR-124`, эталон `Δ=0`, периметр «не Прибыл», `251` позиция, `78 184 949,425` KGS) | не измерялось этой сессией дословно (запрос `PARITY-STOCK-INTRANSIT-RECHECK` не воспроизводился) | не измерялось тем же способом | **CONTEXT GAP** — грубые агрегаты по всей таблице (`4 424` строки, `1 115 276 641,421` KGS) с периметром `ADR-124` не сопоставимы напрямую; точную сверку пары подтверждает архитектор отдельным запросом |

**Замер «до» по Условию 1 мандата** (полоса `TIME(moment)>=18:00 UTC`, `fact_loss`/`fact_commissionreportin`,
вне scope объекта A, относится к объекту B) — `step2_run.log`: `commission` — `14/193` строк в полосе,
месячные суммы май/июль по обеим формулам совпали (граница месяца не задета); `loss` — `7/131`, то же.

**Код-репозиторий `holika-prod`:**
- Ветка `deploy/cf-facts-2026-08-09-moment-zone` — коммит `239e571`, запушена, патч перенесён по diff
  против `master` (три файла, ровно как в мандате).
- Слияние в `master` — коммит `508ca64` (`merge --no-ff`), выполнено и запушено ПОСЛЕ успешного
  read-back (шаг 6) и функциональной проверки (шаг 7), как требует процедура.

**Откат (не понадобился):** код — повторный деплой именем ревизии `cf-facts-00010-mog`
(`gcloud functions deploy cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod
--source=gs://gcf-v2-sources-420804682491-asia-east1/cf-facts/function-source.zip#1786194676108292 ...`).
Данные — откат кода сам по себе даты не возвращает (мандат `§3`): обязателен повторный прогон
`mode=returns`/`mode=purchases` на откаченном коде (оба режима `WRITE_TRUNCATE`, полный рефреш,
откат данных полон после одного прогона).

---

## Деплой `cf-facts` — узкая форма `SALES-REFRESH-WINDOW` (2026-08-11)

**Мандат:** `ADR-159`/`ADR-158`, текст — `reference/sales_refresh_window_mandate_adj_2026-08-11.md §4`.
**Задача:** `SALES-REFRESH-WINDOW-DEPLOY` (бриф `briefs/SALES-REFRESH-WINDOW-DEPLOY.md`).
**База деплоя:** ревизия `cf-facts-00011-mab` — сверена с `master` код-репо `holika-prod` ПОБАЙТОВО
ДО правки (шаг 1, `reference/_scratch_SALES-REFRESH-WINDOW-DEPLOY_2026-08-11/step1_run.log`,
`2026-08-11T08:10:20Z…08:10:46Z`): все 10 файлов идентичны, дрейфа нет.

**Патч.** Два файла, перенесены **по diff** (не копированием) против снапшота
`reference/code/cf-facts/{bq_ops.py,config.py}`:
`reference/_scratch_SALES-REFRESH-WINDOW-DEPLOY_2026-08-11/{bq_ops.diff,config.diff}` (194 + 24
строки). Ветка `holika-prod`: `deploy/cf-facts-2026-08-11-refresh-window`, коммит `47b3a45`, push
подтверждён владельцем в чате.

**Деплой** (`step5_run.log`, `2026-08-11T08:38:15Z`): новая ревизия **`cf-facts-00012-ber`**,
`generation 1786437392633949`, `--source` указывал на каталог `cf-facts/` выкаченной ветки.

**Read-back** (`step6_run.log`, `2026-08-11T08:38:39Z…08:38:52Z`): архив несёт 11 файлов, мусора нет
(`.gcloudignore` в архив не попал, как задумано). sha256 всех 11 файлов побайтово совпадает с веткой
деплоя:

| Файл | sha256 |
|---|---|
| `bq_ops.py` | `4b672d5190bf3e2331643f496791b5a9599dd6dd47a02519dc6dc34269647892` |
| `config.py` | `005383e219c1267ee20bf034bbd6483a5613c3b45d01d96e1d0fa307939878c3` |
| `deploy_and_workflow.sh` | `2e9391517c772a03a22f6751135888796778ea0889e15f97d63ba9bafcab9d07` |
| `fetch_byvariant.py` | `88e1a13881103e0faa5ec21a5a07ddd2fc83e9cc9eb4fb9fe67a0da25fb60ff1` |
| `fetch_demands.py` | `b092863efa75346208ee4aa8aa7cde60be42024415638386f76ec6fc96bcf358` |
| `fetch_perimeter.py` | `f609d5656fe6cf79941ffb3c904a122afabe2f5b7633a846a7f5ae713314275e` |
| `fetch_purchases.py` | `159e498789168b0206beca15bf719e3541a2564ec93d786abec8ed7860befafb` |
| `fetch_returns.py` | `7f3dcefadb0de4782d9f09964f5c5baf5d423375406c1f6f2846356ddd663bd1` |
| `helpers.py` | `c1d5f0594a46f176dad33afffb3944fae378148cd7d27b0bd2c81230d020dd21` |
| `main.py` | `97b9ce3aa54085aab0739fd315890db22be8c837e829a9170ebce385ba6642d8` |
| `requirements.txt` | `0c041a8d50f4731ad71aabcf678f388c13d8ba9af6ccb6548af9ccb6fc514051` |

Изменены (`bq_ops.py`, `config.py`) — 2; незатронуты (все остальные, включая `deploy_and_workflow.sh`,
`fetch_perimeter.py`) — 9.

**Снимок до деплоя** (шаг 4, `step4_run.log`, `2026-08-11T08:33:36Z…08:33:57Z`):
`core.fact_sales_profit_snap_20260811` — `42 975` строк всего; май-2026: `3 411` строк /
`96 844 445,61` KGS; июль-2026: `4 707` строк / `112 502 581,88` KGS.

**Откат** (не понадобился): код — повторный деплой ревизии `cf-facts-00011-mab`; данные —
восстановление из снимка `core.fact_sales_profit_snap_20260811` (`CREATE OR REPLACE TABLE … CLONE`),
дополнительно time travel `168`ч.

**Секреты:** сплошной поиск по обоим `.diff` — 0 совпадений (пустая выдача не есть факт отсутствия,
`★ Успех инструмента ≠ факт`).

Первый боевой прогон и замер до/после — отдельная секция ниже, по факту исполнения шагов 8-10 брифа.

---

## Второй заход (`SALES-REFRESH-WINDOW-DEPLOY`, `2026-08-12`) — деплой исполнен, приёмка НЕ
## подтверждена, откат отложен по указанию владельца до адъюдикации архитектора

Полный провенанс — `reference/sales_refresh_window_deploy_v2_2026-08-12.md`.

**Деплой:** ветка `deploy/cf-facts-2026-08-11-refresh-window-v2` (holika-prod), коммит `9ae9a84`,
push подтверждён владельцем. Новая ревизия **`cf-facts-00014-doh`**, source generation
`1786466307902184`. Read-back: все 11 файлов архива побайтово совпали с веткой, мусора нет.
Трафик переведён на `cf-facts-00014-doh` (100%), подтверждено владельцем отдельно от деплоя.

**Приёмка (три числа мандата):**
1. Read-back архива — **выполнено** (sha256 всех 11 файлов совпал, мусора нет).
2. Разбиение таблицы (сумма частей = итог) — не измерялось отдельно в этом заходе (заменено
   точной статистикой MERGE-задания, см. п.3).
3. Сопоставление со снимком П2 по каналу «оптовая торговля» — **НЕ ноль**: MERGE-задание
   `job_id=1e698e3d-35c5-44c2-b90f-fbe852cf39a7` (`2026-08-12T05:15:55Z`) удалило `36` строк
   (`28` — «оптовая торговля», `6` — без канала, `2` — «К Глобал РФ Маркетплейсы»), вставило `27`
   (все датированы `2026-08-12`, не связаны с удалёнными). Полный список — приложение §8
   `sales_refresh_window_deploy_v2_2026-08-12.md`.

**Статус: приёмка провалена по формальному критерию мандата.** По мандату — немедленный откат;
владелец явно распорядился НЕ откатывать до адъюдикации архитектора, чтобы тот увидел полную
картину, включая причину обрыва первой попытки прогона (сон ноутбука посреди не-идемпотентной
операции). **Ветка `deploy/cf-facts-2026-08-11-refresh-window-v2` НЕ слита в `master`.** Трафик на
момент записи остаётся на `cf-facts-00014-doh` — живой риск, зафиксирован `§7` провенанс-файла.

---

## Деплой `cf-facts` — проверка полноты выгрузки с отказом + ветка удаления вариант 1
## (`SALES-REFRESH-WINDOW-DEPLOY-FINAL`, `2026-08-12`, класс B, мандат зафиксирован постфактум)

**Мандат:** владелец, чат `2026-08-12` — объединённый деплой (наблюдающая стадия A с отказом
вместо записи в лог + ветка удаления вариант 1, одним деплоем). Полный текст —
`reference/sales_refresh_window_stage_a_mandate_2026-08-12.md §4` (приёмка по нему заменена,
см. `reference/sales_refresh_window_deploy_final_adj_2026-08-12.md §1-§4`).

**База деплоя:** ревизия `cf-facts-00011-mab` — трафик проверен напрямую (`gcloud run services
describe`, `status.traffic`), а не через `functions describe` (тот отдаёт источник ПОСЛЕДНЕЙ
собранной ревизии, не обслуживающей — см. гэп П2 ниже). Sha256 всех файлов master сверены с
записанными ранее хешами `cf-facts-00011-mab` (`reference/_scratch_SALES-REFRESH-WINDOW-DEPLOY_2026-08-11/step1_run.log`) — совпадение подтверждено, коммитов в `cf-facts/` на `master`
между `2026-08-11T08:10:20Z` и деплоем не было (`git log --since`).

**Патч.** Пять файлов, скопированы из проверенного снапшота `reference/code/cf-facts/`:
`helpers.py` (отказ полноты — новый код поверх стадии A из `SALES-REFRESH-WINDOW-PROBE-PREP`),
`bq_ops.py`/`config.py`/`main.py`/`fetch_perimeter.py` (ветка удаления вариант 1, независимо
проверена — `SALES-REFRESH-WINDOW-SCOPE-VERIFY`, 8/8; `main.py` дополнительно несёт правку
докстринга по находке той же проверки). Ветка `holika-prod`:
`deploy/cf-facts-2026-08-12-completeness-and-delete`, коммит `543b6c1`, push подтверждён
владельцем в чате.

**Деплой** (`reference/_scratch_SALES-REFRESH-WINDOW-DEPLOY-FINAL_2026-08-12/step2_run.log`,
`2026-08-12T14:57:21Z…14:59:42Z`): новая ревизия **`cf-facts-00017-jon`**, `generation
1786546688061530`, `--source` указывал на каталог `cf-facts/` выкаченной ветки. Деплой отдал
новую ревизию с `0%` трафика (эта функция не авто-роутит) — трафик переведён отдельным шагом
(`step2_traffic_switch.log`, `15:17:45Z…15:18:08Z`), подтверждено владельцем отдельно от деплоя.

**Read-back** (`step2_readback.log`, `2026-08-12T16:00:40Z…16:00:50Z`): архив несёт 10 файлов
(остальное — как в предыдущей ревизии), мусора нет. Sha256 всех 10 файлов побайтово совпадает с
веткой деплоя:

| Файл | sha256 |
|---|---|
| `bq_ops.py` | `3be740b767c52447d01e3c192887a968d9e3dbd742ed617d68c3ff40704487c0` |
| `config.py` | `475a785d68e276d3ca87c17f82106a2b6c41eb2132985285cb015c6bd0a9e7c9` |
| `fetch_perimeter.py` | `07ddd1a01b7afa234bdb5db5003db6205f0bd0c6b26269fd0c267eae45d0e03b` |
| `helpers.py` | `661cc5ae8feb2166977bca155d436009573c7b085a9fb358b349d8fd5663852d` |
| `main.py` | `40fee8152969270b0a260196c26dd0cb7a95de2ca9ebfbb69f9e74667d1eb684` |
| остальные 5 файлов | не изменены — не перечислены дословно, см. `step2_readback.log` |

Изменены (`git diff --stat master`) — 5 (`bq_ops.py`, `config.py`, `fetch_perimeter.py`,
`helpers.py`, `main.py`); незатронуты — 5.

**Два гэпа наблюдения, П2 не закрыт полностью** (`★ Успех инструмента ≠ факт`, разбор —
`reference/sales_refresh_window_deploy_final_adj_2026-08-12.md §2`):
1. Первая сверка дрейфа (`p2_drift.log`) сняла архив ревизии `cf-facts-00014-doh` — это
   ПОСЛЕДНЯЯ собранная ревизия, не та, что обслуживала трафик (`cf-facts-00011-mab`);
   `functions describe` без сверки с `status.traffic` отдаёт первое под видом второго.
2. Повторная попытка по закреплённому `generation` (`p2_drift_v2.log`) архив не получила —
   `URLs matched no objects` (объект уже вычищен ротацией бакета). Побайтовое совпадение
   `master ↔ обслуживающая ревизия` установлено КОСВЕННО (сверка хешей + `git log --since`
   без коммитов в этот период), не прямым свежим съёмом.

**Приёмка переписана на три ступени** (`reference/sales_refresh_window_deploy_final_adj_2026-08-12.md`):
ступень 1 (состояние артефакта в проде) — ПРИНЯТА с двумя гэпами выше; ступень 2 (первый
промоут после снятия блокировки постороннего DQ-гейта) — ЗАКРЫТА фактом (см. ниже); ступень 3
(первый недельный прогон `2026-08-16T01:00Z`) — НЕ ИСПОЛНЕНА.

**Ступень 2, доказательство** (`step7_merge_job_stats.sh`/`step7_run2.log`,
`2026-08-12T18:11:24Z`): MERGE-задание продаж `job_id=1b1a37c6-8452-4569-a456-a076e7bcbcf5`
(`2026-08-12T18:05:11Z`, первый ЕСТЕСТВЕННЫЙ прогон после самоснятия DQ-гейта check_drift —
разбор причины блокировки и её несвязанности с этим деплоем: `…deploy_final_adj…§4`) —
`inserted=111, deleted=0, updated=373` по собственной статистике BigQuery
(`dml_statistics`), отрендеренный текст запроса несёт ветку удаления. `core.fact_sales_profit`
за `2026-08-12`: `27 → 138` строк / `1 054 231,43 → 4 240 469,93` KGS — арифметика сходится с
предпрогонным состоянием `staging` (`step6_run.log`). Расхождение со снимком
`snap_20260811_163306` осталось `34` — не выросло.

**Откат** (не понадобился): трафик — `gcloud run services update-traffic cf-facts
--to-revisions=cf-facts-00011-mab=100`, пересборка не требуется.

**Секреты:** сплошной поиск по всем файлам ветки — 0 совпадений (пустая выдача не есть факт
отсутствия, `★ Успех инструмента ≠ факт`).

**Слияние ветки `deploy/cf-facts-2026-08-12-completeness-and-delete` в `master`** — только
после ступени 3 (первый недельный прогон), решение архитектора
(`…deploy_final_adj…§8`). Не сливать до этого момента.

---

## Попытка деплоя `cf-facts` — guard-fix ф3/ф4 (2026-08-18, класс B, мандат
## `guard_fix_deploy_mandate_2026-08-18.md`) — СТОП на предусловии П3, деплой НЕ исполнялся

**Что произошло:** мандат предписывал вести ветку деплоя `deploy/cf-facts-2026-08-18-guard-
fix-f3` от `master`. Read-only проверка предусловия П3 (сверка sha256 архива обслуживающей
ревизии `cf-facts-00017-jon` против свежего `master`) показала расхождение по всем пяти
файлам, которые менял патч `SALES-REFRESH-WINDOW` (`bq_ops.py`, `config.py`,
`fetch_perimeter.py`, `helpers.py`, `main.py`): `master` не несёт коммиты `47b3a45`/
`9ae9a84`/`543b6c1` (`merge-base --is-ancestor` → `NO` для всех трёх) — они намеренно не
слиты до ступени 3 (`2026-08-23`). Полный разбор —
`reference/sales_refresh_window_guard_fix_deploy_2026-08-18.md §5/§7`.

**Что НЕ было сделано:** `git push` и `gcloud functions deploy` не вызывались ни разу. Ветка
`deploy/cf-facts-2026-08-18-guard-fix-f3` (коммит `82c5027`) существует ТОЛЬКО в локальном
клоне код-репо внутри
`reference/_scratch_SALES-REFRESH-WINDOW-GUARD-FIX-DEPLOY_2026-08-18/holika-prod/`, на
`origin` её нет (подтверждено `git ls-remote`).

**Обслуживающая ревизия** осталась `cf-facts-00017-jon, percent=100` — не менялась, откат не
требовался.

**Развилка вынесена владельцу/архитектору** (не решена этой сессией): вести ветку гард-фикса
от `deploy/cf-facts-2026-08-12-completeness-and-delete` (`543b6c1`, содержимое текущего
прода) вместо `master`, либо дождаться слияния ступени 3 и только потом деплоить от `master`.
