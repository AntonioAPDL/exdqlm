#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
jobs="${EXDQLM_FQSG_REBUILD_JOBS:-8}"

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
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

repo_root="$(cd "$repo_root" && pwd)"

# shellcheck disable=SC1091
source "${repo_root}/tools/merge_reports/20260314_family_qspec_signoff_policy_recommended.env"
export EXDQLM_FQSG_REBUILD_JOBS="$jobs"

(
  cd "$repo_root"
  Rscript tools/merge_reports/20260314_build_family_qspec_signoff_views.R "$repo_root" --force
  Rscript tools/merge_reports/20260314_build_family_qspec_repair_queue.R "$repo_root" /home/jaguir26/local/state/exdqlm/family_qspec_repair_v1
)
