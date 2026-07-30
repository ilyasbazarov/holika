# MANIFEST · /reference/code/cf-inventory/ — снапшот исходника (SOURCE-MAP-REST)

**Тип:** provenance-снапшот, не оракул, не прод-код.
**Источник:** задеплоенный `function-source.zip` (Cloud Storage), скачан напрямую `gcloud storage cp` — не транскрипция.
**Дата извлечения:** 2026-07-30, прогон `2026-07-30T10:47:33Z`…`10:47:49Z` (`date -u`, скрипт
`reference/_scratch_SOURCE-MAP-REST_2026-07-30/step2_snapshot_cf_inventory.sh`).

## Ревизия и провенанс

| Поле | Значение | Источник |
|---|---|---|
| `revision` | `cf-inventory-00003-vuf` | `gcloud functions describe cf-inventory --gen2 --region=asia-east1` |
| `entryPoint` | `main` | `buildConfig.entryPoint` |
| `source.storageSource` | `gs://gcf-v2-sources-420804682491-asia-east1/cf-inventory/function-source.zip` (generation `1778486115150159`) | `buildConfig.source.storageSource` |
| `createTime` | `2026-05-07T09:09:33.031784952Z` | describe |
| `updateTime` | `2026-07-30T10:04:58.467601786Z` | describe |
| `state` | `ACTIVE` | describe |
| `serviceAccountEmail` | `etl-sa@msklad-bi-prod.iam.gserviceaccount.com` | `serviceConfig.serviceAccountEmail` |
| `uri` | `https://cf-inventory-xw5u2boozq-de.a.run.app` | `serviceConfig.uri` |
| `region` | `asia-east1` | `gcloud functions list --filter="name:cf-inventory"` (Шаг 1) |
| `timeoutSeconds` | `540` | describe |
| `availableMemory` | `512M` | describe |
| `availableCpu` | `0.3333` | describe |
| `maxInstanceCount` | `3` | describe |
| `ingressSettings` | `ALLOW_ALL` | describe |
| `environmentVariables` (имена) | `LOG_EXECUTION_ID=true` | describe |
| `secretEnvironmentVariables` (имена, не значения) | `MSKLAD_TOKEN` ← секрет `msklad-token`, версия `latest` | describe |
| Триггер | `HTTP_TRIGGER` | описание (нет `eventTrigger` в выводе), вызывается по HTTP |
| `build` | `projects/420804682491/locations/asia-east1/builds/737f0ec0-3316-40a5-9bc6-5f5a6b685695` | describe |

## Триггер (Cloud Scheduler)

Джоба `cf-inventory-trigger`, регион `asia-east1`, `schedule: 0 21 * * *`, `timeZone: UTC` (⇒ 03:00 KGT —
совпадает с докстрингом `main.py:4` «03:00 KGT»), `state: ENABLED`. OIDC `serviceAccountEmail:
etl-sa@msklad-bi-prod.iam.gserviceaccount.com`, `audience` = URI функции. `attemptDeadline: 180s`.
**Наблюдение (не факт о дефекте, флаг):** `attemptDeadline` (180s) МЕНЬШЕ серверного `timeoutSeconds` CF
(540s) — тот же паттерн, что `ADR-023` нашёл и исправил у `finance-daily-update` (там подняли 180s→1800s
именно потому, что клиентский дедлайн Scheduler обрубал раньше, чем завершался прогон). Здесь правка не
внесена — эта задача не чинит (`CLAUDE.md §Граница контракта`), фиксируется фактом для фикс-форварда.
Уже известная строка (`11_INFRA_FACTS.md §CF cf-finance` строка 27) называла джобу `cf-inventory-trigger`
только по имени/расписанию, без `attemptDeadline` — эта сессия дополняет деталь.

Провенанс: `reference/_scratch_SOURCE-MAP-REST_2026-07-30/step1c_scheduler.log`.

## Чистота архива (ADR-040)

Архив несёт **только** `main.py`, `config.py`, `helpers.py`, `requirements.txt` — исполняемый код и его
единственную зависимость. Плюс `.DS_Store` (macOS Finder, не рантайм-зависимость) — не перенесён в этот
каталог, не влияет на исполнение. Патч-скриптов, `.bak`-файлов, вложенных архивов — нет; чище, чем
прецеденты `cf-finance`/`cf-facts` (`RQ-3`/`Q-57`).

## sha256 (из задеплоенного архива, файлы верхнего уровня — живой код)

| Файл | sha256 |
|---|---|
| `main.py` | `a2bd4c5e75f64838aaf6b75dcfa8d88e7f3dfe66b0edb93d3a012c61b4724da3` |
| `config.py` | `741257fa557b824e4e42d91f5c87a6b651d63bf7a581b91e9dda3834bacc11fe` |
| `helpers.py` | `0d63885e5ee16dbf8286fc02760042b271206d58c908bae923acd52534564b74` |
| `requirements.txt` | `92a7f76a7a26eb89e05dcd36ba3d92dccdaa9416efc3c920a179fc225d195d46` |

Файл вне рантайма (не перенесён, sha256 зафиксирован в
`reference/_scratch_SOURCE-MAP-REST_2026-07-30/cf-inventory-extract/unpacked/`): `.DS_Store` —
`17e164862967ec0e0d448ff39da314ec5f78f78d090afa55324f80baa14d6d18`.

## Сверка disk vs deployed

Файлы, перенесённые в этот каталог, скачаны напрямую из `gs://gcf-v2-sources-420804682491-asia-east1/
cf-inventory/function-source.zip#1778486115150159` — того же объекта и generation, что в
`source.storageSource` задеплоенной ревизии `cf-inventory-00003-vuf`. Второй копии для независимой сверки
(как у `cf-finance` на диске Cloud Shell) нет — архив уже есть «то, что задеплоено» по построению команды
`describe`.

## Метод извлечения

```bash
gcloud functions describe cf-inventory --gen2 --region=asia-east1 --project=msklad-bi-prod --format=yaml
gcloud storage cp "gs://gcf-v2-sources-420804682491-asia-east1/cf-inventory/function-source.zip#1778486115150159" ./function-source.zip
unzip function-source.zip -d unpacked
sha256sum unpacked/*
```

Полный лог — `reference/_scratch_SOURCE-MAP-REST_2026-07-30/step2_run.log`.

## Известное открытое (не блокирует, для памяти)

- `attemptDeadline` джобы (180s) < серверный timeout CF (540s) — см. §Триггер выше, фикс-форвард не
  назначен этой сессией.
- Конвертация в KGS: `cost_kgs = price / 100` без множителя `× rate.value` (см. основной артефакт §5г) —
  зафиксировано фактом, не оценивается на корректность этой сессией.
