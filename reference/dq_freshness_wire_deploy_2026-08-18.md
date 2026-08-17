# FILE: dq_freshness_wire_deploy_2026-08-18.md

# Деплой `cf-dq` — `DQ-FRESHNESS-WIRE, деплой` — попытка 2026-08-18, НЕУСПЕХ

**Дата:** 2026-08-18 (Бишкек) · **Задача:** `DQ-FRESHNESS-WIRE-DEPLOY` · **Класс:** B, мандат
выдан поимённо владельцем 2026-08-17 (`ADR-185 §8`, `07_STATE.md:1961`).
**Дерево/ветка holika:** `worktrees/DQ-FRESHNESS-WIRE-DEPLOY` / `s/DQ-FRESHNESS-WIRE-DEPLOY`.
**Ветка код-репо:** `deploy/cf-dq-2026-08-18-freshness-wire` от `master` (коммит-основание
`9a08b5a`), патч-коммит `2a3228d`, запушена в `origin`, **НЕ слита** (неуспех).

**Назначение файла.** Самодостаточная приёмка попытки деплоя. Итог — деплой упал, причина
установлена точно, прод не задет, следующий шаг назван.

---

## Предусловия (все read-only, ДО деплоя) — закрыты чисто

Скрипты/логи — `reference/_scratch_DQ-FRESHNESS-WIRE-DEPLOY_2026-08-18/`.

- **П1.** Ветка `s/DQ-FRESHNESS-WIRE-GUARD-FIX` слита в `main` холики коммитом `330e42b`
  (`git log --merged`) — фикс шести `*_business` присутствует в снапшоте.
- **П2.** Обслуживающая ревизия снята живым съёмом `gcloud run services describe cf-dq
  --format="yaml(status.traffic)"` — `revisionName=cf-dq-00009-coy, percent=100`. Совпадает с
  откатной ревизией из брифа. Подмены нет.
- **П3.** Архив обслуживающей ревизии (`generation=1786561996565446`) скачан
  (`gcloud storage cp`) и распакован, sha256 всех четырёх файлов побайтово сверены с `master`
  код-репо (свежий клон) — `main.py`/`config.py`/`helpers.py`/`requirements.txt` все
  `IDENTICAL`. Дрейфа нет (`step1_run.log`).
- **П4.** Ветка `deploy/cf-dq-2026-08-18-freshness-wire` заведена от `master` (не от
  устаревшей базы). `git diff --stat master` — **ровно один файл**: `cf-dq/main.py`
  (`214 insertions(+), 125 deletions(-)`). `.gcloudignore` присутствует и исключает
  `patch_*.py`/`*.bak`/`__pycache__/`/`*.pyc`/`.DS_Store`/`src.zip`/`function-source*.zip`.
  Сплошной поиск секретов по диффу — `NO_MATCHES` (`step2_run.log`).

## Объявление действия (`ADR-077 §6`) и подтверждение владельца

Отдельным сообщением в чат ДО ask названы: что исполняется (push ветки +
`gcloud functions deploy cf-dq` из неё), объект (прод-функция `cf-dq`, `msklad-bi-prod`,
`asia-east1`, изменён только `main.py`), откат (`cf-dq-00009-coy`, пересборка не требуется).
Владелец подтвердил: «Да, push и деплоить».

## Push ветки

`git push -u origin deploy/cf-dq-2026-08-18-freshness-wire` — успех, ветка создана в `origin`
(`step3_push_run.log`). `master` на этом шаге не тронут.

## Живая конфигурация до деплоя

Снята `gcloud run services describe cf-dq --format=yaml` (`step4_live_config_before_deploy.log`)
— параметры совпадают с прошлым деплоем `DQ-CFDQ-DEPLOY` (`cpu=0.3333`, `memory=512Mi`,
`timeout=120s`, `min-instances=1`, `max-instances=6`, `concurrency=1`,
`service-account=etl-sa@...`, `ingress=all`, `LOG_EXECUTION_ID=true`,
`MSKLAD_TOKEN=msklad-token:latest`).

## Деплой — НЕУСПЕХ

```
gcloud functions deploy cf-dq --gen2 --runtime=python312 --region=asia-east1 \
  --source=cf-dq/ --entry-point=main --trigger-http \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=512Mi --cpu=0.3333 --timeout=120s --min-instances=1 --max-instances=6 \
  --concurrency=1 --ingress-settings=all --set-env-vars=LOG_EXECUTION_ID=true \
  --set-secrets=MSKLAD_TOKEN=msklad-token:latest
```

Build прошёл (`done`), Service-этап упал: `OperationError: code=3, message=Could not create or
update Cloud Run service cf-dq, Container Healthcheck failed…`. Новая ревизия —
**`cf-dq-00010-kiq`**. Скрипт/лог — `step5_deploy_run.log`.

## Read-only диагностика после срыва (запрет слепого retry соблюдён)

`step6_diagnose_run.log`:

- `status.traffic` после срыва — **`cf-dq-00009-coy, percent=100`**, без изменений. Cloud Run
  gen2 не переключает трафик на ревизию, не прошедшую healthcheck — объект (прод) не задет,
  откат не требуется.
- `gcloud run revisions list` — `cf-dq-00010-kiq` несёт `STATUS=False`,
  `MESSAGE="The user-provided container failed to start and listen on the port…"`.
- Логи ревизии (`gcloud logging read`) дают точный traceback:

```
File "/workspace/main.py", line 223, in <module>
    ("freshness_purchases_technical",         check_freshness_purchases_technical),
NameError: name 'check_freshness_purchases_technical' is not defined
```

## Корневая причина — дефект самого ревьюнутого снапшота

`reference/code/cf-dq/main.py`: `CHECKS = [...]` (строки `215-235`) перечисляет все двенадцать
функций `check_freshness_*_technical`/`_business` по имени, но эти функции определены НИЖЕ по
файлу (первая, `check_freshness_purchases_technical`, — на строке `270`; последняя,
`check_freshness_invoices_business`, — на строке `499`). Python исполняет модуль
последовательно сверху вниз: на строке присвоения `CHECKS` эти двенадцать имён ещё не
существуют в пространстве имён модуля → `NameError` **при любом импорте**, не только в
Cloud Run — тот же результат дал бы `python3 -c "import main"` локально.

**Ни одно из двух ревью не поймало дефект:**
- `dq_freshness_wire_deploy_review_2026-08-17.md` — построчно проверял наличие `try`/`except`
  в каждой из двенадцати функций (таблица §2.2), но не пытался исполнить модуль.
- `guard_fixes_review_2026-08-17.md §2` — подтвердил «все двенадцать функций несут
  `try`/`except`» и «`CHECKS` несёт `19` пар» тем же текстовым разбором, тоже не исполняя
  модуль.

Класс ошибки — тот же, что `★ Успех инструмента ≠ факт` (`ADR-021 §2`, `ADR-044`): вердикт
готовности был построен на текстовом соответствии образцу, не на факте успешного исполнения.
Обе проверки (`try/except` есть, `CHECKS` содержит 19 пар) были верны и остаются верными; они
просто не покрывали **порядок** определений — свойство, которое текстовый греп по одной
функции за раз структурно не видит.

## Итог по процедуре деплоя (`05_CONVENTIONS §Процедура деплоя`, п.8)

Ветка `deploy/cf-dq-2026-08-18-freshness-wire` (`2a3228d`, в `origin`) **НЕ слита** в `master`.
`master` код-репо не изменился с прошлого деплоя (`9a08b5a` = `cf-dq-00009-coy`). Инвариант
«основная ветка = то, что стоит в проде» цел: прод как был на `cf-dq-00009-coy`, так и остался.

Мандат класса B `DQ-FRESHNESS-WIRE, деплой` (`07_STATE.md:1961`) считается **исчерпанным
этой попыткой** — объект патча (текущее содержимое `main.py`) деплою не подлежит без правки.

## Что дальше (рекомендация, не решение)

1. Правка порядка определений в `reference/code/cf-dq/main.py` — перенести блок
   `CHECKS = [...]` НИЖЕ определений всех двенадцати функций `check_freshness_*` (либо
   перенести определения функций выше `CHECKS`). Правка механическая, класса A (перестановка
   блоков текста, логика функций не меняется), но по духу `ADR-170 §3` обязана пройти
   **факт-проверку исполнением**, а не только текстовым ревью: минимум
   `python3 -c "import ast; ast.parse(open('main.py').read())"` не достаточно (это не ловит
   `NameError`, только синтаксис) — нужен реальный `python3 -c "import main"` (либо
   аналогичный запуск в окружении с зависимостями) до следующей попытки деплоя.
2. Повторное ревью архитектора по факту исполнения (не по тексту) — новый гейт для следующей
   попытки, по прецеденту `ADR-170 §3`/`ADR-173`.
3. Новый деплой-заход с тем же классом B мандатом (объект патча тот же по содержанию, форма
   изменилась только порядком строк) — либо владелец переоткрывает мандат явно.

## Провенанс

`reference/_scratch_DQ-FRESHNESS-WIRE-DEPLOY_2026-08-18/`:
`step1_predusloviya.sh`+`step1_run.log`, `step2_branch_and_patch.sh`+`step2_run.log`,
`step3_push_run.log`, `step4_live_config_before_deploy.log`, `step5_deploy_run.log`,
`step6_diagnose_run.log`. `date -u`/`gcloud auth list` первой и последней командой каждого
скрипта — авторизация не деградировала ни разу (`ilyasbazarov4@gmail.com` везде).
