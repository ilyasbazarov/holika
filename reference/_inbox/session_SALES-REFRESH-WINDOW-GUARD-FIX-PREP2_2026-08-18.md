=== SESSION LOG · 2026-08-18 · SALES-REFRESH-WINDOW-GUARD-FIX-PREP2 ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: SALES-REFRESH-WINDOW-GUARD-FIX-PREP2 — обвязка `run_started_at` через `main()` →
  `_run_promote`/`_run_perimeter_promote` → `promote_to_core`/`promote_perimeter_to_core`;
  разбор трёх видов `run_id`.
- Сделано:
  - `_parse_run_started_at(run_id)` добавлена в `main.py` — различает float / строку-число /
    строку `%Y%m%dT%H%M%S`; неразбираемое значение — `ValueError` с названной причиной
    (fail-closed, `ADR-145`).
  - `_run_promote`/`_run_perimeter_promote` получили параметр `run_id`, вызывают
    `_parse_run_started_at` и форвардят результат третьим аргументом в
    `promote_to_core`/`promote_perimeter_to_core`.
  - Оба вызова из `main()` (`mode="promote"`, `mode="perimeter_promote"`) обновлены передавать
    `run_id`.
  - `bq_ops.py` не тронут ни строкой — нижний край, `GUARD_TOLERANCE_DAYS`, тела обоих `MERGE`
    остаются как после `PREP`.
- Команды/логи ключевые:
  - `grep -n "promote_to_core(\|promote_perimeter_to_core("` / `grep -n "_run_promote(\|_run_perimeter_promote("` —
    `0` совпадений старой (двухаргументной) арности.
  - `python3 -m py_compile reference/code/cf-facts/main.py reference/code/cf-facts/bq_ops.py` → `rc=0`.
  - `reference/_scratch_SALES-REFRESH-WINDOW-GUARD-FIX-PREP2_2026-08-18/verify_promote_chain.py` —
    три контроля через `main()` целиком (позитивный, отрицательный, разбор форм `run_id`) —
    все прошли как ожидалось.
  - `git diff --stat reference/code/cf-facts/bq_ops.py` → пусто.
  - Полный ход — `reference/sales_refresh_window_guard_fix_prep2_2026-08-18.md`.
- Отклонения от плана: нет.

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача SALES-REFRESH-WINDOW-GUARD-FIX-PREP2: READY → DONE (приёмка `guard_fixes_review_
  2026-08-17.md §7`, шесть пунктов, все закрыты — `reference/sales_refresh_window_guard_fix_
  prep2_2026-08-18.md §7`); строка полностью закрыта, переносится в `07_ARCHIVE.md` дословно
  (`ADR-064`).
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, НЕ дописывается, ровно пять строк):
  - Прошлый шаг: обвязка `run_started_at` для `SALES-REFRESH-WINDOW-GUARD-FIX-PREP2` исполнена
    и закрыта — `reference/sales_refresh_window_guard_fix_prep2_2026-08-18.md`.
  - Где мы: обе подготовки (`PREP` верхний край, `PREP2` обвязка) закрыты; деплой `cf-facts`
    ждёт повторного ревью архитектора, гейт на выкладку `SALES-REFRESH-WINDOW-GUARD-FIX-DEPLOY`.
  - Следующий шаг: повторное ревью архитектора `PREP2` → запрос мандата класса B на
    `SALES-REFRESH-WINDOW-GUARD-FIX-DEPLOY` → деплой `cf-facts` → первый недельный прогон
    (`2026-08-23`), исполняющий ветку периметра.
  - Развилки на владельце: нет (ревью — роль архитектора; мандат B запрашивается после ревью).
  - Счётчик: срок `2026-09-29`, шесть недельных прогонов; цепочка `PREP2 → ревью → мандат →
    деплой` обязана уложиться до `2026-08-23`, чтобы не сдвинуться на `08-30`
    (`guard_fixes_review_2026-08-17.md §8`).
- Подробности для модели: `PREP2` закрыта тем же приёмом проверки, что `PREP` и ревью §2 этого
  же документа — машинный обход вызовов (счётчик совпадений), не утверждение. Три контроля
  приёмки прогнаны через `main()` целиком (не через `promote_to_core` напрямую) — фейковые
  `google.cloud.*`/`flask`/`requests`/`tenacity` в `sys.modules`, скрипт запущен под
  `python3.14` (системный `python3` в этом окружении — `3.9.6`, не поддерживает PEP 604,
  которого требует несвязанный с патчем файл `fetch_returns.py`, импортируемый транзитивно
  через `main.py`); `py_compile` (приёмка) проходил отдельно системным `python3`. Полный ход —
  `reference/sales_refresh_window_guard_fix_prep2_2026-08-18.md`.
- Новые открытые вопросы: нет.
- Блокеры: нет.
- updated_at: 2026-08-18
- обновил: исполнитель (сессия: SALES-REFRESH-WINDOW-GUARD-FIX-PREP2)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md как ADR; "нет" если нет)
- нет

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
- нет

=== END SESSION ===
