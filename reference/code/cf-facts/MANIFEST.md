# MANIFEST · /reference/code/cf-facts/ — снапшот исходника (SOURCE-MAP-SALES)

**Тип:** provenance-снапшот, не оракул, не прод-код.
**Источник:** задеплоенный `function-source.zip` (Cloud Storage), скачан напрямую `gcloud storage cp` — не транскрипция.
**Дата извлечения:** 2026-07-29 (сессия начата), фактический прогон скачивания — `2026-07-30T10:15:35Z`…`10:15:51Z` (после восстановления биллинга владельцем, см. session-блок §Отклонения от плана).

## Ревизия и провенанс

Функция `cf-facts` — GEN_2, регион `asia-east1`. `gcloud functions describe` для этой CF стабильно возвращал
`403`/billing-related ошибку на этой сессии (три попытки подряд, независимо от статуса биллинга — см. ниже);
поля ниже сняты эквивалентным read-only вызовом `gcloud functions list --filter="name:cf-facts" --format=json`
(тот же ресурс `Function`, та же схема) и подтверждены `gcloud run services describe cf-facts` (Cloud Run API,
gen2-функции строятся поверх Cloud Run).

| Поле | Значение | Источник |
|---|---|---|
| `revision` | `cf-facts-00007-xir` | `functions list --format=json` |
| `entryPoint` | `main` | `functions list --format=json` (`buildConfig.entryPoint`) |
| `source.storageSource` | `gs://gcf-v2-sources-420804682491-asia-east1/cf-facts/function-source.zip` (generation `1782334223015697`) | `functions list --format=json`; независимо подтверждено `run services describe` (`run.googleapis.com/build-source-location`) |
| `updateTime` | `2026-07-29T04:05:10.487996910Z` | `functions list --format=json` |
| `createTime` | `2026-05-06T08:26:29.388991725Z` | `functions list --format=json` |
| `state` | `ACTIVE` | `functions list --format=json` |
| `serviceAccountEmail` | `etl-sa@msklad-bi-prod.iam.gserviceaccount.com` | `functions list --format=json` (`serviceConfig.serviceAccountEmail`); подтверждено `run services describe` (`serviceAccountName`) |
| `uri` | `https://cf-facts-xw5u2boozq-de.a.run.app` | `functions list --format=json`; альтернативный alias `https://asia-east1-msklad-bi-prod.cloudfunctions.net/cf-facts` из `run services describe` |
| `timeoutSeconds` | `540` | `functions list --format=json` |
| `availableMemory` | `2048M` | `functions list --format=json` |
| `availableCpu` | `1` | `functions list --format=json` |
| `minInstanceCount` / `maxInstanceCount` | `1` / `5` | `functions list --format=json`; `run services describe` даёт `maxScale: '3'` в `metadata.annotations` (устаревшая аннотация, актуальное значение — `spec.template.metadata.annotations.autoscaling.knative.dev/maxScale: '5'`, оно и указано здесь) |
| `ingressSettings` | `ALLOW_ALL` | `functions list --format=json` |
| `environmentVariables` (имена) | `LOG_EXECUTION_ID=true` | `functions list --format=json` |
| `secretEnvironmentVariables` (имена, не значения) | `MSKLAD_TOKEN` ← секрет `msklad-token`, версия `latest` | `functions list --format=json` |
| Триггер | `HTTP_TRIGGER` | `run services describe` (`spec.template.metadata.annotations.cloudfunctions.googleapis.com/trigger-type`) |
| `build` | `projects/420804682491/locations/asia-east1/builds/6ac22631-8a64-4102-821f-8946a89d8eb4` | `functions list --format=json` |

## Известная аномалия сессии (не факт о коде, факт о доступе)

При старте Шага 1 три независимые read-команды (`functions describe`, `scheduler jobs list`,
`storage cp` на скачивание архива) вернули `403`/`PERMISSION_DENIED`, ссылаясь на биллинг. Прямая проверка
`gcloud billing projects describe msklad-bi-prod` подтвердила `billingEnabled: false`. Эскалировано владельцу
в чате, владелец подтвердил восстановление; повторная проверка дала `billingEnabled: true`, дальнейшие шаги
(скачивание архива, `bq query`, `bq show --transfer_config`) прошли штатно. Провенанс — в session-блоке и в
логах `step1d_describe.log`/`step1e_scheduler.log`/`step2_download.log` этой же директории `_scratch`.

## Автозапуск

Триггер — `HTTP_TRIGGER` (прямой HTTP-вызов, не Pub/Sub/Eventarc). В коде `cf-facts` нет обращения к
Cloud Scheduler API — расписание/оркестрация задаются снаружи (Workflow, судя по докстрингу `main.py:6-15`:
`workflow.yaml` с шагами `step_facts`→`step_dq`→`step_promote`(→`step_purchases`), сам `workflow.yaml`
**в этот архив не входит**, discovery его состава — `Q-13`/вне мандата этой сессии). `gcloud scheduler jobs
list` не выполнен по этой CF (не требовался после того, как выяснилось, что триггер HTTP, а не
Scheduler-специфичный OIDC-джоб типа `cf-loss-commission`; конкретный вызывающий Scheduler-job для `cf-facts`
этой сессией не идентифицирован — фиксируется как остаток, не как факт).

## Чистота архива (ADR-040)

Архив **грязный** — сверх кода и `requirements.txt` содержит:
- `fetch_demands.py.bak`, `fetch_purchases.py.bak`, `fetch_returns.py.bak` — резервные копии;
- `patch_code.py`, `patch_timeout.py` — разовые patch-скрипты;
- `deploy_and_workflow.sh` — деплой-скрипт (не рантайм-зависимость Python, но и не код функции);
- `.DS_Store` — артефакт macOS Finder;
- `src.zip` — **вложенный ZIP** с ещё одной копией исходников. Не читается кодом в рантайме
  (`grep -rn "src.zip\|src_zip\|zipfile" *.py` — 0 совпадений во всех файлах верхнего уровня) — инертен
  для исполнения. Расходится по содержимому с файлами верхнего уровня: `fetch_demands.py` внутри `src.zip`
  **не содержит** `× rate.value` (нет конвертации валюты для demand-позиций — при этом в файле верхнего
  уровня, который реально исполняется, эта строка есть, см. §Конвертация в KGS в основном артефакте),
  `helpers.py` внутри `src.zip` несёт `timeout=30` вместо `timeout=90`. Похоже на более старую версию
  исходников, случайно оставленную в архиве при упаковке. Это read-back-наблюдение, не повод чинить —
  чистка вменяется следующему деплою (`ADR-040`), эта задача деплой не производит.

Прецедент того же класса — `RQ-3`/`Q-57` на `cf-finance`.

## sha256 (из задеплоенного архива, файлы верхнего уровня — живой код)

| Файл | sha256 |
|---|---|
| `main.py` | `2b1e4519523dbe0e78520b035f5c047b18e4f348730c98de19dbe54c8b9e4da5` |
| `config.py` | `977fd82813d3487a1eb9c8cd297312d6e542be3b45fe65b45d73cc143ca3289b` |
| `helpers.py` | `aac5dee5add76513f52e8909a32925f261ad25d09ef55a1a6013f5262cd01c48` |
| `bq_ops.py` | `dad48a6eec2d80b5a3373beb5463cdd3d94ac71cef481d89f389e8a2308dc4e3` |
| `fetch_demands.py` | `637f25dba1a87a412bde7feac32a0b56a052e99c9bb8a5246e13b266b7648770` |
| `fetch_byvariant.py` | `88e1a13881103e0faa5ec21a5a07ddd2fc83e9cc9eb4fb9fe67a0da25fb60ff1` |
| `fetch_purchases.py` | `5db807fee2da21c31c5fa3aeed77e16d1a4ae04193f55831534b89c5e9158486` |
| `fetch_returns.py` | `7ce9373aa084258e45d2ba12c8f1bc2812b249958eec400c4181e4802793ae56` |
| `requirements.txt` | `0c041a8d50f4731ad71aabcf678f388c13d8ba9af6ccb6548af9ccb6fc514051` |

Файлы вне рантайма (не перенесены в этот каталог, но зафиксированы sha256 в
`reference/_scratch_SOURCE-MAP-SALES_2026-07-29/cf-facts-archive/unzipped/` как провенанс):
`fetch_demands.py.bak`, `fetch_purchases.py.bak`, `fetch_returns.py.bak`, `patch_code.py`,
`patch_timeout.py`, `deploy_and_workflow.sh`, `.DS_Store`, `src.zip` — полный список sha256 в
`reference/_scratch_SOURCE-MAP-SALES_2026-07-29/cf-facts-archive/unzipped/` (лог не входит в этот
MANIFEST, чтобы не путать «живой код» со «всем содержимым архива»).

## Сверка disk vs deployed

Файлы, перенесённые в этот каталог, скачаны **напрямую** из `gs://gcf-v2-sources-420804682491-asia-east1/
cf-facts/function-source.zip#1782334223015697` — того же самого объекта и той же generation, что указаны
в `source.storageSource` задеплоенной ревизии `cf-facts-00007-xir`. В отличие от прецедента `cf-finance`
(отдельная копия на persistent-диске Cloud Shell, требовавшая независимой сверки) здесь второй копии для
сравнения нет — архив уже и есть «то, что задеплоено» по построению команды `describe`/`list`. Отдельная
верификация «содержимое диска = содержимое деплоя» этим снапшотом не производится, потому что нет второго
диска — снят только сам задеплоенный артефакт.

## Известное открытое (не блокирует, для памяти)

- `gcloud functions describe cf-facts` не отработал ни разу за сессию (3 попытки, все `403` с формулировкой
  про биллинг) — не переверено после восстановления биллинга владельцем (переверка не входила в мандат,
  метаданные уже сняты эквивалентным путём). Если понадобится точный `describe`-YAML — можно перезапустить.
- Конкретный вызывающий Cloud Scheduler job для `cf-facts` (аналог `loss-commission-daily-update` у
  `cf-loss-commission`) не идентифицирован этой сессией — `workflow.yaml` вне архива, `scheduler jobs list`
  не сужался по имени `cf-facts` до восстановления биллинга и не переисполнялся после (не входил в шаги
  брифа буквально — брифовый Шаг 1 запрашивал `describe`, не `scheduler jobs list`; последний добавлен
  этой сессией как побочная диагностика при первичном investigatiоn биллинг-аномалии).
- Архив грязный (см. §Чистота архива) — чистка вменяется следующему деплою, не этой задаче.
