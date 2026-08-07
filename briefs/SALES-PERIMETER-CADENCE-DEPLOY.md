# TASK BRIEF · T-SALES-PERIMETER-CADENCE-DEPLOY

**Класс задачи (ADR-076):** B
Живая конфигурация Cloud Workflows (`msklad-pipeline-weekly`) — деплой. Мандат выдан поимённо: **ADR-132**
(`06_DECISIONS_LOG.md:4717-4759`), введён сессией `SALES-PERIMETER-QUEUE-ADJ` 2026-08-07. Строка мандата в
`07_STATE.md §Мандат Claude Code` — `SALES-PERIMETER-CADENCE, шаг 3 (деплой Workflows)` (`07_STATE.md:1228`);
имя строки отличается от имени этого брифа формой (шаг родительской задачи против отдельного `-DEPLOY`-брифа
по прецеденту `SALES-INGEST-PATCH-DEPLOY`/`INVOICES-LOADER-DEPLOY`), объект и мандат — тот же самый ADR.
Расхождения имени с мандатом по существу нет; при сомнении сверить оба текста перед стартом.

**Параллель (ADR-082 §1, уточнён `ADR-083 §1`):** нет
Класс B не параллелится никогда (`07_STATE.md:1180`).

**Файлы на запись** (полный список; на нём МЕХАНИЧЕСКИ проверяется пересечение при параллельном
запуске — `tools/parallel_check.sh`, `ADR-083 §1`):
- `reference/code/cf-facts/MANIFEST.md` — запись результата read-back деплоя Workflows (ревизия до/после, `updateTime`, sha256 `sourceContents`), по образцу секции `DQ-GATE-SCOPE-SPLIT-DEPLOY` в этом же файле
- `reference/sales_perimeter_cadence_deploy_2026-08-07.md` — провенанс-артефакт сессии: объявление действия (шаг 4 процедуры), read-back, функциональная проверка, откат
- `reference/_scratch_SALES-PERIMETER-CADENCE-DEPLOY_2026-08-07/` — скрипты и сырые логи шагов 1/5/6/7

Вне этого списка правки: код-репозиторий `holika-prod` (внешний git-репозиторий, не файл `holika`) —
ветка `deploy/workflows-<дата>-perimeter-cadence`, коммит и слияние там регулируются `05_CONVENTIONS §Часть II
Процедура деплоя` и `reference/deploy_procedure_2026-08-03.md`, но это НЕ файл текущего репозитория и в
`tools/parallel_check.sh` не участвует.

## Роль
Ты — исполнитель проекта. Законы — `CLAUDE.md`, стандарты — `05_CONVENTIONS.md` Части I и II.
Модель исполнения: ты исполняешь сам (`ADR-082 §2`). Не-идемпотентное — `gcloud workflows deploy`,
`git push` — только отдельным действием после явного подтверждения владельца, никогда в связке с
диагностикой. `Done` — только по подтверждённому логу, не по `rc=0`.
Работаешь в СВОЁМ рабочем дереве и коммитишь в СВОЮ ветку (`ADR-081 §6`). `07_STATE`,
`06_DECISIONS_LOG` и `06_INDEX` не правишь: session-блок кладёшь файлом в `reference/_inbox/`.

## Цель
Развернуть на живом Cloud Workflows `msklad-pipeline-weekly` подготовленный патч
(`reference/code/cf-facts/workflow_weekly.yaml`): два новых шага — `step_perimeter` (staging, между
`step_facts` и `step_dq`) и `step_perimeter_promote` (core, после `step_promote`) — так, чтобы каденция
периметра продаж (`entity/retaildemand` + `entity/commissionreportin`) подключилась к недельному прогону,
с подтверждённым read-back и функциональной проверкой, без изменения `msklad-pipeline-hourly` и без
изменения самой функции `cf-facts`.

## Context-to-load (обязательно прочитать перед работой)
- `_METHOD`, `00_CHARTER`, `05_CONVENTIONS`, `07_STATE` (всегда, читаются с диска по именам)
- `05_CONVENTIONS.md` §«Процедура деплоя Cloud Function — только из код-репо, вариант Б» (Часть II) —
  канон процедуры; для Workflows read-back делается через `--format=json` + `sourceContents`, не через
  `--format="value(sourceContents)"` (ловушка лишнего перевода строки)
- `reference/deploy_procedure_2026-08-03.md` — полный текст процедуры (§1-§6, чек-лист §5)
- `06_DECISIONS_LOG.md:4717-4759` — ADR-132 полностью: разрешённое действие (§1), предусловие (§2),
  порядок и откат (§3), оговорка объявления действия (§4), явное исключение ручного прогона (§5)
- `07_GAPS.md` строка `SALES-PERIMETER-CADENCE` — полный текст гэпа: позиция шагов задана архитектурно
  и не выбирается сессией, основание недельной (не часовой) каденции, названная цена решения (розница/
  комиссия отстают от опта до 7 суток)
- `reference/sales_perimeter_cadence_2026-08-07.md` — шаги 1-2 (переснятие живых объектов + патч
  снапшота), уже DONE; шаг 1 этой задачи (свежий снимок ПЕРЕД деплоем) выполняется заново, снимок
  2026-08-07 не переиспользуется как «текущий» без повторной проверки (`ADR-021 §2`)
- `reference/code/cf-facts/workflow_weekly.yaml` — готовый пропатченный снапшот, источник патча для деплоя
- `reference/code/cf-facts/MANIFEST.md` §«Cloud Workflows — DQ-GATE-SCOPE-SPLIT-DEPLOY» (строки 86-128) —
  прямой прецедент деплоя Workflows той же процедурой: форма read-back, расположение каталога `workflows/`
  ВЕРХНЕГО уровня код-репо (не внутри `cf-facts/`), форма записи ревизия↔коммит
- `11_INFRA_FACTS.md` §CF, абзац «Инвентарь Cloud Scheduler» (строка 27) — регион `asia-east1`, проект
  `msklad-bi-prod`; учесть побочное наблюдение шага 1 `SALES-PERIMETER-CADENCE`: живых джобов Cloud
  Scheduler стало шесть против пяти в этом снимке (`invoices-daily-update` не документирован) — не
  трогать, не входит в scope этой задачи

Если чего-то из списка нет в контексте → выдай `CONTEXT GAP` и остановись.

## Входы
- Живой Cloud Workflow `msklad-pipeline-weekly`, регион `asia-east1`, проект `msklad-bi-prod`; ревизия
  на момент подготовки — `000004-6bf` (`updateTime=2026-08-05T05:17:59.298028382Z`,
  `reference/sales_perimeter_cadence_2026-08-07.md:24`). Эта задача обязана снять СВЕЖИЙ снимок перед
  правкой (шаг 1 процедуры) — ревизия могла измениться после 2026-08-07T13:04Z.
- Готовый пропатченный текст `reference/code/cf-facts/workflow_weekly.yaml` — синтаксис и порядок шагов
  уже проверены (`pyyaml`), патч НЕ выбирается заново.
- Код-репозиторий `holika-prod` (`https://github.com/ilyasbazarov/holika-prod`), ветка по умолчанию
  `master`, каталог `workflows/` верхнего уровня (прецедент `DQ-GATE-SCOPE-SPLIT-DEPLOY`).
- Мандат `ADR-132`: разрешено РОВНО одно действие — деплой нового текста `msklad-pipeline-weekly` с
  двумя названными шагами. Ничего сверх этого (никаких правок `msklad-pipeline-hourly`, никаких новых
  Scheduler-джобов, никаких правок `cf-facts`) этим мандатом не разрешено.

## Шаги
1. **Предусловие (Шаг 0 процедуры).** Подтвердить чистое дерево (`bash tools/session_status.sh`),
   мандат `ADR-132` выдан — уже подтверждено этим брифом.
2. **Шаг 1 процедуры — свежий снимок и сверка.** `gcloud workflows describe msklad-pipeline-weekly
   --format=json` (read-only), `date -u`/`gcloud auth list` в начале и в конце скрипта (`ADR-055 §4`).
   Извлечь `sourceContents` программно, сравнить с текущим содержимым `master` код-репо (каталог
   `workflows/`) побайтово. Расхождение с ожидаемой ревизией из предыдущего снимка — это ожидаемо
   (снимок ДО патча); СТОП наступает только если живой текст разошёлся с тем, что лежит в `master`
   код-репо (дрейф). Не совпало → СТОП, разбор до деплоя.
3. **Шаг 2 процедуры — ветка и перенос патча.** В код-репо `holika-prod`: `git checkout master && git
   pull`, `git checkout -b deploy/workflows-<дата>-perimeter-cadence`. Патч (два новых шага) переносится
   в `workflows/msklad-pipeline-weekly.yaml` (или под тем именем, под которым файл лежит в этом
   каталоге — проверить фактическое имя в `master`) **по diff** против пропатченного снапшота
   `reference/code/cf-facts/workflow_weekly.yaml`, не копированием файла целиком, если снапшот старше
   живого текста, снятого шагом 2.
4. **Шаг 3 процедуры — коммит и выкладка ветки.** Сообщение вида `workflows: подключить каденцию
   периметра продаж в msklad-pipeline-weekly (задача SALES-PERIMETER-CADENCE-DEPLOY)`. `git push` ветки
   — подтверждается владельцем отдельно (`ADR-076 §1`). `master` не трогается.
5. **Шаг 4 процедуры — объявление действия.** Отдельным сообщением в чат ДО деплоя: что именно
   разворачивается (новый текст `msklad-pipeline-weekly` с `step_perimeter`/`step_perimeter_promote`),
   на каком объекте (`msklad-pipeline-weekly`, `asia-east1`, `msklad-bi-prod`), чем откатывается (повторный
   `gcloud workflows deploy` текстом снятой на шаге 2 ревизии, сохранённым в scratch ДО деплоя, не по
   памяти) — `ADR-077 §6`, `ADR-132 §4`.
6. **Шаг 5 процедуры — деплой (класс B, требует подтверждения владельца).** Одна команда
   `gcloud workflows deploy msklad-pipeline-weekly --source=<путь к yaml в выкаченной ветке>
   --location=asia-east1 --project=msklad-bi-prod`, отдельным пастом, не в связке с диагностикой
   (`ADR-055 §2`). Доставка файлом, лог в файл, `date -u`/`gcloud auth list` первой И последней
   командой (`ADR-055 §4`, `ADR-063 §4`). Обрыв/timeout → read-only `describe`, не слепой retry.
7. **Шаг 6 процедуры — read-back.** `gcloud workflows describe msklad-pipeline-weekly --format=json`
   новой ревизии → `sourceContents` (программное извлечение, не форматтер `gcloud`, во избежание ложного
   расхождения на перевод строки — прецедент `DQ-GATE-SCOPE-SPLIT-DEPLOY`). Сверить sha256/содержимое с
   текстом ветки побайтово. Расхождение → деплой неуспешен, ветка не сливается (шаг 9 процедуры).
8. **Шаг 7 процедуры — функциональная проверка.** Мандат `ADR-132 §5` НЕ покрывает принудительный ручной
   прогон новых режимов (`perimeter`/`perimeter_promote`) — это отдельное решение (прецедент
   `PARITY-STOCK-SNAPSHOT-SYNC` шаг 2), в эту задачу не входит. Проверка ограничена тем, что не требует
   ручного вызова: дождаться штатного расписания (`0 1 * * 0`, UTC) ИЛИ подтвердить синтаксис/структуру
   развёрнутого текста программно (`pyyaml`, порядок шагов) как минимальную форму проверки без записи в
   `core`. Если требуется живая проверка прогоном — это `CONTEXT GAP`, отдельное решение владельца, не
   догадка.
9. **Шаг 8 процедуры — слияние и запись.** Только после успешного read-back: `git checkout master && git
   merge --no-ff deploy/workflows-<дата>-perimeter-cadence`, `git push origin master` (подтверждение
   владельца). Тем же шагом — запись в `reference/code/cf-facts/MANIFEST.md`: ревизия до/после,
   `updateTime`, sha256 `sourceContents`, SHA коммита код-репо (по образцу секции
   `DQ-GATE-SCOPE-SPLIT-DEPLOY`).
10. При неуспехе (шаг 9 процедуры) — ветка не сливается, откат на названную на шаге 4 ревизию,
    неудачная попытка фиксируется в `MANIFEST.md` наравне с удачной.

## Критерии приёмки (Acceptance)
- Живой `msklad-pipeline-weekly` несёт оба новых шага (`step_perimeter` между `step_facts` и `step_dq`,
  `step_perimeter_promote` после `step_promote`) — подтверждено read-back'ом (`sourceContents`
  побайтово), не сообщением команды деплоя (`ADR-021 §2`).
- `msklad-pipeline-hourly` не изменён (мандат `ADR-132 §1` запрещает); подтверждается тем, что его
  ревизия/`sourceContents` не трогались этой сессией.
- `master` код-репо равен развёрнутому тексту (инвариант процедуры §4.1) — коммит слияния существует
  только ПОСЛЕ успешного шага 6.
- `reference/code/cf-facts/MANIFEST.md` несёт запись «ревизия ↔ коммит» для этого деплоя.
- Мандат `ADR-132` не превышен: ни новых Scheduler-джобов, ни правок `cf-facts`, ни принудительного
  ручного вызова `perimeter_promote` этой сессией не сделано.

## Что вернуть человеку (Return-this)
- `reference/sales_perimeter_cadence_deploy_2026-08-07.md` с полным ходом (снимок до, ветка, объявление
  действия, деплой, read-back, что проверено функционально и что не проверено и почему, слияние).
- Точная команда шага 6 (деплой) и её вывод/лог, сообщение с объявлением действия (шаг 4) — как
  отдельное сообщение в чат ДО запроса подтверждения.
- Session-блок по `05_CONVENTIONS` Часть III файлом в `reference/_inbox/`.

## Вне scope этой задачи
- Правка `msklad-pipeline-hourly` — не разрешена мандатом.
- Правка самой функции `cf-facts` — не разрешена мандатом.
- Принудительный ручной прогон `mode=perimeter`/`perimeter_promote` — отдельное решение (`ADR-132 §5`).
- Правка `11_INFRA_FACTS.md` по найденному шестому Scheduler-джобу (`invoices-daily-update`) — не входит
  в набор файлов на запись этой задачи.
- Деплой `SALES-PERIMETER-CHANNEL-DECIDE` и `SALES-DOCUMENT-OWNER-DEPLOY` — отдельные задачи, отдельные
  мандаты, не выданы этим ADR.

## В конце сессии
Выдай SESSION-блок по формату `05_CONVENTIONS` Часть III
(`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`).
