# TASK BRIEF · FX-OUTBOUND-COVERAGE

*(discovery-бриф, `08_TASK_BRIEF_TEMPLATE §Вариант: discovery-бриф`; заведён `ADR-039 §4/§5`, бриф сгенерирован сессией `E1-T1-MECH-PREP-ADJ-2`, 2026-07-26)*

## Роль
Ты — разработчик проекта. Сначала прочитай `_METHOD` + `05_CONVENTIONS` (правила агента), затем действуй.
Модель исполнения: ты ПИШЕШЬ скрипты/запросы с ожидаемым выводом и командой запуска, человек ЗАПУСКАЕТ и
возвращает логи. Ты не исполняешь сам. Задача **read-only**, ничего не гейтит, идёт параллельно `E1-T1-MECH`.

## Цель
Снять два факта, объявленных `ADR-039 §4/§5` **предусловием** решения владельца по `ADR-039 §2`
(политика исходящей FX-конвертации): **(1)** покрытие `core.dim_fx_rates` по датам — есть ли курсы за
май-2026 и ранее, и нет ли дыр внутри покрытого окна; **(2)** какие из 13 SQ флота используют паттерн
`latest_fx` (`ORDER BY date DESC LIMIT 1` по `core.dim_fx_rates`).

## Context-to-load (обязательно прочитать перед работой; SHA `1d572461806f356a52848e90bc5eea6ac8540617`)
- `https://raw.githubusercontent.com/ilyasbazarov/holika/1d572461806f356a52848e90bc5eea6ac8540617/_METHOD.md`
- `https://raw.githubusercontent.com/ilyasbazarov/holika/1d572461806f356a52848e90bc5eea6ac8540617/00_CHARTER.md`
- `https://raw.githubusercontent.com/ilyasbazarov/holika/1d572461806f356a52848e90bc5eea6ac8540617/05_CONVENTIONS.md`
- `https://raw.githubusercontent.com/ilyasbazarov/holika/1d572461806f356a52848e90bc5eea6ac8540617/07_STATE.md`
- `https://raw.githubusercontent.com/ilyasbazarov/holika/1d572461806f356a52848e90bc5eea6ac8540617/02_ERP_CONTRACTS.md` (§`core.dim_fx_rates`, стр.125–134)
- `https://raw.githubusercontent.com/ilyasbazarov/holika/1d572461806f356a52848e90bc5eea6ac8540617/06_DECISIONS_LOG.md` (`ADR-039`, `ADR-010`, `ADR-028 §4`, `ADR-014`, `ADR-043`, `ADR-044`)
- `https://raw.githubusercontent.com/ilyasbazarov/holika/1d572461806f356a52848e90bc5eea6ac8540617/11_INFRA_FACTS.md` (§SQ — Config ID)
- `https://raw.githubusercontent.com/ilyasbazarov/holika/1d572461806f356a52848e90bc5eea6ac8540617/reference/sql/README.md`

Если чего-то из списка нет в контексте → выдай `CONTEXT GAP` и остановись.

## Входы (факты, уже установленные; не переспрашивать)
- `core.dim_fx_rates` — две колонки: `date DATE`, `rate_kgs_per_usd FLOAT64` (KGS за 1 USD, официальный курс НБКР). Источник **с 2026-06-03**: Bakai Bank OpenBanking API → `officialRates[currencySymbol=USD].rate` (`02` стр.125–134). Покрытие ранее этой даты **не замерено ни одной сессией**.
- Живой паттерн-образец (`/reference/sql/sq_marts_expenses.sql` стр.19–26): `total_sum_usd = ROUND(SUM(p.sum_kgs) / fx.rate_kgs_per_usd, 2)`, где `fx` — CROSS JOIN одной строки `SELECT rate_kgs_per_usd FROM core.dim_fx_rates ORDER BY date DESC LIMIT 1`.
- Тот же паттерн задокументирован как **канонический** для `marts.in_transit` (`03 §marts`, стр.126–134) — то есть он ожидаемо встретится минимум дважды.
- Флот = **13 файлов** в `/reference/sql/`: `sq_audit_dim_counterparties_snapshot`, `sq_audit_dim_employees_snapshot`, `sq_audit_dim_products_snapshot`, `sq_marts_abc_xyz`, `sq_marts_customer_invoices_ar`, `sq_marts_expenses`, `sq_marts_gmroi`, `sq_marts_gmroi_by_folder`, `sq_marts_in_transit`, `sq_marts_inventory_health`, `sq_marts_sales_overview`, `sq_marts_supplier_price_history`, `sq_marts_weight_flow`.

## Шаги

**Шаг 1 — границы и плотность покрытия.**
```sql
SELECT
  MIN(date) AS min_date,
  MAX(date) AS max_date,
  COUNT(*) AS rows_total,
  COUNT(DISTINCT date) AS distinct_dates,
  DATE_DIFF(MAX(date), MIN(date), DAY) + 1 AS span_days
FROM `msklad-bi-prod.core.dim_fx_rates`
```
Если `rows_total = 0` или запрос вернул пусто — это **гэп наблюдения, а не факт «таблица пуста»**
(`05 Часть I ★ Успех инструмента ≠ факт`, `ADR-021 §2`). Не докладывать «курсов нет»; перепроверить
независимо (`bq show --schema` + `SELECT COUNT(*)` отдельным запросом) и только тогда трактовать.

**Шаг 2 — разбивка по месяцам (прямой ответ на «есть ли май-2026»).**
```sql
SELECT
  FORMAT_DATE('%Y-%m', date) AS ym,
  COUNT(*) AS rows_cnt,
  COUNT(DISTINCT date) AS days_cnt,
  MIN(date) AS first_day,
  MAX(date) AS last_day
FROM `msklad-bi-prod.core.dim_fx_rates`
GROUP BY 1
ORDER BY 1
```

**Шаг 3 — дыры внутри покрытого окна.**
Это не педантизм: вариант (b) `ADR-039 §2` («курс на дату периода») требует курс на **каждую нужную
дату**, а не просто наличие месяца в таблице. Месяц с 3 днями из 31 для (b) так же неисполним, как
отсутствующий.
```sql
WITH bounds AS (
  SELECT MIN(date) AS d0, MAX(date) AS d1 FROM `msklad-bi-prod.core.dim_fx_rates`
),
cal AS (
  SELECT d FROM bounds, UNNEST(GENERATE_DATE_ARRAY(bounds.d0, bounds.d1)) AS d
)
SELECT cal.d AS missing_date
FROM cal
LEFT JOIN `msklad-bi-prod.core.dim_fx_rates` r ON r.date = cal.d
WHERE r.date IS NULL
ORDER BY 1
```
Вернуть **полный список** пропущенных дат (или явное «пропусков нет»), не только их количество.

**Шаг 4 — скан 13 SQL на паттерн `latest_fx`.**
Требование `ADR-044 §2`: вердикт обязан печатать **совпавшие строки с номерами**, не метку
`PASS`/`FAIL`. Требование `ADR-044 §3`: конструкция **многострочная** — в живом
`sq_marts_expenses.sql` `ORDER BY date DESC` и `LIMIT 1` стоят на разных строках, поиск по одной
строке даст ложное «нет».
```bash
cd <клон holika>/reference/sql
for f in *.sql; do
  echo "=== $f ==="
  grep -n -i -E 'dim_fx_rates|rate_kgs_per_usd|ORDER[[:space:]]+BY[[:space:]]+date[[:space:]]+DESC|LIMIT[[:space:]]+1' "$f"
done
```
Затем: для **каждого** файла, где нашёлся `dim_fx_rates`, привести блок целиком с запасом ±5 строк.
Вердикт «использует / не использует `latest_fx`» выносится по **прочитанному блоку**, не по совпадению
токена: `dim_fx_rates` может читаться и с фильтром по дате, и это ровно та разница, которую замер ищет.

**Шаг 5 — собрать артефакт** `/reference/fx_outbound_coverage_2026-07-26.md` (дата — локальная, `ADR-046 §1`;
все временны́е факты внутри — UTC с суффиксом `Z`, `ADR-046 §3`). Структура:
§1 покрытие (шаги 1–3, числа и полный список пропусков) · §2 таблица 13 SQ: файл → да/нет `latest_fx` →
процитированные строки с номерами · §3 прямой ответ по май-2026: есть ли хоть одна майская дата и
покрыты ли все даты мая · §4 команды и сырой вывод.

**Дисциплина доставки:** один copy-paste-ready блок, запуск с редиректом в файл
(`bash script.sh > run.log 2>&1; cat run.log`) — `ADR-014`. Временные директории **не удалять**, путь
печатать **последней строкой** вывода — `ADR-043`.

## Критерии приёмки (Acceptance)
- Покрытие снято числом: `min_date`, `max_date`, `distinct_dates`, `span_days` + **полный** список пропущенных дат внутри окна (или явное «пропусков нет»).
- По каждому из **13** файлов дан вердикт `latest_fx` да/нет, и для каждого «да» приведены строки с номерами.
- По май-2026 дан **однозначный** ответ на два разных вопроса: (i) есть ли в `dim_fx_rates` хотя бы одна дата мая-2026; (ii) покрыты ли **все** даты мая-2026.
- Ни один вывод не опирается на метку без выдержки (`ADR-044 §2`) и ни один пустой результат не трактован как факт (`ADR-021 §2`).

## Что вернуть человеку (Return-this)
- Файл `/reference/fx_outbound_coverage_2026-07-26.md` (коммитит человек).
- Session-блок по `05` Часть III. В `STATE_PATCH`: `FX-OUTBOUND-COVERAGE` READY → DONE; `Q-56` получает строку «предусловие `ADR-039 §4/§5` снято фактом ⇒ решение владельца по `ADR-039 §2` разблокировано»; при обнаружении SQ с `latest_fx` сверх `expenses`/`in_transit` — перечислить их в `Q-56` (это blast radius варианта (b), `ADR-039 §5`).
- ADR **не** предлагать: политику выбирает владелец (`ADR-039 §2`).

## Вне scope этой задачи
- **НЕ выбирать** политику (a)/(b)/(c) и не рекомендовать её — owner-gated (`ADR-039 §2`).
- **НЕ править** ни один SQL: ни `sq_marts_expenses`, ни `sq_marts_in_transit`, ни прочие. Задача read-only.
- **НЕ трогать** дельту `E1-T1-MECH` — формула `total_sum_usd` сохраняется как есть (`ADR-039 §1`).
- **НЕ добывать** исторические курсы из внешних источников (НБКР, Bakai, CBR). Это отдельная задача, которая возникает **только** если владелец выберет (b) и покрытия не хватит.
- **НЕ измерять** магнитуду искажения USD-величин по месяцам — это `Q-30`, DEFER, owner-gated.

## В конце сессии
Выдай SESSION-блок по формату `05_CONVENTIONS` Часть III
(`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`).
