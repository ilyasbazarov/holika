#!/usr/bin/env python3
"""Замер v2: опознание сессии по имени её ветки/дерева (s/<TASK>, worktrees/<TASK>) —
признак точный, потому что ветку заводит сама сессия. Классификация по тексту промпта
(v1) отброшена как ненадёжная: ловила любое упоминание слова «сборка».
В репо выносятся ТОЛЬКО агрегаты и имена задач. Тела реплик не извлекаются.
"""
import json, glob, os, re, statistics as st
from collections import Counter

D = os.path.expanduser("~/.claude/projects/-Users-ilyasbazarov-Desktop-msklad-project-holika")
BRANCH = re.compile(r'(?:s/|worktrees/)([A-Z][A-Z0-9]+(?:-[A-Z0-9]+)*)')
ASSEMBLY = re.compile('docs: *сборка буфера')

rows = []
for p in sorted(glob.glob(os.path.join(D, "*.jsonl"))):
    tin = tout = tcache = 0; turns = 0
    names = Counter(); is_asm = False
    for line in open(p, encoding="utf-8", errors="replace"):
        if ASSEMBLY.search(line): is_asm = True
        for m in BRANCH.finditer(line): names[m.group(1)] += 1
        try: o = json.loads(line)
        except Exception: continue
        msg = o.get("message")
        if isinstance(msg, dict):
            u = msg.get("usage")
            if u:
                turns += 1
                tin += u.get("input_tokens", 0) or 0
                tout += u.get("output_tokens", 0) or 0
                tcache += (u.get("cache_read_input_tokens", 0) or 0) + \
                          (u.get("cache_creation_input_tokens", 0) or 0)
    if turns < 20: continue
    task = names.most_common(1)[0][0] if names else None
    rows.append({"file": os.path.basename(p)[:8], "task": task,
                 "assembly": is_asm, "turns": turns,
                 "out": tout, "fresh_in": tin, "cache": tcache})

ME = "a8429d8d"
mine = next(r for r in rows if r["file"] == ME)
others = [r for r in rows if r["file"] != ME]
asm = [r for r in others if r["assembly"]]
work = [r for r in others if not r["assembly"]]

print(f"сессий в выборке (>=20 обменов): {len(rows)}  из них проходов сборки: {len(asm)}")
print()
print("ЭТА СЕССИЯ (сквозная, четыре хода + делегированная сборка):")
print(f"  обменов {mine['turns']}, выход {mine['out']:,}, свежий вход {mine['fresh_in']:,}, кэш {mine['cache']:,}")
print(f"  опознана по ветке как: {mine['task']}")
print()
for label, group in (("РАБОЧИЕ СЕССИИ (без проходов сборки)", work), ("ПРОХОДЫ СБОРКИ", asm)):
    if not group: continue
    o = [r["out"] for r in group]
    print(f"{label}: n={len(group)}")
    print(f"  выход: медиана {int(st.median(o)):,}  среднее {int(st.mean(o)):,}  мин {min(o):,}  макс {max(o):,}")
print()
med_work = st.median([r["out"] for r in work])
print("СРАВНЕНИЕ, о котором спрашивал владелец:")
print(f"  эта сквозная сессия, выход:            {mine['out']:,}")
for k in (3, 4, 5):
    print(f"  {k} типовых рабочих сессии по медиане:  {int(med_work*k):,}   (отношение {mine['out']/(med_work*k):.2f})")
print()
fresh_share = lambda r: r["fresh_in"]/max(1,(r["fresh_in"]+r["cache"]))
print("ДОЛЯ СВЕЖЕГО ВХОДА (остальное — чтение кэша, оно дешевле):")
print(f"  эта сессия: {fresh_share(mine)*100:.4f}%")
import statistics as _st
print(f"  медиана по рабочим сессиям: {_st.median([fresh_share(r) for r in work])*100:.4f}%")
print()
print("ТОП рабочих сессий по выходу (контроль перекоса медианы):")
for r in sorted(work, key=lambda r: -r["out"])[:8]:
    print(f"  {r['file']} {(r['task'] or '-')[:38]:38} выход {r['out']:>8,} обменов {r['turns']:>4}")
json.dump(rows, open("reference/_scratch_PIPELINE-MODE-OBSERVATION_2026-08-05/sessions_metrics_v2.json","w"),
          ensure_ascii=False, indent=1)
