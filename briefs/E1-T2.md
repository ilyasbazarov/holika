# TASK BRIEF · E1-T2 — Декомпозиция статей расходов по типам документов МойСклад (Трек B, discovery)

> Тип: **discovery/диагностический** (`_METHOD §11`). Return-this = обогащение репо (матрица источников + характеризация двух статей), **не прод-код, не правка витрины, НЕ классификационное решение** (его принимает клиент). Второй бриф Epic-1, поверх находок E1-T1.

## Роль
Ты — **разработчик**. Сначала прочитай `_METHOD` + `05_CONVENTIONS`, затем действуй.
Модель исполнения: ты ПИШЕШЬ запросы (MoySklad API + BQ), **человек ЗАПУСКАЕТ** и возвращает логи. Ты не исполняешь сам.
Это **read-only диагностика**: никаких правок `sq_marts_expenses`, `transferConfig`, таблиц, статей в МойСкладе.

## Цель
Закрыть количественно **Q-9/Q-23** и собрать **доказательную базу** под два вопроса клиента (Q-22, Q-24), не принимая решений за него:
1. **Декомпозировать** оракульные суммы 5 «понижённых» статей (E1-T1) на `paymentout` / `cashout` / `loss` → показать, какая часть занижения объясняется отсутствием `loss` в `fact_payments` (гипотеза ADR-012 §4), и есть ли **остаток** сверх loss.
2. **Характеризовать «Вывод прибыли»** (4 246 163,66) на уровне документов: контрагент + назначение → капитал или opex (evidence, НЕ вердикт).
3. **Получить cash-«Налоги и сборы»** из платежей и сверить с accrued-строкой П&Л 2 168 917,60 (Q-24).
4. Дать **dashboard-swing** (± «Вывод прибыли») для вопроса клиенту.

## Context-to-load (только `curl` по SHA от человека; нет файла → `CONTEXT GAP`, стоп)
```
https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/_METHOD.md
https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/00_CHARTER.md
https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/05_CONVENTIONS.md
https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/07_STATE.md
https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/02_ERP_CONTRACTS.md   # §семантика П&Л, §поведение API, §справочные (UUID)
https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/03_PIPELINE_SPEC.md    # §marts.expenses, §marts легаси
https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/06_DECISIONS_LOG.md    # ADR-005/006/009/010/012
https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/reference/pnl_2026-05.md
https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/reference/expense_articles_client.md
https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/RUNBOOK_v8.md          # §20 (expand+limit), §21.2 (хардчек), §25.8 (расхождение по типу документа), М-44
```

## Входы (существует, доступно)
- **MoySklad API** у человека: токен из Secret Manager, `401 → refresh` (RB §17). Все GET через Python `requests`, не `curl+Content-Type` (RB §20/415).
- **Метод — уже документирован, НЕ изобретать:**
  - `entity/paymentout` + `entity/cashout` + `entity/loss`, `expand=expenseItem,agent` (RB §21.2, `02 §семантика П&Л`).
  - **`limit ≤ 100` при `expand`** — иначе API молча роняет `expand` в `NULL` (RB §20, стр.243).
  - Конвертация: `minor_units ÷ 100 × document.rate.value` (ADR-010); если `rate` не задан — текущий курс.
  - **Governing recipe (RB §25.8):** одна статья может идти из РАЗНЫХ типов документов; П&Л агрегирует ПО СТАТЬЕ, не по типу. Прежде чем искать баг в ETL одного типа — прямым API-запросом проверить сумму по статье во ВСЕХ трёх типах. Подтверждённые случаи cross-type: «Списания», «Маркетинг и реклама», «Прочие расходы».
- **Оракул:** `/reference/pnl_2026-05.md` (KGS, ORACLE-строки).
- **Прод-факт май** уже снят в E1-T1 (приложи тот лог как baseline `paymentout+cashout`-стороны).
- **`loss` в BQ ОТСУТСТВУЕТ** (ADR-012: TO-BE не построен) → loss берётся ТОЛЬКО из MoySklad API.

## Шаги
1. **Заземлить метод.** Прочитай RB §25.8 + §21.2 + ADR-006 §семантика. Подтверди: 3 типа документов, `expenseItem`, `rate.value`, `limit≤100`. Не изобретай пагинацию — **зеркаль существующий fetch `cf-finance`** (paymentout/cashout уже тянутся так), добавь `entity/loss`.
2. **Снять май по 3 типам.** Период `moment ∈ [2026-05-01 … 2026-05-31]` (сверь границу с оракулом). Для каждого документа: `expenseItem.name`, `agent`, сумма `÷100 × rate.value` → KGS. Агрегат **по (`expenseItem.name` × тип документа)**.
```python
   # ЧЕЛОВЕК ЗАПУСКАЕТ. Read-only. Токен — из Secret Manager (RB §17).
   # Зеркалить логику cf-finance; ниже — контур, не финальный код.
   import requests, time
   BASE = "https://api.moysklad.ru/api/remap/1.2/entity"
   HEAD = {"Authorization": f"Bearer {TOKEN}", "Accept-Encoding": "gzip"}
   def pull(dtype):                      # dtype ∈ {paymentout, cashout, loss}
       rows, offset = [], 0
       while True:
           r = requests.get(f"{BASE}/{dtype}",
               params={"expand":"expenseItem,agent","limit":100,"offset":offset,
                       "filter":"moment>=2026-05-01 00:00:00;moment<=2026-05-31 23:59:59"},
               headers=HEAD, timeout=90)
           if r.status_code == 429: time.sleep(300); continue   # RB §18
           r.raise_for_status(); js = r.json(); rows += js["rows"]
           if len(js["rows"]) < 100: break
           offset += 100; time.sleep(0.25)                      # RB rate-limit
       return rows
   # для каждой row: article = (row.get("expenseItem") or {}).get("name","Не указана")
   #                 rate = ((row.get("rate") or {}).get("value")) or CURRENT_RATE
   #                 kgs  = row["sum"]/100 * rate
   #                 agent= (row.get("agent") or {}).get("name")
   # → агрегировать sum(kgs) по (article, dtype); отдельно копить (article, agent, kgs) для шага 4
```
3. **Матрица источников + Q-9/Q-23.** Таблица: `статья · paymentout_kgs · cashout_kgs · loss_kgs · oracle_kgs · (p+c) · разрыв_до_loss · разрыв_после_loss`. Для 5 статей E1-T1 (Банк-комиссия, Мой Склад, Бухгалтерские услуги, Интернет и связь + loss-питаемые «Списания» и т.д.): показать, закрывает ли `loss` разрыв. **Остаток после loss ≠ 0 → изолировать как настоящий необъяснённый** (кандидат в отдельный ADR/Q-3).
4. **«Вывод прибыли» — характеризация (Q-22 evidence, БЕЗ вердикта).** Выпиши все её документы (`paymentout`/`cashout`) с `agent` и назначением/комментарием. Пометь строки, где контрагент = собственник/учредитель или «перевод на свои счета» (паттерн RB §21.2: крупные SWIFT/переводы на свои счета, часто неразнесённые). **Классификацию НЕ выноси** — это вопрос клиенту.
5. **«Налоги и сборы» — cash (Q-24 evidence).** Есть ли `expenseItem.name = "Налоги и сборы"` на `paymentout`/`cashout` за май? Сумма → **cash-величина**. Приведи рядом с accrued **2 168 917,60** (строка П&Л ниже опер.прибыли, ВНЕ 32 opex). Явно пометь: это **разные по природе** величины; вывод — за клиентом.
6. **Dashboard-swing (Q-22 evidence).** Из прод `marts.expenses` за май: opex-тотал **с** и **без** «Вывод прибыли» (+ доля). Дай две цифры под вопрос клиенту.
7. **Граница (Q-3).** Если статья категоризирована в МойСкладе, но `fact_payments` её теряет (нужен неверсионированный код пайплайна) → `CONTEXT GAP → DEFER Q-3`, **не гадать**.

## Критерии приёмки
- `/reference/recon_expenses_sources_2026-05.md` — матрица `статья × {paymentout,cashout,loss} × oracle`, трассируемо к API-логам (приложены).
- **Q-9/Q-23 количественно закрыты:** каждая из 5 статей декомпозирована; ADR-012 §4 **CONFIRMED + оцифрован** ИЛИ остаток изолирован.
- **«Вывод прибыли»**: таблица документов (agent/назначение) — только evidence.
- **«Налоги и сборы»**: cash-сумма vs 2 168 917,60 — обе приведены, природа помечена.
- **Swing**: две цифры (± «Вывод прибыли»).
- **Ни одна прод/МойСклад-сущность не изменена** (всё — GET/SELECT).

## Return-this
- `/reference/recon_expenses_sources_2026-05.md` (+ два evidence-блока: «Вывод прибыли», «Налоги cash»).
- Точные запросы + вывод (провенанс для перезапуска).
- `SESSION`-блок: `STATE_PATCH` (Q-9/Q-23 статус, evidence для 22/24), `NEW_DECISIONS` = **нет** (ADR-013 ратифицирует архитектор ПОСЛЕ ответов клиента, не developer).

## Вне scope
- **Классификация** «Вывод прибыли»/«Налоги и сборы» — клиент.
- Любая правка `sq_marts_expenses`/витрины — под `E1-T1-MECH` (staging-first), отдельно.
- Трек A, Q-20 (DQ-порог), UUID-хардинг (канон фильтра = по имени, ADR-006).
- Постройка TO-BE raw-марта (ADR-012 §2: НЕ строится).

## В конце сессии
`SESSION`-блок по `05_CONVENTIONS` Часть III.
