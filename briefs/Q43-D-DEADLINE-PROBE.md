# TASK BRIEF · Q43-D-DEADLINE-PROBE  (discovery, read-only)

## Роль
Ты — разработчик проекта. Сначала прочитай `_METHOD` + `05_CONVENTIONS` (правила агента), затем действуй.
Модель исполнения: ты ПИШЕШЬ команды/артефакты, человек ЗАПУСКАЕТ и возвращает логи. Ты не исполняешь сам.
Это **discovery-бриф** (`_METHOD §11`): return-this — обогащение репо, НЕ прод-код.

## Цель
Установить ground truth по факт-половине Q-43: обрывает ли истечение клиентского `attemptDeadline=180s`
Scheduler-джоба `finance-daily-update` серверную обработку `cf-finance` на середине `MERGE` в
`core.fact_payments`, — или это чисто клиентский таймаут, а сервер (BQ-джоб) доводит запись независимо.
Единственное чистое наблюдение условия 180s — уже состоявшийся штатный прогон 2026-07-21 03:00 Asia/Bishkek.
Снять его логи, пока `attemptDeadline` не поднят (после raise условие не воспроизвести).

## Context-to-load (обязательно прочитать перед работой; raw-URL пиннены по SHA e76d1a7)
- `_METHOD`  — https://raw.githubusercontent.com/ilyasbazarov/holika/e76d1a77eedbcb5b5f1813397e9d337ede219de6/_METHOD.md
- `00_CHARTER` — https://raw.githubusercontent.com/ilyasbazarov/holika/e76d1a77eedbcb5b5f1813397e9d337ede219de6/00_CHARTER.md
- `05_CONVENTIONS` — https://raw.githubusercontent.com/ilyasbazarov/holika/e76d1a77eedbcb5b5f1813397e9d337ede219de6/05_CONVENTIONS.md
- `07_STATE` — https://raw.githubusercontent.com/ilyasbazarov/holika/e76d1a77eedbcb5b5f1813397e9d337ede219de6/07_STATE.md
- `03_PIPELINE_SPEC` §cf-finance (порядок `run_etl`, 5 шагов, MERGE) — https://raw.githubusercontent.com/ilyasbazarov/holika/e76d1a77eedbcb5b5f1813397e9d337ede219de6/03_PIPELINE_SPEC.md
- `11_INFRA_FACTS` §CF (`cf-finance` timeout=1800s; джоб `finance-daily-update`; OIDC `etl-sa@`; регион/сервис-имя — брать ОТСЮДА, не догадка) + §IAM — https://raw.githubusercontent.com/ilyasbazarov/holika/e76d1a77eedbcb5b5f1813397e9d337ede219de6/11_INFRA_FACTS.md
- `06_DECISIONS_LOG` — ADR-022 (каноническая модель вызова: анон→403, Scheduler→OIDC 200), ADR-020 §Q-34 (класс молчаливого сбоя, `maxRetryDuration=0s`), ADR-021 §2 («успех инструмента + пустой результат ≠ факт») — https://raw.githubusercontent.com/ilyasbazarov/holika/e76d1a77eedbcb5b5f1813397e9d337ede219de6/06_DECISIONS_LOG.md
Если чего-то из списка нет в контексте → `CONTEXT GAP`, остановись (anti-improvisation, `05` Часть I).

## Входы (факты из репо; не переизобретать)
- Scheduler-джоб `finance-daily-update`: `attemptDeadline: 180s`, `retryConfig.maxRetryDuration=0s`.
- Сервер `cf-finance`: `--timeout=1800s` (укладывается с запасом; наблюдённый runtime ~5 мин).
- Пост-ADR-022: `allUsers`-invoker снят; `etl-sa@msklad-bi-prod.iam.gserviceaccount.com` → `roles/run.invoker`;
  Scheduler переведён на OIDC. Прогон 03:00 — ПЕРВЫЙ штатный необслуживаемый fire после lockdown.
- Проект: `msklad-bi-prod`. Точные `service`-имя/регион `cf-finance` и поля джоба — из `11 §CF`.
- Целевой прогон: 2026-07-21 03:00 Asia/Bishkek (Kyrgyzstan UTC+6, без DST) = `2026-07-20T21:00:00Z`.
  ТОЧНЫЙ инстант перевычислить из `timeZone`+`schedule` самого джоба (`describe`), не хардкодить.

## Шаги
1. `describe`-контекст (read-only): снять `gcloud scheduler jobs describe finance-daily-update`
   (project=msklad-bi-prod, регион из `11 §CF`) → зафиксировать актуальные `attemptDeadline`,
   `retryConfig`, `schedule`, `timeZone`, `oidcToken.serviceAccountEmail`. Подтвердить, что `attemptDeadline`
   ещё = 180s (raise не применён). Вычислить UTC-инстант последнего fire.
2. **Источник A — Scheduler execution.** `gcloud logging read` по ресурсу `cloud_scheduler_job` /
   имени джоба за окно [инстант−5м … инстант+35м] (35м > server timeout 1800s): статус доставки, код ответа
   (ожидание: OIDC 200 либо DEADLINE/`4xx`/`5xx`), латентность (упёрлось ли в ~180s).
3. **Источник B — `cf-finance` request+app логи.** `gcloud logging read` по Cloud Run–ревизии/сервису
   `cf-finance` за то же окно: длительность и статус HTTP-запроса; маркеры шагов `run_etl` (1..5);
   любой `SIGTERM`/принудительное завершение инстанса; финальный маркер завершения функции.
4. **Источник C (решающий) — BQ job history.** Найти MERGE-джоб в `core.fact_payments` в том же окне
   (`bq ls -j --max_results=… --format=prettyjson` project=msklad-bi-prod, либо
   `INFORMATION_SCHEMA.JOBS_BY_PROJECT` с фильтром по времени и `statement_type='MERGE'`/целевой таблице):
   `state`, `creation/start/end time`, `dml_stats`/затронутые строки. Это авторитетный сигнал «запись дошла».
5. Триангуляция → вердикт: если MERGE в BQ достиг `DONE` с ожидаемыми строками, даже когда Scheduler
   доложил дедлайн на 180s ⇒ `attemptDeadline` — чисто клиентский таймаут, сервер доводит независимо
   (raise = гигиена/шумоподавление). Если MERGE отсутствует/частичный/`FAILED` в сцепке с меткой 180s
   ⇒ дедлайн обрывает на середине ⇒ реальный риск частичной записи (raise = обязательный safety-гейт).

## Дисциплина наблюдения (обязательно)
- ADR-014: команды — ОДНИМ copy-paste-ready bash-блоком, запуск с `> run.log 2>&1; cat run.log`
  (разделимая форма). Секретов для logging/bq-ридов нет; плейсхолдеры `<ВСТАВИТЬ…>` запрещены — project
  и имена ресурсов из `11 §CF`/`00_CHARTER`.
- ADR-021 §2: `rc=0` при пустом выводе logging/bq — это **гэп наблюдения, не факт «прогона не было»**.
  Пустой источник A/B/C → расширить окно и подтвердить факт fire независимо (Источник A), НЕ делать вывод
  «не запускалось».
- `05` §Untrusted: наложенный/противоречивый лог — недостоверен; запросить чистый повторный ридаут в
  разделимой форме, не примирять половины.
- Read-only жёстко: никаких `deploy`/`run`/правок джоба в этом брифе.

## Критерии приёмки (Acceptance)
- Точный UTC-инстант прогона вычислен из `timeZone`+`schedule` джоба (не допущен).
- Все три источника (A/B/C) сняты за корректное окно, в разделимой форме, непусты и взаимно согласованы
  (иначе — чистый повторный ридаут запрошен, а не «дотянут»).
- Вердикт обрыв-пропагации трассируем: `state`+тайминг BQ-MERGE относительно метки 180s, сверенные с кодом
  ответа Scheduler и статусом Cloud Run–запроса.
- Побочно подтверждено: OIDC-вызов штатного прогона отработал (не тихий `403`/`maxRetryDuration=0s`-провал
  класса ADR-020 §Q-34).

## Что вернуть человеку (Return-this) — обогащение репо
- `/reference/fin_sched_deadline_probe_2026-07-21.md`: ключевые строки источников A/B/C (verbatim,
  провенанс-помечены — какая команда/какой лог), вычисленный инстант, таблица триангуляции, вердикт.
- `NEW_DECISIONS` — черновой ADR (`proposed`, апрув владельца): закрытие факт-половины Q-43 одним из двух
  вердиктов (§5). При «обрыв реален» — явно поднять raise из «рекомендации» в **обязательный пре-cutover
  гейт** для любого не-приостановленного штатного прогона.
- `STATE_PATCH` (`07_STATE`): факт-половина Q-43 → CLOSED/partial (с явным residual, если C неполон);
  строка «Текущий фокус» — снять пункт (1) wait-ветку, зафиксировать статус raise по вердикту.
  STATE_PATCH фиксирует статус ТОЛЬКО при наличии возвращённого артефакта (`/reference` + логи), не по метке.

## Вне scope этой задачи
- Правка `attemptDeadline`/`retryConfig` (raise) — owner-rolled изменение, отдельно; здесь read-only.
- Q-42: read-only аудит `--allow-unauthenticated` по 6 прочим CF — отдельный утверждённый параллельный бриф.
- Магнитудный замер currency-бага (Q-30) — DEFER.
- Генерация брифа `E1-T1` / grounding-закрытие Q-31 — отдельный фокус-пункт (3), отдельный бриф.
- Любой `deploy`/редеплой `cf-finance`.

## В конце сессии
Выдай SESSION-блок по формату `05_CONVENTIONS` Часть III
(`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`), адресованный последнему
закоммиченному SHA.
