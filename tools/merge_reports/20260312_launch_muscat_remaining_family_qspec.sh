#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
if [[ ! -f "$repo_root/DESCRIPTION" ]]; then
  echo "Run this script from exdqlm repo root." >&2
  exit 1
fi

manifest_default="tools/merge_reports/20260312_family_qspec_muscat_launch_manifest.tsv"
manifest="${1:-$manifest_default}"
max_parallel="${MAX_PARALLEL_BATCHES:-4}"

if [[ ! -f "$manifest" ]]; then
  echo "Launch manifest not found: $manifest" >&2
  exit 1
fi

if ! [[ "$max_parallel" =~ ^[0-9]+$ ]] || [[ "$max_parallel" -lt 1 ]]; then
  echo "MAX_PARALLEL_BATCHES must be a positive integer." >&2
  exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is required but not available." >&2
  exit 1
fi

batches=(
  "static_paper_tt100"
  "static_paper_tt1000"
  "static_shrink_ridge_tt100"
  "static_shrink_rhs_tt100"
  "static_shrink_ridge_tt1000"
  "static_shrink_rhs_tt1000"
  "dynamic_tt500"
  "dynamic_tt5000"
)

stamp="$(date '+%Y%m%d_%H%M%S')"
registry="tools/merge_reports/20260312_muscat_launch_registry_${stamp}.tsv"
printf "session\tbatch\tlog\tstart_ts\tcmd\n" > "$registry"

count_batch_rows() {
  local batch="$1"
  awk -F'\t' -v batch="$batch" '
    NR==1 {
      for (i=1; i<=NF; i++) idx[$i]=i
      next
    }
    $idx["batch_label"] == batch && $idx["launch_on_muscat_now"] == "TRUE" { c++ }
    END { print c+0 }
  ' "$manifest"
}

active_launch_sessions() {
  tmux list-sessions -F '#S' 2>/dev/null | grep -c '^mqsp_' || true
}

echo "START $(date '+%F %T') muscat launch orchestration"
echo "manifest=$manifest"
echo "max_parallel_batches=$max_parallel"
echo "registry=$registry"

for batch in "${batches[@]}"; do
  n_rows="$(count_batch_rows "$batch")"
  if [[ "$n_rows" -eq 0 ]]; then
    echo "SKIP batch=$batch (no launchable roots)"
    continue
  fi

  while [[ "$(active_launch_sessions)" -ge "$max_parallel" ]]; do
    echo "WAIT active_mqsp_sessions=$(active_launch_sessions) cap=$max_parallel"
    sleep 20
  done

  session="mqsp_${batch}_${stamp}"
  log="tools/merge_reports/20260312_muscat_${batch}_${stamp}.log"
  cmd="bash tools/merge_reports/20260312_run_family_qspec_manifest_batch.sh '$manifest' '$batch' > '$log' 2>&1"

  tmux new-session -d -s "$session" "cd '$repo_root' && $cmd"
  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$session" "$batch" "$log" "$(date --iso-8601=seconds)" "$cmd" >> "$registry"
  echo "LAUNCHED session=$session batch=$batch roots=$n_rows log=$log"
done

echo "ACTIVE mqsp sessions:"
tmux list-sessions -F '#S' 2>/dev/null | grep '^mqsp_' || true
echo "END $(date '+%F %T') muscat launch orchestration"
