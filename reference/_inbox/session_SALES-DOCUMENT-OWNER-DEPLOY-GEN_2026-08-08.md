=== SESSION LOG · 2026-08-08 · SALES-DOCUMENT-OWNER-DEPLOY-GEN ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: SALES-DOCUMENT-OWNER-DEPLOY-GEN — генерация task-brief для деплойной половины задачи
  `SALES-DOCUMENT-OWNER-DEPLOY` (сотрудник-владелец документа, `document_owner_employee_id`, в
  `core.fact_sales_profit`).
- Сделано: прочитан `_GENERATOR.md`, `_METHOD.md`, `00_CHARTER.md`, `04_ROADMAP.md`, `06_INDEX.md`
  (полностью), `07_STATE.md` (стенд-ап, строки мандата `SALES-DOCUMENT-OWNER-DEPLOY, доработка
  патча`/`, деплой`, строка «Открытые вопросы» `SALES-DOCUMENT-OWNER-DEPLOY`, разделы «Подробности
  для модели» вокруг доработки и деплоя), `05_CONVENTIONS.md` (полностью), `06_DECISIONS_LOG.md`
  точечно (`ADR-135`, `ADR-136` полным текстом), `reference/sales_document_owner_deploy_prep_
  2026-08-07.md` (приёмка доработки — `git diff`, `py_compile`, список колонок `UPDATE SET`/
  `INSERT`), `reference/sales_document_owner_ingest_2026-08-07.md` (базовый патч, провенанс поля,
  открытый вопрос `Q-105`), `reference/code/cf-facts/MANIFEST.md` (текущая база деплоя —
  `cf-facts-00009-tul`, после ДВУХ предыдущих деплоев того же дня), `11_INFRA_FACTS.md §cf-facts`
  (устарел — ревизия `00007-xir`, отмечено в брифе), `reference/deploy_procedure_2026-08-03.md`
  (процедура вариант Б целиком), `08_TASK_BRIEF_TEMPLATE.md`, прецедент
  `briefs/SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY.md` (структура и процедура для того же `cf-facts`),
  `reference/code/cf-facts/bq_ops.py` (подтверждено — колонка `document_owner_employee_id` типа
  `STRING`, обе ветки `MERGE` несут её). Собран бриф `briefs/SALES-DOCUMENT-OWNER-DEPLOY.md`.
- Команды/логи ключевые: только чтение с диска (`Read`/`Grep`/`Bash grep/wc`), без облачных вызовов
  — задача read-only генерации брифа; `bash tools/session_status.sh` на старте (RC 0, дерево чистое).
- Отклонения от плана: нет.

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача SALES-DOCUMENT-OWNER-DEPLOY: OPEN → OPEN (без изменений статуса); бриф деплойной половины
  собран, `briefs/SALES-DOCUMENT-OWNER-DEPLOY.md`, мандат класса B по-прежнему НЕ выдан.
- Стенд-ап: НЕ меняется этой сессией — генерация брифа не двигает «Текущий фокус», стенд-ап
  переписывается только сборкой/исполнительными сессиями.
- Подробности для модели: **Бриф `SALES-DOCUMENT-OWNER-DEPLOY` (деплойная половина) собран
  (сессия `SALES-DOCUMENT-OWNER-DEPLOY-GEN`, 2026-08-08), не взят.** Класс задачи — B (деплой
  `cf-facts` плюс `ALTER TABLE` живой `core.fact_sales_profit`), параллель — нет, мандат — НЕ выдан
  на момент сборки этого брифа (`07_STATE.md §Мандат Claude Code`, строка
  `SALES-DOCUMENT-OWNER-DEPLOY, деплой`); бриф несёт явный гейт в шапке по прямому предписанию
  `_GENERATOR.md §4a` («класс B без указанного ADR, выдавшего мандат» → бриф генерируется,
  исполнение блокировано до появления поимённого ADR). Доработка патча (класс A) уже DONE
  (`ADR-136 §2`) — бриф это фиксирует как вход, не переисполняет. Базовая ревизия для деплоя —
  `cf-facts-00009-tul` (`generation 1786115536540209`, `updateTime 2026-08-07T15:13:10Z`, `master`
  код-репо на коммите `7e039bd`) — это уже ВТОРОЙ деплой поверх ревизии, названной в предыдущем
  брифе (`cf-facts-00008-zen`); `11_INFRA_FACTS.md §cf-facts` устарел трижды подряд тем же классом
  дрейфа — бриф явно предупреждает исполнителя не брать оттуда ревизию/`generation` буквально. Бриф
  добавляет к процедуре вариант Б обязательный шаг `ALTER TABLE core.fact_sales_profit ADD COLUMN
  document_owner_employee_id STRING` ДО деплоя кода (предусловие `ADR-136 §4 (1)`, с read-only
  проверкой отсутствия колонки перед DDL) и обязательный первый прогон `weekly`/`window_days=90`
  ПОСЛЕ деплоя (предусловие `ADR-136 §4 (3)`, иначе июль-2026 не попадает в окно `MERGE`; окно
  закрывается `2026-09-29`, `ADR-125 §5`).
- Новые открытые вопросы: нет.
- Блокеры: нет новых; существующий блокер (мандат класса B на деплой НЕ выдан) не снят этой
  сессией — генерация брифа мандат не выдаёт.
- updated_at: 2026-08-08
- обновил: генератор брифа (сессия: SALES-DOCUMENT-OWNER-DEPLOY-GEN)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md как ADR; "нет" если нет)
- нет

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
- нет

=== END SESSION ===
