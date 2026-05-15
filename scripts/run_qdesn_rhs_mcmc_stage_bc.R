#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
`%||%` <- function(a, b) if (is.null(a)) b else a

matrix_path <- get_arg("--matrix", file.path("config", "validation", "qdesn_rhs_mcmc_repair_matrix.csv"))
profiles_path <- get_arg("--profiles", file.path("config", "validation", "qdesn_rhs_mcmc_repair_profiles.yaml"))
analysis_root <- get_arg("--analysis-root", NULL)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

if (is.null(analysis_root)) {
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  analysis_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_mcmc_repair_sequence", paste0(stamp, "__git-", exdqlm:::.qdesn_validation_git_sha()))
}
analysis_root <- normalizePath(analysis_root, winslash = "/", mustWork = FALSE)
exdqlm:::.qdesn_validation_dir_create(analysis_root)
exdqlm:::.qdesn_validation_dir_create(file.path(analysis_root, "manifest"))

run_ids_b <- c("B1_vbinit_stronger_short", "B2_vbinit_stronger_medium")
run_ids_c <- c("C1_taufreeze_10", "C2_taufreeze_20", "C3_taufreeze_50")

run_one <- function(experiment_id, vb_profile_override = NULL) {
  exdqlm:::qdesn_rhs_mcmc_repair_run_experiment(
    experiment_id = experiment_id,
    matrix_path = matrix_path,
    profiles_path = profiles_path,
    create_plots = create_plots,
    verbose = verbose,
    vb_warm_start_profile_override = vb_profile_override,
    repo_root = repo_root
  )
}

stage_b_runs <- lapply(run_ids_b, run_one)
stage_b_compare <- exdqlm:::qdesn_rhs_mcmc_repair_summarize_reports(
  report_roots = vapply(stage_b_runs, `[[`, character(1), "report_root"),
  output_root = file.path(analysis_root, "stageB_compare"),
  experiment_ids = vapply(stage_b_runs, `[[`, character(1), "experiment_id"),
  create_plots = create_plots
)

best_b_profile <- stage_b_compare$best_vb_warm_start_profile
if (!nzchar(best_b_profile %||% "")) {
  stop("Stage B did not produce a selectable VB warm-start profile.", call. = FALSE)
}

stage_c_runs <- lapply(run_ids_c, function(experiment_id) run_one(experiment_id, vb_profile_override = best_b_profile))
stage_c_compare <- exdqlm:::qdesn_rhs_mcmc_repair_summarize_reports(
  report_roots = vapply(stage_c_runs, `[[`, character(1), "report_root"),
  output_root = file.path(analysis_root, "stageC_compare"),
  experiment_ids = vapply(stage_c_runs, `[[`, character(1), "experiment_id"),
  create_plots = create_plots
)

exdqlm:::.qdesn_validation_write_json(file.path(analysis_root, "manifest", "stage_bc_manifest.json"), list(
  generated_at = as.character(Sys.time()),
  analysis_root = analysis_root,
  matrix_path = normalizePath(matrix_path, winslash = "/", mustWork = TRUE),
  profiles_path = normalizePath(profiles_path, winslash = "/", mustWork = TRUE),
  stage_b = list(
    experiments = unname(run_ids_b),
    report_roots = unname(vapply(stage_b_runs, `[[`, character(1), "report_root")),
    best_experiment_id = stage_b_compare$best_experiment_id,
    best_vb_warm_start_profile = stage_b_compare$best_vb_warm_start_profile
  ),
  stage_c = list(
    experiments = unname(run_ids_c),
    report_roots = unname(vapply(stage_c_runs, `[[`, character(1), "report_root")),
    best_experiment_id = stage_c_compare$best_experiment_id,
    best_freeze_tau_burnin_iters = stage_c_compare$best_freeze_tau_burnin_iters
  )
))

cat(sprintf("Analysis root: %s\n", analysis_root))
cat(sprintf("Stage B best experiment: %s\n", stage_b_compare$best_experiment_id))
cat(sprintf("Stage B best VB profile: %s\n", stage_b_compare$best_vb_warm_start_profile))
cat(sprintf("Stage C best experiment: %s\n", stage_c_compare$best_experiment_id))
cat(sprintf("Stage C best tau freeze: %s\n", as.character(stage_c_compare$best_freeze_tau_burnin_iters)))
