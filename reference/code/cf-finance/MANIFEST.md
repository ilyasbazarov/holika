# MANIFEST · /reference/code/cf-finance/ — снапшот + патч диспетчера/счетов (`INVOICES-LOADER-BUILD`)

**Тип:** снапшот живой ревизии (свежий, снят этой сессией) + внесённый патч, готовый к переносу
на `T4` (`INVOICES-LOADER-DEPLOY`, класс B, не эта задача).
**Заменяет предыдущий манифест этой директории** (снапшот ревизии `00006-piv`, устаревший на
шесть ревизий, диспетчера не имел вовсе — `reference/invoices_loader_design_2026-08-02.md §11`
гэп 1).

---

## Базовый снапшот (ДО патча) — сверка с задеплоенной ревизией

`gcloud functions describe cf-finance --gen2 --region=asia-east1 --project=msklad-bi-prod`
→ `reference/_scratch_INVOICES-LOADER-BUILD_2026-08-02/cf_finance_describe.json`.

| Поле | Значение |
|---|---|
| `serviceConfig.revision` | `cf-finance-00012-cik` |
| `updateTime` | `2026-07-30T10:04:58.604346800Z` |
| `buildConfig.source.storageSource` | `gs://gcf-v2-sources-420804682491-asia-east1/cf-finance/function-source.zip`, generation `1784560843778541` |

Архив скачан `gsutil cp` тем же generation, распакован в
`reference/_scratch_INVOICES-LOADER-BUILD_2026-08-02/live_source/`.

sha256 архива: `04c337f4c31cfa3bb63a7c6ffc913f9f52ef387d4001d89ee2ff494fa2d0b202` — **совпадает** с
записью `reference/code_repo_standup_d2_2026-08-01.md §4` (та же ревизия, снята независимо
другой сессией на Cloud Shell). sha256 `main.py` (до патча):
`0cb4f6698a61cee96c90f9a14973ada38f5123418b54ff901f24ea2026ddab59` — **совпадает** с
`reference/code_repo_standup_d2_2026-08-01.md §6`. Оба совпадения проверены скриптом
(`shasum -a 256`), не на глаз.

**Наблюдение по гэпу 1 (design §11.1):** в живой ревизии `00012-cik` диспетчер режимов (`mode`)
**ОТСУТСТВОВАЛ** — точка входа была `def main(request): run_etl(); return "OK", 200`
(идентично снапшоту `00006-piv`, разница ревизий в этой части нулевая). Патч ниже вносит его
впервые.

## Патч, внесённый этой сессией

| Файл | Действие | sha256 (после патча) |
|---|---|---|
| `main.py` | добавлен диспетчер `mode` (`payments`\|`invoices`), `run_etl()` не тронут | `1afbaa3707182b54fc0c14600682d0220fe94a257f92093a862e55da27a2c6df` |
| `invoices.py` | НОВЫЙ модуль — весь режим `invoices` (design §2-§10) | `dc1768d973c2898addf5ee92116e831272437e3a9140683c92eb09cd74701886` |
| `requirements.txt` | добавлена строка `tenacity` (ретраи 429/5xx, design §3.4) | `f986310a048c5c90c93e511ec3ef0eeacf71feb2ecf591d45b001097e6707164` |
| `patch_main_finance.py` | **УДАЛЁН из снапшота** — junk-файл прошлой ревизии (не про конвертер, про `try/except` на `trigger_marts()`), тот же класс мусора, что `ADR-040`/`ADR-094 §4` уже исключали из код-репо; не относится к загрузчику счетов | — |

`main.py` вырос со 145 строк (живая ревизия) до 161 (+16: импорт `invoices`, дублирующий
дефолт-комментарий, тело диспетчера); `run_etl()`/`trigger_marts()`/`parse_href()` — байт-в-байт
как в живой ревизии (проверено диффом, см. `reference/_scratch_INVOICES-LOADER-BUILD_2026-08-02/checks/`).

**Не является финальным деплойным артефактом.** `T4` обязан снять СВОЙ свежий снапшот перед
переносом (ревизия могла измениться между этой сессией и деплоем) и перенести патч по diff,
не скопировать файлы этой директории вслепую.
