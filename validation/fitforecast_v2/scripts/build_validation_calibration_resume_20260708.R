#!/usr/bin/env Rscript

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)

timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
git_sha <- trimws(system("git rev-parse HEAD", intern = TRUE))
git_branch <- trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE))

stop_article_path <- function(path) {
  if (grepl("Article-Q-DESN|PriceFM|GloFAS|joint-QVP", path, ignore.case = TRUE)) {
    stop(sprintf("Refusing cross-lane path: %s", path), call. = FALSE)
  }
  invisible(path)
}

read_csv <- function(path) {
  stop_article_path(path)
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

md_table <- function(x, digits = 3) {
  if (!nrow(x)) return("_No rows._")
  y <- x
  for (nm in names(y)) {
    if (is.numeric(y[[nm]])) y[[nm]] <- format(round(y[[nm]], digits), nsmall = 0, trim = TRUE)
    y[[nm]][is.na(y[[nm]])] <- ""
  }
  header <- paste0("| ", paste(names(y), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(y)), collapse = " | "), " |")
  rows <- apply(y, 1L, function(z) paste0("| ", paste(z, collapse = " | "), " |"))
  paste(c(header, sep, rows), collapse = "\n")
}

current_best_path <- "validation/fitforecast_v2/docs/exdqlm_dqlm_qdesn_vb_current_best_comparison_20260703.csv"
tau005_winners_path <- "validation/fitforecast_v2/runs/20260706_exdqlm_dqlm_vb_tau005_refinement__git-0d22ebc/screen_summary/candidate_cell_winners.csv"
qdesn_fitfirst_path <- paste(
  "reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup",
  "qdesn-vb-rhs-fitfirst-followup-full-20260707-190614__git-17cf71b",
  "20260707-190657__git-17cf71b",
  "tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv",
  sep = "/"
)

current_best <- read_csv(current_best_path)
needed <- c(
  "model_variant", "family", "tau", "fit_qtrue_rmse", "fit_check",
  "forecast_qtrue_mae", "forecast_qtrue_rmse", "forecast_check",
  "source_registry_hash_value", "validation_branch", "validation_commit",
  "run_tag", "package_version", "forecast_protocol", "state_update_method",
  "max_lead_configured", "origin_stride"
)
missing <- setdiff(needed, names(current_best))
if (length(missing)) {
  stop(sprintf("Current-best VB comparison is missing: %s", paste(missing, collapse = ", ")), call. = FALSE)
}

baseline <- data.frame(
  model_family = "exdqlm_dqlm",
  model_variant = as.character(current_best$model_variant),
  model_key = paste0(as.character(current_best$model_variant), "_vb_current_best"),
  inference = "vb",
  method = "vb",
  family = as.character(current_best$family),
  tau = as.numeric(current_best$tau),
  fit_size = 500L,
  effective_fit_size = 500L,
  fit_qtrue_rmse = as.numeric(current_best$fit_qtrue_rmse),
  fit_check_loss = as.numeric(current_best$fit_check),
  fit_pinball_mean = as.numeric(current_best$fit_check),
  forecast_qtrue_mae_lead_weighted = as.numeric(current_best$forecast_qtrue_mae),
  forecast_qtrue_rmse_lead_weighted = as.numeric(current_best$forecast_qtrue_rmse),
  forecast_check_loss_lead_weighted = as.numeric(current_best$forecast_check),
  forecast_pinball_mean_lead_weighted = as.numeric(current_best$forecast_check),
  source_registry_hash_name = "sha256",
  source_registry_hash_value = as.character(current_best$source_registry_hash_value),
  validation_branch = as.character(current_best$validation_branch),
  validation_commit = as.character(current_best$validation_commit),
  run_tag = as.character(current_best$run_tag),
  package_version = as.character(current_best$package_version),
  forecast_protocol = as.character(current_best$forecast_protocol),
  state_update_method = as.character(current_best$state_update_method),
  max_lead_configured = as.integer(current_best$max_lead_configured),
  origin_stride = as.integer(current_best$origin_stride),
  baseline_source = current_best_path,
  stringsAsFactors = FALSE
)

baseline_path <- "validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv"
write_csv(baseline, baseline_path)

mk_candidate <- function(id, trend, seasonal, df, dim, notes) {
  data.frame(
    candidate_id = id,
    calibration_id = paste0("resume_", id),
    trend_C0_scale = trend,
    seasonal_C0_scale = seasonal,
    df_value = df,
    dim_df = dim,
    notes = notes,
    stringsAsFactors = FALSE
  )
}

ex_candidates <- do.call(rbind, list(
  mk_candidate("r0801_c13_anchor", 100, 1, "0.995,0.99", "2,4", "Current c13 reference retained as guard."),
  mk_candidate("r0802_lowq_t5_s010_df0985", 5, 0.10, "0.985,0.985", "2,4", "Very tight prior for low-quantile forecast bias."),
  mk_candidate("r0803_lowq_t5_s025_df099", 5, 0.25, "0.99,0.99", "2,4", "Tight low-quantile candidate near tau005 winners."),
  mk_candidate("r0804_lowq_t10_s010_df099", 10, 0.10, "0.99,0.99", "2,4", "Low seasonal variance, moderate level shrinkage."),
  mk_candidate("r0805_lowq_t10_s025_df099", 10, 0.25, "0.99,0.99", "2,4", "Best gausmix tau 0.05 neighborhood."),
  mk_candidate("r0806_lowq_t10_s050_df099", 10, 0.50, "0.99,0.99", "2,4", "Tight trend with moderate seasonal prior."),
  mk_candidate("r0807_lowq_t25_s025_df099", 25, 0.25, "0.99,0.99", "2,4", "Broader trend with tight season."),
  mk_candidate("r0808_lowq_t25_s050_df099", 25, 0.50, "0.99,0.99", "2,4", "Tau005 normal/laplace neighborhood."),
  mk_candidate("r0809_lowq_t25_s100_df099", 25, 1.00, "0.99,0.99", "2,4", "Flexible seasonal variant for low tau."),
  mk_candidate("r0810_lowq_t50_s025_df099", 50, 0.25, "0.99,0.99", "2,4", "Higher trend variance, tight season."),
  mk_candidate("r0811_lowq_t50_s050_df099", 50, 0.50, "0.99,0.99", "2,4", "Moderate trend and seasonal prior."),
  mk_candidate("r0812_lowq_t100_s025_df099", 100, 0.25, "0.99,0.99", "2,4", "Current c13 trend with tighter season."),
  mk_candidate("r0813_lowq_t100_s050_df099", 100, 0.50, "0.99,0.99", "2,4", "Current c13 trend with moderate season."),
  mk_candidate("r0814_bal_t25_s050_df0995", 25, 0.50, "0.995,0.995", "2,4", "Balanced smoother alternative."),
  mk_candidate("r0815_bal_t25_s100_df0995", 25, 1.00, "0.995,0.995", "2,4", "Smoother low-trend candidate."),
  mk_candidate("r0816_bal_t50_s050_df0995", 50, 0.50, "0.995,0.995", "2,4", "C13-shrunk smoother candidate."),
  mk_candidate("r0817_bal_t50_s100_df0995", 50, 1.00, "0.995,0.995", "2,4", "Moderate c13 neighborhood."),
  mk_candidate("r0818_bal_t100_s050_df0995", 100, 0.50, "0.995,0.995", "2,4", "C13 trend with tighter season and smoother discount."),
  mk_candidate("r0819_bal_t100_s100_df0995", 100, 1.00, "0.995,0.995", "2,4", "Symmetric smoother c13 variant."),
  mk_candidate("r0820_bal_t200_s100_df0995", 200, 1.00, "0.995,0.995", "2,4", "Larger level variance, smooth evolution."),
  mk_candidate("r0821_bal_t200_s200_df0995", 200, 2.00, "0.995,0.995", "2,4", "Broader seasonal variance for high tau."),
  mk_candidate("r0822_flex_t50_s100_df09975", 50, 1.00, "0.9975,0.995", "2,4", "Smoother trend, c13-like season."),
  mk_candidate("r0823_flex_t100_s100_df09975", 100, 1.00, "0.9975,0.995", "2,4", "Smooth trend c13 extension."),
  mk_candidate("r0824_flex_t200_s100_df09975", 200, 1.00, "0.9975,0.995", "2,4", "High level variance smooth trend."),
  mk_candidate("r0825_flex_t400_s100_df09975", 400, 1.00, "0.9975,0.995", "2,4", "Large trend variance sentinel."),
  mk_candidate("r0826_flex_t100_s200_df09975", 100, 2.00, "0.9975,0.995", "2,4", "Broader seasonal prior, smooth trend."),
  mk_candidate("r0827_flex_t200_s200_df09975", 200, 2.00, "0.9975,0.995", "2,4", "Flexible median/high-tau candidate."),
  mk_candidate("r0828_fast_t25_s050_df0985s099", 25, 0.50, "0.985,0.99", "2,4", "Fast trend, standard season for bias diagnostics."),
  mk_candidate("r0829_fast_t50_s050_df0985s099", 50, 0.50, "0.985,0.99", "2,4", "Fast trend with moderate prior."),
  mk_candidate("r0830_fast_t100_s050_df0985s099", 100, 0.50, "0.985,0.99", "2,4", "Fast trend c13 seasonal shrink."),
  mk_candidate("r0831_seasonfast_t50_s050_df099s0985", 50, 0.50, "0.99,0.985", "2,4", "Seasonal fast-evolution diagnostic."),
  mk_candidate("r0832_seasonfast_t100_s100_df099s0985", 100, 1.00, "0.99,0.985", "2,4", "C13 trend with fast season."),
  mk_candidate("r0833_broad_t400_s200_df0995", 400, 2.00, "0.995,0.995", "2,4", "Broad variance sentinel."),
  mk_candidate("r0834_broad_t400_s500_df0995", 400, 5.00, "0.995,0.995", "2,4", "Large seasonal variance sentinel."),
  mk_candidate("r0835_ultrasmooth_t100_s100_df0999", 100, 1.00, "0.999,0.9975", "2,4", "Ultra-smooth drift sentinel."),
  mk_candidate("r0836_ultrasmooth_t200_s200_df0999", 200, 2.00, "0.999,0.9975", "2,4", "Ultra-smooth flexible sentinel.")
))
candidate_path <- "validation/fitforecast_v2/config/exdqlm_dqlm_vb_calibration_resume_candidates_20260708.csv"
write_csv(ex_candidates, candidate_path)

qdesn <- read_csv(qdesn_fitfirst_path)
baseline_keys <- baseline[, c("family", "tau", "model_variant", "fit_qtrue_rmse", "fit_check_loss", "forecast_qtrue_mae_lead_weighted", "forecast_check_loss_lead_weighted"), drop = FALSE]
best_by_cell <- do.call(rbind, lapply(split(baseline_keys, paste(baseline_keys$family, baseline_keys$tau, sep = "::")), function(z) {
  data.frame(
    family = z$family[[1L]],
    tau = as.numeric(z$tau[[1L]]),
    best_vb_fit_rmse = min(as.numeric(z$fit_qtrue_rmse), na.rm = TRUE),
    best_vb_fit_check = min(as.numeric(z$fit_check_loss), na.rm = TRUE),
    best_vb_forecast_mae = min(as.numeric(z$forecast_qtrue_mae_lead_weighted), na.rm = TRUE),
    best_vb_forecast_check = min(as.numeric(z$forecast_check_loss_lead_weighted), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
rownames(best_by_cell) <- NULL

qdesn$status <- toupper(as.character(qdesn$status))
qdesn$comparison_eligible <- as.logical(qdesn$comparison_eligible)
qkeep <- qdesn$status == "SUCCESS" & qdesn$comparison_eligible & as.integer(qdesn$fit_size) == 500L
qdesn <- qdesn[qkeep, , drop = FALSE]
qdesn$family <- as.character(qdesn$family)
qdesn$tau <- as.numeric(qdesn$tau)
qdesn$likelihood_family <- as.character(qdesn$likelihood_family)
qdesn$key <- paste(qdesn$family, qdesn$tau, qdesn$likelihood_family, sep = "::")

qdesn_gap <- do.call(rbind, lapply(split(qdesn, qdesn$key), function(z) {
  base <- best_by_cell[best_by_cell$family == z$family[[1L]] & abs(best_by_cell$tau - z$tau[[1L]]) < 1e-8, , drop = FALSE]
  if (!nrow(base)) return(NULL)
  data.frame(
    track = "qdesn_rhs_vb",
    model_variant = paste0("qdesn_", z$likelihood_family[[1L]], "_rhs"),
    family = z$family[[1L]],
    tau = z$tau[[1L]],
    n_candidates = length(unique(z$screening_profile_id)),
    best_fit_rmse = min(as.numeric(z$train_qtrue_rmse), na.rm = TRUE),
    best_fit_rmse_ratio = min(as.numeric(z$train_qtrue_rmse), na.rm = TRUE) / base$best_vb_fit_rmse[[1L]],
    best_fit_check = min(as.numeric(z$train_pinball_tau), na.rm = TRUE),
    best_fit_check_ratio = min(as.numeric(z$train_pinball_tau), na.rm = TRUE) / base$best_vb_fit_check[[1L]],
    best_forecast_mae = min(as.numeric(z$forecast_all_qtrue_mae), na.rm = TRUE),
    best_forecast_mae_ratio = min(as.numeric(z$forecast_all_qtrue_mae), na.rm = TRUE) / base$best_vb_forecast_mae[[1L]],
    best_forecast_check = min(as.numeric(z$forecast_all_pinball_mean), na.rm = TRUE),
    best_forecast_check_ratio = min(as.numeric(z$forecast_all_pinball_mean), na.rm = TRUE) / base$best_vb_forecast_check[[1L]],
    recommendation = if (min(as.numeric(z$train_qtrue_rmse), na.rm = TRUE) <= base$best_vb_fit_rmse[[1L]]) "mcmc_candidate_after_recheck" else "needs_more_vb_fit_calibration",
    stringsAsFactors = FALSE
  )
}))

tau005 <- read_csv(tau005_winners_path)
tau005_gap <- do.call(rbind, lapply(split(tau005, paste(tau005$family, tau005$tau, sep = "::")), function(z) {
  dqlm <- z[tolower(z$model_variant) == "dqlm", , drop = FALSE]
  exdqlm <- z[tolower(z$model_variant) == "exdqlm", , drop = FALSE]
  if (!nrow(dqlm) || !nrow(exdqlm)) return(NULL)
  data.frame(
    track = "exdqlm_dqlm_vb_tau005_refinement",
    model_variant = "exdqlm_vs_dqlm",
    family = z$family[[1L]],
    tau = as.numeric(z$tau[[1L]]),
    n_candidates = length(strsplit(as.character(z$available_candidate_ids[[1L]]), ";", fixed = TRUE)[[1L]]),
    best_fit_rmse = as.numeric(exdqlm$fit_qtrue_rmse[[1L]]),
    best_fit_rmse_ratio = as.numeric(exdqlm$fit_qtrue_rmse[[1L]]) / as.numeric(dqlm$fit_qtrue_rmse[[1L]]),
    best_fit_check = as.numeric(exdqlm$fit_check_loss[[1L]]),
    best_fit_check_ratio = as.numeric(exdqlm$fit_check_loss[[1L]]) / as.numeric(dqlm$fit_check_loss[[1L]]),
    best_forecast_mae = as.numeric(exdqlm$forecast_qtrue_mae[[1L]]),
    best_forecast_mae_ratio = as.numeric(exdqlm$forecast_qtrue_mae[[1L]]) / as.numeric(dqlm$forecast_qtrue_mae[[1L]]),
    best_forecast_check = as.numeric(exdqlm$forecast_check_loss[[1L]]),
    best_forecast_check_ratio = as.numeric(exdqlm$forecast_check_loss[[1L]]) / as.numeric(dqlm$forecast_check_loss[[1L]]),
    recommendation = if (as.numeric(exdqlm$forecast_check_loss[[1L]]) <= 1.05 * as.numeric(dqlm$forecast_check_loss[[1L]])) "near_or_noninferior" else "needs_more_vb_calibration",
    stringsAsFactors = FALSE
  )
}))

gap <- rbind(qdesn_gap, tau005_gap)
gap <- gap[order(gap$track, gap$family, gap$tau, gap$model_variant), , drop = FALSE]
gap_path <- "validation/fitforecast_v2/docs/validation_calibration_resume_gap_audit_20260708.csv"
write_csv(gap, gap_path)

ex_summary <- tau005_gap[, c("family", "tau", "best_fit_rmse_ratio", "best_forecast_mae_ratio", "best_forecast_check_ratio", "recommendation"), drop = FALSE]
q_summary <- qdesn_gap[, c("model_variant", "family", "tau", "best_fit_rmse_ratio", "best_forecast_mae_ratio", "best_forecast_check_ratio", "recommendation"), drop = FALSE]
q_summary <- q_summary[order(-q_summary$best_fit_rmse_ratio, q_summary$family, q_summary$tau), , drop = FALSE]
q_summary <- head(q_summary, 18L)

doc_path <- "validation/fitforecast_v2/docs/VALIDATION_CALIBRATION_RESUME_2026-07-08.md"
doc <- c(
  "# Q-DESN + exDQLM/DQLM Calibration Resume Plan",
  "",
  sprintf("Generated: `%s`", timestamp),
  "",
  "## Lane Lock",
  "",
  "This document belongs only to the shared Q-DESN + exDQLM/DQLM fit+forecast validation worktree. It does not authorize Article-Q-DESN, PriceFM, GloFAS, or joint-QVP work.",
  "",
  "## Current Validation Baseline",
  "",
  sprintf("- branch: `%s`", git_branch),
  sprintf("- commit: `%s`", git_sha),
  "- package baseline: `exdqlm` 1.0.0",
  "- source registry hash: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`",
  "- fit window: source indices `8501:9000`",
  "- forecast block: source indices `9001:10000`",
  "- rolling protocol: no refit, state update over observed lags",
  "- maximum lead: `30`; origin stride: `30`",
  "",
  "## Validation-Local Baseline",
  "",
  sprintf("Baseline CSV: `%s`", baseline_path),
  "",
  "The baseline is normalized from validation-side evidence only. No Article-Q-DESN table is used as the source of truth for this calibration lane.",
  "",
  "## exDQLM/DQLM Gap Summary",
  "",
  md_table(ex_summary),
  "",
  "The low-quantile exDQLM rows remain the main exDQLM/DQLM calibration target. The next pass expands the dynamic prior/discount grid around the tau=0.05 winners and c13 reference, then ranks candidates before any MCMC is considered.",
  "",
  "## Q-DESN RHS Gap Summary",
  "",
  md_table(q_summary),
  "",
  "The newest Q-DESN RHS fit-first screen remains diagnostic because the fit-RMSE ratios stay above the best validation-local DQLM/exDQLM VB baseline. The next pass therefore regenerates the fit-first grid against the validation-local baseline with a wider but still bounded profile budget.",
  "",
  "## New Candidate Registry",
  "",
  sprintf("exDQLM/DQLM candidate CSV: `%s`", candidate_path),
  "",
  "## Launch Policy",
  "",
  "- Run VB calibration first for both tracks.",
  "- Do not launch MCMC from this pass unless VB produces cell-specific candidates that are best or near-best on both fit and rolling forecast metrics.",
  "- Keep all outputs storage-light and diagnostic until a separate strict promotion audit.",
  "- Keep this chat and this worktree in the validation lane only."
)
writeLines(doc, doc_path)

cat(sprintf("baseline_path: %s\n", normalizePath(baseline_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("candidate_path: %s\n", normalizePath(candidate_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("gap_path: %s\n", normalizePath(gap_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("doc_path: %s\n", normalizePath(doc_path, winslash = "/", mustWork = TRUE)))
