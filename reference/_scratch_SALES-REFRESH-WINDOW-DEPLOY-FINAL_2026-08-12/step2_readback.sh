#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

GEN=1786546688061530
BUCKET=gcf-v2-sources-420804682491-asia-east1
OBJECT=cf-facts/function-source.zip
echo "=== pulling pinned archive for cf-facts-00017-jon, generation=$GEN ==="
gcloud storage cp "gs://${BUCKET}/${OBJECT}#${GEN}" ./archive.zip
mkdir extracted && cd extracted
unzip -q ../archive.zip

echo "=== archive file listing (junk check: *.bak, __pycache__, patch_*.py) ==="
find . -type f | sort

echo "=== sha256 archive vs deploy branch ==="
BR=/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/SALES-REFRESH-WINDOW-DEPLOY-FINAL/reference/_scratch_SALES-REFRESH-WINDOW-DEPLOY-FINAL_2026-08-12/holika-prod
BRANCH_SHA=$(git -C "$BR" rev-parse deploy/cf-facts-2026-08-12-completeness-and-delete)
echo "branch HEAD: $BRANCH_SHA"
ALL_MATCH=1
for f in helpers.py bq_ops.py config.py main.py fetch_perimeter.py fetch_byvariant.py fetch_demands.py fetch_purchases.py fetch_returns.py requirements.txt; do
  A=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
  B=$(git -C "$BR" show "$BRANCH_SHA:cf-facts/$f" 2>/dev/null | sha256sum | cut -d' ' -f1)
  MATCH="MISMATCH"
  [ "$A" = "$B" ] && MATCH="match" || ALL_MATCH=0
  echo "$f: archive=$A branch=$B -> $MATCH"
done
echo "ALL_MATCH=$ALL_MATCH"

echo "=== diff vs previous revision (cf-facts-00011-mab archive, sha256 recorded earlier) ==="
declare -A PREV=(
  [helpers.py]=c1d5f0594a46f176dad33afffb3944fae378148cd7d27b0bd2c81230d020dd21
  [bq_ops.py]=e8bb06596bc64a22889890cff583a2d8ed8325ef4c5941d48a8769c2e18c90d8
  [config.py]=56e77eff536ce8fe2a1c3a015c2633ed1317e8a9cbbd9729165d5a7af38de63a
  [main.py]=97b9ce3aa54085aab0739fd315890db22be8c837e829a9170ebce385ba6642d8
  [fetch_perimeter.py]=f609d5656fe6cf79941ffb3c904a122afabe2f5b7633a846a7f5ae713314275e
  [fetch_byvariant.py]=88e1a13881103e0faa5ec21a5a07ddd2fc83e9cc9eb4fb9fe67a0da25fb60ff1
  [fetch_demands.py]=b092863efa75346208ee4aa8aa7cde60be42024415638386f76ec6fc96bcf358
  [fetch_purchases.py]=159e498789168b0206beca15bf719e3541a2564ec93d786abec8ed7860befafb
  [fetch_returns.py]=7f3dcefadb0de4782d9f09964f5c5baf5d423375406c1f6f2846356ddd663bd1
  [requirements.txt]=0c041a8d50f4731ad71aabcf678f388c13d8ba9af6ccb6548af9ccb6fc514051
)
CHANGED=0
for f in "${!PREV[@]}"; do
  A=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
  if [ "$A" != "${PREV[$f]}" ]; then
    echo "CHANGED vs 00011-mab: $f"
    CHANGED=$((CHANGED+1))
  fi
done
echo "files changed vs cf-facts-00011-mab: $CHANGED (expected: 5)"

echo "=== workdir path (printed, not cleaned — ADR-043) ==="
echo "$WORKDIR"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
