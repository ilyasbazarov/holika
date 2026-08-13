# FILE: marts_build_stamp_prep_2026-08-13.md

# `MARTS-BUILD-STAMP-PREP` — сборка трёх готовых текстов и проверка потребителей

**Дата:** 2026-08-13 (Бишкек) · **Задача:** `MARTS-BUILD-STAMP-PREP` · **Класс:** A, без брифа
(`ADR-086 §1`).
**База:** `git rev-parse HEAD` на старте — `680de46a1965f0d8418000af52f08119ccf6fd99`.
**Дерево/ветка:** `worktrees/MARTS-BUILD-STAMP-PREP` / `s/MARTS-BUILD-STAMP-PREP`.

**Форма (owner-gated выбор), на которую опирается эта сессия:**
`reference/marts_build_stamp_form_adj_2026-08-13.md` — вариант «две колонки»
(`_marts_built_at` TIMESTAMP = `CURRENT_TIMESTAMP()`, `_source_max_loaded_at` TIMESTAMP =
`MAX(_loaded_at)`/`LEAST(...)` источников). Этот документ читался целиком до начала работы;
committed на ветке `s/MARTS-STAMP-FORM-ADJ` (`91bfd29`), в `main` на момент старта этой сессии ещё
не влит — прочитан напрямую из связанного дерева (read-only, чужое дерево не редактировалось).
Разбор трёх запросов — `reference/marts_build_stamp_2026-08-10.md` (не переписан).

**Что делает эта сессия (остаток класса A по §7 формы):**
1. Собирает три готовых цельных текста запроса под выбранный вариант.
2. Проверяет каждый `bq query --dry_run`.
3. Проверяет потребителей Looker Studio: `customer_invoices_ar`/`expenses` (два Custom Query,
   ранее размечены безопасными) — перепроверка грепом; `weight_flow` (не Custom Query) — установка
   по репо, что читает страница «Склад», и вердикт по риску.

**Вне scope (напоминание из постановки):** применение SQL, правка `transferConfig`, деплой — класс B
на трёх объектах, пакетный мандат запрещён (`ADR-115 §5`). `core.dim_fx_rates` и
`marts.expenses_staging` вне scope (реестр известных ограничений, `ADR-156 §5`).

---

## §1 Три готовых текста

Файлы — `reference/sql/`:
- [sq_marts_customer_invoices_ar_stamped_2026-08-13.sql](sql/sq_marts_customer_invoices_ar_stamped_2026-08-13.sql)
- [sq_marts_expenses_stamped_2026-08-13.sql](sql/sq_marts_expenses_stamped_2026-08-13.sql)
- [sq_marts_weight_flow_stamped_2026-08-13.sql](sql/sq_marts_weight_flow_stamped_2026-08-13.sql)

Каждый — полный текст от первой строки до последней (не фрагмент, без многоточий), собран из
живого снапшота (`reference/sql/sq_marts_*.sql`, выгрузка 2026-07-07) плюс вставка колонок по
инсёрт-пойнту, указанному в `marts_build_stamp_2026-08-10.md` (customer_invoices_ar — строки
97-122; expenses — строки 181-212; weight_flow — строки 299-344).

**Отличие от чернового текста разбора 2026-08-10, зафиксированное явно:**
- `sq_marts_expenses`: в черновике §3 разбора `_marts_built_at` по ошибке не встречалась бы в
  `GROUP BY`, если копировать список группировки буквально из черновика с добавленной колонкой —
  этой сессией группировка оставлена БЕЗ добавления `_marts_built_at`/`_source_max_loaded_at`:
  обе колонки — константы запроса (не ссылаются на группируемые столбцы), группировка по ним не
  требуется и была бы синтаксической ошибкой лишнего толка. Подтверждено дословно — `dry_run`
  ниже проходит без синтаксической правки такого рода.
- `sq_marts_weight_flow`: `inbound` CTE в черновике 2026-08-10 обозначена многоточием
  («без изменений, строки 31-49 снапшота») — в готовом тексте это полный текст CTE, переписанный
  дословно из `reference/sql/sq_marts_weight_flow.sql:31-49`, без изменений содержимого.

## §2 `bq query --dry_run` — три прогона

Лог целиком: `reference/_scratch_MARTS-BUILD-STAMP-PREP_2026-08-13/dry_run_2026-08-13.log`
(`date -u`/`gcloud auth list` первой и последней командой скрипта, `ADR-055/063`; аккаунт
`ilyasbazarov4@gmail.com`, идентичен на входе и выходе — деградации авторизации в середине прогона
не было).

| Файл | rc | Вывод |
|---|---|---|
| `sq_marts_customer_invoices_ar_stamped_2026-08-13.sql` | 0 | `Query successfully validated. Assuming the tables are not modified, running this query will process 1415414 bytes of data.` |
| `sq_marts_expenses_stamped_2026-08-13.sql` | 0 | `Query successfully validated. Assuming the tables are not modified, running this query will process 1533969 bytes of data.` |
| `sq_marts_weight_flow_stamped_2026-08-13.sql` | 0 | `Query successfully validated. Assuming the tables are not modified, running this query will process upper bound of 3230365 bytes of data.` |

`rc=0` сопровождён непустым парсимым выводом (байты обработки — число, не placeholder) по всем
трём — критерий «успех инструмента ≠ факт» (`ADR-021 §2`, `ADR-044`) удовлетворён: это не голый
код возврата, а проверяемое утверждение BigQuery о валидности синтаксиса и схемы против живых
таблиц `core.*`/`marts.*` на момент запуска. Ни одна запись в BigQuery не производилась
(`--dry_run`, команда в allow, `.claude/settings.json:10`).

## §3 Потребители — вердикт

### `marts.customer_invoices_ar`, `marts.expenses` — безопасно

Перепроверено грепом (не пересказ архитекторской пометки):

```
$ grep -n "SELECT \*" reference/sql/msklad_expenses.sql
(0 совпадений, rc=1)
$ grep -n "SELECT \*" reference/sql/msklad_customer_invoices_ar.sql
(0 совпадений, rc=1)
```

Оба Custom Query (`reference/sql/msklad_expenses.sql:10-21`,
`reference/sql/msklad_customer_invoices_ar.sql:11-19`) перечисляют колонки явным списком; ни
`_marts_built_at`, ни `_source_max_loaded_at` в списки не входят и войти не могут без правки текста
самого Custom Query. Добавление двух колонок к соответствующим витринам эти два запроса не
затрагивает.

**Вердикт: безопасно.**

### `marts.weight_flow` — CONTEXT GAP, вопрос владельцу

Установлено по репо (`reference/ls_custom_queries_2026-07-30.md:30,35-39`): страница дашборда
«Склад» несёт источник `weight_flow`, и этот источник **не входит** в перечень пяти живых
Custom Query дашборда (`msklad_counterparty_returns`, `msklad_expenses`, `fact_returns`,
`msklad_customer_invoices_ar`, `msklad_inventory_latest`) — он в списке шести источников,
подключённых к таблице `marts.weight_flow` напрямую («прямые подключения к таблицам слоя `marts`,
не Custom Query», подтверждено независимо присутствием имени `weight_flow` в
`reference/schema_dump_2026-07-28.md` как таблицы датасета `marts`).

Для прямого подключения (в отличие от Custom Query) состав полей клиентской поверхности
определяется конфигурацией data source внутри интерфейса Looker Studio (список подключённых полей,
режим ручного/автоматического подхвата новых полей схемы), а не текстом, который лежит в этом
репозитории. Тот же паттерн риска архитектор уже называл для другого прямого подключения этого же
дашборда, `msklad_inventory_latest` (`ls_custom_queries_2026-07-30.md:93-94`: «идёт через
`SELECT *`. Состав колонок клиентской поверхности задаётся схемой… а не решением») — и сама форма
(`marts_build_stamp_form_adj_2026-08-13.md §4`) уже отметила это предусловие как непроверенное:
«Состав полей источника данных Looker Studio этой сессией не проверялся — проверка остаётся
предусловием».

Репозиторий не содержит: (а) списка полей, которые data source `weight_flow` в Looker Studio
объявляет подключёнными; (б) режима подхвата новых колонок схемы (авто vs фиксированный список);
(в) состава графиков страницы «Склад», использующих `weight_flow` (в отличие от
`msklad_inventory_latest`, для которого графики поимённо сняты владельцем 2026-07-30, для
`weight_flow` такого снятия не было).

```
CONTEXT GAP: репо не устанавливает, увидит ли Looker Studio две новые колонки (`_marts_built_at`,
`_source_max_loaded_at`) у прямого подключения `weight_flow` автоматически или только после
ручного «Refresh Fields» в интерфейсе, и есть ли на странице «Склад» график/вычисляемое поле,
чувствительное к неожиданному появлению новых полей (например, использующее позиционный, а не
именной доступ к колонкам, либо агрегацию по «всем полям»). Ни `_METHOD`, ни доступный снимок
дашборда (`reference/ls_custom_queries_2026-07-30.md`) этого не фиксируют — интерфейс Looker
Studio инструменту недоступен (`ADR-085 §9`). Вопрос адресован владельцу (у него интерфейс):
при появлении `_marts_built_at`/`_source_max_loaded_at` в `marts.weight_flow` не сломается ли
что-то на странице «Склад» источника `weight_flow`, и нужен ли перед применением ручной снимок
состава графиков/полей этого источника по прецеденту `msklad_inventory_latest`?
```

**Вердикт: CONTEXT GAP — предусловие применения (класс B) для объекта `sq_marts_weight_flow` не
закрыто; вопрос адресован владельцу выше.** Для `customer_invoices_ar`/`expenses` предусловие
закрыто вердиктом «безопасно» в этом же документе.

## §4 Что этой сессией не делалось (явно)

- Ни один SQL не применён, ни один живой `transferConfig` не тронут (класс A, только чтение +
  `--dry_run`).
- CONTEXT GAP по `weight_flow` не закрыт этой сессией — закрытие требует ответа владельца
  (интерфейс Looker Studio недоступен инструменту).
- `core.dim_fx_rates`, `marts.expenses_staging` — вне scope этой задачи (реестр известных
  ограничений, `ADR-156 §5`), не тронуты.
- Развилка агрегации (`LEAST()` vs раздельные колонки по источнику) не пересматривалась — принята
  как закрытая формой (`marts_build_stamp_form_adj_2026-08-13.md §3`).
