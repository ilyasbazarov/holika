# FILE: dq_gate_scope_split_deploy_2026-08-05.md

# `DQ-GATE-SCOPE-SPLIT-DEPLOY` — деплой патча периметра DQ Gate на два живых Cloud Workflows

**Задеплоено. Оба workflow стоят на новых ревизиях: `msklad-pipeline-hourly` →
`000004-5fc`, `msklad-pipeline-weekly` → `000004-6bf`.**

**Дата (Бишкек):** 2026-08-05 · **Роль:** исполнитель · **Класс задачи:** B (мандат выдан поимённо
`ADR-122 §5`, `reference/dq_gate_deploy_adj_2026-08-04.md §3`)
**Бриф:** `briefs/DQ-GATE-SCOPE-SPLIT-DEPLOY.md`
**Скрипты и сырые логи:** `reference/_scratch_DQ-GATE-SCOPE-SPLIT-DEPLOY_2026-08-05/`

---

## 1. Что сделано

Применён уже готовый и проверенный текстовый патч (`reference/code/cf-facts/workflow_{hourly,weekly}.yaml`)
к двум живым Cloud Workflows по процедуре `05_CONVENTIONS §Процедура деплоя … вариант Б`,
распространённой на класс объектов Cloud Workflows (`reference/dq_gate_deploy_adj_2026-08-04.md §5`).
Патч — чистая перестановка позиции шагов: `step_purchases` (оба workflow) и `step_returns` (weekly)
перенесены на позицию сразу после `step_facts`, перед `step_dq`. Ни один шаг текстуально не изменён.

## 2. Шаг 1 — свежий снимок и re-diff (до правки)

`gcloud workflows describe … --format=json`, поле `sourceContents` извлечено в файлы.

| Объект | `revisionId` (снят) | Ожидалось | Совпало |
|---|---|---|---|
| `msklad-pipeline-hourly` | `000003-f02` | `000003-f02` | да |
| `msklad-pipeline-weekly` | `000003-fa9` | `000003-fa9` | да |

sha256 живых снимков — `89f29d3ba73b54173d5eef3ed80ccfca0cb4f6aed0224549348304de88a36e6c` (hourly),
`cf08969259e8925a92a58aa23bc2b01358a87eb8bd44d11884b651b91bcabb1c` (weekly) — **точно совпали** с
sha256 снимка `2026-08-02`, объявленными во входах брифа. Дрейфа нет, СТОП не сработал.

`diff <(sort живой) <(sort патч)` пуст для обоих файлов (`step1_run.log`) — множество строк
тождественно, подтверждение перестановочности против СВЕЖЕГО снимка (не только против снимка
2026-08-02, на котором патч готовился).

## 3. Шаг 2-3 — seed и перенос патча в код-репо `holika-prod`

- **Seed** (исходный, не патченный текст живых ревизий, форма `ADR-094 §1`): коммит `f293555` в
  `master`, каталог `workflows/` верхнего уровня, файлы `msklad-pipeline-hourly.yaml` /
  `msklad-pipeline-weekly.yaml`. sha256 seed-файлов побайтово совпал с живым снимком шага 1 (значит и
  со снимком `2026-08-02`).
- **Патч перенесён по diff**, не копированием: сгенерирован `diff -u` между снимком `2026-08-02`
  (`reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02/step2_{hourly,weekly}_workflow.yaml`) и
  каноническим патчем (`reference/code/cf-facts/workflow_{hourly,weekly}.yaml`), применён к файлам
  seed-ветки командой `patch`. Результат — sha256 файлов ветки **точно совпал** с заранее объявленным
  sha256 патча в мандате (hourly `821edbeef502d786b2345219a01f0f7c2cee36d8d0b184a7ac63b85395eac47f`,
  weekly `9b7fcee08a2f2b46704c3b7aa8d83a26317260c6e79bb675e712ae76884d1647`). Коммит `e79bef6` в ветке
  `deploy/workflows-2026-08-05-dq-scope-split`.
- Сплошной поиск секретов по обоим файлам ветки (`token|secret|password|api[_-]?key|bearer`,
  регистронезависимо) — **0 совпадений**, команда и результат напечатаны (`step1_run.log`/сессионный
  вывод), пустая выдача не выдаётся за факт молча — зафиксирована явно.
- `master` до Шага 8 не тронут.

## 4. Шаг 4 — объявление действия

Объявлено отдельным сообщением в чате до каждого не-идемпотентного действия (push seed, push ветки,
деплой, merge) — что исполняется, на каком объекте, чем откатывается (`ADR-077 §6`). Все четыре
подтверждены владельцем явно, по одному за раз.

## 5. Шаг 5 — деплой

Порядок: сначала `msklad-pipeline-hourly`, затем `msklad-pipeline-weekly` (брифовое требование —
hourly проверяется на живом прогоне в течение часа, weekly ждал бы воскресенья).

| Объект | Команда | Новая ревизия | `state` | Лог |
|---|---|---|---|---|
| `msklad-pipeline-hourly` | `gcloud workflows deploy … --source=workflows/msklad-pipeline-hourly.yaml` | `000004-5fc` | `ACTIVE` | `step5a_deploy_hourly_run.log` |
| `msklad-pipeline-weekly` | `gcloud workflows deploy … --source=workflows/msklad-pipeline-weekly.yaml` | `000004-6bf` | `ACTIVE` | `step5b_deploy_weekly_run.log` |

Оба скрипта — `date -u`/`gcloud auth list` первой И последней командой, отдельными пастами, лог в
файл. Обрывов не было, слепой retry не потребовался.

## 6. Шаг 6 — read-back развёрнутого

**Находка, важная методически:** `describe --format="value(sourceContents)"` добавляет собственный
перевод строки в конце потока (артефакт форматтера `gcloud`, не факт о содержимом объекта) — первая
сверка hourly этим способом дала ложное расхождение в 1 байт. Read-back переделан через
`--format=json` + извлечение поля `sourceContents` программно (без постобработки потока) —
побайтовое равенство подтверждено для обоих объектов:

| Объект | sha256 read-back | sha256 файла ветки | Совпало |
|---|---|---|---|
| `msklad-pipeline-hourly` | `821edbeef502d786b2345219a01f0f7c2cee36d8d0b184a7ac63b85395eac47f` | тот же | да |
| `msklad-pipeline-weekly` | `9b7fcee08a2f2b46704c3b7aa8d83a26317260c6e79bb675e712ae76884d1647` | тот же | да |

Расхождений не найдено, ветка НЕ откатывалась.

## 7. Шаг 7 — функциональная проверка на живом прогоне hourly

Дождались очередного исполнения по расписанию (`0 * * * *`). Execution
`a28be854-7211-42e4-a723-a1aa70c8752e`: `startTime=2026-08-05T06:00:02Z`,
`endTime=2026-08-05T06:05:57Z`, `state=SUCCEEDED`, лог `[HOURLY] Pipeline COMPLETED`.

**Порядок `step_purchases` относительно `step_dq` установлен по HTTP-логам `cloud_run_revision`**
(прямой прикладной лог `mode=` от `cf-facts` в это окно отсутствует — гэп наблюдения, не примиряется
тихо, назван явно):

```
06:00:02  cf-dim    200   (step_dim)
06:01:03  cf-fx     200   (step_fx)
06:01:07  cf-facts  200   latency 55s   → завершение ~06:02:02  (step_facts)
06:02:02  cf-facts  200   latency 219s  → завершение ~06:05:41  (step_purchases — единственный
                                                                   оставшийся кандидат по числу и
                                                                   позиции вызовов к cf-facts в
                                                                   read-back-подтверждённом YAML)
06:05:41  cf-dq     200   latency 4s                             (step_dq)
06:05:46  cf-facts  200   latency 11s                            (step_promote)
06:05:57  "[HOURLY] Pipeline COMPLETED"                          (done)
```

Третий вызов `cf-facts` (`step_purchases`) заканчивается ровно в момент начала вызова `cf-dq` —
то есть исполняется **до** `step_dq`, что и было целью патча. Три вызова `cf-facts` в окне точно
соответствуют трём HTTP-шагам YAML (`step_facts`, `step_purchases`, `step_promote`); других кандидатов
на средний вызов нет — `step_dim`/`step_fx`/`step_dq` идут на другие URL и уже учтены отдельно.
**Что НЕ проверялось и не имитировалось:** поведение при ПРОВАЛЕ `check_dq` — провал не синтезируется,
наступает сам; это `DQ-GATE-SCOPE-CONFIRM`, отдельная задача.

## 8. Шаг 8 — слияние и запись соответствия

`merge --no-ff` ветки `deploy/workflows-2026-08-05-dq-scope-split` в `master`, `push` — коммит
`6a581bf`. Запись «ревизия ↔ коммит» — `reference/code/cf-facts/MANIFEST.md §Cloud Workflows —
DQ-GATE-SCOPE-SPLIT-DEPLOY`.

## 9. Что НЕ менялось (подтверждено диффом, не утверждением)

`step_dim`, `step_fx`, `step_facts`, `parse_dq_result`, `check_dq`, `raise_dq_failed`, весь путь
`step_promote` — ни одна строка не изменена текстуально сверх позиции соседних шагов (§3/§4
`reference/dq_gate_scope_split_2026-08-03.md`, диффы приведены построчно, применённый патч —
байт-в-байт та же конструкция). Порог `drift_check` (`0,10`/`0,03`) не тронут — задача калибровки не
имела решения на этой метрике (`reference/dq_gate_threshold_calibration_2026-08-04.md`), правки порога
нет вовсе.

## 10. Вне scope, не выполнялось этой сессией

Правка порога `drift_check`; ветка `ma7 == 0 → passed=True` (`DQ-GATE-FAIL-OPEN-FIX`); переделка
метрики (`DQ-GATE-METRIC-REDESIGN`); новые DQ-чеки для шести ненаблюдаемых таблиц
(`DQ-FRESHNESS-COVERAGE`); починка алерта `msklad-dq-gate-failed` (`DQ-ALERT-FILTER-FIX`); проверка
возобновления промоута (`FACTS-FLOW-RESUME-CONFIRM`, закрыта раньше отдельной сессией); правка
`deploy_and_workflow.sh`; правка inline-комментариев `# ── STEP 8/9`.
