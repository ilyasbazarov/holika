# FILE: infra_facts_landing_2026-08-10.md

# INFRA-FACTS-LANDING — перенос фактов в живые доки, 2026-08-10

**Задача:** `INFRA-FACTS-LANDING` (класс A, `07_STATE.md §Мандат Claude Code`). Перенос трёх уже
измеренных групп фактов из `/reference` в живые доки, снятие `Q-11`/`Q-12`/`Q-13`. Облачных вызовов
нет — все входы уже в репозитории (`briefs/INFRA-FACTS-LANDING.md §Уточнение по этой задаче`).

Сырые логи: `reference/_scratch_INFRA-FACTS-LANDING_2026-08-10/`.

---

## 1. Таблица «факт → куда положен → источник → дата факта»

| Факт | Куда положен | Источник | Дата факта |
|---|---|---|---|
| `cf-alert`: тип/ревизия/URI/legacy URL/SA/timeout | `01_ARCHITECTURE.md §топология` | `reference/infra_facts_sweep_2026-08-01.md §Q-12`, `gcloud functions describe cf-alert` | 2026-08-01 |
| `cf-alert`: роль webhook-канала Cloud Monitoring, кто НЕ вызывает | `01_ARCHITECTURE.md §топология` | `reference/dq_source_capture_2026-08-02.md §5` | 2026-08-02 |
| `cf-alert`: полный блок (ревизия/URI/SA/timeout/секреты/роль) | `11_INFRA_FACTS.md §CF` | `reference/infra_facts_sweep_2026-08-01.md §Q-12` + `reference/dq_source_capture_2026-08-02.md §5` | 2026-08-01 / 2026-08-02 |
| Секреты `telegram-bot-token`/`telegram-chat-id` (имена) | `11_INFRA_FACTS.md §секреты (имена)` | `reference/infra_facts_sweep_2026-08-01.md §Q-12` | 2026-08-01 |
| Порядок 9 шагов `msklad-pipeline-hourly` (правка позиции `step_purchases`) | `01_ARCHITECTURE.md §DAG` | `reference/code/cf-facts/workflow_hourly.yaml` (sha256 сверен), `MANIFEST.md §Cloud Workflows — DQ-GATE-SCOPE-SPLIT-DEPLOY` | 2026-08-05 |
| Порядок 12 шагов `msklad-pipeline-weekly` (снимает `GAP Q-13`) | `01_ARCHITECTURE.md §DAG` | `reference/code/cf-facts/workflow_weekly.yaml` (sha256 сверен), `MANIFEST.md §Cloud Workflows — SALES-PERIMETER-CADENCE-DEPLOY` | 2026-08-07 |
| Блокирующая семантика (различие hourly/weekly по `step_purchases`/`step_returns`/`step_perimeter`/`step_perimeter_promote`) | `01_ARCHITECTURE.md §DAG` | оба снимка `.yaml`, строки `except`/`raise_*` | 2026-08-05 / 2026-08-07 |
| Указатель на `01 §DAG` вместо устаревшей формулировки `Q-13` | `11_INFRA_FACTS.md §CF`, строка про `msklad-pipeline-weekly` | правка этой сессии | 2026-08-10 |
| X=28/Y=164/Z=338 (530 строк), A=112/B=151/C=267 | `03_PIPELINE_SPEC.md:250` (указатель на дом, числа рядом) | `07_STATE.md §Контрольные цифры` (уже внесены сборкой 2026-08-01) | 2026-08-01 |

---

## 2. Сплошной поиск понятий (`ADR-083 §2`, Шаг 1) — вердикт по каждому совпадению

Полная выдача — `reference/_scratch_INFRA-FACTS-LANDING_2026-08-10/step1_sweep.log`. Ниже — файлы с
совпадениями и вердикт; построчная детализация внутри указанных файлов не переносится сюда целиком
(объём), кроме мест, где вердикт «правится».

### 2.1. `cf-alert` (`grep -rn "cf-alert"`)

- `01_ARCHITECTURE.md`, `11_INFRA_FACTS.md` — **правится** этой сессией (см. §1).
- `03_PIPELINE_SPEC.md` — упоминание в §DQ (не топология/не CF-факт) — **остаётся**, вне scope брифа
  (только строка 250 в наборе на запись).
- `04_ROADMAP.md` — историческая декомпозиция ЗАКРЫТОГО эпика M-P4 (`M-P4-01a`/`M-P4-D12`) — **остаётся,
  потому что** описывает прошлое планирование, не текущий placeholder; `04_ROADMAP.md` не входит в
  список файлов на запись этого брифа.
- `06_DECISIONS_LOG.md`, `06_INDEX.md` — append-only журнал решений, содержит исторические ADR-тексты —
  **остаётся, потому что** канон append-only, правка запрещена дисциплиной документации.
- `07_ARCHIVE.md` — архив закрытых строк (`ADR-064`) — **остаётся, потому что** архив не редактируется
  задним числом; отражает состояние на момент закрытия строки `INFRA-FACTS-SWEEP`.
- `07_GAPS.md`, `07_STATE.md` — не в списке файлов на запись этой сессии («Вне scope» брифа) — **остаётся**,
  правка — работа прохода сборки.
- `MIGRATION_MAP.md`, `RUNBOOK_v8.md` — замороженные источники — **остаётся** (`ADR-043`/метод, историчны
  по построению).
- `briefs/*.md` — брифы прошлых и текущей задач — **остаются**, брифы session-scoped и не переписываются.
- `reference/*.md`, `reference/_scratch_*` — датированные артефакты и провенанс прошлых сессий —
  **остаются** (`ADR-043`).

### 2.2. `pipeline-weekly`/`weekly-DAG` (`grep -rn`)

- `01_ARCHITECTURE.md`, `11_INFRA_FACTS.md` — **правится** этой сессией (см. §1).
- `04_ROADMAP.md` — декомпозиция закрытого M-P4 (`M-P4-01b`: «состав weekly-DAG = Q-13, вне scope A-01») —
  **остаётся**, тот же класс, что 2.1.
- `06_DECISIONS_LOG.md`, `06_INDEX.md`, `07_ARCHIVE.md`, `07_GAPS.md`, `07_STATE.md`, `MIGRATION_MAP.md`,
  `RUNBOOK_v8.md`, `briefs/*.md`, `reference/*.md`, `reference/_scratch_*` — тот же класс, что 2.1,
  **остаются** по тем же основаниям.
- `reference/code/cf-facts/MANIFEST.md` — провенанс-снапшот (не живой док) — **остаётся**, источник
  переноса, не предмет правки.

### 2.3. `X=39|Y=148|Z=439` (`grep -rn`)

- `03_PIPELINE_SPEC.md` — **правится** этой сессией; после правки **0 совпадений** (подтверждено §3
  ниже).
- `07_ARCHIVE.md` — архивная строка `INFRA-FACTS-SWEEP` цитирует старое/новое число как провенанс
  замера — **остаётся** (`ADR-064`, архив не редактируется).
- `07_STATE.md` — дом цифр, несёт и старое, и новое число как историю дрейфа — **остаётся** (не в
  списке файлов на запись; правка — работа сборки).
- `MIGRATION_MAP.md` — карта переноса, адресует PR-30 к `07_STATE` — **остаётся** (замороженная карта).
- `PROJECT_REFERENCE_v6.md` — замороженный источник — **остаётся** (`ADR-043`).
- `briefs/INFRA-FACTS-LANDING.md`, `briefs/INFRA-FACTS-SWEEP.md` — брифы, несут числа как часть
  постановки задачи — **остаются** (session-scoped, не переписываются).
- `reference/infra_facts_sweep_2026-08-01.md` — датированный артефакт замера — **остаётся** (`ADR-043`).

### 2.4. `GAP Q-1[123]|Q-1[123]` (`grep -rn`)

- `01_ARCHITECTURE.md` — **правится**; после правки `grep -c "GAP Q-12\|GAP Q-13"` даёт **0** (см. §3).
- `11_INFRA_FACTS.md` — **правится** (строка про `msklad-pipeline-weekly`, см. §1).
- `04_ROADMAP.md` — декомпозиция закрытого M-P4 (`M-P4-01a`/`M-P4-01b`/`M-P4-D12`/`M-P5-Q1`) —
  **остаётся**, тот же класс, что 2.1.
- `06_DECISIONS_LOG.md`, `06_INDEX.md` — ADR-142 (заводит `INFRA-FACTS-LANDING`), ADR-132 (мандат на
  деплой Cloud Workflows) — **остаются**, append-only канон.
- `07_ARCHIVE.md`, `07_GAPS.md`, `07_STATE.md` — реестр гэпов и его архив; строки `Q-11`/`Q-12`/`Q-13`
  и строка задачи `INFRA-FACTS-LANDING` — **остаются**, закрытие этих строк и перенос в архив — работа
  прохода сборки (session-блок ниже предлагает закрытие, не исполняет его).
- `MIGRATION_MAP.md` — карта переноса, исходная постановка `Q-3`/`Q-12` — **остаётся** (замороженная).
- `briefs/*.md` — брифы прошлых и текущей задач (`DQ-ALERT-FILTER-FIX`, `DQ-GATE-SCOPE-SPLIT`, `M-P3b`,
  `M-P4-A-01`, `M-P4-D5`, `M-P5-A-01` и др.) — **остаются**, session-scoped.
- `reference/*.md`, `reference/_scratch_*` — датированные артефакты — **остаются** (`ADR-043`).

**Итог сплошного поиска:** все совпадения вне пятёрки файлов на запись этой сессии либо в файлах вне
scope брифа классифицированы «остаётся»; ни одного необъяснённого совпадения не найдено. Полная
построчная выдача — `step1_sweep.log` (упомянутый выше).

---

## 3. Сверка снимков конвейеров (Шаг 2)

```
$ shasum -a 256 reference/code/cf-facts/workflow_weekly.yaml reference/code/cf-facts/workflow_hourly.yaml
a1a58a2f385ac1d32c488cae45134c08ed9f3e1097bb808eb2d0253527115ff8  reference/code/cf-facts/workflow_weekly.yaml
821edbeef502d786b2345219a01f0f7c2cee36d8d0b184a7ac63b85395eac47f  reference/code/cf-facts/workflow_hourly.yaml
```

Оба совпали с таблицей брифа §Входы п.2 и с `reference/code/cf-facts/MANIFEST.md §Cloud Workflows`.

**Извлечённый порядок шагов (программно, `grep -n "^    - "`):**

Weekly (12 шагов после `init`): `init → step_dim → step_fx → step_facts → step_purchases →
step_returns → step_perimeter → step_dq → parse_dq_result → check_dq → step_promote →
step_perimeter_promote → done`.

Hourly (9 шагов после `init`): `init → step_dim → step_fx → step_facts → step_purchases → step_dq →
parse_dq_result → check_dq → step_promote → done`.

Полная выдача с номерами строк — `reference/_scratch_INFRA-FACTS-LANDING_2026-08-10/step2_sha_and_order.log`.

---

## 4. Проверка приёмки — числа X/Y/Z бок о бок

```
07_STATE.md:1756: - X/Y/Z распределение (ABC/XYZ марты): X=28, Y=164, Z=338 (`marts.abc_xyz` = 530 строк; было X=39/Y=148/Z=439 на 2026-06-05, `Q-11` закрыт `INFRA-FACTS-SWEEP` 2026-08-01)
03_PIPELINE_SPEC.md:250: Распределение X/Y/Z и A-класс SKU — волатильные цифры, дом `07_STATE` §Контрольные цифры (факт **2026-08-01**: X=28, Y=164, Z=338 при 530 строках `marts.abc_xyz`; A=112, B=151, C=267).
```

Совпадают до единицы: `X=28`, `Y=164`, `Z=338`.

---

## 5. Проверка «мёртвая проводка» не перенесена

```
$ grep -n "мёртв" 01_ARCHITECTURE.md 11_INFRA_FACTS.md
(0 совпадений)
```

Снятый вывод (`ADR-149`) в живые доки не попал; в оба места внесена одна строка-указатель на
`DQ-ALERT-FILTER-FIX`/`ADR-149` без пересказа содержания.

---

## 6. Именованные остатки / пределы переноса

- **Состояние живых объектов на сегодня (2026-08-10) не проверялось.** Перенесены факты на даты
  замеров: `cf-alert` — 2026-08-01/2026-08-02; конвейеры — 2026-08-05/2026-08-07 (даты последних
  деплоев, снятые `MANIFEST.md`); ABC/XYZ — 2026-08-01. Ревизия `cf-alert-00001-bej` могла быть
  передеплоена после замера — этой сессией не проверялось (вне scope, облачных вызовов нет).
- Исходный код `cf-alert` в `reference/code/` не снят — остаток `Q-3`, отдельная задача (не эта).
- Причина дрейфа чисел классов товаров (было 626 строк, стало 530) — вне метода `Q-11`, не
  устанавливалась (то же ограничение унаследовано от `INFRA-FACTS-SWEEP`).
- Состояние доставки DQ-алерта в Telegram и разбор фильтра лог-метрики — закрыто отдельной задачей
  (`DQ-ALERT-FILTER-FIX`/`ADR-149`), в этой сессии только строка-указатель, без повторной диагностики.
- Обновление ревизий/URL прочих функций (`cf-dim`, `cf-fx`, `cf-facts`, `cf-finance`, `cf-dq`,
  `cf-inventory`) — не предмет этой задачи; расхождения не искались целенаправленно.
- `Q-11` в доме (`07_STATE §Контрольные цифры`) уже нёс свежие числа на момент этой сессии (внесены
  сборкой 2026-08-01) — эта сессия правит только указатель `03_PIPELINE_SPEC.md:250`, не сам дом.

---

## Провенанс

- `reference/_scratch_INFRA-FACTS-LANDING_2026-08-10/step1_sweep.log` — сплошной поиск (Шаг 1).
- `reference/_scratch_INFRA-FACTS-LANDING_2026-08-10/step2_sha_and_order.log` — sha256 + порядок шагов (Шаг 2).
- `reference/_scratch_INFRA-FACTS-LANDING_2026-08-10/step_acceptance_check.log` — сводная проверка
  критериев приёмки перед коммитом.
