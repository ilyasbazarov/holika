=== SESSION LOG · 2026-07-29 · SOURCE-MAP-SALES ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: `SOURCE-MAP-SALES` — карта происхождения «документ МойСклада → `core.fact_sales_profit` →
  `marts.sales_overview` → LS «Инвестор»/«Операционка»» по живому коду снапшота `cf-facts`; исполнение
  различителя `Q-83` (двойной вычет возвратов).
- Старт-SHA (`git rev-parse HEAD`, основное дерево до создания ветки сессии): `4c8c42ebc1291ee43acadb0e60503d1f3b5d4d57`.
- Сделано:
  - Снят снапшот `cf-facts` (ревизия `cf-facts-00007-xir`, регион `asia-east1`) — `reference/code/cf-facts/`
    (8 живых файлов кода + `requirements.txt`) + `MANIFEST.md` по форме `cf-loss-commission`.
  - Карта поля→колонка для `revenue_kgs`/`cogs_kgs`/`margin_kgs` и сопутствующих величин —
    `reference/source_map_sales_2026-07-29.md`.
  - Различитель `Q-83` исполнен обеими половинами (код + числа май-2026): **двойного вычета возвратов
    НЕТ**, `revenue_kgs` в `core.fact_sales_profit` — валовая величина (=`sell_sum_kgs`), `return_sum_kgs`
    в этой таблице захардкожен `0.0`, единственный вычет — в марте из `core.fact_returns`.
  - Слот `cf-facts` в `11_INFRA_FACTS.md §CF` заполнен.
  - Переверка живого `sq_marts_sales_overview` конфига против репо-снимка 2026-07-07 — совпал (только
    косметические различия длины декоративных линий-комментариев и конечного перевода строки).
  - Три пункта для архитектора — `reference/architect_review_queue_2026-07-29-1.md`.
- Команды/логи ключевые: `reference/_scratch_SOURCE-MAP-SALES_2026-07-29/` — все скрипты и логи (`step1`…
  `step5`), включая диагностику билинг-аномалии.
- Отклонения от плана:
  1. **Найдена и остановлена сессией аномалия вне мандата задачи:** биллинг проекта `msklad-bi-prod` был
     отключён (`billingEnabled: false`, подтверждено `gcloud billing projects describe`), что блокировало
     `gcloud functions describe`, `gcloud scheduler jobs list` и скачивание архива из GCS. Эскалировано
     владельцу в чате отдельным сообщением ДО продолжения (класс B по существу — живой прод, не в мандате
     класса A этой сессии); владелец подтвердил восстановление биллинга в чате («восстановлено»); повторная
     проверка дала `billingEnabled: true`. Сессия продолжена с этой точки. Починка биллинга — действие
     владельца, не этой сессии; в session-блоке фиксируется как факт, не как выполненное этой сессией
     действие.
  2. `gcloud functions describe cf-facts` не заработал ни разу после восстановления биллинга — не
     переисполнялся повторно (метаданные уже сняты эквивалентным путём `functions list --format=json` +
     `run services describe`, независимо перекрёстно подтверждены). Расхождение зафиксировано в `MANIFEST.md`.
  3. Сессия пересекла полночь Бишкека (пауза на подтверждение владельца) — старт 2026-07-29, продолжение и
     коммиты — 2026-07-30 по локальной дате. Артефакты датированы `2026-07-29` (дата генерации брифа и
     фактического старта Шага 0), без ретро-переименования; UTC-факты внутри артефакта несут точные метки.
  4. Обнаружено и вынесено в review-очередь внутреннее противоречие кода `cf-facts` по трактовке зоны
     `moment` (продажи трактуют как UTC→Bishkek, возвраты/закупки — как уже-Bishkek без конвертации) — не
     решается этой сессией (класс A, без API-вызовов к МойСкладу).

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача `SOURCE-MAP-SALES`: READY → **DONE**. Артефакт: `reference/source_map_sales_2026-07-29.md`.
  Снапшот: `reference/code/cf-facts/` + `MANIFEST.md`. Слот `cf-facts` в `11_INFRA_FACTS §CF` заполнен.
  Различитель `Q-83` исполнен (см. ниже). Дополнение к описанию задачи в реестре: закрывает нашу сторону
  `Q-78` (карта поля→колонка снята для пары «Инвестор»/«Операционка», включая противоречие заголовка SQL
  и тела запроса по блоку возвратов); построчная численная сверка и правило моста — по-прежнему впереди,
  вне этой задачи. **Следующая в очереди — `SOURCE-MAP-REST`.**
- **Новая строка `Q-83` (заводится этим патчем — на SHA `79905d2` строки не было; текст восстановлен
  владельцем из закрытого чата `PARITY-REGISTRY-BRIDGE`, приведён дословно в брифе; см. `ADR-079`
  §Последствия, пункт не был исполнен коммитом `20b01da`):**

  | `Q-83` | (`PARITY-REGISTRY-BRIDGE`, 2026-07-29; **исполнен `SOURCE-MAP-SALES`, 2026-07-30**) `02 §схемы
  core` описывает `core.fact_sales_profit.revenue_kgs` как «Нетто выручка KGS» при наличии отдельных
  `sell_sum_kgs` и `return_sum_kgs`, а `reference/sql/sq_marts_sales_overview.sql` вычитает возвраты:
  `net_revenue_kgs = ROUND(f.revenue_kgs - COALESCE(r.return_sum_kgs, 0), 2)` по `LEFT JOIN` на
  `core.fact_returns`. Шапка того же SQL утверждает, что блок возвратов не подключён, тогда как `03 §marts`
  документирует join как действующий | факт (был кандидат в дефект) | **ЗАКРЫТ ФАКТОМ.** Код
  (`bq_ops.py:197-200,242-244,265-267,287-289`, снапшот `reference/code/cf-facts/`): `revenue_kgs` в
  `core.fact_sales_profit` тождественна `sell_sum_kgs` (обе = валовая `s.revenue_kgs` из staging, без
  вычета возвратов); `return_sum_kgs`/`return_quantity` в этой таблице захардкожены `0.0` для каждой строки
  — `core.fact_sales_profit` никогда не подключает `core.fact_returns`. Числа за май-2026 (запрос
  `reference/_scratch_SOURCE-MAP-SALES_2026-07-29/step4_q83_query.sh`, `2026-07-30T10:30:16Z`):
  `sales_sell_sum_kgs = sales_revenue_kgs = 93 522 995.53` (побитово равны), `sales_return_sum_kgs
  (core.fact_sales_profit) = 0.00`, `returns_sum_kgs (core.fact_returns) = 570.00`. **Двойного вычета
  возвратов НЕТ.** `revenue_kgs`/`sell_sum_kgs` в `core` — валовая величина; единственный вычет — в марте,
  из `core.fact_returns`. Дефект — в формулировке `02_ERP_CONTRACTS.md:49` («Нетто» вместо «Валовая»), не
  в SQL марта. Кандидат в объект паритета для пары «Инвестор»/«Операционка»: `net_revenue_kgs` (март) —
  единственная реально нетто-величина в цепочке; **выбор объекта паритета — решение архитектора**, не
  вывод этой сессии (`reference/architect_review_queue_2026-07-29-1.md`, пункт 1). Полный разбор —
  `reference/source_map_sales_2026-07-29.md §10`. |

- Текущий фокус: `SOURCE-MAP-REST` (`ADR-079 §7b`, класс A) — карта остальных трёх поверхностей
  (`core.fact_purchases`/`marts.in_transit`, `core.fact_customer_invoices`/`marts.customer_invoices_ar`,
  `stock`-компонент `marts.inventory_health`) + SQL custom query `msklad_counterparty_returns`. Снапшот
  `cf-facts` уже частично покрывает `fetch_purchases.py` (режим `purchases`) — при исполнении
  `SOURCE-MAP-REST` можно переиспользовать уже скачанный архив `reference/code/cf-facts/` вместо повторного
  скачивания (тот же revision, если не передеплоено между сессиями — проверить `updateTime` заново, не
  предполагать неизменность).
- Новые открытые вопросы:
  1. Три пункта архитекторской review-очереди (`reference/architect_review_queue_2026-07-29-1.md`):
     (1) выбор колонки-объекта паритета для пары «Инвестор»/«Операционка» (`revenue_kgs`/`sell_sum_kgs`
     валовая vs `net_revenue_kgs` марта) — блокирует финальное правило моста этой пары в
     `reference/parity_registry.md`; (2) противоречие трактовки зоны `moment` внутри `cf-facts` (продажи:
     UTC→Bishkek конвертация; возвраты/закупки: уже-Bishkek без конвертации) — не гейтит текущий якорь
     паритета (весь май-2026), рекомендация — DEFER по аналогии с `Q-77`; (3) отсутствие `× rate.value` в
     `fetch_byvariant.py` (COGS-агрегат) — вероятно корректно по семантике report-эндпоинта, не
     расследовано точечно.
  2. Расхождение кода с доками (не гейтит, зафиксировано `reference/source_map_sales_2026-07-29.md §8`):
     `PAGE_SIZE=1000` в `cf-facts` vs «`limit≤100`» в `04_ROADMAP.md` M-P4-02g; режим `returns` (`03`
     заявляет window `730`, константы `730` в коде `cf-facts` нет — вероятно параметр вызывающего
     `workflow.yaml`, вне архива); режим `purchases` (`03` заявляет «`MERGE` за 90 дней», код делает
     `WRITE_TRUNCATE` без окна — относится к `SOURCE-MAP-REST`, зафиксировано здесь одной строкой по
     требованию брифа).
  3. Вызывающий Cloud Scheduler job для `cf-facts` не идентифицирован (см. `MANIFEST.md §Известное открытое`).
- Блокеры: нет (все находки — `DEFER`/`proposed`, ничего не блокирует старт `SOURCE-MAP-REST`).
- updated_at: 2026-07-29
- обновил: исполнитель (сессия: `SOURCE-MAP-SALES`)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md; "нет" если нет)
нет — находки требуют суждения архитектора (`reference/architect_review_queue_2026-07-29-1.md`), не
формулируются как `accepted` ADR этой сессией.

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
нет

=== END SESSION ===
