#!/usr/bin/env Rscript

sha256_file <- function(path) {
  output <- system2("sha256sum", shQuote(normalizePath(path)), stdout = TRUE)
  if (!length(output)) stop("sha256sum produced no output for ", path, call. = FALSE)
  strsplit(output[[1L]], "[[:space:]]+")[[1L]][[1L]]
}

args <- commandArgs(trailingOnly = TRUE)
packet_dir <- if (length(args)) {
  args[[1L]]
} else {
  "validation/fitforecast_v2/promotions/independent_exdqlm_1p1p1_cran_release_addendum_20260828"
}
packet_dir <- normalizePath(packet_dir, mustWork = TRUE)

required <- c(
  "README.md",
  "relevant_source_hash_comparison.csv",
  "behavioral_compatibility_checks.csv",
  "focused_upstream_test_summary.csv",
  "cran_release_manifest.json",
  "artifact_manifest.csv"
)
missing <- required[!file.exists(file.path(packet_dir, required))]
if (length(missing)) {
  stop("Missing CRAN addendum files: ", paste(missing, collapse = ", "), call. = FALSE)
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required", call. = FALSE)
}

checks <- utils::read.csv(
  file.path(packet_dir, "behavioral_compatibility_checks.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
sources <- utils::read.csv(
  file.path(packet_dir, "relevant_source_hash_comparison.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
tests <- utils::read.csv(
  file.path(packet_dir, "focused_upstream_test_summary.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
artifacts <- utils::read.csv(
  file.path(packet_dir, "artifact_manifest.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
manifest <- jsonlite::read_json(
  file.path(packet_dir, "cran_release_manifest.json"),
  simplifyVector = TRUE
)

artifact_paths <- file.path(packet_dir, artifacts$path)
artifact_hashes <- vapply(artifact_paths, sha256_file, character(1L))

verification <- c(
  required_files_present = !length(missing),
  check_count_13 = nrow(checks) == 13L,
  all_behavioral_checks_pass = nrow(checks) > 0L && all(checks$pass),
  source_rows_9 = nrow(sources) == 9L,
  required_source_rows_identical = all(sources$exact_match[sources$exact_match_required]),
  focused_test_row_present = nrow(tests) == 1L,
  focused_tests_pass = nrow(tests) == 1L && isTRUE(tests$pass[[1L]]),
  focused_test_blocks_13 = identical(as.integer(tests$test_blocks[[1L]]), 13L),
  focused_test_expectations_111 = identical(as.integer(tests$passed_expectations[[1L]]), 111L),
  focused_test_failures_zero = identical(as.integer(tests$failed_expectations[[1L]]), 0L),
  focused_test_errors_zero = identical(as.integer(tests$errors[[1L]]), 0L),
  focused_test_warnings_zero = identical(as.integer(tests$warnings[[1L]]), 0L),
  focused_test_skips_zero = identical(as.integer(tests$skips[[1L]]), 0L),
  artifact_count_4 = nrow(artifacts) == 4L,
  artifact_hashes_match = identical(unname(artifact_hashes), artifacts$sha256),
  manifest_decision = identical(
    manifest$decision,
    "CRAN_1P1P1_PUBLIC_AUTHORITY_HISTORICAL_EXECUTION_PROVENANCE_RETAINED"
  ),
  manifest_public_version = identical(manifest$public_software_authority$version, "1.1.1"),
  manifest_public_repository = identical(manifest$public_software_authority$repository, "CRAN"),
  manifest_all_checks_pass = isTRUE(manifest$compatibility$all_checks_pass),
  manifest_no_rerun_required = identical(
    manifest$compatibility$scientific_rerun_required,
    FALSE
  )
)

if (!all(verification)) {
  stop(
    "CRAN addendum verification failed: ",
    paste(names(verification)[!verification], collapse = ", "),
    call. = FALSE
  )
}

cat(
  "CRAN_RELEASE_ADDENDUM_VERIFY_PASS ",
  sum(verification), "/", length(verification), "\n",
  sep = ""
)
