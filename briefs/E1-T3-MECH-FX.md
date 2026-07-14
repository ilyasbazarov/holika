# TASK BRIEF · E1-T3-MECH-FX

> Тип: **фикс-форвард прод-кода** (не discovery). Решения адъюдицированы (ADR-010/016/017 — accepted);
> остаток — исполнение поверх принятого + один эмпирический факт-чек (RQ-2) и один read-only структурный
> гейт (Q-19). Модель: разработчик (средняя). Гейты RQ-2/Q-19 расписаны с явными STOP-условиями.
> SHA контекста (пиннить при перечитывании): `095bf6e361a5c2a2e76b8226586a73a0952e6c1f`.

## Роль
Ты — разработчик проекта. Сначала прочитай `_METHOD` + `05_CONVENTIONS` (правила агента), затем действуй.
Модель исполнения (железно): ты ПИШЕШЬ код/скрипты с ожидаемым выводом и командой запуска, человек ЗАПУСКАЕТ
и возвращает логи. Ты не исполняешь сам. Задача не выполнена без подтверждённого человеком лога реального
интегрированного прогона.

## Цель
Привести `cf-finance` в соответствие с уже принятым каноном конвертации **ADR-010** (`minor_units ÷ 100 ×
rate.value` документа; если `rate.value` не задан — текущий курс/база): при загрузке в `core.fact_payments`
умножать не-KGS суммы `paymentout`/`cashout` на курс документа, а не только делить на 100. Результат: re-diff
прод `core.fact_payments` против **живого API МойСклад** по не-KGS документам мая-2026 = **0,00 без остатка**;
KGS-документы не меняются. Правка — **staging-first** (требование ADR-016 §4), с контролируемым cutover'ом.

## Context-to-load (обязательно прочитать перед работой; литеральные raw-URL по SHA)
Всегда:
- `_METHOD` — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/_METHOD.md
- `00_CHARTER` — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/00_CHARTER.md
- `05_CONVENTIONS` — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/05_CONVENTIONS.md
- `07_STATE` — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/07_STATE.md

Решения (обязательно — это и есть спека фикса):
- `06_DECISIONS_LOG` — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/06_DECISIONS_LOG.md
  — читать: **ADR-010** (канон конвертации, скоуп глобальный: `sum` в `paymentout`/`cashout`), **ADR-016**
  (§3 директива enforcement по paymentout+cashout, §4 staging-first, §6 границы доказанного/отложенного),
  **ADR-017** (§2 снапшот новой ревизии из zip/disk, §3 де-гейт + реальный гейт = байт-точный `main.py`),
  **ADR-014** (стандарт доставки скриптов), **ADR-002** (закон-следствие: фикс-форвард в нужный слой),
  ADR-012 §4 (loss/commission — ортогональный дефект того же марта, **вне scope этой задачи**).

Доменные секции:
- `03_PIPELINE_SPEC §cf-finance` (порядок `run_etl`, поведение) + `§конвертация валют (доменная логика)` + `§fact_payments (Ghost Records)`
  — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/03_PIPELINE_SPEC.md
- `02_ERP_CONTRACTS §валюты (мультивалютность)` + `§поведение МойСклад API` + `§оракул`
  — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/02_ERP_CONTRACTS.md
- `09_GLOSSARY §конвертация валют — входящая/исходящая`
  — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/09_GLOSSARY.md

Инфра/секреты:
- `11_INFRA_FACTS §CF` (деплой-конфиг cf-finance, ревизия `00006-piv`) + `§секреты` (`msklad-token`)
  — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/11_INFRA_FACTS.md

Эталон/находки:
- Локус конвертера — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/reference/cf_finance_converter_findings_2026-07-14.md
- Снапшот кода (disk==deployed) — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/reference/code/cf-finance/main.py
  и MANIFEST — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/reference/code/cf-finance/MANIFEST.md
- Оракул расхождения (38/38 не-KGS занижены) — https://raw.githubusercontent.com/ilyasbazarov/holika/095bf6e361a5c2a2e76b8226586a73a0952e6c1f/reference/recon_vyvod_pribyli_2026-05.md

Если чего-то из списка нет в контексте → выдай `CONTEXT GAP` и остановись.

## Входы (существуют и доступны)
- **cf-finance**, ревизия `cf-finance-00006-piv`; источники на диске Cloud Shell `/home/ilyasbazarov4/cf-finance`;
  деплой (11 §CF): `--gen2 --runtime=python312 --region=asia-east1 --source=. --entry-point=main
  --trigger-http --allow-unauthenticated --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com
  --memory=512MB --timeout=1800s --set-secrets="MSKLAD_TOKEN=msklad-token:latest"`.
- **Локус конвертера** (findings §1): `main.py::run_etl()`, единственная строка расчёта суммы —
  `"sum_kgs": float((row.get("sum") or 0) / 100.0)`. Запрос: `.../entity/{paymentout|cashout}?expand=expenseItem,agent,project,salesChannel&limit=100` — **`rate` в `expand` НЕТ**.
  Конвертер локален (не shared-модуль): blast radius ограничен `core.fact_payments` и тем, что его читает.
- **Оракул сверки** — прямой запрос к `api.moysklad.ru` (00_CHARTER §главный принцип: источник истины
  реконсиляции = ТОЛЬКО live API, никогда собственные BQ-таблицы). Секрет токена — `msklad-token`.
- **Живой деструктивный джоб**: Cloud Scheduler `finance-daily-update`, `0 3 * * *`, `Asia/Bishkek`, HTTP POST
  на URI cf-finance; `maxRetryDuration=0s` (ретраев нет). Прогон делает `WRITE_TRUNCATE` STG + `MERGE` в
  `core.fact_payments` + `DELETE` ghost-статей → правка требует паузы/контроля cutover.
- Эталон занижения (recon §8): 38/38 подлежащих загрузке не-KGS документов мая занижены; Σ 1 108 075,75 KGS;
  KGS-документы (23/25 в выборке ВП) совпали → фикс `×rate.value` для базовой валюты даёт `×1`, регресса нет.

## Шаги
1. **Старт-ритуал** (05 §Ритуал СТАРТА): переформулируй задачу своими словами, перечисли полученные входы/доки,
   проверь полноту context-to-load. Нет чего-то → `CONTEXT GAP`, стоп.

2. **RQ-2 — эмпирическая проверка формы `rate` (первый внутренний шаг; факт, не догадка).**
   Напиши read-only `curl`-probe к ИЗВЕСТНОМУ не-KGS майскому `paymentout`-документу (взять id из recon-выборки)
   и к одному KGS-документу для контраста. Цель: подтвердить по СЫРОМУ ответу API —
   (а) присутствует ли объект `rate` и поле `rate.value` **без** явного `expand`;
   (б) точная форма (`rate.value` — число; `rate.currency` — meta);
   (в) для KGS-документа `rate.value` отсутствует / = 1 (ожидаемо, findings §1).
   Человек запускает, возвращает сырой JSON. **Форму НЕ угадывать** — фикс адаптируется к подтверждённой.
   Если `rate.value` НЕ приходит без expand → добавь минимально необходимый `expand` и проверь ещё раз тем же
   probe; если и с expand не приходит → `CONTEXT GAP` (вопрос API-контракта МойСклад), стоп.

3. **Напиши фикс `main.py::run_etl()`** (только пишешь, НЕ деплоишь). По ADR-010:
   `sum_kgs = (sum / 100.0) * rate_value`, где `rate_value` берётся из подтверждённой RQ-2 формы
   (напр. `(row.get("rate") or {}).get("value")`), а при отсутствии → `1.0` (базовая валюта/KGS).
   Применить к **обоим** типам — `paymentout` И `cashout` (ADR-016 §3: cashout — из глобального scope ADR-010,
   forward-корректность, не из замера E1-T3). Если RQ-2 потребовал правку `expand` — внеси её в URL запроса.
   Всё остальное (схема STG, `MERGE`, `DELETE` ghost-статей, `trigger_marts`) оставить **байт-идентичным**
   снапшоту — не рефакторить, не «улучшать» (минимизировать blast radius, сохранить провенанс).

4. **Staging-first валидация (ТРЕБОВАНИЕ ADR-016 §4 — ДО касания прод `core.fact_payments`).**
   Проверь корректность нового `sum_kgs` против live API по не-KGS маю, НЕ записывая в прод. Допустимая форма
   (выбери, обоснуй, человек запустит): либо (a) прогон исправленного конвертера с перенаправлением `STG_TABLE`
   и цели `MERGE` в **staging-датасет/копию** + diff staging vs live API; либо (b) отдельный dry-compare скрипт:
   тянет майские не-KGS документы из live API, считает исправленный `sum_kgs`, диффит против KGS-суммы,
   выведенной из `rate.value` того же ответа — **без** `MERGE` в прод. Цель: **0,00 по не-KGS май без остатка**;
   KGS-документы неизменны. Не сходится → диагностика (не подгонка), правка фикса, повтор.

5. **Q-19 — структурный пре-cutover гейт (read-only, БЕЗ квантификации).**
   Сними живой `sq_marts_sales_overview.sql` (`bq show --transfer_config` Config `69ff34b4-0000-2b2b-a390-14c14ef7af10`)
   → закоммить в `/reference/sql/`. Определи ФАКТОМ: зависит ли `sales_overview` от `core.fact_payments`/
   `core.sum_kgs`. Ожидание (findings §2): sales питается `fact_sales_profit` (cf-facts), НЕ `fact_payments` →
   core-фикс изолирован, двойного исправления нет. **Подтвердить фактом, не допущением.** Если SQL всё же
   ссылается на `core.fact_payments` → **STOP**, вынеси архитектору (cutover обязан учесть двойную коррекцию).
   Квантификация/фикс sales — **вне scope** (Q-30/Q-19 магнитуда = DEFER).

6. **Контролируемый прод-cutover (только после зелёных 4 и 5 + апрув человека).**
   Не-идемпотентная дисциплина (05): сначала read-only, слепой retry запрещён.
   (i) пауза `finance-daily-update`; (ii) `describe`/`list` — убедиться, что нет in-flight прогона;
   (iii) деплой исправленной ревизии тем же деплой-конфигом из 11 §CF; (iv) контролируемый ручной прогон;
   (v) re-diff прод `core.fact_payments` vs live API по не-KGS май = **0,00 без остатка**;
   (vi) вернуть расписание `finance-daily-update`.

7. **Пост-cutover (обогащение провенанса).**
   Снапшот НОВОЙ ревизии cf-finance в `/reference/code/cf-finance/` — **байт-точно из `function-source.zip`/
   on-disk, НЕ транскрипцией** (ADR-017 §2) + обнови `MANIFEST.md` (sha256) и `11 §CF` (новая ревизия).

**Стандарт доставки всех скриптов (ADR-014, обязательно):** каждый скрипт — ОДНИМ copy-paste-ready
bash-блоком; секреты резолвятся inline — `gcloud secrets versions access msklad-token --project=msklad-bi-prod`
(имя из 11 §секреты, не изобретать); плейсхолдеры `<ВСТАВИТЬ…>` запрещены; запуск с редиректом
`bash script.sh > run.log 2>&1; cat run.log`. Наложенный/неразделимый лог = Untrusted → чистый перезапуск.

## Критерии приёмки (Acceptance)
- **RQ-2** разрешён реальным ответом API: форма `rate.value` подтверждена (или установлен минимальный `expand`);
  результат зафиксирован в session-логе. KGS-документ: `rate.value` отсутствует/=1 подтверждено.
- **Staging-валидация**: исправленный `sum_kgs` vs live API по не-KGS май = **0,00 точно, без остатка**;
  KGS-документы неизменны (нет регресса) — на staging/копии, до записи в прод.
- **Q-19-гейт**: зависимость `sales_overview` от `core.fact_payments` установлена ФАКТОМ (SQL снят);
  при наличии зависимости — эскалировано архитектору (cutover не выполнять до решения).
- **Прод re-diff** (после cutover): `core.fact_payments` vs live МойСклад API по не-KGS май = **0,00 без
  остатка** — подтверждённый человеком лог реального прогона.
- **Дисциплина cutover**: `finance-daily-update` поставлен на паузу на время деплоя и возвращён после;
  проверка отсутствия in-flight прогона выполнена; слепого retry на deploy/run не было.
- **Провенанс**: новая ревизия снапшочена в `/reference/code/cf-finance/` (байт-точно из zip/disk) +
  `MANIFEST`/`11 §CF` обновлены.

## Что вернуть человеку (Return-this)
- Патч `main.py` (фикс) + probe-скрипт (RQ-2) + staging-валидатор + cutover-скрипт — каждый одним bash-блоком,
  с командой запуска и ожидаемым выводом.
- Логи назад: (1) сырой JSON RQ-2 (не-KGS + KGS); (2) staging-diff = 0,00; (3) находка зависимости
  `sales_overview` (снятый SQL); (4) прод re-diff = 0,00; (5) подтверждение pause/resume расписания;
  (6) снапшот новой ревизии + sha256.
- Session-блок по `05_CONVENTIONS` Часть III (`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` /
  `NEW_CONVENTIONS`). В `STATE_PATCH`: `E1-T3-MECH-FX` → DONE (при зелёной приёмке); Текущий фокус → следующее;
  при подтверждении маршрутизации — коснуться Q-31 (порядок cutover E1-T1-MECH); снять заморозку расходных
  цифр дашборда (ADR-016 §Последствия), если приёмка зелёная.

## Вне scope этой задачи
- **Магнитудная кампания** (Q-30, DEFER, owner-gated): `cashout` за пределами мая, другие месяцы, весь март,
  sales-сторона количественно. Здесь — только forward-корректность кода + сверка не-KGS май.
- **Фикс/квантификация `sales_overview`** (Q-19 магнитуда — DEFER); здесь только структурный read-only гейт.
- **Аудит конвертера прочих CF** — `cf-facts`, `cf-fx`, `cf-dim`, `cf-dq`, `cf-inventory`, `cf-alert`,
  `load_invoices.py` (residual Q-3, следующий discovery-бриф).
- **E1-T1-MECH** (инъекция `loss`+`commissionreportin` в `sq_marts_expenses`, ADR-012 §4) — отдельная задача;
  порядок cutover относительно неё гейтится Q-31 (не решать здесь, только пометить в STATE, если всплывёт).
- **CODE-REPO-STANDUP** (живой VC-репо, ADR-017 §4/§5) — отдельная низкоприоритетная задача.
- **Построение TO-BE raw-марта** (ADR-012 §2 — не строится).

## В конце сессии
Выдай SESSION-блок по формату `05_CONVENTIONS` Часть III
(`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`).
