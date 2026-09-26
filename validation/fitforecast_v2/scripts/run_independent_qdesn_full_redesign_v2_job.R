#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
value_after <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) return(default)
  args[[i + 1L]]
}

config_path <- value_after("--config")
if (is.null(config_path)) stop("Usage: --config <job.json>", call. = FALSE)

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
Sys.setenv(
  OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1", RCPP_PARALLEL_NUM_THREADS = "1"
)
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_full_redesign_v2.R"
))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_full_redesign_v2_runtime.R"
))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_full_redesign_v2_resume.R"
))

cfg <- iqfr_v2_read_json(config_path)
source_version <- as.character(read.dcf(
  file.path(repo_root, "DESCRIPTION"), fields = "Version"
)[[1L]])
loaded_version <- as.character(utils::packageVersion("exdqlm"))
if (!identical(source_version, iqfr_v2_expected_package_version) ||
    !identical(loaded_version, iqfr_v2_expected_package_version)) {
  stop(
    "Worker package contract failed: source=", source_version,
    ", loaded=", loaded_version,
    ", expected=", iqfr_v2_expected_package_version, ".",
    call. = FALSE
  )
}
materialization <- iqfr_v2_read_json(file.path(
  cfg$run_root, "manifests", "materialization.json"
))
environment <- iqfr_v2_read_json(file.path(
  cfg$run_root, "manifests", "environment.json"
))
observed_head <- system2(
  "git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE
)
observed_protocol_sha <- iqfr_v2_sha256(cfg$protocol_path)
head_contract <- iqfr_v2_worker_head_contract(
  materialization, environment, observed_head, cfg$run_root
)
if (!identical(as.character(environment$package_version), loaded_version) ||
    !isTRUE(head_contract$pass) ||
    !identical(as.character(cfg$protocol_sha256), observed_protocol_sha)) {
  stop("Worker provenance contract failed for ", cfg$job_id, ".",
       call. = FALSE)
}
append_execution_provenance <- function() {
  if (file.exists(cfg$status_path)) {
    status <- iqfr_v2_read_json(cfg$status_path)
    status$execution_git_head <- observed_head
    status$execution_provenance_mode <- head_contract$mode
    status$resume_authorization_sha256 <-
      head_contract$authorization_sha256
    iqfr_v2_write_json(status, cfg$status_path)
  }
}
stage <- as.character(cfg$stage)
tryCatch({
  if (stage %in% c("normal_initial", "normal_adaptive", "normal_full")) {
    iqfr_v2_normal_job(config_path)
  } else if (identical(stage, "quantile_vb")) {
    iqfr_v2_quantile_vb_job(config_path)
  } else if (stage %in% c("mcmc_pilot", "mcmc_confirmation")) {
    iqfr_v2_mcmc_job(config_path)
  } else {
    stop("Unsupported redesigned-validation job stage: ", stage,
         call. = FALSE)
  }
}, finally = append_execution_provenance())
