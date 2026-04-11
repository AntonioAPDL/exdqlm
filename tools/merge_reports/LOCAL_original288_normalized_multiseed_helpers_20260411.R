source("tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_helpers_20260410.R")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

ensure_dir_original288_normalized_multiseed <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}

safe_chr_original288_normalized_multiseed <- function(x, default = NA_character_) {
  if (is.null(x) || !length(x)) return(default)
  y <- as.character(x)[1]
  if (is.na(y) || !nzchar(trimws(y)) || identical(toupper(trimws(y)), "NA")) default else y
}

safe_num_original288_normalized_multiseed <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (is.finite(v)) v else default
}

safe_int_original288_normalized_multiseed <- function(x, default = NA_integer_) {
  v <- suppressWarnings(as.integer(x)[1])
  if (is.finite(v)) v else default
}

as_flag_original288_normalized_multiseed <- function(x, default = FALSE) {
  if (is.null(x) || !length(x)) return(default)
  if (is.logical(x)) return(isTRUE(x[1]))
  tolower(as.character(x)[1]) %in% c("1", "true", "yes", "y", "t")
}

resolve_existing_path_original288_normalized_multiseed <- function(path) {
  if (is.na(path) || !nzchar(path)) return(NA_character_)
  roots <- c(
    "/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration",
    "/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
  )
  if (file.exists(path)) return(normalizePath(path, winslash = "/", mustWork = TRUE))
  norm_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  for (root in roots) {
    if (!startsWith(norm_path, root)) next
    rel <- sub(paste0("^", root), "", norm_path)
    for (alt_root in roots) {
      cand <- paste0(alt_root, rel)
      if (file.exists(cand)) return(normalizePath(cand, winslash = "/", mustWork = TRUE))
    }
  }
  NA_character_
}

current_repo_root_original288_normalized_multiseed <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration"
}

predecessor_repo_root_original288_normalized_multiseed <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
}

map_to_current_repo_root_original288_normalized_multiseed <- function(path) {
  path <- safe_chr_original288_normalized_multiseed(path, NA_character_)
  if (is.na(path)) return(NA_character_)
  sub(
    paste0("^", predecessor_repo_root_original288_normalized_multiseed()),
    current_repo_root_original288_normalized_multiseed(),
    path
  )
}

read_csv_safe_original288_normalized_multiseed <- function(path) {
  path <- resolve_existing_path_original288_normalized_multiseed(path)
  if (is.na(path) || !file.exists(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

run_tag_original288_normalized_multiseed <- function() {
  "original288_normalized_multiseed_relaunch_20260411"
}

variant_tag_original288_normalized_multiseed <- function() {
  "orig288_normalized_multiseed_20260411"
}

phase_order_original288_normalized_multiseed <- c(
  pilot_static_mcmc = 1L,
  pilot_static_vb = 2L,
  pilot_dynamic_vb = 3L,
  pilot_dynamic_mcmc = 4L,
  full_static_mcmc = 5L,
  full_static_vb = 6L,
  full_dynamic_vb = 7L,
  full_dynamic_mcmc = 8L
)

paths_original288_normalized_multiseed <- function() {
  tag <- run_tag_original288_normalized_multiseed()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    selection = "tools/merge_reports/LOCAL_original288_comparison_selection_rhsns_v1_20260411.csv",
    universe = "tools/merge_reports/LOCAL_original288_normalized_multiseed_universe_20260411.csv",
    control_audit = "tools/merge_reports/LOCAL_original288_normalized_multiseed_control_audit_20260411.csv",
    seedbank = "tools/merge_reports/LOCAL_original288_normalized_multiseed_seedbank_20260411.csv",
    pilot_manifest = "tools/merge_reports/LOCAL_original288_normalized_multiseed_pilot_manifest_20260411.csv",
    full_manifest = "tools/merge_reports/LOCAL_original288_normalized_multiseed_full_manifest_20260411.csv",
    pilot_stage_counts = "tools/merge_reports/LOCAL_original288_normalized_multiseed_pilot_stage_counts_20260411.csv",
    full_stage_counts = "tools/merge_reports/LOCAL_original288_normalized_multiseed_full_stage_counts_20260411.csv",
    pilot_manifest_status = "tools/merge_reports/LOCAL_original288_normalized_multiseed_pilot_manifest_status_20260411.csv",
    full_manifest_status = "tools/merge_reports/LOCAL_original288_normalized_multiseed_full_manifest_status_20260411.csv",
    pilot_phase_summary = "tools/merge_reports/LOCAL_original288_normalized_multiseed_pilot_phase_summary_20260411.csv",
    full_phase_summary = "tools/merge_reports/LOCAL_original288_normalized_multiseed_full_phase_summary_20260411.csv",
    pilot_seed_ranking = "tools/merge_reports/LOCAL_original288_normalized_multiseed_pilot_seed_ranking_20260411.csv",
    full_seed_ranking = "tools/merge_reports/LOCAL_original288_normalized_multiseed_full_seed_ranking_20260411.csv",
    pilot_selected = "tools/merge_reports/LOCAL_original288_normalized_multiseed_pilot_selected_20260411.csv",
    full_selected = "tools/merge_reports/LOCAL_original288_normalized_multiseed_full_selected_20260411.csv",
    normalized_selection = "tools/merge_reports/LOCAL_original288_comparison_selection_normalized_multiseed_v1_20260411.csv",
    normalized_selection_summary = "tools/merge_reports/LOCAL_original288_comparison_selection_normalized_multiseed_summary_v1_20260411.csv",
    comparison_output_dir = "tools/merge_reports/original288_tablebacked_comparison_normalized_multiseed_20260411",
    comparison_report = "reports/static_exal_tuning_20260411/original288_tablebacked_cluster_comparison_normalized_multiseed_20260411.md",
    program_doc = "reports/static_exal_tuning_20260411/original288_normalized_multiseed_relaunch_program_20260411.md",
    execution_doc = "reports/static_exal_tuning_20260411/original288_normalized_multiseed_relaunch_execution_20260411.md",
    run_root = run_dir,
    config_dir = file.path(run_dir, "configs"),
    rows_dir = file.path(run_dir, "rows"),
    health_dir = file.path(run_dir, "health"),
    metrics_dir = file.path(run_dir, "metrics"),
    draws_dir = file.path(run_dir, "draws"),
    logs_dir = file.path(run_dir, "logs"),
    dynamic_restored_dir = file.path(run_dir, "restored_dynamic_sources"),
    dynamic_baseline_dir = file.path(run_dir, "dynamic_synthetic_baselines")
  )
}

hash_seed_original288_normalized_multiseed <- function(key) {
  ints <- utf8ToInt(as.character(key)[1])
  if (!length(ints)) return(2026041101L)
  acc <- 0
  for (i in seq_along(ints)) {
    acc <- (acc + i * ints[i]) %% 2000000000L
  }
  as.integer(100000L + acc)
}

extract_seed_from_fit_original288_normalized_multiseed <- function(path) {
  path <- resolve_existing_path_original288_normalized_multiseed(path)
  if (is.na(path)) return(NA_integer_)
  obj <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(obj)) return(NA_integer_)
  fit <- obj$fit %||% obj
  seed <- safe_int_original288_normalized_multiseed(obj$meta$seed %||% obj$seed %||% fit$seed, NA_integer_)
  seed
}

seed_offsets_original288_normalized_multiseed <- c(0L, 101L, 1009L, 10007L)

seed_vector_original288_normalized_multiseed <- function(base_seed) {
  base_seed <- safe_int_original288_normalized_multiseed(base_seed, 2026041101L)
  v <- base_seed + seed_offsets_original288_normalized_multiseed
  v[v > 2147483000L] <- v[v > 2147483000L] - 1000000000L
  as.integer(v)
}

dynamic_materialized_source_dir_original288_normalized_multiseed <- function(family, tau_label, fit_size) {
  materialized_source_dir_original288_syncedbase_dynamic_restored_closure(family, tau_label, fit_size)
}

dynamic_source_context_original288_normalized_multiseed <- function(sel_row) {
  fit_path_raw <- safe_chr_original288_normalized_multiseed(sel_row$selected_fit_path, NA_character_)
  source_run_root_raw <- sub("/fits/.*$", "", fit_path_raw)
  source_run_root <- resolve_existing_path_original288_normalized_multiseed(source_run_root_raw)
  if (is.na(source_run_root)) source_run_root <- source_run_root_raw
  source_fit_input_dir_raw <- dirname(source_run_root)
  source_fit_input_dir <- resolve_existing_path_original288_normalized_multiseed(source_fit_input_dir_raw)
  if (is.na(source_fit_input_dir)) source_fit_input_dir <- source_fit_input_dir_raw
  tau_label <- safe_chr_original288_normalized_multiseed(sel_row$tau, NA_character_)
  if (is.na(tau_label)) tau_label <- safe_chr_original288_normalized_multiseed(sel_row$tau_label, NA_character_)
  list(
    source_run_root = source_run_root,
    source_fit_input_dir = source_fit_input_dir,
    source_series_wide_path = resolve_existing_path_original288_normalized_multiseed(file.path(source_fit_input_dir, "series_wide.csv")),
    source_selection_indices_path = resolve_existing_path_original288_normalized_multiseed(file.path(source_fit_input_dir, "selection_indices.csv")),
    source_true_quantile_grid_path = resolve_existing_path_original288_normalized_multiseed(file.path(source_fit_input_dir, "true_quantile_grid.csv")),
    materialized_source_dir = dynamic_materialized_source_dir_original288_normalized_multiseed(sel_row$family, tau_label, as.integer(sel_row$fit_size)),
    materialized_sim_output_path = file.path(dynamic_materialized_source_dir_original288_normalized_multiseed(sel_row$family, tau_label, as.integer(sel_row$fit_size)), "sim_output.rds")
  )
}

dynamic_status_path_original288_normalized_multiseed <- function(source_run_root, model, tau_label) {
  file.path(source_run_root, "logs", sprintf("%s_tau_%s.status.tsv", model, tau_label))
}

extract_dynamic_df_original288_normalized_multiseed <- function(status_path, default = 0.98) {
  if (!file.exists(status_path)) return(as.numeric(default))
  lines <- readLines(status_path, warn = FALSE)
  hit <- grep("df=", lines, value = TRUE)
  if (!length(hit)) return(as.numeric(default))
  df <- suppressWarnings(as.numeric(sub(".*df=([0-9.]+).*", "\\1", hit[1])))
  if (is.finite(df)) df else as.numeric(default)
}

dynamic_period_original288_normalized_multiseed <- function(materialized_sim_output_path) {
  x <- readRDS(materialized_sim_output_path)
  as.integer(x$info$params$period %||% 50L)[1]
}

build_dynamic_synthetic_baseline_original288_normalized_multiseed <- function(row, out_path) {
  dctx <- dynamic_source_context_original288_normalized_multiseed(row)
  tau_label <- safe_chr_original288_normalized_multiseed(row$tau, safe_chr_original288_normalized_multiseed(row$tau_label, "0p50"))
  tau_num <- suppressWarnings(as.numeric(gsub("p", ".", tau_label, fixed = TRUE)))
  seed <- extract_seed_from_fit_original288_normalized_multiseed(row$selected_fit_path)
  if (!is.finite(seed)) seed <- hash_seed_original288_normalized_multiseed(row$original_case_key)
  status_path <- dynamic_status_path_original288_normalized_multiseed(dctx$source_run_root, row$model, tau_label)
  diag_path <- file.path(dctx$source_run_root, "tables", "mcmc_diagnostics_summary.csv")
  mh_proposal <- "laplace_rw"
  mh_joint <- FALSE
  mh_adapt <- TRUE
  mh_scale_final <- NA_real_
  accept_rate_keep <- NA_real_
  if (file.exists(diag_path)) {
    diag_df <- read.csv(diag_path, stringsAsFactors = FALSE, check.names = FALSE)
    tau_num_cmp <- suppressWarnings(as.numeric(gsub("p", ".", tau_label, fixed = TRUE)))
    hit <- diag_df[diag_df$model == row$model & abs(as.numeric(diag_df$tau) - tau_num_cmp) < 1e-12, , drop = FALSE]
    if (nrow(hit) >= 1L) {
      hit <- hit[1, , drop = FALSE]
      mh_proposal <- safe_chr_original288_normalized_multiseed(hit$mh_proposal, mh_proposal)
      mh_joint <- as_flag_original288_normalized_multiseed(hit$mh_joint_sample, mh_joint)
      mh_adapt <- as_flag_original288_normalized_multiseed(hit$mh_adapt, mh_adapt)
      mh_scale_final <- safe_num_original288_normalized_multiseed(hit$mh_scale_final, NA_real_)
      accept_rate_keep <- safe_num_original288_normalized_multiseed(hit$accept_rate_keep, NA_real_)
    }
  }
  baseline <- list(
    seed = as.integer(seed),
    p0 = tau_num,
    model = build_dlm_constV_smallW_model_original288_syncedbase_dynamic_restored_closure(
      period = dynamic_period_original288_normalized_multiseed(dctx$materialized_sim_output_path),
      no_trend = TRUE
    ),
    df = rep(extract_dynamic_df_original288_normalized_multiseed(status_path, default = 0.98), 2L),
    dim.df = c(2L, 4L),
    n.burn = 5000L,
    n.mcmc = 20000L,
    init.from.vb = TRUE,
    vb.init.method = "ldvb",
    mh.diagnostics = list(
      proposal = mh_proposal,
      joint_sample = mh_joint,
      adapt = mh_adapt,
      trace_every = 50L,
      scale_final = mh_scale_final,
      accept = list(keep = accept_rate_keep)
    )
  )
  ensure_dir_original288_normalized_multiseed(dirname(out_path))
  saveRDS(baseline, out_path)
  out_path
}

restore_dynamic_sim_output_original288_normalized_multiseed <- function(row, out_path) {
  dctx <- dynamic_source_context_original288_normalized_multiseed(row)
  target_row <- data.frame(
    row_id = row$base_row_id,
    original_case_key = row$original_case_key,
    family = row$family,
    tau = row$tau,
    tau_label = row$tau_label,
    fit_size = row$fit_size,
    source_run_root = dctx$source_run_root,
    source_fit_input_dir = dctx$source_fit_input_dir,
    source_series_wide_path = dctx$source_series_wide_path,
    source_selection_indices_path = dctx$source_selection_indices_path,
    source_true_quantile_grid_path = dctx$source_true_quantile_grid_path,
    materialized_source_dir = dctx$materialized_source_dir,
    materialized_sim_output_path = dctx$materialized_sim_output_path,
    stringsAsFactors = FALSE
  )
  restore_dynamic_sim_output_original288_syncedbase_dynamic_restored_closure(target_row, out_path)
}

select_draw_indices_original288_normalized_multiseed <- function(n_available, n_target, seed) {
  n_available <- as.integer(n_available)[1]
  n_target <- as.integer(n_target)[1]
  if (!is.finite(n_available) || n_available < 1L) stop("n_available must be >= 1")
  if (!is.finite(n_target) || n_target < 1L) stop("n_target must be >= 1")
  if (n_available == n_target) return(seq_len(n_available))
  set.seed(as.integer(seed)[1])
  if (n_available > n_target) {
    sort(sample.int(n_available, n_target, replace = FALSE))
  } else {
    sample.int(n_available, n_target, replace = TRUE)
  }
}

safe_rmvnorm_original288_normalized_multiseed <- function(n, mean, sigma) {
  mean <- as.numeric(mean)
  sigma <- as.matrix(sigma)
  if (!nrow(sigma)) return(matrix(mean, nrow = n, byrow = TRUE))
  if (any(!is.finite(sigma))) sigma[!is.finite(sigma)] <- 0
  if (!all(is.finite(mean))) mean[!is.finite(mean)] <- 0
  if (nrow(sigma) != ncol(sigma) || nrow(sigma) != length(mean)) {
    return(matrix(mean, nrow = n, byrow = TRUE))
  }
  out <- tryCatch(
    mvtnorm::rmvnorm(n, mean = mean, sigma = sigma, method = "svd"),
    error = function(e) NULL
  )
  if (!is.null(out)) return(out)
  sigma <- sigma + diag(1e-8, nrow(sigma))
  mvtnorm::rmvnorm(n, mean = mean, sigma = sigma, method = "svd")
}

static_build_design_original288_normalized_multiseed <- function(series_wide) {
  X_slopes <- as.matrix(series_wide[, grepl("^x[0-9]+$", names(series_wide)), drop = FALSE])
  X <- cbind(`(Intercept)` = 1, X_slopes)
  storage.mode(X) <- "double"
  list(
    X = X,
    X_slopes = X_slopes,
    y = as.numeric(series_wide$y),
    q_truth = if ("q_target" %in% names(series_wide)) as.numeric(series_wide$q_target) else rep(NA_real_, nrow(X))
  )
}

static_validation_dir_original288_normalized_multiseed <- function(sel_row) {
  fit_path_raw <- safe_chr_original288_normalized_multiseed(sel_row$selected_fit_path, NA_character_)
  if (is.na(fit_path_raw)) return(NA_character_)
  validation_dir <- sub("/fits/.*$", "", fit_path_raw)
  resolved <- resolve_existing_path_original288_normalized_multiseed(validation_dir)
  if (is.na(resolved)) validation_dir else resolved
}

static_fit_summary_row_original288_normalized_multiseed <- function(sel_row) {
  validation_dir <- static_validation_dir_original288_normalized_multiseed(sel_row)
  fit_summary <- read_csv_safe_original288_normalized_multiseed(file.path(validation_dir, "tables", "fit_summary.csv"))
  if (is.null(fit_summary)) return(NULL)
  inf_col <- if ("inference" %in% names(fit_summary)) "inference" else "method"
  hit <- fit_summary[
    fit_summary[[inf_col]] == sel_row$inference[[1]] &
      fit_summary$model == sel_row$model[[1]],
    ,
    drop = FALSE
  ]
  if (!nrow(hit)) return(NULL)
  hit[1, , drop = FALSE]
}

static_mcmc_diag_row_original288_normalized_multiseed <- function(sel_row) {
  validation_dir <- static_validation_dir_original288_normalized_multiseed(sel_row)
  diag_df <- read_csv_safe_original288_normalized_multiseed(file.path(validation_dir, "tables", "mcmc_diagnostics_summary.csv"))
  if (is.null(diag_df)) return(NULL)
  tau_num <- safe_num_original288_normalized_multiseed(sel_row$tau_num %||% sel_row$tau, NA_real_)
  hit <- diag_df[
    diag_df$model == sel_row$model[[1]] &
      abs(suppressWarnings(as.numeric(diag_df$tau)) - tau_num) < 1e-12,
    ,
    drop = FALSE
  ]
  if (!nrow(hit)) return(NULL)
  hit[1, , drop = FALSE]
}

static_predictive_draws_original288_normalized_multiseed <- function(fit_obj, row, series_wide, n_draws = 20000L, seed = 1L) {
  des <- static_build_design_original288_normalized_multiseed(series_wide)
  X <- des$X
  target <- as.integer(n_draws)[1]

  if (identical(row$inference, "mcmc")) {
    beta_draws <- as.matrix(fit_obj$samp.beta)
    idx <- select_draw_indices_original288_normalized_multiseed(nrow(beta_draws), target, seed)
    beta_sel <- beta_draws[idx, , drop = FALSE]
    sigma_sel <- as.numeric(fit_obj$samp.sigma)[idx]
    if (identical(row$model, "al") || isTRUE(fit_obj$dqlm.ind)) {
      gamma_sel <- rep(0, target)
    } else {
      gamma_sel <- as.numeric(fit_obj$samp.gamma)[idx]
    }
  } else {
    beta_mean <- as.numeric(fit_obj$qbeta$m)
    beta_sel <- safe_rmvnorm_original288_normalized_multiseed(target, beta_mean, as.matrix(fit_obj$qbeta$V))
    if (identical(row$model, "al") || isTRUE(fit_obj$dqlm.ind)) {
      shape <- safe_num_original288_normalized_multiseed(fit_obj$qsig$a, NA_real_)
      rate <- safe_num_original288_normalized_multiseed(fit_obj$qsig$b, NA_real_)
      if (!is.finite(shape) || !is.finite(rate) || shape <= 0 || rate <= 0) {
        sigma_sel <- rep(safe_num_original288_normalized_multiseed(fit_obj$qsig$E_sigma, 1), target)
      } else {
        set.seed(as.integer(seed) + 17L)
        sigma_sel <- 1 / stats::rgamma(target, shape = shape, rate = rate)
      }
      gamma_sel <- rep(0, target)
    } else {
      qsg <- fit_obj$qsiggam
      sg_draws <- safe_rmvnorm_original288_normalized_multiseed(
        target,
        c(qsg$eta_hat, qsg$ell_hat),
        as.matrix(qsg$Sigma)
      )
      eta_draw <- sg_draws[, 1]
      ell_draw <- sg_draws[, 2]
      bounds <- fit_obj$misc$bounds %||% c(L = -4, U = 4)
      L <- as.numeric(bounds[1])
      U <- as.numeric(bounds[2])
      s <- stats::plogis(eta_draw)
      s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
      gamma_sel <- L + (U - L) * s
      sigma_sel <- exp(ell_draw)
    }
  }

  xb <- des$X %*% t(beta_sel)
  draws <- matrix(NA_real_, nrow = nrow(des$X), ncol = target)
  p0 <- safe_num_original288_normalized_multiseed(row$tau_num %||% row$tau, 0.5)
  for (j in seq_len(target)) {
    draws[, j] <- rexal(nrow(des$X), p0 = p0, mu = xb[, j], sigma = sigma_sel[j], gamma = gamma_sel[j])
  }
  list(
    draws = draws,
    beta_draws = beta_sel,
    sigma_draws = sigma_sel,
    gamma_draws = gamma_sel
  )
}

static_metrics_original288_normalized_multiseed <- function(row, fit_obj, series_wide, coef_truth, draws_bundle) {
  des <- static_build_design_original288_normalized_multiseed(series_wide)
  beta_draws <- draws_bundle$beta_draws
  draw_mat <- draws_bundle$draws

  slope_terms <- coef_truth$term[grepl("^x[0-9]+$", coef_truth$term)]
  beta_truth <- as.numeric(coef_truth$beta_truth[match(slope_terms, coef_truth$term)])
  true_ind <- as.logical(coef_truth$is_signal[match(slope_terms, coef_truth$term)])

  coef_names <- colnames(beta_draws)
  expected_coef_names <- c("(Intercept)", slope_terms)
  if (is.null(coef_names) && ncol(beta_draws) == length(expected_coef_names)) {
    colnames(beta_draws) <- expected_coef_names
    coef_names <- expected_coef_names
  }
  slope_idx <- match(slope_terms, coef_names %||% expected_coef_names)
  if (any(!is.finite(slope_idx)) && ncol(beta_draws) == length(expected_coef_names)) {
    slope_idx <- seq_along(slope_terms) + 1L
  }
  slope_draws <- beta_draws[, slope_idx, drop = FALSE]

  q_fit <- apply(draw_mat, 1L, stats::median, na.rm = TRUE)
  q_rmse <- sqrt(mean((q_fit - des$q_truth)^2, na.rm = TRUE))
  crps <- mean(.exdqlm_crps_vec(des$y, draw_mat), na.rm = TRUE)

  rmse_per_beta <- sqrt(colMeans((sweep(slope_draws, 2, beta_truth, "-"))^2, na.rm = TRUE))
  beta_qq <- t(apply(slope_draws, 2, stats::quantile, probs = c(0.025, 0.975), na.rm = TRUE))
  beta_cover <- beta_truth >= beta_qq[, 1] & beta_truth <= beta_qq[, 2]

  sd_x <- apply(des$X_slopes, 2, stats::sd)
  sd_y <- stats::sd(des$y)
  be_star <- sweep(slope_draws, 2, sd_x / sd_y, "*")
  be_ind <- abs(be_star) > 0.1
  cie <- mean(rowMeans(sweep(be_ind, 2, true_ind, "==")))

  ci_low <- apply(draw_mat, 1L, stats::quantile, probs = 0.025, na.rm = TRUE)
  ci_high <- apply(draw_mat, 1L, stats::quantile, probs = 0.975, na.rm = TRUE)
  coverage95 <- mean(des$y >= ci_low & des$y <= ci_high, na.rm = TRUE)

  out <- data.frame(
    crps = crps,
    q_rmse = q_rmse,
    coverage95 = coverage95,
    coverage95_gap = abs(coverage95 - 0.95),
    cie = cie,
    beta_rmse_mean = mean(rmse_per_beta),
    beta_coverage_mean = mean(beta_cover),
    beta_coverage_gap = abs(mean(beta_cover) - 0.95),
    mean_ci_width = mean(ci_high - ci_low, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  out
}

dynamic_standardize_draws_original288_normalized_multiseed <- function(fit_obj, n_draws = 20000L, seed = 1L) {
  draw_mat <- as.matrix(fit_obj$samp.post.pred)
  idx <- select_draw_indices_original288_normalized_multiseed(ncol(draw_mat), as.integer(n_draws)[1], seed)
  draw_mat[, idx, drop = FALSE]
}

dynamic_metrics_original288_normalized_multiseed <- function(row, sim_obj, draw_mat) {
  y <- as.numeric(sim_obj$y)
  truth_q <- if (!is.null(sim_obj$q) && nrow(as.matrix(sim_obj$q)) == length(y)) {
    as.numeric(as.matrix(sim_obj$q)[, 1])
  } else {
    rep(NA_real_, length(y))
  }
  q_fit <- apply(draw_mat, 1L, function(z) stats::quantile(z, probs = safe_num_original288_normalized_multiseed(row$tau_num %||% row$tau, 0.5), na.rm = TRUE))
  ci_low <- apply(draw_mat, 1L, stats::quantile, probs = 0.025, na.rm = TRUE)
  ci_high <- apply(draw_mat, 1L, stats::quantile, probs = 0.975, na.rm = TRUE)
  coverage95 <- mean(y >= ci_low & y <= ci_high, na.rm = TRUE)
  data.frame(
    crps = mean(.exdqlm_crps_vec(y, draw_mat), na.rm = TRUE),
    q_rmse = sqrt(mean((q_fit - truth_q)^2, na.rm = TRUE)),
    coverage95 = coverage95,
    coverage95_gap = abs(coverage95 - 0.95),
    mean_ci_width = mean(ci_high - ci_low, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

gate_rank_original288_normalized_multiseed <- function(gate) {
  x <- toupper(as.character(gate))
  ifelse(x == "PASS", 1L, ifelse(x == "WARN", 2L, ifelse(x == "FAIL", 3L, 4L)))
}

pilot_case_keys_original288_normalized_multiseed <- function(selection) {
  wanted <- c(
    "static_paper::normal::0p25::100::paper::al::mcmc",
    "static_paper::normal::0p25::100::paper::exal::mcmc",
    "static_paper::normal::0p25::100::paper::al::vb",
    "static_paper::normal::0p25::100::paper::exal::vb",
    "static_shrink::normal::0p25::1000::rhs_ns::exal::mcmc",
    "static_shrink::normal::0p25::1000::ridge::exal::vb",
    "dynamic::normal::0p05::500::default::dqlm::vb",
    "dynamic::normal::0p05::500::default::exdqlm::vb",
    "dynamic::normal::0p05::500::default::dqlm::mcmc",
    "dynamic::normal::0p05::500::default::exdqlm::mcmc",
    "dynamic::normal::0p05::5000::default::dqlm::mcmc",
    "dynamic::normal::0p05::5000::default::exdqlm::mcmc"
  )
  intersect(wanted, selection$original_case_key)
}

phase_for_row_original288_normalized_multiseed <- function(block, inference, pilot = FALSE) {
  prefix <- if (pilot) "pilot_" else "full_"
  if (identical(block, "dynamic") && identical(inference, "mcmc")) return(paste0(prefix, "dynamic_mcmc"))
  if (identical(block, "dynamic") && identical(inference, "vb")) return(paste0(prefix, "dynamic_vb"))
  if (identical(inference, "mcmc")) return(paste0(prefix, "static_mcmc"))
  paste0(prefix, "static_vb")
}
