"""
Три проверки чек-листа §13 п.4/7/8, все против ТЕСТОВОЙ копии core-схемы
(`stg_msklad.fact_customer_invoices_core_test_staging`), НЕ живой `core.fact_customer_invoices`.

Почему тестовая копия, а не живая core-таблица: мандат этой строки (`07_STATE.md:432`)
разрешает запись только в `reference/code/` и `*_staging`; текст брифа отдельно
запрещает запись в живые прод-таблицы `core.*` в этой сессии. Чек-лист §13 п.7/8
(идемпотентность, ветка удаления) требует реально исполнить MERGE и увидеть эффект —
единственный способ сделать это, не нарушив ни то, ни другое ограничение: прогнать
СОБСТВЕННЫЙ, дословно тот же текст MERGE (`invoices.build_merge_sql`) против
непрод-таблицы с идентичной схемой (14 колонок core.fact_customer_invoices, сверено
`bq show` в сессии) и именем, оканчивающимся на `_staging` (буквально попадает под
разрешённый мандатом `*_staging`, хотя семантически это тестовая цель MERGE, не
источник). SQL-текст, который проверяется, — ТОТ ЖЕ, что пойдёт в живой код (T4).
"""
import sys

sys.path.insert(0, "reference/code/cf-finance")
sys.path.insert(0, "reference/_scratch_INVOICES-LOADER-BUILD_2026-08-02/checks")
import invoices as inv
from bq_client import get_client

TEST_CORE = "msklad-bi-prod.stg_msklad.fact_customer_invoices_core_test_staging"

bq = get_client()

# ── Очистка тестовой core-копии перед прогоном (идемпотентная подготовка, не MERGE) ──
bq.query(f"TRUNCATE TABLE `{TEST_CORE}`").result()
print("test_core_truncated=1")

# Staging уже несёт 3 синтетические строки от currency_test.py (synt-kgs-1,
# synt-usd-withrate, synt-usd-fallback). Прогон 1: первый MERGE — все три должны
# вставиться (ADR-100 §1: T.moment обновляется; здесь для INSERT это неважно).

stats1 = inv.merge_predicted_stats(bq, core_table=TEST_CORE, staging_table=inv.STG_INVOICES)
bq.query(inv.build_merge_sql(core_table=TEST_CORE, staging_table=inv.STG_INVOICES)).result()
print(f"run1_predicted={stats1}")
assert stats1 == {"merged_inserted": 3, "merged_updated": 0, "merged_deleted": 0}, stats1

n_after_run1 = list(bq.query(f"SELECT COUNT(*) AS n FROM `{TEST_CORE}`").result())[0].n
sum_after_run1 = list(bq.query(f"SELECT ROUND(SUM(sum_kgs),2) AS s FROM `{TEST_CORE}`").result())[0].s
print(f"n_rows_after_run1={n_after_run1} sum_sum_kgs_after_run1={sum_after_run1}")
assert n_after_run1 == 3, n_after_run1

# ── п.4 чек-листа §13 — правило суток: moment=2026-05-12 22:15:00.000 UTC (полоса
# [18:00;24:00)) обязано лечь на СЛЕДУЮЩИЕ бишкекские сутки относительно UTC-даты. ──
row = list(bq.query(
    f"SELECT moment FROM `{TEST_CORE}` WHERE invoice_id = 'synt-usd-fallback'"
).result())[0]
print(f"moment_rule_test: utc_date=2026-05-12 utc_time=22:15 -> core.moment={row.moment}")
assert str(row.moment) == "2026-05-13", f"ожидалось 2026-05-13 (DATE(M+6ч)), получено {row.moment}"

# ── п.7 чек-листа §13 — идемпотентность: второй прогон MERGE на ТОМ ЖЕ staging
# не меняет числа строк/сумм, merged_inserted=0, merged_deleted=0. ──
stats2 = inv.merge_predicted_stats(bq, core_table=TEST_CORE, staging_table=inv.STG_INVOICES)
bq.query(inv.build_merge_sql(core_table=TEST_CORE, staging_table=inv.STG_INVOICES)).result()
print(f"run2_predicted={stats2}")
assert stats2["merged_inserted"] == 0, stats2
assert stats2["merged_deleted"] == 0, stats2
assert stats2["merged_updated"] == 3, stats2  # все три матчатся повторно (WHEN MATCHED)

n_after_run2 = list(bq.query(f"SELECT COUNT(*) AS n FROM `{TEST_CORE}`").result())[0].n
sum_after_run2 = list(bq.query(f"SELECT ROUND(SUM(sum_kgs),2) AS s FROM `{TEST_CORE}`").result())[0].s
print(f"n_rows_after_run2={n_after_run2} sum_sum_kgs_after_run2={sum_after_run2}")
assert n_after_run2 == n_after_run1, (n_after_run2, n_after_run1)
assert sum_after_run2 == sum_after_run1, (sum_after_run2, sum_after_run1)

# ── п.8 чек-листа §13 — ветка удаления: удалить ОДНУ строку из staging вручную,
# повторный MERGE обязан убрать РОВНО её, merged_deleted=1. ──
bq.query(
    f"DELETE FROM `{inv.STG_INVOICES}` WHERE invoice_id = 'synt-usd-withrate'"
).result()
print("staging_row_manually_deleted=synt-usd-withrate")

stats3 = inv.merge_predicted_stats(bq, core_table=TEST_CORE, staging_table=inv.STG_INVOICES)
bq.query(inv.build_merge_sql(core_table=TEST_CORE, staging_table=inv.STG_INVOICES)).result()
print(f"run3_predicted={stats3}")
assert stats3 == {"merged_inserted": 0, "merged_updated": 2, "merged_deleted": 1}, stats3

n_after_run3 = list(bq.query(f"SELECT COUNT(*) AS n FROM `{TEST_CORE}`").result())[0].n
remaining_ids = sorted(r.invoice_id for r in bq.query(f"SELECT invoice_id FROM `{TEST_CORE}`").result())
print(f"n_rows_after_run3={n_after_run3} remaining_ids={remaining_ids}")
assert n_after_run3 == 2, n_after_run3
assert remaining_ids == ["synt-kgs-1", "synt-usd-fallback"], remaining_ids

print(
    "VERDICT: run1_inserted=3 run2_inserted=0 run2_deleted=0 "
    f"run2_rows_unchanged={n_after_run2 == n_after_run1} run2_sums_unchanged={sum_after_run2 == sum_after_run1} "
    f"run3_deleted=1 run3_remaining_rows={n_after_run3} moment_rule_ok={str(row.moment) == '2026-05-13'}"
)
