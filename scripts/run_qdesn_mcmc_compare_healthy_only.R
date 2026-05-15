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
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  if (is.null(path)) return(NULL)
  raw <- as.character(path)[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

safe_mean <- function(x) {
  v <- suppressWarnings(as.numeric(x))
  v <- v[is.finite(v)]
  if (!length(v)) return(NA_real_)
  mean(v)
}

safe_median <- function(x) {
  v <- suppressWarnings(as.numeric(x))
  v <- v[is.finite(v)]
  if (!length(v)) return(NA_real_)
  stats::median(v)
}

defaults_path <- resolve_path(
  get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_structural_reparam_constc2_v1.yaml")),
  must_work = TRUE
)
grid_path <- resolve_path(
  get_arg("--grid", file.path("config", "validation", "qdesn_mcmc_compare_grid.csv")),
  must_work = TRUE
)
results_root <- resolve_path(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "compare_constc2_candidate")),
  must_work = FALSE
)
report_root <- resolve_path(
  get_arg("--report-root", file.path("reports", "qdesn_mcmc_validation", "compare_constc2_candidate")),
  must_work = FALSE
)
healthy_subdir <- get_arg("--healthy-subdir", "healthy_only")
verbose <- !has_flag("--quiet")
create_plots <- !has_flag("--no-plots")

run <- exdqlm:::qdesn_validation_run_campaign(
  grid_path = grid_path,
  defaults_path = defaults_path,
  results_root = results_root,
  report_root = report_root,
  create_plots = create_plots,
  verbose = verbose
)

pair_path <- file.path(run$report_root, "tables", "campaign_pair_summary.csv")
method_path <- file.path(run$report_root, "tables", "campaign_method_summary.csv")
root_path <- file.path(run$report_root, "tables", "campaign_root_summary.csv")

pair_df <- read_csv_safe(pair_path)
method_df <- read_csv_safe(method_path)
root_df <- read_csv_safe(root_path)

if (!nrow(pair_df)) {
  stop(sprintf("Missing or empty pair summary table: %s", pair_path), call. = FALSE)
}

pair_grade <- as.character(pair_df$pair_signoff_grade %||% rep(NA_character_, nrow(pair_df)))
pair_eligible <- as.logical(pair_df$pair_comparison_eligible %||% rep(FALSE, nrow(pair_df)))
both_success <- if ("both_success" %in% names(pair_df)) as.logical(pair_df$both_success) else rep(TRUE, nrow(pair_df))
healthy_idx <- pair_eligible & (pair_grade != "FAIL") & !is.na(pair_grade) & both_success
healthy_pairs <- pair_df[healthy_idx, , drop = FALSE]

healthy_root_ids <- unique(as.character(healthy_pairs$root_id))
healthy_methods <- if (nrow(method_df)) method_df[method_df$root_id %in% healthy_root_ids, , drop = FALSE] else method_df
healthy_roots <- if (nrow(root_df)) root_df[root_df$root_id %in% healthy_root_ids, , drop = FALSE] else root_df

healthy_root <- file.path(run$report_root, healthy_subdir)
dir.create(healthy_root, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(healthy_root, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(healthy_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

utils::write.csv(healthy_pairs, file.path(healthy_root, "tables", "healthy_pair_summary.csv"), row.names = FALSE)
utils::write.csv(healthy_methods, file.path(healthy_root, "tables", "healthy_method_summary.csv"), row.names = FALSE)
utils::write.csv(healthy_roots, file.path(healthy_root, "tables", "healthy_root_summary.csv"), row.names = FALSE)

group_rows <- list()
if (nrow(healthy_pairs)) {
  key <- interaction(
    as.character(healthy_pairs$scenario),
    as.character(healthy_pairs$tau),
    as.character(healthy_pairs$beta_prior_type),
    drop = TRUE
  )
  split_rows <- split(healthy_pairs, key)
  for (k in names(split_rows)) {
    sub <- split_rows[[k]]
    group_rows[[length(group_rows) + 1L]] <- data.frame(
      scenario = as.character(sub$scenario[1L] %||% NA_character_),
      tau = suppressWarnings(as.numeric(sub$tau[1L] %||% NA_real_)),
      beta_prior_type = as.character(sub$beta_prior_type[1L] %||% NA_character_),
      n_pairs = nrow(sub),
      n_pair_pass = sum(as.character(sub$pair_signoff_grade) == "PASS", na.rm = TRUE),
      n_pair_warn = sum(as.character(sub$pair_signoff_grade) == "WARN", na.rm = TRUE),
      n_pair_fail = sum(as.character(sub$pair_signoff_grade) == "FAIL", na.rm = TRUE),
      runtime_ratio_mean = safe_mean(sub$runtime_ratio_mcmc_vs_vb),
      runtime_ratio_median = safe_median(sub$runtime_ratio_mcmc_vs_vb),
      stage_runtime_ratio_mean = safe_mean(sub$stage_runtime_ratio_mcmc_vs_vb),
      qhat_mae_delta_mean = safe_mean(sub$forecast_qhat_mae_delta_mcmc_minus_vb),
      pinball_tau_delta_mean = safe_mean(sub$forecast_pinball_tau_delta_mcmc_minus_vb),
      stringsAsFactors = FALSE
    )
  }
}
healthy_group <- if (length(group_rows)) do.call(rbind, group_rows) else data.frame(stringsAsFactors = FALSE)
utils::write.csv(healthy_group, file.path(healthy_root, "tables", "healthy_pair_group_summary.csv"), row.names = FALSE)

n_pairs_total <- nrow(pair_df)
n_pairs_healthy <- nrow(healthy_pairs)
healthy_rate <- if (n_pairs_total > 0L) n_pairs_healthy / n_pairs_total else NA_real_

manifest <- list(
  generated_at = as.character(Sys.time()),
  defaults_path = defaults_path,
  grid_path = grid_path,
  campaign_report_root = run$report_root,
  campaign_results_root = run$results_root,
  healthy_output_root = healthy_root,
  n_pairs_total = n_pairs_total,
  n_pairs_healthy = n_pairs_healthy,
  healthy_pair_rate = healthy_rate,
  n_roots_total = nrow(root_df),
  n_roots_healthy = nrow(healthy_roots),
  n_methods_healthy = nrow(healthy_methods),
  healthy_filter = "pair_comparison_eligible == TRUE && pair_signoff_grade != FAIL && both_success == TRUE",
  git_sha = exdqlm:::.qdesn_validation_git_sha()
)
exdqlm:::.qdesn_validation_write_json(file.path(healthy_root, "manifest", "healthy_summary_manifest.json"), manifest)

summary_lines <- c(
  "# Healthy-Only Comparison Summary",
  "",
  sprintf("- Campaign report root: `%s`", run$report_root),
  sprintf("- Healthy output root: `%s`", healthy_root),
  sprintf("- Total pairs: `%d`", n_pairs_total),
  sprintf("- Healthy pairs: `%d`", n_pairs_healthy),
  sprintf("- Healthy pair rate: `%0.3f`", healthy_rate),
  sprintf("- Healthy roots: `%d`", nrow(healthy_roots))
)
writeLines(summary_lines, file.path(healthy_root, "healthy_summary.md"))

cat(sprintf("Campaign report root: %s\n", run$report_root))
cat(sprintf("Healthy output root: %s\n", healthy_root))
cat(sprintf("Healthy pairs: %d / %d\n", n_pairs_healthy, n_pairs_total))
