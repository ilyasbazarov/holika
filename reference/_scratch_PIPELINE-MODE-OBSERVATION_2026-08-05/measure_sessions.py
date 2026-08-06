#!/usr/bin/env python3
"""Замер стоимости сессий по транскриптам Claude Code (класс A: только чтение локального диска).

В репо выносятся ТОЛЬКО агрегаты и опознанное имя задачи. Тела реплик, промпты и любые
значения из них НЕ извлекаются и в артефакт не попадают — иначе замер сам стал бы утечкой.
"""
import json, glob, os, re, datetime
from collections import defaultdict

D = os.path.expanduser("~/.claude/projects/-Users-ilyasbazarov-Desktop-msklad-project-holika")
TASK = re.compile(r'\b(?:ЗАДАЧА|задача)\s*:\s*`?([A-Z][A-Z0-9\-]{4,})')
ROLE = [("сборка", re.compile(r'сборк|_ASSEMBLER|сборщик', re.I)),
        ("генерация брифа", re.compile(r'-GEN\b|генерац\w* бриф', re.I)),
        ("архитектор", re.compile(r'Ты — архитектор|архитекторск', re.I)),
        ("исполнитель", re.compile(r'бриф\s+briefs/|Ты — исполнитель|executor', re.I))]

rows = []
for p in sorted(glob.glob(os.path.join(D, "*.jsonl"))):
    tin = tout = tcache = 0
    turns = 0
    ts_first = ts_last = None
    task = None; role = None; first_user = ""
    for line in open(p, encoding="utf-8", errors="replace"):
        try: o = json.loads(line)
        except Exception: continue
        t = o.get("timestamp") or (o.get("message") or {}).get("timestamp")
        if t:
            if ts_first is None: ts_first = t
            ts_last = t
        m = o.get("message")
        if isinstance(m, dict):
            u = m.get("usage")
            if u:
                turns += 1
                tin    += u.get("input_tokens", 0) or 0
                tout   += u.get("output_tokens", 0) or 0
                tcache += (u.get("cache_read_input_tokens", 0) or 0) + \
                          (u.get("cache_creation_input_tokens", 0) or 0)
            if o.get("type") == "user" and not first_user:
                c = m.get("content")
                if isinstance(c, str): first_user = c[:4000]
                elif isinstance(c, list):
                    first_user = " ".join(x.get("text","") for x in c if isinstance(x, dict))[:4000]
    if turns == 0: continue
    mt = TASK.search(first_user)
    task = mt.group(1) if mt else None
    for name, rx in ROLE:
        if rx.search(first_user): role = name; break
    dur = None
    if ts_first and ts_last:
        try:
            a = datetime.datetime.fromisoformat(ts_first.replace("Z", "+00:00"))
            b = datetime.datetime.fromisoformat(ts_last.replace("Z", "+00:00"))
            dur = round((b - a).total_seconds() / 60, 1)
        except Exception: pass
    rows.append({"file": os.path.basename(p)[:8], "task": task, "role": role,
                 "turns": turns, "in": tin, "out": tout, "cache": tcache,
                 "total": tin + tout + tcache, "minutes": dur})

rows.sort(key=lambda r: -r["total"])
print(f"{'файл':10} {'роль':16} {'задача':34} {'обменов':>7} {'выход':>8} {'всего':>11} {'мин':>6}")
for r in rows:
    print(f"{r['file']:10} {(r['role'] or '-'):16} {(r['task'] or '-')[:34]:34} "
          f"{r['turns']:7d} {r['out']:8d} {r['total']:11d} {str(r['minutes'] or '-'):>6}")

print("\n=== агрегаты по ролям ===")
by = defaultdict(list)
for r in rows: by[r["role"] or "не опознана"].append(r)
for k, v in sorted(by.items(), key=lambda kv: -len(kv[1])):
    tot = sorted(x["total"] for x in v); out = sorted(x["out"] for x in v)
    med = lambda a: a[len(a)//2]
    print(f"{k:16} сессий={len(v):3d}  медиана всего={med(tot):9d}  медиана выхода={med(out):7d}")

json.dump(rows, open("reference/_scratch_PIPELINE-MODE-OBSERVATION_2026-08-05/sessions_metrics.json","w"),
          ensure_ascii=False, indent=1)
print("\nсырые агрегаты: reference/_scratch_PIPELINE-MODE-OBSERVATION_2026-08-05/sessions_metrics.json")
