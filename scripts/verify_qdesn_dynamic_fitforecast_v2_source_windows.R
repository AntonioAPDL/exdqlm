#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
`%||%` <- function(a, b) if (is.null(a)) b else a
arg_value <- function(flag, default = NULL) {
  idx <- match(flag, args)
  if (is.na(idx) || idx >= length(args)) return(default)
  args[[idx + 1L]]
}

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

defaults_path <- arg_value(
  "--defaults",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml")
)
inventory_path <- arg_value("--inventory", default = NULL)
out_path <- arg_value(
  "--out",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_source_window_verification.csv")
)

suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
runtime <- exdqlm:::qdesn_validation_assert_runtime(repo_root = repo_root)

defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path, repo_root = repo_root)
if (is.null(inventory_path)) {
  staged_root <- exdqlm:::.qdesn_validation_resolve_path(
    (defaults$source_materialization %||% list())$staged_root,
    repo_root = repo_root,
    must_work = TRUE
  )
  inventory_path <- file.path(staged_root, "materialized_source_inventory.csv")
}

verification <- exdqlm:::qdesn_dynamic_fitforecast_verify_source_windows(
  inventory_path,
  expected_train_end = 9000L,
  expected_forecast_end = 10000L,
  stop_on_fail = TRUE
)
exdqlm:::.qdesn_validation_write_df(verification, out_path)

cat(sprintf("inventory: %s\n", inventory_path))
cat(sprintf("Rscript: %s\n", runtime$rscript))
cat(sprintf("R version: %s\n", runtime$r_version))
cat(sprintf("verification_rows: %d\n", nrow(verification)))
cat(sprintf("verification: %s\n", out_path))
print(table(verification$status, useNA = "ifany"))
