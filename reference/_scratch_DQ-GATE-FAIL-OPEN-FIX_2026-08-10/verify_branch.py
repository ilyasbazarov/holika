"""Офлайн-симуляция новой ветки check_drift (ma7==0) — без обращения к живому BigQuery.
Числа взяты дословно из reference/dq_gate_fail_open_adj_2026-08-03.md §1:
  yesterday_rev(target_rev) = 191800 (2026-08-03, staging)
  core.fact_sales_profit НЕ пуста исторически: MAX(transaction_date)=2026-08-01 (core заморожена
  с этой даты, но строки в ней ЕСТЬ) -> ever_had_data > 0 в кейсе "заморозка".
Кейс "первый запуск" использует единственную легитимную константу 0 (не выдуманная бизнес-цифра).
"""

def new_branch(target_rev, ever_had_data):
    if ever_had_data == 0:
        return True, (f"yesterday_rev={target_rev:.0f}, ma7=0, core_ever_rows=0 "
                       f"(первый запуск проекта - базы сравнения не существует, пропуск обоснован)")
    return False, (f"yesterday_rev={target_rev:.0f}, ma7=0, core_ever_rows={ever_had_data} "
                    f"(окно T-8..T-2 пусто при непустой истории core - вероятная остановка "
                    f"промоута, блокирую вместо тихого пропуска)")

# Кейс 1: заморозка ядра (адъюдикация 2026-08-03, реальные числа)
target_rev = 191800.0
ever_had_data_frozen = 1  # core.fact_sales_profit исторически непуста (MAX(transaction_date)=2026-08-01)
passed, detail = new_branch(target_rev, ever_had_data_frozen)
print("Кейс 1 (заморозка ядра, реальные числа адъюдикации):")
print(f"  passed={passed}  detail={detail}")
assert passed is False, "заморозка обязана блокировать, не пропускать"

# Кейс 2: легитимный первый запуск проекта (COUNT(*) FROM core.fact_sales_profit = 0)
ever_had_data_first_run = 0
passed2, detail2 = new_branch(target_rev, ever_had_data_first_run)
print("Кейс 2 (первый запуск проекта, ever_had_data=0):")
print(f"  passed={passed2}  detail={detail2}")
assert passed2 is True, "первый запуск обязан пропускать, а не создавать тупик"

print("OK: оба кейса различены веткой корректно")
