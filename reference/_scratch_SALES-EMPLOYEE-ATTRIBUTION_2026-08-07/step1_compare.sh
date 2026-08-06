#!/bin/bash
set -euo pipefail
date -u
gcloud auth list

echo "=== q1: our current per-counterparty breakdown inside Turdalieva's manager-corzina, July, opt+ofis ==="
bq query --use_legacy_sql=false --format=prettyjson '
SELECT
  c.name AS counterparty_name,
  f.agent_id,
  COUNT(*) AS row_count,
  ROUND(SUM(f.revenue_kgs), 2) AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit` f
LEFT JOIN `msklad-bi-prod.core.dim_counterparties` c
  ON f.agent_id = c.agent_id AND c.scd2_is_current = TRUE
LEFT JOIN `msklad-bi-prod.core.dim_employees` e
  ON c.owner_employee_id = e.employee_id
WHERE f.transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
  AND COALESCE(f.sales_channel_name, "Не указан") IN ("Оптовая торговля", "Не указан")
  AND e.full_name = "Турдалиева А. М."
GROUP BY counterparty_name, f.agent_id
ORDER BY revenue_kgs DESC
' > q1_turdalieva_our_counterparties.json

echo "=== q2: for the 30 counterparty NAMES from the client xls, current manager on our side + July revenue (any manager) ==="
bq query --use_legacy_sql=false --format=prettyjson '
WITH xls_names AS (
  SELECT name FROM UNNEST([
    "ООО \"ХОЛЛИШОП\" Москва ( ДОГОВОР РФ)",
    "Руслан Алматы +77471880101",
    "Диана NANA skinstore Шымкент +7 701 882 9090",
    "ИП Лигай Леон Di Store +996705445044 (ДОГОВОР КР)",
    "Лаура Карабалаева (Айнура) +77780074698",
    "ИП Лигай Даяна +996 705 445 044 (ДОГОВОР КР) Di Store",
    "Хакимова Дильноза Узбекистан +998998826564 КОД 40044",
    "Асель Токтосунова @optovye_ceny01 0706552277",
    "Инна Андрей Алматы +77017888000",
    "Алиева Салима Шахбановна  Дагестан , Каспийск +77057770802",
    "Разуев Роберт Махачкала +79887856222",
    "Муслима г.Хасавюрт  +79282247800",
    "Илияз WB (Договор) ИП Женишбекова Альбина Женишбековна",
    "Аблов Константин Алматы +7 705 333 8405",
    "TOO \"GLAMA\" Аблов +7 705 333 8405 (ДОГОВОР КЗ)",
    "Оксана Ташкент Kshopkorea +998909385015 Код 40501",
    "Таня Казарян Астана +7 778 900 9325",
    "Асиф Керимли Алматы The Beauty Store +77478155521",
    "Елена Ким Ташкент (Александра) Код 40612",
    "Умида Ташкент vitamino.uz +998939727318 КОД 40129",
    "ИП Мигали Иван Иванович +79660454959  (ДОГОВОР РФ)",
    "Санам Шымкент SANAM_BEAUTYLAB +7 775 333 0504",
    "Динар тате Алматы +77029472121",
    "Анара Женишбекова +996554429997 (ДОГОВОР КР)",
    "Екатерина Богомолова г. Кемерово, Россия  +79505744340",
    "ИП Красовский Владимир Россия Федор +79260090240  (Договор РФ)",
    "Яна Севастополь +79787251890",
    "Якубова Фарзона +992 928247700",
    "Kumurska_cosmetics +996222940110 (ДОГОВОР КР)",
    "Асель Holi"
  ]) AS name
)
SELECT
  x.name AS xls_name,
  c.name AS our_name,
  c.agent_id,
  e.full_name AS our_current_manager,
  (SELECT ROUND(SUM(f.revenue_kgs),2) FROM `msklad-bi-prod.core.fact_sales_profit` f
   WHERE f.agent_id = c.agent_id AND f.transaction_date BETWEEN "2026-07-01" AND "2026-07-31") AS july_revenue_kgs
FROM xls_names x
LEFT JOIN `msklad-bi-prod.core.dim_counterparties` c
  ON c.name = x.name AND c.scd2_is_current = TRUE
LEFT JOIN `msklad-bi-prod.core.dim_employees` e
  ON c.owner_employee_id = e.employee_id
ORDER BY x.name
' > q2_xls_names_our_side.json

date -u
gcloud auth list
