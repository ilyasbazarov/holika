# FILE: sales_ingest_patch_deploy_2026-08-07.md

# /reference/sales_ingest_patch_deploy_2026-08-07.md — `SALES-INGEST-PATCH-DEPLOY`

**Не задеплоено. Прод `cf-facts` по-прежнему стоит на ревизии `cf-facts-00007-xir` (без изменений).**
Сессия остановлена владельцем на шаге 4 (push ветки) — владелец ответил «Нет, остановиться» на
прямой вопрос о push. Шаги 5–10 брифа (объявление действия, деплой, read-back, функциональные
проверки, слияние в `master`) не выполнялись.

**Задача:** `SALES-INGEST-PATCH-DEPLOY` (бриф `briefs/SALES-INGEST-PATCH-DEPLOY.md`).
**Класс:** B. **Мандат на сам деплой (шаг 5+):** по-прежнему НЕ выдан — вопрос не задавался, до
него дело не дошло.

---

## Что сделано (шаги 1–3 брифа, класс A/B-read-only, разрешены владельцем явно)

### Шаг 1 — состав полей позиции `entity/retaildemand` (разрешение владельца получено в чате)

Живой `GET entity/retaildemand?limit=1` → id `011ac0ec-ad98-11f0-0a80-18fc003e89ce`, затем
`GET entity/retaildemand/{id}/positions`. Тело ответа — дословно в
`reference/_scratch_SALES-INGEST-PATCH-DEPLOY_2026-08-07/step1_run.log`.

**Вердикт по каждому полю:**

| Поле (предположено по аналогии с `entity/demand`) | Найдено в живом ответе | Значение в образце |
|---|---|---|
| `price` | ДА | `108000.0` |
| `quantity` | ДА | `1.0` |
| `discount` | ДА | `0.0` |
| `assortment` | ДА | ссылка на `entity/product` |

Дополнительно присутствуют не предполагавшиеся заранее поля позиции: `id`, `accountId`, `vat`,
`vatEnabled`, `meta`. Ограничение метода из `sales_ingest_patch_2026-08-03.md §2` закрыто фактом:
позиционная форма `entity/retaildemand` подтверждена живым запросом, совпадает с предположением
по аналогии с `entity/demand` по всем четырём полям, которые код фактически читает.

### Шаг 2 — свежий снапшот и сверка с `master`

`gcloud functions describe cf-facts --gen2` (2026-08-06T19:19:48Z) вернул ту же ревизию и тот же
`generation`, что зафиксированы в `reference/code/cf-facts/MANIFEST.md` (`cf-facts-00007-xir`,
`generation 1782334223015697`) — дрейфа с прошлой сессии нет.

Архив скачан по закреплённому `generation`, распакован, `sha256` всех файлов сверен с `master`
код-репо (`git clone --branch master`, `HEAD = 6a581bf`). Полный лог —
`reference/_scratch_SALES-INGEST-PATCH-DEPLOY_2026-08-07/step2_run.log`.

**Результат сверки:** все 9 исполняемых файлов (`main.py`, `bq_ops.py`, `config.py`,
`fetch_byvariant.py`, `fetch_demands.py`, `fetch_purchases.py`, `fetch_returns.py`, `helpers.py`,
`requirements.txt`) плюс `deploy_and_workflow.sh` — sha256 совпадает побайтово с `master`.
Расхождение только в 7 файлах-мусоре живого архива (`.DS_Store`, три `.bak`, два разовых
patch-скрипта, `src.zip`) — тех же, что уже задокументированы `MANIFEST.md §Чистота архива`,
и они не входят в `master` (уже отфильтрованы seed'ом). **Расхождения не найдено — можно
продолжать.**

### Шаг 3 — ветка и перенос патча

Ветка `deploy/cf-facts-2026-08-07-perimeter` создана от `master` (`6a581bf`), локально, в клоне
код-репо внутри `reference/_scratch_SALES-INGEST-PATCH-DEPLOY_2026-08-07/step2_work/master_repo/repo/`
(не запушена — см. «Что НЕ сделано» ниже).

Патч перенесён **по diff**, а не копированием каталога: перед переносом отдельно подтверждено
(шаг 2), что база снапшота (`reference/code/cf-facts/`) и живая база `master` идентичны байт-в-байт
по всем не тронутым патчем файлам (`fetch_byvariant.py`, `fetch_purchases.py`, `fetch_returns.py`,
`helpers.py`, `requirements.txt`, `deploy_and_workflow.sh` — все 6 sha256-совпадают с `master`).
Только затем 4 патченных файла (`bq_ops.py`, `config.py`, `fetch_demands.py`, `main.py`) и новый
файл (`fetch_perimeter.py`) перенесены из снапшота поверх выкаченной ветки.

Размер диффа совпал с заявленным в `sales_ingest_patch_2026-08-03.md`: `bq_ops.py` (+222/−0),
`config.py` (+22/−0), `fetch_demands.py` (+19/−4), `main.py` (+82/−0), новый `fetch_perimeter.py`.

**`.gcloudignore`:** до патча в `cf-facts/` его не было (в самом `master` мусора и так нет — seed
уже очищен). Добавлен `.gcloudignore` (`*.bak`, `__pycache__/`, `*.pyc`, `.DS_Store`, `src.zip`,
`patch_*.py`) как условие следующего деплоя (`ADR-040`) — подтверждено: в ветке на момент коммита
НЕТ ни одного `.bak`/`__pycache__`/`.DS_Store`/`src.zip`.

**Сплошной поиск секретов** (grep по всем 5 файлам патча, печать совпавших строк):

```
$ grep -nE "AIza|Bearer [A-Za-z0-9._-]{20,}|-----BEGIN|api[_-]?key|secret[_-]?key|password\s*=|token\s*=\s*[\"'][A-Za-z0-9]{15,}" ...
0 совпадений

$ grep -n "MSKLAD_TOKEN\|msklad-token" ...
cf-facts/main.py:31:    --set-secrets="MSKLAD_TOKEN=msklad-token:latest"
cf-facts/config.py:21:SECRET_TOKEN = "msklad-token"
```

Оба совпадения — имя секрета Secret Manager (для последующего резолва `gcloud secrets` /
`--set-secrets`), не значение секрета. Значений токенов/ключей в патче нет.

**C1/C2 повторно подтверждены на перенесённом коде:** `grep -n "THEN INSERT ROW" cf-facts/bq_ops.py`
→ 0 совпадений; `python3 -m py_compile` всех 5 файлов патча — без ошибок.

Коммит в ветку (локально, не запушен): `bfa74d4`
`"cf-facts: расширение периметра продаж (retaildemand + commissionreportin) и исключение выручки
по отгрузке комиссионеру (задача SALES-INGEST-PATCH-DEPLOY)"`.

---

## Что НЕ сделано и почему

- **Push ветки `deploy/cf-facts-2026-08-07-perimeter` в `github.com/ilyasbazarov/holika-prod` —
  НЕ выполнен.** Владелец ответил «Нет, остановиться» на прямой вопрос о push (шаг 4 брифа
  требует подтверждения владельца перед этим действием). Коммит `bfa74d4` существует только
  локально, в рабочем клоне внутри
  `reference/_scratch_SALES-INGEST-PATCH-DEPLOY_2026-08-07/step2_work/master_repo/repo/`
  (сохранён, не удалён, `ADR-043`); текст диффа продублирован как провенанс —
  `reference/_scratch_SALES-INGEST-PATCH-DEPLOY_2026-08-07/step3_branch_diff.patch`.
- Шаг 4 (push) → шаг 10 (слияние в `master`) брифа не начинались.
- Объявление действия (шаг 5) не делалось — до вопроса о мандате на сам деплой дело не дошло.
- Прод `cf-facts` НЕ трогался: ревизия/архив/секреты/трафик — без изменений.
- `reference/code/cf-facts/MANIFEST.md` НЕ обновлён — запись «ревизия ↔ коммит» делается только
  по результату read-back успешного деплоя (шаг 6 брифа), которого не было.
- `reference/parity_registry.md` строки 18–19 не тронуты (вне scope этой задачи и не достигнуты
  по порядку).
- Пересверка расхождения `core` vs `report/profit/*` НЕ производилась — патч не деплоился, менять
  прод нечему.

## Продолжение

Задача `SALES-INGEST-PATCH-DEPLOY` остаётся `READY`, мандат класса B на деплой (шаг 5+) НЕ выдан.
Локальный коммит `bfa74d4` в ветке `deploy/cf-facts-2026-08-07-perimeter` (не запушенной) —
готовый материал для следующей сессии; следующей сессии не нужно заново переносить патч по diff,
достаточно проверить, что база (`master`) не сдвинулась с `6a581bf`, и продолжить с шага 4.
