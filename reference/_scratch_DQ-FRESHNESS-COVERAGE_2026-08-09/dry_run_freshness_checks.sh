#!/bin/bash
# DQ-FRESHNESS-COVERAGE — dry_run всех спроектированных проверок свежести (read-only, класс A).
# ADR-055 §3/§4: UTC-якорь + подтверждение личности вызывающего первой И последней командой.
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== caller identity (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"

run_dry() {
  local label="$1"
  local sql="$2"
  echo ""
  echo "--- dry_run: ${label} ---"
  bq query --project_id="${PROJECT}" --use_legacy_sql=false --dry_run "${sql}"
}

# ── 1. fact_purchases (A) техническая свежесть — часовая каденция, порог 2ч ──
run_dry "fact_purchases (A) technical" "
SELECT
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
    COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
    COUNT(*) AS n_rows
FROM \`${PROJECT}.core.fact_purchases\`
"

# ── 2. fact_purchases (B) бизнес-свежесть, без порога ──
run_dry "fact_purchases (B) business" "
SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(order_date), DAY) AS business_lag_days
FROM \`${PROJECT}.core.fact_purchases\`
"

# ── 3. fact_returns (A) техническая свежесть — недельная каденция, порог 336ч ──
run_dry "fact_returns (A) technical" "
SELECT
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
    COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
    COUNT(*) AS n_rows
FROM \`${PROJECT}.core.fact_returns\`
"

# ── 4. fact_returns (B) бизнес-свежесть, без порога ──
run_dry "fact_returns (B) business" "
SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(return_date), DAY) AS business_lag_days
FROM \`${PROJECT}.core.fact_returns\`
"

# ── 5. fact_inventory (A) техническая свежесть — суточная каденция, порог 48ч ──
run_dry "fact_inventory (A) technical" "
SELECT
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
    COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
    COUNT(*) AS n_rows
FROM \`${PROJECT}.core.fact_inventory\`
"

# ── 6. fact_inventory (B) бизнес-свежесть, без порога ──
run_dry "fact_inventory (B) business" "
SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(date_snapshot), DAY) AS business_lag_days
FROM \`${PROJECT}.core.fact_inventory\`
"

# ── 7. fact_payments (A) техническая свежесть — SQL валиден, НЕ готова (инвариант не подтверждён) ──
run_dry "fact_payments (A) technical [NOT READY - invariant unconfirmed]" "
SELECT
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
    COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
    COUNT(*) AS n_rows
FROM \`${PROJECT}.core.fact_payments\`
"

# ── 8. fact_payments (B) бизнес-свежесть, без порога ──
run_dry "fact_payments (B) business" "
SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(moment), DAY) AS business_lag_days
FROM \`${PROJECT}.core.fact_payments\`
"

# ── 9. fact_commissionreportin (A) техническая свежесть — SQL валиден, НЕ готова (инвариант не подтверждён) ──
run_dry "fact_commissionreportin (A) technical [NOT READY - invariant unconfirmed]" "
SELECT
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
    COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
    COUNT(*) AS n_rows
FROM \`${PROJECT}.core.fact_commissionreportin\`
"

# ── 10. fact_commissionreportin (B) бизнес-свежесть, без порога (moment TIMESTAMP → DATE, ADR-088 §3 DATE(M)) ──
run_dry "fact_commissionreportin (B) business" "
SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), DATE(MAX(moment)), DAY) AS business_lag_days
FROM \`${PROJECT}.core.fact_commissionreportin\`
"

# ── 11. fact_customer_invoices (A) техническая свежесть — перенесено, invoices_loader_design §9.2 ──
run_dry "fact_customer_invoices (A) technical [перенесено без изменений]" "
SELECT
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
  COUNT(DISTINCT _loaded_at)                                 AS distinct_load_stamps,
  COUNT(*)                                                   AS n_rows
FROM \`${PROJECT}.core.fact_customer_invoices\`
"

# ── 12. fact_customer_invoices (B) бизнес-свежесть — перенесено, invoices_loader_design §9.2 ──
run_dry "fact_customer_invoices (B) business [перенесено без изменений]" "
SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(moment), DAY) AS business_lag_days
FROM \`${PROJECT}.core.fact_customer_invoices\`
"

echo ""
echo "=== UTC anchor (end) ==="
date -u
echo "=== caller identity (end) ==="
gcloud auth list
