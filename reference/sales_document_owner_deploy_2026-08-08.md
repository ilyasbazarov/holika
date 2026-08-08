# FILE: sales_document_owner_deploy_2026-08-08.md

# SALES-DOCUMENT-OWNER-DEPLOY — попытка деплоя, 2026-08-08

**Первой фразой:** НЕ задеплоено. Мандат класса B на деплой не выдан (известно из брифа); дополнительно
эта сессия нашла, что шаг 3 (перенос патча по diff) не исполним как написано — снапшот несёт два
переплетённых недеплоенных патча, разделение которых не в компетенции исполнителя. `weekly`-прогон
не выполнялся.

**Задача:** `SALES-DOCUMENT-OWNER-DEPLOY`, деплойная половина (класс B).
**Статус:** заблокирована ДО начала (мандат не выдан) и НЕЗАВИСИМО от этого заблокирована по-новому
найденной причине на шаге 3.

---

## Что сделано (шаги 1–2, класс A, read-only)

**Шаг 1 — свежая проверка патча (Вход 1).** `reference/code/cf-facts/bq_ops.py:320` несёт строку
`T.document_owner_employee_id = S.document_owner_employee_id` в ветке `WHEN MATCHED THEN UPDATE SET`,
совпадает с приёмкой `reference/sales_document_owner_deploy_prep_2026-08-07.md`. `python3 -m py_compile`
— чисто (лог не сохранён отдельно, тривиальный прогон, воспроизводим командой из брифа).

**Шаг 2 — сверка живой ревизии с `master`.**
- `gcloud functions describe cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod` →
  ревизия `cf-facts-00009-tul`, `generation 1786115536540209`,
  `updateTime 2026-08-07T15:13:10.253085704Z` — совпадает с ожиданием брифа (Вход 4).
  Провенанс: `reference/_scratch_SALES-DOCUMENT-OWNER-DEPLOY_2026-08-08/describe_cf-facts.json`.
- Архив скачан по `generation`, распакован, `shasum -a 256` по всем 11 файлам.
- `master` код-репо (`holika-prod`) на коммите `7e039bd` — совпадает с ожиданием брифа (Вход 5).
- Побайтовая сверка (sha256): **все 11 файлов совпадают** между живым архивом и `cf-facts/` в `master`
  (`.gcloudignore` в `master` есть, в архиве отсутствует — ожидаемо, файл деплоя не касается).
  Провенанс: `reference/_scratch_SALES-DOCUMENT-OWNER-DEPLOY_2026-08-08/step2_compare.log`.

**База деплоя подтверждена фактом:** живая ревизия `cf-facts-00009-tul` == `master` @ `7e039bd`.

## Новая находка — шаг 3 не исполним как написано

Диф текущего снапшота `reference/code/cf-facts/bq_ops.py` против `master` (файл
`reference/_scratch_SALES-DOCUMENT-OWNER-DEPLOY_2026-08-08/step3_snapshot_vs_master.diff`) несёт
**два переплетённых недеплоенных патча** в одних и тех же функциях (`_build_merge_sql`,
`_build_perimeter_merge_sql`):

1. `document_owner_employee_id` — эта задача (`SALES-DOCUMENT-OWNER-INGEST`/`ADR-128` база +
   `SALES-DOCUMENT-OWNER-DEPLOY`/`ADR-136 §2` доработка `UPDATE SET`).
2. Ветка `WHEN NOT MATCHED BY SOURCE ... THEN DELETE` в ОБОИХ `MERGE` — задача `SALES-REFRESH-WINDOW`
   (`ADR-144 §8`, узкая форма), класс B, мандат тоже не выдан. Патч включает и правку докстринга
   `_build_perimeter_merge_sql`, которая описывает, что оба патча теперь присутствуют одновременно.

Бриф (Вход 4) исходил из посылки «снапшот несёт ровно один недеплоенный патч» — это было верно на
момент генерации брифа (2026-08-08, сессия `SALES-DOCUMENT-OWNER-DEPLOY-GEN`), но с тех пор снапшот
получил ещё патч `SALES-REFRESH-WINDOW` поверх того же файла (та же дата, более поздняя сессия
`SALES-REFRESH-WINDOW-ADJ`). Порядок/объединение деплоя этих двух патчей уже зафиксирован как
нерешённая развилка владельца в `07_STATE.md` (стенд-ап, «Развилки на владельце») и в `07_GAPS.md`
(строка `SALES-REFRESH-WINDOW`).

**Почему это не решается исполнителем механически:** «перенести патч по diff» из шага 3 предполагает
один патч. Ручное вычленение только хунков `document_owner_employee_id` из общего дифа потребовало бы
редакторского решения — какие хунки оставить, как переписать докстринг (который сейчас текстуально
утверждает наличие ОБОИХ патчей) — то есть фактически принять решение по неразрешённой развилке
порядка деплоя, не будучи на это уполномоченным.

## Что НЕ сделано и почему

- Шаг 3 (ветка, перенос патча) — не начат: см. находку выше.
- Шаг 4 (коммит, push ветки) — не начат (зависит от шага 3).
- Шаг 5 (объявление действия) и далее — не наступают: мандат класса B на деплой
  `SALES-DOCUMENT-OWNER-DEPLOY` не выдан (`07_STATE.md` §Мандат Claude Code, строка
  `SALES-DOCUMENT-OWNER-DEPLOY, деплой`).
- `ALTER TABLE` не исполнялся.
- `weekly`-прогон не исполнялся.

## Провенанс

`reference/_scratch_SALES-DOCUMENT-OWNER-DEPLOY_2026-08-08/`: `describe_cf-facts.json`,
`step2_describe.log`, `step2_download.log`, `step2_compare.log`, `step3_snapshot_vs_master.diff`,
`clone.log`. Скачанный архив/распаковка/клон `master` оставлены на диске (не закоммичены — бинарник и
вложенный `.git`), путь: `reference/_scratch_SALES-DOCUMENT-OWNER-DEPLOY_2026-08-08/{cf-facts-source.zip,live_archive/,holika-prod-check/}`.
