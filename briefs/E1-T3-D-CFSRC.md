# TASK BRIEF · E1-T3-D-CFSRC  (discovery)

> Тип: **discovery-бриф** (`_METHOD §11`) — return = обогащение репо, НЕ прод-код.
> Гейт-роль: разблокирует `E1-T3-MECH-FX` (ADR-016 §4). Двигает `Q-3` (cf-finance-часть) + снимает
> СТРУКТУРНУЮ половину `Q-30`/`Q-19`. ID присвоен генератором по факту генерации (роудмап отложил
> детализацию: `04_ROADMAP` Epic-1 / ADR-016 §Последствия).
> Пиннить перечитывание по SHA: `8687fe2dd6b097e483972322d1ecb3c35fbdc046`.

## Роль
Ты — разработчик проекта. Сначала прочитай `_METHOD` + `05_CONVENTIONS` (правила агента), затем действуй.
Модель исполнения: ты ПИШЕШЬ команды/артефакты, человек ЗАПУСКАЕТ в Cloud Shell и возвращает логи. Ты не
исполняешь сам. Задача НЕ выполнена без подтверждённого человеком лога (`_METHOD §3`).

Это **read-only discovery** (извлечение/инвентаризация/диагностика). Никаких деплоев, правок кода прода,
изменений `transferConfig`/CF. Фикс — отдельная задача `E1-T3-MECH-FX`, вне scope (см. ниже).

## Цель
Извлечь и версионировать **рабочий исходник `cf-finance`** (сейчас — только на persistent-диске Cloud Shell,
нигде не под контролем версий) как трассируемый референс-артефакт; установить **точный код-локус**
currency-conversion (где `÷100` применяется БЕЗ `×rate.value` — корень Q-27/ADR-016) для заземления фикса; и
зафиксировать **структурный охват конвертера** (локальный ли он для `cf-finance` или общий код-путь,
питающий другие `core.fact_*`). Решение о *каноническом месте хранения* — вынести архитектору как proposed,
НЕ принимать самому.

## Context-to-load (обязательно прочитать перед работой; литеральные raw-URL по SHA)
- `_METHOD` — https://raw.githubusercontent.com/ilyasbazarov/holika/8687fe2dd6b097e483972322d1ecb3c35fbdc046/_METHOD.md
- `00_CHARTER` — https://raw.githubusercontent.com/ilyasbazarov/holika/8687fe2dd6b097e483972322d1ecb3c35fbdc046/00_CHARTER.md
- `05_CONVENTIONS` — https://raw.githubusercontent.com/ilyasbazarov/holika/8687fe2dd6b097e483972322d1ecb3c35fbdc046/05_CONVENTIONS.md
- `07_STATE` — https://raw.githubusercontent.com/ilyasbazarov/holika/8687fe2dd6b097e483972322d1ecb3c35fbdc046/07_STATE.md
- `06_DECISIONS_LOG` — https://raw.githubusercontent.com/ilyasbazarov/holika/8687fe2dd6b097e483972322d1ecb3c35fbdc046/06_DECISIONS_LOG.md  *(ADR-002 фикс-форвард; ADR-010 канон конвертации; ADR-014 доставка артефактов; ADR-015 review-очередь; ADR-016 корень/директива фикса)*
- `11_INFRA_FACTS` — https://raw.githubusercontent.com/ilyasbazarov/holika/8687fe2dd6b097e483972322d1ecb3c35fbdc046/11_INFRA_FACTS.md  *(§CF: деплой/ревизия/путь исходника cf-finance; §секреты: `msklad-token`; §IAM: аномалия Q-28)*
- `01_ARCHITECTURE` — https://raw.githubusercontent.com/ilyasbazarov/holika/8687fe2dd6b097e483972322d1ecb3c35fbdc046/01_ARCHITECTURE.md  *(§топология: cf-finance → `core.fact_payments` (paymentout+cashout))*
- `03_PIPELINE_SPEC` §cf-finance — https://raw.githubusercontent.com/ilyasbazarov/holika/8687fe2dd6b097e483972322d1ecb3c35fbdc046/03_PIPELINE_SPEC.md  *(поведенческий контракт: порядок `run_etl`)*
- Эталон-evidence бага (E1-T3) — https://raw.githubusercontent.com/ilyasbazarov/holika/8687fe2dd6b097e483972322d1ecb3c35fbdc046/reference/recon_vyvod_pribyli_2026-05.md  *(§2–4/§8: доказанное занижение не-KGS `paymentout`, Σ 1 108 075,75 KGS, 38/38 док.)*
- Review-очередь (адъюдицирована ADR-016) — https://raw.githubusercontent.com/ilyasbazarov/holika/8687fe2dd6b097e483972322d1ecb3c35fbdc046/reference/architect_review_queue_2026-07-14.md

Если чего-то из списка нет в контексте → выдай `CONTEXT GAP` и остановись.

## Входы (факты из `11_INFRA_FACTS §CF`, актуальны на 2026-06-25 / PR-13 — при расхождении с живой инфрой доверять живому и пометить)
- CF: `cf-finance`, gen2, `python312`, region `asia-east1`, entry-point `main`, SA `etl-sa@msklad-bi-prod.iam.gserviceaccount.com`, `--set-secrets MSKLAD_TOKEN=msklad-token:latest`, timeout 1800s.
- **Рабочий исходник (persistent disk):** `/home/ilyasbazarov4/cf-finance`.
- **Задокументированная ревизия:** `cf-finance-00006-piv` (история `00001-wiv`→`00005-wob`→`00006-piv`, фикс `trigger_marts()` 2026-06-25).
- URI (Cloud Run native): `https://cf-finance-xw5u2boozq-de.a.run.app`.
- Проект: `msklad-bi-prod`.
- Известная не-блокирующая IAM-аномалия при `gcloud secrets versions access` — `Regional Access Boundary / Gaia id … ilyasbazarov4@gmail.com` (Q-28, DEFER). Для этого read-only извлечения секрет НЕ нужен; если всплывёт — задокументировать, не чинить.

## Шаги
1. **Переформулируй задачу своими словами**, перечисли полученные входы; проверь полноту context-to-load → нет чего-то → `CONTEXT GAP`.
2. **Инвентаризация on-disk источника** (read-only): листинг + рекурсивный перечень файлов + per-file `sha256` дерева `/home/ilyasbazarov4/cf-finance` (исключить `.git`, `__pycache__`).
3. **Провенанс vs прод:** `gcloud functions describe cf-finance --gen2 --region=asia-east1 --project=msklad-bi-prod` → снять `serviceConfig.revision`, `buildConfig.source` (GCS-локация исходника сборки), `buildConfig.entryPoint`, `updateTime`. Сверить, что on-disk соответствует задеплоенной ревизии `00006-piv`: скачать `buildConfig.source.storageSource` (zip из `gcf-v2-sources-*` бакета) и `diff` против on-disk. Совпало → зафиксировать «disk == deployed». Расхождение → это **Untrusted-состояние** (`_METHOD §6`): не примирять, зафиксировать факт «disk ≠ deployed rev» с перечнем расходящихся файлов — фикс нельзя писать поверх неоднозначного источника.
4. **Дамп исходника** в лог (все `*.py` и манифесты: `requirements.txt`, `*.toml`/`*.cfg`/`*.yaml`/`*.json`) — для чтения и последующего капчура в `/reference/code/cf-finance/`.
5. **Локус конвертера (корень Q-27):** найти в исходнике место, где строится `sum_kgs` для `paymentout`/`cashout` — grep по `rate`, `rate.value`, `/ 100`/`÷100`, `sum_kgs`, `paymentout`, `cashout`, `convert`. Зафиксировать **файл · функция · строка(и)**, где происходит `÷100`, и где ОТСУТСТВУЕТ `×rate.value` для не-KGS документов. Это точка enforcement ADR-010 (не примирять формулу — только локализовать).
6. **Структурный охват (СТРУКТУРНАЯ половина Q-30/Q-19, БЕЗ квантификации):** установить, конвертер **локален** для `cf-finance` (inline) или **общий модуль/хелпер** (импорт). Если общий — назвать модуль и перечислить, какие `core.fact_*` таблицы идут через тот же код-путь (даёт бласт-радиус: expense-only vs project-wide). МАГНИТУДНЫЙ замер (месяцы × таблицы × cashout) — НЕ здесь (Q-30 DEFER).
7. Собрать один **copy-paste-ready bash-блок** (ADR-014): read-only, без секретов; запуск с редиректом `bash extract.sh > cf_extract.log 2>&1; cat cf_extract.log` (разделимая форма, `_METHOD §6`). Никаких `<ВСТАВИТЬ…>`-плейсхолдеров. Человек запускает → возвращает `cf_extract.log`.
8. По логу: сформировать капчур-артефакт + findings + proposed-ADR (см. Return-this). Незакрытую decision-половину Q-3 (канон-место хранения) — в `architect_review_queue`, НЕ решать самому.

## Критерии приёмки (Acceptance)
- Исходник `cf-finance` (ревизия `00006-piv`, рабочая копия) извлечён и закоммичен в `/reference/code/cf-finance/` с манифестом провенанса: путь, ревизия, дата, результат сверки **disk-vs-deployed** (пусто/расхождение) — трассируемо к `11_INFRA_FACTS §CF` и `gcloud functions describe`.
- Сверка disk==deployed **выполнена и зафиксирована** (совпало ИЛИ расхождение явно записано как Untrusted, `_METHOD §6`).
- **Код-локус конвертера локализован**: конкретные файл/функция/строка(и), где `÷100` без `×rate.value` для не-KGS — в findings-артефакте, трассируемо к извлечённому исходнику. (Заземляет `E1-T3-MECH-FX`.)
- **Структурный охват зафиксирован**: конвертер local vs shared-module (назван); перечень `core.fact_*`, питаемых тем же путём — закрыта СТРУКТУРНАЯ половина Q-30/Q-19 (магнитуда остаётся DEFER).
- `Q-3` помечен на **partial-close** (cf-finance-часть закрыта); остаток (`load_invoices.py` в `/tmp`, прочие CF) явно оставлен как residual Q-3.
- Decision-половина Q-3 (**каноническое место хранения кода**) вынесена как **proposed-ADR + пункт `architect_review_queue`** (ADR-015) — НЕ решена разработчиком.

## Что вернуть человеку (Return-this) — обогащение репо, не прод-код
- `/reference/code/cf-finance/**` — извлечённый исходник (снапшот) + `MANIFEST.md` (путь-источник, ревизия `00006-piv`, дата, `sha256`-дерево, результат disk-vs-deployed).
- `/reference/cf_finance_converter_findings_2026-07-<DD>.md` — **диагностический** (evidence, НЕ оракул, вне `02 §оракул`): локус конвертера (файл/функция/строка), формула as-is, структурный охват (local/shared + список fed `core.fact_*`), кросс-ссылка на `recon_vyvod_pribyli_2026-05.md §8` и ADR-016 §2–§3.
- **Proposed-ADR** (черновик в session-блоке `NEW_DECISIONS`, статус `proposed`): каноническое место хранения исходников пайплайна (репо `holika` / отдельный код-репо / снапшот-`/reference`) — двигает decision-половину Q-3; решает архитектор/владелец.
- `/reference/architect_review_queue_2026-07-<DD>.md` — пункт по этому решению (контекст · вопрос · варианты · рекомендация (не решение) · что блокирует), по формату ADR-015.
- **SESSION-блок** (`05_CONVENTIONS` Часть III) со `STATE_PATCH`: `Q-3` → partial (cf-finance извлечён, decision pending); `E1-T3-MECH-FX` → «источник подтверждён, готов к написанию (staging-first), после решения о месте хранения»; Q-30/Q-19 → структурная половина captured; при disk≠deployed — новый блокер.

## Вне scope этой задачи
- **Написание самого фикса** `E1-T3-MECH-FX` (enforcement ADR-010 в cf-finance) — отдельная задача, staging-first (ADR-016 §3–§4), поверх этого закрытого гэпа.
- **МАГНИТУДНЫЙ замер** бага (весь март / другие месяцы / `cashout` / sales-сторона) — `Q-30` DEFER, owner-gated; `Q-19` sales-квантификация — отдельный гейт.
- **Полное извлечение прочих CF** (`cf-facts`/`cf-dim`/`cf-fx`/`cf-dq`/`cf-inventory`/`cf-alert`) и `load_invoices.py` — residual `Q-3`, следующий discovery-бриф.
- **Принятие решения** о каноническом месте хранения — только вынести архитектору (proposed).
- Любые деплои / правки `transferConfig` / изменения прода.

## В конце сессии
Выдай ОДИН SESSION-блок по формату `05_CONVENTIONS` Часть III
(`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`). Открытые для архитектора пункты —
дополнительно файлом `architect_review_queue_<date>.md` (ADR-015). Без session-блока сессия не закрыта.
