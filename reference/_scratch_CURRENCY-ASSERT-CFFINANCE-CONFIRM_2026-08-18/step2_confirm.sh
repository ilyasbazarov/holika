set -u
date -u
echo "== 1. объём против базы деплоя (a4422d6 = INVOICES-LOADER-BUILD, содержимое код-репо) =="
git diff --stat a4422d6 HEAD -- reference/code/cf-finance/
echo
echo "== 2. арифметика: строка расчёта суммы в диффе патча целиком =="
git diff a4422d6 HEAD -- reference/code/cf-finance/main.py | grep -nE '^[+-].*rate.*value.*1\.0|^[+-].*sum_kgs' || echo "  НИ ОДНОЙ изменённой строки с расчётом — арифметика не тронута"
echo
echo "== 3. факт-проверка ИСПОЛНЕНИЕМ (скрипт ревью, без изменений) =="
python3 reference/_scratch_CURRENCY-ASSERT-CFFINANCE-REVIEW_2026-08-18/import_check.py reference/code/cf-finance/main.py
echo "rc_import=$?"
echo
echo "== 4. sha256 трёх файлов снапшота =="
shasum -a 256 reference/code/cf-finance/main.py reference/code/cf-finance/invoices.py reference/code/cf-finance/requirements.txt
echo
echo "== 5. существующий запрос run_etl (main.py:66 базы) НЕ ретрофитнут — ожидание: без timeout =="
grep -n "requests.get" reference/code/cf-finance/main.py
date -u
