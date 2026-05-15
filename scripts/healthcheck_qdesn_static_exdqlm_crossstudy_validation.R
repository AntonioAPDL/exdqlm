#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
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
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

count_table_df <- function(x, name) {
  if (!length(x)) return(data.frame(stringsAsFactors = FALSE))
  out <- as.data.frame(table(value = as.character(x)), stringsAsFactors = FALSE)
  names(out) <- c(name, "n")
  out[order(out[[name]]), , drop = FALSE]
}

defaults_path <- resolve_path(get_arg("--defaults", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_defaults.yaml")), must_work = TRUE)
grid_path <- resolve_path(get_arg("--grid", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_grid.csv")), must_work = TRUE)
defaults <- exdqlm:::qdesn_static_crossstudy_load_defaults(defaults_path)
grid_df <- exdqlm:::qdesn_static_crossstudy_load_grid(grid_path)
grid_summary <- exdqlm:::qdesn_static_crossstudy_validate_grid(grid_df, defaults)

campaign_cfg <- defaults$campaign %||% list()
base_results_root <- resolve_path(get_arg("--results-root", campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "static_exdqlm_crossstudy")), must_work = FALSE)
base_report_root <- resolve_path(get_arg("--report-root", campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "static_exdqlm_crossstudy")), must_work = FALSE)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required", call. = FALSE)

outer_results_root <- file.path(base_results_root, run_tag)
outer_report_root <- file.path(base_report_root, run_tag)
pick_campaign_report_root <- function(path) {
  if (!dir.exists(path)) return(path)
  if (file.exists(file.path(path, "manifest", "campaign_manifest.json")) || dir.exists(file.path(path, "tables"))) {
    return(path)
  }
  children <- sort(list.dirs(path, recursive = FALSE, full.names = TRUE))
  keep <- children[
    grepl("__git-", basename(children)) &
      (file.exists(file.path(children, "manifest", "campaign_manifest.json")) | dir.exists(file.path(children, "tables")))
  ]
  if (length(keep)) utils::tail(keep, 1L) else path
}
pick_campaign_results_root <- function(path) {
  if (!dir.exists(path)) return(path)
  if (dir.exists(file.path(path, "roots"))) {
    return(path)
  }
  children <- sort(list.dirs(path, recursive = FALSE, full.names = TRUE))
  keep <- children[grepl("__git-", basename(children)) & dir.exists(file.path(children, "roots"))]
  if (length(keep)) utils::tail(keep, 1L) else path
}
campaign_report_root <- pick_campaign_report_root(outer_report_root)
campaign_results_root <- pick_campaign_results_root(outer_results_root)

roots_dir <- file.path(campaign_results_root, "roots")
root_dirs <- if (dir.exists(roots_dir)) sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE)) else character(0)
status_vec <- vapply(
  root_dirs,
  function(root_dir) {
    path <- file.path(root_dir, "manifest", "root_status.txt")
    if (!file.exists(path)) return("MISSING")
    trimws(readLines(path, warn = FALSE, n = 1L))
  },
  character(1)
)
root_status_mix <- count_table_df(status_vec, "root_status")
fit_summary <- read_csv_safe(file.path(campaign_report_root, "tables", "campaign_fit_summary.csv"))
pair_summary <- read_csv_safe(file.path(campaign_report_root, "tables", "campaign_pairwise_vb_vs_mcmc.csv"))
root_summary <- read_csv_safe(file.path(campaign_report_root, "tables", "campaign_root_signoff_summary.csv"))
campaign_completed <- file.path(campaign_report_root, "manifest", "campaign_completed.json")
launch_manifest <- file.path(outer_report_root, "launch", "qdesn_static_exdqlm_crossstudy_launch_manifest.json")
recommendation <- if (file.exists(campaign_completed)) {
  as.character((exdqlm:::.qdesn_validation_read_json_if_exists(campaign_completed) %||% list())$recommendation %||% "NA")[1L]
} else {
  "IN_PROGRESS"
}

cat(sprintf("Snapshot: %s\n", as.character(Sys.time())))
cat(sprintf("Run tag: %s\n", run_tag))
cat(sprintf("Outer report root: %s\n", outer_report_root))
cat(sprintf("Outer results root: %s\n", outer_results_root))
cat(sprintf("Campaign report root: %s\n", campaign_report_root))
cat(sprintf("Campaign results root: %s\n", campaign_results_root))
cat(sprintf("Expected roots: %d\n", grid_summary$enabled_roots))
cat(sprintf("Materialized roots: %d\n", length(root_dirs)))
cat(sprintf("Completed root summaries: %d\n", nrow(root_summary)))
cat(sprintf("Completed fit rows: %d\n", nrow(fit_summary)))
cat(sprintf("Completed algorithm-pair rows: %d\n", nrow(pair_summary)))
cat(sprintf("Recommendation: %s\n", recommendation))
cat(sprintf("Launch manifest present: %s\n", if (file.exists(launch_manifest)) "TRUE" else "FALSE"))
cat("\nRoot status mix:\n")
if (nrow(root_status_mix)) {
  utils::write.table(root_status_mix, row.names = FALSE, quote = FALSE)
} else {
  cat("(no root status rows yet)\n")
}
