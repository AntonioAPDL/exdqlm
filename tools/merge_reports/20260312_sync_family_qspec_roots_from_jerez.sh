#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(pwd)}"
remote_host="${JEREZ_HOST:-jaguir26@jerez.be.ucsc.edu}"
remote_repo_root="${JEREZ_EXDQLM_ROOT:-/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp}"
manifest="${repo_root}/tools/merge_reports/20260312_family_qspec_jerez_sync_manifest.tsv"
results_tsv="${repo_root}/tools/merge_reports/20260312_family_qspec_jerez_sync_results.tsv"

if [[ ! -f "$manifest" ]]; then
  echo "Missing sync manifest: $manifest" >&2
  exit 1
fi

printf 'root_id\trun_root\taction\tstatus\tnote\n' > "$results_tsv"

tail -n +2 "$manifest" | while IFS=$'\t' read -r root_id root_kind family tau fit_size prior run_root jerez_state jerez_prepared muscat_review muscat_post muscat_models sync_action note; do
  if [[ "$sync_action" != "sync_root" ]]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$root_id" "$run_root" "$sync_action" "skipped" "$note" >> "$results_tsv"
    continue
  fi

  dest_dir="${repo_root}/${run_root}"
  if [[ -d "$dest_dir" ]] && find "$dest_dir" -mindepth 1 -print -quit | grep -q .; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$root_id" "$run_root" "$sync_action" "conflict_nonempty_dest" "Destination already contains files; manual review required." >> "$results_tsv"
    continue
  fi

  mkdir -p "$(dirname "$dest_dir")"
  rsync -a "$remote_host:$remote_repo_root/$run_root/" "$dest_dir/"
  printf '%s\t%s\t%s\t%s\t%s\n' "$root_id" "$run_root" "$sync_action" "synced" "Exact root copy from jerez completed." >> "$results_tsv"
done

echo "Wrote:"
echo "$results_tsv"
