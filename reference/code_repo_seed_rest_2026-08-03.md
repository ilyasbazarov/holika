# FILE: code_repo_seed_rest_2026-08-03.md

# `CODE-REPO-SEED-REST` — seed `cf-facts` и `cf-dq` в код-репо `holika-prod`

**Дата (Бишкек):** 2026-08-03 · **Класс задачи:** A (подготовка + локальный коммит; `push` — владелец)
**Дерево/ветка:** `worktrees/CODE-REPO-SEED-REST` / `s/CODE-REPO-SEED-REST`
**Провенанс:** `reference/_scratch_CODE-REPO-SEED-REST_2026-08-03/step1_run.log` (якоря `date -u` и
`gcloud auth list` в начале и в конце, `ADR-063 §4`).

---

## 1. Способ съёма — обе функции прямым методом

В отличие от прежнего наблюдения `07_STATE.md` («`gcloud functions describe cf-facts` возвращает
`403`, рабочий обходной путь — `gcloud run services describe`»), **на этой попытке прямой
`gcloud functions describe cf-facts --gen2` отработал без ошибки.** Обходной путь не понадобился ни
для `cf-facts`, ни для `cf-dq`. Оба архива скачаны командой `gcloud storage cp <storageSource>#<generation>`
с **закреплённым `generation`**, то есть гарантированно той версией объекта, на которую указывает
текущая ревизия, а не текущим (возможно, более новым) содержимым бакета. Полный лог —
`reference/_scratch_CODE-REPO-SEED-REST_2026-08-03/step1_run.log`; сырые JSON-ответы —
`cf-facts_describe.json`, `cf-facts_run_describe.json` (кросс-проверка, не замена), `cf-dq_describe.json`
в том же каталоге.

| Функция | Ревизия | `generation` архива | URI (закреплённый) |
|---|---|---|---|
| `cf-facts` | `cf-facts-00007-xir` | `1782334223015697` | `gs://gcf-v2-sources-420804682491-asia-east1/cf-facts/function-source.zip#1782334223015697` |
| `cf-dq` | `cf-dq-00007-hot` | `1781780276907576` | `gs://gcf-v2-sources-420804682491-asia-east1/cf-dq/function-source.zip#1781780276907576` |

## 2. Сверка «на диске = задеплоено»

**`cf-dq`.** Сверка со старым `reference/code/cf-dq/MANIFEST.md` (снят 2026-08-02 прямым методом) —
**совпало** по всем 5 файлам, побайтово, той же ревизии и того же `generation`. Снапшот подтверждён,
файлы кода не переписывались (переписан только `MANIFEST.md` — добавлен раздел переподтверждения):

| Файл | sha256 (прежний, 2026-08-02) | sha256 (свежий, 2026-08-03) | Совпало |
|---|---|---|---|
| `main.py` | `9693010a…d86ea09` | `9693010a…d86ea09` | да |
| `helpers.py` | `0f335877…4ce9dd146` | `0f335877…4ce9dd146` | да |
| `config.py` | `7a818364…12fc543b6` | `7a818364…12fc543b6` | да |
| `requirements.txt` | `587133da…dbebfd6b516` | `587133da…dbebfd6b516` | да |
| `patch_dq.py` | `bb1bc968…9ccf213eeb22a` | `bb1bc968…9ccf213eeb22a` | да |

(Полные 64-символьные sha256 — в таблице §4 ниже и в `reference/code/cf-dq/MANIFEST.md`.)

**`cf-facts`.** Сверять было не с чем по построению (прежний снапшот снят обходным путём без
закреплённого `generation` — замера равенства не было). Свежий съём **СТАЛ базой**; строка «первый
замер равенства» внесена в `reference/code/cf-facts/MANIFEST.md`. Побочно (не входит в критерий
приёмки, но полезно для доверия к прежней документации): 9 из 10 файлов прежнего снапшота совпали
побайтово со свежим съёмом; десятый файл (`deploy_and_workflow.sh`) в прежнем снапшоте отсутствовал
вовсе — он не был утерян, а не был снят обходным методом.

## 3. Гигиена архива (`ADR-040`)

**`cf-facts` — архив несёт 17 записей, 10 вошли в seed, 7 исключены:**

| Исключённый файл | Причина |
|---|---|
| `.DS_Store` | macOS filesystem-мусор |
| `fetch_demands.py.bak` | резервная копия |
| `fetch_purchases.py.bak` | резервная копия |
| `fetch_returns.py.bak` | резервная копия |
| `patch_code.py` | разовый patch-скрипт, правящий `fetch_purchases.py`/`bq_ops.py` на месте (добавление `order_name`) |
| `patch_timeout.py` | разовый patch-скрипт, правящий `timeout=30→90` в `helpers.py` на месте |
| `src.zip` | самореференциальный вложенный архив-остаток упаковки (11 файлов), не исполняется рантаймом |

**`cf-dq` — архив несёт 8 записей, 5 вошли в seed, 3 исключены** (без изменений против прежнего
снапшота): `src.zip`, `function-source.zip`, `function-source-patched.zip` — три вложенных
самореференциальных архива, та же аномалия, что уже задокументирована.

**`patch_dq.py` — решение о включении, явно.** В отличие от двух разовых скриптов `cf-facts`,
`patch_dq.py` **включён в seed `cf-dq`**: это не мусор, а документированный провенанс уже
применённого T-1-фикса `check_drift` (`reference/dq_source_capture_2026-08-02.md §6`) — патч,
переписывающий функцию, идентичен телу, реально задеплоенному в `main.py` (посимвольное сравнение),
и датирован тем же днём, что создание текущей ревизии. Для `patch_code.py`/`patch_timeout.py`
`cf-facts` такого документированного статуса нет — они неотличимы от разовых рабочих скриптов,
поэтому исключены по правилу по умолчанию (`ADR-040`).

## 4. sha256 всех включённых в seed файлов

**`cf-facts` (10 файлов):**

| Файл | sha256 |
|---|---|
| `main.py` | `2b1e4519523dbe0e78520b035f5c047b18e4f348730c98de19dbe54c8b9e4da5` |
| `bq_ops.py` | `dad48a6eec2d80b5a3373beb5463cdd3d94ac71cef481d89f389e8a2308dc4e3` |
| `config.py` | `977fd82813d3487a1eb9c8cd297312d6e542be3b45fe65b45d73cc143ca3289b` |
| `fetch_byvariant.py` | `88e1a13881103e0faa5ec21a5a07ddd2fc83e9cc9eb4fb9fe67a0da25fb60ff1` |
| `fetch_demands.py` | `637f25dba1a87a412bde7feac32a0b56a052e99c9bb8a5246e13b266b7648770` |
| `fetch_purchases.py` | `5db807fee2da21c31c5fa3aeed77e16d1a4ae04193f55831534b89c5e9158486` |
| `fetch_returns.py` | `7ce9373aa084258e45d2ba12c8f1bc2812b249958eec400c4181e4802793ae56` |
| `helpers.py` | `aac5dee5add76513f52e8909a32925f261ad25d09ef55a1a6013f5262cd01c48` |
| `requirements.txt` | `0c041a8d50f4731ad71aabcf678f388c13d8ba9af6ccb6548af9ccb6fc514051` |
| `deploy_and_workflow.sh` | `2e9391517c772a03a22f6751135888796778ea0889e15f97d63ba9bafcab9d07` |

**`cf-dq` (5 файлов):**

| Файл | sha256 |
|---|---|
| `main.py` | `9693010ae04cd14859b7ed53bba25fa28cbf1962a9b127c012a75d521d86ea09` |
| `helpers.py` | `0f335877c29d9c18c5e8d9617ab38768c6d2ba01986d178abaff92d4ce9dd146` |
| `config.py` | `7a818364c78fdf21cb32d8ce52d54da0972a6de511d1f6023fb8ea812fc543b6` |
| `requirements.txt` | `587133daa6a4c31e57bfd84c371ea4d6e0831e69ed66babf12c15dbebfd6b516` |
| `patch_dq.py` | `bb1bc968b81573431c5f7c912539918d51d1ee18cd34b040a109ccf213eeb22a` |

Полные MANIFEST'ы с полным разбором — `reference/code/cf-facts/MANIFEST.md`,
`reference/code/cf-dq/MANIFEST.md` (переподтверждён этой сессией).

## 5. Форма раскладки — выбрана и обоснована

**Выбрано: все три функции переносятся под каталоги одного уровня `cf-finance/`, `cf-facts/`,
`cf-dq/`**, включая три существующих файла `cf-finance` (были в корне, перенесены `git mv`).

**Обоснование.** Оставить `cf-finance` в корне, а новые функции добавить подкаталогами дало бы
несогласованную структуру (одна функция особая, две — обычные), не масштабируемую на residual `Q-3`
(`cf-dim`, `cf-fx`, `cf-inventory`, `cf-alert`, `cf-loss-commission` — тот же паттерн later). Единая
конвенция «каталог = имя CF» читается однозначно при добавлении новых функций и не требует решения
каждый раз заново. Цена — `git mv` двух файлов `cf-finance` тем же коммитом; история их содержимого
сохранена (`git log --follow` видит переименование, `git show --stat` показывает `rename … (100%)`).

`.gitignore` расширен (не переписан) тремя новыми паттернами (`patch_code.py`, `patch_timeout.py`,
`.DS_Store`) плюс `src.zip`, поверх уже существовавших `*.bak`, `__pycache__/`, `patch_main_finance.py`,
`function-source.zip`, `archive/`.

## 6. Локальный коммит

**SHA:** `81812f4d06fccb5ea0500b565269b07755831fb0`
**Сообщение:** `Seed cf-facts from deployed revision cf-facts-00007-xir (generation 1782334223015697); seed cf-dq from deployed revision cf-dq-00007-hot (generation 1781780276907576); move cf-finance under cf-finance/ for per-CF layout consistency`
**Родитель:** `4317047333d6311d7439e8e7215de3b3638a4ddd` (исходный seed-коммит `cf-finance`) — та же
история, не новая; `git log --oneline --all` в клоне подтверждает.
**Расположение клона:** `/private/tmp/claude-501/-Users-ilyasbazarov-Desktop-msklad-project-holika-worktrees-CODE-REPO-SEED-REST/2a94fffd-5c3e-4cd7-8aa8-b87d44627363/scratchpad/holika-prod` (сессионный scratchpad, НЕ внутри репо `holika`).
`git status` клона на момент коммита — чист (`nothing to commit, working tree clean`).

18 файлов изменено, 2112 добавлений: 10 файлов `cf-facts/`, 5 файлов `cf-dq/`, `.gitignore`,
2 переименования `cf-finance/`.

## 7. Ни одного push, деплоя или записи в живые таблицы

Ни разу не вызывались: `git push`, `gcloud functions deploy`, `bq query` (кроме read-only, не
исполнялся вовсе — задача не требовала BQ), любая запись в `marts.*`/`core.*`. Единственные команды
записи — локальные файловые операции (`cp`, `git mv`, `git commit`) в клоне вне `holika`.

## 8. Команда `push` для владельца

```bash
cd "/private/tmp/claude-501/-Users-ilyasbazarov-Desktop-msklad-project-holika-worktrees-CODE-REPO-SEED-REST/2a94fffd-5c3e-4cd7-8aa8-b87d44627363/scratchpad/holika-prod" && git push origin master
```

**Внимание владельцу (не решается этой сессией, `CODE-REPO-VISIBILITY`, `07_GAPS.md`):** репозиторий
`holika-prod` сейчас публичный (`isPrivate: false`), хотя `ADR-109 §7` фиксировал решение «приватный».
Секретов-значений в коде нет (читаются из Secret Manager по имени), но публично станут видны
идентификатор проекта GCP, адреса служебных аккаунтов, имена бакетов/датасетов, имя секрета
`msklad-token` и логика загрузчиков `cf-facts`/`cf-dq`. Решение о видимости — прежнее, этим `push`
не меняется и не создаётся заново.

Клон в scratchpad — временный (сессионный каталог); после `push` его можно удалить, провенанс
коммита сохранён в этом артефакте и в `reference/code/*/MANIFEST.md`.
