# FILE: dq_cfdq_deploy_2026-08-13.md

# Деплой `cf-dq` — переделка метрики `drift_check` + две проверки свежести (`DQ-CFDQ-DEPLOY`)

**Дата:** 2026-08-13 (Бишкек) · **Задача:** `DQ-CFDQ-DEPLOY` · **Класс:** B, мандат выдан
поимённо (владелец, чат 2026-08-12, `ADR-173 §5`).
**Дерево/ветка holika:** `worktrees/DQ-CFDQ-DEPLOY` / `s/DQ-CFDQ-DEPLOY`.
**Ветка код-репо:** `deploy/cf-dq-2026-08-12-drift-and-freshness` от `master` (коммит-основание
`5ad9544`), патч-коммит `c9b967f`, merge-коммит `9a08b5a`.

**Назначение файла.** Самодостаточная приёмка деплоя по чек-листу
`deploy_procedure_2026-08-03.md §5` — шаги 0–9 применительно к `cf-dq`.

---

## Предусловия старта (проверены перед первым действием)

- **П3** (`SALES-REFRESH-WINDOW-DEPLOY-FINAL`, ступени 1 и 2 закрыты) — подтверждено чтением
  живого `07_STATE.md` перед стартом сессии, статус не расходился с брифом.
- **П0** (ревью патча) — снято `ADR-173 §4` до этой сессии, переизмерения не требовало.
- Патч (`reference/code/cf-dq/main.py`+`config.py`) — снапшот, прошедший три захода ревью,
  провенанс приёмки — `reference/dq_cfdq_prep_2026-08-12.md` (прочитан целиком до исполнения).

## Шаг 0 — старт сессии

`bash tools/session_status.sh` — ЧИСТО, `HEAD=7f4148f`. Дерево `worktrees/DQ-CFDQ-DEPLOY`
заведено командой `git worktree add worktrees/DQ-CFDQ-DEPLOY -b s/DQ-CFDQ-DEPLOY HEAD`. Хук
общий для деревьев (`.git/hooks/pre-commit` в common git dir), самотест —
`пройдено 36, провалено 0`.

## Шаг 1 — П1/П2: живая (обслуживающая) ревизия + сверка дрейфа

Read-only, скрипты/логи —
`reference/_scratch_DQ-CFDQ-DEPLOY_2026-08-13/step1_live_revision_and_drift.sh`+`step1_run.log`,
`step2_drift_check.sh`+`step2_run.log`.

Обслуживающая ревизия снята через `gcloud run services describe cf-dq
--format="yaml(status.traffic)"` (не через `functions describe` — прецедент подмены,
`ADR-173 §5`, `…deploy_final_adj…§2`): `status.traffic` вернул `revisionName=cf-dq-00008-cev,
percent=100, latestRevision=true`. Обслуживающая ревизия совпадает с последней созданной —
подмены нет в этом конкретном случае, но проверка сделана правильным методом.

Архив `cf-dq-00008-cev` (`generation=1786372858921485`) скачан и распакован. sha256 всех
четырёх файлов (`main.py`/`config.py`/`helpers.py`/`requirements.txt`) побайтово сверены с
`master` код-репо `holika-prod` (свежий клон) — **все четыре `IDENTICAL`**. Дрейфа нет.

Откатная ревизия (П2) зафиксирована ДО деплоя: **`cf-dq-00008-cev`**.

## Шаг 2 — ветка код-репо, перенос патча

```
git clone --branch master https://github.com/ilyasbazarov/holika-prod.git
git checkout -b deploy/cf-dq-2026-08-12-drift-and-freshness
```

Патч перенесён копированием из `reference/code/cf-dq/{main.py,config.py}` (снапшот, прошедший
ревью) поверх файлов ветки — база ветки (`master`) подтверждена байт-в-байт идентичной живому
архиву в Шаге 1, поэтому перенос копированием эквивалентен переносу по diff.

`git diff --stat master` — **ровно два файла**:
```
cf-dq/config.py |  41 ++++++++
cf-dq/main.py   | 302 +++++++++++++++++++++++++++++++++++++++++++++++++++++-
2 files changed, 340 insertions(+), 3 deletions(-)
```
(Больше строк, чем в диффе `dq_cfdq_prep_2026-08-12.md`, потому что база сравнения там — HEAD
холики, а здесь — `master` код-репо, который уже нёс отдельно задеплоенный фикс `ma7==0`
(`ADR-152`, ревизия `cf-dq-00008-cev`) поверх более старой базы, от которой считался дифф
холики. Итоговое содержимое файлов идентично `reference/code/cf-dq/{main.py,config.py}` —
проверено `cp`+`git diff --stat`, что и требуется приёмкой П1.)

`.gcloudignore` (`cf-dq/.gcloudignore`) уже заведён прошлым деплоем (`DQ-GATE-FAIL-OPEN-FIX`,
`2026-08-10`) и исключает `patch_*.py`/`*.bak`/`__pycache__/`/`*.pyc`/`.DS_Store`/`src.zip`/
`function-source*.zip` — проверен, правки не потребовалось.

Сплошной поиск секретов по диффу:
```
$ git diff -- cf-dq/main.py cf-dq/config.py | grep -inE "secret|token|password|api[_-]?key|bearer|AIza|ya29\.|-----BEGIN"
NO_MATCHES (пусто — печатается явно, не как факт по умолчанию)
```

## Шаг 3 — коммит и push ветки

Коммит `c9b967ffcae01ceeae3b6fd0e6e2cba0549ed738`. Push ветки подтверждён владельцем
(«Да, отправить») — `origin/deploy/cf-dq-2026-08-12-drift-and-freshness` создана. `master` на
этом шаге не тронут.

## Шаг 4 — объявление действия

Отдельным сообщением в чат (до ask): что исполняется (деплой `cf-dq` из ветки
`deploy/cf-dq-2026-08-12-drift-and-freshness`), на каком объекте (прод-функция `cf-dq`, проект
`msklad-bi-prod`), чем откатывается (перевод трафика на `cf-dq-00008-cev`). Владелец
подтвердил («Да, деплоить»).

## Шаг 5 — деплой

Параметры сняты с живой конфигурации ДО деплоя (`live_config_before_deploy.yaml`), не
изобретены: `--gen2 --runtime=python312 --region=asia-east1 --entry-point=main --trigger-http
--service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com --memory=512Mi --cpu=0.3333
--timeout=120s --min-instances=1 --max-instances=6 --concurrency=1 --ingress-settings=all
--set-env-vars=LOG_EXECUTION_ID=true --set-secrets=MSKLAD_TOKEN=msklad-token:latest`.

Скрипт/лог — `step5_deploy.sh`+`step5_run.log`. `date -u`/`gcloud auth list` в начале и в
конце — авторизация не деградировала (`ilyasbazarov4@gmail.com` в обоих случаях).

**Новая ревизия: `cf-dq-00009-coy`**, `updateTime=2026-08-12T19:14:47.725221603Z`.

## Шаг 6 — read-back

`status.traffic` после деплоя — `revisionName=cf-dq-00009-coy, percent=100`. Архив новой
ревизии (`generation=1786561996565446`) скачан и распакован: **ровно 4 исполняемых файла**
(`main.py`/`config.py`/`helpers.py`/`requirements.txt`), мусора нет — `.gcloudignore` сработал.
sha256 всех четырёх файлов побайтово совпадают с веткой деплоя (`IDENTICAL` по всем). Скрипт/лог
— `step6_readback.sh`+`step6_run.log`. Полные sha256 — `reference/code/cf-dq/MANIFEST.md`.

## Шаг 7 — функциональная проверка (условия 2/3 приёмки `ADR-173 §5`)

Первый естественный часовой прогон (`msklad-pipeline-hourly`, `0 * * * *`) —
`run_id=1786564802.7168841`, `checked_at=2026-08-12 20:04:52 UTC`. Запрос-сравнение с прошлым
прогоном (ДО деплоя, `run_id=1786561202.3581266`, `checked_at=2026-08-12 19:02:14 UTC`) —
`reference/_scratch_DQ-CFDQ-DEPLOY_2026-08-13/step8_first_natural_run_compare.log`.

**Условие 2 — запись несёт оба исхода метрики `drift_check`.** Семь строк вместо шести:

| check_name | passed | detail |
|---|---|---|
| `drift_check` | `true` | `yesterday_rev=4240470, ma7=4453347, ratio=0.95, threshold=0.1 (weekday), target_date=2026-08-12` |
| `drift_zero_docs` | `true` | `yesterday_rev=4240470, ma7=4453347, target_date=2026-08-12 (notify, не блокирует promote)` |

Оба присутствуют в одной записи (`run_id=1786564802.7168841`) — условие 2 выполнено.

**Условие 3 — поведение остальных пяти проверок не изменилось.**

| check_name | до деплоя (19:02:14) | после деплоя (20:04:52) | совпадает |
|---|---|---|---|
| `not_empty` | `passed=true, staging_count=484` | `passed=true, staging_count=484` | да |
| `fk_integrity` | `passed=true, orphan_product_ids=0` | `passed=true, orphan_product_ids=0` | да |
| `freshness` | `passed=true, max_date=2026-08-12, lag_days=1` | `passed=true, max_date=2026-08-12, lag_days=1` | да |
| `margin_sanity` | `passed=true, bad_margin_rows=0 (core, last 7d)` | `passed=true, bad_margin_rows=0 (core, last 7d)` | да |
| `currency_normalization` | `passed=true, avg_revenue_kgs=73169.21` | `passed=true, avg_revenue_kgs=73169.21` | да |

Все пять побайтово идентичны (`passed` и `detail`) — регрессии нет.

**Приёмка `ADR-173 §5` закрыта полностью.**

## Шаг 8 — слияние в master и запись MANIFEST

Merge `--no-ff` подтверждён владельцем («Да, отправить»): merge-коммит
`9a08b5aa2522eb0340c5568e8763ff90255d3ec8`, `git push origin master` (`5ad9544..9a08b5a`).
Запись ревизия↔коммит — `reference/code/cf-dq/MANIFEST.md` (по результату read-back Шага 6, не
по сообщению команды деплоя).

## Шаг 9 — неуспех

Не применимо — деплой успешен, откат не потребовался.

---

## Что этой задачей НЕ делалось

- `reference/code/cf-dq/helpers.py` и остальные пять исходных проверок — не затронуты
  (подтверждено побайтовым совпадением sha256 в Шаге 1/6: `helpers.py` не менялся ни разу).
- Вторая лог-метрика для доставки исхода `drift_zero_docs` в телеграм-канал `notify` — не
  заводилась (отдельная задача класса B, мандат не выдан, `ADR-153 §Последствия`).
- Проверки свежести `fact_payments`/`fact_commissionreportin` подключены к `CHECKS` вместе с
  этим деплоем (входили в патч), но подключение других четырёх проверок свежести
  (`fact_purchases`/`fact_returns`/`fact_inventory`/`fact_customer_invoices`) в этот деплой не
  входило — они не были частью подготовленного патча (см. `dq_cfdq_prep_2026-08-12.md`).
- Пороги `DQ_DRIFT_THRESHOLD`/`DQ_DRIFT_WEEKEND_THRESHOLD` не менялись.
