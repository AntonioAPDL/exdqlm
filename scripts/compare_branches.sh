#!/usr/bin/env bash
set -euo pipefail

BR1="${1:-origin/esn}"
BR2="${2:-origin/esn-server}"
OUT="${3:-branch_comparison.csv}"

# Collect file lists (tracked files only)
mapfile -d '' -t F1 < <(git ls-tree -r -z --name-only "$BR1")
mapfile -d '' -t F2 < <(git ls-tree -r -z --name-only "$BR2")

# Build union
declare -A U=()
for f in "${F1[@]}"; do U["$f"]=1; done
for f in "${F2[@]}"; do U["$f"]=1; done

echo "path,status,esn_sha,esn_bytes,esn_last_commit,esn_author,esn_date,esnserver_sha,esnserver_bytes,esnserver_last_commit,esnserver_author,esnserver_date" > "$OUT"

for f in "${!U[@]}"; do
  # BR1 info
  sha1="$(git ls-tree -r "$BR1" -- "$f" | awk '{print $3}' | head -n1 || true)"
  size1=""
  l1h=""; l1a=""; l1d=""
  if [[ -n "$sha1" ]]; then
    size1="$(git cat-file -s "$sha1" 2>/dev/null || true)"
    l1h="$(git log -1 --format='%h' "$BR1" -- "$f" 2>/dev/null || true)"
    l1a="$(git log -1 --format='%an' "$BR1" -- "$f" 2>/dev/null || true)"
    l1d="$(git log -1 --date=short --format='%ad' "$BR1" -- "$f" 2>/dev/null || true)"
  fi

  # BR2 info
  sha2="$(git ls-tree -r "$BR2" -- "$f" | awk '{print $3}' | head -n1 || true)"
  size2=""
  l2h=""; l2a=""; l2d=""
  if [[ -n "$sha2" ]]; then
    size2="$(git cat-file -s "$sha2" 2>/dev/null || true)"
    l2h="$(git log -1 --format='%h' "$BR2" -- "$f" 2>/dev/null || true)"
    l2a="$(git log -1 --format='%an' "$BR2" -- "$f" 2>/dev/null || true)"
    l2d="$(git log -1 --date=short --format='%ad' "$BR2" -- "$f" 2>/dev/null || true)"
  fi

  status="SAME"
  if [[ -z "$sha1" && -n "$sha2" ]]; then status="ONLY_IN_esn-server"; fi
  if [[ -n "$sha1" && -z "$sha2" ]]; then status="ONLY_IN_esn"; fi
  if [[ -n "$sha1" && -n "$sha2" && "$sha1" != "$sha2" ]]; then status="MODIFIED"; fi

  # CSV line
  echo "\"$f\",\"$status\",\"$sha1\",\"$size1\",\"$l1h\",\"$l1a\",\"$l1d\",\"$sha2\",\"$size2\",\"$l2h\",\"$l2a\",\"$l2d\"" >> "$OUT"
done
echo "Wrote $OUT"
