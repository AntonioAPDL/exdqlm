#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

repo_root="$(cd "$repo_root" && pwd)"

# shellcheck disable=SC1091
source "${repo_root}/tools/merge_reports/20260314_family_qspec_signoff_policy_recommended.env"
# shellcheck disable=SC1091
source "${repo_root}/tools/merge_reports/20260314_family_qspec_repair_tuning_recommended.env"

exec "${repo_root}/tools/merge_reports/20260314_family_qspec_repair_supervisor.sh" \
  --repo-root "$repo_root" \
  "$@"
