# 01 · ARCHITECTURE — Топология и порядок прогона

**Версия:** 0.2 (§топология/§DAG/§потребители наполнены, M-P4-A-01) · **Статус:** STABLE
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

**⚠️ GAP Q-12 (факт):** `cf-alert` присутствует на ASCII-схеме (RB-03) как узел топологии, но отсутствует в таблице CF источника (PR-07) — URL/ревизия/конфиг/канал Telegram нигде не задокументированы. Это **явный placeholder**, НЕ примирять и НЕ выдумывать конфиг; discovery — `gcloud functions describe cf-alert` + конфиг алертинга (закрывается отдельным брифом, заменит placeholder).

**Узел `audit`** (ADR-008 §Решение 1): датасет `audit` в BigQuery хранит ежедневные append-снапшоты трёх dim-таблиц (`dim_products`, `dim_counterparties`, `dim_employees`) — инструментация, не доменная логика мартов. Config ID/расписание/стратегия → `11_INFRA_FACTS` §SQ; схема датасета → `/reference` (Q-4); SQL → `/reference/sql/`. Промоушен в consumer-facing спеку — только по появлении аналитического требования (новый ADR).

*(RB-03, PR-07, ADR-008 §Решение 1)*

## §DAG — последовательность прогона

**Workflow:** `msklad-pipeline-hourly` (Cloud Workflows, `asia-east1`), расписание — каждый час (PR-20).

**Порядок шагов:**
```
step_dim → step_fx → step_facts(hourly) → step_dq → [check_dq] → step_promote(window=7) → step_purchases(window=90, NON-BLOCKING)
```

**Маппинг шагов на диагностику при сбое (RB-19, §7 Workflows упал):**

| Шаг | Причина | Диагностика |
|---|---|---|
| raise_dim | CF-Dim упал | Логи `cf-dim` |
| raise_fx | CF-FX упал | Логи `cf-fx` / ротация токена Bakai |
| raise_facts | CF-Facts hourly упал | Логи `cf-facts` |
| raise_dq | CF-DQ crashed | Логи `cf-dq` |
| raise_dq_failed | DQ Gate FAILED | `10_OPS_PLAYBOOK` §2 (DQ Gate провалился) |
| raise_promote | Promote упал | Логи `cf-facts mode=promote` |

Явного `raise_*`-шага для `step_purchases` в источнике нет (шаг NON-BLOCKING по определению DAG — сбой не прерывает workflow).

**Weekly-workflow (`msklad-pipeline-weekly`)** — расписание известно из источника, но состав шагов не задокументирован → **GAP Q-13** (вне scope этой сессии).

*(PR-20, RB-19)*

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
