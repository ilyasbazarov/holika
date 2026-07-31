echo "--- load_payments.py (полный текст) ---"
cat "$HOME/load_payments.py" 2>&1
echo "--- msklad_project / reference / sql: содержимое ---"
find "$HOME/msklad_project" "$HOME/reference" "$HOME/sql" -maxdepth 3 -type f -printf "%TY-%Tm-%Td %s %p\n" 2>/dev/null | sort | head -60
echo "--- архивы (zip/tar/gz) в HOME ---"
find "$HOME" -maxdepth 3 -type f \( -name "*.zip" -o -name "*.tar*" -o -name "*.gz" \) -printf "%TY-%Tm-%Td %s %p\n" 2>/dev/null | sort | head -30
echo "--- .bash_history: диапазон и упоминания invoice/load/ndjson ---"
wc -l "$HOME/.bash_history" 2>/dev/null
grep -n -i -e invoice -e ndjson -e "bq load" -e load_ "$HOME/.bash_history" 2>/dev/null | head -40
echo "--- любые файлы (любой каталог) со словом invoice в ИМЕНИ ---"
find "$HOME" -iname "*invoice*" -printf "%TY-%Tm-%Td %s %p\n" 2>/dev/null | head -30
echo "--- КОНЕЦ УДАЛЁННОЙ ЧАСТИ ---"
