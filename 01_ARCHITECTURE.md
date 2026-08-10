# 01 · ARCHITECTURE — Топология и порядок прогона

**Версия:** 0.3 (+ факт `cf-alert`/weekly-DAG/правка порядка часового прогона, `INFRA-FACTS-LANDING`) · **Статус:** STABLE
**Назначение:** топология слоёв МойСклад → GCS/BQ (`stg`/`core`/`marts`) → Looker Studio; DAG и последовательность прогона; слой потребителей.
Секции — скелет: заголовок + указатель трассировки. Прод-наполнение прозой — P4.

---

## §топология

**Слои (RB-03, первичный источник — ASCII-схема архитектуры):**

```
МойСклад REST API v1.2
        │
        │  (Cloud Functions gen2, region: asia-east1)
        ▼
┌───────────────────────────────────────────────────┐
│  cf-facts (hourly + weekly)                       │  mode=hourly → 7d rolling
│  cf-dim   (daily 03:00 KGT)                       │  mode=weekly → 90d MERGE
│  cf-fx    (daily) ← Bakai Bank OpenBanking API    │  MERGE по дате (идемпотентно)
│  cf-inventory (daily 03:00 KGT snapshot)          │
│  cf-dq    (DQ Gate, вызывается из workflow)       │
│  cf-alert (webhook для Telegram алертов)          │
│  cf-finance (daily 03:00 KGT) ⚠️ allow-unauthenticated │  MERGE paymentout+cashout → fact_payments
└───────────────────────────────────────────────────┘
        │ raw JSON (immutable)         │ BQ loads
        ▼                              ▼
  GCS: msklad-raw-msklad-bi-prod/  BigQuery: msklad-bi-prod
  (lifecycle 365 дней)             ├── stg_msklad (TTL 14d)
                                   ├── core
                                   │   ├── fact_sales_profit   (+ sales_channel, project)
                                   │   ├── fact_returns
                                   │   ├── fact_inventory
                                   │   ├── fact_purchases     (+ order_name)
                                   │   ├── fact_payments      (cf-finance, полная выгрузка + DELETE-постфильтр после MERGE)
                                   │   ├── dim_products        (+ weight)
                                   │   ├── dim_counterparties  (+ country, SCD2)
                                   │   ├── dim_employees
                                   │   ├── dim_fx_rates        (Bakai Bank → НБКР rate)
                                   │   └── dim_metadata_mappings
                                   ├── audit                   (см. ниже — узел audit)
                                   ├── marts
                                   │   ├── sales_overview      (+ sales_channel, project)
                                   │   ├── inventory_health
                                   │   ├── gmroi / gmroi_by_folder
                                   │   ├── abc_xyz
                                   │   ├── in_transit          (+ order_name)
                                   │   ├── supplier_price_history
                                   │   └── weight_flow         (KPI кладовщиков)
                                   └── _backup
                                            ▼
                                     Looker Studio
                                     ├── Инвестор KGS
                                     ├── Склад (+ weight KPI)
                                     ├── Операционка (+ каналы, проекты)
                                     └── Закупки в пути
```

**Ответственность CF (PR-07 колонка 4):**

| CF | Ответственность |
|---|---|
| cf-dim | Загрузка `dim_products` (incl. weight), `dim_counterparties` (incl. country), `dim_employees`, `dim_metadata_mappings` |
| cf-facts | Загрузка `fact_sales_profit` (incl. sales_channel, project), `fact_purchases` (incl. order_name) |
| cf-fx | Загрузка `dim_fx_rates` из Bakai Bank OpenBanking API (НБКР officialRates) |
| cf-inventory | Ежедневный снэпшот `fact_inventory` в 03:00 KGT |
| cf-dq | DQ Gate: 6 чеков перед promote |
| cf-finance | Загрузка `fact_payments` (paymentout+cashout); заменяет standalone `load_payments.py` |
| cf-alert | Webhook для Telegram-алертов |

**`cf-alert`** (факт **2026-08-01**, `gcloud functions describe cf-alert --project=msklad-bi-prod --region=asia-east1 --gen2`, `reference/infra_facts_sweep_2026-08-01.md §Q-12`): Cloud Function gen2, HTTP, регион `asia-east1`; единственная ревизия `cf-alert-00001-bej` — с момента создания (`createTime 2026-05-13T12:23:18Z`) ни разу не редеплоена; `state: ACTIVE`. URI (Cloud Run native) `https://cf-alert-xw5u2boozq-de.a.run.app`, legacy URL `https://asia-east1-msklad-bi-prod.cloudfunctions.net/cf-alert`; `serviceAccountEmail: etl-sa@msklad-bi-prod.iam.gserviceaccount.com`; `timeoutSeconds: 30`. Полный состав секретов и полей — `11_INFRA_FACTS.md §CF`/§секреты (дом волатильных инфра-фактов, дублирования здесь нет).

Роль в схеме уведомления (факт **2026-08-02**, `reference/dq_source_capture_2026-08-02.md §5`): `cf-alert` — webhook-канал Cloud Monitoring для Telegram; ни `cf-dq`, ни тексты обоих Cloud Workflow (`msklad-pipeline-hourly`/`-weekly`) его не вызывают (сплошной `grep`, 0 совпадений в обоих) — уведомление устроено на уровне alert policy Cloud Monitoring, не прямым вызовом из пайплайна. Текущее состояние фильтра лог-метрики DQ-алерта закрыто отдельной задачей — `DQ-ALERT-FILTER-FIX` (`ADR-149`, `reference/dq_alert_filter_fix_2026-08-09.md`), здесь не пересказывается.

**Узел `audit`** (ADR-008 §Решение 1): датасет `audit` в BigQuery хранит ежедневные append-снапшоты трёх dim-таблиц (`dim_products`, `dim_counterparties`, `dim_employees`) — инструментация, не доменная логика мартов. Config ID/расписание/стратегия → `11_INFRA_FACTS` §SQ; схема датасета → `/reference` (Q-4); SQL → `/reference/sql/`. Промоушен в consumer-facing спеку — только по появлении аналитического требования (новый ADR).

*(RB-03, PR-07, ADR-008 §Решение 1)*

## §DAG — последовательность прогона

**Workflow:** `msklad-pipeline-hourly` (Cloud Workflows, `asia-east1`), расписание — каждый час (PR-20).

**Порядок шагов** (факт **2026-08-05**, снимок `reference/code/cf-facts/workflow_hourly.yaml`, sha256
`821edbeef502d786b2345219a01f0f7c2cee36d8d0b184a7ac63b85395eac47f`, побайтово сверен с живой ревизией
`000004-5fc` — `reference/code/cf-facts/MANIFEST.md §Cloud Workflows`, `DQ-GATE-SCOPE-SPLIT-DEPLOY`):
```
init → step_dim → step_fx → step_facts(mode=hourly) → step_purchases(mode=purchases, window_days=90, NON-BLOCKING) → step_dq → parse_dq_result → check_dq → step_promote(mode=promote, window_days=7) → done
```
**Исправление порядка (с 2026-08-05, `DQ-GATE-SCOPE-SPLIT`):** `step_purchases` стоит ДО `step_dq`, не
после `step_promote`, как утверждала предыдущая редакция этой строки.

**Маппинг шагов на диагностику при сбое (RB-19, §7 Workflows упал):**

| Шаг | Причина | Диагностика |
|---|---|---|
| raise_dim | CF-Dim упал | Логи `cf-dim` |
| raise_fx | CF-FX упал | Логи `cf-fx` / ротация токена Bakai |
| raise_facts | CF-Facts hourly упал | Логи `cf-facts` |
| raise_dq | CF-DQ crashed | Логи `cf-dq` |
| raise_dq_failed | DQ Gate FAILED | `10_OPS_PLAYBOOK` §2 (DQ Gate провалился) |
| raise_promote | Promote упал | Логи `cf-facts mode=promote` |

`step_purchases` (hourly) — **NON-BLOCKING**: `except`-ветка несёт только `sys.log severity=WARNING`
(`workflow_hourly.yaml:91`), шага `raise_*` нет — сбой не прерывает workflow по построению.

*(PR-20, RB-19, факт 2026-08-05)*

**Weekly-workflow (`msklad-pipeline-weekly`)** — факт **2026-08-07** (снимок
`reference/code/cf-facts/workflow_weekly.yaml`, sha256
`a1a58a2f385ac1d32c488cae45134c08ed9f3e1097bb808eb2d0253527115ff8`, побайтово сверен с живой ревизией
`000005-124` — `reference/code/cf-facts/MANIFEST.md §Cloud Workflows`, `SALES-PERIMETER-CADENCE-DEPLOY`).
Расписание — `0 1 * * 0`, UTC (`11_INFRA_FACTS.md §CF`, инвентарь Cloud Scheduler). Вызовы — `http.post`,
`auth: type: OIDC`.

**Порядок двенадцати шагов** (`init` шагом не считается):
```
init → step_dim → step_fx → step_facts(mode=weekly) → step_purchases(mode=purchases) →
step_returns(mode=returns, window_days=90) → step_perimeter(mode=perimeter, window_days=90) →
step_dq → parse_dq_result → check_dq → step_promote(mode=promote, window_days=90) →
step_perimeter_promote(mode=perimeter_promote, window_days=90) → done
```

**Блокирующая семантика — различна по конвейеру, берётся из текста снимка, не по аналогии:**

| Шаг | Конвейер | Блокирует promote при ошибке |
|---|---|---|
| `step_purchases` | hourly | **НЕТ** — `except`/`sys.log severity=WARNING`, без `raise_*` (`workflow_hourly.yaml:91`) |
| `step_purchases` | weekly | **ДА** — собственный `raise_purchases` (`workflow_weekly.yaml:107`) |
| `step_returns` | weekly (в hourly нет) | **ДА** — собственный `raise_returns` (`workflow_weekly.yaml:134`) |
| `step_perimeter` | weekly (в hourly нет) | **ДА** — собственный `raise_perimeter` (`workflow_weekly.yaml:162`) |
| `step_perimeter_promote` | weekly (в hourly нет) | **ДА** — собственный `raise_perimeter_promote` (`workflow_weekly.yaml:255`) |

Комментарий в снимке у `step_returns` («После promote — независимая таблица») отстаёт от фактического
порядка — шаг стоит ДО гейта; порядок взят из последовательности шагов, не из комментария.

*(PR-20, факт 2026-08-07, `reference/code/cf-facts/MANIFEST.md §Cloud Workflows`)*

## §потребители — слой Looker Studio

**Страницы LS ↔ источники (PR-39):**

| Страница | Источники LS | Назначение |
|---|---|---|
| Инвестор | `msklad_sales_overview` | Выручка, маржа, динамика для инвестора |
| Склад | `msklad_weight_flow`, `msklad_inventory_health`, `msklad_in_transit` | KPI кладовщиков, остатки, «В пути» |
| Операционка | `msklad_sales_overview`, `msklad_counterparty_returns`, `msklad_customer_invoices_ar` | Менеджеры, контрагенты, страны, дебиторка |
| Закупки в пути | `msklad_in_transit` | Детализация заказов поставщику |
| Расходы | `msklad_expenses` | Burn rate, П&Л-расходы для владельцев/инвесторов |

**Назначение страниц LS для мартов (PR-30):** `marts.abc_xyz` (ABC/XYZ-классификация) и `marts.supplier_price_history`/`marts.gmroi`/`marts.gmroi_by_folder` не имеют прямого соответствия странице LS в таблице PR-39 — используются как аналитические марты без выделенной LS-страницы на момент источника (не GAP, просто отсутствие назначенной страницы в замороженном источнике).

*(PR-39, PR-30)*
