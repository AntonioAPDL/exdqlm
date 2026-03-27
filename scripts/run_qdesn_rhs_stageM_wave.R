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

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

safe_num <- function(x, default = NA_real_) {
  x <- suppressWarnings(as.numeric(x))
  if (!length(x) || !is.finite(x[1L])) default else x[1L]
}

median_or_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else stats::median(x)
}

max_or_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else max(x)
}

min_or_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else min(x)
}

count_contains <- function(x, token) {
  x <- as.character(x %||% character(0))
  sum(grepl(token, x, fixed = TRUE), na.rm = TRUE)
}

grade_worst <- function(x) {
  g <- toupper(trimws(as.character(x %||% "")))
  if (any(g == "FAIL", na.rm = TRUE)) return("FAIL")
  if (any(g == "WARN", na.rm = TRUE)) return("WARN")
  if (any(g == "PASS", na.rm = TRUE)) return("PASS")
  NA_character_
}

worst_reason <- function(df) {
  if (!nrow(df)) return(NA_character_)
  g <- toupper(as.character(df$signoff_grade %||% ""))
  if (any(g == "FAIL", na.rm = TRUE)) {
    return(as.character(df$signoff_reason[g == "FAIL"][1L] %||% NA_character_))
  }
  if (any(g == "WARN", na.rm = TRUE)) {
    return(as.character(df$signoff_reason[g == "WARN"][1L] %||% NA_character_))
  }
  as.character(df$signoff_reason[1L] %||% NA_character_)
}

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
git_sha <- exdqlm:::.qdesn_validation_git_sha()
run_tag <- as.character(get_arg("--run-tag", paste0("stageM-", stamp, "__git-", git_sha)))[1L]

analysis_root <- resolve_path(
  get_arg("--analysis-root", file.path("reports", "qdesn_mcmc_validation", "rhs_stageM_wave", run_tag)),
  must_work = FALSE
)
results_root <- resolve_path(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "rhs_stageM_wave", run_tag)),
  must_work = FALSE
)

for (d in c(analysis_root, file.path(analysis_root, "tables"), file.path(analysis_root, "manifest"), file.path(analysis_root, "config"))) {
  dir_create(d)
}
dir_create(results_root)

promoted_defaults <- resolve_path(
  get_arg("--promoted-defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_stageJKL_promoted.yaml")),
  must_work = TRUE
)
guardrail_lock <- resolve_path(
  get_arg("--guardrail-lock", file.path("config", "validation", "qdesn_rhs_guardrail_lock.yaml")),
  must_work = TRUE
)
guardrailed_defaults <- resolve_path(
  get_arg("--guardrailed-defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_stageM_guardrailed.yaml")),
  must_work = FALSE
)
canary_grid <- resolve_path(
  get_arg("--canary-grid", file.path("config", "validation", "qdesn_rhs_stageM_seed123_grid.csv")),
  must_work = TRUE
)
full_grid <- resolve_path(
  get_arg("--full-grid", file.path("config", "validation", "qdesn_rhs_stageM_expansion_grid.csv")),
  must_work = TRUE
)
tracker_doc <- resolve_path(
  get_arg("--tracker-doc", file.path("docs", "TRACK__qdesn_rhs_stageM_wave.md")),
  must_work = FALSE
)

create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")
canary_only <- has_flag("--canary-only")

gate_cfg <- list(
  require_zero_fail = TRUE,
  require_all_eligible = TRUE,
  require_all_finite_domain = TRUE,
  require_zero_trace_unavailable = TRUE
)

# Step M0: materialize guardrailed defaults from promoted profile.
base <- yaml::read_yaml(promoted_defaults)
lock <- yaml::read_yaml(guardrail_lock)
if (!is.list(base) || !is.list(lock)) {
  stop("Promoted defaults and guardrail lock must parse as YAML lists.", call. = FALSE)
}
lock$guardrails <- NULL
guardrailed <- modifyList(base, lock)

input_mode <- tolower(as.character(guardrailed$pipeline$readout$input_mode %||% "raw_y_lags")[1L])
decomp_enabled <- isTRUE(guardrailed$pipeline$decomposition$enabled %||% FALSE)
init_log_tau <- guardrailed$pipeline$inference$vb$priors$beta$rhs$init_log_tau %||% NA_real_

if (!identical(input_mode, "raw_y_lags")) {
  stop(sprintf("Guardrail violation: readout.input_mode must be raw_y_lags; got '%s'.", input_mode), call. = FALSE)
}
if (decomp_enabled) {
  stop("Guardrail violation: decomposition.enabled must be FALSE for this validation framework.", call. = FALSE)
}
if (!is.finite(as.numeric(init_log_tau))) {
  stop("Guardrail violation: vb.priors.beta.rhs.init_log_tau must resolve to numeric.", call. = FALSE)
}

dir_create(dirname(guardrailed_defaults))
yaml::write_yaml(guardrailed, guardrailed_defaults)
yaml::write_yaml(guardrailed, file.path(analysis_root, "config", "stageM_guardrailed_defaults.yaml"))

summarize_campaign <- function(stage_id, report_root) {
  pair_df <- read_csv_safe(file.path(report_root, "tables", "campaign_pair_summary.csv"))
  method_df <- read_csv_safe(file.path(report_root, "tables", "campaign_method_signoff.csv"))
  mcmc_df <- method_df[as.character(method_df$method %||% "") == "mcmc", , drop = FALSE]
  gate <- exdqlm:::.qdesn_rhs_campaign_strict_gate(pair_df, cfg = gate_cfg)

  summary <- data.frame(
    stage_id = stage_id,
    n_pairs = as.integer(gate$n_pairs %||% 0L),
    n_pair_fail = as.integer(gate$n_pair_fail %||% 0L),
    n_pair_eligible = as.integer(gate$n_pair_eligible %||% 0L),
    all_finite_ok = isTRUE(gate$all_finite_ok),
    all_domain_ok = isTRUE(gate$all_domain_ok),
    all_finite_domain_ok = isTRUE(gate$all_finite_domain_ok),
    mcmc_signoff_grade_worst = grade_worst(mcmc_df$signoff_grade),
    mcmc_signoff_reason_worst = worst_reason(mcmc_df),
    mcmc_min_ess_rhs_min = min_or_na(mcmc_df$mcmc_min_ess_rhs),
    mcmc_max_geweke_absz_rhs_max = max_or_na(mcmc_df$mcmc_max_geweke_absz_rhs),
    mcmc_max_half_drift_rhs_max = max_or_na(mcmc_df$mcmc_max_half_drift_rhs),
    runtime_ratio_median = median_or_na(pair_df$runtime_ratio_mcmc_vs_vb),
    n_trace_unavailable_total = as.integer(gate$n_trace_unavailable_total %||% 0L),
    gate_pass = isTRUE(gate$pass),
    gate_zero_fail = isTRUE(gate$pass_zero_fail),
    gate_all_eligible = isTRUE(gate$pass_all_eligible),
    gate_finite_domain = isTRUE(gate$pass_finite_domain),
    gate_no_trace_unavailable = isTRUE(gate$pass_trace),
    report_root = report_root,
    stringsAsFactors = FALSE
  )
  list(summary = summary, pair = pair_df, method = method_df, gate = gate)
}

run_campaign <- function(grid_path, results_dir, report_dir) {
  exdqlm:::qdesn_validation_run_campaign(
    grid_path = grid_path,
    defaults_path = guardrailed_defaults,
    results_root = results_dir,
    report_root = report_dir,
    create_plots = create_plots,
    verbose = verbose
  )
}

canary_results <- file.path(results_root, "canary")
canary_reports <- file.path(analysis_root, "canary")
full_results <- file.path(results_root, "full")
full_reports <- file.path(analysis_root, "full")

# Step M1: canary run.
run_canary <- run_campaign(canary_grid, canary_results, canary_reports)
canary <- summarize_campaign("M1_canary", run_canary$report_root)
utils::write.csv(canary$summary, file.path(analysis_root, "tables", "canary_summary.csv"), row.names = FALSE)
utils::write.csv(canary$pair, file.path(analysis_root, "tables", "canary_pair_summary.csv"), row.names = FALSE)

# Step M2: full expansion only if canary passes strict gate.
full <- list(summary = data.frame(stringsAsFactors = FALSE), gate = list(pass = FALSE), pair = data.frame(stringsAsFactors = FALSE))
full_attempted <- FALSE
if (isTRUE(canary$gate$pass) && !isTRUE(canary_only)) {
  full_attempted <- TRUE
  run_full <- run_campaign(full_grid, full_results, full_reports)
  full <- summarize_campaign("M2_full", run_full$report_root)
  utils::write.csv(full$summary, file.path(analysis_root, "tables", "full_summary.csv"), row.names = FALSE)
  utils::write.csv(full$pair, file.path(analysis_root, "tables", "full_pair_summary.csv"), row.names = FALSE)
}

decision <- list(
  canary_pass = isTRUE(canary$gate$pass),
  full_attempted = isTRUE(full_attempted),
  full_pass = isTRUE(full$gate$pass),
  promoted_for_next_wave = isTRUE(full_attempted) && isTRUE(full$gate$pass),
  generated_at = as.character(Sys.time())
)

manifest <- list(
  run_tag = run_tag,
  analysis_root = analysis_root,
  results_root = results_root,
  promoted_defaults = promoted_defaults,
  guardrail_lock = guardrail_lock,
  guardrailed_defaults = guardrailed_defaults,
  canary_grid = canary_grid,
  full_grid = full_grid,
  canary = list(summary = canary$summary, gate = canary$gate, report_root = canary_reports),
  full = list(summary = full$summary, gate = full$gate, report_root = if (isTRUE(full_attempted)) full_reports else NULL),
  decision = decision
)
jsonlite::write_json(
  manifest,
  file.path(analysis_root, "manifest", "stageM_wave_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

tracker_lines <- c(
  "# TRACK: QDESN RHS Stage-M Wave",
  "",
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- analysis_root: `%s`", analysis_root),
  sprintf("- results_root: `%s`", results_root),
  sprintf("- promoted_defaults: `%s`", promoted_defaults),
  sprintf("- guardrail_lock: `%s`", guardrail_lock),
  sprintf("- guardrailed_defaults: `%s`", guardrailed_defaults),
  sprintf("- canary_grid: `%s`", canary_grid),
  sprintf("- full_grid: `%s`", full_grid),
  sprintf("- canary_pass: `%s`", if (isTRUE(canary$gate$pass)) "true" else "false"),
  sprintf("- full_attempted: `%s`", if (isTRUE(full_attempted)) "true" else "false"),
  sprintf("- full_pass: `%s`", if (isTRUE(full$gate$pass)) "true" else "false"),
  sprintf("- promoted_for_next_wave: `%s`", if (isTRUE(decision$promoted_for_next_wave)) "true" else "false"),
  "",
  "## Canary Summary",
  ""
)
tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(canary$summary))
if (isTRUE(full_attempted) && nrow(full$summary)) {
  tracker_lines <- c(tracker_lines, "", "## Full Summary", "")
  tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(full$summary))
}
tracker_lines <- c(
  tracker_lines,
  "",
  "## Decision",
  sprintf("- canary_pass: `%s`", if (isTRUE(canary$gate$pass)) "true" else "false"),
  sprintf("- full_attempted: `%s`", if (isTRUE(full_attempted)) "true" else "false"),
  sprintf("- full_pass: `%s`", if (isTRUE(full$gate$pass)) "true" else "false"),
  sprintf("- promoted_for_next_wave: `%s`", if (isTRUE(decision$promoted_for_next_wave)) "true" else "false")
)
dir_create(dirname(tracker_doc))
writeLines(tracker_lines, tracker_doc)

cat(sprintf("Stage-M analysis root: %s\n", analysis_root))
cat(sprintf("Canary pass: %s\n", if (isTRUE(canary$gate$pass)) "yes" else "no"))
cat(sprintf("Full attempted: %s\n", if (isTRUE(full_attempted)) "yes" else "no"))
cat(sprintf("Full pass: %s\n", if (isTRUE(full$gate$pass)) "yes" else "no"))
cat(sprintf("Tracker: %s\n", tracker_doc))
