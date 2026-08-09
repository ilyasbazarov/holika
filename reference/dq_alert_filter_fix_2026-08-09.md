# FILE: dq_alert_filter_fix_2026-08-09.md

# `DQ-ALERT-FILTER-FIX` — диагноз и предложенный фильтр (read-only, применение НЕ исполнено)

**Дата:** 2026-08-09 (Бишкек) · **Класс задачи:** B (правка живой policy — за гейтом мандата, НЕ выдан)
**Дерево/ветка:** `worktrees/DQ-ALERT-FILTER-FIX` / `s/DQ-ALERT-FILTER-FIX`
**База:** `git rev-parse HEAD` на старте — `abd48362504afa776f421f2cc68420f6168e0a9f`.
**Скрипты и сырые логи:** `reference/_scratch_DQ-ALERT-FILTER-FIX_2026-08-09/` (не убираются, `ADR-043`).

---

## 1. Свежее подтверждение текущей конфигурации (не повтор артефакта `dq_source_capture_2026-08-02.md`)

**Команды:** `gcloud logging metrics list` + `gcloud alpha monitoring policies list`
(`step2_list.sh`/`.log`, `2026-08-09T13:54:28Z`).

Лог-метрика (**имя ресурса** — `msklad_dq_gate_failed`, подчёркивания: GCP не допускает дефис в ID
лог-метрики; отображаемое имя policy — `msklad-dq-gate-failed`, дефисное — это два РАЗНЫХ
идентификатора одной цепочки, не расхождение):

```
name: msklad_dq_gate_failed
filter: |-
  resource.type="cloud_run_revision"
  resource.labels.service_name="cf-dq"
  jsonPayload.message=~"DQ.*FAILED|dq_gate.*fail|check failed"
  severity>=ERROR
```

Alert policy `msklad-dq-gate-failed` (enabled: true), условие:

```
conditionThreshold.filter: resource.type="cloud_run_revision" AND metric.type="logging.googleapis.com/user/msklad_dq_gate_failed"
comparison: COMPARISON_GT, aggregation: ALIGN_COUNT / REDUCE_SUM, alignmentPeriod=60s
notificationChannels:
- projects/msklad-bi-prod/notificationChannels/876055528317282377
- projects/msklad-bi-prod/notificationChannels/13959469767726741244
```

**Вывод:** фильтр дословно совпадает с зафиксированным в `dq_source_capture_2026-08-02.md §5` —
расхождения между тем снапшотом и текущей живой конфигурацией нет. Оба канала уведомлений (email +
Telegram через `cf-alert`) присутствуют и включены — алерт «выглядит настроенным» подтверждено
повторно, свежим запросом.

---

## 2. Диагноз — почему метрика не может сработать (уточнение сверх `dq_source_capture_2026-08-02.md`)

Реальный провал DQ Gate логируется **не тем сервисом и не в то поле**, которых ждёт фильтр. Прямой
запрос по известному инциденту `2026-08-01T18:02:01Z` (`step3_real_event.sh`/`.log`) вернул реальную
запись:

```json
{
  "resource": {"type": "workflows.googleapis.com/Workflow",
               "labels": {"workflow_id": "msklad-pipeline-hourly", "location": "asia-east1"}},
  "severity": "CRITICAL",
  "textPayload": "[HOURLY] DQ Gate FAILED run_id=1785607202.673309 details={...\"failed_checks\":[\"drift_check\"],\"passed\":false,\"status\":\"FAILED\"}",
  "timestamp": "2026-08-01T18:02:01.273774363Z"
}
```

Три независимых несовпадения с текущим фильтром, каждое по отдельности достаточно, чтобы дать 0
совпадений:

1. **`resource.type`/`resource.labels.service_name`** — запись живёт на
   `workflows.googleapis.com/Workflow` (`workflow_id=msklad-pipeline-hourly`), не на
   `cloud_run_revision` / `service_name="cf-dq"`. Само срабатывание чека происходит внутри `cf-dq`
   (HTTP-ответом), но КРИТИЧЕСКИЙ лог о провале пишет оркестрирующий Workflow (`sys.log`), не сама
   функция — это подтверждает `dq_source_capture_2026-08-02.md §5` дословно.
2. **`severity`** — реальная запись несёт `CRITICAL`, фильтр требует `severity>=ERROR`. Формально
   `CRITICAL ≥ ERROR` в шкале Cloud Logging, это несовпадение НЕ было бы блокирующим само по себе;
   блокируют пункты 1 и 3.
3. **Поле текста (новая находка этой сессии, не в `dq_source_capture_2026-08-02.md`).** Фильтр ищет
   `jsonPayload.message=~"..."`, но реальная запись несёт `textPayload`, не `jsonPayload` — поля
   `jsonPayload.message` у неё структурно не существует. Даже если бы `resource`/`severity` совпали,
   регэксп по `jsonPayload.message` не нашёл бы совпадения, потому что Workflow пишет `sys.log()` как
   простую строку (`textPayload`), а не структурированный JSON.

**Вывод:** метрика не срабатывает НЕ из-за одной ошибки, а из-за трёх независимых несовпадений
координат лога (ресурс, тип поля текста; severity формально проходит, но не спасает). Контрольный
запрос текущим фильтром дословно за то же 90-суточное окно, что и предложенный ниже (`step5`, свежий
запрос этой сессии, не повтор старого числа) — **0 совпадений**, подтверждено печатью:

```
match_count=0
```
(`step5_current_filter_control.log`, окно `2026-05-11T00:00:00Z…2026-08-09T13:55:00Z`).

---

## 3. Предложенный фильтр

```
resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id=~"^msklad-pipeline"
severity>=CRITICAL
textPayload=~"DQ Gate FAILED"
```

Обоснование по полям, каждое — от реального лога провала (§2), не от предположения «как должно быть»:

- `resource.type="workflows.googleapis.com/Workflow"` — ресурс, на котором реально пишется запись
  (замена `cloud_run_revision`/`service_name="cf-dq"`).
- `resource.labels.workflow_id=~"^msklad-pipeline"` — покрывает оба workflow (`-hourly` и `-weekly`,
  `11_INFRA_FACTS`/`infra_facts_sweep_2026-08-01.md §Q-13` подтверждает, что `-weekly` вызывает
  `cf-dq` тем же путём через `check_dq`); якорь `^` исключает случайные совпадения подстроки.
  Наблюдаемый инцидент относится к `-hourly`, второй ветвью замер не проверен (см. §5 «Предел»).
- `severity>=CRITICAL` — сужение с `>=ERROR` до `>=CRITICAL`: реальная запись несёт именно
  `CRITICAL`, `sys.log` вызывается workflow-степом с этим уровнем буквально
  (`dq_source_capture_2026-08-02.md §5`, `step2_hourly_workflow.yaml:99-109`); сужение не теряет
  сигнал, потому что других уровней severity этот текст не несёт.
- `textPayload=~"DQ Gate FAILED"` — замена `jsonPayload.message=~"DQ.*FAILED|dq_gate.*fail|check
  failed"`: поле, где реально лежит текст, плюс сама подстрока читается из реального провала
  дословно (`"[HOURLY] DQ Gate FAILED run_id=…"`). Регэксп сужен до одной подстроки, которая
  фактически наблюдалась; альтернативные варианты текста старого фильтра (`dq_gate.*fail`, `check
  failed`) в реальном логе не встречаются — не переносятся, чтобы не плодить непроверенные ветки.

---

## 4. Проверка на реальном событии `2026-08-01T18:02:01Z` (не синтетика)

**Команда:** `gcloud logging read` с предложенным фильтром, окно `2026-08-01T18:00:00Z …
2026-08-01T18:10:00Z` (`step4_proposed_filter_check.sh`/`.log`).

**Результат — ненулевая выдача, полная запись:**

```json
[
  {
    "insertId": "205cvff3tr3w2",
    "resource": {"type": "workflows.googleapis.com/Workflow",
                 "labels": {"workflow_id": "msklad-pipeline-hourly", "location": "asia-east1"}},
    "severity": "CRITICAL",
    "textPayload": "[HOURLY] DQ Gate FAILED run_id=1785607202.673309 details={...}",
    "timestamp": "2026-08-01T18:02:01.273774363Z"
  }
]
```

Совпадает `insertId` с записью, снятой в §2 независимым запросом (`205cvff3tr3w2`) — предложенный
фильтр адресует ровно ту запись, что диагностирована как реальный провал, не похожую по случайности.

**Контрольный замер за полное 90-суточное окно** (`2026-05-11T00:00:00Z…2026-08-09T13:55:00Z`,
`proposed_filter_90d.json`, `step4`):

```
match_count=118
```

118 — не аномалия и не ошибка широты фильтра: это согласуется с `ADR-101`/`07_STATE` («самоподдер-
живающийся отказ после первого срабатывания» — `drift_check` проваливается многократно в окне,
воркфлоу падает на каждом часовом прогоне до восстановления потока продаж). Число печатается как
факт наблюдения, интерпретация величины — вне scope этой сессии (диагностика причины отказа
`drift_check` — предмет `DQ-GATE-METRIC-REDESIGN`/`ADR-101`, не этой задачи).

---

## 5. Предел проверки

- Оба запроса (§2 контроль, §4 проверка) выполнены `gcloud logging read` — прямым чтением журнала
  Cloud Logging, независимо от `gcloud logging metrics`/`gcloud alpha monitoring policies`; это
  подтверждает, что записи ЕСТЬ и фильтр их находит, но **не эквивалентно факту, что лог-метрика с
  предложенным фильтром реально считает и агрегирует их** (метрика не создана, `gcloud logging read`
  не проходит через движок метрики). Это остаётся частью «применения», за гейтом мандата.
- **Доставка в Telegram/почту предложенным фильтром не проверялась** — вне класса A этой сессии
  (тот же предел, что в `dq_source_capture_2026-08-02.md §7`), не пытаться закрыть здесь.
- Ветвь `-weekly` (второй workflow, покрываемый `workflow_id=~"^msklad-pipeline"`) не имеет своего
  наблюдённого инцидента в выборке — покрытие regex подтверждено по имени (`infra_facts_sweep
  2026-08-01.md §Q-13`), не по факту сработавшего провала на этой ветке.
- Число `118` — наблюдение за фиксированное 90-суточное окно на момент `2026-08-09T13:55Z`, не
  прогноз будущей частоты.

---

## 6. Статус применения

**Правка живой log-based метрики/alert policy `msklad-dq-gate-failed`
(`gcloud logging metrics update` / `gcloud alpha monitoring policies update` или эквивалент) НЕ
ИСПОЛНЕНА.** Класс задачи — B; мандат владельца на применение не выдан ни одним ADR на момент
закрытия этой сессии (`07_GAPS.md`: `DQ-ALERT-FILTER-FIX` — READY, класс B, НЕ выдан). Весь текст
выше — read-only диагноз и предложение, ждущее отдельного мандата (прецедент формы — `ADR-092`,
`ADR-100 §9`).

---

## Провенанс

Все сырые логи и скрипты — `reference/_scratch_DQ-ALERT-FILTER-FIX_2026-08-09/`:
- `step1_describe.sh`/`.log` — попытка `gcloud logging metrics describe msklad-dq-gate-failed`
  (дефисное имя) — `NOT_FOUND`, оставлено как провенанс найденного дефекта нейминга (`ADR-043`):
  ID лог-метрики использует подчёркивания, отображаемое имя policy — дефис; два разных
  идентификатора одной цепочки, не расхождение конфигурации.
- `step2_list.sh`/`.log` — свежая конфигурация метрики + всех четырёх enabled policy (§1).
- `step3_real_event.sh`/`.log` — сырая запись реального провала `2026-08-01T18:02:01Z` (§2).
- `step4_proposed_filter_check.sh`/`.log` + `proposed_filter_90d.json` — проверка предложенного
  фильтра на реальном событии и за 90 суток (§4).
- `step5_current_filter_control.sh`/`.log` + `current_filter_90d.json` — свежий контрольный запрос
  ТЕКУЩИМ фильтром за то же окно, `match_count=0` (§2).

Каждый скрипт несёт `date -u`/`gcloud auth list` первой и последней командой (`ADR-055 §3/§4`).
