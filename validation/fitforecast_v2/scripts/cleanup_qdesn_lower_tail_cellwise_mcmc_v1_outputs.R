#!/usr/bin/env Rscript

suppressPackageStartupMessages(requireNamespace("jsonlite", quietly = TRUE))

args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) default else args[[index[[1L]] + 1L]]
}
execute <- "--execute" %in% args
repo_root <- normalizePath(
  arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)

expected_branch <- "validation/qdesn-lower-tail-cellwise-mcmc-v1-1.0.0"
run_id <- "qdesn_lower_tail_cellwise_mcmc_v1_tiera_20260811_215538"
run_tag <- "qdesn-lower-tail-cellwise-mcmc-v1-tiera-20260811_215538__git-c050ccf"
stage <- "qdesn_dynamic_fitforecast_v2_500obs_lower_tail_cellwise_mcmc_v1"
result_root <- file.path(
  repo_root, "results", "qdesn_mcmc_validation", stage
)
campaign_root <- file.path(result_root, run_tag)
jobs_root <- file.path(campaign_root, "jobs")
state_root <- file.path(
  repo_root, "reports", "shared_fitforecast_v2_orchestration", run_id
)
evidence_dir <- file.path(
  repo_root, "validation", "fitforecast_v2", "docs",
  "qdesn_lower_tail_cellwise_mcmc_v1_cleanup_20260813"
)
dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)

read_json <- function(path) {
  jsonlite::read_json(path, simplifyVector = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
bytes <- function(paths) {
  if (!length(paths)) return(0)
  sum(as.numeric(file.info(paths)$size), na.rm = TRUE)
}
files_under <- function(path) {
  unlist(lapply(path, function(one_path) {
    if (!dir.exists(one_path)) return(character())
    list.files(one_path, recursive = TRUE, full.names = TRUE, all.files = TRUE,
               no.. = TRUE, include.dirs = FALSE)
  }), use.names = FALSE)
}
write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
format_gib <- function(value) sprintf("%.3f", value / 1024^3)

branch <- system("git branch --show-current", intern = TRUE)
if (!identical(branch, expected_branch)) {
  stop(sprintf("Cleanup is restricted to branch %s; found %s.",
               expected_branch, branch), call. = FALSE)
}
if (!dir.exists(jobs_root) || !dir.exists(state_root)) {
  stop("The exact completed campaign roots are required.", call. = FALSE)
}
closeout <- read_json(file.path(state_root, "confirmation", "confirmation_closeout.json"))
verification <- read_json(file.path(state_root, "confirmation_verification.json"))
if (!identical(closeout$decision, "NO_CONFIRMED_GAIN_RETAIN_V6") ||
    !identical(verification$decision, "PASS")) {
  stop("The negative canonical closeout and passing verification are required.",
       call. = FALSE)
}

process_lines <- system("ps -eo pid=,args=", intern = TRUE)
active <- process_lines[
  grepl(run_tag, process_lines, fixed = TRUE) &
    !grepl("cleanup_qdesn_lower_tail_cellwise_mcmc_v1_outputs", process_lines,
           fixed = TRUE)
]
tmux_lines <- tryCatch(system("tmux list-sessions", intern = TRUE,
                              ignore.stderr = TRUE), error = function(e) character())
active_tmux <- tmux_lines[grepl("lower_tail_cellwise_mcmc_v1", tmux_lines,
                               fixed = TRUE)]
if (length(active) || length(active_tmux)) {
  stop(sprintf("Refusing cleanup: active task references found:\n%s",
               paste(c(active, active_tmux), collapse = "\n")), call. = FALSE)
}

job_roots <- sort(list.dirs(jobs_root, recursive = FALSE, full.names = TRUE))
confirmation <- grepl("^tier_a_confirmation__", basename(job_roots))
if (length(job_roots) != 218L || sum(confirmation) != 6L) {
  stop(sprintf("Expected 218 roots with 6 protected confirmations; found %d and %d.",
               length(job_roots), sum(confirmation)), call. = FALSE)
}
status_paths <- file.path(job_roots, "job_status.json")
statuses <- vapply(status_paths, function(path) {
  if (!file.exists(path)) return("MISSING")
  as.character(read_json(path)$status)
}, character(1L))
if (!all(statuses == "SUCCESS")) {
  stop("Every job must have a SUCCESS status before cleanup.", call. = FALSE)
}

delete_relpaths <- c(
  "latent_v_trace.csv",
  "theta_trace.csv",
  "sigmagam_trace.csv",
  file.path("tables", "fit_quantile_path_train.csv"),
  file.path("tables", "fit_quantile_path_holdout.csv"),
  file.path("tables", "forecast_rolling_origin_paths.csv")
)
nonconfirmation_roots <- job_roots[!confirmation]
delete_paths <- sort(unlist(lapply(nonconfirmation_roots, function(root) {
  file.path(root, delete_relpaths)
}), use.names = FALSE))
delete_paths <- delete_paths[file.exists(delete_paths)]
expected_delete_count <- length(nonconfirmation_roots) * length(delete_relpaths)

delete_manifest_path <- file.path(evidence_dir, "cleanup_dry_run_delete_manifest.csv")
progress_manifest_path <- file.path(evidence_dir, "cleanup_dry_run_progress_manifest.csv")
removed_path <- file.path(evidence_dir, "cleanup_removed_files.csv")
compaction_path <- file.path(evidence_dir, "progress_trace_compaction_audit.csv")
classification_path <- file.path(evidence_dir, "artifact_classification.csv")
summary_path <- file.path(evidence_dir, "cleanup_summary.md")

progress_paths <- file.path(job_roots, "progress_trace.csv")
if (!all(file.exists(progress_paths))) {
  stop("All 218 progress traces must exist before compaction.", call. = FALSE)
}

compact_preview <- function(path, stride = 50L, replace = FALSE) {
  before_hash <- sha256(path)
  before_bytes <- as.numeric(file.info(path)$size)
  trace <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  if (!"step" %in% names(trace) || !nrow(trace)) {
    return(data.frame(
      path = path, rows_before = nrow(trace), rows_after = nrow(trace),
      bytes_before = before_bytes, bytes_after = before_bytes,
      sha256_before = before_hash, sha256_after = before_hash,
      disposition = "kept_unmodified_no_step_rows", stringsAsFactors = FALSE
    ))
  }
  step <- suppressWarnings(as.integer(trace$step))
  keep <- seq_len(nrow(trace)) %in% c(1L, nrow(trace)) |
    (is.finite(step) & step %% stride == 0L)
  finite_step <- step[is.finite(step)]
  if (length(finite_step)) {
    keep <- keep | step == min(finite_step) | step == max(finite_step)
  }
  compact <- trace[keep, , drop = FALSE]
  temporary <- tempfile("ltcv1-progress-", tmpdir = dirname(path), fileext = ".csv")
  on.exit(unlink(temporary), add = TRUE)
  utils::write.csv(compact, temporary, row.names = FALSE, na = "")
  after_bytes <- as.numeric(file.info(temporary)$size)
  after_hash <- sha256(temporary)
  if (replace) {
    if (!file.rename(temporary, path)) {
      stop(sprintf("Could not atomically replace progress trace: %s", path),
           call. = FALSE)
    }
  }
  data.frame(
    path = path, rows_before = nrow(trace), rows_after = nrow(compact),
    bytes_before = before_bytes, bytes_after = after_bytes,
    sha256_before = before_hash, sha256_after = after_hash,
    disposition = "compacted_keep_first_final_and_stride50",
    stringsAsFactors = FALSE
  )
}

if (!execute) {
  if (length(delete_paths) != expected_delete_count) {
    stop(sprintf("Expected %d deletion candidates; found %d.",
                 expected_delete_count, length(delete_paths)), call. = FALSE)
  }
  delete_manifest <- data.frame(
    path = delete_paths,
    size_bytes = as.numeric(file.info(delete_paths)$size),
    sha256 = vapply(delete_paths, sha256, character(1L)),
    classification = "old_regenerable_nonpromoted_dense_output",
    planned_action = "delete",
    reason = paste(
      "non-confirmation raw trace or dense path export; scalar metrics,",
      "lead summaries, logs, manifests, statuses, and confirmation evidence retained"
    ),
    stringsAsFactors = FALSE
  )
  progress_manifest <- do.call(rbind, lapply(progress_paths, compact_preview))
  write_csv(delete_manifest, delete_manifest_path)
  write_csv(progress_manifest, progress_manifest_path)
} else {
  if (!file.exists(delete_manifest_path) || !file.exists(progress_manifest_path)) {
    stop("Run the default dry-run mode before --execute.", call. = FALSE)
  }
  delete_manifest <- utils::read.csv(delete_manifest_path,
                                     stringsAsFactors = FALSE, check.names = FALSE)
  progress_manifest <- utils::read.csv(progress_manifest_path,
                                       stringsAsFactors = FALSE, check.names = FALSE)
  if (!identical(sort(delete_manifest$path), delete_paths) ||
      length(delete_paths) != expected_delete_count) {
    stop("The current deletion candidates do not match the dry-run manifest.",
         call. = FALSE)
  }
  delete_ok <- vapply(seq_len(nrow(delete_manifest)), function(i) {
    path <- delete_manifest$path[[i]]
    file.exists(path) &&
      identical(as.numeric(file.info(path)$size),
                as.numeric(delete_manifest$size_bytes[[i]])) &&
      identical(sha256(path), delete_manifest$sha256[[i]])
  }, logical(1L))
  progress_ok <- vapply(seq_len(nrow(progress_manifest)), function(i) {
    path <- progress_manifest$path[[i]]
    file.exists(path) && identical(sha256(path), progress_manifest$sha256_before[[i]])
  }, logical(1L))
  if (!all(delete_ok) || !all(progress_ok)) {
    stop("At least one candidate changed after dry-run; no cleanup was executed.",
         call. = FALSE)
  }
  removed <- delete_manifest[, c("path", "size_bytes", "sha256"), drop = FALSE]
  removed$removed_at_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  unlink(delete_manifest$path)
  if (any(file.exists(delete_manifest$path))) {
    stop("At least one whitelisted candidate could not be removed.", call. = FALSE)
  }
  compaction <- do.call(rbind, lapply(progress_paths, compact_preview, replace = TRUE))
  expected_after <- setNames(progress_manifest$sha256_after, progress_manifest$path)
  if (!all(compaction$sha256_after == expected_after[compaction$path])) {
    stop("Progress compaction differed from the dry-run preview.", call. = FALSE)
  }
  write_csv(removed, removed_path)
  write_csv(compaction, compaction_path)
}

delete_manifest <- utils::read.csv(delete_manifest_path, stringsAsFactors = FALSE,
                                   check.names = FALSE)
progress_manifest <- utils::read.csv(progress_manifest_path, stringsAsFactors = FALSE,
                                     check.names = FALSE)
delete_bytes <- sum(delete_manifest$size_bytes)
progress_recovery <- sum(progress_manifest$bytes_before - progress_manifest$bytes_after)

classification <- data.frame(
  path_pattern = c(
    file.path(state_root, "**"),
    file.path(result_root, "source_replicates", "**"),
    file.path(result_root, "staged_source_windows", "**"),
    file.path(jobs_root, "tier_a_confirmation__*", "**"),
    file.path(jobs_root, "non-confirmation", "{configs,manifests,status,logs,scalar metrics,lead summaries}"),
    file.path(jobs_root, "non-confirmation", "{raw traces,dense fit/forecast paths}"),
    file.path(jobs_root, "*", "progress_trace.csv"),
    file.path(result_root, "qdesn-ltcv1-precommit-smoke-20260811", "**")
  ),
  ownership = "independent single-quantile Q-DESN/exQ-DESN validation",
  classification = c(
    "authoritative_closeout_evidence", "frozen_source_provenance",
    "frozen_source_windows", "canonical_confirmation_evidence",
    "reproducibility_metadata_and_compact_metrics",
    "old_regenerable_nonpromoted_dense_output", "compact_telemetry",
    "obsolete_but_small_precommit_smoke_evidence"
  ),
  action = c("keep", "keep", "keep", "keep", "keep", "delete",
             "compact_stride50", "keep"),
  reason = c(
    "rankings, plans, hashes, verification, and closeout are authoritative",
    "126 source archives are hash-declared inputs, not fitted-model payloads",
    "exact source-window evidence supports deterministic reruns",
    "six canonical chains directly support the no-promotion decision",
    "required to audit or reproduce each scalar comparison",
    "212 non-confirmation roots are closed and no metric was promoted",
    "preserve first, final, and every 50th iteration plus status files",
    "only 2.9 MiB; retention is safer than deleting marginal evidence"
  ),
  stringsAsFactors = FALSE
)
write_csv(classification, classification_path)

remaining_delete_candidates <- sum(file.exists(delete_manifest$path))
remaining_binary_jobs <- length(list.files(
  jobs_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
))
protected_confirmation_files <- files_under(job_roots[confirmation])
required_relpaths <- c(
  "job_status.json", "fit_summary_row.csv", "signoff_summary.csv",
  file.path("manifest", "output_retention.json"),
  file.path("tables", "forecast_lead_metrics.csv"),
  file.path("tables", "forecast_horizon_summary.csv")
)
required_paths <- unlist(lapply(job_roots, function(root) file.path(root, required_relpaths)),
                         use.names = FALSE)
if (!all(file.exists(required_paths)) || remaining_binary_jobs != 0L ||
    (execute && remaining_delete_candidates != 0L)) {
  stop("Post-cleanup evidence verification failed.", call. = FALSE)
}

summary <- c(
  "# Q-DESN lower-tail cellwise MCMC v1 storage cleanup",
  "",
  sprintf("- Mode: `%s`", if (execute) "execute" else "dry-run"),
  sprintf("- Generated: `%s`", format(Sys.time(), tz = "UTC", usetz = TRUE)),
  sprintf("- Branch: `%s`", branch),
  sprintf("- HEAD: `%s`", system("git rev-parse HEAD", intern = TRUE)),
  sprintf("- Campaign: `%s`", run_tag),
  sprintf("- Campaign roots verified: `%d/218` SUCCESS", length(job_roots)),
  sprintf("- Canonical confirmation roots protected: `%d/6`", sum(confirmation)),
  sprintf("- Deletion candidates: `%d` files, `%s GiB`", nrow(delete_manifest),
          format_gib(delete_bytes)),
  sprintf("- Progress traces: `%d` files, expected recovery `%s GiB`",
          nrow(progress_manifest), format_gib(progress_recovery)),
  sprintf("- Total expected recovery: `%s GiB`",
          format_gib(delete_bytes + progress_recovery)),
  sprintf("- Remaining eligible deletion files: `%d`", remaining_delete_candidates),
  sprintf("- Forbidden fitted-model binary payloads under jobs: `%d`",
          remaining_binary_jobs),
  sprintf("- Protected confirmation files currently present: `%d`",
          length(protected_confirmation_files)),
  "",
  "The cleanup preserves every source archive/window, canonical confirmation root,",
  "configuration, manifest, status, log, scalar metric, lead-level summary, ranking,",
  "verification record, and closeout file. It removes only hash-recorded raw traces",
  "and dense path exports from the 212 closed non-confirmation roots. Progress traces",
  "retain their first, final, and every 50th iteration; status files are untouched.",
  "",
  "## Evidence",
  "",
  "- `artifact_classification.csv`",
  "- `cleanup_dry_run_delete_manifest.csv`",
  "- `cleanup_dry_run_progress_manifest.csv`",
  if (execute) "- `cleanup_removed_files.csv`" else
    "- `cleanup_removed_files.csv` (created only by `--execute`)",
  if (execute) "- `progress_trace_compaction_audit.csv`" else
    "- `progress_trace_compaction_audit.csv` (created only by `--execute`)"
)
writeLines(summary, summary_path, useBytes = TRUE)

cat(sprintf(
  paste0("mode=%s roots=%d confirmation=%d delete_files=%d delete_gib=%s ",
         "progress_files=%d progress_recovery_gib=%s expected_total_gib=%s ",
         "remaining=%d\n"),
  if (execute) "execute" else "dry-run", length(job_roots), sum(confirmation),
  nrow(delete_manifest), format_gib(delete_bytes), nrow(progress_manifest),
  format_gib(progress_recovery), format_gib(delete_bytes + progress_recovery),
  remaining_delete_candidates
))
cat(sprintf("evidence=%s\n", evidence_dir))
