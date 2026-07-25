# MANIFEST · /reference/code/cf-loss-commission/ — снапшот исходника (E1-T1-MECH-INGEST)

**Тип:** provenance-снапшот, не оракул, не прод-код.
**Источник:** задеплоенный `function-source.zip` (Cloud Storage), скачан напрямую `gcloud storage cp` — не транскрипция.
**Дата извлечения:** 2026-07-25.

## Ревизия и провенанс
| Поле | Значение |
|---|---|
| `revision` | `cf-loss-commission-00007-kuh` |
| `entryPoint` | `main` |
| `source.storageSource` | `gs://gcf-v2-sources-420804682491-asia-east1/cf-loss-commission/function-source.zip` (generation `1784983258299919`) |
| `updateTime` | `2026-07-25T12:41:34.158435921Z` |
| `state` | `ACTIVE` |
| `serviceAccountEmail` | `etl-sa@msklad-bi-prod.iam.gserviceaccount.com` |
| `uri` | `https://cf-loss-commission-xw5u2boozq-de.a.run.app` |

## Что изменилось относительно предыдущей ревизии `00006-dip`
- `start_date`/`end_date` больше не обязательны в теле запроса: при отсутствии — берётся весь период с `2020-01-01` по завтрашнюю дату (UTC). Нужно для автоматического ночного запуска (Cloud Scheduler), которому неоткуда взять даты самому.

## Автозапуск (Cloud Scheduler)
Задача `loss-commission-daily-update`, `asia-east1`, `0 3 * * *` (Asia/Bishkek), вызов через OIDC от `etl-sa@msklad-bi-prod.iam.gserviceaccount.com`, `attemptDeadline=1800s` (= серверный timeout функции), `maxRetryDuration=0s` (без повторов, по прецеденту `cf-finance`).

## sha256 (из задеплоенного архива)
| Файл | sha256 |
|---|---|
| `main.py` | `06895748a765ef0263e8b782148588543d596fea0bd47267398496a076739efd` |
| `requirements.txt` | `4b25b2242cecaa781a0b7b1a9e25c1b4a66b3874f37dc1d05bbaa07e8aecc519` |

## Сверка disk vs deployed
`main.py`, скачанный напрямую из задеплоенного архива, побайтово совпал с файлом, использованным для деплоя (`diff -q`, без расхождений).

## Известное открытое (не блокирует, для памяти)
- Приёмочный критерий «конвертация проверена на ≥1 не-KGS документе» не закрыт живым тестом: по состоянию на 2026-07-25 ни одного документа не в сомах не найдено ни в `entity/loss` (128 документов), ни в `entity/commissionreportin` (191 документ) за всю историю аккаунта.
