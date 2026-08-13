# INGEST-CURRENCY-ASSERT (шаги 1-2) — детекция «забыли умножить на курс»

**Класс задачи:** A (чтение репо/облака read-only, правка снапшотов кода, коммит без push).
**Дата исполнения:** 2026-08-13 (не 2026-08-03, дата в имени брифа — см. «Отклонение от брифа» ниже).

## Открывающая цитата постановки

`07_GAPS.md:67` (`Q-20`, дословно): «DQ-порог `currency_normalization` (`avg_revenue_kgs < 10M`,
`03_PIPELINE_SPEC.md` §DQ) — только верхняя граница (ловит «забыли `/100`, остались тыйыны»); НЕ
ловит регрессию «забыли `×rate`» (сумма занижена ~90x, а не завышена) — тот же класс бага, что и
TD-RECON-01. […] Дописка `ADR-101 §5`: ПЕРЕФОРМУЛИРОВАН. Вопрос «каким должен быть нижний порог»
получает ответ «порог не нужен и не помог бы». […] Проверка переносится в слой загрузки, где валюта
и курс есть на руках […]: для каждой позиции либо валюта документа есть валюта аккаунта, либо
применён `rate.value» (при отсутствии — курс по `ADR-010`); ответ бинарный, порога и owner-gated
числа не требует. Работа адресуется задачей `INGEST-CURRENCY-ASSERT`.»

`06_DECISIONS_LOG.md` `ADR-101 §5` — то же решение полным текстом (условная арифметика: «майские
`93 522 995,53` на 1363 строках ⇒ ≈`68 616` KGS/строка, регрессия `÷100` даёт ≈`6,86` млн, что НИЖЕ
порога `10` млн — проверка не сработала бы и на своей цели; утверждение условное, потому что текста
проверки в репо нет (`CONTEXT GAP`, снимается шагом 1 новой задачи)»).

## Отклонение от брифа: датировка артефактов

Бриф `briefs/INGEST-CURRENCY-ASSERT.md` датирован `2026-08-03` и называет файлы на запись с этим
суффиксом. Фактическая дата исполнения сессии — `2026-08-13` (десять суток спустя, задача не была
исполнена раньше). По `ADR-046 §1` датировка сессий/артефактов — локальная дата Бишкека на момент
исполнения, а не дата написания брифа. Артефакт и рабочая директория этой сессии несут суффикс
`_2026-08-13`; расхождение с литеральным именем в брифе называется, не примиряется молча.

## Шаг 1 — переподтверждение свежести `reference/code/cf-dq/`

Скрипт `reference/_scratch_INGEST-CURRENCY-ASSERT_2026-08-13/step1_reconfirm_cfdq_revision.sh`,
лог — `step1_run.log` в той же директории.

**Read-only `gcloud functions describe cf-dq`** вернул `serviceConfig.revision = cf-dq-00009-coy`,
`state=ACTIVE`, `updateTime=2026-08-12T19:14:47Z`. sha256 живого снапшота `reference/code/cf-dq/`
(`main.py`/`config.py`/`helpers.py`/`requirements.txt`) побайтово совпадает с таблицей read-back
ревизии `cf-dq-00009-coy` в `reference/code/cf-dq/MANIFEST.md` (раздел «Деплой `DQ-CFDQ-DEPLOY»`).
**Ревизия НЕ дрейфовала относительно снапшота в репо** — снапшот уже актуален (обновлён ДРУГИМИ
сессиями, `DQ-GATE-FAIL-OPEN-FIX` 2026-08-10 и `DQ-CFDQ-DEPLOY» 2026-08-12, ПОСЛЕ написания брифа
этой задачи). Повторного снятия исходника не требуется.

**Текст `check_currency_normalization` (`reference/code/cf-dq/main.py:209-213`), дословно из живого
снапшота:**

```python
def check_currency_normalization(bq):
    avg_rev = run_scalar(bq, f"""
        SELECT COALESCE(AVG(revenue_kgs),0) FROM `{STAGING}` WHERE revenue_kgs IS NOT NULL
    """) or 0.0
    return float(avg_rev) < DQ_CURRENCY_MAX_AVG_REV, f"avg_revenue_kgs={float(avg_rev):.2f}"
```

`STAGING = {GCP_PROJECT}.stg_msklad.fact_sales_staging` (`main.py:15`), `DQ_CURRENCY_MAX_AVG_REV =
10_000_000` (`config.py:18`). Подтверждён факт из `ADR-101 §5`: проверка — агрегатная эвристика по
`AVG(revenue_kgs)`, не построчная; ни валюты документа, ни `rate.value` в `stg_msklad.fact_sales_staging`
нет физически (конвертация уже применена загрузчиком до записи в staging) — проверка не может
различить класс ошибки «забыли `× rate»` по построению, только «остались тыйыны» (`÷100` не применён).

**Закрытие расхождения формулировки `07_GAPS.md:67`.** Текст строки числит шаг 1 задачи
невыполненным («исходник `cf-dq` не снят, ревизия не снята»). Факт: шаг 1 (съём исходника + ревизии)
уже исполнен ДРУГОЙ сессией `DQ-SOURCE-CAPTURE` (2026-08-02, `07_ARCHIVE.md` строка `DQ-SOURCE-CAPTURE»,
DONE) и `Q-6` закрыт (`07_ARCHIVE.md` строка `Q-6`, CLOSED `ADR-112 §4`: ревизия `cf-dq-00007-hot»,
создана `2026-06-18T10:59:31Z`, перенесена в `11_INFRA_FACTS.md §cf-dq`). Эта сессия переподтвердила,
что и текущая (более новая) ревизия `cf-dq-00009-coy` доступна в снапшоте и несёт тот же текст
`check_currency_normalization` (правка `DQ-CFDQ-DEPLOY` трогала только `check_drift`/новые проверки
свежести, не эту функцию — см. `MANIFEST.md` «Объём» соответствующего деплоя). Формулировка
`07_GAPS.md:67` устарела относительно факта в репо; правка самого `07_GAPS.md` — вне мандата этой
сессии (класс A, файл в списке «Вне scope»), расхождение фиксируется здесь и в `STATE_PATCH`
session-блока для сборки.

## Шаг 2 — перепроверка сплошного поиска точек конвертации

Команда `grep -rn "rate.get\|get(\"rate\"" reference/code/cf-facts/*.py reference/code/cf-finance/*.py`
(выполнена заново этой сессией, не доверяя списку брифа на слово):

```
reference/code/cf-facts/fetch_demands.py:148:            currency_rate = demand.get("rate", {}).get("value") or 1.0
reference/code/cf-facts/fetch_returns.py:79:            currency_rate = doc.get("rate", {}).get("value") or 1.0
reference/code/cf-facts/fetch_purchases.py:100:        currency_rate = order.get("rate", {}).get("value")
reference/code/cf-facts/fetch_perimeter.py:128:            currency_rate = doc.get("rate", {}).get("value") or 1.0
reference/code/cf-finance/main.py:70:                        * ((row.get("rate") or {}).get("value") or 1.0)
reference/code/cf-finance/invoices.py:144/171/172/173: rate/rate_value/currency — НЕ точка
    конвертации типа "or 1.0" (образец правильной формы ADR-029, см. ниже)
```

Шесть точек из брифа подтверждены (совпадает построчно). `cf-loss-commission/main.py:83-85` этим
grep-паттерном не ловится (другое именование полей) — вне scope, см. таблицу ниже.

**Находка по `fetch_purchases.py`, заявленная брифом как «требует отдельной проверки»:**
строка 100 (`currency_rate = order.get("rate", {}).get("value")`) действительно НЕ несёт `or 1.0`
на этой строке. Но `or 1.0` не исчезает — он переехал на точку ИСПОЛЬЗОВАНИЯ,
`fetch_purchases.py:140` (до правки этой сессии): `price_kgs = (pos.get("price") or 0) / 100.0 *
(currency_rate or 1.0)`. Поведение идентично остальным четырём точкам — `None` закрывается `1.0`,
просто в две строки вместо одной. Не самостоятельная находка нового класса, класс тот же.

## Шаг 3-4 — карта валют и детекция (таблица решений по каждой точке)

Правило детекции везде одинаковое (`ADR-101 §5`): `currency_ok = (iso_code == "KGS") or (rate.value
is not None)`; при `not currency_ok` — `log.warning`/`print` с id документа/позиции + счётчик,
печатаемый в конце функции. Карта `{currency_uuid: isoCode}` строится ОДНИМ запросом
`entity/currency` (пагинированным), НЕ через `expand=rate.currency` (ловушка `Q-49` /
`02_ERP_CONTRACTS.md:425` — `expand` молча роняется в `NULL` при `limit>100` в списочном ответе).

| Точка конвертации | Решение | Уровень детекции | Найдено детектором в offline-тесте |
|---|---|---|---|
| `fetch_demands.py:148` (`core.fact_sales_profit`) | **Правится.** `_fetch_currency_map` добавлена рядом с `_fetch_sales_channel_map`/`_fetch_project_map`; детекция — позиция | позиция (внутри цикла по `positions`, там же где `currency_rate`) | да (синтетика: не-KGS без `rate.value` → `currency_mismatch=1`) |
| `fetch_returns.py:79` (`core.fact_returns`) | **Правится.** Своя `_fetch_currency_map`; детекция — документ | документ (`rate` читается один раз на `salesreturn`/`retailsalesreturn`) | да |
| `fetch_purchases.py:100/140` (`core.fact_purchases`) | **Правится.** Своя `_fetch_currency_map`; детекция — заказ (там же, где читается `currency_rate`, ДО цикла позиций — рейт документный) | заказ | да |
| `fetch_perimeter.py:128` (`core.fact_sales_profit`, розница+комиссия) | **Правится.** `_fetch_currency_map` с модульным кэшем `_CURRENCY_MAP_CACHE` (функция вызывается из ДВУХ входных точек модуля — `fetch_retaildemand_positions`/`fetch_commission_sales_positions` — за один прогон, кэш не даёт задвоить запрос); детекция — позиция | позиция | да |
| `cf-finance/main.py:70` (`core.fact_payments`) | **Правится.** cf-finance не несёт `helpers.py`; `_fetch_currency_map` — инлайн-пагинация тем же приёмом (`nextHref`), что уже использует `run_etl()`; детекция — строка (paymentout/cashout) | строка (per-row) | да |
| `cf-loss-commission/main.py:83-85` (`core.fact_commissionreportin.reward_sum_kgs`) | **Вне scope.** Governed `ADR-026`; другая величина (`reward_sum_kgs`, не `revenue_kgs`/`sum_kgs`), брифом явно исключена | — | — |

## Diff'ы правленых точек (только добавленные строки в части арифметики)

`git diff --stat` этой сессии по пяти файлам: `180 insertions(+), 2 deletions(-)`. Обе «удалённые»
строки — расширение существующей `log.info(...)` до трёх счётчиков вместо двух и сдвиг пустой строки
(`fetch_demands.py`), не арифметика. Полный unified diff — `reference/_scratch_INGEST-CURRENCY-ASSERT_2026-08-13/full_diff.patch`.
Ключевой факт, подтверждающий незыблемость арифметики: во всех пяти файлах строки, вычисляющие
`revenue_kgs`/`sum_kgs`/`price_kgs`/`in_transit_sum_kgs`, присутствуют в diff'е ТОЛЬКО как контекст
(без `+`/`-` префикса) — детекция вставлена рядом (до или после), ветка `currency_rate = ... or 1.0`
не тронута ни в одной точке. Offline-тест (Шаг 6) подтверждает то же самое числом: арифметика
идентична ДО и ПОСЛЕ правки на всех трёх синтетических ветвях каждой точки.

Пример (`fetch_demands.py`, полностью):

```diff
             # Financial fields (all in тыйыны → ÷100 → KGS)
             currency_rate = demand.get("rate", {}).get("value") or 1.0  # KGS per currency unit
+
+            # INGEST-CURRENCY-ASSERT Шаг 4 (ADR-101 §5): бинарная детекция «валюта=KGS либо
+            # применён rate.value» — арифметика currency_rate/price_kgs НЕ меняется, только лог.
+            rate_obj    = demand.get("rate", {}) or {}
+            has_rate    = rate_obj.get("value") is not None
+            currency_id = parse_href(rate_obj.get("currency", {}).get("meta", {}).get("href", ""))
+            iso_code    = currency_map.get(currency_id) if currency_id else None
+            if not (iso_code == "KGS" or has_rate):
+                currency_mismatch += 1
+                log.warning(
+                    "Demand %s position %s: currency=%s (iso=%s) без rate.value — "
+                    "класс ошибки ADR-101 §5", demand_id, pos_id, currency_id, iso_code,
+                )
+
             price_kgs  = pos.get("price", 0) / 100.0 * currency_rate
```

Остальные четыре точки — тот же паттерн, вставка рядом с чтением `rate`, арифметическая строка не
модифицирована. Полный текст всех пяти диффов — `full_diff.patch` (351 строка).

## Шаг 5 — находка `ADR-029 §1`

**Действующий код всех пяти правленых точек нарушает уже принятое правило `ADR-029 §1`**
(«fallback-ветка ОБЯЗАНА падать исключением, если курс не прочитан; `1.0` запрещён»). Паттерн `...
or 1.0` — ровно запрещённая форма, во всех пяти точках без исключения. В проекте уже есть
задеплоенный образец правильной формы — `reference/code/cf-finance/invoices.py::rate_and_currency`/
`_fetch_current_rate` (`INVOICES-LOADER-DEPLOY», DONE 2026-08-03, ревизия `cf-finance-00013-jaq`):
три явные ветви (rate.value задан → использовать; нет и KGS → `1.0`; нет и не-KGS → живой `GET`
текущего курса, падение исключением при недоступности).

**Замена детекции на исправление (эта сессия НЕ делает) поменяла бы `revenue_kgs`/`sum_kgs` задним
числом при повторной загрузке** — больший blast radius (пересчёт исторических значений на всех
четырёх мартах-потребителях: продажи, возвраты, закупки, платежи), решение/задача владельца, вне
scope `INGEST-CURRENCY-ASSERT` (см. брифа §«Вне scope»). Рекомендация фиксируется в session-блоке
(`Новые открытые вопросы»`), решение НЕ принимается этой сессией.

## Шаг 6 — offline-тест

Скрипт `reference/_scratch_INGEST-CURRENCY-ASSERT_2026-08-13/step6_offline_currency_detect_test.py`,
лог — `step6_run.log` в той же директории. **Без секрета `msklad-token`, без единого живого `GET` к
МойСклад, без единого `bq query`/записи в прод-таблицы** (BigQuery замокан фиктивным клиентом, где
код финансового CF его вызывает вообще).

Метод: прямой импорт правленых модулей, подмена `paginate_entity`/`requests.get`/`bigquery.Client`
фиктивными данными (три синтетические ветви на каждую из пяти точек: KGS без `rate.value` → ok;
не-KGS с `rate.value» → ok; не-KGS без `rate.value` → детектор срабатывает, счётчик = 1/2 по числу
затронутых документов), плюс assert на неизменность формулы (`revenue_kgs`/`sum_kgs`/`price_kgs`
пересчитаны в тесте той же формулой и сравнены побайтово с результатом функции).

Окружение: система несёт Python 3.9 (`X | None` type hints в `fetch_returns.py` не парсятся —
несовместимость окружения тестирования с современным синтаксисом снапшота, не дефект снапшота: прод
несёт `python312`, см. `MANIFEST.md`). Тест запущен под `python3.14` (Homebrew) в изолированном venv
(`/tmp/ica_venv`, вне репо) с `pip install requests`; тяжёлые облачные SDK (`google-cloud-*`,
`tenacity`, `bigquery`) застублены модулями-заглушками — ни одна их функция тестом не вызывается.

**Вердикт (`step6_run.log`, `exit=0`):**

```
=== VERDICT ===
demands_kgs_no_rate: OK (no mismatch expected, arithmetic verified)
demands_usd_with_rate: OK (no mismatch expected, arithmetic verified)
demands_usd_no_rate_detected: OK mismatch_count=1
returns_kgs_no_rate: OK (arithmetic verified)
returns_usd_with_rate: OK (arithmetic verified)
returns_usd_no_rate_detected: OK mismatch_count=2
purchases_kgs_no_rate: OK (arithmetic verified)
purchases_usd_with_rate: OK (arithmetic verified)
purchases_usd_no_rate_detected: OK mismatch_count=1
perimeter_kgs_no_rate: OK (arithmetic verified)
perimeter_usd_with_rate: OK (arithmetic verified)
perimeter_usd_no_rate_detected: OK mismatch_count=1
finance_kgs_no_rate: OK (no mismatch, run_etl completed)
finance_usd_with_rate: OK (no mismatch, run_etl completed)
finance_usd_no_rate_detected: OK mismatch_lines=2
ALL OFFLINE CURRENCY-DETECT TESTS PASSED
```

`returns_usd_no_rate_detected=2` и `finance_usd_no_rate_detected=2` — ожидаемо (два документа/строки
в синтетике для этих точек: два типа документа у возвратов, два entity_type у платежей), не аномалия.

## Итог

Все шесть точек конвертации из брифа разобраны поимённо (пять правятся, одна — `cf-loss-commission`
— явно вне scope с названной причиной). Детекция вставлена в снапшот (не только описана прозой),
арифметика `revenue_kgs`/`sum_kgs`/`price_kgs` подтверждена неизменной diff'ом и offline-тестом.
Карта валют строится отдельным запросом `entity/currency`, не через `expand=rate.currency`. Ни
одного живого `GET` к МойСклад (кроме read-only `gcloud functions describe` Шага 1), ни одного `bq
query` к прод-таблицам, ничего не задеплоено. Находка `ADR-029 §1` зафиксирована как рекомендация,
не как решение.
