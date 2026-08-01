#!/usr/bin/env bash
# Оговорка ADR-076 §5(3): grep -rF по ЗНАЧЕНИЮ токена перед git add.
# Любое совпадение есть стоп. Печатается только счётчик, не значение.
set -uo pipefail
echo "=== ЯКОРЬ НАЧАЛА ==="; date -u; gcloud auth list 2>&1; echo
T="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
echo "длина токена: ${#T}"
N="$(grep -rF -- "$T" reference/ 2>/dev/null | wc -l | tr -d ' ')"
echo "совпадений значения токена в reference/: $N"
if [ "$N" = "0" ]; then echo "0 совпадений — чисто"; else echo "СТОП: значение токена найдено в файлах"; fi
echo; echo "=== ЯКОРЬ КОНЦА ==="; date -u; gcloud auth list 2>&1
