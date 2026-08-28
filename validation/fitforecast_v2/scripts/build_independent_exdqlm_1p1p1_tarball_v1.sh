#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${HARNESS_ROOT}/../.." && pwd)"
EXPECTED_BRANCH="validation/independent-qdesn-exdqlm-1.1.1-rerun-20260827"
PACKAGE_COMMIT="6dba6f2863705e0e90f0ce19e0c75d106d022a52"
PACKAGE_VERSION="1.1.1"
TASK_TRACKER="${REPO_ROOT}/validation/fitforecast_v2/local_trackers/independent_qdesn_exdqlm_1p1p1_rerun_20260827"
OUTPUT_DIR="${OUTPUT_DIR:-${TASK_TRACKER}/package}"
TARBALL="${OUTPUT_DIR}/exdqlm_${PACKAGE_VERSION}.tar.gz"
BUILD_MANIFEST="${OUTPUT_DIR}/package_build_manifest.json"
R_BIN="${R_BIN:-$(command -v R)}"

branch="$(git -C "${REPO_ROOT}" branch --show-current)"
head="$(git -C "${REPO_ROOT}" rev-parse HEAD)"
tree="$(git -C "${REPO_ROOT}" rev-parse 'HEAD^{tree}')"
upstream_head="$(git -C "${REPO_ROOT}" rev-parse '@{u}')"
if [[ "${branch}" != "${EXPECTED_BRANCH}" ]]; then
  echo "Refusing unexpected branch: ${branch}" >&2
  exit 2
fi
if [[ -n "$(git -C "${REPO_ROOT}" status --short)" || "${head}" != "${upstream_head}" ]]; then
  echo "Refusing a dirty, unpushed, or divergent validation branch." >&2
  exit 2
fi
if ! git -C "${REPO_ROOT}" merge-base --is-ancestor "${PACKAGE_COMMIT}" HEAD; then
  echo "Required exdqlm 1.1.1 source commit is not an ancestor of HEAD." >&2
  exit 2
fi
version="$(sed -n 's/^Version:[[:space:]]*//p' "${REPO_ROOT}/DESCRIPTION" | head -n 1)"
if [[ "${version}" != "${PACKAGE_VERSION}" ]]; then
  echo "DESCRIPTION does not report exdqlm ${PACKAGE_VERSION}." >&2
  exit 2
fi

mkdir -p "${OUTPUT_DIR}"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/exdqlm-1p1p1-build.XXXXXX")"
trap 'rm -rf "${tmp_root}"' EXIT
source_root="${tmp_root}/source"
mkdir -p "${source_root}"
git -C "${REPO_ROOT}" archive --format=tar HEAD | tar -xf - -C "${source_root}"

(
  cd "${OUTPUT_DIR}"
  "${R_BIN}" CMD build "${source_root}" --no-build-vignettes --no-resave-data
)
if [[ ! -f "${TARBALL}" ]]; then
  echo "Expected tarball was not created: ${TARBALL}" >&2
  exit 2
fi
forbidden_paths="$(tar -tzf "${TARBALL}" | grep -E '^[^/]+/(reports|results|session_logs|tmux_logs)/' || true)"
if [[ -n "${forbidden_paths}" ]]; then
  echo "Tarball contains forbidden runtime paths:" >&2
  printf '%s\n' "${forbidden_paths}" >&2
  exit 2
fi

sha256="$(sha256sum "${TARBALL}" | awk '{print $1}')"
bytes="$(stat -c '%s' "${TARBALL}")"
file_count="$(tar -tzf "${TARBALL}" | wc -l)"
HEAD_COMMIT="${head}" HEAD_TREE="${tree}" PACKAGE_SOURCE_COMMIT="${PACKAGE_COMMIT}" \
  PACKAGE_VERSION_VALUE="${PACKAGE_VERSION}" TARBALL_PATH="${TARBALL}" \
  TARBALL_SHA256="${sha256}" TARBALL_BYTES="${bytes}" FILE_COUNT="${file_count}" \
  "${R_BIN}script" --vanilla - "${BUILD_MANIFEST}" <<'RS'
args <- commandArgs(trailingOnly = TRUE)
jsonlite::write_json(list(
  schema_version = "independent_exdqlm_1p1p1_package_build_v1",
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  git_commit = Sys.getenv("HEAD_COMMIT"),
  git_tree = Sys.getenv("HEAD_TREE"),
  package_source_commit = Sys.getenv("PACKAGE_SOURCE_COMMIT"),
  package_version = Sys.getenv("PACKAGE_VERSION_VALUE"),
  build_source = "git_archive_of_committed_tree",
  tarball_path = normalizePath(Sys.getenv("TARBALL_PATH"), winslash = "/", mustWork = TRUE),
  tarball_sha256 = Sys.getenv("TARBALL_SHA256"),
  tarball_bytes = as.numeric(Sys.getenv("TARBALL_BYTES")),
  tarball_files = as.integer(Sys.getenv("FILE_COUNT")),
  forbidden_runtime_paths = 0L
), args[[1L]], auto_unbox = TRUE, pretty = TRUE, null = "null", na = "string")
RS

printf 'tarball=%s sha256=%s bytes=%s files=%s head=%s\n' \
  "${TARBALL}" "${sha256}" "${bytes}" "${file_count}" "${head}"
