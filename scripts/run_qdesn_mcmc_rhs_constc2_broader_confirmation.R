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
`%||%` <- function(a, b) if (is.null(a)) b else a

sanitize_yaml_keys <- function(x) {
  if (!is.list(x)) return(x)
  nm <- names(x)
  if (!is.null(nm) && ("FALSE" %in% nm)) {
    if (is.null(x[["n", exact = TRUE]])) {
      x[["n"]] <- x[["FALSE", exact = TRUE]]
    }
    x[["FALSE"]] <- NULL
  }
  if (length(x)) {
    for (ii in seq_along(x)) {
      x[[ii]] <- sanitize_yaml_keys(x[[ii]])
    }
  }
  x
}

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

timestamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_stub <- sprintf("%s__git-%s", timestamp, exdqlm:::.qdesn_validation_git_sha())

defaults_path <- resolve_path(
  get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_structural_reparam_constc2_candidate.yaml")),
  must_work = TRUE
)
grid_path <- resolve_path(
  get_arg("--grid", file.path("config", "validation", "qdesn_mcmc_multichain_rhs_broader_confirmation_grid.csv")),
  must_work = TRUE
)
results_base <- resolve_path(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "rhs_constc2_broader_confirmation")),
  must_work = FALSE
)
report_base <- resolve_path(
  get_arg("--report-root", file.path("reports", "qdesn_mcmc_validation", "rhs_constc2_broader_confirmation")),
  must_work = FALSE
)
promotion_defaults_path <- resolve_path(
  get_arg("--promotion-defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_structural_reparam_constc2_v1.yaml")),
  must_work = FALSE
)

results_run_root <- file.path(results_base, run_stub)
report_run_root <- file.path(report_base, run_stub)

n_chains <- as.integer(get_arg("--n-chains", "4"))[1L]
chain_seed_base <- as.integer(get_arg("--chain-seed-base", "920000"))[1L]
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")
promote_on_pass <- !has_flag("--no-promote")

for (d in c(
  report_run_root,
  file.path(report_run_root, "tables"),
  file.path(report_run_root, "manifest")
)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

res <- exdqlm:::qdesn_validation_run_multichain_campaign(
  grid_path = grid_path,
  defaults_path = defaults_path,
  results_root = results_run_root,
  report_root = report_run_root,
  n_chains = n_chains,
  chain_seed_base = chain_seed_base,
  create_plots = create_plots,
  verbose = verbose
)

root_conf_path <- file.path(report_run_root, "tables", "campaign_root_confirmation.csv")
root_conf <- read_csv_safe(root_conf_path)
n_roots <- nrow(root_conf)
n_fail <- if (n_roots) sum(as.character(root_conf$confirmation_grade) == "FAIL", na.rm = TRUE) else NA_integer_
n_warn <- if (n_roots) sum(as.character(root_conf$confirmation_grade) == "WARN", na.rm = TRUE) else NA_integer_
n_pass <- if (n_roots) sum(as.character(root_conf$confirmation_grade) == "PASS", na.rm = TRUE) else NA_integer_
gate_pass <- is.finite(n_fail) && (n_fail == 0L)

unresolved <- subset(root_conf, as.character(confirmation_grade) == "FAIL")
utils::write.csv(unresolved, file.path(report_run_root, "tables", "broader_unresolved_fail_roots.csv"), row.names = FALSE)

promoted <- FALSE
if (isTRUE(promote_on_pass) && isTRUE(gate_pass)) {
  promoted_defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path)
  promoted_defaults$campaign <- promoted_defaults$campaign %||% list()
  promoted_defaults$campaign$name <- "qdesn_mcmc_rhs_constc2_v1"
  promoted_defaults$campaign$results_root <- "results/qdesn_mcmc_validation/rhs_constc2_v1"
  promoted_defaults$campaign$reports_root <- "reports/qdesn_mcmc_validation/rhs_constc2_v1"
  promoted_defaults <- sanitize_yaml_keys(promoted_defaults)
  dir.create(dirname(promotion_defaults_path), recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(promoted_defaults, promotion_defaults_path)
  promoted <- TRUE
}

summary_df <- data.frame(
  generated_at = as.character(Sys.time()),
  defaults_path = defaults_path,
  grid_path = grid_path,
  report_root = report_run_root,
  results_root = results_run_root,
  n_roots = if (n_roots) n_roots else 0L,
  n_fail = if (is.finite(n_fail)) as.integer(n_fail) else NA_integer_,
  n_warn = if (is.finite(n_warn)) as.integer(n_warn) else NA_integer_,
  n_pass = if (is.finite(n_pass)) as.integer(n_pass) else NA_integer_,
  gate_pass = gate_pass,
  promoted_defaults = promoted,
  promoted_defaults_path = if (promoted) promotion_defaults_path else NA_character_,
  n_chains = as.integer(n_chains),
  chain_seed_base = as.integer(chain_seed_base),
  stringsAsFactors = FALSE
)
utils::write.csv(summary_df, file.path(report_run_root, "tables", "broader_confirmation_summary.csv"), row.names = FALSE)

exdqlm:::.qdesn_validation_write_json(file.path(report_run_root, "manifest", "broader_confirmation_manifest.json"), list(
  generated_at = as.character(Sys.time()),
  defaults_path = defaults_path,
  grid_path = grid_path,
  report_root = report_run_root,
  results_root = results_run_root,
  n_chains = as.integer(n_chains),
  chain_seed_base = as.integer(chain_seed_base),
  n_roots = if (n_roots) n_roots else 0L,
  n_fail = if (is.finite(n_fail)) as.integer(n_fail) else NULL,
  n_warn = if (is.finite(n_warn)) as.integer(n_warn) else NULL,
  n_pass = if (is.finite(n_pass)) as.integer(n_pass) else NULL,
  gate_pass = isTRUE(gate_pass),
  promoted_defaults = isTRUE(promoted),
  promoted_defaults_path = if (promoted) promotion_defaults_path else NULL,
  campaign_report_root = res$report_root %||% report_run_root,
  campaign_results_root = res$results_root %||% results_run_root,
  git_sha = exdqlm:::.qdesn_validation_git_sha()
))

cat(sprintf("Broader confirmation report root: %s\n", report_run_root))
cat(sprintf("Broader confirmation results root: %s\n", results_run_root))
cat(sprintf(
  "Root grades: PASS=%s WARN=%s FAIL=%s\n",
  as.character(n_pass), as.character(n_warn), as.character(n_fail)
))
cat(sprintf("Gate pass (FAIL=0): %s\n", as.character(gate_pass)))
cat(sprintf("Promoted defaults: %s\n", as.character(promoted)))
