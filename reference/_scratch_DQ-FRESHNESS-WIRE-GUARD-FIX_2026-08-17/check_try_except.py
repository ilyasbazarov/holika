import ast, sys

FUNCS = [
    "check_freshness_purchases_technical", "check_freshness_purchases_business",
    "check_freshness_returns_technical", "check_freshness_returns_business",
    "check_freshness_inventory_technical", "check_freshness_inventory_business",
    "check_freshness_payments_technical", "check_freshness_payments_business",
    "check_freshness_commissionreportin_technical", "check_freshness_commissionreportin_business",
    "check_freshness_invoices_technical", "check_freshness_invoices_business",
]

src = open("reference/code/cf-dq/main.py", encoding="utf-8").read()
tree = ast.parse(src)

def has_try_except(fn_node):
    for node in ast.walk(fn_node):
        if isinstance(node, ast.Try) and node.handlers:
            for h in node.handlers:
                if h.type is None:
                    continue
                if isinstance(h.type, ast.Name) and h.type.id == "Exception":
                    return True
    return False

defs = {n.name: n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)}

rows = []
for name in FUNCS:
    node = defs.get(name)
    if node is None:
        rows.append((name, "MISSING", "MISSING", "?"))
        continue
    ok = has_try_except(node)
    rows.append((name, "ДА" if ok else "НЕТ", "ДА" if ok else "НЕТ", "нет" if ok else "ДА"))

print("| Функция | `try` | `except Exception` | Может ли заблокировать конвейер |")
print("|---|---|---|---|")
for name, t, e, block in rows:
    print(f"| `{name}` | {t} | {e} | {block} |")

any_blocking = any(r[3] == "ДА" for r in rows)
print()
print("ИТОГ:", "все двенадцать защищены, блокирующих нет" if not any_blocking else "ОСТАЛИСЬ незащищённые функции")
sys.exit(0 if not any_blocking else 1)
