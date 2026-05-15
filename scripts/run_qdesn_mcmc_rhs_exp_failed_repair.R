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
or_else <- function(x, y) if (is.null(x)) y else x

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, base_dir = ".", must_work = TRUE) {
  if (is.null(path)) return(NULL)
  p <- trimws(as.character(path)[1L])
  if (!nzchar(p)) return(NULL)
  raw <- if (grepl("^(/|~)", p)) p else file.path(base_dir, p)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

latest_completed_matrix_report <- function(base_root) {
  dirs <- sort(list.dirs(base_root, full.names = TRUE, recursive = FALSE))
  if (!length(dirs)) return(NULL)
  completed <- Filter(function(d) file.exists(file.path(d, "manifest", "matrix_completed.json")), dirs)
  if (!length(completed)) return(NULL)
  completed[[length(completed)]]
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

matrix_config_path <- get_arg(
  "--matrix-config",
  file.path("config", "validation", "qdesn_mcmc_rhs_exp_matrix", "matrix.yaml")
)
matrix_report_root <- get_arg("--matrix-report-root", NULL)
winner_patch_ids <- trimws(strsplit(get_arg("--winner-patches", "E07,E11"), ",", fixed = TRUE)[[1L]])
winner_patch_ids <- winner_patch_ids[nzchar(winner_patch_ids)]

create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

matrix_cfg <- exdqlm:::.qdesn_rhs_exp_matrix_load(matrix_config_path)
if (is.null(matrix_report_root) || !nzchar(trimws(matrix_report_root))) {
  matrix_report_root <- latest_completed_matrix_report(
    file.path(repo_root, "reports", "qdesn_mcmc_validation", "rhs_exp_matrix")
  )
}
if (is.null(matrix_report_root) || !nzchar(trimws(matrix_report_root))) {
  stop("No completed matrix report root found; pass --matrix-report-root.", call. = FALSE)
}
matrix_report_root <- resolve_path(matrix_report_root, must_work = TRUE)

base_defaults <- exdqlm:::qdesn_validation_load_defaults(matrix_cfg$matrix$base_defaults)

exp_index <- list()
for (ph in matrix_cfg$phases) {
  for (ex in ph$experiments) {
    exp_index[[ex$id]] <- ex$patch_path
  }
}
missing_ids <- setdiff(winner_patch_ids, names(exp_index))
if (length(missing_ids)) {
  stop(sprintf("Unknown winner patch ids: %s", paste(missing_ids, collapse = ", ")), call. = FALSE)
}

resolved_defaults <- base_defaults
chain_seed_base <- matrix_cfg$matrix$chain_seed_base
for (patch_id in winner_patch_ids) {
  patch_doc <- exdqlm:::.qdesn_rhs_exp_matrix_read_patch(exp_index[[patch_id]])
  resolved_defaults <- exdqlm:::.qdesn_rhs_exp_matrix_deep_merge(resolved_defaults, or_else(patch_doc$patch, list()))
  run_over <- or_else(patch_doc$run_overrides, list())
  if (!is.null(run_over$chain_seed_base)) {
    chain_seed_base <- as.integer(run_over$chain_seed_base)[1L]
  }
}

n_chains <- as.integer(get_arg("--n-chains", as.character(matrix_cfg$matrix$n_chains)))[1L]
if (!is.finite(n_chains) || n_chains < 2L) n_chains <- matrix_cfg$matrix$n_chains

chain_seed_base_arg <- get_arg("--chain-seed-base", NULL)
if (!is.null(chain_seed_base_arg) && nzchar(trimws(chain_seed_base_arg))) {
  chain_seed_base <- as.integer(chain_seed_base_arg)[1L]
}
if (!is.finite(chain_seed_base)) chain_seed_base <- matrix_cfg$matrix$chain_seed_base

confirm_files <- Sys.glob(file.path(matrix_report_root, "*", "*", "tables", "campaign_root_confirmation.csv"))
if (!length(confirm_files)) {
  stop(sprintf("No campaign_root_confirmation.csv files under %s", matrix_report_root), call. = FALSE)
}

confirm_df <- do.call(rbind, lapply(confirm_files, read_csv_safe))
if (!nrow(confirm_df)) {
  stop("No rows found in campaign root confirmation tables.", call. = FALSE)
}
required_cols <- c("scenario", "tau", "beta_prior_type", "seed", "reservoir_profile", "confirmation_grade")
miss_cols <- setdiff(required_cols, names(confirm_df))
if (length(miss_cols)) {
  stop(sprintf("Missing required columns in confirmation tables: %s", paste(miss_cols, collapse = ", ")), call. = FALSE)
}

failed_df <- subset(confirm_df, as.character(confirmation_grade) == "FAIL")
if (!nrow(failed_df)) {
  cat("No failed roots found in matrix report; nothing to repair.\n")
  quit(save = "no", status = 0)
}

grid_df <- unique(failed_df[, c("scenario", "tau", "beta_prior_type", "seed", "reservoir_profile")])
grid_df$enabled <- TRUE
rownames(grid_df) <- NULL

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_stub <- paste0(stamp, "__git-", exdqlm:::.qdesn_validation_git_sha())
default_results_root <- file.path("results", "qdesn_mcmc_validation", "rhs_exp_failed_repair", run_stub)
default_reports_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_exp_failed_repair", run_stub)

results_root <- resolve_path(get_arg("--results-root", default_results_root), must_work = FALSE)
reports_root <- resolve_path(get_arg("--reports-root", default_reports_root), must_work = FALSE)
dir.create(results_root, recursive = TRUE, showWarnings = FALSE)
dir.create(reports_root, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(reports_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

grid_path <- resolve_path(get_arg("--grid-out", file.path(reports_root, "failed_root_grid.csv")), must_work = FALSE)
utils::write.csv(grid_df, grid_path, row.names = FALSE)

defaults_path <- resolve_path(get_arg("--defaults-out", file.path(reports_root, "resolved_defaults.yaml")), must_work = FALSE)
yaml::write_yaml(resolved_defaults, defaults_path)

resolved_defaults$campaign <- or_else(resolved_defaults$campaign, list())
resolved_defaults$campaign$name <- "qdesn_rhs_exp_failed_repair"
resolved_defaults$campaign$results_root <- results_root
resolved_defaults$campaign$reports_root <- reports_root
yaml::write_yaml(resolved_defaults, defaults_path)

exdqlm:::.qdesn_validation_write_json(file.path(reports_root, "manifest", "repair_manifest_started.json"), list(
  started_at = as.character(Sys.time()),
  matrix_report_root = matrix_report_root,
  matrix_config_path = matrix_cfg$matrix_path,
  winner_patch_ids = winner_patch_ids,
  n_failed_roots = nrow(grid_df),
  grid_path = grid_path,
  defaults_path = defaults_path,
  n_chains = n_chains,
  chain_seed_base = chain_seed_base,
  results_root = results_root,
  reports_root = reports_root,
  git_sha = exdqlm:::.qdesn_validation_git_sha()
))

res <- exdqlm:::qdesn_validation_run_multichain_campaign(
  grid_path = grid_path,
  defaults = resolved_defaults,
  defaults_path = defaults_path,
  results_root = results_root,
  report_root = reports_root,
  n_chains = n_chains,
  chain_seed_base = chain_seed_base,
  create_plots = create_plots,
  verbose = verbose
)

confirm_out <- read_csv_safe(file.path(reports_root, "tables", "campaign_root_confirmation.csv"))
n_fail <- if (nrow(confirm_out)) sum(as.character(confirm_out$confirmation_grade) == "FAIL", na.rm = TRUE) else NA_integer_
n_warn <- if (nrow(confirm_out)) sum(as.character(confirm_out$confirmation_grade) == "WARN", na.rm = TRUE) else NA_integer_
n_pass <- if (nrow(confirm_out)) sum(as.character(confirm_out$confirmation_grade) == "PASS", na.rm = TRUE) else NA_integer_

exdqlm:::.qdesn_validation_write_json(file.path(reports_root, "manifest", "repair_manifest_completed.json"), list(
  finished_at = as.character(Sys.time()),
  matrix_report_root = matrix_report_root,
  winner_patch_ids = winner_patch_ids,
  n_failed_input_roots = nrow(grid_df),
  n_fail_after_repair = n_fail,
  n_warn_after_repair = n_warn,
  n_pass_after_repair = n_pass,
  grid_path = normalizePath(grid_path, winslash = "/", mustWork = FALSE),
  defaults_path = normalizePath(defaults_path, winslash = "/", mustWork = FALSE),
  results_root = normalizePath(results_root, winslash = "/", mustWork = FALSE),
  reports_root = normalizePath(reports_root, winslash = "/", mustWork = FALSE),
  git_sha = exdqlm:::.qdesn_validation_git_sha()
))

cat(sprintf("Matrix report root: %s\n", matrix_report_root))
cat(sprintf("Repair grid path: %s\n", normalizePath(grid_path, winslash = "/", mustWork = FALSE)))
cat(sprintf("Repair defaults path: %s\n", normalizePath(defaults_path, winslash = "/", mustWork = FALSE)))
cat(sprintf("Repair results root: %s\n", normalizePath(results_root, winslash = "/", mustWork = FALSE)))
cat(sprintf("Repair reports root: %s\n", normalizePath(reports_root, winslash = "/", mustWork = FALSE)))
cat(sprintf("Post-repair root grades: PASS=%s WARN=%s FAIL=%s\n", n_pass, n_warn, n_fail))
