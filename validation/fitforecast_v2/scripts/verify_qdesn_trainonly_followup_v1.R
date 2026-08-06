#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "pkgload", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
})
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_trainonly_followup_v1.R"))

stage <- qdesn_tfv1_stage()
stub <- file.path(repo_root, "config", "validation", stage)
read_csv <- function(path) utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
issues <- character()
add_issue <- function(...) issues <<- c(issues, sprintf(...))

desc <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(desc[1L, "Version"]), "1.0.0")) add_issue("Package version is not 1.0.0.")
tryCatch(qdesn_tfv1_validate_plan(), error = function(e) add_issue("Plan: %s", conditionMessage(e)))

index_path <- paste0(stub, "_bundle_index.csv")
if (!file.exists(index_path)) add_issue("Missing bundle index.")
index <- if (file.exists(index_path)) read_csv(index_path) else data.frame()
if (nrow(index) != 7L || sum(as.integer(index$expected_specs)) != 36L) add_issue("Expected seven source-valid bundles and 36 roots.")

source_rows <- list()
if (nrow(index)) for (i in seq_len(nrow(index))) {
  id <- as.character(index$bundle_id[[i]])
  defaults <- yaml::read_yaml(index$defaults_path[[i]])
  grid <- read_csv(index$grid_path[[i]])
  specs <- read_csv(index$target_specs_path[[i]])
  if (nrow(grid) != index$expected_specs[[i]]) add_issue("%s grid count mismatch.", id)
  if (length(unique(grid$source_scenario)) != if (startsWith(id, "exal_")) 3L else 1L) {
    add_issue("%s crosses an invalid number of source scenarios for its canonical root.", id)
  }
  if (nrow(specs) != index$expected_specs[[i]] || anyDuplicated(specs$spec_id)) add_issue("%s spec ids invalid.", id)
  if (any(grid$train_start_source_index != 8501L) || any(grid$train_end_source_index != 9000L) ||
      any(grid$forecast_start_source_index != 9001L) || any(grid$forecast_end_source_index != 10000L)) {
    add_issue("%s source windows differ from the frozen contract.", id)
  }
  if (any(grepl("^/home/jaguir26/local/src", unlist(grid), fixed = FALSE))) add_issue("%s contains stale /home paths.", id)
  if (!identical(defaults$preproc$fit_scope, "train_only")) add_issue("%s is not train-only.", id)
  if (isTRUE(defaults$pipeline$outputs$keep_draws) || isTRUE(defaults$pipeline$outputs$keep_mcmc_vb_init) ||
      isTRUE(defaults$pipeline$outputs$save_forecast_objects) || isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure)) {
    add_issue("%s violates storage-light output policy.", id)
  }
  rhs <- defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns
  if (!isTRUE(defaults$pipeline$inference$mcmc$init_from_vb) || rhs$progress_every != 50L) add_issue("%s telemetry/warm-start contract failed.", id)
  contract <- qdesn_tfv1_bundle_contract()
  row <- contract[contract$bundle_id == id, , drop = FALSE]
  if (rhs$n_burn != row$n_burn || rhs$n_mcmc != row$n_mcmc) add_issue("%s MCMC budget mismatch.", id)
  expected_sampler <- qdesn_tfv1_sampler_control(id)
  for (nm in c("core_update_mode", "width_gamma", "width_sigma", "core_extra_passes")) {
    if (!identical(rhs$slice[[nm]], expected_sampler$slice[[nm]])) add_issue("%s sampler field %s mismatch.", id, nm)
  }
  if (!identical(isTRUE(rhs$multi_start$enabled), isTRUE(expected_sampler$multi_start$enabled))) add_issue("%s multi-start mismatch.", id)
  source_rows[[length(source_rows) + 1L]] <- unique(grid[, c(
    "source_scenario", "source_family", "tau", "source_series_wide_path",
    "source_series_wide_sha256", "source_sim_path", "source_sim_sha256",
    "source_registry_hash_value", "source_registry_role"
  ), drop = FALSE])
}

sources <- if (length(source_rows)) unique(do.call(rbind, source_rows)) else data.frame()
if (nrow(sources)) {
  for (i in seq_len(nrow(sources))) {
    for (pair in list(c("source_series_wide_path", "source_series_wide_sha256"), c("source_sim_path", "source_sim_sha256"))) {
      path <- as.character(sources[[pair[[1L]]]][[i]])
      expected <- as.character(sources[[pair[[2L]]]][[i]])
      if (!file.exists(path)) add_issue("Missing source artifact: %s", path) else if (!identical(unname(tools::sha256sum(path)), expected)) add_issue("Source hash mismatch: %s", path)
    }
  }
}

manifest_path <- paste0(stub, "_materialization_manifest.json")
manifest <- if (file.exists(manifest_path)) jsonlite::read_json(manifest_path, simplifyVector = TRUE) else NULL
if (is.null(manifest)) add_issue("Missing materialization manifest.") else {
  if (!identical(manifest$canonical_source_registry_identity, "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275")) add_issue("Canonical registry identity changed.")
  if (!identical(manifest$development_source_registry_sha256, "af83f8704ca330a7d0fb7296c2cd8c4f9bf42b09c79851e2c75303de88a8b1e9")) add_issue("Development registry hash changed.")
}

out <- list(
  generated_at = as.character(Sys.time()), status = if (length(issues)) "FAIL" else "PASS",
  issues = as.list(issues), package_version = as.character(desc[1L, "Version"]),
  bundles = nrow(index), qdesn_roots = if (nrow(index)) sum(index$expected_specs) else 0L,
  unique_source_rows = nrow(sources), article_update_allowed = FALSE
)
out_path <- get_arg("--output", file.path("reports", "qdesn_mcmc_validation", stage, "contract_verification.json"))
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(out, out_path, pretty = TRUE, auto_unbox = TRUE, null = "null")
cat(sprintf("Follow-up v1 contract: %s\n", out$status))
cat(sprintf("Q-DESN roots: %d; source rows: %d\n", out$qdesn_roots, out$unique_source_rows))
if (length(issues)) stop(paste(issues, collapse = "\n"), call. = FALSE)
