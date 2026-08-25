#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/prepare_independent_metric_interval_evidence_bundle_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
source_repo <- normalizePath(args$`source-repo` %||% "", winslash = "/", mustWork = TRUE)
output_root <- normalizePath(args$`output-root` %||% "", winslash = "/", mustWork = FALSE)
audit_dir <- normalizePath(args$`audit-dir` %||% imic_v1_audit_dir(repo_root),
                           winslash = "/", mustWork = FALSE)
if (!nzchar(output_root) || dir.exists(output_root) || file.exists(paste0(output_root, ".tar.gz"))) {
  stop("--output-root must identify a new bundle path with no existing archive.", call. = FALSE)
}

source_state <- file.path(source_repo, "reports", "shared_fitforecast_v2_orchestration",
                          imic_v1_production_run_id)
if (!dir.exists(source_state)) stop("The frozen production state root is missing.", call. = FALSE)
promotion_dir <- imic_v1_promotion_dir(repo_root)
job_audit <- ffv2_read_csv(file.path(promotion_dir, "job_artifact_audit.csv"))
if (nrow(job_audit) != 198L || any(!job_audit$checks_pass)) {
  stop("The promoted job audit is not the expected 198-job PASS authority.", call. = FALSE)
}

resolve_source_path <- function(path) {
  path <- as.character(path)[1L]
  if (file.exists(path)) return(normalizePath(path, winslash = "/", mustWork = TRUE))
  markers <- c("/results/", "/reports/", "/validation/", "/config/")
  for (marker in markers) {
    pos <- regexpr(marker, path, fixed = TRUE)[1L]
    if (pos > 0L) {
      candidate <- file.path(source_repo, substring(path, pos + 1L))
      if (file.exists(candidate)) {
        return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
      }
    }
  }
  stop(sprintf("Could not resolve frozen evidence path: %s", path), call. = FALSE)
}

ffv2_ensure_dir(output_root)
ledger_rows <- list()
ledger_i <- 0L
add_file <- function(source, relative_path, artifact_role, job_id = "") {
  source <- resolve_source_path(source)
  destination <- file.path(output_root, relative_path)
  observed_sha <- ffv2_file_sha256(source)
  imic_v1_copy_verified(source, destination, observed_sha)
  ledger_i <<- ledger_i + 1L
  ledger_rows[[ledger_i]] <<- data.frame(
    artifact_role = artifact_role,
    job_id = job_id,
    relative_path = relative_path,
    bytes = as.numeric(file.info(destination)$size),
    sha256 = observed_sha,
    stringsAsFactors = FALSE
  )
  invisible(destination)
}

for (i in seq_len(nrow(job_audit))) {
  row <- job_audit[i, , drop = FALSE]
  job_id <- as.character(row$job_id[[1L]])
  status_path <- file.path(source_state, "status", paste0(job_id, ".json"))
  status <- ffv2_read_json(status_path)
  if (!identical(as.character(status$status), "SUCCESS")) {
    stop(sprintf("Frozen job is not successful: %s", job_id), call. = FALSE)
  }
  files <- list(
    metric_draws = c(row$metric_draws_path[[1L]], "metric_draws.csv.gz"),
    metric_interval_summary = c(status$metric_interval_summary_path,
                                "metric_interval_summary.csv"),
    metric_interval_manifest = c(status$metric_interval_manifest_path,
                                 "metric_interval_manifest.json"),
    frozen_config = c(status$config_path, "config.json"),
    terminal_status = c(status_path, "status.json")
  )
  for (role in names(files)) {
    add_file(files[[role]][[1L]], file.path("jobs", job_id, files[[role]][[2L]]),
             role, job_id)
  }
}

source_files <- list.files(file.path(source_state, "sources"), recursive = TRUE,
                           full.names = TRUE, all.files = FALSE)
source_files <- source_files[file.info(source_files)$isdir %in% FALSE]
for (path in source_files) {
  rel <- substring(path, nchar(file.path(source_state, "sources")) + 2L)
  add_file(path, file.path("source_inputs", rel), "staged_source_input")
}

campaign_files <- list.files(file.path(source_state, "manifests"), recursive = TRUE,
                             full.names = TRUE, all.files = FALSE)
campaign_files <- campaign_files[file.info(campaign_files)$isdir %in% FALSE]
for (path in campaign_files) {
  rel <- substring(path, nchar(file.path(source_state, "manifests")) + 2L)
  add_file(path, file.path("campaign_manifests", rel), "campaign_manifest")
}

promotion_files <- list.files(promotion_dir, recursive = TRUE, full.names = TRUE,
                              all.files = FALSE)
promotion_files <- promotion_files[file.info(promotion_files)$isdir %in% FALSE]
for (path in promotion_files) {
  rel <- substring(path, nchar(promotion_dir) + 2L)
  add_file(path, file.path("promotion", rel), "tracked_promotion")
}

file_ledger <- do.call(rbind, ledger_rows)
file_ledger <- file_ledger[order(file_ledger$relative_path), , drop = FALSE]
metadata <- list(
  schema_version = "independent_metric_interval_portable_evidence_bundle_v1",
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  promotion_id = imic_v1_promotion_id,
  production_run_id = imic_v1_production_run_id,
  source_branch_head = system2("git", c("-C", source_repo, "rev-parse", "HEAD"),
                               stdout = TRUE)[[1L]],
  builder_branch_head = system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                                stdout = TRUE)[[1L]],
  payload_files = nrow(file_ledger),
  metric_draw_files = sum(file_ledger$artifact_role == "metric_draws"),
  payload_bytes = sum(file_ledger$bytes),
  fitted_model_binary_count = 0L,
  promotion_manifest_sha256 = ffv2_file_sha256(
    file.path(promotion_dir, "promotion_manifest.json")
  )
)
metadata_path <- ffv2_write_json(metadata, file.path(output_root, "bundle_metadata.json"))
file_ledger <- rbind(file_ledger, data.frame(
  artifact_role = "bundle_metadata", job_id = "", relative_path = "bundle_metadata.json",
  bytes = as.numeric(file.info(metadata_path)$size), sha256 = ffv2_file_sha256(metadata_path),
  stringsAsFactors = FALSE
))
ledger_path <- ffv2_write_csv(file_ledger, file.path(output_root, "bundle_file_manifest.csv"))

archive_path <- paste0(output_root, ".tar.gz")
tar_bin <- Sys.which("tar")
gzip_bin <- Sys.which("gzip")
if (!nzchar(tar_bin) || !nzchar(gzip_bin)) stop("tar and gzip are required.", call. = FALSE)
parent <- dirname(output_root)
base <- basename(output_root)
command <- sprintf(
  "%s --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner -cf - -C %s %s | %s -n > %s",
  shQuote(tar_bin), shQuote(parent), shQuote(base), shQuote(gzip_bin), shQuote(archive_path)
)
status <- system2("bash", c("-c", shQuote(command)))
if (status != 0L || !file.exists(archive_path)) stop("Portable archive creation failed.", call. = FALSE)

ffv2_ensure_dir(audit_dir)
file.copy(ledger_path, file.path(audit_dir, "portable_bundle_file_manifest.csv"),
          overwrite = TRUE)
locator <- list(
  schema_version = imic_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  archive_filename = basename(archive_path),
  local_archive_path = normalizePath(archive_path, winslash = "/", mustWork = TRUE),
  archive_bytes = as.numeric(file.info(archive_path)$size),
  archive_sha256 = ffv2_file_sha256(archive_path),
  bundle_root = normalizePath(output_root, winslash = "/", mustWork = TRUE),
  bundle_file_manifest_sha256 = ffv2_file_sha256(ledger_path),
  payload_files = nrow(file_ledger),
  metric_draw_files = sum(file_ledger$artifact_role == "metric_draws")
)
ffv2_write_json(locator, file.path(audit_dir, "portable_bundle_locator.json"))
cat(sprintf("bundle=%s files=%d metric_draws=%d archive_bytes=%.0f sha256=%s\n",
            archive_path, locator$payload_files, locator$metric_draw_files,
            locator$archive_bytes, locator$archive_sha256))
