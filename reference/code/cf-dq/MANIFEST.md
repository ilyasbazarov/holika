# MANIFEST · /reference/code/cf-dq/ — снапшот исходника (DQ-SOURCE-CAPTURE)

**Тип:** discovery-снапшот (`_METHOD §11`), не оракул, не прод-код.
**Источник:** прямое снятие через `gcloud functions describe` + `gsutil cp` задеплоенного архива (не обходной путь — `describe` отработал без `403`).
**Дата снятия (UTC):** `2026-08-02T15:01:49Z…15:02:00Z` (`step1_run.log`).
**Скрипт:** `reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02/step1_capture_source.sh`, лог `step1_run.log`.

---

## Ревизия и провенанс (`gcloud functions describe cf-dq --gen2 --region=asia-east1 --project=msklad-bi-prod`)

| Поле | Значение |
|---|---|
| `serviceConfig.revision` | `cf-dq-00007-hot` (совпадает с `11_INFRA_FACTS §CF`) |
| `buildConfig.entryPoint` | `main` |
| `buildConfig.runtime` | `python312` |
| `buildConfig.source.storageSource` | `gs://gcf-v2-sources-420804682491-asia-east1/cf-dq/function-source.zip` (generation `1781780276907576`) |
| `updateTime` (сервиса) | `2026-07-30T10:04:58.501779835Z` (метаданная-правка массовой сессии того дня, не передеплой кода — тот же вывод, что уже зафиксирован `11_INFRA_FACTS.md:76`) |
| `state` | `ACTIVE` |

Ревизия `cf-dq-00007-hot` создана `2026-06-18T10:59:31Z` (`11_INFRA_FACTS.md §cf-dq`, история ревизий не переснималась этой сессией — уже зафиксирована).

## Состав задеплоенного архива

Распакованный `function-source.zip` несёт 8 записей, из них 5 — исполняемые модули функции, 3 — **вложенные архивы** (см. раздел «Известная аномалия» ниже):

| Файл | sha256 | Роль |
|---|---|---|
| `main.py` | `9693010ae04cd14859b7ed53bba25fa28cbf1962a9b127c012a75d521d86ea09` | Точка входа (`entryPoint=main`), 6 DQ-чеков |
| `helpers.py` | `0f335877c29d9c18c5e8d9617ab38768c6d2ba01986d178abaff92d4ce9dd146` | BQ-клиент, `run_scalar`/`run_row`, запись в `audit.dq_runs` |
| `config.py` | `7a818364c78fdf21cb32d8ce52d54da0972a6de511d1f6023fb8ea812fc543b6` | Константы: пороги, имена датасетов/таблиц, секреты |
| `requirements.txt` | `587133daa6a4c31e57bfd84c371ea4d6e0831e69ed66babf12c15dbebfd6b516` | Зависимости |
| `patch_dq.py` | `bb1bc968b81573431c5f7c912539918d51d1ee18cd34b040a109ccf213eeb22a` | Патч-скрипт, применённый к `main.py` (см. ниже) |

sha256 всех пяти файлов посчитан напрямую с диска (`shasum -a 256`), не транскрипцией — расхождение класса `E1-T3-D-CFSRC` (`patch_main_finance.py`, `07_STATE`) здесь структурно исключено.

## Известная аномалия архива (не факт о логике функции)

Архив несёт три вложенных ZIP-файла: `src.zip` (`2026-06-18T10:55`), `function-source.zip` (`2026-05-26T09:53`),
`function-source-patched.zip` (`2026-05-26T09:54`) — **самореференциальные остатки предыдущей упаковки**,
тот же класс мусора в задеплоенном архиве, что `main.py.bak` у `cf-finance` (`ADR-040`, `07_STATE` E1-T3-D-CFSRC).
Их `main.py` (идентичен во всех трёх, sha256 `b3c6f6c…c99d`) несёт **дозфиксовую** версию `check_drift`
(T-0/`max_d`/`today_rev`, без комментария «Изменено на T-1»), датирован `2026-05-26` — совпадает с ревизией
`cf-dq-00006-lac` (`2026-05-26T09:56:13Z`). Не влияет на исполняемый код: `entryPoint=main` резолвится в
топоуровневый `main.py` архива, вложенные zip Python-раннтаймом не исполняются. Оставлены как найдены,
не удалены (`ADR-043`), лежат в `reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02/source_unzipped/`.

## Патч, применённый к текущей ревизии

`patch_dq.py` — скрипт, переписывающий функцию `check_drift` в `main.py` целиком (посимвольное сравнение
текста `new_func` внутри `patch_dq.py` с телом `check_drift` в задеплоенном `main.py` — идентичны). `mtime`
`main.py` и `patch_dq.py` в архиве совпадают (`2026-06-18 10:57`), тот же день, что создание ревизии
`cf-dq-00007-hot` (`10:59:31Z`) — патч применён и упакован непосредственно перед этим деплоем. Разбор — в
основном артефакте `reference/dq_source_capture_2026-08-02.md §3`.

## Итог по критерию приёмки

Снята вся точка входа (`main.py`) и её прямые зависимости (`helpers.py`, `config.py`, `requirements.txt`)
плюс патч-скрипт (`patch_dq.py`), задокументированный отдельно. sha256 — прямой с диска, не транскрипция.
Способ снятия — **прямой** (`gcloud functions describe` без `403`), обходной путь не понадобился.

## Переподтверждение (`CODE-REPO-SEED-REST`, 2026-08-02T20:50:05Z)

Свежий съём тем же прямым методом (`gcloud functions describe cf-dq --gen2` →
`gcloud storage cp <storageSource>#<generation>`), лог —
`reference/_scratch_CODE-REPO-SEED-REST_2026-08-03/step1_run.log`. Ревизия и generation те же
(`cf-dq-00007-hot`, `1781780276907576`). Все 5 sha256 из таблицы выше **совпали побайтово** со свежим
съёмом — снапшот подтверждён, файлы не переписывались:

| Файл | sha256 (свежий съём) | Совпало |
|---|---|---|
| `main.py` | `9693010ae04cd14859b7ed53bba25fa28cbf1962a9b127c012a75d521d86ea09` | да |
| `helpers.py` | `0f335877c29d9c18c5e8d9617ab38768c6d2ba01986d178abaff92d4ce9dd146` | да |
| `config.py` | `7a818364c78fdf21cb32d8ce52d54da0972a6de511d1f6023fb8ea812fc543b6` | да |
| `requirements.txt` | `587133daa6a4c31e57bfd84c371ea4d6e0831e69ed66babf12c15dbebfd6b516` | да |
| `patch_dq.py` | `bb1bc968b81573431c5f7c912539918d51d1ee18cd34b040a109ccf213eeb22a` | да |

Три вложенных самореференциальных архива (`src.zip`, `function-source.zip`, `function-source-patched.zip`,
раздел «Известная аномалия» выше) присутствуют в архиве без изменений — не входят в seed этой сессией
по той же причине, что и раньше.

## Деплой `DQ-GATE-FAIL-OPEN-FIX` (2026-08-10, мандат `ADR-152`)

**Новая ревизия:** `cf-dq-00008-cev`, `updateTime=2026-08-10T14:42:35.892464988Z`, `state=ACTIVE`.
**Источник:** `gs://gcf-v2-sources-420804682491-asia-east1/cf-dq/function-source.zip`
(generation `1786372858921485`), деплой из ветки код-репо `holika-prod`
`deploy/cf-dq-2026-08-10-fail-open` (коммит `71e42669ab7cdefb788a9a8ff3c87ad87b411893`), каталог
`--source=cf-dq/`. Скрипты — `reference/_scratch_DQ-GATE-FAIL-OPEN-FIX_2026-08-10/deploy/`
(`step1_predusloviya.sh`, `step2_deploy.sh`, `step3_readback.sh`), логи там же.

**Предусловия (`ADR-152 §6`) — оба закрыты ДО правки ветки:**
- (i) Живая ревизия `cf-dq-00007-hot` сверена с `master` код-репо ДО деплоя — дрейфа не найдено, sha256
  всех пяти файлов побайтово совпали с таблицей выше и с `master` (`step1_run.log`).
- (ii) `.gcloudignore` в `holika-prod` для `cf-dq/` **отсутствовал вообще** (ни в корне, ни в
  каталоге функции) — гэп, закрытый этим деплоем: создан `cf-dq/.gcloudignore` по прецеденту формы
  `cf-facts/.gcloudignore`, исключает как минимум `patch_*.py`, `*.bak`, `__pycache__/`, `*.pyc`,
  `.DS_Store`, `src.zip`, `function-source*.zip`.

**Объём (`ADR-152 §2/§3`):** только `cf-dq/main.py` (диапазон — тело `if ma7 == 0:` функции
`check_drift`) плюс новый `cf-dq/.gcloudignore`. `config.py`/`helpers.py`/`requirements.txt` —
байт-в-байт как `master` (не менялись). Заготовка `DQ-FRESHNESS-COVERAGE` (снапшот `holika`,
`main.py:18-24`/`139-300` + `config.py:20-49`) в ветку деплоя НЕ перенесена — в код-репо её нет и
после этого деплоя по-прежнему нет.

**Read-back (`ADR-152 §5`, условие 1 из 3 — выполнено):** sha256 `main.py`/`config.py`/`helpers.py`/
`requirements.txt` нового архива побайтово совпадают с веткой деплоя (`step3_run.log`). Состав
архива — впервые для `cf-dq` ЧИСТЫЙ: 4 исполняемых файла + `.gcloudignore`, `patch_dq.py` и три
вложенных самореференциальных архива (`src.zip`, `function-source.zip`, `function-source-patched.zip`)
в новом архиве отсутствуют — ожидаемое следствие нового `.gcloudignore`, аномалия прежних ревизий
закрыта попутно.

| Файл | sha256 (новый архив = ветка деплоя) |
|---|---|
| `main.py` | `0e910907af0e4cb0a84ea43b5660b6e66d62932f9f5e059343f6e5e7c74e2d0b` |
| `config.py` | `7a818364c78fdf21cb32d8ce52d54da0972a6de511d1f6023fb8ea812fc543b6` (не менялся) |
| `helpers.py` | `0f335877c29d9c18c5e8d9617ab38768c6d2ba01986d178abaff92d4ce9dd146` (не менялся) |
| `requirements.txt` | `587133daa6a4c31e57bfd84c371ea4d6e0831e69ed66babf12c15dbebfd6b516` (не менялся) |

**Условия 2 (функциональная проверка на первом плановом часовом прогоне) и 3 (регрессия остальных
пяти чеков в `audit.dq_runs`) — PENDING**, наступают на прогоне `msklad-pipeline-hourly`
(`0 * * * *`) после `2026-08-10T14:42:35Z`. Не синтезируются заранее (`ADR-152 §5`, прецедент
`reference/dq_gate_scope_split_deploy_2026-08-05.md §7`).

**Слияние ветки в `master` код-репо — ИСПОЛНЕНО** (владелец подтвердил отдельным сообщением
«Да, сливай»). `deploy/cf-dq-2026-08-10-fail-open` (`71e4266`) слита в `master` merge-коммитом
`5ad9544ce65c72278c6d02a8b16f727cc8ffa4e8` (не fast-forward, `--no-ff`), отправлено
`git push origin master`. Инвариант «основная ветка = то, что стоит в проде» восстановлен: `master`
несёт ровно `cf-dq/main.py` (хунк `ma7`) + новый `cf-dq/.gcloudignore`, идентичные деплою
`cf-dq-00008-cev`.
