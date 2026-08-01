# FILE: code_repo_standup_d2_2026-08-01.md

**Задача:** `CODE-REPO-STANDUP`, шаг 2a (сборка первого seed код-репо `cf-finance`) · **Класс:** A (`07_STATE §Мандат`)
**Дата (Бишкек):** 2026-08-01 · **Провенанс:** сессия `CODE-REPO-STANDUP-2NDSTEP`, бриф `briefs/CODE-REPO-STANDUP-2NDSTEP.md`
**SHA holika на старте сессии:** `8d76358ba361d6a53b8ab50b3544cb5050e31f88`
**Форма seed:** `ADR-094` — архив исходников задеплоенной ревизии (byte-for-byte), не рабочая копия диска, не транскрипция.

---

## §1 Доступ к Cloud Shell

Перепроверен ЭТОЙ сессией (не унаследован от прошлой), лог в разделимой форме, `date -u` по краям:
`reference/_scratch_CODE-REPO-STANDUP_2026-08-01/run.log`. Результат: `CLOUD_SHELL_REACHABLE`
(`2026-08-01T14:07:58Z` … `14:08:30Z`).

## §2 Путь нового код-репо

`/home/ilyasbazarov4/cf-finance-coderepo` (рекомендованное брифом имя, использовано как есть).
Явно отличен от `/home/ilyasbazarov4/cf-finance/` (существующая заготовка `.git`, `ADR-094 §3`).

## §3 Ревизия и generation

- Ревизия: `cf-finance-00012-cik` (100 % трафика, замер `DEPLOY-REVISION-PROBE` 2026-08-01, `Q-95` закрыт).
- Generation объекта архива: `1784560843778541`.
- Источник: `gs://gcf-v2-sources-420804682491-asia-east1/cf-finance/function-source.zip#1784560843778541`.

## §4 Сверка sha256 (скриптом, не на глаз)

| Файл | sha256 фактический | sha256 ожидаемый (`reference/deploy_revision_probe_2026-08-01.md`) | Совпало |
|---|---|---|---|
| `function-source.zip` | `04c337f4c31cfa3bb63a7c6ffc913f9f52ef387d4001d89ee2ff494fa2d0b202` | тот же | да |
| `main.py` (из архива) | `0cb4f6698a61cee96c90f9a14973ada38f5123418b54ff901f24ea2026ddab59` | тот же | да |

Оба сравнения прошли скриптовым `if`-условием (`step2_seed.sh`), при несовпадении скрипт остановился
бы сам (`exit 1`, `CONTEXT GAP`) — расхождения не было, до `exit 1` дело не дошло.

## §5 `.gitignore` (содержимое, дословно)

```
*.bak
__pycache__/
patch_main_finance.py
function-source.zip
archive/
```

Обоснование состава — `ADR-040`/`ADR-094 §4`: архив задеплоенной сборки нёс мусор (`main.py.bak`,
`main.py.pre-e1t3-mech-fx.bak`, `patch_main_finance.py`, `__pycache__/main.cpython-312.pyc`,
зафиксировано `reference/deploy_revision_probe_2026-08-01.md §6 п.1`) — в новый код-репо он не входит.

## §6 Первый коммит

Содержит РОВНО `main.py`, `requirements.txt`, `.gitignore` — junk-файлы не входят и покрыты
`.gitignore` (подтверждено `git show --stat`, ниже).

```
git log --oneline --all:
4317047 Seed from deployed revision cf-finance-00012-cik (generation 1784560843778541)

git show --stat HEAD:
commit 4317047333d6311d7439e8e7215de3b3638a4ddd
Author: Ilyas Bazarov <ilyasbazarov4@gmail.com>
Date:   Sat Aug 1 14:09:49 2026 +0000

    Seed from deployed revision cf-finance-00012-cik (generation 1784560843778541)

 .gitignore       |   5 ++
 main.py          | 145 +++++++++++++++++++++++++++++++++++++++++++++++++++++++
 requirements.txt |   4 ++
 3 files changed, 154 insertions(+)
```

sha256 закоммиченных файлов (после коммита, из рабочего дерева нового репо):
- `main.py` = `0cb4f6698a61cee96c90f9a14973ada38f5123418b54ff901f24ea2026ddab59` (= sha256 архива §4)
- `requirements.txt` = `5b9dfa54877cc7b48885be34cd1bf4c125435bb9f19f1e0dd856def14e4b6d92`

## §7 Расхождение рабочей копии `/home/ilyasbazarov4/cf-finance/` против архива

Установлено фактом (реальный sha256-сравнение, не предположением):

- `main.py`: sha256 на диске `0cb4f6698a61cee96c90f9a14973ada38f5123418b54ff901f24ea2026ddab59` =
  sha256 архива. **Совпадает.**
- `requirements.txt`: sha256 на диске `5b9dfa54877cc7b48885be34cd1bf4c125435bb9f19f1e0dd856def14e4b6d92` =
  sha256 архива. **Совпадает.**

**Расхождений на момент снятия (2026-08-01T14:09:49Z) нет.** Второй коммит по `ADR-094 §4` НЕ
делается — это явный факт, а не пропущенный шаг (см. `Шаг 3` брифа).

## §8 Заготовка `/home/ilyasbazarov4/cf-finance/.git` — подтверждение нетронутости

`ls -la .git` до и после исполнения скрипта дали одинаковый вывод (те же `branches`, `config`,
`description`, `HEAD`, `hooks`, `index`, `info`, `objects`, `refs`; те же mtime `Jun 25 09:05` /
`Jul 14 17:09` / `Jul 28 16:41`) — заготовка не изменена этой сессией. Оба вывода — в
`reference/_scratch_CODE-REPO-STANDUP_2026-08-01/run2.log`.

## §9 Не выполнено этой сессией (вне scope)

- `git push`, создание удалённого репозитория — нет ни одного вызова (шаг 2b, владелец).
- Заготовка `/home/ilyasbazarov4/cf-finance/.git` не удалялась и не изменялась.
- Форма деплой-процедуры «только из код-репо» (`ADR-065`) — не решалась.
- Статус `E1-T3-MECH-FX` — не менялся.

---

## Provenance

- Скрипты: `reference/_scratch_CODE-REPO-STANDUP_2026-08-01/step1_check_access.sh`,
  `reference/_scratch_CODE-REPO-STANDUP_2026-08-01/step2_seed_ran.sh` (копия исполненного на
  Cloud Shell файла, забрана обратно `scp` для провенанса).
- Логи полностью: `reference/_scratch_CODE-REPO-STANDUP_2026-08-01/run.log` (Шаг 1),
  `reference/_scratch_CODE-REPO-STANDUP_2026-08-01/run2.log` (Шаг 2).
- Метод доступа: `gcloud cloud-shell ssh --authorize-session` / `gcloud cloud-shell scp`, доставка и
  сбор — `ADR-055 §1`, редирект в файл на удалённой стороне (`bash ~/step2_seed.sh > ~/run2.log 2>&1`).
