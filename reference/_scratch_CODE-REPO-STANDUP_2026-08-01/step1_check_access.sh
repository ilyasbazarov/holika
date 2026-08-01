#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud cloud-shell ssh --authorize-session --command="echo CLOUD_SHELL_REACHABLE" 2>&1 || echo CLOUD_SHELL_UNREACHABLE
date -u
