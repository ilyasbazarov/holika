"""
Машинная проверка текста MERGE (design §7.5.1, ADR-044: числа, не метки).
Комментарии SQL (строки, начинающиеся с '--' после strip) отбрасываются ДО поиска —
иначе цитаты запрета/пояснений в комментариях дают ложное совпадение (тот же класс
ловушки, что design §7.5.1 уже описал для строки 'INSERT ROW').
"""
import re
import sys

sys.path.insert(0, "reference/code/cf-finance")
import invoices as inv

sql_raw = inv.build_merge_sql()

lines = sql_raw.split("\n")
exec_lines = [l for l in lines if l.strip() and not l.strip().startswith("--")]
exec_sql = "\n".join(exec_lines)

# V1 — запрет INSERT ROW (C1 / ADR-030)
insert_row_hits = len(re.findall(r"INSERT\s+ROW", exec_sql, re.IGNORECASE))
print(f"V1. строк исполнимого SQL с 'INSERT ROW': {insert_row_hits}")

# V2 — пересчёт колонок
update_set_block = re.search(r"WHEN MATCHED THEN UPDATE SET(.*?)WHEN NOT MATCHED", exec_sql, re.S).group(1)
update_assignments = [a for a in update_set_block.split(",") if a.strip()]
n_update = len(update_assignments)

insert_block = re.search(r"INSERT\s*\((.*?)\)\s*VALUES", exec_sql, re.S).group(1)
insert_cols = [c.strip() for c in insert_block.split(",") if c.strip()]
n_insert = len(insert_cols)

values_block = re.search(r"VALUES\s*\((.*)\)", exec_sql, re.S)
values_items = [v.strip() for v in values_block.group(1).split(",") if v.strip()]
n_values = len(values_items)

print("V2. Пересчёт колонок")
print(f"    UPDATE SET присваиваний: {n_update}")
print(f"    INSERT имён колонок:     {n_insert}")
print(f"    VALUES значений:         {n_values}")

# INSERT[i] <-> VALUES[i] — сверка по суффиксу имени (S.col == col)
insert_values_match = all(
    values_items[i].strip() == f"S.{insert_cols[i].strip()}" for i in range(n_insert)
) if n_insert == n_values else False
print(f"    INSERT[i] <-> VALUES[i]: {'полное соответствие' if insert_values_match else 'РАСХОЖДЕНИЕ'}")

# все UPDATE T.X = S.X
update_pairs_ok = True
for a in update_assignments:
    m = re.match(r"\s*T\.(\w+)\s*=\s*S\.(\w+)\s*$", a.strip())
    if not m or m.group(1) != m.group(2):
        update_pairs_ok = False
print(f"    во всех UPDATE T.X = S.X: {'да' if update_pairs_ok else 'НЕТ'}")

LIVE_CORE_14 = [
    "invoice_id", "invoice_name", "moment", "agent_id", "agent_name", "state_id", "state_name",
    "sum_kgs", "payed_sum_kgs", "unpaid_sum_kgs", "payment_planned", "sales_channel_id",
    "sales_channel_name", "_loaded_at",
]
insert_set_match = set(insert_cols) == set(LIVE_CORE_14)
print(f"    живая схема core (14) == INSERT-набор: {'ДА' if insert_set_match else 'НЕТ'}")

update_cols = set(re.match(r"\s*T\.(\w+)", a.strip()).group(1) for a in update_assignments)
expected_update_set = set(LIVE_CORE_14) - {"invoice_id"}
update_set_match = update_cols == expected_update_set
print(f"    UPDATE-набор == схема минус ключ invoice_id: {'ДА' if update_set_match else 'НЕТ'}")

t_moment_present = "moment" in update_cols
print(f"    T.moment (дефект ADR-100 §2) в UPDATE SET: {'ДА' if t_moment_present else 'НЕТ'}")

delete_branch_present = bool(re.search(r"WHEN NOT MATCHED BY SOURCE THEN DELETE", exec_sql))
print(f"    ветка удаления (C2 / ADR-100 §1): {'ДА' if delete_branch_present else 'НЕТ'}")

on_clause = re.search(r"\)\s*S\s*\nON\s+(.*?)\n", sql_raw, re.S).group(1)
window_in_on = bool(re.search(r"DATE_SUB|CURRENT_DATE|window", on_clause, re.IGNORECASE))
print(f"    окно/DATE_SUB в ON (ловушка ADR-100 §7 ii): {'НЕТ — верно' if not window_in_on else 'ДА — ДЕФЕКТ'}")

slice_defect = bool(re.search(r"moment_raw\[:?10\]|moment_str\[:?10\]", exec_sql))
print(f"    срез moment_raw[:10] в ИСПОЛНИМОМ SQL (дефект ADR-088 §4): {'НЕТ — верно' if not slice_defect else 'ДА — ДЕФЕКТ'}")

bishkek_hits = len(re.findall(r"Asia/Bishkek", exec_sql))
print(f"    вхождений зоны 'Asia/Bishkek' в исполнимом SQL: {bishkek_hits}")

# Общее число вхождений строки INSERT ROW во всём файле (включая комментарии) — для
# явного различения "цитата в комментарии" vs "конструкция в исполнимом коде" (§7.5.1).
total_hits_whole_text = len(re.findall(r"INSERT\s+ROW", sql_raw, re.IGNORECASE))
print(f"\nВсего вхождений 'INSERT ROW' во всём тексте SQL (включая комментарии): {total_hits_whole_text}")
print(f"Из них в исполнимом коде (после отбрасывания строк-комментариев): {insert_row_hits}")

ok = (
    insert_row_hits == 0
    and n_update == 13
    and n_insert == 14
    and n_values == 14
    and insert_values_match
    and update_pairs_ok
    and insert_set_match
    and update_set_match
    and t_moment_present
    and delete_branch_present
    and not window_in_on
    and not slice_defect
    and bishkek_hits == 2
)
print(f"\nСВОДНЫЙ ВЕРДИКТ (все числа выше, не метка): {'ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ' if ok else 'ЕСТЬ РАСХОЖДЕНИЕ — см. числа выше'}")
sys.exit(0 if ok else 1)
