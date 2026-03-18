#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
jobs="${EXDQLM_FQSG_REBUILD_JOBS:-8}"
baseline_method_signoff=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    --jobs)
      jobs="$2"
      shift 2
      ;;
    --baseline-method-signoff)
      baseline_method_signoff="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

repo_root="$(cd "$repo_root" && pwd)"
jobs="$(printf '%s' "$jobs" | sed 's/[^0-9].*$//')"
[[ -n "$jobs" ]] || jobs=8
if (( jobs < 1 )); then jobs=1; fi

if [[ -n "$baseline_method_signoff" && "$baseline_method_signoff" != /* ]]; then
  baseline_method_signoff="${repo_root}/${baseline_method_signoff}"
fi

(
  cd "$repo_root"
  "${repo_root}/tools/merge_reports/20260315_apply_family_qspec_second_wave_policy.sh" \
    --repo-root "$repo_root" \
    --jobs "$jobs"
  Rscript tools/merge_reports/20260315_analyze_family_qspec_post_repair_delta.R "$repo_root"
)

if [[ -n "$baseline_method_signoff" ]]; then
  if [[ ! -f "$baseline_method_signoff" ]]; then
    echo "Baseline method signoff not found: $baseline_method_signoff" >&2
    exit 1
  fi
  (
    cd "$repo_root"
    Rscript tools/merge_reports/20260317_analyze_family_qspec_targeted_effect.R \
      "$repo_root" \
      "$baseline_method_signoff"
  )
fi

echo "Signoff rebuild + delta complete."
