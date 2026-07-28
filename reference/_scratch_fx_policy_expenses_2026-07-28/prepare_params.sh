#!/usr/bin/env bash
# ПОДГОТОВКА подмены. Ничего в облаке не меняет — только читает локальные файлы
# и собирает готовую полезную нагрузку. Печатает ГОТОВО либо СТОП.
# Запуск:  bash prepare_params.sh > run6.log 2>&1; cat run6.log
set -uo pipefail

NEWSQL_DIR="$HOME/holika_newsql_20260727T153004Z"
STEP1_DIR="$HOME/holika_step1_20260727T153556Z"

echo "########## ЯКОРЬ ##########"; date -u

python3 - "$NEWSQL_DIR" "$STEP1_DIR" <<'PY'
import json, os, re, sys
newsql_dir, step1_dir = sys.argv[1], sys.argv[2]
src_sql  = os.path.join(newsql_dir, 'new_query_from_job.sql')
cfg_json = os.path.join(step1_dir,  'live_config_before.json')

for p in (src_sql, cfg_json):
    if not os.path.exists(p):
        print(f"СТОП: нет файла {p}"); sys.exit(1)

# 1. установочный текст = исполненный запрос без обёртки CREATE OR REPLACE TABLE
sql = open(src_sql, encoding='utf-8').read()
m = re.search(r'CREATE OR REPLACE TABLE\s+`[^`]+`\s+AS\s*\n', sql)
if not m:
    print("СТОП: обёртка CREATE OR REPLACE в исходном тексте не найдена — не срезаю вслепую")
    sys.exit(1)
body = sql[m.end():].strip('\n') + '\n'

checks = {
    "обёртка CREATE удалена":            'CREATE OR REPLACE' not in body,
    "текст начинается с WITH fx AS":     body.lstrip().startswith('WITH fx AS'),
    "три ветки источников":              body.count('UNION ALL') == 2,
    "есть fact_payments":                'core.fact_payments' in body,
    "есть fact_loss":                    'core.fact_loss' in body,
    "есть fact_commissionreportin":      'core.fact_commissionreportin' in body,
    "есть фильтр 4 системных статей":    body.count('24c0e914-2d8c-11f1-0a80-11b0000c7043') == 1,
    "нет записи в expenses_staging":     'expenses_staging' not in body,
}
print("-- проверки установочного текста:")
for k, v in checks.items():
    print(f"   {'OK ' if v else 'НЕТ'}  {k}")
print(f"   байт: {len(body.encode('utf-8'))}")

# 2. параметры живой конфигурации: меняем ТОЛЬКО query, остальное сохраняем как есть
cfg = json.load(open(cfg_json, encoding='utf-8'))
params = cfg.get('params')
if not isinstance(params, dict) or not params:
    print("СТОП: params живой конфигурации не прочитаны — подмена вслепую затрёт настройки")
    sys.exit(1)

print("\n-- параметры ЖИВОЙ конфигурации (что там сейчас, кроме самого запроса):")
for k in sorted(params):
    v = params[k]
    print(f"   {k}: {'<текст запроса, ' + str(len(str(v).encode('utf-8'))) + ' байт>' if k == 'query' else repr(v)}")

new_params = dict(params)
new_params['query'] = body

lost = set(params) - set(new_params)
if lost:
    print(f"СТОП: потерялись ключи {lost}"); sys.exit(1)

out_sql    = os.path.join(newsql_dir, 'install_query.sql')
out_params = os.path.join(newsql_dir, 'params.json')
open(out_sql, 'w', encoding='utf-8').write(body)
json.dump(new_params, open(out_params, 'w', encoding='utf-8'), ensure_ascii=False)

print(f"\n-- сохранено:")
print(f"   {out_sql}")
print(f"   {out_params}  (ключей: {len(new_params)}, все прежние сохранены)")

if all(checks.values()):
    print("\nГОТОВО — можно вставлять команду подмены.")
else:
    print("\nСТОП — часть проверок не прошла, подмену не запускать.")
    sys.exit(1)
PY

echo
echo "########## ЯКОРЬ (конец) ##########"; date -u
echo "########## КОМАНД В ОБЛАКО НЕТ ##########"
