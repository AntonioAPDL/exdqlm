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
  file.path("config", "validation", "qdesn_mcmc_compare_rhs_structural_reparam_gateB_tauwarm25.yaml")
)
grid_path <- get_arg(
  "--grid",
  file.path("config", "validation", "qdesn_mcmc_multichain_rhs_runtime_isolation_grid.csv")
)
results_root <- get_arg(
  "--results-root",
  file.path("results", "qdesn_mcmc_validation", "rhs_runtime_isolation_wave", run_stub)
)
report_root <- get_arg(
  "--report-root",
  file.path("reports", "qdesn_mcmc_validation", "rhs_runtime_isolation_wave", run_stub)
)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

dir.create(report_root, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(report_root, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(report_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path)
tmp_defaults <- tempfile(pattern = "runtime-isolation-defaults-", fileext = ".yaml")
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

chain_path <- file.path(report_root, "tables", "campaign_chain_signoff.csv")
root_path <- file.path(report_root, "tables", "campaign_root_confirmation.csv")

if (file.exists(chain_path)) {
  chain <- utils::read.csv(chain_path, stringsAsFactors = FALSE)
} else {
  chain <- data.frame(stringsAsFactors = FALSE)
}

if (file.exists(root_path)) {
  root <- utils::read.csv(root_path, stringsAsFactors = FALSE)
} else {
  root <- data.frame(stringsAsFactors = FALSE)
}

contains_reason <- function(x, pat) {
  if (!length(x)) return(logical(0))
  grepl(pat, x, fixed = TRUE)
}

runtime_summary <- data.frame(
  n_roots = nrow(root),
  n_root_fail = if (nrow(root)) sum(root$confirmation_grade == "FAIL", na.rm = TRUE) else NA_integer_,
  n_root_warn = if (nrow(root)) sum(root$confirmation_grade == "WARN", na.rm = TRUE) else NA_integer_,
  n_chains = nrow(chain),
  n_chain_fail = if (nrow(chain)) sum(chain$signoff_grade == "FAIL", na.rm = TRUE) else NA_integer_,
  n_missing_diag = if (nrow(chain)) sum(contains_reason(chain$signoff_reason, "missing_chain_diagnostics"), na.rm = TRUE) else NA_integer_,
  n_pipeline_fail = if (nrow(chain)) sum(contains_reason(chain$signoff_reason, "pipeline"), na.rm = TRUE) else NA_integer_,
  max_split_rhat = if (nrow(root)) max(as.numeric(root$max_split_rhat), na.rm = TRUE) else NA_real_,
  runtime_isolation_pass = if (nrow(chain)) sum(contains_reason(chain$signoff_reason, "missing_chain_diagnostics"), na.rm = TRUE) == 0L else FALSE,
  stringsAsFactors = FALSE
)

utils::write.csv(runtime_summary, file.path(report_root, "tables", "runtime_isolation_summary.csv"), row.names = FALSE)
exdqlm:::.qdesn_validation_write_json(file.path(report_root, "manifest", "runtime_isolation_manifest.json"), list(
  generated_at = as.character(Sys.time()),
  defaults_path = normalizePath(defaults_path, winslash = "/", mustWork = TRUE),
  grid_path = normalizePath(grid_path, winslash = "/", mustWork = TRUE),
  results_root = normalizePath(results_root, winslash = "/", mustWork = FALSE),
  report_root = normalizePath(report_root, winslash = "/", mustWork = FALSE),
  runtime_isolation_summary_path = normalizePath(file.path(report_root, "tables", "runtime_isolation_summary.csv"), winslash = "/", mustWork = FALSE)
))

cat(sprintf("Runtime isolation report root: %s\n", normalizePath(report_root, winslash = "/", mustWork = FALSE)))
cat(sprintf("Runtime isolation results root: %s\n", normalizePath(results_root, winslash = "/", mustWork = FALSE)))
if (nrow(runtime_summary)) {
  cat(sprintf(
    "Runtime isolation pass: %s (missing_diag=%s, root_fail=%s, chain_fail=%s, max_split_rhat=%.4f)\n",
    as.character(runtime_summary$runtime_isolation_pass[[1L]]),
    as.character(runtime_summary$n_missing_diag[[1L]]),
    as.character(runtime_summary$n_root_fail[[1L]]),
    as.character(runtime_summary$n_chain_fail[[1L]]),
    as.numeric(runtime_summary$max_split_rhat[[1L]])
  ))
}
