# 11 · INFRA_FACTS — волатильные инфра-факты

**Версия:** 0.1 (скелет + 11a, M-P4-B-11) · **Статус:** LIVING
**Назначение:** канонический реестр волатильных инфра-фактов — URL/ревизии CF, Config ID SQ, расписания, IAM, секреты (имена). Обновляется часто, при каждом деплою/ротации секретов (ADR-004).
**Состав по `00_CHARTER §карта документов` стр.53.**

---

## §CF (URL/ревизии)

*(пусто — нет факта в источнике на момент M-P4-B-11; ожидается из брифа A-03: cf-fx URL/ревизии, PR-18ч)*

Источник-адрес: `00_CHARTER §карта документов` стр.53; ADR-004 §Последствия (PR-07, PR-10, PR-13, PR-15, PR-18ч).

## §SQ (Config ID + расписания)

Источник: `reference/sql/README.md` (выгрузка 2026-07-07, проект `msklad-bi-prod`, location `asia-east1`) · ADR-008 §Решение (1) · PR-21.

| Config ID | displayName | Целевая таблица | Schedule | Состояние |
|---|---|---|---|---|
| `69fc93d1-0000-2d64-bdd1-30fd381336b4` | `sq_audit_dim_products_snapshot` | `msklad-bi-prod.audit.dim_products_snapshots` | every day 04:00 | ⚠ FAILED (as-is, не чинить — вне scope ADR-008/M-P4-11a) |
| `69fc9c75-0000-2ab4-91b3-883d24f4db64` | `sq_audit_dim_counterparties_snapshot` | `msklad-bi-prod.audit.dim_counterparties_snapshots` | every day 04:00 | SUCCEEDED |
| `69fc9d6e-0000-2ab4-91b3-883d24f4db64` | `sq_audit_dim_employees_snapshot` | `msklad-bi-prod.audit.dim_employees_snapshots` | every day 04:00 | SUCCEEDED |

Трассировка: ADR-008 §Решение (1) — дом Config ID/расписание/стратегия = `11 §SQ`; схема датасета `audit` → `/reference` (гейт Q-4); SQL → `/reference/sql/` (гейт Q-5, уже выгружен).

## §IAM

*(пусто — нет факта в источнике на момент M-P4-B-11)*

Источник-адрес: `00_CHARTER §карта документов` стр.53; ADR-004 §Последствия (RB-05 «аспект IAM»).

## §секреты (имена)

*(пусто — нет факта в источнике на момент M-P4-B-11)*

Источник-адрес: `00_CHARTER §карта документов` стр.53; ADR-004 §Последствия (PR-18ч «cf-fx URL/секрет» — придёт из брифа A-03).

---

**Вне scope этой сессии:** CF-ревизии/URL/секреты cf-fx (→ бриф A-03); `10_OPS_PLAYBOOK`; схема датасета `audit` (Q-4); SQL audit-SQ в `/reference` (уже есть).
