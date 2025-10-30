#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

SLUGS=(dlm_ar1V dlm_constV_bigW dlm_constV_smallW)

for s in "${SLUGS[@]}"; do
  RDIR="results/sim_suite_dlm/${s}/latest"
  echo -e "\n== ${s} =="
  if [[ ! -e "$RDIR" ]]; then
    echo "  (no latest symlink yet)"; continue
  fi
  STAT=$(cat "${RDIR}/manifest/status.txt" 2>/dev/null || echo "UNKNOWN")
  echo "  status: ${STAT}"
  for sub in figs tables models logs manifest; do
    d="${RDIR}/${sub}"
    n=$(ls -1 "$d" 2>/dev/null | wc -l || echo 0)
    echo "  ${sub}/: ${n}"
  done
  echo "  sample figs:"
  ls -1 "${RDIR}/figs"/*.png 2>/dev/null | head -8 || true
  echo "  sample tables:"
  ls -1 "${RDIR}/tables"/*.csv 2>/dev/null | head -5 || true
done
echo
