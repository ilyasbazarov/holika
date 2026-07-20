# 11 · INFRA_FACTS — волатильные инфра-факты

**Версия:** 0.2 (+ §CF/§секреты cf-finance/cf-fx, M-P4-A-03) · **Статус:** LIVING
**Назначение:** канонический реестр волатильных инфра-фактов — URL/ревизии CF, Config ID SQ, расписания, IAM, секреты (имена). Обновляется часто, при каждом деплою/ротации секретов (ADR-004).
**Состав по `00_CHARTER §карта документов` стр.53.**

---

## §CF (URL/ревизии)

**cf-finance** (конфигурация актуальна на 2026-06-25, PR-13):
```bash
gcloud functions deploy cf-finance \
  --gen2 --runtime=python312 --region=asia-east1 \
  --source=. --entry-point=main \
  --trigger-http \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=512MB --timeout=1800s \
  --set-secrets="MSKLAD_TOKEN=msklad-token:latest"
```
- Исходники: `/home/ilyasbazarov4/cf-finance` (Cloud Shell persistent disk)
- Revision: `cf-finance-00006-piv` (история: `00001-wiv` первый деплой 2026-06-18 → `00005-wob` фикс таймаута 2026-06-25 → `00006-piv` фикс `trigger_marts()` 2026-06-25)
- URI (Cloud Run native): `https://cf-finance-xw5u2boozq-de.a.run.app`
- Legacy URL: `https://asia-east1-msklad-bi-prod.cloudfunctions.net/cf-finance`
- Cloud Scheduler: `finance-daily-update`, `0 3 * * *`, `Asia/Bishkek`, HTTP POST на URI выше. `attemptDeadline=180s`; серверный `--timeout` самой CF = `1800s` (≫ наблюдённый runtime 5+ мин — сервер укладывается с запасом; остаётся открытым Q-43: обрывает ли клиентский `attemptDeadline` серверную обработку). `retryConfig.maxRetryDuration=0s` — ретраев НЕТ (DROP-DUP c RB-42; падение Scheduler тихо проглатывается, алерт только от мониторинга 5xx на Cloud Run). Вызов аутентифицирован через `--oidc-service-account-email=etl-sa@msklad-bi-prod.iam.gserviceaccount.com` (ADR-022, с 2026-07-20).
- ⚠️ TD-SEC-01 — подтверждённый инцидент 2026-07-20, устранён IAM-lockdown (ADR-022): `allUsers`-invoker снят, вызов только через `etl-sa` (OIDC).
- Ops-следствие (ADR-022 §4, флаг, не гейт): после lockdown любой ручной/ad-hoc вызов `cf-finance` требует identity-token, анонимный `curl` больше не работает. `10_OPS_PLAYBOOK` не существует (Q-35, DEFER) — нота живёт здесь.

**cf-fx** (после миграции 2026-06-03, PR-18):
- Внешний источник (не собственный CF URL, а вызываемый API): `BAKAI_FX_URL = "https://openbanking-api.bakai.kg/api/Directory/GetRateDirectory"` (Bakai Bank OpenBanking API → `officialRates[USD].rate`, курс НБКР).
- Ревизия/URL самой CF `cf-fx`: не зафиксированы в источнике на момент этой сессии → *(пусто, ожидает discovery)*.

**cf-facts** — URL/ревизия: не зафиксированы в источнике на момент этой сессии → *(пусто, ожидает discovery)*.
**cf-dq** — актуальная ревизия после T-1-фикса не подтверждена в источнике → **GAP Q-6** (см. `07_STATE`); последняя известная в источнике — `cf-dq-00006-lac` (⚠ дата этой ревизии предшествует T-1-фиксу 2026-06-24, канон не зафиксирован, не выдавать за актуальную).

Источник-адрес: `00_CHARTER §карта документов` стр.53; ADR-004 §Последствия (PR-13); PR-35 правило 41 (DROP-DUP); RB-42 (`maxRetryDuration=0s`).

## §SQ (Config ID + расписания)

Источник: `reference/sql/README.md` (выгрузка 2026-07-07, проект `msklad-bi-prod`, location `asia-east1`) · ADR-008 §Решение (1) · PR-21.

| Config ID | displayName | Целевая таблица | Schedule | Состояние |
|---|---|---|---|---|
| `69fc93d1-0000-2d64-bdd1-30fd381336b4` | `sq_audit_dim_products_snapshot` | `msklad-bi-prod.audit.dim_products_snapshots` | every day 04:00 (подтверждено run history 2026-07-17: 71 прогон, все 04:00 UTC) | ⚠ **FAILED с 2026-06-03** — schema drift (ADR-019): `Inserted row has wrong column count; Has 15, expected 14 at [2:1]`. Дельта = `weight` FLOAT64 (`core.dim_products` поз.14, в цели отсутствует); поз.1–13 идентичны; `snapshot_at` занимает поз.14 цели ⇒ `ALTER … ADD COLUMN` НЕ чинит (ADR-019 §3). Последний срез 2026-06-02 04:00:10; дыра 45 суток безвозвратна. Фикс = вариант E → задача `AUDIT-SNAPSHOT-FIX` (после Step 6 `E1-T3-MECH-FX`). Пометка «as-is, не чинить» СНЯТА (ADR-019). Провенанс: `/reference/sq_audit_dim_products_drift_2026-07-17.md` |
| `69fc9c75-0000-2ab4-91b3-883d24f4db64` | `sq_audit_dim_counterparties_snapshot` | `msklad-bi-prod.audit.dim_counterparties_snapshots` | every day 04:00 | SUCCEEDED |
| `69fc9d6e-0000-2ab4-91b3-883d24f4db64` | `sq_audit_dim_employees_snapshot` | `msklad-bi-prod.audit.dim_employees_snapshots` | every day 04:00 | SUCCEEDED |
| `6a22a243-0000-20fd-a458-883d24f4cad4` | `sq_marts_expenses` | `msklad-bi-prod.marts.expenses` | every 24 hours (BQ DTS default, ~11:10 UTC; schedule-поле пустое, nextRunTime активен) | SUCCEEDED · провенанс live-recheck: `/reference/bq_transferconfig_sq_marts_expenses_2026-07-08.txt` (ADR-012) |
| `6a23f3ea-0000-2952-853d-582429be7ecc` | `sq_marts_customer_invoices_ar` | `msklad-bi-prod.marts.customer_invoices_ar` | **фактически ежедневно, якорь ~10:00 UTC** (run history 2026-07-17: 43 прогона подряд, посл. 2026-07-17 10:00 UTC; поле `schedule` в конфиге НЕ снято — остаток Q-21) | SUCCEEDED · 0 не-OK / 43 · провенанс: `/reference/sq_fleet_health_2026-07-17.md` (ADR-020 §6) |

Трассировка: ADR-008 §Решение (1) — дом Config ID/расписание/стратегия = `11 §SQ`; схема датасета `audit` → `/reference` (гейт Q-4); SQL → `/reference/sql/` (гейт Q-5, уже выгружен). ADR-012 §5/провенанс: живая bq show 2026-07-08, мед-реверификация расписания (выявлено дефолтное 24h, исходная формулировка ошибочно указывала «manual»).

## §IAM

**cf-finance (ADR-022, 2026-07-20):** `roles/run.invoker` предоставлен `etl-sa@msklad-bi-prod.iam.gserviceaccount.com`; привязка `allUsers` → `run.invoker` снята. Верификация 2026-07-20: анонимный запрос → `403`; вызов Scheduler (OIDC через тот же SA) → `200`.

**Известная не-блокирующая аномалия (Q-28, DEFER):** в логе E1-T2 (2026-07-14) при
`gcloud secrets versions access` — `Regional Access Boundary … 404 Gaia id not found for
ilyasbazarov4@gmail.com`. Прогон отработал (токен резолвился). Триггер расследования: повтор ИЛИ появление
в не-интерактивном / service-account прогоне. См. `07_STATE` Q-28.

Источник-адрес: `00_CHARTER §карта документов` стр.53; ADR-004 §Последствия (RB-05 «аспект IAM»).

## §секреты (имена)

- `bakai-fx-token` — Secret Manager, JWT-токен (Bearer auth) для Bakai OpenBanking API, используется `cf-fx` (PR-18). **TTL токена неизвестен → GAP Q-7** (см. `07_STATE`); рабочая DEFER-политика — ротация по факту 401 (`10_OPS_PLAYBOOK` §17).
- `msklad-token` — Secret Manager, используется `cf-finance` (`MSKLAD_TOKEN`, PR-13).

Источник-адрес: `00_CHARTER §карта документов` стр.53; ADR-004 §Последствия (PR-18 «cf-fx URL/секрет», PR-13).

---

**Вне scope этой сессии (M-P4-A-03):** URL/ревизия самих CF `cf-fx`/`cf-facts` (не зафиксированы в источнике — остаются пустыми слотами); `10_OPS_PLAYBOOK`; схема датасета `audit` (Q-4); IAM (RB-05, не в scope A-03).
