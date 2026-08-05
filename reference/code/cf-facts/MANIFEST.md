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
