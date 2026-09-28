#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
harness_root=$(cd "$script_dir/.." && pwd)
repo_root=$(cd "$harness_root/../.." && pwd)
expected_branch="validation/independent-qdesn-full-redesign-v2-20260925"
expected_upstream="origin/${expected_branch}"
rscript="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
r_binary="${R_BINARY:-/data/jaguir26/local/opt/R/4.6.0/bin/R}"
workers="${WORKERS:-15}"
run_root="${RUN_ROOT:?RUN_ROOT is required}"
source_run_root="${SOURCE_RUN_ROOT:?SOURCE_RUN_ROOT is required}"
cpu_set="${CPU_SET:?CPU_SET is required}"
source_tarball="${SOURCE_TARBALL:-/data/jaguir26/local/src/exdqlm__wt__independent_exdqlm_mcmc_rolling_state_fix_v1_1p0p0/validation/fitforecast_v2/local_trackers/independent_exdqlm_mcmc_rolling_state_fix_v1/package/exdqlm_1.1.1.tar.gz}"
expected_tarball_sha="3f3ed643ded7602fd62357d7f62024ca9071e0096214456650ed2de79722443e"

state_root="${run_root}/orchestration"
runtime_root="${run_root}/runtime"
r_library="${runtime_root}/Rlib"
tarball="${runtime_root}/package/exdqlm_1.1.1.tar.gz"
pipeline_log="${state_root}/pipeline.stdout.log"
status_file="${state_root}/pipeline.status"
stage_status="${state_root}/stage_status.csv"

export R_LIBS_USER="$r_library"
export OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1 OMP_DYNAMIC=FALSE
export OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 BLIS_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1

branch=$(git -C "$repo_root" branch --show-current)
upstream=$(git -C "$repo_root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')
[[ "$branch" == "$expected_branch" && "$upstream" == "$expected_upstream" ]] || {
  printf 'Unexpected branch/upstream: %s / %s\n' "$branch" "$upstream" >&2
  exit 2
}
[[ -z $(git -C "$repo_root" status --porcelain) ]] || {
  printf 'The dedicated validation worktree must be clean.\n' >&2
  exit 2
}
read -r behind ahead < <(git -C "$repo_root" rev-list --left-right --count '@{upstream}...HEAD')
[[ "$behind" -eq 0 && "$ahead" -eq 0 ]] || {
  printf 'Branch divergence is behind=%s ahead=%s.\n' "$behind" "$ahead" >&2
  exit 2
}
[[ "$workers" -eq 15 ]] || { printf 'Recovery requires exactly 15 workers.\n' >&2; exit 2; }
[[ $(tr ',' '\n' <<< "$cpu_set" | sed '/^$/d' | wc -l) -eq "$workers" ]] || {
  printf 'CPU_SET does not contain exactly 15 CPUs: %s\n' "$cpu_set" >&2
  exit 2
}
[[ -x "$rscript" && -x "$r_binary" && -f "$source_tarball" ]] || {
  printf 'R 4.6.0 or the CRAN source tarball is unavailable.\n' >&2
  exit 2
}
[[ -d "$source_run_root" ]] || { printf 'Source failed run is missing.\n' >&2; exit 2; }
[[ $(sha256sum "$source_tarball" | awk '{print $1}') == "$expected_tarball_sha" ]] || {
  printf 'CRAN exdqlm 1.1.1 tarball hash mismatch.\n' >&2
  exit 2
}
[[ ! -e "$run_root" ]] || { printf 'Refusing an existing run root.\n' >&2; exit 2; }

mkdir -p "$state_root" "$r_library" "$(dirname "$tarball")"
exec > >(tee -a "$pipeline_log") 2>&1
printf 'timestamp,stage,status,detail\n' > "$stage_status"
printf 'status=RUNNING started_at=%s\n' "$(date --iso-8601=seconds)" > "$status_file"

record() {
  local stage=$1 status=$2 detail=$3
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" "$status" \
    "${detail//,/;}" >> "$stage_status"
}
fail() {
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    printf 'status=FAILED exit_code=%d ended_at=%s\n' "$rc" \
      "$(date --iso-8601=seconds)" > "$status_file"
  fi
}
trap fail EXIT INT TERM

record resource_gate STARTED "workers=${workers};cpu_set=${cpu_set}"
read -r load1 _ < /proc/loadavg
memory_gb=$(awk '/MemAvailable:/ {printf "%.1f", $2/1048576}' /proc/meminfo)
disk_gb=$(df -Pk "$repo_root" | awk 'NR==2 {printf "%.1f", $4/1048576}')
awk -v l="$load1" -v m="$memory_gb" -v d="$disk_gb" \
  'BEGIN {exit !((l <= 48) && (m >= 96) && (d >= 250))}' || {
  printf 'Resource gate failed: load=%s memory=%sGB disk=%sGB\n' \
    "$load1" "$memory_gb" "$disk_gb" >&2
  exit 3
}
record resource_gate PASS "load=${load1};memory_gb=${memory_gb};disk_gb=${disk_gb}"

record package_install STARTED "CRAN exdqlm 1.1.1"
cp --reflink=auto "$source_tarball" "$tarball"
"$r_binary" CMD INSTALL --no-multiarch --library="$r_library" "$tarball" \
  > "${state_root}/package_install.log" 2>&1
"$rscript" --vanilla -e \
  'd<-packageDescription("exdqlm"); h<-c("make_df_mat",".exdqlm_regularize_cov",".exdqlm_regularize_var","p.fn","A.fn","B.fn","C.fn"); ok<-vapply(h,function(x)is.function(get0(x,asNamespace("exdqlm"),mode="function",inherits=FALSE)),logical(1)); stopifnot(d$Version=="1.1.1",d$Repository=="CRAN",all(ok)); print(d[c("Version","Repository")]); print(ok); print(.libPaths())' \
  > "${state_root}/package_preflight.log" 2>&1
record package_install PASS "version=1.1.1;repository=CRAN;sha256=${expected_tarball_sha}"

record materialization STARTED "hash-verifying 54 completed fit handoffs"
"$rscript" --vanilla \
  "$script_dir/manage_independent_qdesn_fixed_comparator_forecast_recovery_v1.R" \
  --action materialize --source-run-root "$source_run_root" \
  --run-root "$run_root" --tarball "$tarball"
manifest="${run_root}/manifests/job_manifest.csv"
jobs=$(( $(wc -l < "$manifest") - 1 ))
[[ "$jobs" -eq 54 ]] || { printf 'Expected 54 jobs; found %s.\n' "$jobs" >&2; exit 3; }
record materialization PASS "jobs=54;source_handoffs=54;refits=0"

record installed_namespace_smoke STARTED "DQLM and exDQLM terminal-origin forecast"
"$rscript" --vanilla \
  "$script_dir/smoke_independent_qdesn_fixed_comparator_forecast_recovery_v1.R" \
  --source-run-root "$source_run_root" \
  --output "${run_root}/manifests/installed_namespace_smoke.csv"
record installed_namespace_smoke PASS "models=2;terminal_origin=9970;horizon=30"

record launcher_dry_run STARTED "forecast-only manifest=${manifest}"
"$rscript" --vanilla \
  "$script_dir/launch_exdqlm_dynamic_fitforecast_v2_validation.R" \
  --manifest "$manifest" --phase mcmc_tt500 --workers "$workers" \
  --validation-stage forecast-only --dry-run \
  > "${state_root}/launcher_dry_run.log" 2>&1
grep -q 'selected_rows: 54' "${state_root}/launcher_dry_run.log" || {
  printf 'Launcher dry run did not select all 54 recovery rows.\n' >&2
  exit 3
}
record launcher_dry_run PASS "selected_rows=54;validation_stage=forecast-only"

record forecast_recovery STARTED "jobs=54;workers=15;threads_per_job=1;refits=0"
taskset -c "$cpu_set" env EXDQLM_FFV2_LAUNCH_APPROVED=true \
  "$rscript" --vanilla \
  "$script_dir/launch_exdqlm_dynamic_fitforecast_v2_validation.R" \
  --manifest "$manifest" --phase mcmc_tt500 --workers "$workers" \
  --validation-stage forecast-only
record forecast_recovery PASS "launcher_exit=0"

record health STARTED "post-recovery status audit"
"$rscript" --vanilla \
  "$script_dir/manage_independent_qdesn_fixed_comparator_forecast_recovery_v1.R" \
  --action health --source-run-root "$source_run_root" --run-root "$run_root" \
  | tee "${state_root}/final_health.log"
grep -q 'done=54 running=0 failed=0 remaining=0' "${state_root}/final_health.log" || {
  printf 'Final health gate did not confirm 54/54 successful jobs.\n' >&2
  exit 4
}
record health PASS "done=54;failed=0;remaining=0"

record closeout STARTED "four-model matched-lattice aggregation"
"$rscript" --vanilla \
  "$script_dir/manage_independent_qdesn_fixed_comparator_forecast_recovery_v1.R" \
  --action closeout --source-run-root "$source_run_root" --run-root "$run_root"
record closeout PASS "matched comparison complete;cleanup deferred"

record diagnostics STARTED "ignored four-model review PDF"
"$rscript" --vanilla \
  "$script_dir/build_independent_qdesn_fixed_comparator_stride1_v1_diagnostics.R" \
  --run-root "$run_root"
record diagnostics PASS "review packet complete"

find "$run_root" -type f \( -iname '*.rds' -o -iname '*.rda' -o -iname '*.rdata' \
  -o -iname '*.ffv2handoff' \) -printf '%s\t%p\n' | sort -nr \
  > "${state_root}/heavy_binary_audit.tsv"
[[ ! -s "${state_root}/heavy_binary_audit.tsv" ]] || {
  printf 'Unexpected recovery-owned binary payloads remain.\n' >&2
  exit 4
}
source_handoffs=$(find "$source_run_root" -type f -name '*.ffv2handoff' | wc -l)
[[ "$source_handoffs" -eq 54 ]] || {
  printf 'Source handoff retention changed during recovery.\n' >&2
  exit 4
}
record storage_audit PASS "recovery_binaries=0;source_handoffs_retained=54"

printf 'status=SUCCESS ended_at=%s\n' "$(date --iso-8601=seconds)" > "$status_file"
record pipeline_complete PASS "ready_for_scientific_review;article_untouched"
trap - EXIT INT TERM
printf 'FORECAST_RECOVERY_COMPLETE run_root=%s\n' "$run_root"
