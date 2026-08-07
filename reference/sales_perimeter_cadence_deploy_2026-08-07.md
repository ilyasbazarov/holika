# FILE: sales_perimeter_cadence_deploy_2026-08-07.md

# SALES-PERIMETER-CADENCE-DEPLOY — шаг 3 (деплой Cloud Workflows) исполнен

**Дата:** 2026-08-07 (Бишкек) · **Класс:** B, мандат `ADR-132` (`06_DECISIONS_LOG.md:4717-4759`)
**Сессия:** `SALES-PERIMETER-CADENCE-DEPLOY` · **Провенанс:**
`reference/_scratch_SALES-PERIMETER-CADENCE-DEPLOY_2026-08-07/`

## Ход процедуры (`05_CONVENTIONS §Процедура деплоя … вариант Б`, чек-лист §5)

**Шаг 0 — предусловия.** Дерево чистое (`tools/session_status.sh`, RC=0), буфер пуст, отставания от
`origin/main` нет. Мандат `ADR-132` выдан поимённо (§1 разрешает ровно одно действие — деплой нового
текста `msklad-pipeline-weekly` с двумя названными шагами).

**Шаг 1 — свежий снимок и сверка.** `gcloud workflows describe msklad-pipeline-weekly --format=json`
на `2026-08-07T14:04:10Z…14:04:16Z` — живая ревизия `000004-6bf`
(`updateTime=2026-08-05T05:17:59.298028382Z`), `sourceContents` sha256
`9b7fcee08a2f2b46704c3b7aa8d83a26317260c6e79bb675e712ae76884d1647`. Побайтовая сверка с
`workflows/msklad-pipeline-weekly.yaml` в `master` код-репо `holika-prod` — **идентично**, дрейфа нет.
Поиск подстроки `perimeter` в живом тексте — 0 совпадений (каденция ещё не подключена, ожидаемо).
Сверка живого текста с пропатченным снапшотом `reference/code/cf-facts/workflow_weekly.yaml` —
расхождение ровно в два новых шага (`step_perimeter`, `step_perimeter_promote`), без побочных правок.
`gcloud auth list`/`date -u` в начале и в конце — аккаунт `ilyasbazarov4@gmail.com`, деградации нет.
Лог — `reference/_scratch_SALES-PERIMETER-CADENCE-DEPLOY_2026-08-07/step1_snapshot_and_diff.log`.

**Шаг 2 — ветка и перенос патча.** В `holika-prod`: `git checkout -b
deploy/workflows-2026-08-07-perimeter-cadence` от актуального `master`. Патч перенесён копированием
файла-снапшота (эквивалентно diff — шаг 1 подтвердил, что снапшот отличается от живого/master текста
ровно на два новых шага, дрейфа нет). Сплошной поиск секретов по диффу (`secret|token|password|api[_-]?key|private[_-]?key`,
регистронезависимо) — 0 совпадений. Коммит `1ef452c`.

**Шаг 3 — выкладка ветки.** `git push origin deploy/workflows-2026-08-07-perimeter-cadence` — по
подтверждению владельца в чате. `master` не тронут.

**Шаг 4 — объявление действия (отдельным сообщением ДО подтверждения деплоя, `ADR-077 §6`/`ADR-132 §4`).**
Названо: что разворачивается (новый текст `msklad-pipeline-weekly` с `step_perimeter`/
`step_perimeter_promote`), на каком объекте (`msklad-pipeline-weekly`, `asia-east1`, `msklad-bi-prod`),
чем откатывается (повторный деплой текстом ревизии `000004-6bf`, сохранённым в scratch до деплоя).

**Шаг 5 — деплой (по подтверждению владельца).** `gcloud workflows deploy msklad-pipeline-weekly
--source=<ветка>/workflows/msklad-pipeline-weekly.yaml --location=asia-east1
--project=msklad-bi-prod`, отдельным пастом, лог в файл, `date -u`/`gcloud auth list` первой и
последней командой. `2026-08-07T14:07:24Z…14:07:35Z`, RC=0, новая ревизия `000005-124`
(`updateTime=2026-08-07T14:07:30.884386952Z`). Обрывов не было, слепой retry не потребовался. Лог —
`reference/_scratch_SALES-PERIMETER-CADENCE-DEPLOY_2026-08-07/step5_deploy.log`.

**Шаг 6 — read-back.** `describe --format=json` новой ревизии → программное извлечение
`sourceContents` (не форматтер `gcloud`, во избежание ложного расхождения на перевод строки). sha256
read-back `a1a58a2f385ac1d32c488cae45134c08ed9f3e1097bb808eb2d0253527115ff8` — побайтово совпадает с
файлом ветки. Порядок шагов подтверждён построчным `grep`: `step_dim → step_fx → step_facts →
step_purchases → step_returns → step_perimeter → step_dq → step_promote → step_perimeter_promote →
done` — `step_perimeter` между `step_facts` и `step_dq`, `step_perimeter_promote` после `step_promote`,
как задано архитектурно (`07_GAPS.md` строка `SALES-PERIMETER-CADENCE`). YAML синтаксически валиден
(`pyyaml`). `msklad-pipeline-hourly` подтверждён неизменённым: `describe` вернул ту же ревизию
`000004-5fc` и тот же `updateTime`, что и до деплоя этой сессии. Лог —
`reference/_scratch_SALES-PERIMETER-CADENCE-DEPLOY_2026-08-07/step6_readback.log`.

**Шаг 7 — функциональная проверка.** Мандат `ADR-132 §5` НЕ покрывает принудительный ручной прогон
`perimeter`/`perimeter_promote` — не исполнялся, как и оговорено брифом. Проверено то, что не требует
ручного вызова: синтаксис/структура/порядок развёрнутого текста программно (шаг 6). **Не проверено:**
фактическое исполнение новых шагов на живых данных — это дождётся штатного расписания
`msklad-pipeline-weekly` (`0 1 * * 0`, UTC, следующий прогон ≈ 2026-08-09T01:00Z) и остаётся задачей
следующей сессии (прочитать лог прогона, подтвердить `stg_msklad.fact_sales_perimeter_staging` и
`core.fact_sales_profit` получили строки).

**Шаг 8 — слияние и запись.** `git checkout master && git merge --no-ff
deploy/workflows-2026-08-07-perimeter-cadence` → коммит `0c5f68e`, `git push origin master` — по
подтверждению владельца. Запись «ревизия ↔ коммит» — `reference/code/cf-facts/MANIFEST.md` §«Cloud
Workflows — `SALES-PERIMETER-CADENCE-DEPLOY`».

## Приёмка

- Живой `msklad-pipeline-weekly` несёт оба новых шага в заданной позиции — подтверждено read-back'ом
  побайтово. ✅
- `msklad-pipeline-hourly` не изменён — подтверждено (ревизия/`updateTime` совпадают с состоянием до
  деплоя). ✅
- `master` код-репо равен развёрнутому тексту — коммит слияния `0c5f68e` создан только после успешного
  шага 6. ✅
- `reference/code/cf-facts/MANIFEST.md` несёт запись «ревизия ↔ коммит» для этого деплоя. ✅
- Мандат `ADR-132` не превышен: ни новых Scheduler-джобов, ни правок `cf-facts`, ни принудительного
  ручного вызова `perimeter_promote` этой сессией не сделано. ✅

## Откат
Не потребовался. Форма (если понадобится позже): `gcloud workflows deploy msklad-pipeline-weekly
--source=<файл с текстом ревизии 000004-6bf> --location=asia-east1 --project=msklad-bi-prod`, текст —
`reference/_scratch_SALES-PERIMETER-CADENCE-DEPLOY_2026-08-07/step1_weekly_live_source.yaml`
(sha256 `9b7fcee0...`).
