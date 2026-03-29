#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
has_flag <- function(flag) any(args == flag)
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

manifest_path <- resolve_path(get_arg("--phase01-manifest", ""), must_work = TRUE)
workers <- as.integer(get_arg("--workers", "4"))[1L]
if (!is.finite(workers) || workers < 1L) workers <- 1L
allow_expansion <- !has_flag("--skip-expansion")
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

phase01 <- jsonlite::fromJSON(manifest_path, simplifyVector = TRUE)
gateA <- phase01$gateA %||% list(gateA_pass = FALSE)
workspace <- phase01$workspace %||% list()
files <- phase01$files %||% list()
baseline_report_root <- as.character((phase01$baseline %||% list())$report_root %||% "")[1L]

summary_dir <- as.character(workspace$summary_dir %||% dirname(manifest_path))[1L]
tables_dir <- as.character(workspace$tables_dir %||% file.path(dirname(summary_dir), "tables"))[1L]
configs_dir <- as.character(workspace$configs_dir %||% file.path(dirname(summary_dir), "configs"))[1L]
final_report_root <- as.character(workspace$final_report_root %||% dirname(summary_dir))[1L]
final_results_root <- as.character(workspace$final_results_root %||% file.path(repo_root, "results", "qdesn_mcmc_validation", basename(dirname(summary_dir))))[1L]
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(configs_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(final_results_root, recursive = TRUE, showWarnings = FALSE)

if (!isTRUE(gateA$gateA_pass)) {
  out <- list(
    generated_at = as.character(Sys.time()),
    phase = "3-5",
    gateA_pass = FALSE,
    gateB_pass = FALSE,
    recommendation = "hold defaults; escalate to kernel redesign",
    note = "Skipped micro-pilot because Gate A failed."
  )
  jsonlite::write_json(out, file.path(summary_dir, "phase35_manifest.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")
  writeLines(
    c(
      "# QDESN Finalization Phase 3-5",
      "",
      "- Gate A did not pass.",
      "- Micro-pilot and conditional expansion were skipped.",
      "- Recommendation: hold defaults; escalate to kernel redesign."
    ),
    file.path(summary_dir, "phase35_summary.md")
  )
  cat("Gate A failed; Phase 3-5 skipped.\n")
  quit(status = 0)
}

micro_grid_path <- resolve_path(as.character(files$micro_grid %||% ""), must_work = TRUE)
profiles_tbl <- read_csv_safe(resolve_path(as.character(files$profiles %||% ""), must_work = TRUE))
if (!nrow(profiles_tbl)) stop("No remediation profiles available in phase01 outputs.", call. = FALSE)

baseline_method <- read_csv_safe(file.path(baseline_report_root, "tables", "campaign_method_summary.csv"))
baseline_pair <- read_csv_safe(file.path(baseline_report_root, "tables", "campaign_pair_summary.csv"))
if (!nrow(baseline_method) || !nrow(baseline_pair)) stop("Baseline tables missing for phase3-5.", call. = FALSE)

micro_grid <- read_csv_safe(micro_grid_path)
if (!nrow(micro_grid)) stop("Micro-pilot grid is empty.", call. = FALSE)

key_cols <- c("scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile")
keys_present <- key_cols[key_cols %in% names(micro_grid)]

build_key <- function(df, cols = key_cols) {
  cols <- cols[cols %in% names(df)]
  if (!length(cols)) return(character(nrow(df)))
  do.call(paste, c(df[, cols, drop = FALSE], sep = "||"))
}

micro_key <- build_key(micro_grid, key_cols)
baseline_method$root_join_key <- build_key(baseline_method, key_cols)
baseline_pair$root_join_key <- build_key(baseline_pair, key_cols)
base_mcmc_micro <- baseline_method[
  baseline_method$root_join_key %in% micro_key & as.character(baseline_method$method) == "mcmc",
, drop = FALSE]
base_pair_micro <- baseline_pair[baseline_pair$root_join_key %in% micro_key, , drop = FALSE]

if (!nrow(base_mcmc_micro)) stop("Baseline MCMC micro rows are empty.", call. = FALSE)

run_profile <- function(profile_id, defaults_path) {
  report_root <- file.path(final_report_root, "micro_pilot", profile_id)
  results_root <- file.path(final_results_root, "micro_pilot", profile_id)
  dir.create(report_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(results_root, recursive = TRUE, showWarnings = FALSE)
  exdqlm:::qdesn_validation_run_campaign(
    grid_path = micro_grid_path,
    defaults_path = defaults_path,
    results_root = results_root,
    report_root = report_root,
    create_plots = create_plots,
    verbose = verbose,
    workers = workers
  )
}

safe_mean <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  mean(x)
}
safe_median <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  stats::median(x)
}

profile_eval <- function(profile_id, run_obj) {
  method_path <- file.path(run_obj$report_root, "tables", "campaign_method_summary.csv")
  pair_path <- file.path(run_obj$report_root, "tables", "campaign_pair_summary.csv")
  method_df <- read_csv_safe(method_path)
  pair_df <- read_csv_safe(pair_path)
  method_df$root_join_key <- build_key(method_df, key_cols)
  pair_df$root_join_key <- build_key(pair_df, key_cols)

  prof_mcmc <- method_df[
    method_df$root_join_key %in% micro_key & as.character(method_df$method) == "mcmc",
  , drop = FALSE]
  prof_pair <- pair_df[pair_df$root_join_key %in% micro_key, , drop = FALSE]

  merged <- merge(
    base_mcmc_micro[, c("root_join_key", "signoff_grade", "fit_runtime_seconds", "finite_ok", "domain_ok", "rhs_collapse_flag",
                        "forecast_CRPS_mean", "forecast_pinball_tau", "forecast_qhat_mae", "forecast_S_mean",
                        "signal_qhat_rmse", "signal_qhat_corr",
                        "mcmc_min_ess_core", "mcmc_max_geweke_absz_core", "mcmc_max_half_drift_core"), drop = FALSE],
    prof_mcmc[, c("root_join_key", "signoff_grade", "fit_runtime_seconds", "finite_ok", "domain_ok", "rhs_collapse_flag",
                  "forecast_CRPS_mean", "forecast_pinball_tau", "forecast_qhat_mae", "forecast_S_mean",
                  "signal_qhat_rmse", "signal_qhat_corr",
                  "mcmc_min_ess_core", "mcmc_max_geweke_absz_core", "mcmc_max_half_drift_core"), drop = FALSE],
    by = "root_join_key", suffixes = c("_base", "_prof"), all.x = TRUE
  )

  base_fail_n <- sum(as.character(merged$signoff_grade_base) == "FAIL", na.rm = TRUE)
  prof_fail_n <- sum(as.character(merged$signoff_grade_prof) == "FAIL", na.rm = TRUE)
  fail_reduction <- if (base_fail_n > 0) (base_fail_n - prof_fail_n) / base_fail_n else NA_real_

  fail_to_pass <- sum(as.character(merged$signoff_grade_base) == "FAIL" & as.character(merged$signoff_grade_prof) == "PASS", na.rm = TRUE)
  fail_to_warn <- sum(as.character(merged$signoff_grade_base) == "FAIL" & as.character(merged$signoff_grade_prof) == "WARN", na.rm = TRUE)
  fail_to_fail <- sum(as.character(merged$signoff_grade_base) == "FAIL" & as.character(merged$signoff_grade_prof) == "FAIL", na.rm = TRUE)

  no_new_fd <- all((as.logical(merged$finite_ok_prof) %||% FALSE), na.rm = TRUE) &&
    all((as.logical(merged$domain_ok_prof) %||% FALSE), na.rm = TRUE)
  collapse_reg <- any(
    (as.logical(merged$rhs_collapse_flag_base) %||% FALSE) == FALSE &
      (as.logical(merged$rhs_collapse_flag_prof) %||% FALSE) == TRUE,
    na.rm = TRUE
  )
  no_collapse_reg <- !collapse_reg

  runtime_ratio <- suppressWarnings(as.numeric(merged$fit_runtime_seconds_prof) / pmax(as.numeric(merged$fit_runtime_seconds_base), 1e-8))
  runtime_inflation_median <- safe_median(runtime_ratio - 1)
  runtime_ok <- isTRUE(is.finite(runtime_inflation_median) && runtime_inflation_median <= 0.50)

  gateB_pass <- isTRUE(
    is.finite(fail_reduction) && fail_reduction >= 0.40 &&
      no_new_fd && no_collapse_reg && runtime_ok
  )

  diag_shift <- data.frame(
    profile_id = profile_id,
    delta_ess_core = safe_median(as.numeric(merged$mcmc_min_ess_core_prof) - as.numeric(merged$mcmc_min_ess_core_base)),
    delta_geweke_absz = safe_median(as.numeric(merged$mcmc_max_geweke_absz_core_prof) - as.numeric(merged$mcmc_max_geweke_absz_core_base)),
    delta_half_drift = safe_median(as.numeric(merged$mcmc_max_half_drift_core_prof) - as.numeric(merged$mcmc_max_half_drift_core_base)),
    stringsAsFactors = FALSE
  )

  metric_shift <- data.frame(
    profile_id = profile_id,
    delta_forecast_crps = safe_median(as.numeric(merged$forecast_CRPS_mean_prof) - as.numeric(merged$forecast_CRPS_mean_base)),
    delta_forecast_pinball_tau = safe_median(as.numeric(merged$forecast_pinball_tau_prof) - as.numeric(merged$forecast_pinball_tau_base)),
    delta_forecast_qhat_mae = safe_median(as.numeric(merged$forecast_qhat_mae_prof) - as.numeric(merged$forecast_qhat_mae_base)),
    delta_forecast_s = safe_median(as.numeric(merged$forecast_S_mean_prof) - as.numeric(merged$forecast_S_mean_base)),
    delta_signal_qhat_rmse = safe_median(as.numeric(merged$signal_qhat_rmse_prof) - as.numeric(merged$signal_qhat_rmse_base)),
    delta_signal_qhat_corr = safe_median(as.numeric(merged$signal_qhat_corr_prof) - as.numeric(merged$signal_qhat_corr_base)),
    stringsAsFactors = FALSE
  )

  summary_row <- data.frame(
    profile_id = profile_id,
    base_fail_n = as.integer(base_fail_n),
    prof_fail_n = as.integer(prof_fail_n),
    fail_reduction = as.numeric(fail_reduction),
    fail_to_pass = as.integer(fail_to_pass),
    fail_to_warn = as.integer(fail_to_warn),
    fail_to_fail = as.integer(fail_to_fail),
    no_new_finite_domain_violations = as.logical(no_new_fd),
    no_collapse_regression = as.logical(no_collapse_reg),
    runtime_inflation_median = as.numeric(runtime_inflation_median),
    runtime_ok = as.logical(runtime_ok),
    gateB_pass = as.logical(gateB_pass),
    report_root = run_obj$report_root,
    results_root = run_obj$results_root,
    stringsAsFactors = FALSE
  )

  list(
    summary = summary_row,
    diag_shift = diag_shift,
    metric_shift = metric_shift,
    transitions = merged
  )
}

if (isTRUE(verbose)) {
  cat(sprintf("[phase35] manifest: %s\n", manifest_path))
  cat(sprintf("[phase35] workers: %d\n", workers))
  cat(sprintf("[phase35] micro grid: %s\n", micro_grid_path))
}

profile_results <- list()
for (i in seq_len(nrow(profiles_tbl))) {
  pid <- as.character(profiles_tbl$profile_id[i])
  dpath <- resolve_path(as.character(profiles_tbl$defaults_path[i]), must_work = TRUE)
  if (isTRUE(verbose)) cat(sprintf("[phase35] running profile %s\n", pid))
  run_obj <- run_profile(pid, dpath)
  profile_results[[pid]] <- profile_eval(pid, run_obj)
  utils::write.csv(profile_results[[pid]]$transitions, file.path(tables_dir, sprintf("phase35_transitions_%s.csv", pid)), row.names = FALSE)
}

pilot_summary <- do.call(rbind, lapply(profile_results, function(x) x$summary))
pilot_diag <- do.call(rbind, lapply(profile_results, function(x) x$diag_shift))
pilot_metric <- do.call(rbind, lapply(profile_results, function(x) x$metric_shift))
pilot_summary <- pilot_summary[order(-as.numeric(pilot_summary$gateB_pass), -pilot_summary$fail_reduction, pilot_summary$runtime_inflation_median), , drop = FALSE]

utils::write.csv(pilot_summary, file.path(tables_dir, "phase35_micro_pilot_summary.csv"), row.names = FALSE)
utils::write.csv(pilot_diag, file.path(tables_dir, "phase35_micro_pilot_diag_shift.csv"), row.names = FALSE)
utils::write.csv(pilot_metric, file.path(tables_dir, "phase35_micro_pilot_metric_shift.csv"), row.names = FALSE)

gateB_any <- any(as.logical(pilot_summary$gateB_pass), na.rm = TRUE)
winner <- if (gateB_any) pilot_summary[which(as.logical(pilot_summary$gateB_pass))[1], , drop = FALSE] else pilot_summary[0, , drop = FALSE]
winner_profile <- if (nrow(winner)) as.character(winner$profile_id[1]) else NA_character_

expansion_summary <- data.frame(stringsAsFactors = FALSE)
if (gateB_any && allow_expansion) {
  fail_full <- baseline_method[
    as.character(baseline_method$method) == "mcmc" &
      as.character(baseline_method$signoff_grade) == "FAIL",
    key_cols, drop = FALSE
  ]
  fail_full <- unique(fail_full)
  fail_full$enabled <- TRUE
  full_grid_path <- file.path(configs_dir, "full_failing_cell_grid.csv")
  utils::write.csv(fail_full, full_grid_path, row.names = FALSE)

  winner_defaults <- resolve_path(as.character(profiles_tbl$defaults_path[match(winner_profile, profiles_tbl$profile_id)]), must_work = TRUE)
  exp_report_root <- file.path(final_report_root, "expansion", winner_profile)
  exp_results_root <- file.path(final_results_root, "expansion", winner_profile)
  dir.create(exp_report_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(exp_results_root, recursive = TRUE, showWarnings = FALSE)

  if (isTRUE(verbose)) cat(sprintf("[phase35] running expansion for winner=%s\n", winner_profile))
  exp_run <- exdqlm:::qdesn_validation_run_campaign(
    grid_path = full_grid_path,
    defaults_path = winner_defaults,
    results_root = exp_results_root,
    report_root = exp_report_root,
    create_plots = create_plots,
    verbose = verbose,
    workers = workers
  )

  exp_method <- read_csv_safe(file.path(exp_run$report_root, "tables", "campaign_method_summary.csv"))
  exp_method$root_join_key <- build_key(exp_method, key_cols)
  base_fail_full <- baseline_method[
    as.character(baseline_method$method) == "mcmc" &
      as.character(baseline_method$signoff_grade) == "FAIL",
  , drop = FALSE]
  base_fail_full$root_join_key <- build_key(base_fail_full, key_cols)
  exp_mcmc <- exp_method[as.character(exp_method$method) == "mcmc", , drop = FALSE]
  merged_exp <- merge(
    base_fail_full[, c("root_join_key", "signoff_grade", "fit_runtime_seconds", "finite_ok", "domain_ok", "rhs_collapse_flag"), drop = FALSE],
    exp_mcmc[, c("root_join_key", "signoff_grade", "fit_runtime_seconds", "finite_ok", "domain_ok", "rhs_collapse_flag"), drop = FALSE],
    by = "root_join_key", suffixes = c("_base", "_exp"), all.x = TRUE
  )
  base_fail_n <- sum(as.character(merged_exp$signoff_grade_base) == "FAIL", na.rm = TRUE)
  exp_fail_n <- sum(as.character(merged_exp$signoff_grade_exp) == "FAIL", na.rm = TRUE)
  fail_reduction <- if (base_fail_n > 0) (base_fail_n - exp_fail_n) / base_fail_n else NA_real_
  no_new_fd <- all(as.logical(merged_exp$finite_ok_exp), na.rm = TRUE) &&
    all(as.logical(merged_exp$domain_ok_exp), na.rm = TRUE)
  collapse_reg <- any(
    (as.logical(merged_exp$rhs_collapse_flag_base) %||% FALSE) == FALSE &
      (as.logical(merged_exp$rhs_collapse_flag_exp) %||% FALSE) == TRUE,
    na.rm = TRUE
  )
  runtime_ratio <- suppressWarnings(as.numeric(merged_exp$fit_runtime_seconds_exp) / pmax(as.numeric(merged_exp$fit_runtime_seconds_base), 1e-8))
  runtime_inflation_median <- safe_median(runtime_ratio - 1)

  expansion_summary <- data.frame(
    winner_profile = winner_profile,
    n_fail_baseline = as.integer(base_fail_n),
    n_fail_expansion = as.integer(exp_fail_n),
    fail_reduction = as.numeric(fail_reduction),
    no_new_finite_domain_violations = as.logical(no_new_fd),
    no_collapse_regression = as.logical(!collapse_reg),
    runtime_inflation_median = as.numeric(runtime_inflation_median),
    report_root = exp_run$report_root,
    results_root = exp_run$results_root,
    stringsAsFactors = FALSE
  )
  utils::write.csv(merged_exp, file.path(tables_dir, "phase35_expansion_transitions.csv"), row.names = FALSE)
  utils::write.csv(expansion_summary, file.path(tables_dir, "phase35_expansion_summary.csv"), row.names = FALSE)
}

final_recommendation <- if (!gateB_any) {
  "hold defaults; escalate to kernel redesign"
} else if (!nrow(expansion_summary)) {
  "promote tuned MCMC defaults (pilot-passing winner); expansion pending/manual"
} else if (
  isTRUE(expansion_summary$fail_reduction[1] >= 0.40) &&
    isTRUE(expansion_summary$no_new_finite_domain_violations[1]) &&
    isTRUE(expansion_summary$no_collapse_regression[1]) &&
    isTRUE(expansion_summary$runtime_inflation_median[1] <= 0.50)
) {
  "promote tuned MCMC defaults"
} else {
  "hold defaults; escalate to kernel redesign"
}

phase35 <- list(
  generated_at = as.character(Sys.time()),
  phase = "3-5",
  gateA_pass = TRUE,
  gateB_pass = isTRUE(gateB_any),
  winner_profile = winner_profile,
  allow_expansion = allow_expansion,
  recommendation = final_recommendation,
  files = list(
    pilot_summary = file.path(tables_dir, "phase35_micro_pilot_summary.csv"),
    pilot_diag_shift = file.path(tables_dir, "phase35_micro_pilot_diag_shift.csv"),
    pilot_metric_shift = file.path(tables_dir, "phase35_micro_pilot_metric_shift.csv"),
    expansion_summary = file.path(tables_dir, "phase35_expansion_summary.csv")
  )
)
jsonlite::write_json(phase35, file.path(summary_dir, "phase35_manifest.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")

summary_lines <- c(
  "# QDESN Finalization Phase 3-5",
  "",
  sprintf("- generated_at: `%s`", phase35$generated_at),
  sprintf("- gateA_pass: `%s`", if (isTRUE(phase35$gateA_pass)) "TRUE" else "FALSE"),
  sprintf("- gateB_pass: `%s`", if (isTRUE(phase35$gateB_pass)) "TRUE" else "FALSE"),
  sprintf("- winner_profile: `%s`", as.character(phase35$winner_profile %||% NA_character_)),
  sprintf("- allow_expansion: `%s`", if (allow_expansion) "TRUE" else "FALSE"),
  sprintf("- recommendation: `%s`", phase35$recommendation),
  "",
  "## Micro-Pilot Summary",
  exdqlm:::.qdesn_validation_df_to_markdown(pilot_summary),
  "",
  "## Micro-Pilot Diagnostic Shift",
  exdqlm:::.qdesn_validation_df_to_markdown(pilot_diag),
  "",
  "## Micro-Pilot Metric Shift",
  exdqlm:::.qdesn_validation_df_to_markdown(pilot_metric),
  "",
  "## Expansion Summary",
  exdqlm:::.qdesn_validation_df_to_markdown(expansion_summary)
)
writeLines(summary_lines, file.path(summary_dir, "phase35_summary.md"))

cat(sprintf("Phase35 summary: %s\n", file.path(summary_dir, "phase35_summary.md")))
cat(sprintf("Phase35 manifest: %s\n", file.path(summary_dir, "phase35_manifest.json")))
