#!/usr/bin/env python3
"""
Безопасный патч main.py (cf-finance): оборачивает вызов trigger_marts() в try/except,
чтобы сбой форс-триггера sq_marts_expenses (PermissionDenied) не убивал успешный
ответ функции после уже завершённого MERGE.

Запуск (находясь в /home/ilyasbazarov4/cf-finance, рядом с main.py):
    python3 patch_main_finance.py

Делает бэкап main.py.bak перед изменением. Если паттерн не найден ровно один раз —
ничего не трогает и печатает текст для ручной правки.
"""
import shutil
import sys

TARGET_FILE = "main.py"
BACKUP_FILE = "main.py.bak"

OLD = "    trigger_marts()"
NEW = (
    "    try:\n"
    "        trigger_marts()\n"
    "    except Exception as e:\n"
    "        print(f\"WARNING: trigger_marts() failed (non-fatal, marts have their own schedule): {e}\")"
)

def main():
    try:
        with open(TARGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()
    except FileNotFoundError:
        sys.exit(f"ERROR: {TARGET_FILE} не найден в текущей директории ({TARGET_FILE} должен лежать рядом со скриптом).")

    count = content.count(OLD)
    if count == 0:
        sys.exit(
            f"ERROR: точная строка не найдена:\n  {OLD!r}\n"
            "Возможно отступ другой (таб vs пробелы) — открой main.py и поправь руками, "
            "обернув вызов trigger_marts() в try/except, текст блока ниже:\n\n" + NEW
        )
    if count > 1:
        sys.exit(
            f"ERROR: строка {OLD!r} встречается {count} раз(а) — не патчу автоматически, "
            "чтобы не задеть лишнее. Покажи main.py, поправим вручную."
        )

    shutil.copy(TARGET_FILE, BACKUP_FILE)
    print(f"Бэкап сохранён: {BACKUP_FILE}")

    new_content = content.replace(OLD, NEW, 1)
    with open(TARGET_FILE, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"OK: {TARGET_FILE} обновлён.")
    print("\n--- Контекст изменения (для проверки глазами) ---")
    idx = new_content.find(NEW)
    start = max(0, idx - 80)
    end = min(len(new_content), idx + len(NEW) + 80)
    print(new_content[start:end])

if __name__ == "__main__":
    main()
