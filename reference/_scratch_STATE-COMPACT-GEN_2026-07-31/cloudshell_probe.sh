#!/usr/bin/env bash
# Read-only проба домашнего каталога Cloud Shell: ищем скрипт/файл 2026-06-05,
# которым сформирован исходный NDJSON для core.fact_customer_invoices_stg (4058 строк).
# Ничего не пишет и не удаляет. ADR-055/063: date -u и gcloud auth list первой И последней командой.
set -u
cd "$(dirname "$0")"

echo "=== СТАРТ ==="
date -u
gcloud auth list 2>&1
gcloud version 2>&1 | head -2

B64=$(base64 < remote_probe.sh | tr -d '\n')

echo "=== ЗАПУСК cloud-shell ssh (read-only) ==="
# macOS: coreutils-овского timeout может не быть — используем gtimeout, иначе без обёртки
if command -v gtimeout >/dev/null 2>&1; then TO="gtimeout 480"; else TO=""; fi
$TO gcloud -q cloud-shell ssh --authorize-session --command="echo ${B64} | base64 -d | bash" 2>&1
echo "RC_SSH=$?"

echo "=== ФИНИШ ==="
date -u
gcloud auth list 2>&1
