# TASK BRIEF · M-P4-D5 (discovery)

## Роль
Ты — исполнитель discovery проекта **holika**. Сначала прочитай `_METHOD` + `05_CONVENTIONS`, затем действуй.
Модель исполнения: ты ПИШЕШЬ точные команды/артефакты, человек ЗАПУСКАЕТ (`bq`/`gcloud`) и возвращает вывод. Сам не исполняешь.
Это **discovery-бриф** (`_METHOD` §11): цель — добыть знание и обогатить репо, НЕ строить прод-артефакт.

## Цель
Закрыть **Q-5**: выгрузить канонический SQL всех scheduled queries (SQ / transferConfigs) BigQuery → `/reference/sql/`.
Это единственная жёсткая зависимость внутри M-P4 (`D5 → 03e2`); разблокирует подзадачу **M-P4-03e2** (перенос канонического SQL ~11 мартов/SQ в `03 §marts`).

## Context-to-load (обязательно; человек пиннит актуальным SHA при вставке в рабочий чат)
- `_METHOD` — https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/_METHOD.md
- `00_CHARTER` — https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/00_CHARTER.md
- `05_CONVENTIONS` — https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/05_CONVENTIONS.md
- `07_STATE` — https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/07_STATE.md  (строка **Q-5** в GAP-реестре)
- `04_ROADMAP` — https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/04_ROADMAP.md  (M-P4-D5 + квалификация Q-5)
- `MIGRATION_MAP.md` — https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/MIGRATION_MAP.md  (адрес **PR-29** — канонический SQL мартов)
- `03_PIPELINE_SPEC` — https://raw.githubusercontent.com/ilyasbazarov/holika/<SHA>/03_PIPELINE_SPEC.md  (§marts — адресат разблокировки)

Если чего-то из списка нет в контексте → выдай `CONTEXT GAP` и остановись.

## Входы
- Доступ к GCP-проекту **holika** с BigQuery Data Transfer (scheduled queries).
- **Точные `project_id` / `location` / Config ID — НЕ в репо** на этом SHA: `11_INFRA_FACTS` ещё не заведён (404), PR-21 Config ID — GAP. Поэтому Config ID добываются **живым `bq ls`**, а не из репо (иначе фабрикация).
- `bq` CLI, аутентифицированный под аккаунтом с правом чтения transferConfigs.

## Шаги
1. Список всех SQ:
   `bq ls --transfer_config --transfer_location=<LOCATION> --project_id=<PROJECT_ID> --format=prettyjson`
   Вернуть человеку полный список: `name` (resource), `displayName`, `destinationDatasetId`, `schedule`.
2. По каждому transferConfig:
   `bq show --transfer_config --format=prettyjson <RESOURCE_NAME>`
   Извлечь `params.query` (текст SQL) и целевую таблицу.
3. Сохранить каждый SQL как `/reference/sql/<displayName-slug>.sql` — **дословно**, без правок/форматирования/оптимизации (это эталон-провенанс, не рефактор).
4. Собрать индекс `/reference/sql/README.md`: таблица `Config ID ↔ displayName ↔ файл ↔ целевая таблица ↔ schedule`, с датой выгрузки и SHA.
5. Черновой патч `07_STATE`: **Q-5** → помечен на закрытие (референс-артефакт посеян + трассируем); отметить, что **M-P4-03e2 разблокирован**.

## Критерии приёмки (Acceptance)
- SQL **всех** SQ (ожидаемо ~11 + `in_transit`) выгружены **дословно** в `/reference/sql/*.sql`.
- Число `.sql`-файлов = числу transferConfigs из шага 1 (покрытие 100%, проверяемо).
- Каждый файл трассируем к своему Config ID через `/reference/sql/README.md`.
- Открытый вопрос **Q-5** в `07_STATE` помечен на закрытие; явно отмечена разблокировка **M-P4-03e2**.

## Что вернуть человеку (Return-this)
- Каталог `/reference/sql/` (файлы SQL) + `/reference/sql/README.md` (индекс).
- Полный вывод шага 1 (`bq ls`) — для аудита полноты.
- Черновой патч-diff по `07_STATE` (Q-5 → на закрытие + разблокировка M-P4-03e2).
- Точные команды, которые человек прогнал, с привязкой к созданным файлам.
- **НЕ** прод-код; **НЕ** проза `03 §marts`.

## Вне scope этой задачи
- Наполнение прозы `03 §marts` каноническим SQL (это **M-P4-03e2**, отдельной задачей поверх закрытого Q-5).
- Любая правка / рефактор / оптимизация выгруженного SQL.
- Прочие GAP (Q-4/Q-6/Q-7/Q-9/Q-10/Q-12/Q-13) и заведение `11_INFRA_FACTS`.
- Построение прод-марта `marts.expenses` (это Epic 1, гейтится завершением M-P4/M-P5).

## В конце сессии
Выдай SESSION-блок по формату `05_CONVENTIONS` Часть III
(`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`).
