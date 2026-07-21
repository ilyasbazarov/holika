# Q-43 Deadline Probe — 2026-07-21

Прогон: finance-daily-update, scheduledTime 2026-07-20T21:00:00.860336Z (03:00 Asia/Bishkek 2026-07-21)

## Источник A — Scheduler execution (provenance: gcloud logging read, resource.type=cloud_scheduler_job)
- AttemptStarted: 2026-07-20T21:00:00.860336Z
- AttemptFinished: 2026-07-20T21:03:05Z — status=DEADLINE_EXCEEDED, http=504, debugInfo=URL_TIMEOUT-TIMEOUT_WEB
- Ретраев не было (maxRetryDuration=0s подтверждён поведением)

## Источник B — cf-finance Cloud Run (provenance: gcloud logging read, resource.type=cloud_run_revision, revision=cf-finance-00012-cik)
- Request start: 2026-07-20T21:00:00.877514Z; итоговый latency=807.271704568s; status=200
- 21:00:02 — STARTUP TCP probe succeeded
- 21:13:23 — "Loading 6386 records to STG..."
- 21:13:25 — "Running MERGE..."
- 21:13:26 — "Cleaning up excluded system expenses (ghosts removal)..."
- 21:13:27 — "Triggering scheduled query via API..."
- 21:13:28 — WARNING (non-fatal) trigger_marts() 403 permission denied — ожидаемое поведение по 03_PIPELINE_SPEC §cf-finance

## Источник C (решающий) — BQ MERGE job (provenance: INFORMATION_SCHEMA.JOBS_BY_PROJECT, region-asia-east1)
- job_id 3ee868bb-af4a-4847-afaa-69e2ba84f501
- creation_time 2026-07-20 21:13:25 → end_time 2026-07-20 21:13:26
- state=DONE, error_result=null, inserted=1449, updated=4937

## Триангуляция
Scheduler объявил клиентский DEADLINE_EXCEEDED в 21:03:05 (T+180s от старта). Сервер продолжил
работу необорванным и завершил MERGE успешно в 21:13:26 (T+~13м25с от старта) — на ~10 минут ПОСЛЕ
клиентского таймаута. Инстанс не терминирован (SIGTERM в логах отсутствует), все 5 шагов run_etl()
пройдены по порядку.

## Вердикт
attemptDeadline=180s — чисто клиентский таймаут Scheduler. Сервер (cf-finance → BQ MERGE) доводит
запись независимо от истечения клиентского дедлайна. Риск частичной записи в этом прогоне НЕ
подтверждён. Raise attemptDeadline квалифицируется как гигиена/шумоподавление, не как обязательный
пре-cutover safety-гейт.

## Побочное наблюдение (не в scope вердикта)
Обслуживающая ревизия cf-finance-00012-cik расходится с 11_INFRA_FACTS §CF (там — 00006-piv,
данные на 2026-06-25). 11 устарел, требует патча ревизии; природа промежуточных деплоев не
исследована этой сессией.
