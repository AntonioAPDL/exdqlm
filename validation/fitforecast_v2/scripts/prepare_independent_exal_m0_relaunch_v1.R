#!/usr/bin/env Rscript

suppressPackageStartupMessages(requireNamespace("jsonlite", quietly = TRUE))
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_exal_m0_relaunch_v1.R"
))
output_arg <- get_arg(
  "--output-root",
  file.path("reports", "shared_fitforecast_v2_orchestration", "m0_prepare_only")
)
output_root <- if (grepl("^/", output_arg)) output_arg else file.path(repo_root, output_arg)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
stub <- qdesn_m0v1_config_stub(repo_root)
plan <- qdesn_m0v1_read_csv(paste0(stub, "_chain_plan.csv"))

rows <- lapply(seq_len(nrow(plan)), function(i) {
  config_path <- file.path(repo_root, plan$config_path[[i]])
  config <- qdesn_m0v1_read_json(config_path)
  data.frame(
    job_id = plan$job_id[[i]],
    budget = plan$budget[[i]],
    anchor_id = plan$anchor_id[[i]],
    chain_id = plan$chain_id[[i]],
    config_path = plan$config_path[[i]],
    config_sha256 = qdesn_m0v1_sha256(config_path),
    observed_path = plan$observed_path[[i]],
    observed_sha256 = qdesn_m0v1_sha256(file.path(repo_root, plan$observed_path[[i]])),
    method_id = as.character(config$config$inference$mcmc$slice$core_update_mode),
    n_burn = as.integer(config$config$inference$mcmc$n_burn),
    n_mcmc = as.integer(config$config$inference$mcmc$n_mcmc),
    threads = as.integer(config$config$cpp$postpred_threads),
    action = "prepare_only_no_fit",
    stringsAsFactors = FALSE
  )
})
dry_run <- do.call(rbind, rows)
qdesn_m0v1_write_csv(dry_run, file.path(output_root, "dry_run_manifest.csv"))
binary_paths <- list.files(
  output_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
pass <- nrow(dry_run) == 60L &&
  all(dry_run$config_sha256 == plan$config_sha256) &&
  all(dry_run$observed_sha256 == plan$observed_sha256) &&
  all(dry_run$method_id == qdesn_m0v1_method_id) &&
  all(dry_run$threads == 1L) && !length(binary_paths)
qdesn_m0v1_write_json(list(
  generated_at = as.character(Sys.time()),
  mode = "prepare_only",
  planned_jobs = nrow(dry_run),
  smoke_jobs = sum(dry_run$budget == "smoke"),
  canary_jobs = sum(dry_run$budget == "canary"),
  full_jobs = sum(dry_run$budget == "full"),
  model_fits_started = 0L,
  binary_payloads = length(binary_paths),
  decision = if (pass) "PASS" else "FAIL"
), file.path(output_root, "prepare_only_gate.json"))
cat(sprintf("prepare-only: %s (%d jobs; no fits)\n", if (pass) "PASS" else "FAIL",
            nrow(dry_run)))
if (!pass) stop("Prepare-only contract failed.", call. = FALSE)
