#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("yaml")
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

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path)[1L]
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

base_defaults <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_structural_reparam_constc2_v1.yaml")),
  must_work = TRUE
)
lock_path <- resolve_path(
  get_arg("--lock", file.path("config", "validation", "qdesn_rhs_guardrail_lock.yaml")),
  must_work = TRUE
)
output_path <- get_arg("--output", NULL)
if (is.null(output_path) || !nzchar(trimws(output_path))) {
  stop("--output is required.", call. = FALSE)
}
if (!grepl("^(/|~)", output_path)) output_path <- file.path(repo_root, output_path)
output_path <- normalizePath(output_path, winslash = "/", mustWork = FALSE)

base <- yaml::read_yaml(base_defaults)
lock <- yaml::read_yaml(lock_path)
if (!is.list(base) || !is.list(lock)) {
  stop("Both base defaults and lock files must parse as YAML lists.", call. = FALSE)
}

lock$guardrails <- NULL
materialized <- modifyList(base, lock)

input_mode <- tolower(as.character(materialized$pipeline$readout$input_mode %||% "raw_y_lags")[1L])
decomp_enabled <- isTRUE(materialized$pipeline$decomposition$enabled %||% FALSE)
init_log_tau <- materialized$pipeline$inference$vb$priors$beta$rhs$init_log_tau %||% NA_real_

if (!identical(input_mode, "raw_y_lags")) {
  stop(sprintf("Guardrail violation: readout.input_mode must be raw_y_lags; got '%s'.", input_mode), call. = FALSE)
}
if (decomp_enabled) {
  stop("Guardrail violation: decomposition.enabled must be FALSE for this validation framework.", call. = FALSE)
}
if (!is.finite(as.numeric(init_log_tau))) {
  stop("Guardrail violation: vb.priors.beta.rhs.init_log_tau must resolve to numeric.", call. = FALSE)
}

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
yaml::write_yaml(materialized, output_path)

cat(sprintf("Materialized defaults: %s\n", output_path))
cat(sprintf("Base defaults: %s\n", base_defaults))
cat(sprintf("Guardrail lock: %s\n", lock_path))
