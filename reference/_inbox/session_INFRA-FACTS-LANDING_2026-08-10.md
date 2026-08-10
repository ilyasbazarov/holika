=== SESSION LOG · 2026-08-10 · INFRA-FACTS-LANDING ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: `INFRA-FACTS-LANDING` — перенос трёх групп уже измеренных фактов из `/reference` в живые доки, закрытие `Q-11`/`Q-12`/`Q-13`
- Сделано:
  - `01_ARCHITECTURE.md §топология`: `GAP Q-12` заменён фактом `cf-alert` (ревизия, URI, SA, timeout, роль webhook-канала Cloud Monitoring, дата факта 2026-08-01/2026-08-02)
  - `01_ARCHITECTURE.md §DAG`: исправлен порядок часового прогона (`step_purchases` до `step_dq`, факт 2026-08-05); `GAP Q-13` заменён полным блоком недельного прогона (12 шагов, факт 2026-08-07) + таблица блокирующей семантики по конвейерам
  - `11_INFRA_FACTS.md §CF`: добавлен блок `cf-alert`; `§секреты (имена)`: добавлены `telegram-bot-token`/`telegram-chat-id`; снята устаревшая формулировка про `Q-13` у `msklad-pipeline-weekly`, заменена ссылкой на `01 §DAG`
  - `03_PIPELINE_SPEC.md:250`: устаревшие числа X=39/Y=148/Z=439 заменены свежими X=28/Y=164/Z=338 (A=112/B=151/C=267), указатель на дом `07_STATE §Контрольные цифры` сохранён
  - Шапки версий `01_ARCHITECTURE.md` (0.2→0.3) и `11_INFRA_FACTS.md` (0.2→0.3) обновлены
  - Артефакт `reference/infra_facts_landing_2026-08-10.md`: таблица факт→куда→источник→дата, полный сплошной поиск с вердиктом по каждому совпадению, sha256+порядок шагов, именованные остатки
- Команды/логи ключевые: `shasum -a 256` обоих `workflow_*.yaml` совпал с брифом и `MANIFEST.md`; `grep -n "GAP Q-12\|GAP Q-13" 01_ARCHITECTURE.md` → 0; `grep -n "мёртв" 01_ARCHITECTURE.md 11_INFRA_FACTS.md` → 0; `bash tools/hooks/selftest.sh` → провалено 0 (36/36); коммит `75c7091` прошёл хук
- Отклонения от плана: нет

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача `INFRA-FACTS-LANDING`: READY → DONE (правки закоммичены `75c7091` в ветку `s/INFRA-FACTS-LANDING`; строка вместе с `Q-11`/`Q-12`/`Q-13` предлагается к переносу в `07_ARCHIVE.md` целиком, `ADR-090 §1` — строка мандата `INFRA-FACTS-LANDING` снимается тем же коммитом)
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, НЕ дописывается, ровно пять строк):
  - Прошлый шаг: `INFRA-FACTS-LANDING` закрыта — три группы фактов (`cf-alert`, weekly-DAG, ABC/XYZ) перенесены в `01_ARCHITECTURE.md`/`11_INFRA_FACTS.md`/`03_PIPELINE_SPEC.md`, артефакт `reference/infra_facts_landing_2026-08-10.md`
  - Где мы: `Q-11`/`Q-12`/`Q-13` закрыты фактом; параллельно продолжается подготовка `DQ-GATE-METRIC-REDESIGN`/`DQ-GATE-BLOCK-BOUNDED`
  - Следующий шаг: выбор владельца по очереди передачи клиенту (`06_DECISIONS_LOG.md ADR-142 §6`) — `DQ-GATE-METRIC-REDESIGN` подготовка или `DQ-GATE-BLOCK-BOUNDED` подготовка
  - Развилки на владельце: выбор следующей задачи из рекомендации `ADR-142 §6` (proposed)
  - Счётчик: без изменений этой сессией (доки-перенос, не пара реестра)
- Подробности для модели: `01_ARCHITECTURE.md §DAG` теперь несёт различие блокирующей семантики по конвейерам (`step_purchases` non-blocking в hourly, blocking в weekly) — следующая сессия, работающая с `DQ-FRESHNESS-COVERAGE` или похожими задачами, может опираться на эту таблицу без повторного чтения `.yaml`-снимков. Полный ход — `reference/infra_facts_landing_2026-08-10.md`.
- Новые открытые вопросы: нет
- Блокеры: нет
- updated_at: 2026-08-10
- обновил: исполнитель (сессия: INFRA-FACTS-LANDING)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md как ADR; "нет" если нет)
- нет

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
- нет

**Отдельным пунктом (по требованию брифа §Шаг 9):** фактический набор файлов на запись этой сессии
шире поля `Пишет:` строки мандата `INFRA-FACTS-LANDING` в `07_STATE.md` — включён `03_PIPELINE_SPEC.md`.
Основание: решение владельца 2026-08-10 (см. `briefs/INFRA-FACTS-LANDING.md §Входы п.3` и шапку брифа);
`03_PIPELINE_SPEC.md` — документ исполнения, правится session-блоком без ADR
(`05_CONVENTIONS §Дисциплина изменений документации`). Расхождение поля `Пишет:` строки мандата и
фактического списка файлов названо здесь явно, как предписывает шапка брифа.

=== END SESSION ===
