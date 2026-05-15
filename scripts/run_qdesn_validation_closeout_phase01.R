#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "jsonlite", "yaml")
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

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("closeout-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

baseline_results_root <- resolve_path(
  get_arg(
    "--baseline-results-root",
    file.path(
      "results", "qdesn_mcmc_validation", "dynamic_family_prior_rerun",
      "dynamic-family-prior-20260329-053603", "20260329-053636__git-2641e6b"
    )
  ),
  must_work = TRUE
)
baseline_report_root <- resolve_path(
  get_arg(
    "--baseline-report-root",
    file.path(
      "reports", "qdesn_mcmc_validation", "dynamic_family_prior_rerun",
      "dynamic-family-prior-20260329-053603", "20260329-053636__git-2641e6b"
    )
  ),
  must_work = TRUE
)
base_defaults_path <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_dynamic_family_prior_defaults.yaml")),
  must_work = TRUE
)
micro_size <- as.integer(get_arg("--micro-size", "4"))[1L]
if (!is.finite(micro_size) || micro_size < 4L) micro_size <- 4L
if (micro_size > 6L) micro_size <- 6L

final_report_root <- file.path(repo_root, "reports", "qdesn_mcmc_validation", paste0("finalization_", run_tag))
final_results_root <- file.path(repo_root, "results", "qdesn_mcmc_validation", paste0("finalization_", run_tag))
summary_dir <- file.path(final_report_root, "summary")
tables_dir <- file.path(final_report_root, "tables")
configs_dir <- file.path(final_report_root, "configs")
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(configs_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(final_results_root, recursive = TRUE, showWarnings = FALSE)

status_path <- file.path(baseline_report_root, "tables", "campaign_status.csv")
method_path <- file.path(baseline_report_root, "tables", "campaign_method_summary.csv")
pair_path <- file.path(baseline_report_root, "tables", "campaign_pair_summary.csv")
method_group_path <- file.path(baseline_report_root, "tables", "campaign_method_group_summary.csv")
pair_group_path <- file.path(baseline_report_root, "tables", "campaign_pair_group_summary.csv")

status_df <- read_csv_safe(status_path)
method_df <- read_csv_safe(method_path)
pair_df <- read_csv_safe(pair_path)
method_group_df <- read_csv_safe(method_group_path)
pair_group_df <- read_csv_safe(pair_group_path)

if (!nrow(method_df)) stop("Baseline method summary is missing/empty.", call. = FALSE)
if (!nrow(pair_df)) stop("Baseline pair summary is missing/empty.", call. = FALSE)

proc_lines <- suppressWarnings(system(
  "pgrep -af \"run_qdesn_|pipeline_sim_main.R|pipeline_real_main.R\" | grep -v \"pgrep -af\" | grep -v \"run_qdesn_validation_closeout_\" || true",
  intern = TRUE
))
active_qdesn_processes <- proc_lines[nzchar(trimws(proc_lines))]

preflight <- list(
  generated_at = as.character(Sys.time()),
  git_sha = git_sha,
  run_tag = run_tag,
  baseline_results_root = baseline_results_root,
  baseline_report_root = baseline_report_root,
  baseline_tables = list(
    campaign_status = status_path,
    campaign_method_summary = method_path,
    campaign_pair_summary = pair_path,
    campaign_method_group_summary = method_group_path,
    campaign_pair_group_summary = pair_group_path
  ),
  finalization_workspace = list(
    report_root = final_report_root,
    results_root = final_results_root,
    summary_dir = summary_dir,
    tables_dir = tables_dir,
    configs_dir = configs_dir
  ),
  active_qdesn_processes = as.list(active_qdesn_processes),
  stale_exclusions = list(
    "dynamic-family-prior-20260329-053316" = "ABORTED_STALE",
    "stageP-20260327-181230__git-2641e6b/ridge_anchor" = "ABORTED_STALE"
  )
)
jsonlite::write_json(
  preflight,
  file.path(summary_dir, "phase01_preflight_manifest.json"),
  pretty = TRUE, auto_unbox = TRUE, null = "null"
)

preflight_lines <- c(
  "# QDESN Finalization Preflight",
  "",
  sprintf("- generated_at: `%s`", preflight$generated_at),
  sprintf("- git_sha: `%s`", git_sha),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- baseline_report_root: `%s`", baseline_report_root),
  sprintf("- baseline_results_root: `%s`", baseline_results_root),
  sprintf("- final_report_root: `%s`", final_report_root),
  sprintf("- final_results_root: `%s`", final_results_root),
  sprintf("- active_qdesn_processes_n: `%d`", length(active_qdesn_processes)),
  "",
  "## Active Process Snapshot",
  if (length(active_qdesn_processes)) paste0("- ", active_qdesn_processes) else "- none",
  "",
  "## Stale Exclusion Registry",
  "- dynamic-family-prior-20260329-053316: ABORTED_STALE",
  "- stageP-20260327-181230__git-2641e6b/ridge_anchor: ABORTED_STALE"
)
writeLines(preflight_lines, file.path(summary_dir, "phase01_preflight.md"))

is_true <- function(x) {
  out <- as.logical(x)
  out[is.na(out)] <- FALSE
  out
}

method_df$healthy_method <- with(
  method_df,
  status == "SUCCESS" &
    is_true(finite_ok) &
    is_true(domain_ok) &
    !is_true(unhealthy) &
    (!("rhs_collapse_flag" %in% names(method_df)) | !is_true(rhs_collapse_flag)) &
    as.character(signoff_grade) != "FAIL"
)
pair_df$healthy_pair <- with(
  pair_df,
  as.character(pair_signoff_grade) != "FAIL" &
    is_true(pair_comparison_eligible) &
    is_true(both_finite_ok) &
    is_true(both_domain_ok)
)

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
pct <- function(num, den) {
  if (!is.finite(den) || den <= 0) return(NA_real_)
  100 * (as.numeric(num) / as.numeric(den))
}

method_summary_fn <- function(df, label) {
  split_df <- split(df, list(df$method, df$likelihood_family, df$beta_prior_type), drop = TRUE)
  rows <- lapply(split_df, function(sub) {
    data.frame(
      scope = label,
      method = as.character(sub$method[1]),
      likelihood_family = as.character(sub$likelihood_family[1]),
      beta_prior_type = as.character(sub$beta_prior_type[1]),
      n = nrow(sub),
      signoff_pass = sum(as.character(sub$signoff_grade) == "PASS", na.rm = TRUE),
      signoff_warn = sum(as.character(sub$signoff_grade) == "WARN", na.rm = TRUE),
      signoff_fail = sum(as.character(sub$signoff_grade) == "FAIL", na.rm = TRUE),
      eligible_rate_pct = pct(sum(is_true(sub$comparison_eligible), na.rm = TRUE), nrow(sub)),
      fit_runtime_mean = safe_mean(sub$fit_runtime_seconds),
      fit_runtime_median = safe_median(sub$fit_runtime_seconds),
      forecast_crps_mean = safe_mean(sub$forecast_CRPS_mean),
      forecast_pinball_tau_mean = safe_mean(sub$forecast_pinball_tau),
      forecast_qhat_mae_mean = safe_mean(sub$forecast_qhat_mae),
      forecast_s_mean = safe_mean(sub$forecast_S_mean),
      signal_qhat_rmse_mean = safe_mean(sub$signal_qhat_rmse),
      signal_qhat_corr_mean = safe_mean(sub$signal_qhat_corr),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
pair_summary_fn <- function(df, label) {
  split_df <- split(df, list(df$likelihood_family, df$beta_prior_type), drop = TRUE)
  rows <- lapply(split_df, function(sub) {
    data.frame(
      scope = label,
      likelihood_family = as.character(sub$likelihood_family[1]),
      beta_prior_type = as.character(sub$beta_prior_type[1]),
      n = nrow(sub),
      pair_pass = sum(as.character(sub$pair_signoff_grade) == "PASS", na.rm = TRUE),
      pair_warn = sum(as.character(sub$pair_signoff_grade) == "WARN", na.rm = TRUE),
      pair_fail = sum(as.character(sub$pair_signoff_grade) == "FAIL", na.rm = TRUE),
      eligible_rate_pct = pct(sum(is_true(sub$pair_comparison_eligible), na.rm = TRUE), nrow(sub)),
      runtime_ratio_mcmc_vs_vb_mean = safe_mean(sub$runtime_ratio_mcmc_vs_vb),
      runtime_ratio_mcmc_vs_vb_median = safe_median(sub$runtime_ratio_mcmc_vs_vb),
      forecast_crps_delta_mean = safe_mean(sub$forecast_CRPS_delta_mcmc_minus_vb),
      forecast_pinball_tau_delta_mean = safe_mean(sub$forecast_pinball_tau_delta_mcmc_minus_vb),
      forecast_qhat_mae_delta_mean = safe_mean(sub$forecast_qhat_mae_delta_mcmc_minus_vb),
      signal_qhat_rmse_delta_mean = safe_mean(sub$signal_qhat_rmse_delta_mcmc_minus_vb),
      signal_qhat_corr_delta_mean = safe_mean(sub$signal_qhat_corr_delta_mcmc_minus_vb),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

method_all_tbl <- method_summary_fn(method_df, "all_fits")
method_healthy_tbl <- method_summary_fn(method_df[is_true(method_df$healthy_method), , drop = FALSE], "healthy_only")
pair_all_tbl <- pair_summary_fn(pair_df, "all_pairs")
pair_healthy_tbl <- pair_summary_fn(pair_df[is_true(pair_df$healthy_pair), , drop = FALSE], "healthy_only_pairs")

utils::write.csv(method_all_tbl, file.path(tables_dir, "phase01_method_all_fits.csv"), row.names = FALSE)
utils::write.csv(method_healthy_tbl, file.path(tables_dir, "phase01_method_healthy_only.csv"), row.names = FALSE)
utils::write.csv(pair_all_tbl, file.path(tables_dir, "phase01_pair_all_fits.csv"), row.names = FALSE)
utils::write.csv(pair_healthy_tbl, file.path(tables_dir, "phase01_pair_healthy_only.csv"), row.names = FALSE)

key_cols <- c("scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile")
mcmc_fail <- method_df[
  as.character(method_df$method) == "mcmc" &
    as.character(method_df$signoff_grade) == "FAIL",
, drop = FALSE]

flag_has <- function(x, token) grepl(token, as.character(x %||% ""), fixed = TRUE)

if (nrow(mcmc_fail)) {
  mcmc_fail$flag_low_ess <- flag_has(mcmc_fail$signoff_reason, "low_ess")
  mcmc_fail$flag_high_acf <- flag_has(mcmc_fail$signoff_reason, "high_autocorrelation")
  mcmc_fail$flag_geweke <- flag_has(mcmc_fail$signoff_reason, "geweke_drift")
  mcmc_fail$flag_half_drift <- flag_has(mcmc_fail$signoff_reason, "half_chain_drift")
  mcmc_fail$failure_cluster <- ifelse(
    mcmc_fail$flag_low_ess & mcmc_fail$flag_high_acf & mcmc_fail$flag_geweke & mcmc_fail$flag_half_drift, "all_four",
    ifelse(
      mcmc_fail$flag_low_ess & mcmc_fail$flag_high_acf, "ess_acf",
      ifelse(
        mcmc_fail$flag_geweke & mcmc_fail$flag_half_drift, "drift_geweke",
        ifelse(
          mcmc_fail$flag_half_drift, "half_drift",
          ifelse(
            mcmc_fail$flag_low_ess, "low_ess",
            ifelse(
              mcmc_fail$flag_geweke, "geweke",
              ifelse(mcmc_fail$flag_high_acf, "high_acf", "other")
            )
          )
        )
      )
    )
  )
} else {
  mcmc_fail$failure_cluster <- character(0)
}

pair_join_cols <- intersect(key_cols, names(pair_df))
if (nrow(mcmc_fail) && length(pair_join_cols)) {
  pair_join <- pair_df[, c(pair_join_cols, "runtime_ratio_mcmc_vs_vb"), drop = FALSE]
  names(pair_join)[names(pair_join) == "runtime_ratio_mcmc_vs_vb"] <- "runtime_ratio_pair"
  mcmc_fail <- merge(
    mcmc_fail,
    pair_join,
    by = pair_join_cols,
    all.x = TRUE
  )
} else {
  mcmc_fail$runtime_ratio_pair <- NA_real_
}

forensic_cols <- c(
  key_cols,
  "signoff_reason", "failure_cluster",
  "mcmc_min_ess_core", "mcmc_max_acf1_core", "mcmc_max_geweke_absz_core", "mcmc_max_half_drift_core",
  "fit_runtime_seconds", "runtime_ratio_pair",
  "rhs_diag_available", "rhs_collapse_flag", "rhs_root_cause_context"
)
forensic_cols <- forensic_cols[forensic_cols %in% names(mcmc_fail)]
forensic_tbl <- if (nrow(mcmc_fail)) mcmc_fail[, forensic_cols, drop = FALSE] else data.frame(stringsAsFactors = FALSE)
utils::write.csv(forensic_tbl, file.path(tables_dir, "phase01_mcmc_fail_forensics.csv"), row.names = FALSE)

cluster_tbl <- data.frame(stringsAsFactors = FALSE)
if (nrow(mcmc_fail)) {
  ess_warn <- 10
  acf_warn <- 0.98
  geweke_warn <- 3
  drift_warn <- 0.5
  score_ess <- pmax(0, (ess_warn - as.numeric(mcmc_fail$mcmc_min_ess_core)) / ess_warn)
  score_acf <- pmax(0, (as.numeric(mcmc_fail$mcmc_max_acf1_core) - acf_warn) / (1 - acf_warn))
  score_geweke <- pmax(0, (as.numeric(mcmc_fail$mcmc_max_geweke_absz_core) - geweke_warn) / geweke_warn)
  score_drift <- pmax(0, (as.numeric(mcmc_fail$mcmc_max_half_drift_core) - drift_warn) / drift_warn)
  score_mat <- cbind(low_ess = score_ess, high_acf = score_acf, geweke_drift = score_geweke, half_chain_drift = score_drift)
  mcmc_fail$failure_mode <- colnames(score_mat)[max.col(score_mat, ties.method = "first")]
  mcmc_fail$severity <- rowSums(score_mat, na.rm = TRUE)

  split_cluster <- split(mcmc_fail, mcmc_fail$failure_mode, drop = TRUE)
  cluster_rows <- lapply(split_cluster, function(sub) {
    data.frame(
      failure_cluster = as.character(sub$failure_mode[1]),
      n_fail = nrow(sub),
      share_fail_pct = pct(nrow(sub), nrow(mcmc_fail)),
      median_ess = safe_median(sub$mcmc_min_ess_core),
      median_acf1 = safe_median(sub$mcmc_max_acf1_core),
      median_geweke_absz = safe_median(sub$mcmc_max_geweke_absz_core),
      median_half_drift = safe_median(sub$mcmc_max_half_drift_core),
      median_runtime_ratio_mcmc_vs_vb = safe_median(sub$runtime_ratio_pair),
      impact_score = nrow(sub) * (safe_median(sub$severity) %||% 0),
      stringsAsFactors = FALSE
    )
  })
  cluster_tbl <- do.call(rbind, cluster_rows)
  cluster_tbl <- cluster_tbl[order(-cluster_tbl$n_fail, -cluster_tbl$impact_score), , drop = FALSE]
}
utils::write.csv(cluster_tbl, file.path(tables_dir, "phase01_mcmc_fail_cluster_rank.csv"), row.names = FALSE)

gateA_top3_share <- if (nrow(cluster_tbl)) {
  topn <- min(3L, nrow(cluster_tbl))
  sum(cluster_tbl$n_fail[seq_len(topn)]) / sum(cluster_tbl$n_fail)
} else {
  NA_real_
}
gateA_pass <- isTRUE(is.finite(gateA_top3_share) && gateA_top3_share >= 0.70)

baseline_fail_roots <- unique(mcmc_fail[, key_cols[key_cols %in% names(mcmc_fail)], drop = FALSE])
if (nrow(baseline_fail_roots)) {
  sev <- mcmc_fail
  if (!"severity" %in% names(sev)) {
    sev$severity <- with(
      sev,
      (1 / pmax(as.numeric(mcmc_min_ess_core), 1e-6)) +
        pmax(as.numeric(mcmc_max_acf1_core), 0) +
        pmax(as.numeric(mcmc_max_geweke_absz_core), 0) +
        pmax(as.numeric(mcmc_max_half_drift_core), 0)
    )
  }
  sev <- sev[order(-sev$severity), c(key_cols, "failure_cluster", "severity")]
  sev <- sev[!duplicated(do.call(paste, c(sev[key_cols], sep = "||"))), ]
  baseline_fail_roots <- merge(
    baseline_fail_roots,
    sev,
    by = key_cols,
    all.x = TRUE
  )
} else {
  baseline_fail_roots$severity <- numeric(0)
  baseline_fail_roots$failure_cluster <- character(0)
}

select_micro_roots <- function(df, size = 4L) {
  if (!nrow(df)) return(df)
  df <- df[order(-as.numeric(df$severity %||% 0)), , drop = FALSE]
  make_key <- function(x) do.call(paste, c(x[, key_cols, drop = FALSE], sep = "||"))
  chosen <- logical(nrow(df))
  add_first <- function(cond) {
    idx <- which(cond & !chosen)
    if (!length(idx)) return(invisible(NULL))
    chosen[idx[1]] <<- TRUE
    invisible(NULL)
  }
  add_first(abs(as.numeric(df$tau) - 0.5) < 1e-8)
  add_first(as.numeric(df$tau) %in% c(0.05, 0.95))
  if (length(unique(as.character(df$likelihood_family))) > 1L) {
    add_first(as.character(df$likelihood_family) == "al")
    add_first(as.character(df$likelihood_family) == "exal")
  }
  if ("rhs_ns" %in% unique(as.character(df$beta_prior_type))) {
    add_first(as.character(df$beta_prior_type) == "rhs_ns")
  }
  while (sum(chosen) < min(size, nrow(df))) {
    idx <- which(!chosen)
    if (!length(idx)) break
    chosen[idx[1]] <- TRUE
  }
  out <- df[chosen, , drop = FALSE]
  out <- out[order(-as.numeric(out$severity %||% 0)), , drop = FALSE]
  utils::head(out, size)
}

micro_roots <- if (gateA_pass) select_micro_roots(baseline_fail_roots, size = micro_size) else baseline_fail_roots[0, , drop = FALSE]
if (nrow(micro_roots)) {
  micro_grid <- micro_roots[, key_cols, drop = FALSE]
  micro_grid$enabled <- TRUE
  utils::write.csv(micro_grid, file.path(configs_dir, "micro_pilot_grid.csv"), row.names = FALSE)
  utils::write.csv(micro_roots, file.path(tables_dir, "phase01_micro_pilot_roots_selected.csv"), row.names = FALSE)
}

base_defaults <- yaml::read_yaml(base_defaults_path)
make_profile_defaults <- function(profile_id, defaults) {
  cfg <- defaults
  cfg$campaign <- cfg$campaign %||% list()
  cfg$campaign$name <- paste0("qdesn_finalization_", profile_id)
  cfg$pipeline <- cfg$pipeline %||% list()
  cfg$pipeline$inference <- cfg$pipeline$inference %||% list()
  cfg$pipeline$inference$mcmc <- cfg$pipeline$inference$mcmc %||% list()
  cfg$pipeline$inference$mcmc$prior_overrides <- cfg$pipeline$inference$mcmc$prior_overrides %||% list()
  cfg$pipeline$inference$mcmc$prior_overrides$ridge <- cfg$pipeline$inference$mcmc$prior_overrides$ridge %||% list()
  cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns <- cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns %||% list()
  cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs <- cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs %||% list()
  cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt <- cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt %||% list()

  if (identical(profile_id, "P1_longer_chain")) {
    cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_burn <- 600L
    cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_mcmc <- 1600L
    cfg$pipeline$inference$mcmc$prior_overrides$ridge$progress_every <- 80L
    cfg$pipeline$inference$mcmc$prior_overrides$ridge$slice <- list(
      width_gamma = 0.55, width_sigma = 0.30, max_steps_out = 50L, max_shrink = 200L
    )
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 900L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 2200L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 120L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$freeze_tau_burnin_iters <- 50L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt$warmup_iters <- 400L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt$step_size <- 0.015
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice <- list(
      width_gamma = 0.50, width_sigma = 0.30,
      width_rhs_lambda = 0.16, width_rhs_tau = 0.11, width_rhs_c2 = 0.08,
      width_rhs_tau_c2_block = 0.24,
      rhs_global_block_update = "transformed_tau_c2_block",
      rhs_transformed_block_passes = 4L,
      width_rhs_tau_c2_transformed_z1 = 0.22,
      width_rhs_tau_c2_transformed_z2 = 0.16,
      max_steps_out = 60L, max_shrink = 240L
    )
  } else if (identical(profile_id, "P2_conservative_slice")) {
    cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_burn <- 800L
    cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_mcmc <- 2200L
    cfg$pipeline$inference$mcmc$prior_overrides$ridge$progress_every <- 100L
    cfg$pipeline$inference$mcmc$prior_overrides$ridge$slice <- list(
      width_gamma = 0.45, width_sigma = 0.24, max_steps_out = 70L, max_shrink = 260L
    )
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 1000L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 2600L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 120L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$freeze_tau_burnin_iters <- 60L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt$warmup_iters <- 500L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt$step_size <- 0.012
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice <- list(
      width_gamma = 0.44, width_sigma = 0.24,
      width_rhs_lambda = 0.12, width_rhs_tau = 0.085, width_rhs_c2 = 0.065,
      width_rhs_tau_c2_block = 0.18,
      rhs_global_block_update = "transformed_tau_c2_block",
      rhs_transformed_block_passes = 5L,
      width_rhs_tau_c2_transformed_z1 = 0.17,
      width_rhs_tau_c2_transformed_z2 = 0.13,
      max_steps_out = 80L, max_shrink = 300L
    )
  } else if (identical(profile_id, "P3_blocked_adapt")) {
    cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_burn <- 900L
    cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_mcmc <- 2400L
    cfg$pipeline$inference$mcmc$prior_overrides$ridge$progress_every <- 120L
    cfg$pipeline$inference$mcmc$prior_overrides$ridge$slice <- list(
      width_gamma = 0.40, width_sigma = 0.22, max_steps_out = 80L, max_shrink = 300L
    )
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 1100L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 2800L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 140L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$freeze_tau_burnin_iters <- 70L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$freeze_tau_only_during_burn <- TRUE
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt$enabled <- TRUE
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt$warmup_iters <- 650L
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt$only_during_burn <- TRUE
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt$target_score_low <- -0.8
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt$target_score_high <- 0.8
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt$step_size <- 0.010
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt$width_min <- 0.02
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$rhs$width_adapt$width_max <- 1.50
    cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice <- list(
      width_gamma = 0.40, width_sigma = 0.22,
      width_rhs_lambda = 0.10, width_rhs_tau = 0.070, width_rhs_c2 = 0.055,
      width_rhs_tau_c2_block = 0.16,
      rhs_global_block_update = "transformed_tau_c2_block",
      rhs_transformed_block_passes = 6L,
      width_rhs_tau_c2_transformed_z1 = 0.15,
      width_rhs_tau_c2_transformed_z2 = 0.11,
      max_steps_out = 90L, max_shrink = 320L
    )
  } else {
    stop(sprintf("Unknown profile_id '%s'.", profile_id), call. = FALSE)
  }
  cfg
}

profiles <- c("P1_longer_chain", "P2_conservative_slice", "P3_blocked_adapt")
profile_rows <- list()
if (gateA_pass) {
  for (pid in profiles) {
    cfg <- make_profile_defaults(pid, base_defaults)
    out_path <- file.path(configs_dir, sprintf("defaults_%s.yaml", pid))
    yaml::write_yaml(cfg, out_path)
    profile_rows[[length(profile_rows) + 1L]] <- data.frame(
      profile_id = pid,
      defaults_path = out_path,
      ridge_n_burn = as.integer(cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_burn %||% NA_integer_),
      ridge_n_mcmc = as.integer(cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_mcmc %||% NA_integer_),
      rhsns_n_burn = as.integer(cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn %||% NA_integer_),
      rhsns_n_mcmc = as.integer(cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc %||% NA_integer_),
      rhs_block = as.character((cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice %||% list())$rhs_global_block_update %||% NA_character_),
      rhs_block_passes = as.integer((cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$slice %||% list())$rhs_transformed_block_passes %||% NA_integer_),
      stringsAsFactors = FALSE
    )
  }
}
profiles_tbl <- if (length(profile_rows)) do.call(rbind, profile_rows) else data.frame(stringsAsFactors = FALSE)
utils::write.csv(profiles_tbl, file.path(tables_dir, "phase02_profiles.csv"), row.names = FALSE)

gateA <- list(
  gateA_pass = gateA_pass,
  n_mcmc_fail = nrow(mcmc_fail),
  n_failure_clusters = nrow(cluster_tbl),
  top3_share = as.numeric(gateA_top3_share),
  dominant_clusters = as.list(utils::head(as.character(cluster_tbl$failure_cluster), 3L)),
  recommendation = if (gateA_pass) {
    "Proceed to micro-pilot (Phase 3)."
  } else {
    "STOP: failure patterns diffuse; escalate to kernel redesign path."
  }
)

manifest <- list(
  generated_at = as.character(Sys.time()),
  git_sha = git_sha,
  run_tag = run_tag,
  baseline = list(
    report_root = baseline_report_root,
    results_root = baseline_results_root
  ),
  workspace = list(
    final_report_root = final_report_root,
    final_results_root = final_results_root,
    summary_dir = summary_dir,
    tables_dir = tables_dir,
    configs_dir = configs_dir
  ),
  gateA = gateA,
  files = list(
    preflight_md = file.path(summary_dir, "phase01_preflight.md"),
    preflight_json = file.path(summary_dir, "phase01_preflight_manifest.json"),
    method_all = file.path(tables_dir, "phase01_method_all_fits.csv"),
    method_healthy = file.path(tables_dir, "phase01_method_healthy_only.csv"),
    pair_all = file.path(tables_dir, "phase01_pair_all_fits.csv"),
    pair_healthy = file.path(tables_dir, "phase01_pair_healthy_only.csv"),
    fail_forensics = file.path(tables_dir, "phase01_mcmc_fail_forensics.csv"),
    fail_clusters = file.path(tables_dir, "phase01_mcmc_fail_cluster_rank.csv"),
    micro_roots = file.path(tables_dir, "phase01_micro_pilot_roots_selected.csv"),
    micro_grid = file.path(configs_dir, "micro_pilot_grid.csv"),
    profiles = file.path(tables_dir, "phase02_profiles.csv")
  )
)
jsonlite::write_json(manifest, file.path(summary_dir, "phase01_manifest.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")

summary_lines <- c(
  "# QDESN Finalization Phase 0-2",
  "",
  sprintf("- generated_at: `%s`", manifest$generated_at),
  sprintf("- git_sha: `%s`", git_sha),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- baseline_report_root: `%s`", baseline_report_root),
  sprintf("- baseline_results_root: `%s`", baseline_results_root),
  sprintf("- active_qdesn_processes_n: `%d`", length(active_qdesn_processes)),
  "",
  "## Gate A",
  sprintf("- gateA_pass: `%s`", if (isTRUE(gateA$gateA_pass)) "TRUE" else "FALSE"),
  sprintf("- n_mcmc_fail: `%d`", as.integer(gateA$n_mcmc_fail)),
  sprintf("- n_failure_clusters: `%d`", as.integer(gateA$n_failure_clusters)),
  sprintf("- top3_share: `%.3f`", as.numeric(gateA$top3_share %||% NA_real_)),
  sprintf("- dominant_clusters: `%s`", paste(unlist(gateA$dominant_clusters), collapse = ", ")),
  sprintf("- recommendation: `%s`", gateA$recommendation),
  "",
  "## Method Summary (All Fits)",
  exdqlm:::.qdesn_validation_df_to_markdown(method_all_tbl),
  "",
  "## Method Summary (Healthy Only)",
  exdqlm:::.qdesn_validation_df_to_markdown(method_healthy_tbl),
  "",
  "## Pair Summary (All Fits)",
  exdqlm:::.qdesn_validation_df_to_markdown(pair_all_tbl),
  "",
  "## Pair Summary (Healthy Only)",
  exdqlm:::.qdesn_validation_df_to_markdown(pair_healthy_tbl),
  "",
  "## MCMC FAIL Cluster Ranking",
  exdqlm:::.qdesn_validation_df_to_markdown(cluster_tbl),
  "",
  "## Selected Micro-Pilot Roots",
  exdqlm:::.qdesn_validation_df_to_markdown(micro_roots),
  "",
  "## Designed Profiles",
  exdqlm:::.qdesn_validation_df_to_markdown(profiles_tbl),
  "",
  "## Next Command",
  sprintf(
    "`Rscript scripts/run_qdesn_validation_closeout_phase35.R --phase01-manifest %s --workers 4`",
    file.path(summary_dir, "phase01_manifest.json")
  )
)
writeLines(summary_lines, file.path(summary_dir, "phase01_summary.md"))

cat(sprintf("Phase01 summary: %s\n", file.path(summary_dir, "phase01_summary.md")))
cat(sprintf("Phase01 manifest: %s\n", file.path(summary_dir, "phase01_manifest.json")))
