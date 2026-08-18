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

**Условия 2 и 3 — ПОДТВЕРЖДЕНЫ первым плановым часовым прогоном** (`run_id=1786374002.7999175`,
`checked_at=2026-08-10 15:05:55 UTC`, скрипт `step4_verify_hourly.sh`, лог `step4_run.log`).
Условие 2 (функциональность): `drift_check` вернул формат `ratio=…, threshold=…`
(`yesterday_rev=756397, ma7=5459004, ratio=0.14, threshold=0.03 (weekend), target_date=2026-08-09`)
— `ma7 ≠ 0`, новая ветка на здоровых данных не исполнялась, что и ожидалось; функция и импорт
модуля работоспособны. Условие 3 (регрессия): в том же `run_id` все шесть записей
(`not_empty`/`drift_check`/`fk_integrity`/`freshness`/`margin_sanity`/`currency_normalization`)
несут `passed=true`. **Приёмка `ADR-152 §5` закрыта полностью, деплой `DQ-GATE-FAIL-OPEN-FIX`
считается завершённым и подтверждённым.**

**Слияние ветки в `master` код-репо — ИСПОЛНЕНО** (владелец подтвердил отдельным сообщением
«Да, сливай»). `deploy/cf-dq-2026-08-10-fail-open` (`71e4266`) слита в `master` merge-коммитом
`5ad9544ce65c72278c6d02a8b16f727cc8ffa4e8` (не fast-forward, `--no-ff`), отправлено
`git push origin master`. Инвариант «основная ветка = то, что стоит в проде» восстановлен: `master`
несёт ровно `cf-dq/main.py` (хунк `ma7`) + новый `cf-dq/.gcloudignore`, идентичные деплою
`cf-dq-00008-cev`.

## Деплой `DQ-CFDQ-DEPLOY` (2026-08-12, мандат `ADR-173 §5`)

**Предусловия П1/П2 — read-only, ДО деплоя.** Обслуживающая ревизия снята через
`gcloud run services describe cf-dq --format="yaml(status.traffic)"` (НЕ через `functions
describe` — прецедент подмены `…deploy_final_adj…§2`): `status.traffic` вернул
`revisionName=cf-dq-00008-cev, percent=100, latestRevision=true` — обслуживающая ревизия
совпадает с последней, подмены нет. Эта ревизия — откатная (§2 ниже). Дрейф: архив
`cf-dq-00008-cev` (generation `1786372858921485`) скачан и сверен побайтово с `master`
код-репо `holika-prod` — все четыре файла (`main.py`/`config.py`/`helpers.py`/
`requirements.txt`) `IDENTICAL`, дрейфа нет. Скрипты/логи —
`reference/_scratch_DQ-CFDQ-DEPLOY_2026-08-13/step1_live_revision_and_drift.sh`+`step1_run.log`,
`step2_drift_check.sh`+`step2_run.log`.

**Объём (П1, `git diff --stat master`):** ровно два файла — `cf-dq/main.py`, `cf-dq/config.py`.
Патч перенесён из `reference/code/cf-dq/{main.py,config.py}` (снапшот, прошедший ревью в три
захода, `ADR-173`) поверх ветки `deploy/cf-dq-2026-08-12-drift-and-freshness` от `master`
(коммит-основание `5ad9544`). `.gcloudignore` (`cf-dq/.gcloudignore`, заведён прошлым деплоем)
уже исключает `patch_*.py`/`*.bak`/`__pycache__/`/`*.pyc`/`.DS_Store`/`src.zip`/
`function-source*.zip` — проверен, правки не потребовалось. Сплошной поиск секретов по диффу
(`grep -inE "secret|token|password|api[_-]?key|bearer|AIza|ya29\.|-----BEGIN"`) — пусто, печатается
явно (не как факт по умолчанию).

**Коммит в ветку:** `c9b967ffcae01ceeae3b6fd0e6e2cba0549ed738`, ветка выложена в `origin`
(владелец подтвердил push). Деплой — `gcloud functions deploy cf-dq --gen2
--runtime=python312 --region=asia-east1 --source=cf-dq/ --entry-point=main --trigger-http
--service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com --memory=512Mi --cpu=0.3333
--timeout=120s --min-instances=1 --max-instances=6 --concurrency=1 --ingress-settings=all
--set-env-vars=LOG_EXECUTION_ID=true --set-secrets=MSKLAD_TOKEN=msklad-token:latest` —
параметры сняты с живой конфигурации ДО деплоя (`live_config_before_deploy.yaml`), не
изобретены. Владелец подтвердил деплой отдельным ответом («Да, деплоить») на объявление
действия (объект/откат) — `ADR-077 §6`. Скрипт/лог —
`reference/_scratch_DQ-CFDQ-DEPLOY_2026-08-13/step5_deploy.sh`+`step5_run.log`;
`date -u`/`gcloud auth list` в начале и в конце — авторизация не деградировала.

**Новая ревизия:** `cf-dq-00009-coy`, `updateTime=2026-08-12T19:14:47.725221603Z`, `state=ACTIVE`.
**Источник:** `gs://gcf-v2-sources-420804682491-asia-east1/cf-dq/function-source.zip`
(generation `1786561996565446`), деплой из ветки `deploy/cf-dq-2026-08-12-drift-and-freshness`
(коммит `c9b967f`), `--source=cf-dq/`.

**Read-back (условие 1 из 3 — выполнено).** `status.traffic` после деплоя —
`revisionName=cf-dq-00009-coy, percent=100`. Архив новой ревизии скачан и распакован: ровно
4 исполняемых файла (`main.py`/`config.py`/`helpers.py`/`requirements.txt`), мусора нет.
sha256 всех четырёх файлов побайтово совпадают с веткой деплоя (`IDENTICAL` по всем).

| Файл | sha256 (новый архив = ветка деплоя) |
|---|---|
| `main.py` | `477c216ceaa3623a2f254129673413e9697b50bcd263c2451bd0334eb5486e67` |
| `config.py` | `360d0a195abc0bc53ad8bb59ce292bf6b7045486169fcc466dd4d6636ff0a756` |
| `helpers.py` | `0f335877c29d9c18c5e8d9617ab38768c6d2ba01986d178abaff92d4ce9dd146` (не менялся) |
| `requirements.txt` | `587133daa6a4c31e57bfd84c371ea4d6e0831e69ed66babf12c15dbebfd6b516` (не менялся) |

Скрипт/лог read-back — `reference/_scratch_DQ-CFDQ-DEPLOY_2026-08-13/step6_readback.sh`+
`step6_run.log`.

**Условия 2 и 3 — ПОДТВЕРЖДЕНЫ первым естественным часовым прогоном** (`run_id=1786564802.7168841`,
`checked_at=2026-08-12 20:04:52 UTC`, запрос —
`reference/_scratch_DQ-CFDQ-DEPLOY_2026-08-13/step8_first_natural_run_compare.log`).
Условие 2 (запись несёт оба исхода метрики `drift_check`): семь строк вместо шести —
`drift_check` (`passed=true`, `yesterday_rev=4240470, ma7=4453347, ratio=0.95, threshold=0.1
(weekday), target_date=2026-08-12`) и новая `drift_zero_docs` (`passed=true`, тот же
`target_date`, `notify, не блокирует promote`) — обе присутствуют в одной записи. Условие 3
(регрессия остальных пяти проверок): `not_empty`/`fk_integrity`/`freshness`/`margin_sanity`/
`currency_normalization` побайтово идентичны прошлому прогону
(`run_id=1786561202.3581266`, `checked_at=2026-08-12 19:02:14 UTC`, ДО деплоя) — совпадают и
`passed`, и `detail` по каждой из пяти. **Приёмка `ADR-173 §5` закрыта полностью, деплой
`DQ-CFDQ-DEPLOY` считается завершённым и подтверждённым.**

**Откатная ревизия (П2):** `cf-dq-00008-cev` — откат командой
`gcloud run services update-traffic cf-dq --region=asia-east1 --project=msklad-bi-prod
--to-revisions=cf-dq-00008-cev=100`, пересборка не требуется. Не потребовался — деплой успешен.

**Слияние ветки в `master` код-репо — ИСПОЛНЕНО** (владелец подтвердил отдельным сообщением
«Да, отправить»). `deploy/cf-dq-2026-08-12-drift-and-freshness` (`c9b967f`) слита в `master`
merge-коммитом `9a08b5aa2522eb0340c5568e8763ff90255d3ec8` (не fast-forward, `--no-ff`),
отправлено `git push origin master` (`5ad9544..9a08b5a`). Инвариант «основная ветка = то, что
стоит в проде» восстановлен: `master` несёт ровно `cf-dq/main.py`+`cf-dq/config.py`
(переделка `drift_check` + две проверки свежести), идентичные деплою `cf-dq-00009-coy`.

## Попытка деплоя `DQ-FRESHNESS-WIRE-DEPLOY` (2026-08-18) — НЕУСПЕХ, ветка не слита

**Предусловия П1-П4 — все закрыты чисто ДО деплоя.** П1: ветка `s/DQ-FRESHNESS-WIRE-GUARD-FIX`
слита в `main` холики (`330e42b`). П2: обслуживающая ревизия снята `status.traffic` —
`cf-dq-00009-coy, percent=100` — совпадает с откатной. П3: архив `cf-dq-00009-coy`
(`generation=1786561996565446`) скачан и сверен побайтово с `master` код-репо — все четыре
файла `IDENTICAL`, дрейфа нет. П4: ветка `deploy/cf-dq-2026-08-18-freshness-wire` от `master`
(коммит-основание `9a08b5a`), `git diff --stat master` — ровно один файл `cf-dq/main.py`
(`214 insertions, 125 deletions`). `.gcloudignore` присутствует и содержит нужные исключения;
сплошной поиск секретов по диффу — пусто. Коммит патча `2a3228d`, ветка выложена в `origin`
(владелец подтвердил «Да, push и деплоить»). Скрипты/логи —
`reference/_scratch_DQ-FRESHNESS-WIRE-DEPLOY_2026-08-18/step1_run.log`,
`step2_run.log`, `step3_push_run.log`.

**Деплой упал на healthcheck.** Команда та же, что в `DQ-CFDQ-DEPLOY` (параметры сняты с живой
конфигурации ДО деплоя, `step4_live_config_before_deploy.log`). Новая ревизия
**`cf-dq-00010-kiq`** не прошла startup-проверку: «The user-provided container failed to start
and listen on the port… within the allocated timeout». Лог/скрипт —
`reference/_scratch_DQ-FRESHNESS-WIRE-DEPLOY_2026-08-18/step5_deploy_run.log`.

**Read-only диагностика после срыва (запрет слепого retry соблюдён).**
`reference/_scratch_DQ-FRESHNESS-WIRE-DEPLOY_2026-08-18/step6_diagnose_run.log`:
`status.traffic` после срыва — `cf-dq-00009-coy, percent=100` (объект не задет, откат не
потребовался — Cloud Run gen2 не переключает трафик на ревизию, не прошедшую healthcheck).
Логи ревизии `cf-dq-00010-kiq` дают точную причину — `NameError` при импорте модуля:

```
File "/workspace/main.py", line 223, in <module>
    ("freshness_purchases_technical",         check_freshness_purchases_technical),
NameError: name 'check_freshness_purchases_technical' is not defined
```

**Корень — порядок определений в самом ревьюнутом снапшоте, не артефакт переноса патча.**
`reference/code/cf-dq/main.py`: `CHECKS = [...]` (строки `215-235`) ссылается на все
двенадцать функций `check_freshness_*_technical`/`_business`, которые определены НИЖЕ по
файлу (первая — `check_freshness_purchases_technical` на строке `270`). Python исполняет
модуль сверху вниз; на строке присвоения `CHECKS` эти имена ещё не существуют — `NameError`
на любом импорте, включая локальный. **Ни `DQ-FRESHNESS-WIRE-DEPLOY-REVIEW`
(`reference/dq_freshness_wire_deploy_review_2026-08-17.md`), ни `GUARD-FIXES-REVIEW`
(`reference/guard_fixes_review_2026-08-17.md`) дефект не поймали** — оба ревью проверяли
наличие `try/except` текстовым разбором каждой функции, но ни разу не пытались реально
импортировать модуль (`python3 -c "import main"` или эквивалент). Класс ошибки — тот же, что
`★ Успех инструмента ≠ факт`/`ADR-044`: вывод о работоспособности сделан по образцу и
текстовому совпадению, не по факту исполнения.

**Итог по процедуре (`05_CONVENTIONS §Процедура деплоя` п.8):** ветка
`deploy/cf-dq-2026-08-18-freshness-wire` (коммит `2a3228d`, запушена в `origin`) **НЕ слита**
в `master`. `master` код-репо остаётся неизменным с прошлого деплоя (`9a08b5a`) — инвариант
«основная ветка = то, что стоит в проде» не нарушен: прод как был на `cf-dq-00009-coy`, так и
остался, и `master` этой ревизии соответствует. Мандат класса B на этот объект патча
**исчерпан неуспешной попыткой**; дальнейшее — правка `CHECKS` (перенос списка ПОСЛЕ
определений функций, класс A) с повторным ревью, затем новый деплой-заход.

---

## Деплой `cf-dq` — DQ-FRESHNESS-WIRE, второй заход (`2026-08-18`)

**Мандат:** класс B, выдан заново поимённо архитектором (ревью
`reference/review_request_dq_checks_order_2026-08-18.md`), подтверждён владельцем явным «да» в
чате. Объект — деплой `cf-dq` одним файлом `main.py` из НОВОЙ ветки код-репо
`deploy/cf-dq-2026-08-18-freshness-wire-v2`.

**Прод-коммит определён замером, не именем `master` (`ADR-190 §3`).** Обслуживающая ревизия на
момент старта — `cf-dq-00009-coy` (`status.traffic`, `percent=100`); ревизия
`serviceConfig.revision=cf-dq-00010-kiq` из `functions describe` — это ПОСЛЕДНИЙ СОБРАННЫЙ
билд (неудачная попытка `2026-08-18`, healthcheck fail), НЕ обслуживающая ревизия — расхождение
между «последний билд» и «то, что реально отдаёт трафик» ожидаемо после проваленного
деплоя и подтверждено `gcloud run revisions describe` по обеим ревизиям. Архив, реально
использованный сборкой `cf-dq-00009-coy` (`sourceStorage` generation `1786561996565446`,
`creation_time=2026-08-12T19:13:16Z`, соответствует `metadata.creationTimestamp` ревизии
`2026-08-12T19:14:36Z`), скачан и просеян по истории `cf-dq/main.py` в код-репо: sha256
`main.py` (`477c216c…86e67`) совпадает **только** с коммитом
`c9b967ffcae01ceeae3b6fd0e6e2cba0549ed738` («cf-dq: переделка метрики drift_check
+ две проверки свежести», `DQ-CFDQ-DEPLOY`, `2026-08-13`). Все четыре файла архива (`main.py`,
`config.py`, `helpers.py`, `requirements.txt`) сверены с этим коммитом побайтово — `ALL_MATCH=1`
(`step6_run.log`). `git merge-base --is-ancestor c9b967f origin/master` — истина, коммитов между
прод-коммитом и `master`, трогающих `cf-dq/`, нет: `master` и прод-коммит эквивалентны для этой
функции на момент замера (дрейфа нет).

**Патч.** Прод-коммит несёт СТАРУЮ форму `CHECKS` (7 пар, без подключения свежести) — сама
подготовка `DQ-FRESHNESS-WIRE`/`DQ-FRESHNESS-WIRE-GUARD-FIX` в прод ещё не доехала (обе неудачные
попытки `2026-08-18` трафика не получили). Содержание патча дословно равно содержанию
неудачной первой попытки (`origin/deploy/cf-dq-2026-08-18-freshness-wire`, коммит `2a3228d`):
diff между веткой первой попытки и файлом `reference/code/cf-dq/main.py` (уже исправленным
сессией `DQ-FRESHNESS-WIRE-CHECKS-ORDER`) показывает РОВНО перемещение блока `CHECKS`, ни одна
строка внутри блока и ни одна функция не изменены (`step8_run.log`). `cf-dq/main.py` ветки
деплоя заменён целиком на этот проверенный файл.

**П5.** `git diff --stat` против прод-коммита — ровно один файл, `cf-dq/main.py` (`step9_run.log`).
Поиск секретов по диффу (`bearer|msklad-token|api[_-]?key|secret|password|-----BEGIN`) —
0 совпадений (`step10_run.log`).

**П6.** `.gcloudignore` ветки уже несёт `*.bak`, `__pycache__/`, `*.pyc`, `patch_*.py` — не
правился, проверен как есть (`step7_run.log`).

**П7 — факт-проверка исполнением на содержимом ВЕТКИ ДЕПЛОЯ.** Импорт `main` из
`holika-prod/cf-dq/` (не снапшот `reference/code/`), `python 3.14.6` (Homebrew; системный
`python3.9.6` машины не тянет `dict | None`, см. `07_STATE.md §Подробности для модели`) —
`rc=0`, `len(CHECKS)=19` (`step11_run.log`).

**Деплой исполнен** (`step13_run.log`): новая ревизия **`cf-dq-00011-tij`**, generation
`1787008025864914`. Healthcheck пройден (в отличие от `cf-dq-00010-kiq`) — Cloud Build/Run
завершились без предупреждений о старте контейнера, единственное предупреждение —
информационное «A new revision will be deployed serving with 100% traffic». Трафик переведён:
`{'latestRevision': True, 'percent': 100, 'revisionName': 'cf-dq-00011-tij'}`.

Флаги деплоя сняты с живой конфигурации до правки (`step12_run.log`), не угадывались:
`--memory=512Mi --timeout=120s --min-instances=1 --max-instances=6 --concurrency=1
--service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com --ingress-settings=all
--set-env-vars=LOG_EXECUTION_ID=true --set-secrets=MSKLAD_TOKEN=msklad-token:latest
--no-allow-unauthenticated` (IAM-политика инвокера — без `allUsers`, приватный доступ подтверждён
`step12_run.log`).

**Read-back (пункт приёмки 1).** Архив новой ревизии (generation `1787008025864914`) скачан и
сверен побайтово с веткой деплоя — `ALL_MATCH=1` по всем четырём файлам (`config.py`,
`helpers.py`, `main.py`, `requirements.txt`); `patch_dq.py` в архиве легитимно отсутствует
(исключён `.gcloudignore`) (`step14_run.log`).

**Пункт приёмки 2.** `status.traffic` сразу после деплоя —
`{'latestRevision': True, 'percent': 100, 'revisionName': 'cf-dq-00011-tij'}` (`step14_run.log`).

**Пункты приёмки 3–5 (обязательны, не заменяются фактом выкладки) — ЗАКРЫТЫ.** Последний
часовой прогон ПЕРЕД деплоем — `run_id=1787007602.5744402`, `checked_at=2026-08-17 23:05:16
UTC`, `7` проверок (старый код). Первый естественный прогон ПОСЛЕ деплоя —
`run_id=1787011202.5458951`, `checked_at=2026-08-18 00:04:48 UTC` (фоновый опрос сессии не
сохранил уведомление из-за перезапуска инструмента между `23:48 UTC` и `04:14 UTC`; факт снят
прямым запросом `audit.dq_runs` по возобновлении, обнаружено ещё четыре последующих часовых
прогона `01:05`/`02:05`/`03:05`/`04:05 UTC`, тоже по `19` проверок — регресса нет) (`step17_run.log`).

- **Пункт 3.** Прогон `00:04:48 UTC` несёт РОВНО `19` именованных проверок; все двенадцать
  `freshness_*` присутствуют поимённо (`freshness_{purchases,returns,inventory,payments,
  commissionreportin,invoices}_{technical,business}`).
- **Пункт 4.** Шесть блокирующих проверок (`not_empty`, `drift_check`, `drift_zero_docs`,
  `fk_integrity`, `freshness`, `currency_normalization`) — все `passed=true`.
- **Пункт 5.** Ни одна из двенадцати `freshness_*` не несёт `passed=false`; контрольный запрос
  `COUNT(*) WHERE run_id=… AND passed=false` по всему прогону — `0`.

**Приёмка деплоя `cf-dq-00011-tij` полна по всем пяти пунктам.** Ветка код-репо
`deploy/cf-dq-2026-08-18-freshness-wire-v2` (коммит `16d93ec`) запушена в `origin`, **НЕ слита**
в `master` — запрет мандата, слияние требует отдельного решения. Неудачная ветка первой попытки
`deploy/cf-dq-2026-08-18-freshness-wire` (`2a3228d`) остаётся провенансом.
