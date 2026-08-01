#!/usr/bin/env bash
# E1-T3-CLOSE · класс A, только чтение. Размер остатка после закрытия Q-96.
set -u
echo "=== ЯКОРЬ НАЧАЛА ==="; date -u; gcloud auth list 2>&1 | tail -3
echo; echo "=== Инвентарь fact_payments по типу документа ==="
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson \
"SELECT payment_type, COUNT(*) AS docs, MIN(moment) AS first_doc, MAX(moment) AS last_doc,
        ROUND(SUM(sum_kgs),2) AS sum_kgs, MIN(DATE(_loaded_at)) AS loaded_min, MAX(DATE(_loaded_at)) AS loaded_max
 FROM \`msklad-bi-prod.core.fact_payments\` GROUP BY payment_type ORDER BY docs DESC" 2>&1
echo; echo "=== Зона паритета (moment >= 2026-05-01) помесячно ==="
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson \
"SELECT payment_type, FORMAT_DATE('%Y-%m', moment) AS ym, COUNT(*) AS docs,
        ROUND(SUM(sum_kgs),2) AS sum_kgs, MIN(DATE(_loaded_at)) AS loaded_min, MAX(DATE(_loaded_at)) AS loaded_max
 FROM \`msklad-bi-prod.core.fact_payments\` WHERE moment >= '2026-05-01'
 GROUP BY payment_type, ym ORDER BY ym, payment_type" 2>&1
echo; echo "=== Строки зоны паритета, НЕ переписанные после деплоя правки (2026-07-20) ==="
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson \
"SELECT payment_id, payment_name, payment_type, moment, expense_item_name, agent_name,
        payment_purpose, sum_kgs, _loaded_at
 FROM \`msklad-bi-prod.core.fact_payments\`
 WHERE moment >= '2026-05-01' AND _loaded_at < TIMESTAMP('2026-07-20')
 ORDER BY moment" 2>&1
echo; echo "=== ЯКОРЬ КОНЦА ==="; date -u; gcloud auth list 2>&1 | tail -3
