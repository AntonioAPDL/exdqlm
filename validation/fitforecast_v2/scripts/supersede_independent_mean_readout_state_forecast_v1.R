#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/supersede_independent_mean_readout_state_forecast_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))

args <- ffv2_parse_args()
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/",
                            mustWork = TRUE)
decision <- as.character(
  args$decision %||% "SUPERSEDED_BY_REDESIGNED_INDEPENDENT_PROTOCOL"
)[[1L]]
if (!identical(decision, "SUPERSEDED_BY_REDESIGNED_INDEPENDENT_PROTOCOL")) {
  stop("Unexpected supersession decision.", call. = FALSE)
}

health_path <- file.path(state_root, "health", "health_current.json")
jobs_path <- file.path(state_root, "health", "health_jobs.csv")
if (!file.exists(health_path) || !file.exists(jobs_path)) {
  stop("Run the campaign health checker before supersession.", call. = FALSE)
}
health <- jsonlite::read_json(health_path, simplifyVector = TRUE)
jobs <- ffv2_read_csv(jobs_path)
if (as.integer(health$running_total) != 0L ||
    as.integer(health$active_workers) != 0L ||
    any(as.character(jobs$status) == "RUNNING")) {
  stop("Cannot supersede a campaign while workers are active.", call. = FALSE)
}

closeout_root <- file.path(state_root, "closeout", "superseded_protocol_v1")
ffv2_ensure_dir(closeout_root)

frozen_jobs <- jobs
frozen_jobs$supersession_decision <- decision
frozen_jobs$article_consumption <- "refuse"
frozen_jobs_path <- ffv2_write_csv(
  frozen_jobs, file.path(closeout_root, "frozen_job_status.csv")
)

all_paths <- list.files(
  state_root, recursive = TRUE, full.names = TRUE, all.files = TRUE,
  no.. = TRUE
)
all_paths <- all_paths[file.exists(all_paths) & !dir.exists(all_paths)]
relative <- substring(all_paths, nchar(state_root) + 2L)
keep <- !startsWith(relative, "closeout/")
all_paths <- all_paths[keep]
relative <- relative[keep]
info <- file.info(all_paths)
artifact_manifest <- data.frame(
  relative_path = relative,
  evidence_class = sub("/.*$", "", relative),
  size_bytes = as.numeric(info$size),
  sha256 = vapply(all_paths, ffv2_file_sha256, character(1L)),
  stringsAsFactors = FALSE
)
artifact_manifest <- artifact_manifest[
  order(artifact_manifest$evidence_class, artifact_manifest$relative_path),
  , drop = FALSE
]
artifact_path <- ffv2_write_csv(
  artifact_manifest,
  file.path(closeout_root, "frozen_partial_evidence_manifest.csv")
)

git <- ffv2_git_info(ffv2_repo_root())
summary <- list(
  schema_version = "independent_mean_readout_state_supersession_v1",
  decision = decision,
  closed_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  state_root = state_root,
  scientific_status = "incomplete_protocol_superseded",
  article_consumption = "refuse",
  article_metrics_promoted = FALSE,
  active_workers_at_close = 0L,
  planned_total = as.integer(health$planned_total),
  completed_total = as.integer(health$completed_total),
  failed_total = as.integer(health$failed_total),
  remaining_total = as.integer(health$remaining_total),
  fit = health$fit,
  forecast = health$forecast,
  canary = health$canary,
  failed_job_ids = as.character(jobs$job_id[jobs$status == "FAILED"]),
  retained_reusable_scope = c(
    "mean_readout_state_forecast_implementation",
    "paired_path_vs_mean_recursion_tests",
    "health_and_manifest_infrastructure"
  ),
  excluded_scientific_scope = c(
    "partial_metrics",
    "partial_rankings",
    "article_tables",
    "article_figures"
  ),
  git = git,
  frozen_job_status_sha256 = ffv2_file_sha256(frozen_jobs_path),
  frozen_partial_evidence_manifest_sha256 = ffv2_file_sha256(artifact_path),
  frozen_file_count = nrow(artifact_manifest),
  frozen_size_bytes = sum(artifact_manifest$size_bytes)
)
summary_path <- ffv2_write_json(
  summary, file.path(closeout_root, "supersession_summary.json")
)

readme <- c(
  "# Superseded independent mean-readout-state campaign",
  "",
  paste0("Decision: `", decision, "`"),
  "",
  "This campaign is frozen as incomplete diagnostic evidence. It must not be",
  "resumed, ranked, promoted, or consumed by article tables or figures.",
  "The generic path-versus-mean forecasting implementation and focused tests",
  "remain reusable in a separately versioned protocol.",
  "",
  sprintf("- Completed jobs: `%d/%d`", health$completed_total, health$planned_total),
  sprintf("- Failed jobs: `%d`", health$failed_total),
  sprintf("- Unstarted or otherwise incomplete jobs: `%d`", health$remaining_total),
  "- Active workers at close: `0`",
  "- Article promotion: `REFUSED`",
  "",
  "Frozen evidence is indexed by `frozen_partial_evidence_manifest.csv`; the",
  "campaign status is preserved in `frozen_job_status.csv` and",
  "`supersession_summary.json`."
)
writeLines(readme, file.path(closeout_root, "README.md"), useBytes = TRUE)
writeLines(decision, file.path(state_root, "manifests", decision), useBytes = TRUE)

verification <- data.frame(
  artifact = c("frozen_job_status", "frozen_partial_evidence_manifest",
               "supersession_summary", "README"),
  path = c(
    frozen_jobs_path, artifact_path, summary_path,
    normalizePath(file.path(closeout_root, "README.md"), winslash = "/",
                  mustWork = TRUE)
  ),
  sha256 = vapply(c(
    frozen_jobs_path, artifact_path, summary_path,
    file.path(closeout_root, "README.md")
  ), ffv2_file_sha256, character(1L)),
  stringsAsFactors = FALSE
)
ffv2_write_csv(verification, file.path(closeout_root, "closeout_manifest.csv"))

cat(sprintf("decision: %s\n", decision))
cat(sprintf("completed: %d/%d\n", health$completed_total, health$planned_total))
cat(sprintf("failed: %d; remaining: %d; active: 0\n",
            health$failed_total, health$remaining_total))
cat(sprintf("frozen files: %d; frozen bytes: %.3f GiB\n",
            nrow(artifact_manifest), sum(artifact_manifest$size_bytes) / 1024^3))
cat(sprintf("closeout: %s\n", closeout_root))
