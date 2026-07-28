#!/usr/bin/env bash
# Единственный оставшийся вопрос перед подменой: может ли приведение времени к дате
# сдвинуть документ на предыдущие сутки (а на границе месяца — в предыдущий месяц).
# ТОЛЬКО ЧТЕНИЕ.  Запуск:  bash moment_check.sh > run5.log 2>&1; cat run5.log
set -uo pipefail
PROJ="msklad-bi-prod"
Q() { bq --project_id="$PROJ" query --nouse_legacy_sql --format=pretty --max_rows=100 "$1"; }

echo "########## ЯКОРЬ (начало) ##########"
date -u; gcloud auth list --filter=status:ACTIVE --format='value(account)'

echo
echo "########## 1. СКОЛЬКО ДОКУМЕНТОВ ПОПАДАЮТ В ОПАСНЫЙ ЧАС ##########"
echo "   Приведение к дате берёт календарный день по UTC. Бишкек = UTC+6."
echo "   Значит разъезд возможен только у строк со временем 18:00–23:59 UTC:"
echo "   у них день по Бишкеку уже следующий. Если таких строк ноль — вопрос закрыт."
Q "SELECT 'fact_loss' AS tablica,
          COUNT(*) AS vsego_strok,
          COUNTIF(EXTRACT(HOUR FROM moment) >= 18) AS opasnyj_chas_18_23_utc,
          MIN(EXTRACT(HOUR FROM moment)) AS min_chas_utc,
          MAX(EXTRACT(HOUR FROM moment)) AS max_chas_utc
   FROM \`$PROJ.core.fact_loss\`
   UNION ALL
   SELECT 'fact_commissionreportin',
          COUNT(*),
          COUNTIF(EXTRACT(HOUR FROM moment) >= 18),
          MIN(EXTRACT(HOUR FROM moment)),
          MAX(EXTRACT(HOUR FROM moment))
   FROM \`$PROJ.core.fact_commissionreportin\`"

echo
echo "########## 2. РАСПРЕДЕЛЕНИЕ ПО ЧАСАМ (чтобы видеть, что это за время) ##########"
echo "   Рабочие часы 04:00–13:00 UTC = 10:00–19:00 по Бишкеку — признак того, что"
echo "   в базе лежит настоящее UTC. Часы 09:00–19:00 UTC — признак того, что туда"
echo "   положили местное время без пересчёта, и тогда приведение к дате безопасно."
Q "SELECT chas_utc, SUM(loss) AS fact_loss, SUM(comm) AS fact_commissionreportin
   FROM (
     SELECT EXTRACT(HOUR FROM moment) AS chas_utc, 1 AS loss, 0 AS comm FROM \`$PROJ.core.fact_loss\`
     UNION ALL
     SELECT EXTRACT(HOUR FROM moment),              0,        1        FROM \`$PROJ.core.fact_commissionreportin\`
   ) GROUP BY chas_utc ORDER BY chas_utc"

echo
echo "########## 3. ЕСЛИ РАЗЪЕЗД ЕСТЬ — НА КАКУЮ СУММУ И В КАКИХ МЕСЯЦАХ ##########"
echo "   Считаем только строки опасного часа: сколько денег сменило бы месяц."
Q "WITH x AS (
     SELECT moment, sum_kgs FROM \`$PROJ.core.fact_loss\`               WHERE EXTRACT(HOUR FROM moment) >= 18
     UNION ALL
     SELECT moment, sum_kgs FROM \`$PROJ.core.fact_commissionreportin\` WHERE EXTRACT(HOUR FROM moment) >= 18
   )
   SELECT FORMAT_DATE('%Y-%m', DATE(moment))                                    AS mesyats_po_utc,
          FORMAT_DATE('%Y-%m', DATE(moment, 'Asia/Bishkek'))                    AS mesyats_po_bishkeku,
          COUNT(*)                                                              AS strok,
          ROUND(SUM(sum_kgs),2)                                                 AS summa_kgs
   FROM x
   GROUP BY 1,2
   HAVING mesyats_po_utc <> mesyats_po_bishkeku
   ORDER BY 1"

echo
echo "########## 4. КОНТРОЛЬ: МАЙ-2026 ПРИ ДВУХ СПОСОБАХ СЧЁТА ДАТЫ ##########"
echo "   Эталон мая = 10 232 903,20. Первая цифра — как считает проверяемый запрос."
Q "WITH src AS (
     SELECT DATE(moment) AS d_utc, DATE(moment,'Asia/Bishkek') AS d_bish, sum_kgs
     FROM \`$PROJ.core.fact_loss\` WHERE applicable
       AND COALESCE(expense_item_id,'') NOT IN (
         '24c0e914-2d8c-11f1-0a80-11b0000c7043','4e1c05f2-0673-11e6-a655-0cc47a342ca4',
         '8dbf9374-0a01-11e4-b9bf-002590a32f46','8dbf99a0-0a01-11e4-a743-002590a32f46')
     UNION ALL
     SELECT DATE(moment), DATE(moment,'Asia/Bishkek'), sum_kgs
     FROM \`$PROJ.core.fact_commissionreportin\`
   )
   SELECT ROUND(SUM(IF(FORMAT_DATE('%Y-%m', d_utc)  = '2026-05', sum_kgs, 0)),2) AS novye_vetki_may_po_utc,
          ROUND(SUM(IF(FORMAT_DATE('%Y-%m', d_bish) = '2026-05', sum_kgs, 0)),2) AS novye_vetki_may_po_bishkeku
   FROM src"

echo
echo "########## ЯКОРЬ (конец) ##########"
date -u; gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "########## КОМАНД ЗАПИСИ НЕТ ##########"
