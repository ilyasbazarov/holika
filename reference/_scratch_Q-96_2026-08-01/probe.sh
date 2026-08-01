#!/usr/bin/env bash
# Q-96 · Пересчитана ли история core.fact_payments после правки, задеплоенной 2026-07-20.
# Класс A: ТОЛЬКО чтение BigQuery + запись в /reference. Живого GET к МойСкладу НЕТ —
# он был бы классом B, мандат не выдан (строка мандата `Q-96` в 07_STATE).
#
# ОТСТУПЛЕНИЕ ОТ БУКВЫ РАЗЛИЧИТЕЛЯ, названо явно:
# строка Q-96 назначает различителем «core против ЖИВОГО API». Живой API недоступен без мандата
# класса B. Взят эквивалентный внутренний различитель: эталонные значения по ДВУМ конкретным
# документам уже записаны в репо с провенансом (reference/recon_vyvod_pribyli_2026-05.md §2,
# прогон 2026-07-14, слой A = live API). Сравнение идёт против этих записанных чисел.
# Это СИЛЬНЕЕ агрегата: расхождение локализовано до двух документов и двух сумм.
set -u

P="msklad-bi-prod"
D1="8837df1b-50e5-11f1-0a80-0bfd003170f9"   # USD, эталон live API 900 000,00 · core на 07-14: 10 000,00
D2="585c8eaf-5f66-11f1-0a80-132d0026fc3b"   # RUB, эталон live API     937,50 · core на 07-14:    750,00

echo "=== ЯКОРЬ НАЧАЛА ==="
date -u
gcloud auth list 2>&1
gcloud config get-value project 2>&1

echo
echo "=== ШАГ 1. Два документа-маркера: что в core СЕЙЧАС ==="
bq query --project_id="$P" --use_legacy_sql=false --format=prettyjson \
"SELECT payment_id, payment_name, payment_type, moment, sum_kgs, _loaded_at
 FROM \`$P.core.fact_payments\`
 WHERE payment_id IN ('$D1','$D2')
 ORDER BY sum_kgs DESC" 2>&1

echo
echo "=== ШАГ 2. Агрегат мая-2026 по core.fact_payments (слой B эталона) ==="
bq query --project_id="$P" --use_legacy_sql=false --format=prettyjson \
"SELECT COUNT(*) AS docs,
        ROUND(SUM(sum_kgs),2) AS sum_kgs,
        MIN(_loaded_at) AS loaded_min,
        MAX(_loaded_at) AS loaded_max
 FROM \`$P.core.fact_payments\`
 WHERE moment BETWEEN '2026-05-01' AND '2026-05-31'
   AND payment_type = 'paymentout'" 2>&1

echo
echo "=== ШАГ 3. Тот же агрегат БЕЗ фильтра по типу (на случай иной разметки payment_type) ==="
bq query --project_id="$P" --use_legacy_sql=false --format=prettyjson \
"SELECT payment_type, COUNT(*) AS docs, ROUND(SUM(sum_kgs),2) AS sum_kgs,
        MIN(_loaded_at) AS loaded_min, MAX(_loaded_at) AS loaded_max
 FROM \`$P.core.fact_payments\`
 WHERE moment BETWEEN '2026-05-01' AND '2026-05-31'
 GROUP BY payment_type ORDER BY sum_kgs DESC" 2>&1

echo
echo "=== ШАГ 4. Когда строки мая переписывались в последний раз (распределение по суткам) ==="
bq query --project_id="$P" --use_legacy_sql=false --format=prettyjson \
"SELECT DATE(_loaded_at) AS loaded_day, COUNT(*) AS docs
 FROM \`$P.core.fact_payments\`
 WHERE moment BETWEEN '2026-05-01' AND '2026-05-31'
 GROUP BY loaded_day ORDER BY loaded_day" 2>&1

echo
echo "=== ШАГ 5. Инвесторская поверхность: тот же май в marts.expenses (слой C эталона) ==="
bq query --project_id="$P" --use_legacy_sql=false --format=prettyjson \
"SELECT COUNT(*) AS rows_cnt, ROUND(SUM(total_sum_kgs),2) AS total_sum_kgs
 FROM \`$P.marts.expenses\`
 WHERE year_month = '2026-05'" 2>&1 \
|| echo "(колонки не совпали — не факт, а гэп наблюдения; схема снимается отдельно)"

echo
echo "=== ШАГ 6. Схема marts.expenses (если Шаг 5 не сошёлся по именам колонок) ==="
bq show --project_id="$P" --schema --format=prettyjson "$P:marts.expenses" 2>&1 | head -40

echo
echo "=== ЯКОРЬ КОНЦА ==="
date -u
gcloud auth list 2>&1
