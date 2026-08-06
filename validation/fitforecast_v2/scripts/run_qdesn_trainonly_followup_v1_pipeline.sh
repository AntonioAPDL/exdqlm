#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:-qdesn_trainonly_followup_v1_$(date +%Y%m%d_%H%M%S)}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
MAX_LOAD="${MAX_LOAD:-50}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-96}"
MIN_DISK_GB="${MIN_DISK_GB:-250}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
cd "$REPO_ROOT"

STAGE="qdesn_dynamic_fitforecast_v2_500obs_trainonly_followup_v1"
CONFIG_STUB="config/validation/${STAGE}"
STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
mkdir -p "$STATE_ROOT"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
HEARTBEAT_CSV="$STATE_ROOT/heartbeat.csv"
CURRENT_STAGE_FILE="$STATE_ROOT/current_stage.txt"
LOCK_FILE="reports/shared_fitforecast_v2_orchestration/qdesn_trainonly_followup_v1.lock"
printf 'timestamp,stage,bundle,status,detail\n' > "$STATUS_CSV"
printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb\n' > "$HEARTBEAT_CSV"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then echo "Another train-only follow-up v1 pipeline holds $LOCK_FILE" >&2; exit 2; fi

set_stage() { printf '%s\n' "$1" > "$CURRENT_STAGE_FILE"; }
record_status() { printf '%s,%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "$3" "${4//,/;}" >> "$STATUS_CSV"; }
resource_values() {
  local l m d; l="$(awk '{print $1}' /proc/loadavg)"; m="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"; d="$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4}')"
  awk -v l="$l" -v m="$m" -v d="$d" 'BEGIN {printf "%.2f %.1f %.1f",l,m/1048576,d/1048576}'
}
write_heartbeat() { local x s; x="$(resource_values)"; s="$(cat "$CURRENT_STAGE_FILE" 2>/dev/null || printf initializing)"; printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "$s" "${x// /,}" >> "$HEARTBEAT_CSV"; }
heartbeat_loop() { while true; do write_heartbeat; sleep "$HEARTBEAT_SECONDS"; done; }
set_stage initializing; heartbeat_loop & HEARTBEAT_PID=$!
cleanup() { kill "$HEARTBEAT_PID" 2>/dev/null || true; wait "$HEARTBEAT_PID" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
wait_for_resources() {
  while true; do local x l m d; x="$(resource_values)"; read -r l m d <<< "$x"; write_heartbeat
    if awk -v l="$l" -v m="$m" -v d="$d" -v ml="$MAX_LOAD" -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" 'BEGIN {exit !((l<=ml)&&(m>=mm)&&(d>=md))}'; then
      record_status resource_gate all PASS "load=${l};memory_gb=${m};disk_gb=${d}"; return 0
    fi
    record_status resource_gate all WAIT "load=${l};memory_gb=${m};disk_gb=${d}"; sleep "$POLL_SECONDS"
  done
}
binary_audit() { local root="$1" out="$2"; if [[ ! -d "$root" ]]; then printf 'missing root\n' > "$out"; return 1; fi; find "$root" -type f \( -iname '*.rds' -o -iname '*.rda' -o -iname '*.rdata' -o -name '*.ffv2handoff' \) -printf '%s\t%p\n' | sort -nr > "$out"; [[ ! -s "$out" ]]; }

GIT_SHA="$(git rev-parse HEAD)"; GIT_SHORT="$(git rev-parse --short HEAD)"; STAMP="$(date +%Y%m%d_%H%M%S)"
declare -A TAGS WORKERS CPUS PIDS
BUNDLES=(al_raw al_raw_dev04 al_sr al_sr_dev04 exal_gsg_matched exal_gsg_dense exal_gsg_multistart)
TAGS[al_raw]="qdesn-tfv1-al-raw-full-${STAMP}__git-${GIT_SHORT}"; WORKERS[al_raw]=4; CPUS[al_raw]="0-3"
TAGS[al_raw_dev04]="qdesn-tfv1-al-raw-dev04-full-${STAMP}__git-${GIT_SHORT}"; WORKERS[al_raw_dev04]=4; CPUS[al_raw_dev04]="4-7"
TAGS[al_sr]="qdesn-tfv1-al-sr-full-${STAMP}__git-${GIT_SHORT}"; WORKERS[al_sr]=2; CPUS[al_sr]="8-9"
TAGS[al_sr_dev04]="qdesn-tfv1-al-sr-dev04-full-${STAMP}__git-${GIT_SHORT}"; WORKERS[al_sr_dev04]=2; CPUS[al_sr_dev04]="10-11"
TAGS[exal_gsg_matched]="qdesn-tfv1-exal-gsg-matched-${STAMP}__git-${GIT_SHORT}"; WORKERS[exal_gsg_matched]=4; CPUS[exal_gsg_matched]="12-15"
TAGS[exal_gsg_dense]="qdesn-tfv1-exal-gsg-dense-${STAMP}__git-${GIT_SHORT}"; WORKERS[exal_gsg_dense]=4; CPUS[exal_gsg_dense]="16-19"
TAGS[exal_gsg_multistart]="qdesn-tfv1-exal-gsg-multistart-${STAMP}__git-${GIT_SHORT}"; WORKERS[exal_gsg_multistart]=4; CPUS[exal_gsg_multistart]="20-23"
COMPARATOR_PREFIX="qdesn-tfv1-c13-${STAMP}__git-${GIT_SHORT}"
cat > "$STATE_ROOT/run_tags.env" <<EOF
RUN_ID=$RUN_ID
AL_RAW_RUN_TAG=${TAGS[al_raw]}
AL_RAW_DEV04_RUN_TAG=${TAGS[al_raw_dev04]}
AL_SR_RUN_TAG=${TAGS[al_sr]}
AL_SR_DEV04_RUN_TAG=${TAGS[al_sr_dev04]}
EXAL_GSG_MATCHED_RUN_TAG=${TAGS[exal_gsg_matched]}
EXAL_GSG_DENSE_RUN_TAG=${TAGS[exal_gsg_dense]}
EXAL_GSG_MULTISTART_RUN_TAG=${TAGS[exal_gsg_multistart]}
COMPARATOR_RUN_TAG_PREFIX=$COMPARATOR_PREFIX
GIT_COMMIT=$GIT_SHA
WORKTREE=$REPO_ROOT
TOTAL_MAX_WORKERS=28
CPU_POLICY=al_raw:0-3;al_raw_dev04:4-7;al_sr:8-9;al_sr_dev04:10-11;exal_matched:12-15;exal_dense:16-19;exal_multistart:20-23;comparators:24-27
EOF

set_stage contract_verify; record_status contract_verify all STARTED "36 Q-DESN plus 4 structured roots"
"$R_SCRIPT" validation/fitforecast_v2/scripts/verify_qdesn_trainonly_followup_v1.R --output "$STATE_ROOT/contract_verification.json" > "$STATE_ROOT/contract_verification.log" 2>&1
record_status contract_verify all COMPLETED contract_verification.json

COMMON=("$R_SCRIPT" scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R --allow-grid-subset --methods mcmc --priors rhs_ns --no-plots --stream-child-stdout --fit-timeout-seconds 43200 --fit-timeout-kill-after-seconds 60)
for bundle in "${BUNDLES[@]}"; do
  set_stage "${bundle}_prepare"; record_status prepare "$bundle" STARTED prepare-only
  "${COMMON[@]}" --workers 1 --defaults "${CONFIG_STUB}_${bundle}_defaults.yaml" --grid "${CONFIG_STUB}_${bundle}_grid.csv" --batch full --prepare-only --run-tag "qdesn-tfv1-${bundle}-prepare-${STAMP}__git-${GIT_SHORT}" > "$STATE_ROOT/${bundle}_prepare.log" 2>&1
  record_status prepare "$bundle" COMPLETED no-compute
  set_stage "${bundle}_smoke"; record_status smoke "$bundle" STARTED "four burn plus four retained"
  smoke_tag="qdesn-tfv1-${bundle}-smoke-${STAMP}__git-${GIT_SHORT}"
  "${COMMON[@]}" --workers 1 --defaults "${CONFIG_STUB}_${bundle}_defaults.yaml" --grid "${CONFIG_STUB}_${bundle}_grid.csv" --batch smoke --run-tag "$smoke_tag" > "$STATE_ROOT/${bundle}_smoke.log" 2>&1
  smoke_root="results/qdesn_mcmc_validation/${STAGE}_${bundle}/${smoke_tag}"
  binary_audit "$smoke_root" "$STATE_ROOT/${bundle}_smoke_binary_audit.tsv" || { record_status smoke "$bundle" FAILED binary-payload; exit 3; }
  record_status smoke "$bundle" COMPLETED storage-light
done

set_stage comparator_dryrun
"$R_SCRIPT" validation/fitforecast_v2/scripts/prepare_qdesn_trainonly_followup_v1_comparators.R --run-tag-prefix "${COMPARATOR_PREFIX}-dryrun" --state-root "$STATE_ROOT" --dry-run > "$STATE_ROOT/comparator_dryrun.log" 2>&1
record_status comparator_dryrun structured COMPLETED four-rows

set_stage comparator_smoke
"$R_SCRIPT" validation/fitforecast_v2/scripts/prepare_qdesn_trainonly_followup_v1_comparators.R --run-tag-prefix "${COMPARATOR_PREFIX}-smoke" --state-root "$STATE_ROOT" --smoke > "$STATE_ROOT/comparator_smoke_prepare.log" 2>&1
while IFS=$'\t' read -r role tag root manifest expected; do
  [[ "$role" == "source_role" ]] && continue
  EXDQLM_FFV2_LAUNCH_APPROVED=true "$R_SCRIPT" validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R --manifest "$manifest" --phase mcmc_tt500 --workers 2 > "$STATE_ROOT/comparator_${role}_smoke.log" 2>&1
  binary_audit "$root" "$STATE_ROOT/comparator_${role}_smoke_binary_audit.tsv" || { record_status comparator_smoke "$role" FAILED binary-payload; exit 3; }
done < "$STATE_ROOT/comparator_smoke_index.tsv"
record_status comparator_smoke structured COMPLETED storage-light

set_stage comparator_prepare
"$R_SCRIPT" validation/fitforecast_v2/scripts/prepare_qdesn_trainonly_followup_v1_comparators.R --run-tag-prefix "$COMPARATOR_PREFIX" --state-root "$STATE_ROOT" > "$STATE_ROOT/comparator_prepare.log" 2>&1
record_status comparator_prepare structured COMPLETED four-full-budget-rows

set_stage resource_gate; wait_for_resources
run_qdesn_bundle() {
  local b="$1"; record_status full "$b" STARTED "workers=${WORKERS[$b]};cpus=${CPUS[$b]};run_tag=${TAGS[$b]}"; set +e
  taskset -c "${CPUS[$b]}" "${COMMON[@]}" --workers "${WORKERS[$b]}" --defaults "${CONFIG_STUB}_${b}_defaults.yaml" --grid "${CONFIG_STUB}_${b}_grid.csv" --batch full --run-tag "${TAGS[$b]}" > "$STATE_ROOT/${b}_full.log" 2>&1
  local rc=$?; set -e; printf '%s\n' "$rc" > "$STATE_ROOT/${b}_exit_code.txt"; [[ $rc -eq 0 ]] && record_status full "$b" COMPLETED exit-code-0 || record_status full "$b" FAILED "exit-code=${rc}"; return $rc
}
set_stage full_parallel
for b in "${BUNDLES[@]}"; do run_qdesn_bundle "$b" & PIDS[$b]=$!; done
run_comparators() {
  local rc=0 role tag root manifest expected pid
  local -a comparator_pids=()
  record_status full comparators STARTED "four roots;workers=4;cpus=24-27"
  while IFS=$'\t' read -r role tag root manifest expected; do
    [[ "$role" == "source_role" ]] && continue
    taskset -c 24-27 env EXDQLM_FFV2_LAUNCH_APPROVED=true "$R_SCRIPT" validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R --manifest "$manifest" --phase mcmc_tt500 --workers 2 > "$STATE_ROOT/comparator_${role}_full.log" 2>&1 &
    comparator_pids+=("$!")
  done < "$STATE_ROOT/comparator_index.tsv"
  for pid in "${comparator_pids[@]}"; do wait "$pid" || rc=1; done
  [[ $rc -eq 0 ]] && record_status full comparators COMPLETED exit-code-0 || record_status full comparators FAILED child-failure
  return $rc
}
run_comparators & PIDS[comparators]=$!

ANY_FAILED=0; set +e
for b in "${BUNDLES[@]}" comparators; do wait "${PIDS[$b]}" || ANY_FAILED=1; done
set -e
set_stage storage_audit
for b in "${BUNDLES[@]}"; do
  root="results/qdesn_mcmc_validation/${STAGE}_${b}/${TAGS[$b]}"
  binary_audit "$root" "$STATE_ROOT/${b}_full_binary_audit.tsv" && record_status storage "$b" PASS no-binary-payloads || { record_status storage "$b" FAILED binary-payload; ANY_FAILED=1; }
done
while IFS=$'\t' read -r role tag root manifest expected; do
  [[ "$role" == "source_role" ]] && continue
  binary_audit "$root" "$STATE_ROOT/comparator_${role}_full_binary_audit.tsv" && record_status storage "comparator_${role}" PASS no-binary-payloads || { record_status storage "comparator_${role}" FAILED binary-payload; ANY_FAILED=1; }
done < "$STATE_ROOT/comparator_index.tsv"

set_stage closeout; set +e
"$R_SCRIPT" validation/fitforecast_v2/scripts/audit_qdesn_trainonly_followup_v1.R --state-root "$STATE_ROOT" --output-root "$STATE_ROOT/closeout" > "$STATE_ROOT/closeout.log" 2>&1
AUDIT_RC=$?; set -e
[[ $AUDIT_RC -eq 0 ]] && record_status closeout all COMPLETED followup_gate.json || { record_status closeout all FAILED "exit-code=${AUDIT_RC}"; ANY_FAILED=1; }
set_stage pipeline_complete; write_heartbeat
[[ $ANY_FAILED -eq 0 ]] && { record_status pipeline_complete all COMPLETED "40-root follow-up closed; article unchanged"; exit 0; }
record_status pipeline_complete all COMPLETED_WITH_FAILURES inspect-logs; exit 1
