=== SESSION LOG · 2026-08-07 · SALES-PERIMETER-CADENCE ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: SALES-PERIMETER-CADENCE — шаг 1 (read-only переснятие живых объектов) + шаг 2
  (патч снапшота workflow_weekly.yaml). Класс A, без брифа (мандат `07_STATE.md:1193`).
- Сделано:
  - Шаг 1: `gcloud scheduler jobs list` + `gcloud workflows describe` (weekly и hourly) с
    UTC-якорем и подтверждением личности вызывающего в начале и в конце. Подтверждено: 0
    совпадений подстроки `perimeter` в обоих живых Workflow — каденция периметра НЕ
    подключена, задача не закрывается фактом.
  - Шаг 2: `reference/code/cf-facts/workflow_weekly.yaml` — добавлены `step_perimeter`
    (после `step_facts`/до `step_dq`, staging, `timeout=600`) и `step_perimeter_promote`
    (после `step_promote`, core, `timeout=540`). Позиция задана архитектурно
    (`07_GAPS.md`), не выбиралась сессией. YAML-синтаксис и порядок шагов проверены
    программно (`pyyaml`).
- Команды/логи ключевые: `reference/_scratch_SALES-PERIMETER-CADENCE_2026-08-07/step1_resnap.sh`
  + `.log`; артефакт `reference/sales_perimeter_cadence_2026-08-07.md`.
- Отклонения от плана: нет. Побочное наблюдение вне scope — шедулер-джобов стало шесть
  против пяти в `11_INFRA_FACTS.md:27` (новый `invoices-daily-update`, не документирован);
  правка `11_INFRA_FACTS.md` не в наборе файлов этой задачи, наблюдение зафиксировано в
  артефакте, не как новая GAP-строка.

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача SALES-PERIMETER-CADENCE: OPEN (шаги 1-2 класса A) → шаги 1-2 DONE, шаг 3 (деплой,
  класс B) остаётся OPEN — мандат уже выдан, не входил в scope этой сессии.
- Текущий фокус: без изменений — `SALES-PERIMETER-LANDING-CHECK`/`SALES-DOCUMENT-OWNER-INGEST`
  остаются следующим шагом по стенд-апу; `SALES-PERIMETER-CADENCE` шаг 3 (деплой, класс B,
  мандат уже выдан) готов к исполнению по патчу этой сессии, когда владелец решит его начать.
- Новые открытые вопросы: наблюдение (не GAP-строка) — `invoices-daily-update` в
  `gcloud scheduler jobs list` (`asia-east1`, `0 4 * * *`, `Asia/Bishkek`, `ENABLED`)
  отсутствует в `11_INFRA_FACTS.md:27` (снимок `2026-07-25`); шесть джобов вместо пяти.
- Блокеры: нет.
- updated_at: 2026-08-07
- обновил: исполнитель (сессия: SALES-PERIMETER-CADENCE)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md; "нет" если нет)
нет

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
нет

=== END SESSION ===
