# TASK BRIEF · CODE-REPO-STANDUP-2NDSTEP

> **Имя задачи.** Пользователь просил присвоить этой сессии имя `CODE-REPO-STANDUP-2NDSTEP`. В самом
> репозитории (`07_STATE §Мандат Claude Code: класс задач`, строка мандата, `ADR-091 §4`, `ADR-094`)
> та же работа значится как **`CODE-REPO-STANDUP`, шаг 2a**. Оба имени — одна и та же задача; в
> session-блоке и во всех цитатах ниже используется репозиторное имя `CODE-REPO-STANDUP, шаг 2a`,
> файл брифа — по имени, заданному пользователем.

**Класс задачи (ADR-076):** A
Основание — дословно `07_STATE §Мандат Claude Code: класс задач`, строка «CODE-REPO-STANDUP, шаг 2a
(снимок, `.gitignore`, локальный коммит)»: `A | нет | постоянный | ADR-091 §4; форма seed выбрана
(ADR-094): архив исходников задеплоенной ревизии. Идёт ПОСЛЕ DEPLOY-REVISION-PROBE — от его
результата зависит выбор ревизии (ADR-094 §2). Пишет: диск Cloud Shell,
reference/code_repo_standup_d2_<date>.md`. `DEPLOY-REVISION-PROBE` исполнен 2026-08-01, `Q-95`
закрыт фактом (`07_ARCHIVE.md:131`) — предусловие снято, шаг разгейчен.

**Параллель (ADR-082 §1, уточнён `ADR-083 §1`):** нет
Значение взято дословно из той же строки таблицы мандата (`нет`). Не запускать одновременно с другой
сессией, пишущей в те же файлы или на тот же диск Cloud Shell, без `bash tools/parallel_check.sh` —
но само значение `нет` уже есть отказ параллели, прогон скрипта ничего не меняет.

**Файлы на запись** (полный список; на нём МЕХАНИЧЕСКИ проверяется пересечение при параллельном
запуске — `tools/parallel_check.sh`, `ADR-083 §1`):
- `reference/code_repo_standup_d2_2026-08-01.md` — сводный артефакт шага 2a: путь нового код-репо,
  ревизия/generation, sha256 всех файлов, содержимое `.gitignore`, хеши и сообщения коммитов, полный
  `git log`
- `reference/_scratch_CODE-REPO-STANDUP_2026-08-01/` — скрипты и логи этой сессии (доставка на Cloud
  Shell, распаковка, git-операции), провенанс

> Вне этого списка сессия также пишет НА ДИСК CLOUD SHELL (новый каталог код-репо, вне `holika`,
> `tools/parallel_check.sh` эту область не видит и не обязан — она не часть репозитория `holika`).
> Это ожидаемо и разрешено строкой мандата («Пишет: диск Cloud Shell»); называется здесь явно, чтобы
> не читалось как расхождение с «Файлы на запись».

---

## Роль

Ты — исполнитель проекта. Законы — `CLAUDE.md`, стандарты — `05_CONVENTIONS.md` Части I и II.
Модель исполнения: ты исполняешь сам (`ADR-082 §2`). Не-идемпотентное в этой задаче — `git commit` на
диске Cloud Shell (создание нового каталога и первого/второго коммита): выполняется отдельно от
диагностики, после того как диагностический шаг (Шаг 1 ниже) подтвердил состояние диска, не заранее.
`git push` в этой задаче не встречается вообще (шаг 2b, отдельная задача, владелец) — если по ходу
возникнет искушение создать удалённый репозиторий или запушить, это `CONTEXT GAP`/стоп, не
доисполнение по инерции.
Работаешь в СВОЁМ рабочем дереве и коммитишь в СВОЮ ветку `holika` (`ADR-081 §6`). `07_STATE`,
`06_DECISIONS_LOG` и `06_INDEX` не правишь: session-блок кладёшь файлом в `reference/_inbox/`.

## Цель

Построить первый seed отдельного живого код-репо для `cf-finance` (`ADR-017 §4`, промоушен в
критический путь `ADR-065`) по форме, закрытой `ADR-094`: seed — из АРХИВА исходников задеплоенной
ревизии (byte-for-byte, не с рабочей копии диска и не транскрипцией), существующая пустая заготовка
`.git` в `/home/ilyasbazarov4/cf-finance/` НЕ переиспользуется и не трогается, расхождения рабочей
копии со задеплоенным идут отдельным вторым коммитом с явным объяснением. Шаг 2b (создание удалённого
репозитория, первый `push`) — вне scope, отдельная задача, исполняет владелец.

## Context-to-load (обязательно прочитать перед работой)

- `_METHOD`, `00_CHARTER`, `05_CONVENTIONS`, `07_STATE` (всегда, читаются с диска по именам)
- `06_DECISIONS_LOG.md`, точечно по номеру:
  - `ADR-017` целиком — §4 (живой VC = отдельный код-репо, вариант a, НЕ внутри `holika`), §5
    (шаг 1 = discovery, seed-развилка), §6 (конвенция per-CF, сейчас только `cf-finance`)
  - `ADR-065` целиком — целевой инвариант «деплой любой CF только из код-репо; ревизия ↔ коммит»
  - `ADR-091 §4` — разрез шага 2 на 2a (класс A, эта сессия) / 2b (владелец, `git push` — ask)
  - `ADR-094` целиком, §1–§7 — форма seed (архив, не диск/транскрипция), порядок относительно
    `DEPLOY-REVISION-PROBE`, запрет переиспользовать заготовку `.git`, требование отдельного второго
    коммита под расхождения, scope только `cf-finance`
  - `ADR-040` — гигиена деплоя CF (`.gcloudignore`, `*.bak`/`__pycache__`/patch-скрипты не деплоятся);
    релевантно как обоснование состава `.gitignore` нового репо
  - `ADR-014`, `ADR-043`, `ADR-055`, `ADR-021 §2` — доставка исполняемых артефактов, диагностика не
    убирает за собой, UTC-якорь и личность вызывающего по краям скрипта, успех инструмента ≠ факт
- `11_INFRA_FACTS.md §CF`, строка `cf-finance` — путь исходников на диске Cloud Shell
  (`/home/ilyasbazarov4/cf-finance`), текущая деплоенная ревизия `cf-finance-00012-cik`
- `reference/deploy_revision_probe_2026-08-01.md` целиком — вердикт по `Q-95`, generation архива,
  sha256 всех версий `main.py`, точный diff задеплоенного против до-фиксовой копии, побочный факт о
  мусорных файлах в архиве (§6 п.1, прямо адресован этому шагу оговоркой `ADR-094 §4`)
- `reference/code_repo_standup_d1_2026-07-28.md` целиком — метод доступа к Cloud Shell
  (`gcloud cloud-shell ssh --authorize-session`, подтверждено `CLOUD_SHELL_REACHABLE`; доставка —
  `gcloud cloud-shell scp`), полный факт о состоянии `/home/ilyasbazarov4/cf-finance/.git` (0 коммитов,
  untracked-мусор, remote не задан) — эта заготовка НЕ трогается этим шагом
- Уже полученный этой (предыдущей) сессией `DEPLOY-REVISION-PROBE` архив, читать, не перекачивать
  заново без причины: `reference/_scratch_DEPLOY-REVISION-PROBE_2026-08-01/function-source.zip`,
  `reference/_scratch_DEPLOY-REVISION-PROBE_2026-08-01/describe.json`,
  `reference/_scratch_DEPLOY-REVISION-PROBE_2026-08-01/src/` (уже распакованное содержимое)

Чего-то из списка нет или содержимое не то, что заявлено именем файла: `CONTEXT GAP` либо
`СОДЕРЖИМОЕ НЕ ТО` по `ADR-054`, и стоп.

## Входы (факты из репо, использовать, не перепроверять с нуля)

- **Ревизия и generation.** `cf-finance-00012-cik` обслуживает 100 % трафика (замер
  `2026-08-01T08:05:46Z…08:06:59Z`). Архив собран из объекта
  `gs://gcf-v2-sources-420804682491-asia-east1/cf-finance/function-source.zip`, **generation
  `1784560843778541`**. sha256 архива: `04c337f4c31cfa3bb63a7c6ffc913f9f52ef387d4001d89ee2ff494fa2d0b202`.
- **Состав архива** (полный список верхнего уровня, из уже выполненной распаковки, 6 записей):
  `requirements.txt`, `main.py`, `main.py.bak`, `main.py.pre-e1t3-mech-fx.bak`,
  `patch_main_finance.py`, `__pycache__/main.cpython-312.pyc`. `.gcloudignore` внутри архива
  **отсутствует** (это build-конфиг, не часть содержимого source-archive).
- **sha256 `main.py` из архива:** `0cb4f6698a61cee96c90f9a14973ada38f5123418b54ff901f24ea2026ddab59`
  — конвертер несёт умножение на курс (`ADR-010`/`ADR-016` фикс), строки печатались целиком в
  `reference/deploy_revision_probe_2026-08-01.md §1`.
- **Заготовка `.git` в `/home/ilyasbazarov4/cf-finance/`** (`reference/code_repo_standup_d1_2026-07-28.md`):
  существует, 0 коммитов, `main.py` staged но рабочая копия уже разошлась с индексом, untracked-мусор
  те же 4 файла плюс `.gcloudignore` и `__pycache__/`, remote не задан. `ADR-094 §3`: эта заготовка
  **не удаляется и не переиспользуется**, вообще не трогается этой сессией.
- **Метод доступа к Cloud Shell — уже проверен и рабочий** (сессия `CODE-REPO-STANDUP-D1`,
  2026-07-28): `gcloud cloud-shell ssh --authorize-session --command="…"` даёт `CLOUD_SHELL_REACHABLE`;
  доставка скриптов — `gcloud cloud-shell scp`. Тем не менее это факт от **прошлой** сессии; текущая
  сессия обязана перепроверить его первой командой (состояние авторизации могло измениться), а не
  полагаться на устаревший вывод.
- **Куда пишет шаг 2a — на диск Cloud Shell, НЕ в текущее рабочее дерево `holika`.** Причина не
  стилистическая: рабочие деревья Claude Code (`worktrees/<TASK>/`) удаляются проходом сборки после
  слияния ветки (`ADR-081 §7`); если бы новый код-репо был создан внутри этого дерева, сборка стёрла
  бы только что созданную git-историю целиком. Диск Cloud Shell — отдельная постоянная машина, этому
  риску не подвержена, и это же согласуется дословно со строкой мандата («Пишет: диск Cloud Shell»).

## Шаги

**Шаг 0 — старт сессии по `CLAUDE.md`.** `git status` (дерево грязное → стоп, вопрос владельцу),
`git rev-parse HEAD` в session-блок, проверка `ADR-054` по каждому загруженному доку, хук установлен и
`bash tools/hooks/selftest.sh` даёт «провалено 0».

**Шаг 0б — переформулировать задачу своими словами.** Назвать явно, что этот шаг решает (первый
физический seed отдельного код-репо `cf-finance`, локально закоммиченный) и что НЕ решает: место
удалённого хостинга репо, первый `push`, форма деплой-процедуры «только из репо» (`ADR-065`, отдельное
решение после standup), статус `E1-T3-MECH-FX` (не меняется этим шагом).

**Шаг 1 — перепроверить доступ к Cloud Shell, один скрипт, read-only.**
```bash
#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud cloud-shell ssh --authorize-session --command="echo CLOUD_SHELL_REACHABLE" 2>&1 || echo CLOUD_SHELL_UNREACHABLE
date -u
```
- `CLOUD_SHELL_REACHABLE` → продолжай Шаг 2.
- `CLOUD_SHELL_UNREACHABLE` (или интерактивный апрув, который эта среда дать не может) → `CONTEXT
  GAP`: доступа нет, скрипт Шага 2 отдаётся владельцу на исполнение в самом Cloud Shell (доставка
  файлом, `ADR-055 §1`), лог возвращается в эту сессию для разбора. Не блокер задачи целиком — обычный
  маршрут при недоступности целевой машины.

**Шаг 2 — построить seed на Cloud Shell, один скрипт, лог в файл.**
Выбери и задокументируй в артефакте (Return-this) путь нового каталога — явно ОТЛИЧНЫЙ от
`/home/ilyasbazarov4/cf-finance/` (та заготовка не трогается). Рекомендуемое (не обязательное) имя:
`/home/ilyasbazarov4/cf-finance-coderepo`. Скрипт ниже доставляется и исполняется через
`gcloud cloud-shell scp` + `gcloud cloud-shell ssh --command="bash ~/step2_seed.sh > ~/run2.log 2>&1; cat ~/run2.log"`
(`ADR-055 §1`, редирект в файл).

```bash
#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list 2>&1

NEWREPO="$HOME/cf-finance-coderepo"     # поменять здесь, если выбрано другое имя
OLDDIR="$HOME/cf-finance"               # заготовка — НЕ трогать
PROJECT="msklad-bi-prod"
GEN="1784560843778541"
SRC="gs://gcf-v2-sources-420804682491-asia-east1/cf-finance/function-source.zip#${GEN}"
EXPECT_ZIP_SHA="04c337f4c31cfa3bb63a7c6ffc913f9f52ef387d4001d89ee2ff494fa2d0b202"
EXPECT_MAINPY_SHA="0cb4f6698a61cee96c90f9a14973ada38f5123418b54ff901f24ea2026ddab59"

echo "=== существующая заготовка (только чтение, не трогаем) ==="
ls -la "$OLDDIR/.git" 2>&1 || echo "(не найдено или недоступно)"

echo "=== новый каталог ==="
mkdir -p "$NEWREPO/archive"
cd "$NEWREPO"

echo "=== скачать архив по generation ==="
gcloud storage cp "$SRC" "$NEWREPO/function-source.zip" --project="$PROJECT" 2>&1
ACTUAL_ZIP_SHA=$(sha256sum "$NEWREPO/function-source.zip" | awk '{print $1}')
echo "sha256 архива: $ACTUAL_ZIP_SHA (ожидалось $EXPECT_ZIP_SHA)"
if [ "$ACTUAL_ZIP_SHA" != "$EXPECT_ZIP_SHA" ]; then
  echo "СТОП: sha256 архива не совпал с зафиксированным в reference/deploy_revision_probe_2026-08-01.md — это CONTEXT GAP, не продолжать молча"
  exit 1
fi

echo "=== распаковать во временный каталог, проверить main.py ==="
unzip -o -q "$NEWREPO/function-source.zip" -d "$NEWREPO/archive"
find "$NEWREPO/archive" -maxdepth 2
ACTUAL_MAINPY_SHA=$(sha256sum "$NEWREPO/archive/main.py" | awk '{print $1}')
echo "sha256 main.py: $ACTUAL_MAINPY_SHA (ожидалось $EXPECT_MAINPY_SHA)"
if [ "$ACTUAL_MAINPY_SHA" != "$EXPECT_MAINPY_SHA" ]; then
  echo "СТОП: sha256 main.py не совпал — CONTEXT GAP"
  exit 1
fi

echo "=== .gitignore (ADR-094 §4 / ADR-040: *.bak, __pycache__/, разовые patch-скрипты) ==="
cat > "$NEWREPO/.gitignore" <<'EOF'
*.bak
__pycache__/
patch_main_finance.py
function-source.zip
archive/
EOF
cat "$NEWREPO/.gitignore"

echo "=== копируем только легитимное содержимое в корень репо ==="
cp "$NEWREPO/archive/main.py" "$NEWREPO/main.py"
cp "$NEWREPO/archive/requirements.txt" "$NEWREPO/requirements.txt"

echo "=== git init + первый коммит (byte-for-byte архив минус игнор) ==="
git init 2>&1
git add .gitignore main.py requirements.txt
git status 2>&1
git commit -m "Seed from deployed revision cf-finance-00012-cik (generation ${GEN})" 2>&1
git log --oneline --all 2>&1
git show --stat HEAD 2>&1

echo "=== ПЕРВЫЙ КОММИТ: сверка sha256 закоммиченных файлов против архива ==="
sha256sum "$NEWREPO/main.py" "$NEWREPO/requirements.txt" 2>&1

echo "=== расхождение рабочей копии disk vs архив (ADR-094 §4) ==="
if [ -f "$OLDDIR/main.py" ]; then
  DISK_SHA=$(sha256sum "$OLDDIR/main.py" | awk '{print $1}')
  echo "sha256 $OLDDIR/main.py = $DISK_SHA"
  if [ "$DISK_SHA" = "$ACTUAL_MAINPY_SHA" ]; then
    echo "СОВПАДАЕТ с архивом — расхождений в main.py нет, второй коммит по main.py не нужен"
  else
    echo "РАСХОДИТСЯ с архивом — diff ниже, второй коммит потребуется"
    diff -u "$NEWREPO/archive/main.py" "$OLDDIR/main.py" 2>&1 || true
  fi
else
  echo "$OLDDIR/main.py недоступен для сравнения — гэп наблюдения, не факт «совпадает»"
fi
if [ -f "$OLDDIR/requirements.txt" ]; then
  DISK_REQ_SHA=$(sha256sum "$OLDDIR/requirements.txt" | awk '{print $1}')
  ARCH_REQ_SHA=$(sha256sum "$NEWREPO/archive/requirements.txt" | awk '{print $1}')
  echo "sha256 $OLDDIR/requirements.txt = $DISK_REQ_SHA (архив: $ARCH_REQ_SHA)"
fi

echo "=== заготовка $OLDDIR/.git — подтверждение, что не тронута ==="
ls -la "$OLDDIR/.git" 2>&1 || echo "(недоступно повторно)"

date -u
gcloud auth list 2>&1
```

**Шаг 3 — разбор лога, второй коммит по факту (не заранее).** Если Шаг 2 напечатал «РАСХОДИТСЯ» для
`main.py` и/или `requirements.txt` — скопировать разошедшуюся версию(и) поверх файла(ов) в
`$NEWREPO`, `git add`, закоммитить ОТДЕЛЬНЫМ коммитом с сообщением, дословно называющим, что именно
отличается от задеплоенной ревизии и откуда взята рабочая копия (`/home/ilyasbazarov4/cf-finance/`,
дата снятия). Если Шаг 2 напечатал «СОВПАДАЕТ» по обоим файлам — второй коммит не делается, это
явно фиксируется в артефакте как факт («расхождений на момент снятия нет»), а не как пропущенный шаг.

**Шаг 4 — забрать логи и написать артефакт.** `gcloud cloud-shell scp` — забрать `run.log` (Шаг 1),
`run2.log` (Шаг 2), сложить в `reference/_scratch_CODE-REPO-STANDUP_2026-08-01/`. Написать
`reference/code_repo_standup_d2_2026-08-01.md`.

## Критерии приёмки (Acceptance)

- Доступ к Cloud Shell подтверждён ЭТОЙ сессией (не унаследован от вывода прошлой), лог в
  разделимой форме, `date -u` по краям.
- Новый каталог код-репо создан ПО ДРУГОМУ пути, чем `/home/ilyasbazarov4/cf-finance/`; точный путь
  зафиксирован в артефакте. Существующая заготовка `.git` в старом каталоге не изменена — подтверждено
  read-back'ом до и после (`ls -la .git`, оба вывода в логе).
- Архив скачан по generation `1784560843778541`; sha256 архива и sha256 `main.py` совпали с записанными
  в `reference/deploy_revision_probe_2026-08-01.md` — оба значения сверены скриптом, а не на глаз.
- Первый коммит содержит РОВНО `main.py`, `requirements.txt`, `.gitignore`; junk-файлы
  (`*.bak`, `__pycache__/`, `patch_main_finance.py`) в него не входят и покрыты `.gitignore`.
- Расхождение (или его отсутствие) рабочей копии `/home/ilyasbazarov4/cf-finance/` против архива
  установлено фактом (реальный `diff`/sha256-сравнение), не предположением; при наличии расхождения —
  второй коммит с объяснением; при отсутствии — явная фраза в артефакте.
- `git log --oneline --all` нового репо и `git show --stat` каждого коммита напечатаны в артефакте
  целиком.
- Ни один `git push`, ни создание удалённого репозитория этой сессией не выполнены.
- Артефакт `reference/code_repo_standup_d2_2026-08-01.md` и `reference/_scratch_CODE-REPO-STANDUP_2026-08-01/`
  закоммичены в ветку сессии.

## Что вернуть человеку (Return-this)

- Логи `run.log` (Шаг 1) и `run2.log` (Шаг 2) целиком.
- Артефакт `reference/code_repo_standup_d2_2026-08-01.md`: точный путь нового код-репо на диске Cloud
  Shell, ревизия/generation, все sha256, содержимое `.gitignore`, хеш и сообщение каждого коммита,
  полный `git log`, явный вывод по расхождению рабочей копии (нашли/не нашли).
- Один session-блок по `05_CONVENTIONS` Часть III. `STATE_PATCH`: строка `CODE-REPO-STANDUP` в
  `07_STATE` дополняется результатом шага 2a (путь нового репо, коммиты) — задача не закрывается,
  продолжается шагом 2b (владелец).

## Вне scope этой задачи

- Шаг 2b: создание удалённого репозитория (GitHub или иной хостинг), первый `git push` — исходящее
  действие вовне, владелец, `ADR-091 §4`.
- Любое изменение или удаление существующей заготовки `.git` в `/home/ilyasbazarov4/cf-finance/`
  (`ADR-094 §3`) — не трогать вообще, даже если кажется «мешает».
- Форма деплой-процедуры «только из код-репо» (`ADR-065`) — отдельное решение после standup.
- Residual `Q-3` (прочие CF: `load_invoices.py`, `cf-facts`, `cf-dim`, `cf-fx`, `cf-dq`,
  `cf-inventory`, `cf-alert`) — per-CF, сейчас только `cf-finance` (`ADR-017 §6`/`ADR-094 §6`).
- Переоценка статуса `E1-T3-MECH-FX` — меняется отдельным замером/решением, не этим шагом.
- Новый ADR: `NEW_DECISIONS` в session-блоке ожидается пустым, если по ходу не всплывёт неучтённый
  факт (тогда — `proposed`, без апрува не применяется).

## В конце сессии

Выдай SESSION-блок по формату `05_CONVENTIONS` Часть III
(`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`).
