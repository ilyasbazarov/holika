# /reference/report_fields_2026-07-31.md — Имена полей ответа МойСклад по восьми точкам API (REPORT-FIELDS)

**Задача:** `REPORT-FIELDS` (класс B, мандат поимённо `ADR-079 §9`, scope расширен `ADR-085 §5`).
**Дата замера (UTC):** 2026-07-31, `14:54:21Z…14:54:31Z` (`date -u` первой и последней командой скрипта).
**Личность на старте и в конце:** `ilyasbazarov4@gmail.com` (совпадает, `gcloud auth list`, начало и конец).
**Лог:** `reference/_scratch_REPORT-FIELDS_2026-07-31/step2_3_endpoints.log` + сырые тела ответов `reference/_scratch_REPORT-FIELDS_2026-07-31/0N_*.json`.
**Токен:** прочитан одной командой `gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod` в переменную окружения, нигде не напечатан (в логе — только длина строки, `40` символов). Форма заголовка авторизации — дословно `reference/code/cf-finance/main.py` строка 39: `{"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}`.
**Метод:** `curl --compressed` (декодирует `gzip`), не `requests`; `limit=1` на каждом запросе — снимаем только имена полей первого элемента, не весь список. Первая попытка (без `--compressed`) дала непарсимые тела — `jq` вернул parse error на всех восьми ответах; это untrusted-вывод (лог чистый на вид, но данные бинарны из-за незадекларированного gzip-декодинга), не факт «полей нет» — перезапущено чисто после фикса, старые логи/тела удалены перед повторным прогоном.

**Различитель `curl` вне списка прав (`ADR-076 §5.4`).** `.claude/settings.json` прочитан целиком на старте: `curl` не встречается ни в `allow`, ни в `ask`, ни в `deny` (подтверждено чтением файла, не документацией инструмента). Первый фактический сетевой вызов (`report/stock/all`, см. ниже) исполнен без дополнительного подтверждения сверх уже данного на Шаге 0 (доступ к секрету) — инструмент не завёл отдельный gate на сетевой вызов через `curl`, потому что список прав фильтрует префикс bash-команды (`gcloud`, `bq`, `git`), а не URL/протокол. Поведение зафиксировано по факту исполнения, не предположено.

---

## Восемь эндпоинтов

### 1. `report/stock/all`
- URL: `.../report/stock/all?limit=1`
- HTTP: `200`
- Верхнеуровневые ключи: `context, meta, rows` (`meta.size=312`)
- Ключи `rows[0]`: `externalCode, folder, image, inTransit, meta, name, price, quantity, reserve, salePrice, stock, stockDays, uom`
- Лог: `step2_3_endpoints.log:16-19`

### 2. `report/profit/byproduct`
- URL: `.../report/profit/byproduct?momentFrom=2026-05-01 00:00:00&momentTo=2026-06-01 00:00:00&limit=1`
- HTTP: `200`
- Верхнеуровневые ключи: `context, meta, rows` (`meta.size=279`)
- Ключи `rows[0]`: `assortment, margin, profit, returnCost, returnCostSum, returnPrice, returnQuantity, returnSum, salesMargin, sellCost, sellCostSum, sellPrice, sellQuantity, sellSum`
- Лог: `step2_3_endpoints.log:24-27`

### 3. `report/profit/bycounterparty`
- URL: `.../report/profit/bycounterparty?momentFrom=2026-05-01 00:00:00&momentTo=2026-06-01 00:00:00&limit=1`
- HTTP: `200`
- Верхнеуровневые ключи: `context, meta, rows` (`meta.size=64`)
- Ключи `rows[0]`: `counterparty, margin, profit, returnAvgCheck, returnCostSum, returnCount, returnSum, salesAvgCheck, salesCount, salesMargin, sellCostSum, sellSum`
- Лог: `step2_3_endpoints.log:32-35`

### 4. `report/stock/bystore`
- URL: `.../report/stock/bystore?limit=1`
- HTTP: `200`
- Верхнеуровневые ключи: `context, meta, rows` (`meta.size=317`)
- Ключи `rows[0]`: `meta, stockByStore` (вложенный массив `stockByStore[]` несёт `meta, name, stock, reserve, inTransit` по складу)
- Лог: `step2_3_endpoints.log:40-43`

### 5. `entity/purchaseorder`
- URL: `.../entity/purchaseorder?limit=1`
- HTTP: `200`
- Верхнеуровневые ключи: `context, meta, rows` (`meta.size=211`)
- Ключи `rows[0]`: `accountId, agent, agentAccount, applicable, created, deliveryPlannedMoment, description, externalCode, files, group, id, invoicedSum, meta, moment, name, organization, organizationAccount, owner, payedSum, positions, printed, project, published, rate, shared, shippedSum, state, store, sum, supplies, updated, vatEnabled, waitSum`
- Лог: `step2_3_endpoints.log:48-51`

### 6. `entity/invoiceout`
- URL: `.../entity/invoiceout?limit=1`
- HTTP: `200`
- Верхнеуровневые ключи: `context, meta, rows` (`meta.size=4501`)
- Ключи `rows[0]`: `accountId, agent, applicable, contract, created, demands, externalCode, files, group, id, meta, moment, name, organization, organizationAccount, owner, payedSum, paymentPlannedMoment, positions, printed, project, published, rate, salesChannel, shared, shippedSum, state, store, sum, updated, vatEnabled`
- Лог: `step2_3_endpoints.log:52-58`

### 7. `entity/salesreturn` (ранее не проверялся)
- URL: `.../entity/salesreturn?limit=1`
- HTTP: `200`
- Верхнеуровневые ключи: `context, meta, rows` (`meta.size=11` — всего 11 документов возврата в системе)
- Ключи `rows[0]`: `accountId, agent, agentAccount, applicable, attributes, contract, created, demand, externalCode, files, group, id, meta, moment, name, organization, organizationAccount, owner, payedSum, positions, printed, project, published, rate, salesChannel, shared, state, store, sum, updated, vatEnabled`
- Лог: `step2_3_endpoints.log:60-64`
- Результат Шага 3 брифа: **живой `200`, не `404`.** Кандидат в оракул для пары «Возвраты покупателей» (`ADR-085 §2`) существует и доступен.

### 8. `report/profit/byvariant` (ранее не проверялся, `ADR-085 §7`)
- URL: `.../report/profit/byvariant?momentFrom=2026-05-01 00:00:00&momentTo=2026-06-01 00:00:00&limit=1`
- HTTP: `200`
- Верхнеуровневые ключи: `context, meta, rows` (`meta.size=279`)
- Ключи `rows[0]`: `assortment, margin, profit, returnCost, returnCostSum, returnPrice, returnQuantity, returnSum, salesMargin, sellCost, sellCostSum, sellPrice, sellQuantity, sellSum`
- Лог: `step2_3_endpoints.log:68-71`
- **Наблюдение (факт, не гипотеза):** `rows[0]` этого ответа побайтово совпадает с `rows[0]` эндпоинта `report/profit/byproduct` (тот же `assortment.meta.href`, те же суммы, тот же `meta.size=279`). У товара, попавшего в первую строку (`limit=1`), нет заведённых модификаций (variant) — при их отсутствии `byvariant` схлопывается к товарному уровню и совпадает с `byproduct`. Различие между двумя эндпоинтами на товарах с реальными модификациями этим замером не проверено (не было в scope Шага 3 — снимался только первый элемент).

---

## Шаг 5 — валюта/база денежных полей `report/profit/byvariant`

По содержимому ответа (не по семантике «отчётные эндпоинты в базовой валюте», отклонённой `ADR-085 §7`):

- Ключи `rows[0]` эндпоинта `byvariant` (и идентичного ему в этом снимке `byproduct`) — **не содержат** ни `rate`, ни `currency` ни на одном уровне `rows[0]`. Денежные поля (`sellSum`, `sellCost`, `sellCostSum`, `sellPrice`, `profit`, `returnSum`, `returnCost`, `returnCostSum`, `returnPrice`) идут БЕЗ сопровождающего объекта курса/валюты в строке.
- Для сравнения: `entity/invoiceout`, `entity/purchaseorder`, `entity/salesreturn` (entity-API) **несут** поле `rate.currency`/`rate.value` в `rows[0]` рядом с `sum`.
- Факт: отчётные (`report/*`) эндпоинты не публикуют курс/валюту построчно, entity-эндпоинты публикуют. Само по себе отсутствие `rate` в `report/profit/byvariant` НЕ доказывает и не опровергает базу пересчёта (KGS напрямую или иная) — это отдельный вопрос семантики API, ответ на который эта сессия по инструкции Шага 5 не выводит домысливанием (`ADR-085 §7` отклоняет ровно такой ход рассуждения). Зафиксирован только наблюдаемый факт состава полей.

---

## Шаг 4 — различитель зоны `moment`

**Разрешён фактом сверки владельца (2026-07-31, чат).** Инструмент не имеет доступа к интерфейсу МойСклад (нет залогиненной сессии, credentials не вводятся), поэтому сверка выполнена владельцем по точечному вопросу.

- Документ: `entity/salesreturn`, номер **`00008`**, `id = 0d9650b7-7549-11f1-0a80-19c400103fb5`.
- Поле `moment` в ответе API: **`2026-07-01 15:33:00.000`** (без явного суффикса зоны в самом значении).
- Владелец сообщил, что интерфейс МойСклад по этому документу показывает: «Возврат покупателя № 00008 от 01.07.2026 18:33».
- **Разница: ровно +3 часа** (API `15:33` → интерфейс `18:33`), не +6, как давала бы гипотеза «API в UTC, интерфейс в Бишкеке (+6)», и не 0, как давала бы гипотеза «API уже в Бишкеке». Ни одна из двух предложенных гипотез не подтвердилась буквально — это отдельный, третий факт.
- +3 часа совпадает со сдвигом между Москвой (UTC+3) и Бишкеком (UTC+6): наблюдение согласуется с тем, что `moment` в ответе API отдаётся в московской зоне, а интерфейс показывает время в зоне аккаунта (Бишкек). Это согласованность, не подтверждённая причина — сама причина (почему именно MSK, а не UTC) этим замером не установлена и не входит в мандат этой сессии; адъюдикация правила моста для `moment`/`Q-77` — за архитектором.
- Единственный проверенный документ — один. Обобщение на все документы/эндпоинты этим замером не покрыто.

---

## Проверка перед `git add`

`grep -rF -- "$MSKLAD_TOKEN" reference/_scratch_REPORT-FIELDS_2026-07-31/ reference/report_fields_2026-07-31.md` — **0 совпадений** (exit code 1), выполнено после сборки обоих файлов.
