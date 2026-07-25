# MANIFEST · /reference/code/cf-loss-commission/ — снапшот исходника (E1-T1-MECH-INGEST)

**Тип:** provenance-снапшот, не оракул, не прод-код.
**Источник:** задеплоенный `function-source.zip` (Cloud Storage), скачан напрямую `gcloud storage cp` — не транскрипция.
**Дата извлечения:** 2026-07-25.
**Извлечено разработчиком, закоммичено человеком.**

## Ревизия и провенанс
| Поле | Значение |
|---|---|
| `revision` | `cf-loss-commission-00006-dip` |
| `entryPoint` | `main` |
| `source.storageSource` | `gs://gcf-v2-sources-420804682491-asia-east1/cf-loss-commission/function-source.zip` (generation `1784981288510923`) |
| `updateTime` | `2026-07-25T12:08:48.063835807Z` |
| `state` | `ACTIVE` |
| `serviceAccountEmail` | `etl-sa@msklad-bi-prod.iam.gserviceaccount.com` |
| `uri` | `https://cf-loss-commission-xw5u2boozq-de.a.run.app` |

## Что изменилось относительно предыдущей ревизии `00004-div`
- Курс валюты при отсутствии `rate.value` в документе: было — жёсткая единица (`1.0`); стало — запрос текущего курса через `entity/currency`.
- Запись в `core.fact_commissionreportin`: было — позиционная вставка (`INSERT ROW`, риск молчаливой порчи данных при будущих изменениях схемы); стало — вставка по явным именам колонок, как уже было сделано в `core.fact_loss`.

## sha256 (из задеплоенного архива)
| Файл | sha256 |
|---|---|
| `main.py` | `24d58ddebc93c4e1dce464e419e09f7a1f20c5092f3c7fb8fd7c61054f805f70` |
| `requirements.txt` | `4b25b2242cecaa781a0b7b1a9e25c1b4a66b3874f37dc1d05bbaa07e8aecc519` |

## Сверка disk vs deployed — выполнена
`main.py` и `requirements.txt`, скачанные напрямую из задеплоенного архива, побайтово совпали с файлами, использованными для деплоя (`diff -q`, без расхождений).

## Доступ (IAM)
`roles/run.invoker` явно выдан `etl-sa@msklad-bi-prod.iam.gserviceaccount.com` через Cloud Run (не через устаревший `functions get-iam-policy` — та команда для функций 2-го поколения показывает пусто и вводит в заблуждение, реальная политика — в Cloud Run слое). Открытого публичного доступа нет.

## Известное открытое (не блокирует, для памяти)
- Автозапуск по расписанию для этой функции — статус не выяснен, требует ответа владельца.
- Приёмочный критерий «конвертация проверена на ≥1 не-KGS документе» — не закрыт живым тестом: по состоянию на 2026-07-25 ни одного документа не в сомах в `entity/loss`/`entity/commissionreportin` за последние 6 месяцев не найдено (25 и 59 документов проверено соответственно, 0 валютных).
