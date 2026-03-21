#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Fetch San Lorenzo USGS+covariate CSV into the repo-local external data staging path.

Usage:
  ./scripts/fetch_san_lorenzo_usgs_csv.sh [options]

Options:
  --remote-user USER   SSH user (default: jaguir26)
  --remote-host HOST   SSH host (default: jerez.be.ucsc.edu)
  --remote-path PATH   Remote CSV path
                       (default: /data/muscat_data/jaguir26/data/data_USGS_ppt_soil.csv)
  --dest PATH          Destination path, absolute or repo-relative
                       (default: data-raw/external/data_USGS_ppt_soil.csv)
  -h, --help           Show this help
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
remote_user="jaguir26"
remote_host="jerez.be.ucsc.edu"
remote_path="/data/muscat_data/jaguir26/data/data_USGS_ppt_soil.csv"
dest_path="data-raw/external/data_USGS_ppt_soil.csv"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote-user)
      remote_user="$2"; shift 2 ;;
    --remote-host)
      remote_host="$2"; shift 2 ;;
    --remote-path)
      remote_path="$2"; shift 2 ;;
    --dest)
      dest_path="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2 ;;
  esac
done

if [[ "$dest_path" = /* ]]; then
  dest_abs="$dest_path"
else
  dest_abs="$repo_root/$dest_path"
fi

mkdir -p "$(dirname "$dest_abs")"
tmp="${dest_abs}.tmp"

echo "[fetch] source: ${remote_user}@${remote_host}:${remote_path}"
echo "[fetch] dest:   ${dest_abs}"

scp -p "${remote_user}@${remote_host}:${remote_path}" "$tmp"
mv "$tmp" "$dest_abs"

echo "[fetch] done"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$dest_abs"
fi
