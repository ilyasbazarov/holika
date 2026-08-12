#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

echo "=== traffic status (which revision actually serves) ==="
gcloud run services describe cf-facts --region=asia-east1 --project=msklad-bi-prod \
  --format="value(status.traffic)"

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

# generation pinned by SALES-REFRESH-WINDOW-DEPLOY step1 (2026-08-11T08:10:20Z) for
# cf-facts-00011-mab — the revision confirmed above to hold 100% traffic. `functions
# describe` without a revision arg always reports the LATEST BUILT revision's source
# (currently cf-facts-00014-doh, the reverted deletion-branch attempt), not the one
# serving traffic — this is the exact trap 07_STATE names for cf-facts-00012-ber.
GEN=1786273160918659
BUCKET=gcf-v2-sources-420804682491-asia-east1
OBJECT=cf-facts/function-source.zip
echo "=== pulling pinned archive for cf-facts-00011-mab, generation=$GEN ==="
gcloud storage cp "gs://${BUCKET}/${OBJECT}#${GEN}" ./archive.zip
mkdir extracted && cd extracted
unzip -q ../archive.zip

echo "=== sha256 archive(00011-mab) vs master (holika-prod @ HEAD) ==="
MASTER=/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/SALES-REFRESH-WINDOW-DEPLOY-FINAL/reference/_scratch_SALES-REFRESH-WINDOW-DEPLOY-FINAL_2026-08-12/holika-prod
echo "master HEAD: $(git -C "$MASTER" rev-parse master)"
ALL_MATCH=1
for f in helpers.py bq_ops.py config.py main.py fetch_perimeter.py fetch_byvariant.py fetch_demands.py fetch_purchases.py fetch_returns.py requirements.txt; do
  A=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
  B=$(git -C "$MASTER" show master:cf-facts/$f 2>/dev/null | sha256sum | cut -d' ' -f1)
  MATCH="MISMATCH"
  [ "$A" = "$B" ] && MATCH="match" || ALL_MATCH=0
  echo "$f: archive=$A master=$B -> $MATCH"
done
echo "ALL_MATCH=$ALL_MATCH"

echo "=== workdir path (printed, not cleaned — ADR-043) ==="
echo "$WORKDIR"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
