#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bin/kernel_patch_snapshot.sh snapshot LABEL [HOST ...]
  bin/kernel_patch_snapshot.sh diff BEFORE_DIR AFTER_DIR

Examples:
  bin/kernel_patch_snapshot.sh snapshot before muscat jerez
  bin/kernel_patch_snapshot.sh snapshot after muscat jerez
  bin/kernel_patch_snapshot.sh diff kernel_patch_snapshots/before_20260430_170000 kernel_patch_snapshots/after_20260430_173000

Notes:
  HOST can be a normal ssh target, such as muscat, jerez, user@muscat, or user@jerez.
  If no HOST is given, the snapshot is taken on the local machine.
EOF
}

timestamp() {
  date -u '+%Y%m%d_%H%M%S'
}

run_remote() {
  local host="$1"
  if [[ "$host" == "local" ]]; then
    bash -s
  else
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" 'bash -s'
  fi
}

collect_snapshot() {
  local host="$1"
  local outdir="$2"
  local safe_host
  safe_host="$(printf '%s' "$host" | tr '@/:' '___')"
  local outfile="$outdir/${safe_host}.txt"

  {
    printf '# Kernel patch snapshot\n'
    printf '# host_target: %s\n' "$host"
    printf '# collected_utc: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '\n'
  } >"$outfile"

  if ! run_remote "$host" >>"$outfile" <<'REMOTE_SNAPSHOT'
set -u

section() {
  printf '\n## %s\n' "$1"
}

run() {
  printf '\n$ %s\n' "$*"
  "$@" 2>&1 || printf '[command failed: %s]\n' "$*"
}

run_sh() {
  printf '\n$ %s\n' "$1"
  sh -c "$1" 2>&1 || printf '[command failed: %s]\n' "$1"
}

section "Identity and time"
run hostname -f
run date -u '+%Y-%m-%dT%H:%M:%SZ'
run uptime
run who -b

section "Kernel"
run uname -a
run uname -r
run_sh 'cat /proc/version'
run_sh 'cat /proc/cmdline'

section "Operating system"
if [ -r /etc/os-release ]; then
  run_sh 'cat /etc/os-release'
else
  run_sh 'lsb_release -a'
fi

section "Boot state"
run_sh 'systemctl --failed --no-pager'
run_sh 'systemctl list-jobs --no-pager'
run_sh 'last reboot -n 5'

section "Installed kernel packages"
if command -v rpm >/dev/null 2>&1; then
  run_sh "rpm -qa 'kernel*' | sort"
fi
if command -v dpkg-query >/dev/null 2>&1; then
  run_sh "dpkg-query -W -f='\${binary:Package}\t\${Version}\n' 'linux-image*' 'linux-headers*' 'linux-modules*' 2>/dev/null | sort"
fi

section "Pending package updates"
if command -v dnf >/dev/null 2>&1; then
  run_sh 'dnf check-update kernel\*'
elif command -v yum >/dev/null 2>&1; then
  run_sh 'yum check-update kernel\*'
elif command -v apt >/dev/null 2>&1; then
  run_sh 'apt list --upgradable 2>/dev/null | grep -E "^(linux-image|linux-headers|linux-modules|linux-generic|linux-aws|linux-cloud|linux-virtual|kernel)" || true'
fi

section "Bootloader kernel entries"
if command -v grubby >/dev/null 2>&1; then
  run grubby --default-kernel
  run_sh 'grubby --info=ALL'
elif command -v bootctl >/dev/null 2>&1; then
  run bootctl status
fi
run_sh 'ls -lah /boot 2>/dev/null | sed -n "1,120p"'

section "Loaded modules"
run_sh 'lsmod | sort'

section "Kernel taint and security context"
run_sh 'cat /proc/sys/kernel/tainted'
run_sh 'cat /sys/devices/system/cpu/vulnerabilities/* 2>/dev/null || true'

section "Recent kernel logs"
run_sh 'journalctl -k -b --no-pager -n 200 2>/dev/null || dmesg | tail -200'
REMOTE_SNAPSHOT
  then
    {
      printf '\n## Snapshot failed\n'
      printf 'Could not connect to %s or the remote snapshot command failed.\n' "$host"
      printf 'Try: ssh %s hostname -f\n' "$host"
    } >>"$outfile"
    printf 'Snapshot failed for %s; wrote diagnostic file %s\n' "$host" "$outfile" >&2
    return 1
  fi

  printf 'Wrote %s\n' "$outfile"
}

diff_snapshots() {
  local before="$1"
  local after="$2"
  if [[ ! -d "$before" || ! -d "$after" ]]; then
    printf 'Both arguments must be snapshot directories.\n' >&2
    exit 1
  fi
  diff -ruN "$before" "$after" || true
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local command="$1"
  shift

  case "$command" in
    snapshot)
      if [[ $# -lt 1 ]]; then
        usage
        exit 1
      fi
      local label="$1"
      shift
      local outdir="kernel_patch_snapshots/${label}_$(timestamp)"
      mkdir -p "$outdir"
      local failures=0
      if [[ $# -eq 0 ]]; then
        collect_snapshot "local" "$outdir" || failures=$((failures + 1))
      else
        local host
        for host in "$@"; do
          collect_snapshot "$host" "$outdir" || failures=$((failures + 1))
        done
      fi
      printf '\nSnapshot directory: %s\n' "$outdir"
      if [[ "$failures" -gt 0 ]]; then
        printf 'Completed with %s host failure(s).\n' "$failures" >&2
        exit 1
      fi
      ;;
    diff)
      if [[ $# -ne 2 ]]; then
        usage
        exit 1
      fi
      diff_snapshots "$1" "$2"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
