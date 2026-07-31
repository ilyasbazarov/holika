echo "--- whoami / pwd ---"; whoami; pwd
echo "--- ls -la HOME ---"; ls -la "$HOME"
echo "--- NDJSON/JSONL во всём HOME ---"
find "$HOME" -type f \( -iname "*.ndjson" -o -iname "*.jsonl" \) -printf "%TY-%Tm-%Td %s %p\n" 2>/dev/null | sort | tail -50
echo "--- файлы с mtime 2026-06-01..2026-06-10 ---"
find "$HOME" -type f -newermt "2026-06-01" ! -newermt "2026-06-10" -printf "%TY-%Tm-%Td %s %p\n" 2>/dev/null | sort | head -80
echo "--- grep по содержимому: invoiceout / customer_invoices / bq load ---"
grep -rIl -e invoiceout -e customer_invoices -e "bq load" "$HOME" 2>/dev/null | head -50
echo "--- все .py / .ipynb / .sh в HOME ---"
find "$HOME" -type f \( -name "*.py" -o -name "*.ipynb" -o -name "*.sh" \) -printf "%TY-%Tm-%Td %s %p\n" 2>/dev/null | sort | head -80
echo "--- .bash_history: строки с bq load / invoice ---"
grep -n -e "bq load" -e invoice "$HOME/.bash_history" 2>/dev/null | tail -40
echo "--- КОНЕЦ УДАЛЁННОЙ ЧАСТИ ---"
