=== SESSION LOG · 2026-08-07 · SALES-PERIMETER-LANDING-CHECK ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: `SALES-PERIMETER-LANDING-CHECK` — доехал ли периметр продаж (после деплоя
  `cf-facts-00008-zen` и разового промоута) до июля-2026, до витрины `marts.sales_overview`
  и до клиентской страницы
- Сделано: шесть read-only BigQuery измерений по приёмке `07_GAPS.md` (окно наблюдения,
  ядро/витрина за июль, помесячный разрез стадийной таблицы, разрез по каналу и по
  сотруднику) → артефакт `reference/sales_perimeter_landing_check_2026-08-07.md`
- Команды/логи ключевые: `reference/_scratch_SALES-PERIMETER-LANDING-CHECK_2026-08-07/measure.sh`
  → `.../run.log` (UTC-якорь и `gcloud auth list` в начале и в конце, все шесть блоков
  непустые, лог цельный)
- Отклонения от плана: нет

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача `SALES-PERIMETER-LANDING-CHECK`: READY → DONE
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` целиком, ровно пять строк):
  - Прошлый шаг: `SALES-PERIMETER-LANDING-CHECK` закрыта DONE — периметр продаж доехал до
    июля-2026 на уровне ядра и витрины (`4707`=`4707` строк, `112 502 581,88`≈`112 502
    581,90` KGS), артефакт `reference/sales_perimeter_landing_check_2026-08-07.md`
  - Где мы: суммарный периметр верен на витрине; разрез по сотруднику на клиентской
    странице ещё не переехал — ждёт `SALES-DOCUMENT-OWNER-DEPLOY`
  - Следующий шаг: `SALES-PERIMETER-CADENCE`, `SALES-PERIMETER-CHANNEL-DECIDE`,
    `SALES-DOCUMENT-OWNER-DEPLOY` (класс B, мандат не выдан — ждёт готовности патча)
  - Развилки на владельце: нет
  - Счётчик: пары реестра паритета 7/7 · Epic 1 очередь после деплоя периметра — одна из
    четырёх задач закрыта
- Подробности для модели: `SALES-PERIMETER-LANDING-CHECK` закрыта фактом: `core.fact_sales_profit`
  и `marts.sales_overview` сходятся по июлю на уровне округления; питающая стадийная таблица
  (`stg_msklad.fact_sales_perimeter_staging`, `commissionreportin_sale`) показывает непрерывный
  поток строк май→июнь→июль→август — гипотеза «периметр застрял на разовом промоуте» не
  подтверждается. Наблюдение владельца «прежняя картина расхождения» относится к разрезу по
  сотруднику (атрибуция через `dim_counterparties.owner_employee_id`, не через владельца
  документа), это ожидаемое следствие незавершённого `SALES-DOCUMENT-OWNER-DEPLOY`, а не
  признак того, что периметр не доехал. Полный ход и сырой вывод — `reference/sales_perimeter_landing_check_2026-08-07.md`.
- Новые открытые вопросы: нет
- Блокеры: нет
- updated_at: 2026-08-07
- обновил: executor (сессия: SALES-PERIMETER-LANDING-CHECK)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md как ADR; "нет" если нет)
нет

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
нет

=== END SESSION ===
