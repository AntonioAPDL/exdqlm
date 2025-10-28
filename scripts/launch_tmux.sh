#!/usr/bin/env bash
# Convenience wrapper to launch tmux sessions per dataset with a spec
# Usage: scripts/launch_tmux.sh baseline

set -euo pipefail
SPEC="${1:-baseline}"
Rscript scripts/run_batch.R "$SPEC"
