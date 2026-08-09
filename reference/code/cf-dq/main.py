import functions_framework, json, logging, uuid
from google.cloud import bigquery
from config import (
    GCP_PROJECT, DQ_DRIFT_THRESHOLD, DQ_DRIFT_WEEKEND_THRESHOLD, DQ_FRESHNESS_MAX_DAYS,
    DQ_CURRENCY_MAX_AVG_REV,
    DQ_FRESHNESS_PURCHASES_MAX_HOURS, DQ_FRESHNESS_RETURNS_MAX_HOURS,
    DQ_FRESHNESS_INVENTORY_MAX_HOURS, DQ_FRESHNESS_INVOICES_MAX_HOURS,
)
from helpers import get_bq_client, run_scalar, run_row, write_dq_results

log = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

STAGING     = f"{GCP_PROJECT}.stg_msklad.fact_sales_staging"
CORE_FACT   = f"{GCP_PROJECT}.core.fact_sales_profit"
DIM_PRODUCT = f"{GCP_PROJECT}.core.dim_products"

# DQ-FRESHNESS-COVERAGE (подготовка, класс A) — шесть таблиц ядра без наблюдателя.
CORE_PURCHASES = f"{GCP_PROJECT}.core.fact_purchases"
CORE_RETURNS   = f"{GCP_PROJECT}.core.fact_returns"
CORE_INVENTORY = f"{GCP_PROJECT}.core.fact_inventory"
CORE_PAYMENTS  = f"{GCP_PROJECT}.core.fact_payments"
CORE_COMMISSIONREPORTIN = f"{GCP_PROJECT}.core.fact_commissionreportin"
CORE_INVOICES  = f"{GCP_PROJECT}.core.fact_customer_invoices"

def check_not_empty(bq):
    count = run_scalar(bq, f"SELECT COUNT(*) FROM `{STAGING}`") or 0
    return count > 0, f"staging_count={count}"

def check_drift(bq):
    # BQ DAYOFWEEK: 1=Sunday, 7=Saturday
    # Изменено на T-1 (вчерашний день) для исключения ложных внутридневных срабатываний
    row = run_row(bq, f"""
        WITH target_d AS (
            SELECT DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 1 DAY) AS d
        )
        SELECT
            CAST(target_d.d AS STRING) AS target_date,
            EXTRACT(DAYOFWEEK FROM target_d.d) AS day_of_week,
            COALESCE(SUM(s.revenue_kgs), 0) AS target_rev
        FROM target_d
        LEFT JOIN `{STAGING}` s
          ON DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek') = target_d.d
        GROUP BY target_d.d
    """)
    
    if not row or row.get("target_date") is None:
        return False, "target_date=NULL"
        
    target_rev  = float(row.get("target_rev", 0) or 0)
    day_of_week = int(row.get("day_of_week", 2) or 2)
    target_date = row.get("target_date", "")
    is_weekend  = day_of_week in (1, 7)
    threshold   = DQ_DRIFT_WEEKEND_THRESHOLD if is_weekend else DQ_DRIFT_THRESHOLD
    day_label   = "weekend" if is_weekend else "weekday"
    
    # ma7 считаем за 7 полных дней ДО вчерашнего (T-8 до T-2)
    ma7 = run_scalar(bq, f"""
        SELECT COALESCE(AVG(daily_rev),0) FROM (
            SELECT transaction_date, SUM(revenue_kgs) AS daily_rev
            FROM `{CORE_FACT}`
            WHERE transaction_date >= DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 8 DAY)
              AND transaction_date  <  DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 1 DAY)
            GROUP BY 1)
    """) or 0.0
    
    if ma7 == 0:
        return True, f"yesterday_rev={target_rev:.0f}, ma7=0 (нет истории → пропуск)"
        
    ratio = target_rev / float(ma7)
    return (ratio >= threshold,
            f"yesterday_rev={target_rev:.0f}, ma7={float(ma7):.0f}, ratio={ratio:.2f}, "
            f"threshold={threshold} ({day_label}), target_date={target_date}")

def check_fk_integrity(bq):
    orphans = run_scalar(bq, f"""
        SELECT COUNT(DISTINCT s.product_id) FROM `{STAGING}` s
        LEFT JOIN `{DIM_PRODUCT}` d ON s.product_id = d.product_id
        WHERE d.product_id IS NULL AND s.product_id IS NOT NULL
    """) or 0
    return orphans == 0, f"orphan_product_ids={orphans}"

def check_freshness(bq):
    row = run_row(bq, f"""
        SELECT
            CAST(MAX(DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw),
                          'Asia/Bishkek')) AS STRING) AS max_date,
            DATE_DIFF(
                CURRENT_DATE('Asia/Bishkek'),
                MAX(DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw),
                         'Asia/Bishkek')),
                DAY
            ) AS lag_days
        FROM `{STAGING}`
    """)
    if not row or row.get("max_date") is None:
        return False, "max_date=NULL (staging пустой)"
    lag_days = row["lag_days"] or 0
    return lag_days <= DQ_FRESHNESS_MAX_DAYS, f"max_date={row['max_date']}, lag_days={lag_days}"

def check_margin_sanity(bq):
    # staging не содержит margin_kgs (считается при promote).
    # Проверяем core.fact_sales_profit за последние 7 дней — результат прошлого promote.
    bad = run_scalar(bq, f"""
        SELECT COUNT(*) FROM `{CORE_FACT}`
        WHERE margin_kgs IS NOT NULL
          AND revenue_kgs IS NOT NULL
          AND margin_kgs > revenue_kgs
          AND transaction_date >= DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 7 DAY)
    """) or 0
    return bad == 0, f"bad_margin_rows={bad} (core, last 7d)"

def check_currency_normalization(bq):
    avg_rev = run_scalar(bq, f"""
        SELECT COALESCE(AVG(revenue_kgs),0) FROM `{STAGING}` WHERE revenue_kgs IS NOT NULL
    """) or 0.0
    return float(avg_rev) < DQ_CURRENCY_MAX_AVG_REV, f"avg_revenue_kgs={float(avg_rev):.2f}"

CHECKS = [
    ("not_empty",              check_not_empty),
    ("drift_check",            check_drift),
    ("fk_integrity",           check_fk_integrity),
    ("freshness",              check_freshness),
    ("margin_sanity",          check_margin_sanity),
    ("currency_normalization", check_currency_normalization),
]

# ═══════════════════════════════════════════════════════════════════════════
# DQ-FRESHNESS-COVERAGE (подготовка, класс A, 2026-08-09) — проверки свежести
# для шести таблиц ядра без наблюдателя. НЕ включены в CHECKS выше — эта
# задача не подключает проверки к живому гейту (подключение/деплой —
# отдельная задача класса B, "DQ-FRESHNESS-COVERAGE, деплой", мандат не
# выдан). Полное обоснование, вывод порогов и dry_run-логи —
# reference/dq_freshness_coverage_2026-08-09.md.
#
# Форма (A)/(B) — reference/invoices_loader_design_2026-08-02.md §9.2:
#   (A) техническая свежесть — блокирующая ПО ФОРМЕ (passed=False возможен),
#       но нигде не подключена; порог = 2 × период каденции.
#   (B) бизнес-свежесть — диагностика, ВСЕГДА passed=True, порога нет
#       (осознанный отказ — нет эмпирики пауз между документами).
# ═══════════════════════════════════════════════════════════════════════════

# ─── core.fact_purchases — часовая каденция (step_purchases, NON-BLOCKING) ───

def check_freshness_purchases_technical(bq):
    row = run_row(bq, f"""
        SELECT
            TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
            COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
            COUNT(*) AS n_rows
        FROM `{CORE_PURCHASES}`
    """)
    if not row or row.get("load_lag_hours") is None:
        return False, "load_lag_hours=NULL (таблица пустая)"
    lag = row["load_lag_hours"]
    return (lag <= DQ_FRESHNESS_PURCHASES_MAX_HOURS,
            f"load_lag_hours={lag}, distinct_load_stamps={row['distinct_load_stamps']}, n_rows={row['n_rows']}")

def check_freshness_purchases_business(bq):
    row = run_row(bq, f"""
        SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(order_date), DAY) AS business_lag_days
        FROM `{CORE_PURCHASES}`
    """)
    if not row or row.get("business_lag_days") is None:
        return True, "business_lag_days=NULL (таблица пустая)"
    return True, f"business_lag_days={row['business_lag_days']}"

# ─── core.fact_returns — недельная каденция (step_returns, ТОЛЬКО weekly) ───

def check_freshness_returns_technical(bq):
    row = run_row(bq, f"""
        SELECT
            TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
            COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
            COUNT(*) AS n_rows
        FROM `{CORE_RETURNS}`
    """)
    if not row or row.get("load_lag_hours") is None:
        return False, "load_lag_hours=NULL (таблица пустая)"
    lag = row["load_lag_hours"]
    return (lag <= DQ_FRESHNESS_RETURNS_MAX_HOURS,
            f"load_lag_hours={lag}, distinct_load_stamps={row['distinct_load_stamps']}, n_rows={row['n_rows']}")

def check_freshness_returns_business(bq):
    row = run_row(bq, f"""
        SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(return_date), DAY) AS business_lag_days
        FROM `{CORE_RETURNS}`
    """)
    if not row or row.get("business_lag_days") is None:
        return True, "business_lag_days=NULL (таблица пустая)"
    return True, f"business_lag_days={row['business_lag_days']}"

# ─── core.fact_inventory — суточная каденция (cf-inventory-trigger) ───

def check_freshness_inventory_technical(bq):
    row = run_row(bq, f"""
        SELECT
            TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
            COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
            COUNT(*) AS n_rows
        FROM `{CORE_INVENTORY}`
    """)
    if not row or row.get("load_lag_hours") is None:
        return False, "load_lag_hours=NULL (таблица пустая)"
    lag = row["load_lag_hours"]
    return (lag <= DQ_FRESHNESS_INVENTORY_MAX_HOURS,
            f"load_lag_hours={lag}, distinct_load_stamps={row['distinct_load_stamps']}, n_rows={row['n_rows']}")

def check_freshness_inventory_business(bq):
    row = run_row(bq, f"""
        SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(date_snapshot), DAY) AS business_lag_days
        FROM `{CORE_INVENTORY}`
    """)
    if not row or row.get("business_lag_days") is None:
        return True, "business_lag_days=NULL (таблица пустая)"
    return True, f"business_lag_days={row['business_lag_days']}"

# ─── core.fact_payments — суточная каденция (finance-daily-update) ───
#
# ⚠ Проверка (A) НЕ ЗАВЕДЕНА. Инвариант "один стамп _loaded_at на прогон"
# ОПРОВЕРГНУТ чтением reference/code/cf-finance/main.py:72 —
# `"_loaded_at": datetime.datetime.now(datetime.timezone.utc).strftime(...)`
# вызывается ОТДЕЛЬНО на каждую строку внутри цикла постранично, а не один
# раз на прогон (форма, названная антипаттерном в
# reference/invoices_loader_design_2026-08-02.md §6.4: "разброс по
# микросекундам, который дал бы datetime.now() внутри цикла (форма
# cf-finance/main.py:68)" — тот же файл, тот же класс дефекта). Без
# единого стампа "MAX(_loaded_at)" остаётся вычислимым, но готовность-условие
# "COUNT(DISTINCT _loaded_at) == 1 на прогон" не выполняется, а именно на
# нём построена семантика проверки (A) по образцу invoices. Открытый вопрос
# зафиксирован в reference/dq_freshness_coverage_2026-08-09.md, порог не
# назначен (config.py), функция технической проверки не пишется как готовая
# — только бизнес-диагностика ниже (она от инварианта не зависит).

def check_freshness_payments_business(bq):
    row = run_row(bq, f"""
        SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(moment), DAY) AS business_lag_days
        FROM `{CORE_PAYMENTS}`
    """)
    if not row or row.get("business_lag_days") is None:
        return True, "business_lag_days=NULL (таблица пустая)"
    return True, f"business_lag_days={row['business_lag_days']}"

# ─── core.fact_commissionreportin — суточная каденция (loss-commission-daily-update) ───
#
# ⚠ Проверка (A) НЕ ЗАВЕДЕНА. Тот же класс дефекта, что у fact_payments выше:
# reference/code/cf-loss-commission/main.py:149 (fetch_commission) —
# `"_loaded_at": datetime.datetime.utcnow().isoformat()` вызывается ОТДЕЛЬНО
# на каждую строку (isoformat() несёт микросекунды, разброс гарантирован при
# любом прогоне длиннее одной микросекунды). Тот же дефект пронаблюдён и в
# соседней fetch_loss (main.py:123, вне scope этой задачи). Открытый вопрос —
# reference/dq_freshness_coverage_2026-08-09.md.

def check_freshness_commissionreportin_business(bq):
    row = run_row(bq, f"""
        SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), DATE(MAX(moment)), DAY) AS business_lag_days
        FROM `{CORE_COMMISSIONREPORTIN}`
    """)
    if not row or row.get("business_lag_days") is None:
        return True, "business_lag_days=NULL (таблица пустая)"
    return True, f"business_lag_days={row['business_lag_days']}"

# ─── core.fact_customer_invoices — перенесено БЕЗ ИЗМЕНЕНИЙ ───
# Источник: reference/invoices_loader_design_2026-08-02.md §9.2 (уже готовый
# образец формы; эта задача не переизобретает проверки, только переносит и
# сверяет форму с образцом остальных пяти таблиц).

def check_freshness_invoices_technical(bq):
    row = run_row(bq, f"""
        SELECT
          TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
          COUNT(DISTINCT _loaded_at)                                 AS distinct_load_stamps,
          COUNT(*)                                                   AS n_rows
        FROM `{CORE_INVOICES}`
    """)
    if not row or row.get("load_lag_hours") is None:
        return False, "load_lag_hours=NULL (таблица пустая)"
    lag = row["load_lag_hours"]
    return (lag <= DQ_FRESHNESS_INVOICES_MAX_HOURS,
            f"load_lag_hours={lag}, distinct_load_stamps={row['distinct_load_stamps']}, n_rows={row['n_rows']}")

def check_freshness_invoices_business(bq):
    row = run_row(bq, f"""
        SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(moment), DAY) AS business_lag_days
        FROM `{CORE_INVOICES}`
    """)
    if not row or row.get("business_lag_days") is None:
        return True, "business_lag_days=NULL (таблица пустая)"
    return True, f"business_lag_days={row['business_lag_days']}"

@functions_framework.http
def main(request):
    body   = request.get_json(silent=True) or {}
    run_id = body.get("run_id", str(uuid.uuid4()))
    log.info("CF-DQ start | run_id=%s", run_id)
    bq = get_bq_client()
    results, all_passed, staging_empty = [], True, False
    for name, fn in CHECKS:
        if staging_empty and name != "not_empty":
            results.append({"name": name, "passed": True, "detail": "SKIP (staging пустой)"})
            continue
        try:
            passed, detail = fn(bq)
        except Exception as e:
            passed, detail = False, f"EXCEPTION: {e}"
        log.info("%s %s: %s", "✅" if passed else "❌", name, detail)
        results.append({"name": name, "passed": passed, "detail": detail})
        if not passed:
            all_passed = False
            if name == "not_empty":
                staging_empty = True
    try:
        write_dq_results(bq, run_id, results)
    except Exception as e:
        log.warning("audit write failed (non-blocking): %s", e)
    failed = [c["name"] for c in results if not c["passed"]]
    log.info("DQ Gate %s | run_id=%s", "PASSED" if all_passed else "FAILED", run_id)
    return json.dumps({"passed": all_passed, "run_id": run_id,
                       "status": "PASSED" if all_passed else "FAILED",
                       "failed_checks": failed, "checks": results}), 200
