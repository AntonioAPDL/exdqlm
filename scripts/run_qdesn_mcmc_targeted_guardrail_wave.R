#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml", "jsonlite")
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

dir_create <- function(path) dir.create(path, recursive = TRUE, showWarnings = FALSE)

safe_chr <- function(x, n = length(x)) {
  out <- as.character(x %||% rep(NA_character_, n))
  if (!length(out)) out <- rep(NA_character_, n)
  out
}

safe_lgl <- function(x, n = length(x), default = FALSE) {
  out <- as.logical(x %||% rep(default, n))
  out[is.na(out)] <- default
  out
}

safe_num <- function(x, n = length(x), default = NA_real_) {
  out <- suppressWarnings(as.numeric(x %||% rep(default, n)))
  if (!length(out)) out <- rep(default, n)
  out
}

resolve_rhs_family_guardrail <- function(cfg) {
  beta_cfg <- cfg$pipeline$inference$vb$priors$beta %||% list()
  beta_prior_type <- tolower(as.character(beta_cfg$type %||% "rhs")[1L])
  rhs_key <- if (identical(beta_prior_type, "rhs_ns")) "rhs_ns" else "rhs"
  rhs_cfg <- beta_cfg[[rhs_key]] %||% beta_cfg$rhs %||% list()

  init_log_tau <- suppressWarnings(as.numeric(rhs_cfg$init_log_tau %||% NA_real_)[1L])
  if (!is.finite(init_log_tau)) {
    init_tau <- suppressWarnings(as.numeric(rhs_cfg$init_tau %||% NA_real_)[1L])
    if (is.finite(init_tau) && init_tau > 0) init_log_tau <- log(init_tau)
  }
  if (!is.finite(init_log_tau)) {
    init_tau2 <- suppressWarnings(as.numeric(rhs_cfg$init_tau2 %||% NA_real_)[1L])
    if (is.finite(init_tau2) && init_tau2 > 0) init_log_tau <- 0.5 * log(init_tau2)
  }
  if (!is.finite(init_log_tau)) init_log_tau <- 0.0

  list(beta_prior_type = beta_prior_type, rhs_key = rhs_key, init_log_tau = as.numeric(init_log_tau))
}

selection_mode <- tolower(as.character(get_arg("--selection", "fail_or_ineligible"))[1L])
include_warn <- isTRUE(has_flag("--include-warn")) || identical(selection_mode, "fail_and_warn")
include_ridge <- isTRUE(has_flag("--include-ridge"))
prepare_only <- has_flag("--prepare-only")
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")
skip_reconcile <- has_flag("--skip-reconcile")
max_roots <- suppressWarnings(as.integer(get_arg("--max-roots", NA_integer_))[1L])
if (!is.finite(max_roots) || max_roots <= 0L) max_roots <- NA_integer_

source_report_root <- resolve_path(
  get_arg(
    "--source-report-root",
    file.path(
      "reports", "qdesn_mcmc_validation", "compare_constc2_v1",
      "20260320-084314__git-37f1bd0"
    )
  ),
  must_work = TRUE
)
base_defaults <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_structural_reparam_constc2_v1.yaml")),
  must_work = TRUE
)
guardrail_lock <- resolve_path(
  get_arg("--guardrail-lock", file.path("config", "validation", "qdesn_rhs_guardrail_lock.yaml")),
  must_work = TRUE
)
results_root_base <- resolve_path(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "targeted_rhs_guardrail_wave")),
  must_work = FALSE
)
report_root_base <- resolve_path(
  get_arg("--report-root", file.path("reports", "qdesn_mcmc_validation", "targeted_rhs_guardrail_wave")),
  must_work = FALSE
)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(trimws(run_tag))) {
  run_tag <- sprintf(
    "%s__git-%s",
    format(Sys.time(), "%Y%m%d-%H%M%S"),
    trimws(system("git rev-parse --short HEAD", intern = TRUE))
  )
}

pair_path <- file.path(source_report_root, "tables", "campaign_pair_summary.csv")
if (!file.exists(pair_path)) {
  stop(sprintf("Required source table missing: %s", pair_path), call. = FALSE)
}
pair_df <- utils::read.csv(pair_path, stringsAsFactors = FALSE)
if (!nrow(pair_df)) {
  stop(sprintf("Source pair summary is empty: %s", pair_path), call. = FALSE)
}

required_cols <- c(
  "root_id", "scenario", "tau", "beta_prior_type", "seed", "reservoir_profile",
  "pair_signoff_grade", "pair_comparison_eligible"
)
missing_cols <- setdiff(required_cols, names(pair_df))
if (length(missing_cols)) {
  stop(sprintf("Source pair summary is missing required columns: %s", paste(missing_cols, collapse = ", ")), call. = FALSE)
}

n <- nrow(pair_df)
pair_grade <- toupper(safe_chr(pair_df$pair_signoff_grade, n = n))
pair_eligible <- safe_lgl(pair_df$pair_comparison_eligible, n = n, default = FALSE)
mcmc_grade <- toupper(safe_chr(pair_df$mcmc_signoff_grade, n = n))
vb_grade <- toupper(safe_chr(pair_df$vb_signoff_grade, n = n))
mcmc_status <- toupper(safe_chr(pair_df$mcmc_status, n = n))
vb_status <- toupper(safe_chr(pair_df$vb_status, n = n))
beta_prior <- tolower(safe_chr(pair_df$beta_prior_type, n = n))

mcmc_success <- mcmc_status == "SUCCESS"
vb_success <- vb_status == "SUCCESS"
is_fail <- (pair_grade == "FAIL") |
  (!pair_eligible) |
  (mcmc_grade == "FAIL") |
  (!mcmc_success) |
  (!vb_success)
is_warn <- (pair_grade == "WARN") | (mcmc_grade == "WARN") | (vb_grade == "WARN")

if (!selection_mode %in% c("fail_only", "fail_or_ineligible", "fail_and_warn", "warn_only")) {
  stop(
    "Unsupported --selection. Use one of: fail_only, fail_or_ineligible, fail_and_warn, warn_only.",
    call. = FALSE
  )
}

selected_idx <- rep(FALSE, n)
if (selection_mode %in% c("fail_only", "fail_or_ineligible")) selected_idx <- is_fail
if (selection_mode == "fail_and_warn") selected_idx <- (is_fail | is_warn)
if (selection_mode == "warn_only") selected_idx <- is_warn
if (include_warn && selection_mode %in% c("fail_only", "fail_or_ineligible")) {
  selected_idx <- selected_idx | is_warn
}
if (!include_ridge) selected_idx <- selected_idx & (beta_prior == "rhs")

selected <- pair_df[selected_idx, , drop = FALSE]
if (!nrow(selected)) {
  stop(
    paste0(
      "No roots selected from source report under current filters. ",
      "Try --include-ridge and/or --selection fail_and_warn."
    ),
    call. = FALSE
  )
}

selected_pair_grade <- toupper(safe_chr(selected$pair_signoff_grade, n = nrow(selected)))
selected_pair_eligible <- safe_lgl(selected$pair_comparison_eligible, n = nrow(selected), default = FALSE)
selected_mcmc_grade <- toupper(safe_chr(selected$mcmc_signoff_grade, n = nrow(selected)))
selected_vb_grade <- toupper(safe_chr(selected$vb_signoff_grade, n = nrow(selected)))
selected_mcmc_status <- toupper(safe_chr(selected$mcmc_status, n = nrow(selected)))
selected_vb_status <- toupper(safe_chr(selected$vb_status, n = nrow(selected)))

selected$selection_reason <- vapply(seq_len(nrow(selected)), function(i) {
  tokens <- character(0)
  if (selected_pair_grade[i] == "FAIL") tokens <- c(tokens, "pair_fail")
  if (!selected_pair_eligible[i]) tokens <- c(tokens, "pair_ineligible")
  if (selected_mcmc_grade[i] == "FAIL") tokens <- c(tokens, "mcmc_fail")
  if (selected_vb_grade[i] == "FAIL") tokens <- c(tokens, "vb_fail")
  if (selected_mcmc_status[i] != "SUCCESS") tokens <- c(tokens, "mcmc_non_success")
  if (selected_vb_status[i] != "SUCCESS") tokens <- c(tokens, "vb_non_success")
  if (selected_pair_grade[i] == "WARN") tokens <- c(tokens, "pair_warn")
  if (selected_mcmc_grade[i] == "WARN") tokens <- c(tokens, "mcmc_warn")
  if (selected_vb_grade[i] == "WARN") tokens <- c(tokens, "vb_warn")
  if (!length(tokens)) tokens <- "selection_rule"
  paste(tokens, collapse = ";")
}, character(1))
selected$selection_context <- vapply(seq_len(nrow(selected)), function(i) {
  pieces <- c(
    paste0("pair_reason=", safe_chr(selected$pair_signoff_reason, nrow(selected))[i]),
    paste0("mcmc_reason=", safe_chr(selected$mcmc_signoff_reason, nrow(selected))[i]),
    paste0("vb_reason=", safe_chr(selected$vb_signoff_reason, nrow(selected))[i])
  )
  paste(pieces, collapse = " | ")
}, character(1))

severity_rank <- ifelse(
  selected_pair_grade == "FAIL" | !selected_pair_eligible,
  3L,
  ifelse(selected_pair_grade == "WARN" | selected_mcmc_grade == "WARN" | selected_vb_grade == "WARN", 2L, 1L)
)
prior_rank <- ifelse(tolower(as.character(selected$beta_prior_type)) == "rhs", 0L, 1L)
ord <- order(-severity_rank, prior_rank, as.character(selected$scenario), safe_num(selected$tau), as.character(selected$root_id))
selected <- selected[ord, , drop = FALSE]
if (is.finite(max_roots)) selected <- utils::head(selected, max_roots)

staging_root <- file.path(report_root_base, "staging", run_tag)
for (d in c(
  staging_root,
  file.path(staging_root, "tables"),
  file.path(staging_root, "config"),
  file.path(staging_root, "manifest")
)) {
  dir_create(d)
}
dir_create(results_root_base)
dir_create(report_root_base)
dir_create(file.path(report_root_base, "comparisons"))

target_grid_path <- file.path(staging_root, "config", "target_grid.csv")
target_defaults_path <- file.path(staging_root, "config", "defaults_guardrailed.yaml")
selection_path <- file.path(staging_root, "tables", "target_selection.csv")

grid_cols <- c("root_id", "scenario", "tau", "beta_prior_type", "seed", "reservoir_profile")
grid_df <- selected[, grid_cols, drop = FALSE]
grid_df$enabled <- TRUE

utils::write.csv(grid_df, target_grid_path, row.names = FALSE)
utils::write.csv(selected, selection_path, row.names = FALSE)

mat_cmd <- c(
  file.path("scripts", "materialize_qdesn_rhs_guardrail_defaults.R"),
  "--base-defaults", base_defaults,
  "--lock", guardrail_lock,
  "--output", target_defaults_path
)
mat_out <- tryCatch(
  system2("Rscript", mat_cmd, stdout = TRUE, stderr = TRUE),
  error = function(e) paste("materializer invocation error:", conditionMessage(e))
)
mat_status <- attr(mat_out, "status") %||% 0L
if (!identical(as.integer(mat_status), 0L)) {
  stop(
    paste(
      "Failed to materialize guardrailed defaults.",
      paste(as.character(mat_out), collapse = "\n"),
      sep = "\n"
    ),
    call. = FALSE
  )
}

materialized <- yaml::read_yaml(target_defaults_path)
materialized$campaign <- materialized$campaign %||% list()
materialized$campaign$name <- paste0("qdesn_mcmc_targeted_rhs_guardrail_wave__", run_tag)
materialized$campaign$results_root <- results_root_base
materialized$campaign$reports_root <- report_root_base

input_mode <- tolower(as.character(materialized$pipeline$readout$input_mode %||% "raw_y_lags")[1L])
decomp_enabled <- isTRUE(materialized$pipeline$decomposition$enabled %||% FALSE)
guardrail <- resolve_rhs_family_guardrail(materialized)
init_log_tau <- guardrail$init_log_tau
if (!identical(input_mode, "raw_y_lags")) {
  stop(sprintf("Materialized defaults violate non-DLM guardrail: readout.input_mode='%s'.", input_mode), call. = FALSE)
}
if (decomp_enabled) {
  stop("Materialized defaults violate non-DLM guardrail: decomposition.enabled must be FALSE.", call. = FALSE)
}
if (!is.finite(init_log_tau)) {
  stop("Materialized defaults violate RHS-family guardrail: init_log_tau is not numeric.", call. = FALSE)
}

yaml::write_yaml(materialized, target_defaults_path)

summary_lines <- c(
  "# QDESN Targeted Guardrail Wave (Prepared)",
  "",
  sprintf("- source_report_root: `%s`", source_report_root),
  sprintf("- selection_mode: `%s`", selection_mode),
  sprintf("- include_warn: `%s`", if (include_warn) "true" else "false"),
  sprintf("- include_ridge: `%s`", if (include_ridge) "true" else "false"),
  sprintf("- n_selected_roots: `%d`", nrow(selected)),
  sprintf("- target_grid: `%s`", target_grid_path),
  sprintf("- target_defaults: `%s`", target_defaults_path),
  sprintf("- non_dlm_guardrail.readout_input_mode: `%s`", input_mode),
  sprintf("- non_dlm_guardrail.decomposition_enabled: `%s`", if (decomp_enabled) "true" else "false"),
  sprintf("- rhs_guardrail.beta_prior_type: `%s`", as.character(guardrail$beta_prior_type)),
  sprintf("- rhs_guardrail.init_log_tau: `%.6f`", init_log_tau)
)
writeLines(summary_lines, file.path(staging_root, "targeted_wave_prepare_summary.md"))

manifest <- list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  source_report_root = source_report_root,
  base_defaults = base_defaults,
  guardrail_lock = guardrail_lock,
  target_grid_path = target_grid_path,
  target_defaults_path = target_defaults_path,
  selection_mode = selection_mode,
  include_warn = include_warn,
  include_ridge = include_ridge,
  n_selected_roots = nrow(selected),
  selected_root_ids = as.character(selected$root_id),
  results_root_base = results_root_base,
  report_root_base = report_root_base,
  non_dlm_guardrail = list(
    readout_input_mode = input_mode,
    decomposition_enabled = decomp_enabled,
    init_log_tau = as.numeric(init_log_tau)
  ),
  git_sha = trimws(system("git rev-parse --short HEAD", intern = TRUE))
)
jsonlite::write_json(
  manifest,
  file.path(staging_root, "manifest", "targeted_wave_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

if (isTRUE(prepare_only)) {
  cat(sprintf("Prepared targeted guardrail wave only (no run).\n"))
  cat(sprintf("Staging root: %s\n", staging_root))
  cat(sprintf("Target grid: %s\n", target_grid_path))
  cat(sprintf("Target defaults: %s\n", target_defaults_path))
  quit(save = "no", status = 0)
}

run <- exdqlm:::qdesn_validation_run_campaign(
  grid_path = target_grid_path,
  defaults_path = target_defaults_path,
  results_root = results_root_base,
  report_root = report_root_base,
  create_plots = create_plots,
  verbose = verbose
)

reconcile_status <- "skipped"
if (!isTRUE(skip_reconcile)) {
  recon_cmd <- c(
    file.path("scripts", "reconcile_qdesn_validation_campaign_status.R"),
    "--report-root", run$report_root,
    "--results-root", run$results_root,
    "--apply"
  )
  recon_out <- tryCatch(
    system2("Rscript", recon_cmd, stdout = TRUE, stderr = TRUE),
    error = function(e) paste("reconcile invocation error:", conditionMessage(e))
  )
  recon_status <- attr(recon_out, "status") %||% 0L
  reconcile_status <- if (identical(as.integer(recon_status), 0L)) "ok" else "error"
}

compare_root <- file.path(report_root_base, "comparisons", paste0("vs_source__", basename(run$report_root)))
exdqlm:::qdesn_validation_compare_campaign_reports(
  baseline_report_root = source_report_root,
  tuned_report_root = run$report_root,
  output_root = compare_root,
  create_plots = create_plots
)

manifest$run_completed_at <- as.character(Sys.time())
manifest$campaign_results_root <- run$results_root
manifest$campaign_report_root <- run$report_root
manifest$comparison_root <- compare_root
manifest$reconcile_status <- reconcile_status
jsonlite::write_json(
  manifest,
  file.path(staging_root, "manifest", "targeted_wave_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)
jsonlite::write_json(
  manifest,
  file.path(run$report_root, "manifest", "targeted_wave_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

cat(sprintf("Targeted wave report root: %s\n", run$report_root))
cat(sprintf("Targeted wave results root: %s\n", run$results_root))
cat(sprintf("Comparison root: %s\n", compare_root))
cat(sprintf("Staging root: %s\n", staging_root))
