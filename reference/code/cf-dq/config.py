GCP_PROJECT  = "msklad-bi-prod"
GCS_RAW      = "msklad-raw-msklad-bi-prod"
GCS_ARCHIVE  = "msklad-archive-msklad-bi-prod"
BQ_STG       = "msklad-bi-prod.stg_msklad"
BQ_CORE      = "msklad-bi-prod.core"
BQ_AUDIT     = "msklad-bi-prod.audit"
BQ_MARTS     = "msklad-bi-prod.marts"
BQ_BACKUP    = "msklad-bi-prod._backup"
SA_BOOTSTRAP = "bootstrap-sa@msklad-bi-prod.iam.gserviceaccount.com"
SA_ETL       = "etl-sa@msklad-bi-prod.iam.gserviceaccount.com"
MSKLAD_BASE  = "https://api.moysklad.ru/api/remap/1.2"
MSKLAD_RPS   = 4
PAGE_SIZE    = 1000
SECRET_TOKEN = "msklad-token"
DQ_DRIFT_THRESHOLD         = 0.10
DQ_DRIFT_WEEKEND_THRESHOLD = 0.03
DQ_FRESHNESS_MAX_DAYS   = 3
DQ_CURRENCY_MAX_AVG_REV = 10_000_000

# DQ-FRESHNESS-COVERAGE (подготовка, класс A) — пороги технической свежести (A) для шести таблиц
# ядра без наблюдателя. Формула: порог_часов = 2 × период_каденции (03_PIPELINE_SPEC.md:86,
# "два пропущенных прогона"), тот же способ построения, что уже принят для fact_customer_invoices
# (reference/invoices_loader_design_2026-08-02.md §9.2, порог 48ч). Функции проверок — рядом в
# main.py, НЕ подключены к списку CHECKS (деплой/подключение — отдельная задача класса B,
# "DQ-FRESHNESS-COVERAGE, деплой").
DQ_FRESHNESS_PURCHASES_MAX_HOURS = 2
# step_purchases, msklad-pipeline-hourly (NON-BLOCKING), расписание "0 * * * *" (11_INFRA_FACTS.md)
# → часовая каденция → 2 × 1ч = 2ч.

DQ_FRESHNESS_RETURNS_MAX_HOURS = 336
# step_returns, ТОЛЬКО msklad-pipeline-weekly, расписание "0 1 * * 0" (11_INFRA_FACTS.md)
# → недельная каденция → 2 × 168ч (7 суток) = 336ч (14 суток).

DQ_FRESHNESS_INVENTORY_MAX_HOURS = 48
# cf-inventory-trigger, расписание "0 21 * * *" UTC (11_INFRA_FACTS.md)
# → суточная каденция → 2 × 24ч = 48ч.

DQ_FRESHNESS_INVOICES_MAX_HOURS = 48
# core.fact_customer_invoices — перенесено без изменений из
# reference/invoices_loader_design_2026-08-02.md §9.2 (суточный загрузчик → 2 × 24ч = 48ч).

# DQ_FRESHNESS_PAYMENTS_MAX_HOURS / DQ_FRESHNESS_COMMISSIONREPORTIN_MAX_HOURS — НЕ заводятся.
# Номинальная величина по формуле была бы 48ч (finance-daily-update / loss-commission-daily-update,
# суточная каденция, "0 3 * * *" Asia/Bishkek, 11_INFRA_FACTS.md), но инвариант "один стамп
# _loaded_at на прогон" ОПРОВЕРГНУТ чтением кода для обеих таблиц (cf-finance/main.py:72,
# cf-loss-commission/main.py:149 — datetime.now()/utcnow() вызывается ОТДЕЛЬНО на каждую строку,
# не один раз на прогон), см. reference/dq_freshness_coverage_2026-08-09.md §открытые вопросы.
# Проверка (A) для этих двух таблиц не готова к переносу — константа порога не заводится, чтобы
# не создавать видимость готовой проверки (05_CONVENTIONS ★ anti-improvisation).
