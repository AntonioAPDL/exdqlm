#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml")
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

defaults_path <- get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_compare_phase2_defaults.yaml"))
grid_path <- get_arg("--grid", file.path("config", "validation", "qdesn_mcmc_rhs_failure_grid.csv"))
freeze_values <- strsplit(get_arg("--freeze-values", "0,200,400,800"), ",", fixed = TRUE)[[1L]]
freeze_values <- unique(as.integer(trimws(freeze_values)))
freeze_values <- freeze_values[is.finite(freeze_values) & freeze_values >= 0L]
vb_freeze_tau <- as.integer(get_arg("--vb-freeze-tau", "20"))[1L]
vb_max_iter <- as.integer(get_arg("--vb-max-iter", "80"))[1L]
vb_n_samp_xi <- as.integer(get_arg("--vb-n-samp-xi", "200"))[1L]
results_root <- get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "rhs_tau_freeze_sweep"))
reports_root <- get_arg("--reports-root", file.path("reports", "qdesn_mcmc_validation", "rhs_tau_freeze_sweep"))

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
analysis_root <- file.path(reports_root, paste0(stamp, "__git-", exdqlm:::.qdesn_validation_git_sha()))
dir.create(analysis_root, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(analysis_root, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(analysis_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

base_defaults <- yaml::read_yaml(defaults_path)

run_one <- function(freeze_tau_iters) {
  cfg <- base_defaults
  tag <- sprintf("freeze_tau_%03d", freeze_tau_iters)
  cfg$campaign$name <- paste0("qdesn_rhs_tau_freeze_", tag)
  cfg$campaign$results_root <- file.path(results_root, tag)
  cfg$campaign$reports_root <- file.path(reports_root, tag)

  rhs_override <- cfg$pipeline$inference$mcmc$prior_overrides$rhs
  rhs_override$rhs <- modifyList(rhs_override$rhs %||% list(), list(
    freeze_tau_burnin_iters = freeze_tau_iters,
    freeze_tau_only_during_burn = TRUE
  ))
  rhs_override$vb_warm_start_control <- modifyList(rhs_override$vb_warm_start_control %||% list(), list(
    max_iter = vb_max_iter,
    min_iter_elbo = 12L,
    n_samp_xi = vb_n_samp_xi,
    verbose = FALSE,
    rhs = list(
      freeze_tau_iters = vb_freeze_tau,
      freeze_tau_warmup_iters = vb_freeze_tau,
      tau_local_tol = 5e-4,
      min_tau_updates = 2L,
      force_tau_after_warmup = TRUE
    )
  ))
  cfg$pipeline$inference$mcmc$prior_overrides$rhs <- rhs_override

  tmp_defaults <- tempfile(pattern = paste0("rhs-tau-freeze-", tag, "-"), fileext = ".yaml")
  yaml::write_yaml(cfg, tmp_defaults)

  res <- exdqlm:::qdesn_validation_run_campaign(
    grid_path = grid_path,
    defaults_path = tmp_defaults,
    create_plots = !has_flag("--no-plots"),
    verbose = !has_flag("--quiet")
  )

  progress <- utils::read.csv(file.path(res$report_root, "tables", "campaign_progress.csv"), stringsAsFactors = FALSE)
  method_signoff <- utils::read.csv(file.path(res$report_root, "tables", "campaign_method_signoff.csv"), stringsAsFactors = FALSE)
  list(
    freeze_tau_burnin_iters = freeze_tau_iters,
    vb_freeze_tau_iters = vb_freeze_tau,
    vb_max_iter = vb_max_iter,
    vb_n_samp_xi = vb_n_samp_xi,
    results_root = normalizePath(res$results_root, winslash = "/", mustWork = TRUE),
    report_root = normalizePath(res$report_root, winslash = "/", mustWork = TRUE),
    progress = progress,
    method_signoff = method_signoff
  )
}

rows_progress <- list()
rows_signoff <- list()
runs <- vector("list", length(freeze_values))
for (ii in seq_along(freeze_values)) {
  runs[[ii]] <- run_one(freeze_values[[ii]])
  prog <- runs[[ii]]$progress
  prog$freeze_tau_burnin_iters <- runs[[ii]]$freeze_tau_burnin_iters
  prog$vb_freeze_tau_iters <- runs[[ii]]$vb_freeze_tau_iters
  prog$vb_max_iter <- runs[[ii]]$vb_max_iter
  prog$vb_n_samp_xi <- runs[[ii]]$vb_n_samp_xi
  prog$run_report_root <- runs[[ii]]$report_root
  rows_progress[[ii]] <- prog

  sig <- runs[[ii]]$method_signoff
  sig$freeze_tau_burnin_iters <- runs[[ii]]$freeze_tau_burnin_iters
  sig$vb_freeze_tau_iters <- runs[[ii]]$vb_freeze_tau_iters
  sig$vb_max_iter <- runs[[ii]]$vb_max_iter
  sig$vb_n_samp_xi <- runs[[ii]]$vb_n_samp_xi
  sig$run_report_root <- runs[[ii]]$report_root
  rows_signoff[[ii]] <- sig
}

progress_all <- do.call(rbind, rows_progress)
signoff_all <- do.call(rbind, rows_signoff)
utils::write.csv(progress_all, file.path(analysis_root, "tables", "tau_freeze_sweep_progress.csv"), row.names = FALSE)
utils::write.csv(signoff_all, file.path(analysis_root, "tables", "tau_freeze_sweep_method_signoff.csv"), row.names = FALSE)

summary_rows <- subset(
  signoff_all,
  method == "mcmc",
  select = c(
    "freeze_tau_burnin_iters", "scenario", "tau", "signoff_grade", "signoff_reason",
    "comparison_eligible", "mcmc_n_keep", "mcmc_min_ess_core", "mcmc_max_geweke_absz_core",
    "mcmc_max_half_drift_core", "mcmc_min_ess_rhs", "mcmc_max_geweke_absz_rhs",
    "mcmc_max_half_drift_rhs", "run_report_root"
  )
)
utils::write.csv(summary_rows, file.path(analysis_root, "tables", "tau_freeze_sweep_mcmc_summary.csv"), row.names = FALSE)

summary_lines <- c(
  "# RHS Tau-Freeze Sweep",
  "",
  sprintf("- Defaults base: `%s`", defaults_path),
  sprintf("- Grid: `%s`", grid_path),
  sprintf("- Freeze values: `%s`", paste(freeze_values, collapse = ", ")),
  sprintf("- VB warmup freeze tau: `%d`", vb_freeze_tau),
  sprintf("- VB warmup max_iter: `%d`", vb_max_iter),
  sprintf("- VB warmup n_samp_xi: `%d`", vb_n_samp_xi),
  "",
  "## MCMC RHS Summary",
  ""
)
summary_lines <- c(summary_lines, exdqlm:::.qdesn_validation_df_to_markdown(summary_rows))
writeLines(summary_lines, con = file.path(analysis_root, "tau_freeze_sweep_summary.md"))

exdqlm:::.qdesn_validation_write_json(file.path(analysis_root, "manifest", "tau_freeze_sweep_manifest.json"), list(
  defaults_path = normalizePath(defaults_path, winslash = "/", mustWork = TRUE),
  grid_path = normalizePath(grid_path, winslash = "/", mustWork = TRUE),
  freeze_values = as.list(freeze_values),
  vb_freeze_tau_iters = vb_freeze_tau,
  vb_max_iter = vb_max_iter,
  vb_n_samp_xi = vb_n_samp_xi,
  generated_at = as.character(Sys.time()),
  analysis_root = normalizePath(analysis_root, winslash = "/", mustWork = TRUE)
))

cat(sprintf("Analysis root: %s\n", normalizePath(analysis_root, winslash = "/", mustWork = TRUE)))
