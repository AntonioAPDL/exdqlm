#!/usr/bin/env Rscript

suppressPackageStartupMessages({ library(jsonlite); library(pkgload) })
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/")
setwd(repo)
source("validation/fitforecast_v2/R/utils.R")
ffv2_source_all("validation/fitforecast_v2")
pkgload::load_all(repo, quiet = TRUE)

state <- normalizePath(get_arg("--state-root", "reports/shared_fitforecast_v2_orchestration/qdesn_trainonly_followup_v1_20260805_205744"), winslash = "/")
closeout <- file.path(state, "closeout")
out <- normalizePath(get_arg("--output-root", file.path(closeout, "transport_audit_v2")), winslash = "/", mustWork = FALSE)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
read_csv <- function(p) utils::read.csv(p, check.names = FALSE, stringsAsFactors = FALSE)
write_csv <- function(x, name) utils::write.csv(x, file.path(out, name), row.names = FALSE, na = "")

metrics <- read_csv(file.path(closeout, "qdesn_metrics.csv"))
al <- metrics[metrics$experiment == "al_confirmation", , drop = FALSE]
required_metric_columns <- c(
  "experiment", "source_scenario", "arm_code", "paired_reservoir_seed",
  "screening_profile_id", "target_tau", "fit_summary_path"
)
missing_metric_columns <- setdiff(required_metric_columns, names(al))
if (length(missing_metric_columns)) {
  stop(sprintf("AL closeout metrics lack required columns: %s",
               paste(missing_metric_columns, collapse = ", ")), call. = FALSE)
}
source_contract <- qdesn_tfv1_source_contract()
al$source_role <- source_contract$source_role[
  match(al$source_scenario, source_contract$scenario_id)
]
if (anyNA(al$source_role)) {
  stop(sprintf("Unregistered AL source scenarios: %s",
               paste(unique(al$source_scenario[is.na(al$source_role)]), collapse = ", ")),
       call. = FALSE)
}
design_rows <- calibration_rows <- list()
for (i in seq_len(nrow(al))) {
  fit_dir <- dirname(al$fit_summary_path[[i]])
  request_path <- file.path(fit_dir, "fit_request.json")
  request <- jsonlite::read_json(request_path, simplifyVector = TRUE)
  cfg <- request$config
  observed <- read_csv(request$observed_path)
  n_train <- as.integer(cfg$split$train_n)
  x_names <- as.character(unlist(cfg$columns$x, use.names = FALSE))
  X <- if (length(x_names)) as.matrix(observed[, x_names, drop = FALSE]) else NULL
  scaled <- qdesn_ttav2_scale_train_only(observed$y, X, n_train)
  d <- cfg$desn; D <- as.integer(d$D)
  d$n <- rep(as.integer(unlist(d$n, use.names = FALSE)), length.out = D)
  d$n_tilde <- if (D > 1L) as.integer(unlist(d$n_tilde, use.names = FALSE)) else integer(0)
  allowed <- c("D", "n", "n_tilde", "m", "alpha", "rho", "act_f", "act_k",
               "pi_w", "pi_in", "washout", "add_bias", "seed")
  desn_args <- d[intersect(names(d), allowed)]
  readout <- ms_build_readout_design_real(
    y_full = scaled$y, X_use = scaled$X, cfg = cfg, desn_args = desn_args,
    readout_include_input = isTRUE(cfg$readout$include_input),
    readout_reservoir_lags = as.integer(cfg$readout$reservoir_lags),
    readout_scale = isTRUE(cfg$inference$readout_scale),
    readout_input_mode = cfg$readout$input_mode,
    readout_decomposition = cfg$decomposition
  )
  raw_start <- as.integer(request$root_spec$raw_start_source_index)
  effective_start <- as.integer(request$root_spec$train_start_source_index) - raw_start + 1L
  effective_end <- as.integer(request$root_spec$train_end_source_index) - raw_start + 1L
  train_idx <- readout$keep_aug_abs >= effective_start & readout$keep_aug_abs <= effective_end
  forecast_idx <- readout$keep_aug_abs > effective_end
  X_train <- readout$X_aug_all[train_idx, , drop = FALSE]
  X_fore <- readout$X_aug_all[forecast_idx, , drop = FALSE]
  X_res_train <- readout$X_res_all[train_idx, , drop = FALSE]
  X_res_fore <- readout$X_res_all[forecast_idx, , drop = FALSE]
  diag <- qdesn_ttav2_matrix_diagnostics(X_train, X_fore, X_res_train, X_res_fore)
  diag$source_role <- al$source_role[[i]]
  diag$source_scenario <- al$source_scenario[[i]]
  diag$arm_code <- al$arm_code[[i]]
  diag$reservoir_seed <- al$paired_reservoir_seed[[i]]
  diag$screening_profile_id <- al$screening_profile_id[[i]]
  diag$request_path <- normalizePath(request_path, winslash = "/")
  diag$request_sha256 <- unname(tools::sha256sum(request_path))
  diag$y_center <- scaled$y_center; diag$y_scale <- scaled$y_scale
  diag$effective_train_start <- effective_start; diag$effective_train_end <- effective_end
  design_rows[[length(design_rows) + 1L]] <- diag

  train_path <- read_csv(file.path(fit_dir, "tables", "fit_quantile_path_train.csv"))
  forecast_path <- read_csv(file.path(fit_dir, "tables", "forecast_rolling_origin_paths.csv"))
  for (window in c(0L, 90L, 180L, 360L, 500L)) {
    shift <- if (window == 0L) 0 else qdesn_ttav2_intercept_shift(train_path, al$target_tau[[i]], window)
    z <- qdesn_ttav2_apply_shift(train_path, forecast_path, al$target_tau[[i]], shift)
    z$source_role <- al$source_role[[i]]; z$source_scenario <- al$source_scenario[[i]]
    z$arm_code <- al$arm_code[[i]]; z$reservoir_seed <- al$paired_reservoir_seed[[i]]
    z$screening_profile_id <- al$screening_profile_id[[i]]; z$calibration_window <- window
    z$train_path_sha256 <- unname(tools::sha256sum(file.path(fit_dir, "tables", "fit_quantile_path_train.csv")))
    z$forecast_path_sha256 <- unname(tools::sha256sum(file.path(fit_dir, "tables", "forecast_rolling_origin_paths.csv")))
    calibration_rows[[length(calibration_rows) + 1L]] <- z
  }
}

design <- do.call(rbind, design_rows)
calibration <- do.call(rbind, calibration_rows)
parents <- calibration[calibration$arm_code == "parent_exact",
  c("source_role", "reservoir_seed", "calibration_window", "fit_rmse", "forecast_mae", "forecast_check"), drop = FALSE]
names(parents)[4:6] <- paste0("parent_", names(parents)[4:6])
paired <- merge(calibration[calibration$arm_code != "parent_exact", ], parents,
                by = c("source_role", "reservoir_seed", "calibration_window"), all.x = TRUE, sort = FALSE)
paired$fit_rmse_ratio <- paired$fit_rmse / paired$parent_fit_rmse
paired$forecast_mae_ratio <- paired$forecast_mae / paired$parent_forecast_mae
paired$forecast_check_ratio <- paired$forecast_check / paired$parent_forecast_check
summary <- do.call(rbind, lapply(split(seq_len(nrow(paired)), interaction(paired$source_role, paired$arm_code, paired$calibration_window, drop = TRUE)), function(idx) {
  z <- paired[idx, , drop = FALSE]
  data.frame(source_role = z$source_role[[1L]], arm_code = z$arm_code[[1L]], calibration_window = z$calibration_window[[1L]],
             complete_seeds = nrow(z), median_shift = median(z$shift),
             median_fit_rmse_ratio = median(z$fit_rmse_ratio), median_forecast_mae_ratio = median(z$forecast_mae_ratio),
             median_forecast_check_ratio = median(z$forecast_check_ratio),
             worst_seed_forecast_mae_ratio = max(z$forecast_mae_ratio), stringsAsFactors = FALSE)
}))
eligible <- qdesn_ttav2_candidate_gate(summary)
capabilities <- qdesn_ttav2_exal_capabilities()

design_summary <- aggregate(cbind(condition_number, max_abs_feature_correlation, standardized_centroid_shift,
                                  standardized_scale_ratio_median, reservoir_saturation_train,
                                  reservoir_saturation_forecast) ~ source_role + arm_code,
                            design, median)
decision <- if (length(eligible)) "PREPARE_LEVEL_CALIBRATION_SMOKE" else "STOP_NO_TRANSFERABLE_MECHANISM"
write_csv(design, "design_transport_diagnostics.csv")
write_csv(design_summary, "design_transport_summary.csv")
write_csv(calibration, "intercept_calibration_metrics.csv")
write_csv(paired, "intercept_calibration_paired.csv")
write_csv(summary, "intercept_calibration_summary.csv")
write_csv(capabilities, "exal_capability_audit.csv")
candidates <- if (length(eligible)) data.frame(candidate_id = eligible, action = "prepare_smoke", stringsAsFactors = FALSE) else
  data.frame(candidate_id = character(), action = character(), stringsAsFactors = FALSE)
write_csv(candidates, "next_candidate_manifest.csv")

gate <- list(
  generated_at = as.character(Sys.time()), decision = decision, complete = TRUE,
  input_followup_gate_sha256 = unname(tools::sha256sum(file.path(closeout, "followup_gate.json"))),
  reconstructed_designs = nrow(design), calibration_evaluations = nrow(calibration),
  transferable_candidates = as.list(eligible), candidate_count = length(eligible),
  compute_launched = FALSE, article_update_allowed = FALSE,
  exal_qdesn_fixed_parameter_supported = FALSE,
  next_gate = if (length(eligible)) "validation_side_smoke_then_symmetric_comparator_review" else "model_api_or_transport_hypothesis_required"
)
jsonlite::write_json(gate, file.path(out, "transport_gate.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")
writeLines(c(
  "# Q-DESN Train-Only Transport Audit v2", "",
  sprintf("- Decision: `%s`", decision), sprintf("- Reconstructed designs: `%d`", nrow(design)),
  sprintf("- Train-only calibration evaluations: `%d`", nrow(calibration)),
  sprintf("- Transferable candidates: `%d`", length(eligible)), "- Compute launched: `FALSE`",
  "- Article update allowed: `FALSE`", "",
  "The audit reconstructs every AL design from its exact request and evaluates train-only",
  "quantile-intercept correction without refitting. No correction is promotable unless the",
  "same arm and window beat the paired parent on both frozen sources.", "",
  "Q-DESN exAL fixed-gamma/fixed-sigma diagnostics are not exposed by the package 1.0.0",
  "readout API. exDQLM supports those controls, but that does not justify claiming an",
  "equivalent Q-DESN exAL experiment."
), file.path(out, "README.md"))
files <- setdiff(list.files(out, full.names = TRUE), file.path(out, "file_manifest.csv"))
manifest <- data.frame(path = normalizePath(files, winslash = "/"), bytes = file.info(files)$size,
                       sha256 = unname(tools::sha256sum(files)), stringsAsFactors = FALSE)
write_csv(manifest, "file_manifest.csv")
cat(sprintf("Decision: %s\nDesigns: %d\nCandidates: %d\nOutput: %s\n", decision, nrow(design), length(eligible), out))
