#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "jsonlite", "yaml")
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
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

cmd_lines <- function(cmd, args = character()) {
  out <- tryCatch(
    system2(cmd, args = args, stdout = TRUE, stderr = TRUE),
    error = function(e) sprintf("ERROR: %s", conditionMessage(e))
  )
  enc2utf8(out)
}

is_true <- function(x, default = FALSE) {
  out <- as.logical(x)
  out[is.na(out)] <- default
  out
}

safe_rate <- function(num, den) {
  if (!is.finite(den) || den <= 0) return(NA_real_)
  as.numeric(num) / as.numeric(den)
}

scalar_row_list <- function(df) {
  if (!nrow(df)) return(list())
  out <- lapply(df[1L, , drop = FALSE], function(x) {
    if (length(x) == 0L) return(NULL)
    x[[1L]]
  })
  names(out) <- names(df)
  out
}

count_table_df <- function(x, name) {
  if (!length(x)) return(data.frame(stringsAsFactors = FALSE))
  out <- as.data.frame(table(value = as.character(x)), stringsAsFactors = FALSE)
  names(out) <- c(name, "n")
  out[order(out[[name]]), , drop = FALSE]
}

method_signoff_mix <- function(df) {
  if (!nrow(df) || !all(c("method", "signoff_grade") %in% names(df))) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  out <- as.data.frame(table(
    method = as.character(df$method),
    signoff_grade = as.character(df$signoff_grade)
  ), stringsAsFactors = FALSE)
  names(out)[3L] <- "n"
  out[order(out$method, out$signoff_grade), , drop = FALSE]
}

pair_signoff_mix <- function(df) {
  if (!nrow(df) || !"pair_signoff_grade" %in% names(df)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  out <- as.data.frame(table(
    pair_signoff_grade = as.character(df$pair_signoff_grade)
  ), stringsAsFactors = FALSE)
  names(out)[2L] <- "n"
  out[order(out$pair_signoff_grade), , drop = FALSE]
}

healthy_method_mask <- function(df) {
  if (!nrow(df)) return(logical(0))
  finite_ok <- if ("finite_ok" %in% names(df)) is_true(df$finite_ok, default = FALSE) else rep(FALSE, nrow(df))
  domain_ok <- if ("domain_ok" %in% names(df)) is_true(df$domain_ok, default = FALSE) else rep(FALSE, nrow(df))
  status_ok <- if ("status" %in% names(df)) as.character(df$status) == "SUCCESS" else rep(FALSE, nrow(df))
  unhealthy_ok <- if ("unhealthy" %in% names(df)) !is_true(df$unhealthy, default = FALSE) else rep(TRUE, nrow(df))
  collapse_ok <- if ("rhs_collapse_flag" %in% names(df)) !is_true(df$rhs_collapse_flag, default = FALSE) else rep(TRUE, nrow(df))
  signoff_ok <- if ("signoff_grade" %in% names(df)) as.character(df$signoff_grade) != "FAIL" else rep(FALSE, nrow(df))
  status_ok & finite_ok & domain_ok & unhealthy_ok & collapse_ok & signoff_ok
}

healthy_pair_mask <- function(df) {
  if (!nrow(df)) return(logical(0))
  pair_eligible <- if ("pair_comparison_eligible" %in% names(df)) is_true(df$pair_comparison_eligible, default = FALSE) else rep(FALSE, nrow(df))
  pair_signoff_ok <- if ("pair_signoff_grade" %in% names(df)) as.character(df$pair_signoff_grade) != "FAIL" else rep(FALSE, nrow(df))
  both_success <- if ("both_success" %in% names(df)) is_true(df$both_success, default = TRUE) else rep(TRUE, nrow(df))
  both_finite_ok <- if ("both_finite_ok" %in% names(df)) is_true(df$both_finite_ok, default = TRUE) else rep(TRUE, nrow(df))
  both_domain_ok <- if ("both_domain_ok" %in% names(df)) is_true(df$both_domain_ok, default = TRUE) else rep(TRUE, nrow(df))
  pair_eligible & pair_signoff_ok & both_success & both_finite_ok & both_domain_ok
}

root_status_mix_from_results <- function(results_root) {
  roots_dir <- file.path(results_root, "roots")
  if (!dir.exists(roots_dir)) return(data.frame(stringsAsFactors = FALSE))
  root_dirs <- sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE))
  if (!length(root_dirs)) return(data.frame(stringsAsFactors = FALSE))
  statuses <- vapply(
    file.path(root_dirs, "manifest", "root_status.txt"),
    function(path) {
      if (!file.exists(path)) return("MISSING")
      trimws(readLines(path, warn = FALSE, n = 1L))
    },
    character(1)
  )
  count_table_df(statuses, "root_status")
}

validate_grid <- function(grid_df) {
  expected_scenarios <- sort(c("dlm_ar1V", "dlm_constV_bigW", "dlm_constV_smallW"))
  expected_taus <- sort(c(0.05, 0.50, 0.95))
  expected_lf <- sort(c("al", "exal"))
  expected_priors <- sort(c("ridge", "rhs_ns"))

  scenarios <- sort(unique(as.character(grid_df$scenario)))
  taus <- sort(unique(as.numeric(grid_df$tau)))
  likelihoods <- sort(unique(as.character(grid_df$likelihood_family)))
  priors <- sort(unique(as.character(grid_df$beta_prior_type)))

  problems <- character(0)
  if (nrow(grid_df) != 36L) {
    problems <- c(problems, sprintf("enabled root count must be 36; found %d", nrow(grid_df)))
  }
  if (!identical(scenarios, expected_scenarios)) {
    problems <- c(problems, sprintf("scenario set mismatch: %s", paste(scenarios, collapse = ", ")))
  }
  if (!identical(as.numeric(taus), as.numeric(expected_taus))) {
    problems <- c(problems, sprintf("tau set mismatch: %s", paste(taus, collapse = ", ")))
  }
  if (!identical(likelihoods, expected_lf)) {
    problems <- c(problems, sprintf("likelihood_family set mismatch: %s", paste(likelihoods, collapse = ", ")))
  }
  if (!identical(priors, expected_priors)) {
    problems <- c(problems, sprintf("beta_prior_type set mismatch: %s", paste(priors, collapse = ", ")))
  }
  if (length(problems)) {
    stop(paste(c("Grid validation failed:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }

  list(
    expected_roots = nrow(grid_df),
    scenarios = scenarios,
    taus = taus,
    likelihood_families = likelihoods,
    beta_prior_types = priors
  )
}

validate_defaults_contract <- function(defaults) {
  readout_mode <- as.character((((defaults$pipeline %||% list())$readout %||% list())$input_mode %||% "")[1L])
  decomposition_enabled <- isTRUE((((defaults$pipeline %||% list())$decomposition %||% list())$enabled %||% FALSE))
  threads <- as.integer((((defaults$runtime %||% list())$threads %||% NA_integer_)[1L]))
  postpred_threads <- as.integer((((((defaults$pipeline %||% list())$cpp %||% list())$postpred_threads) %||% NA_integer_)[1L]))

  problems <- character(0)
  if (!identical(readout_mode, "raw_y_lags")) {
    problems <- c(problems, sprintf("readout.input_mode must be raw_y_lags, found %s", readout_mode))
  }
  if (isTRUE(decomposition_enabled)) {
    problems <- c(problems, "decomposition.enabled must be FALSE")
  }
  if (!is.na(threads) && threads != 1L) {
    problems <- c(problems, sprintf("runtime.threads must be 1, found %d", threads))
  }
  if (!is.na(postpred_threads) && postpred_threads != 1L) {
    problems <- c(problems, sprintf("pipeline.cpp.postpred_threads must be 1, found %d", postpred_threads))
  }
  if (length(problems)) {
    stop(paste(c("Defaults contract validation failed:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }

  list(
    readout_input_mode = readout_mode,
    decomposition_enabled = decomposition_enabled,
    runtime_threads = threads,
    postpred_threads = postpred_threads
  )
}

build_rollup_row <- function(label, root_mix, method_df, pair_df) {
  root_success_n <- if (nrow(root_mix)) sum(root_mix$n[root_mix$root_status == "SUCCESS"], na.rm = TRUE) else 0L
  root_total_n <- sum(root_mix$n, na.rm = TRUE)
  method_total_n <- nrow(method_df)
  pair_total_n <- nrow(pair_df)
  mcmc_fail_n <- sum(as.character(method_df$method) == "mcmc" & as.character(method_df$signoff_grade) == "FAIL", na.rm = TRUE)
  pair_fail_n <- sum(as.character(pair_df$pair_signoff_grade) == "FAIL", na.rm = TRUE)
  healthy_method_n <- sum(healthy_method_mask(method_df), na.rm = TRUE)
  healthy_pair_n <- sum(healthy_pair_mask(pair_df), na.rm = TRUE)
  comparison_eligible_pair_n <- if ("pair_comparison_eligible" %in% names(pair_df)) sum(is_true(pair_df$pair_comparison_eligible), na.rm = TRUE) else 0L

  data.frame(
    campaign = label,
    root_success_n = as.integer(root_success_n),
    root_total_n = as.integer(root_total_n),
    root_success_rate = safe_rate(root_success_n, root_total_n),
    method_total_n = as.integer(method_total_n),
    mcmc_fail_n = as.integer(mcmc_fail_n),
    pair_total_n = as.integer(pair_total_n),
    pair_fail_n = as.integer(pair_fail_n),
    healthy_method_n = as.integer(healthy_method_n),
    healthy_pair_n = as.integer(healthy_pair_n),
    healthy_pair_rate = safe_rate(healthy_pair_n, pair_total_n),
    comparison_eligible_pair_n = as.integer(comparison_eligible_pair_n),
    comparison_eligible_pair_rate = safe_rate(comparison_eligible_pair_n, pair_total_n),
    stringsAsFactors = FALSE
  )
}

format_healthcheck_md <- function(lines) {
  c(
    "# Final R512 Certification Healthcheck",
    "",
    "```text",
    lines,
    "```"
  )
}

make_acceptance_df <- function(baseline_rollup, tuned_rollup, method_df, expected_roots) {
  all_root_success <- isTRUE(
    identical(as.integer(tuned_rollup$root_total_n[1L]), as.integer(expected_roots)) &&
      identical(as.integer(tuned_rollup$root_success_n[1L]), as.integer(expected_roots))
  )
  all_method_success <- if ("status" %in% names(method_df)) all(as.character(method_df$status) == "SUCCESS") else FALSE
  all_finite_ok <- if ("finite_ok" %in% names(method_df)) all(is_true(method_df$finite_ok), na.rm = TRUE) else FALSE
  all_domain_ok <- if ("domain_ok" %in% names(method_df)) all(is_true(method_df$domain_ok), na.rm = TRUE) else FALSE
  no_collapse <- if ("rhs_collapse_flag" %in% names(method_df)) !any(is_true(method_df$rhs_collapse_flag), na.rm = TRUE) else TRUE

  checks <- data.frame(
    criterion = c(
      "all_36_roots_success",
      "all_method_rows_success",
      "all_method_rows_finite_ok",
      "all_method_rows_domain_ok",
      "no_rhs_collapse_regressions",
      "mcmc_fail_count_not_worse_than_baseline",
      "pair_fail_count_not_worse_than_baseline",
      "healthy_pair_rate_not_worse_than_baseline",
      "comparison_eligible_pair_rate_not_worse_than_baseline"
    ),
    pass = c(
      all_root_success,
      all_method_success,
      all_finite_ok,
      all_domain_ok,
      no_collapse,
      tuned_rollup$mcmc_fail_n[1L] <= baseline_rollup$mcmc_fail_n[1L],
      tuned_rollup$pair_fail_n[1L] <= baseline_rollup$pair_fail_n[1L],
      tuned_rollup$healthy_pair_rate[1L] >= baseline_rollup$healthy_pair_rate[1L],
      tuned_rollup$comparison_eligible_pair_rate[1L] >= baseline_rollup$comparison_eligible_pair_rate[1L]
    ),
    stringsAsFactors = FALSE
  )
  checks
}

args_defaults <- list(
  defaults = file.path("config", "validation", "qdesn_dynamic_family_prior_r512_certification_defaults.yaml"),
  grid = file.path("config", "validation", "qdesn_dynamic_family_prior_grid.csv"),
  baseline_report_root = file.path(
    "reports", "qdesn_mcmc_validation", "dynamic_family_prior_rerun",
    "dynamic-family-prior-20260329-053603", "20260329-053636__git-2641e6b"
  ),
  baseline_results_root = file.path(
    "results", "qdesn_mcmc_validation", "dynamic_family_prior_rerun",
    "dynamic-family-prior-20260329-053603", "20260329-053636__git-2641e6b"
  )
)

defaults_path <- resolve_path(get_arg("--defaults", args_defaults$defaults), must_work = TRUE)
grid_path <- resolve_path(get_arg("--grid", args_defaults$grid), must_work = TRUE)
baseline_report_root <- resolve_path(get_arg("--baseline-report-root", args_defaults$baseline_report_root), must_work = TRUE)
baseline_results_root <- resolve_path(get_arg("--baseline-results-root", args_defaults$baseline_results_root), must_work = TRUE)
prepare_only <- has_flag("--prepare-only")
verbose <- !has_flag("--quiet")
create_campaign_plots <- !has_flag("--no-plots")

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-final-r512-certification-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

defaults <- yaml::read_yaml(defaults_path)
contract <- validate_defaults_contract(defaults)

campaign_cfg <- defaults$campaign %||% list()
base_results_root <- resolve_path(campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "final_r512_certification"), must_work = FALSE)
base_report_root <- resolve_path(campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "final_r512_certification"), must_work = FALSE)

grid_df <- read_csv_safe(grid_path)
if (!nrow(grid_df)) stop(sprintf("Grid is missing or empty: %s", grid_path), call. = FALSE)
if ("enabled" %in% names(grid_df)) {
  grid_df <- grid_df[tolower(as.character(grid_df$enabled)) %in% c("true", "1", "t", "yes", "y"), , drop = FALSE]
}
grid_summary <- validate_grid(grid_df)

required_baseline_tables <- c(
  "campaign_status.csv",
  "campaign_method_summary.csv",
  "campaign_pair_summary.csv",
  "campaign_method_group_summary.csv",
  "campaign_pair_group_summary.csv"
)
missing_baseline_tables <- required_baseline_tables[!file.exists(file.path(baseline_report_root, "tables", required_baseline_tables))]
if (length(missing_baseline_tables)) {
  stop(
    paste(c(
      "Baseline report root is missing required tables:",
      paste0("- ", file.path(baseline_report_root, "tables", missing_baseline_tables))
    ), collapse = "\n"),
    call. = FALSE
  )
}

active_qdesn_processes <- cmd_lines(
  "bash",
  c(
    "-lc",
    paste(
      "ps -eo pid=,args=",
      "| grep -E -- 'run_qdesn_|qdesn-phase|pipeline_sim_main\\.R|pipeline_real_main\\.R'",
      "| grep -vE 'grep -E|run_qdesn_validation_final_r512_certification\\.R'",
      "|| true"
    )
  )
)
active_qdesn_processes <- active_qdesn_processes[nzchar(trimws(active_qdesn_processes))]

workers_arg <- suppressWarnings(as.integer(get_arg("--workers", NA_character_))[1L])
workers <- if (is.finite(workers_arg) && workers_arg >= 1L) {
  min(16L, workers_arg)
} else if (length(active_qdesn_processes)) {
  8L
} else {
  12L
}

run_results_root <- file.path(base_results_root, run_tag)
run_report_root <- file.path(base_report_root, run_tag)
cert_root <- file.path(run_report_root, "final_certification")
cert_tables_dir <- file.path(cert_root, "tables")
cert_comparison_root <- file.path(cert_root, "comparison_vs_baseline")
dir.create(cert_tables_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cert_comparison_root, recursive = TRUE, showWarnings = FALSE)

resource_snapshot <- list(
  generated_at = as.character(Sys.time()),
  nproc = cmd_lines("nproc"),
  lscpu = cmd_lines("bash", c("-lc", "lscpu | sed -n '1,40p'")),
  free_h = cmd_lines("free", "-h"),
  uptime = cmd_lines("uptime"),
  active_qdesn_processes = as.list(active_qdesn_processes)
)

preflight_manifest <- list(
  generated_at = as.character(Sys.time()),
  git_sha = git_sha,
  run_tag = run_tag,
  defaults_path = defaults_path,
  grid_path = grid_path,
  baseline_report_root = baseline_report_root,
  baseline_results_root = baseline_results_root,
  prepare_only = prepare_only,
  create_campaign_plots = create_campaign_plots,
  workers = workers,
  grid_summary = grid_summary,
  contract = contract,
  resource_snapshot = resource_snapshot,
  output_roots = list(
    base_results_root = base_results_root,
    base_report_root = base_report_root,
    campaign_results_root = run_results_root,
    campaign_report_root = run_report_root,
    certification_root = cert_root,
    comparison_root = cert_comparison_root
  ),
  acceptance_criteria = list(
    all_roots_success = TRUE,
    all_method_rows_success = TRUE,
    no_finite_or_domain_regressions = TRUE,
    no_rhs_collapse_regressions = TRUE,
    mcmc_fail_count_not_worse_than_baseline = TRUE,
    pair_fail_count_not_worse_than_baseline = TRUE,
    healthy_pair_rate_not_worse_than_baseline = TRUE,
    comparison_eligible_pair_rate_not_worse_than_baseline = TRUE
  )
)

jsonlite::write_json(
  preflight_manifest,
  file.path(cert_root, "final_r512_certification_preflight_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

preflight_lines <- c(
  "# Final R512 Certification Preflight",
  "",
  sprintf("- generated_at: `%s`", preflight_manifest$generated_at),
  sprintf("- git_sha: `%s`", git_sha),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- defaults_path: `%s`", defaults_path),
  sprintf("- grid_path: `%s`", grid_path),
  sprintf("- baseline_report_root: `%s`", baseline_report_root),
  sprintf("- baseline_results_root: `%s`", baseline_results_root),
  sprintf("- campaign_report_root: `%s`", run_report_root),
  sprintf("- campaign_results_root: `%s`", run_results_root),
  sprintf("- chosen_workers: `%d`", workers),
  sprintf("- active_qdesn_processes_n: `%d`", length(active_qdesn_processes)),
  sprintf("- create_campaign_plots: `%s`", if (isTRUE(create_campaign_plots)) "TRUE" else "FALSE"),
  "",
  "## Grid Validation",
  sprintf("- enabled_roots: `%d`", grid_summary$expected_roots),
  sprintf("- scenarios: `%s`", paste(grid_summary$scenarios, collapse = ", ")),
  sprintf("- taus: `%s`", paste(grid_summary$taus, collapse = ", ")),
  sprintf("- likelihood_families: `%s`", paste(grid_summary$likelihood_families, collapse = ", ")),
  sprintf("- beta_prior_types: `%s`", paste(grid_summary$beta_prior_types, collapse = ", ")),
  "",
  "## Contract Checks",
  sprintf("- readout.input_mode: `%s`", contract$readout_input_mode),
  sprintf("- decomposition.enabled: `%s`", if (isTRUE(contract$decomposition_enabled)) "TRUE" else "FALSE"),
  sprintf("- runtime.threads: `%s`", contract$runtime_threads),
  sprintf("- pipeline.cpp.postpred_threads: `%s`", contract$postpred_threads),
  "",
  "## Active QDESN Processes",
  if (length(active_qdesn_processes)) paste0("- ", active_qdesn_processes) else "- none"
)
writeLines(preflight_lines, file.path(cert_root, "final_r512_certification_preflight.md"))

if (isTRUE(verbose)) {
  cat(sprintf("[final-r512-certification] run_tag=%s\n", run_tag))
  cat(sprintf("[final-r512-certification] workers=%d\n", workers))
  cat(sprintf("[final-r512-certification] prepare_only=%s\n", if (prepare_only) "TRUE" else "FALSE"))
}

if (isTRUE(prepare_only)) {
  cat(sprintf("Preflight manifest: %s\n", file.path(cert_root, "final_r512_certification_preflight_manifest.json")))
  cat(sprintf("Preflight markdown: %s\n", file.path(cert_root, "final_r512_certification_preflight.md")))
  cat(sprintf("Planned campaign report root: %s\n", run_report_root))
  cat(sprintf("Planned campaign results root: %s\n", run_results_root))
  quit(status = 0)
}

run <- exdqlm:::qdesn_validation_run_campaign(
  grid_path = grid_path,
  defaults_path = defaults_path,
  results_root = run_results_root,
  report_root = run_report_root,
  create_plots = create_campaign_plots,
  verbose = verbose,
  workers = workers
)

campaign_report_root <- normalizePath(run$report_root, winslash = "/", mustWork = TRUE)
campaign_results_root <- normalizePath(run$results_root, winslash = "/", mustWork = TRUE)

healthcheck_lines <- cmd_lines(
  "Rscript",
  c(
    "scripts/healthcheck_qdesn_dynamic_family_prior_wave.R",
    "--run-tag", run_tag,
    "--defaults", defaults_path,
    "--grid", grid_path,
    "--results-root", base_results_root,
    "--report-root", base_report_root
  )
)
writeLines(format_healthcheck_md(healthcheck_lines), file.path(cert_root, "final_r512_certification_healthcheck.md"))

comparison_out <- exdqlm:::qdesn_validation_compare_campaign_reports(
  baseline_report_root = baseline_report_root,
  tuned_report_root = campaign_report_root,
  output_root = cert_comparison_root,
  create_plots = TRUE
)

baseline_method <- read_csv_safe(file.path(baseline_report_root, "tables", "campaign_method_summary.csv"))
baseline_pair <- read_csv_safe(file.path(baseline_report_root, "tables", "campaign_pair_summary.csv"))
tuned_method <- read_csv_safe(file.path(campaign_report_root, "tables", "campaign_method_summary.csv"))
tuned_pair <- read_csv_safe(file.path(campaign_report_root, "tables", "campaign_pair_summary.csv"))

baseline_root_mix <- root_status_mix_from_results(baseline_results_root)
tuned_root_mix <- root_status_mix_from_results(campaign_results_root)
baseline_method_mix <- method_signoff_mix(baseline_method)
tuned_method_mix <- method_signoff_mix(tuned_method)
baseline_pair_mix <- pair_signoff_mix(baseline_pair)
tuned_pair_mix <- pair_signoff_mix(tuned_pair)

baseline_rollup <- build_rollup_row("baseline", baseline_root_mix, baseline_method, baseline_pair)
tuned_rollup <- build_rollup_row("r512_certification", tuned_root_mix, tuned_method, tuned_pair)
rollup <- rbind(baseline_rollup, tuned_rollup)
rollup$campaign <- as.character(rollup$campaign)
rollup_delta <- within(tuned_rollup, {
  campaign <- "delta_tuned_minus_baseline"
  root_success_n <- tuned_rollup$root_success_n - baseline_rollup$root_success_n
  root_total_n <- tuned_rollup$root_total_n - baseline_rollup$root_total_n
  root_success_rate <- tuned_rollup$root_success_rate - baseline_rollup$root_success_rate
  method_total_n <- tuned_rollup$method_total_n - baseline_rollup$method_total_n
  mcmc_fail_n <- tuned_rollup$mcmc_fail_n - baseline_rollup$mcmc_fail_n
  pair_total_n <- tuned_rollup$pair_total_n - baseline_rollup$pair_total_n
  pair_fail_n <- tuned_rollup$pair_fail_n - baseline_rollup$pair_fail_n
  healthy_method_n <- tuned_rollup$healthy_method_n - baseline_rollup$healthy_method_n
  healthy_pair_n <- tuned_rollup$healthy_pair_n - baseline_rollup$healthy_pair_n
  healthy_pair_rate <- tuned_rollup$healthy_pair_rate - baseline_rollup$healthy_pair_rate
  comparison_eligible_pair_n <- tuned_rollup$comparison_eligible_pair_n - baseline_rollup$comparison_eligible_pair_n
  comparison_eligible_pair_rate <- tuned_rollup$comparison_eligible_pair_rate - baseline_rollup$comparison_eligible_pair_rate
})
rollup <- rbind(rollup, rollup_delta)

acceptance_df <- make_acceptance_df(
  baseline_rollup = baseline_rollup,
  tuned_rollup = tuned_rollup,
  method_df = tuned_method,
  expected_roots = grid_summary$expected_roots
)
recommendation <- if (all(is_true(acceptance_df$pass), na.rm = TRUE)) {
  "ACCEPT_R512_AS_CERTIFIED_BASELINE"
} else {
  "HOLD_R512_WITH_CAVEATS"
}
failed_criteria <- acceptance_df$criterion[!is_true(acceptance_df$pass)]

pair_group_compare <- read_csv_safe(file.path(cert_comparison_root, "tables", "pair_group_compare.csv"))
method_group_compare <- read_csv_safe(file.path(cert_comparison_root, "tables", "method_group_compare.csv"))

pair_group_excerpt_cols <- intersect(
  c(
    "scenario",
    "tau",
    "beta_prior_type",
    "baseline_pair_comparison_eligible_rate",
    "tuned_pair_comparison_eligible_rate",
    "pair_comparison_eligible_rate_delta_tuned_minus_baseline",
    "baseline_pair_signoff_pass_rate",
    "tuned_pair_signoff_pass_rate",
    "pair_signoff_pass_rate_delta_tuned_minus_baseline",
    "baseline_runtime_ratio_mcmc_vs_vb_mean",
    "tuned_runtime_ratio_mcmc_vs_vb_mean",
    "runtime_ratio_mcmc_vs_vb_mean_delta_tuned_minus_baseline"
  ),
  names(pair_group_compare)
)
pair_group_excerpt <- if (length(pair_group_excerpt_cols)) pair_group_compare[, pair_group_excerpt_cols, drop = FALSE] else pair_group_compare

method_group_excerpt <- method_group_compare[
  if ("method" %in% names(method_group_compare)) as.character(method_group_compare$method) == "mcmc" else rep(TRUE, nrow(method_group_compare)),
, drop = FALSE]
method_group_excerpt_cols <- intersect(
  c(
    "scenario",
    "tau",
    "likelihood_family",
    "beta_prior_type",
    "method",
    "baseline_comparison_eligible_rate",
    "tuned_comparison_eligible_rate",
    "comparison_eligible_rate_delta_tuned_minus_baseline",
    "baseline_signoff_pass_rate",
    "tuned_signoff_pass_rate",
    "signoff_pass_rate_delta_tuned_minus_baseline",
    "fit_runtime_seconds_mean_delta_tuned_minus_baseline"
  ),
  names(method_group_excerpt)
)
method_group_excerpt <- if (length(method_group_excerpt_cols)) method_group_excerpt[, method_group_excerpt_cols, drop = FALSE] else method_group_excerpt

utils::write.csv(baseline_root_mix, file.path(cert_tables_dir, "baseline_root_status_mix.csv"), row.names = FALSE)
utils::write.csv(tuned_root_mix, file.path(cert_tables_dir, "tuned_root_status_mix.csv"), row.names = FALSE)
utils::write.csv(baseline_method_mix, file.path(cert_tables_dir, "baseline_method_signoff_mix.csv"), row.names = FALSE)
utils::write.csv(tuned_method_mix, file.path(cert_tables_dir, "tuned_method_signoff_mix.csv"), row.names = FALSE)
utils::write.csv(baseline_pair_mix, file.path(cert_tables_dir, "baseline_pair_signoff_mix.csv"), row.names = FALSE)
utils::write.csv(tuned_pair_mix, file.path(cert_tables_dir, "tuned_pair_signoff_mix.csv"), row.names = FALSE)
utils::write.csv(rollup, file.path(cert_tables_dir, "campaign_rollup.csv"), row.names = FALSE)
utils::write.csv(acceptance_df, file.path(cert_tables_dir, "acceptance_checks.csv"), row.names = FALSE)
utils::write.csv(pair_group_excerpt, file.path(cert_tables_dir, "pair_group_compare_excerpt.csv"), row.names = FALSE)
utils::write.csv(method_group_excerpt, file.path(cert_tables_dir, "method_group_compare_excerpt.csv"), row.names = FALSE)

summary_lines <- c(
  "# Final R512 Certification Summary",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- git_sha: `%s`", git_sha),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- defaults_path: `%s`", defaults_path),
  sprintf("- grid_path: `%s`", grid_path),
  sprintf("- baseline_report_root: `%s`", baseline_report_root),
  sprintf("- baseline_results_root: `%s`", baseline_results_root),
  sprintf("- campaign_report_root: `%s`", campaign_report_root),
  sprintf("- campaign_results_root: `%s`", campaign_results_root),
  sprintf("- chosen_workers: `%d`", workers),
  sprintf("- create_campaign_plots: `%s`", if (isTRUE(create_campaign_plots)) "TRUE" else "FALSE"),
  "",
  "## Recommendation",
  "",
  sprintf("- final_recommendation: `%s`", recommendation),
  if (length(failed_criteria)) sprintf("- unmet_criteria: `%s`", paste(failed_criteria, collapse = ", ")) else "- unmet_criteria: `none`",
  "",
  "## Campaign Rollup",
  exdqlm:::.qdesn_validation_df_to_markdown(rollup),
  "",
  "## Acceptance Checks",
  exdqlm:::.qdesn_validation_df_to_markdown(acceptance_df),
  "",
  "## Tuned Root Status Mix",
  exdqlm:::.qdesn_validation_df_to_markdown(tuned_root_mix),
  "",
  "## Tuned Method Signoff Mix",
  exdqlm:::.qdesn_validation_df_to_markdown(tuned_method_mix),
  "",
  "## Tuned Pair Signoff Mix",
  exdqlm:::.qdesn_validation_df_to_markdown(tuned_pair_mix),
  "",
  "## Pair Group Deltas By Scenario / Tau / Prior",
  exdqlm:::.qdesn_validation_df_to_markdown(pair_group_excerpt),
  "",
  "## MCMC Method Group Deltas",
  exdqlm:::.qdesn_validation_df_to_markdown(method_group_excerpt),
  "",
  "## Key Output Paths",
  sprintf("- preflight_manifest: `%s`", file.path(cert_root, "final_r512_certification_preflight_manifest.json")),
  sprintf("- healthcheck: `%s`", file.path(cert_root, "final_r512_certification_healthcheck.md")),
  sprintf("- comparison_root: `%s`", cert_comparison_root),
  sprintf("- comparison_summary: `%s`", file.path(cert_comparison_root, "comparison_summary.md")),
  sprintf("- rollup_table: `%s`", file.path(cert_tables_dir, "campaign_rollup.csv")),
  sprintf("- acceptance_checks: `%s`", file.path(cert_tables_dir, "acceptance_checks.csv"))
)
writeLines(summary_lines, file.path(cert_root, "final_r512_certification_summary.md"))

final_manifest <- list(
  generated_at = as.character(Sys.time()),
  git_sha = git_sha,
  run_tag = run_tag,
  recommendation = recommendation,
  failed_criteria = as.list(failed_criteria),
  workers = workers,
  create_campaign_plots = create_campaign_plots,
  defaults_path = defaults_path,
  grid_path = grid_path,
  baseline = list(
    report_root = baseline_report_root,
    results_root = baseline_results_root
  ),
  campaign = list(
    report_root = campaign_report_root,
    results_root = campaign_results_root
  ),
  outputs = list(
    certification_root = cert_root,
    certification_tables = cert_tables_dir,
    comparison_root = cert_comparison_root,
    preflight_manifest = file.path(cert_root, "final_r512_certification_preflight_manifest.json"),
    healthcheck = file.path(cert_root, "final_r512_certification_healthcheck.md"),
    summary = file.path(cert_root, "final_r512_certification_summary.md")
  ),
  baseline_rollup = scalar_row_list(baseline_rollup),
  tuned_rollup = scalar_row_list(tuned_rollup),
  acceptance_checks = lapply(seq_len(nrow(acceptance_df)), function(i) {
    list(
      criterion = as.character(acceptance_df$criterion[i]),
      pass = is_true(acceptance_df$pass[i])
    )
  })
)

jsonlite::write_json(
  final_manifest,
  file.path(cert_root, "final_r512_certification_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

cat(sprintf("Campaign report root: %s\n", campaign_report_root))
cat(sprintf("Campaign results root: %s\n", campaign_results_root))
cat(sprintf("Certification summary: %s\n", file.path(cert_root, "final_r512_certification_summary.md")))
cat(sprintf("Final recommendation: %s\n", recommendation))
