with open("helpers.py", "r", encoding="utf-8") as f:
    code = f.read()

if "timeout=30" in code:
    code = code.replace("timeout=30", "timeout=90")
    with open("helpers.py", "w", encoding="utf-8") as f:
        f.write(code)
    print("✅ helpers.py успешно пропатчен: timeout увеличен с 30 до 90 секунд")
else:
    print("⚠️ timeout=30 не найден. Проверьте helpers.py вручную.")
