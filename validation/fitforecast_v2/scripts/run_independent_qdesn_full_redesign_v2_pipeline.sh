#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s --run-root PATH [--workers 15]\n' "$0" >&2
}

run_root=""
workers=15
while (($#)); do
  case "$1" in
    --run-root)
      run_root=${2:-}
      shift 2
      ;;
    --workers)
      workers=${2:-}
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$run_root" || ! "$workers" =~ ^[0-9]+$ || "$workers" -ne 15 ]]; then
  usage
  printf 'This frozen campaign requires exactly 15 workers.\n' >&2
  exit 2
fi

repo_root=$(git rev-parse --show-toplevel)
expected_branch="validation/independent-qdesn-full-redesign-v2-20260925"
rscript=${RSCRIPT:-$(command -v Rscript)}
manager="$repo_root/validation/fitforecast_v2/scripts/manage_independent_qdesn_full_redesign_v2.R"
worker="$repo_root/validation/fitforecast_v2/scripts/run_independent_qdesn_full_redesign_v2_job.R"
preflight="$repo_root/validation/fitforecast_v2/scripts/preflight_independent_qdesn_full_redesign_v2.R"
run_root=$(realpath -m "$run_root")

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1

fail() {
  printf 'FATAL: %s\n' "$*" >&2
  exit 1
}

branch=$(git -C "$repo_root" branch --show-current)
[[ "$branch" == "$expected_branch" ]] ||
  fail "expected branch $expected_branch, observed $branch"
[[ -z $(git -C "$repo_root" status --porcelain) ]] ||
  fail "the dedicated validation worktree is dirty"

upstream=$(git -C "$repo_root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) ||
  fail "the dedicated branch has no upstream"
read -r behind ahead < <(
  git -C "$repo_root" rev-list --left-right --count "$upstream...HEAD"
)
[[ "$behind" -eq 0 && "$ahead" -eq 0 ]] ||
  fail "branch/upstream divergence is behind=$behind ahead=$ahead"

package_version=$(
  "$rscript" --vanilla -e \
    'cat(as.character(read.dcf("DESCRIPTION", fields = "Version")[[1L]]))'
)
[[ "$package_version" == "1.1.1" ]] ||
  fail "DESCRIPTION version is $package_version, expected 1.1.1"

load_one=$(cut -d' ' -f1 /proc/loadavg)
available_mem_gb=$(awk '/MemAvailable:/ {printf "%d", $2 / 1024 / 1024}' /proc/meminfo)
available_disk_gb=$(df -Pk /data | awk 'NR==2 {printf "%d", $4 / 1024 / 1024}')
awk -v x="$load_one" 'BEGIN {exit !(x < 48)}' ||
  fail "one-minute load $load_one violates the <48 resource gate"
((available_mem_gb >= 96)) ||
  fail "available memory ${available_mem_gb} GiB violates the 96 GiB gate"
((available_disk_gb >= 250)) ||
  fail "available /data space ${available_disk_gb} GiB violates the 250 GiB gate"

printf 'preflight branch=%s head=%s upstream=%s load=%s mem_gb=%s disk_gb=%s workers=%s threads=1\n' \
  "$branch" "$(git -C "$repo_root" rev-parse HEAD)" "$upstream" \
  "$load_one" "$available_mem_gb" "$available_disk_gb" "$workers"

if [[ ! -f "$run_root/plans/normal_initial.csv" ]]; then
  "$rscript" --vanilla "$manager" --action materialize --run-root "$run_root"
fi

lock_dir="$run_root/.pipeline_lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  old_pid=$(cat "$lock_dir/pid" 2>/dev/null || true)
  if [[ "$old_pid" =~ ^[0-9]+$ && -d "/proc/$old_pid" ]]; then
    fail "pipeline lock is owned by active PID $old_pid"
  fi
  rm -rf "$lock_dir"
  mkdir "$lock_dir"
fi
printf '%s\n' "$$" > "$lock_dir/pid"
cleanup_lock() {
  rm -rf "$lock_dir"
}
trap cleanup_lock EXIT

if [[ ! -f "$run_root/manifests/preflight_report.json" ]]; then
  "$rscript" --vanilla "$preflight" --run-root "$run_root"
fi

run_stage() {
  local stage=$1
  local plan="$run_root/plans/$stage.csv"
  [[ -f "$plan" ]] || fail "missing plan for stage $stage"
  mkdir -p "$run_root/logs/$stage"

  mapfile -t configs < <(
    "$rscript" --vanilla "$manager" --action pending \
      --run-root "$run_root" --stage "$stage"
  )
  printf 'stage=%s planned=%s pending_or_retry=%s\n' \
    "$stage" "$(awk 'END {print NR-1}' "$plan")" "${#configs[@]}"

  if ((${#configs[@]})); then
    export repo_root run_root stage rscript worker
    if ! printf '%s\0' "${configs[@]}" | xargs -0 -n1 -P "$workers" \
      bash -c '
        cfg=$1
        id=$(basename "$cfg" .json)
        "$rscript" --vanilla "$worker" --config "$cfg" \
          > "$run_root/logs/$stage/$id.log" 2>&1
      ' _; then
      "$rscript" --vanilla "$manager" --action health --run-root "$run_root" || true
      fail "one or more $stage workers failed"
    fi
  fi

  mapfile -t remaining < <(
    "$rscript" --vanilla "$manager" --action pending \
      --run-root "$run_root" --stage "$stage"
  )
  if ((${#remaining[@]})); then
    "$rscript" --vanilla "$manager" --action health --run-root "$run_root" || true
    fail "$stage ended with ${#remaining[@]} incomplete jobs"
  fi
  "$rscript" --vanilla "$manager" --action health --run-root "$run_root"
}

run_stage normal_initial

if [[ ! -f "$run_root/plans/normal_adaptive.csv" ]]; then
  "$rscript" --vanilla "$manager" --action adaptive --run-root "$run_root"
fi
run_stage normal_adaptive

if [[ ! -f "$run_root/plans/normal_full.csv" ]]; then
  "$rscript" --vanilla "$manager" --action full --run-root "$run_root"
fi
run_stage normal_full

if [[ ! -f "$run_root/plans/quantile_vb.csv" ]]; then
  "$rscript" --vanilla "$manager" --action quantile --run-root "$run_root"
fi
run_stage quantile_vb

if [[ ! -f "$run_root/plans/mcmc_pilot.csv" ]]; then
  "$rscript" --vanilla "$manager" --action mcmc_pilot --run-root "$run_root"
fi
run_stage mcmc_pilot

if [[ ! -f "$run_root/plans/mcmc_confirmation.csv" ]]; then
  "$rscript" --vanilla "$manager" --action mcmc_confirmation \
    --run-root "$run_root"
fi
run_stage mcmc_confirmation

"$rscript" --vanilla "$manager" --action verify --run-root "$run_root"
"$rscript" --vanilla "$manager" --action closeout --run-root "$run_root"
printf 'pipeline_complete run_root=%s\n' "$run_root"
