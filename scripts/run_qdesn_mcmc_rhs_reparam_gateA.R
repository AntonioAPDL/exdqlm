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

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_stub <- paste0(stamp, "__git-", exdqlm:::.qdesn_validation_git_sha())

defaults_path <- get_arg(
  "--defaults",
  file.path("config", "validation", "qdesn_mcmc_compare_rhs_structural_reparam_candidate_best.yaml")
)
grid_path <- get_arg(
  "--grid",
  file.path("config", "validation", "qdesn_mcmc_multichain_rhs_fail_reparam_grid.csv")
)
results_root <- get_arg(
  "--results-root",
  file.path("results", "qdesn_mcmc_validation", "rhs_reparam_gateA", run_stub)
)
report_root <- get_arg(
  "--report-root",
  file.path("reports", "qdesn_mcmc_validation", "rhs_reparam_gateA", run_stub)
)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

dir.create(report_root, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(report_root, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(report_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path)
tmp_defaults <- tempfile(pattern = "gateA-defaults-", fileext = ".yaml")
yaml::write_yaml(defaults, tmp_defaults)

res <- exdqlm:::qdesn_validation_run_multichain_campaign(
  grid_path = grid_path,
  defaults = defaults,
  defaults_path = tmp_defaults,
  results_root = results_root,
  report_root = report_root,
  create_plots = create_plots,
  verbose = verbose
)

if (file.exists(file.path(report_root, "tables", "campaign_root_confirmation.csv"))) {
  confirm <- utils::read.csv(file.path(report_root, "tables", "campaign_root_confirmation.csv"), stringsAsFactors = FALSE)
  gate_summary <- data.frame(
    n_roots = nrow(confirm),
    n_fail = sum(confirm$confirmation_grade == "FAIL", na.rm = TRUE),
    n_warn = sum(confirm$confirmation_grade == "WARN", na.rm = TRUE),
    n_pass = sum(confirm$confirmation_grade == "PASS", na.rm = TRUE),
    max_split_rhat = max(as.numeric(confirm$max_split_rhat), na.rm = TRUE),
    gateA_pass = all(confirm$confirmation_grade != "FAIL"),
    stringsAsFactors = FALSE
  )
} else {
  gate_summary <- data.frame(
    n_roots = 0L,
    n_fail = NA_integer_,
    n_warn = NA_integer_,
    n_pass = NA_integer_,
    max_split_rhat = NA_real_,
    gateA_pass = FALSE,
    stringsAsFactors = FALSE
  )
}

utils::write.csv(gate_summary, file.path(report_root, "tables", "gateA_summary.csv"), row.names = FALSE)
exdqlm:::.qdesn_validation_write_json(file.path(report_root, "manifest", "gateA_manifest.json"), list(
  generated_at = as.character(Sys.time()),
  defaults_path = normalizePath(defaults_path, winslash = "/", mustWork = TRUE),
  grid_path = normalizePath(grid_path, winslash = "/", mustWork = TRUE),
  results_root = normalizePath(results_root, winslash = "/", mustWork = FALSE),
  report_root = normalizePath(report_root, winslash = "/", mustWork = FALSE),
  gateA_summary_path = normalizePath(file.path(report_root, "tables", "gateA_summary.csv"), winslash = "/", mustWork = FALSE)
))

cat(sprintf("Gate A report root: %s\n", normalizePath(report_root, winslash = "/", mustWork = FALSE)))
cat(sprintf("Gate A results root: %s\n", normalizePath(results_root, winslash = "/", mustWork = FALSE)))
if (nrow(gate_summary)) {
  cat(sprintf("Gate A pass: %s (fail=%s, warn=%s, pass=%s, max_split_rhat=%.4f)\n",
              as.character(gate_summary$gateA_pass[[1L]]),
              as.character(gate_summary$n_fail[[1L]]),
              as.character(gate_summary$n_warn[[1L]]),
              as.character(gate_summary$n_pass[[1L]]),
              as.numeric(gate_summary$max_split_rhat[[1L]])))
}
