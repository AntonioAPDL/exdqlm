#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(pwd)}"
remote_host="${JEREZ_HOST:-jaguir26@jerez.be.ucsc.edu}"
remote_repo_root="${JEREZ_EXDQLM_ROOT:-/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp}"

catalog="${repo_root}/tools/merge_reports/20260312_family_qspec_root_catalog.tsv"
out_tsv="${repo_root}/tools/merge_reports/20260312_family_qspec_jerez_root_audit.tsv"
summary_tsv="${repo_root}/tools/merge_reports/20260312_family_qspec_jerez_root_audit_summary.tsv"

if [[ ! -f "$catalog" ]]; then
  echo "Missing root catalog: $catalog" >&2
  exit 1
fi

printf 'root_id\troot_kind\tfamily\ttau\tfit_size\tprior\tprepared_present\trun_root\tmodel_a_complete\tmodel_b_complete\troot_postprocess_complete\troot_review_complete\troot_state\n' > "$out_tsv"

tail -n +2 "$catalog" | while IFS=$'\t' read -r root_id root_kind family tau fit_axis fit_size fit_label prior prepared_root run_root model_a model_b rest; do
  remote_line="$({
    ssh -o BatchMode=yes "$remote_host" bash -s -- "$remote_repo_root" "$root_kind" "$tau" "$fit_size" "$prior" "$prepared_root" "$run_root" "$model_a" "$model_b" <<'REMOTE'
set -euo pipefail
remote_repo_root="$1"
root_kind="$2"
tau="$3"
fit_size="$4"
prior="$5"
prepared_root="$6"
run_root="$7"
model_a="$8"
model_b="$9"

tau_tag="${tau/./p}"
prep_abs="${remote_repo_root}/${prepared_root}"
run_abs="${remote_repo_root}/${run_root}"

check_event() {
  local path="$1"
  local event="$2"
  [[ -f "$path" ]] && grep -Eq $'\t'"${event}"$'(\t|$)' "$path"
}

model_complete() {
  local model="$1"
  local vb_fit="${run_abs}/fits/vb/vb_${model}_tau_${tau_tag}_fit.rds"
  local mc_fit="${run_abs}/fits/mcmc/mcmc_${model}_tau_${tau_tag}_fit.rds"
  local mc_sum="${run_abs}/derived/mcmc_${model}_tau_${tau_tag}_summary.rds"
  local status_tsv="${run_abs}/logs/${model}_tau_${tau_tag}.status.tsv"
  if [[ -f "$vb_fit" && -f "$mc_fit" ]] && ([[ -f "$mc_sum" ]] || check_event "$status_tsv" "MCMC_DONE"); then
    printf 'TRUE'
  else
    printf 'FALSE'
  fi
}

post_ok=TRUE
for path in \
  "${run_abs}/tables/fit_summary.csv" \
  "${run_abs}/tables/vb_convergence_summary.csv" \
  "${run_abs}/tables/vb_ld_diagnostics_summary.csv" \
  "${run_abs}/tables/mcmc_diagnostics_summary.csv" \
  "${run_abs}/tables/metrics_summary.csv"; do
  [[ -f "$path" ]] || post_ok=FALSE
done
if [[ "$root_kind" != "dynamic" ]]; then
  [[ -f "${run_abs}/tables/rhs_diagnostics_summary.csv" ]] || post_ok=FALSE
fi

if [[ "$root_kind" == "dynamic" ]]; then
  review_ok="$post_ok"
else
  review_ok=TRUE
  for path in \
    "${run_abs}/tables/pairwise_exal_vs_al.csv" \
    "${run_abs}/tables/runtime_diagnostics_summary.csv" \
    "${run_abs}/tables/acceptance_gate_summary.csv" \
    "${run_abs}/tables/fit_metrics_by_task.csv" \
    "${run_abs}/tables/report_summary.md"; do
    [[ -f "$path" ]] || review_ok=FALSE
  done
fi

any_artifact=FALSE
if [[ -d "$run_abs" ]] && find "$run_abs" -mindepth 1 -print -quit | grep -q .; then
  any_artifact=TRUE
fi

state="missing"
if [[ "$review_ok" == TRUE ]]; then
  state="complete"
elif [[ "$any_artifact" == TRUE ]]; then
  state="partial"
fi

printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$([[ -f "${prep_abs}/sim_output.rds" ]] && echo TRUE || echo FALSE)" \
  "$(model_complete "$model_a")" \
  "$(model_complete "$model_b")" \
  "$post_ok" \
  "$review_ok" \
  "$state"
REMOTE
  } | tail -n 1)"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$root_id" "$root_kind" "$family" "$tau" "$fit_size" "$prior" "$remote_line" "$run_root" >> "$out_tsv.tmp"
done

awk -F'\t' '{print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7"\t"$13"\t"$8"\t"$9"\t"$10"\t"$11"\t"$12}' "$out_tsv.tmp" >> "$out_tsv"
rm -f "$out_tsv.tmp"

awk -F'\t' 'NR>1{c[$13]++} END {print "root_state\tcount"; for (k in c) print k"\t"c[k]}' "$out_tsv" | sort > "$summary_tsv"

echo "Wrote:"
echo "$out_tsv"
echo "$summary_tsv"
