#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
out_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    --out-dir)
      out_dir="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

repo_root="$(cd "$repo_root" && pwd)"
stamp="$(date '+%Y%m%d_%H%M%S')"
if [[ -z "$out_dir" ]]; then
  out_dir="/home/jaguir26/local/state/exdqlm/family_qspec_targeted_repair_baseline_${stamp}"
fi
mkdir -p "$out_dir"

copy_file() {
  local rel="$1"
  local src="${repo_root}/${rel}"
  local dst="${out_dir}/$(basename "$rel")"
  if [[ ! -f "$src" ]]; then
    echo "Missing baseline input: $src" >&2
    exit 1
  fi
  cp -f "$src" "$dst"
  echo "$dst"
}

method_copy="$(copy_file "tools/merge_reports/20260314_family_qspec_method_signoff.tsv")"
copy_file "tools/merge_reports/20260314_family_qspec_signoff_summary.tsv" >/dev/null
copy_file "tools/merge_reports/20260315_family_qspec_post_repair_signoff_delta.tsv" >/dev/null
copy_file "tools/merge_reports/20260315_family_qspec_post_repair_delta_summary.md" >/dev/null

{
  echo "baseline_dir=${out_dir}"
  echo "baseline_method_signoff=${method_copy}"
} > "${out_dir}/baseline_paths.env"

echo "Baseline snapshot created: ${out_dir}"
echo "Method signoff baseline: ${method_copy}"
