with open("main.py", "r", encoding="utf-8") as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if line.startswith("def check_drift(bq):"):
        start_idx = i
    elif start_idx != -1 and line.startswith("def "):
        end_idx = i
        break

new_func = """def check_drift(bq):
    # BQ DAYOFWEEK: 1=Sunday, 7=Saturday
    # Изменено на T-1 (вчерашний день) для исключения ложных внутридневных срабатываний
    row = run_row(bq, f\"\"\"
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
    \"\"\")
    
    if not row or row.get("target_date") is None:
        return False, "target_date=NULL"
        
    target_rev  = float(row.get("target_rev", 0) or 0)
    day_of_week = int(row.get("day_of_week", 2) or 2)
    target_date = row.get("target_date", "")
    is_weekend  = day_of_week in (1, 7)
    threshold   = DQ_DRIFT_WEEKEND_THRESHOLD if is_weekend else DQ_DRIFT_THRESHOLD
    day_label   = "weekend" if is_weekend else "weekday"
    
    # ma7 считаем за 7 полных дней ДО вчерашнего (T-8 до T-2)
    ma7 = run_scalar(bq, f\"\"\"
        SELECT COALESCE(AVG(daily_rev),0) FROM (
            SELECT transaction_date, SUM(revenue_kgs) AS daily_rev
            FROM `{CORE_FACT}`
            WHERE transaction_date >= DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 8 DAY)
              AND transaction_date  <  DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 1 DAY)
            GROUP BY 1)
    \"\"\") or 0.0
    
    if ma7 == 0:
        return True, f"yesterday_rev={target_rev:.0f}, ma7=0 (нет истории → пропуск)"
        
    ratio = target_rev / float(ma7)
    return (ratio >= threshold,
            f"yesterday_rev={target_rev:.0f}, ma7={float(ma7):.0f}, ratio={ratio:.2f}, "
            f"threshold={threshold} ({day_label}), target_date={target_date}")

"""

if start_idx != -1 and end_idx != -1:
    lines = lines[:start_idx] + [new_func] + lines[end_idx:]
    with open("main.py", "w", encoding="utf-8") as f:
        f.writelines(lines)
    print("✅ main.py успешно пропатчен (T-1 drift_check)")
else:
    print("❌ Ошибка: функция check_drift не найдена")
