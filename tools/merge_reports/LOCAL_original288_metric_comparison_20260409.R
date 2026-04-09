#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

PRIMARY_WORKTREE_ROOT <- "/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration"
FALLBACK_WORKTREE_ROOTS <- c(
  "/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

ensure_dir_metric_cmp <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

parse_runtime_sec <- function(sel_runtime, fit_obj) {
  candidates <- c(
    suppressWarnings(as.numeric(sel_runtime[1])),
    suppressWarnings(as.numeric(fit_obj$meta$runtime_sec %||% NA_real_)),
    suppressWarnings(as.numeric(fit_obj$run.time %||% NA_real_))
  )
  candidates <- candidates[is.finite(candidates)]
  if (!length(candidates)) NA_real_ else candidates[1]
}

first_numeric_col <- function(x) {
  if (is.null(dim(x))) return(as.numeric(x))
  as.numeric(x[, 1])
}

find_upward_file <- function(start_path, target_name, max_levels = 8L) {
  cur <- normalizePath(dirname(start_path), winslash = "/", mustWork = TRUE)
  for (i in 0:max_levels) {
    cand <- file.path(cur, target_name)
    if (file.exists(cand)) return(cand)
    nxt <- dirname(cur)
    if (identical(nxt, cur)) break
    cur <- nxt
  }
  NA_character_
}

find_upward_file_with_fallbacks <- function(start_path, target_name, max_levels = 8L) {
  direct <- find_upward_file(start_path, target_name, max_levels = max_levels)
  if (!is.na(direct)) return(direct)

  norm_start <- normalizePath(start_path, winslash = "/", mustWork = FALSE)
  for (root in FALLBACK_WORKTREE_ROOTS) {
    if (!startsWith(norm_start, PRIMARY_WORKTREE_ROOT)) next
    alt_start <- sub(
      paste0("^", PRIMARY_WORKTREE_ROOT),
      root,
      norm_start
    )
    alt_match <- find_upward_file(alt_start, target_name, max_levels = max_levels)
    if (!is.na(alt_match)) return(alt_match)
  }

  NA_character_
}

safe_rmvnorm <- function(n, mean, sigma) {
  mean <- as.numeric(mean)
  sigma <- as.matrix(sigma)
  if (!nrow(sigma)) return(matrix(mean, nrow = n, byrow = TRUE))
  if (any(!is.finite(sigma))) {
    sigma[!is.finite(sigma)] <- 0
  }
  if (!all(is.finite(mean))) {
    mean[!is.finite(mean)] <- 0
  }
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

interval_score_vec <- function(observed, lower, upper, level = 95) {
  alpha <- 1 - level / 100
  width <- upper - lower
  lower_penalty <- (2 / alpha) * (lower - observed) * (observed < lower)
  upper_penalty <- (2 / alpha) * (observed - upper) * (observed > upper)
  width + lower_penalty + upper_penalty
}

check_loss_vec <- function(p0, residual) {
  residual * (p0 - (residual < 0))
}

.exdqlm_crps_row_local <- function(y_true, draws_vec) {
  z <- sort(as.numeric(draws_vec))
  z <- z[is.finite(z)]
  m <- length(z)
  if (m < 2L || !is.finite(y_true)) {
    return(NA_real_)
  }
  mean(abs(z - y_true)) - sum((2 * seq_len(m) - m - 1) * z) / (m^2)
}

.exdqlm_crps_vec_local <- function(y_true, draws_mat) {
  draws_mat <- as.matrix(draws_mat)
  stopifnot(length(y_true) == nrow(draws_mat))
  vapply(seq_len(nrow(draws_mat)), function(i) {
    .exdqlm_crps_row_local(y_true[[i]], draws_mat[i, ])
  }, numeric(1))
}

coverage_gap <- function(x, target = 0.95) abs(x - target)

static_vb_sigma_draws <- function(fit_obj, n_draws) {
  if (!is.null(fit_obj$qsig$E_sigma)) {
    a <- as.numeric(fit_obj$qsig$a)[1]
    b <- as.numeric(fit_obj$qsig$b)[1]
    if (is.finite(a) && is.finite(b) && a > 0 && b > 0) {
      return(1 / rgamma(n_draws, shape = a, rate = b))
    }
    return(rep(as.numeric(fit_obj$qsig$E_sigma)[1], n_draws))
  }
  rep(as.numeric(fit_obj$qsiggam$sigma_mean)[1], n_draws)
}

static_vb_gamma_draws <- function(fit_obj, n_draws) {
  if (is.null(fit_obj$qsiggam)) return(rep(0, n_draws))
  center <- c(
    as.numeric(fit_obj$qsiggam$eta_hat)[1],
    as.numeric(fit_obj$qsiggam$ell_hat)[1]
  )
  Sigma <- as.matrix(fit_obj$qsiggam$Sigma)
  draws <- safe_rmvnorm(n_draws, center, Sigma)
  # gamma transform follows the implementation's eta scale.
  sinh(draws[, 1])
}

extract_static_metrics <- function(sel_row, vb_draws = 1000L) {
  fit_path <- sel_row$selected_fit_path[[1]]
  fit_raw <- readRDS(fit_path)
  fit_obj <- fit_raw$fit %||% fit_raw
  sim_path <- find_upward_file_with_fallbacks(fit_path, "sim_output.rds")
  if (is.na(sim_path)) stop(sprintf("sim_output.rds not found upward from %s", fit_path))
  sim <- readRDS(sim_path)

  X <- as.matrix(fit_obj$X %||% sim$extras$X)
  y <- as.numeric(sim$y)
  q_truth <- first_numeric_col(sim$q)
  beta_truth <- as.numeric(sim$extras$beta_mean %||% sim$extras$coef_truth$beta_truth)
  true_ind <- as.logical(sim$extras$true_ind)

  slope_idx <- if (ncol(X) == length(beta_truth) + 1L) 2:ncol(X) else seq_len(length(beta_truth))
  sd_x <- apply(X[, slope_idx, drop = FALSE], 2, stats::sd)
  sd_y <- stats::sd(y)
  signal_threshold <- 0.1

  if (identical(sel_row$inference[[1]], "mcmc")) {
    beta_draws <- as.matrix(fit_obj$samp.beta)
    beta_mean <- colMeans(beta_draws)
    slope_draws <- beta_draws[, slope_idx, drop = FALSE]
  } else {
    beta_mean <- as.numeric(fit_obj$qbeta$m)
    beta_draws <- safe_rmvnorm(vb_draws, beta_mean, as.matrix(fit_obj$qbeta$V))
    slope_draws <- beta_draws[, slope_idx, drop = FALSE]
  }

  q_fit <- as.numeric(drop(X %*% beta_mean))
  q_rmse <- sqrt(mean((q_fit - q_truth) ^ 2, na.rm = TRUE))

  rmse_per_beta <- sqrt(colMeans((sweep(slope_draws, 2, beta_truth, "-")) ^ 2, na.rm = TRUE))
  beta_qq <- t(apply(slope_draws, 2, stats::quantile, probs = c(0.025, 0.975), na.rm = TRUE))
  beta_cover <- beta_truth >= beta_qq[, 1] & beta_truth <= beta_qq[, 2]

  be_star <- sweep(slope_draws, 2, sd_x / sd_y, "*")
  be_ind <- abs(be_star) > signal_threshold
  cie <- mean(rowMeans(sweep(be_ind, 2, true_ind, "==")))

  out <- data.frame(
    row_id = NA_integer_,
    block = sel_row$block[[1]],
    root_kind = sel_row$root_kind[[1]],
    family = sel_row$family[[1]],
    tau_label = sel_row$tau[[1]],
    fit_size = as.integer(sel_row$fit_size[[1]]),
    prior_semantics = sel_row$prior_semantics[[1]],
    model = sel_row$model[[1]],
    inference = sel_row$inference[[1]],
    method_id = paste(sel_row$inference[[1]], sel_row$model[[1]], sep = "__"),
    original_case_key = sel_row$original_case_key[[1]],
    original_scenario_key = sel_row$original_scenario_key[[1]],
    fit_path = fit_path,
    sim_path = sim_path,
    metric_scope = "static",
    metric_error = NA_character_,
    q_rmse = q_rmse,
    cie = cie,
    beta_rmse_mean = mean(rmse_per_beta),
    beta_coverage_mean = mean(beta_cover),
    beta_coverage_gap = coverage_gap(mean(beta_cover)),
    runtime_sec = parse_runtime_sec(sel_row$runtime_sec, fit_obj),
    stringsAsFactors = FALSE
  )

  for (j in seq_along(beta_truth)) {
    out[[sprintf("beta_rmse_b%02d", j)]] <- rmse_per_beta[j]
    out[[sprintf("beta_cover_b%02d", j)]] <- as.numeric(beta_cover[j])
  }

  out
}

extract_dynamic_metrics <- function(sel_row) {
  fit_path <- sel_row$selected_fit_path[[1]]
  fit_raw <- readRDS(fit_path)
  fit_obj <- fit_raw$fit %||% fit_raw
  sim_path <- find_upward_file_with_fallbacks(fit_path, "sim_output.rds")
  if (is.na(sim_path)) stop(sprintf("sim_output.rds not found upward from %s", fit_path))
  sim <- readRDS(sim_path)

  y <- as.numeric(fit_obj$y %||% sim$y)
  q_truth <- first_numeric_col(sim$q)
  pred <- as.matrix(fit_obj$samp.post.pred)
  p0 <- as.numeric(fit_obj$p0)[1]

  q_fit <- apply(pred, 1, stats::quantile, probs = p0, na.rm = TRUE)
  q_rmse <- sqrt(mean((q_fit - q_truth) ^ 2, na.rm = TRUE))

  err <- matrix(y, nrow = length(y), ncol = ncol(pred)) - pred
  pplc <- sum(rowMeans(check_loss_vec(p0, err), na.rm = TRUE), na.rm = TRUE)
  crps <- mean(.exdqlm_crps_vec_local(y, pred), na.rm = TRUE)

  qq95 <- t(apply(pred, 1, stats::quantile, probs = c(0.025, 0.975), na.rm = TRUE))
  interval_score_mean <- mean(interval_score_vec(y, qq95[, 1], qq95[, 2], level = 95), na.rm = TRUE)
  coverage95 <- mean(y >= qq95[, 1] & y <= qq95[, 2], na.rm = TRUE)

  out <- data.frame(
    row_id = NA_integer_,
    block = sel_row$block[[1]],
    root_kind = sel_row$root_kind[[1]],
    family = sel_row$family[[1]],
    tau_label = sel_row$tau[[1]],
    fit_size = as.integer(sel_row$fit_size[[1]]),
    prior_semantics = sel_row$prior_semantics[[1]],
    model = sel_row$model[[1]],
    inference = sel_row$inference[[1]],
    method_id = paste(sel_row$inference[[1]], sel_row$model[[1]], sep = "__"),
    original_case_key = sel_row$original_case_key[[1]],
    original_scenario_key = sel_row$original_scenario_key[[1]],
    fit_path = fit_path,
    sim_path = sim_path,
    metric_scope = "dynamic",
    metric_error = NA_character_,
    q_rmse = q_rmse,
    pplc = pplc,
    crps = crps,
    interval_score_mean = interval_score_mean,
    coverage95 = coverage95,
    coverage95_gap = coverage_gap(coverage95),
    runtime_sec = parse_runtime_sec(sel_row$runtime_sec, fit_obj),
    stringsAsFactors = FALSE
  )

  out
}

aggregate_summary <- function(df, by, metrics, higher_better = character()) {
  if (!nrow(df)) return(data.frame())
  split_df <- split(df, interaction(df[by], drop = TRUE, lex.order = TRUE))
  out <- lapply(split_df, function(chunk) {
    base <- chunk[1, by, drop = FALSE]
    row <- base
    row$n <- nrow(chunk)
    for (metric in metrics) {
      vals <- suppressWarnings(as.numeric(chunk[[metric]]))
      row[[paste0(metric, "_median")]] <- if (all(is.na(vals))) NA_real_ else stats::median(vals, na.rm = TRUE)
      row[[paste0(metric, "_mean")]] <- if (all(is.na(vals))) NA_real_ else mean(vals, na.rm = TRUE)
    }
    row
  })
  do.call(rbind, out)
}

build_static_pairs <- function(static_df) {
  id_cols <- c("block", "family", "tau_label", "fit_size", "prior_semantics", "inference")
  al <- static_df[static_df$model == "al", c(id_cols, "q_rmse", "cie", "beta_rmse_mean", "beta_coverage_gap", "runtime_sec"), drop = FALSE]
  exal <- static_df[static_df$model == "exal", c(id_cols, "q_rmse", "cie", "beta_rmse_mean", "beta_coverage_gap", "runtime_sec"), drop = FALSE]
  names(al)[-(seq_along(id_cols))] <- paste0(names(al)[-(seq_along(id_cols))], "_al")
  names(exal)[-(seq_along(id_cols))] <- paste0(names(exal)[-(seq_along(id_cols))], "_exal")
  out <- merge(al, exal, by = id_cols, sort = FALSE)
  out$q_rmse_delta_exal_minus_al <- out$q_rmse_exal - out$q_rmse_al
  out$cie_delta_exal_minus_al <- out$cie_exal - out$cie_al
  out$beta_rmse_delta_exal_minus_al <- out$beta_rmse_mean_exal - out$beta_rmse_mean_al
  out$beta_coverage_gap_delta_exal_minus_al <- out$beta_coverage_gap_exal - out$beta_coverage_gap_al
  out$runtime_ratio_exal_over_al <- out$runtime_sec_exal / out$runtime_sec_al
  out$exal_better_q_rmse <- out$q_rmse_delta_exal_minus_al < 0
  out$exal_better_cie <- out$cie_delta_exal_minus_al > 0
  out$exal_better_beta_rmse <- out$beta_rmse_delta_exal_minus_al < 0
  out$exal_better_beta_coverage <- out$beta_coverage_gap_delta_exal_minus_al < 0
  out
}

build_dynamic_pairs <- function(dynamic_df) {
  id_cols <- c("family", "tau_label", "fit_size", "inference")
  dqlm <- dynamic_df[dynamic_df$model == "dqlm", c(id_cols, "q_rmse", "pplc", "crps", "interval_score_mean", "coverage95_gap", "runtime_sec"), drop = FALSE]
  exdqlm <- dynamic_df[dynamic_df$model == "exdqlm", c(id_cols, "q_rmse", "pplc", "crps", "interval_score_mean", "coverage95_gap", "runtime_sec"), drop = FALSE]
  names(dqlm)[-(seq_along(id_cols))] <- paste0(names(dqlm)[-(seq_along(id_cols))], "_dqlm")
  names(exdqlm)[-(seq_along(id_cols))] <- paste0(names(exdqlm)[-(seq_along(id_cols))], "_exdqlm")
  out <- merge(dqlm, exdqlm, by = id_cols, sort = FALSE)
  out$q_rmse_delta_exdqlm_minus_dqlm <- out$q_rmse_exdqlm - out$q_rmse_dqlm
  out$pplc_delta_exdqlm_minus_dqlm <- out$pplc_exdqlm - out$pplc_dqlm
  out$crps_delta_exdqlm_minus_dqlm <- out$crps_exdqlm - out$crps_dqlm
  out$interval_score_delta_exdqlm_minus_dqlm <- out$interval_score_mean_exdqlm - out$interval_score_mean_dqlm
  out$coverage95_gap_delta_exdqlm_minus_dqlm <- out$coverage95_gap_exdqlm - out$coverage95_gap_dqlm
  out$runtime_ratio_exdqlm_over_dqlm <- out$runtime_sec_exdqlm / out$runtime_sec_dqlm
  out$exdqlm_better_q_rmse <- out$q_rmse_delta_exdqlm_minus_dqlm < 0
  out$exdqlm_better_pplc <- out$pplc_delta_exdqlm_minus_dqlm < 0
  out$exdqlm_better_crps <- out$crps_delta_exdqlm_minus_dqlm < 0
  out$exdqlm_better_interval_score <- out$interval_score_delta_exdqlm_minus_dqlm < 0
  out$exdqlm_better_coverage95 <- out$coverage95_gap_delta_exdqlm_minus_dqlm < 0
  out
}

pair_summary_static <- function(pair_df, by) {
  aggregate_summary(pair_df, by, c(
    "q_rmse_delta_exal_minus_al", "cie_delta_exal_minus_al",
    "beta_rmse_delta_exal_minus_al", "beta_coverage_gap_delta_exal_minus_al",
    "runtime_ratio_exal_over_al"
  ))
}

pair_summary_dynamic <- function(pair_df, by) {
  aggregate_summary(pair_df, by, c(
    "q_rmse_delta_exdqlm_minus_dqlm", "pplc_delta_exdqlm_minus_dqlm",
    "crps_delta_exdqlm_minus_dqlm", "interval_score_delta_exdqlm_minus_dqlm",
    "coverage95_gap_delta_exdqlm_minus_dqlm", "runtime_ratio_exdqlm_over_dqlm"
  ))
}

summarize_pair_groups <- function(pair_df, by, delta_metrics, win_metrics) {
  split_df <- split(pair_df, interaction(pair_df[by], drop = TRUE, lex.order = TRUE))
  out <- lapply(split_df, function(chunk) {
    base <- chunk[1, by, drop = FALSE]
    row <- base
    row$n <- nrow(chunk)
    for (metric in delta_metrics) {
      vals <- suppressWarnings(as.numeric(chunk[[metric]]))
      row[[paste0(metric, "_available_n")]] <- sum(!is.na(vals))
      row[[paste0(metric, "_median")]] <- if (all(is.na(vals))) NA_real_ else stats::median(vals, na.rm = TRUE)
      row[[paste0(metric, "_mean")]] <- if (all(is.na(vals))) NA_real_ else mean(vals, na.rm = TRUE)
    }
    for (metric in win_metrics) {
      vals <- chunk[[metric]]
      row[[paste0(metric, "_available_n")]] <- sum(!is.na(vals))
      row[[metric]] <- sum(as.logical(vals), na.rm = TRUE)
    }
    row
  })
  do.call(rbind, out)
}

metric_error_row <- function(sel_row, error_message) {
  is_dynamic <- identical(sel_row$root_kind[[1]], "dynamic")
  out <- data.frame(
    row_id = NA_integer_,
    block = sel_row$block[[1]],
    root_kind = sel_row$root_kind[[1]],
    family = sel_row$family[[1]],
    tau_label = sel_row$tau[[1]],
    fit_size = as.integer(sel_row$fit_size[[1]]),
    prior_semantics = sel_row$prior_semantics[[1]],
    model = sel_row$model[[1]],
    inference = sel_row$inference[[1]],
    method_id = paste(sel_row$inference[[1]], sel_row$model[[1]], sep = "__"),
    original_case_key = sel_row$original_case_key[[1]],
    original_scenario_key = sel_row$original_scenario_key[[1]],
    fit_path = sel_row$selected_fit_path[[1]],
    sim_path = NA_character_,
    metric_scope = if (is_dynamic) "dynamic" else "static",
    metric_error = as.character(error_message),
    stringsAsFactors = FALSE
  )

  static_metric_cols <- c("q_rmse", "cie", "beta_rmse_mean", "beta_coverage_mean", "beta_coverage_gap", "runtime_sec")
  dynamic_metric_cols <- c("q_rmse", "pplc", "crps", "interval_score_mean", "coverage95", "coverage95_gap", "runtime_sec")
  for (nm in unique(c(static_metric_cols, dynamic_metric_cols))) {
    out[[nm]] <- NA_real_
  }
  for (j in seq_len(8)) {
    out[[sprintf("beta_rmse_b%02d", j)]] <- NA_real_
    out[[sprintf("beta_cover_b%02d", j)]] <- NA_real_
  }

  out
}

selection_path <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v7_20260407.csv"
selection <- utils::read.csv(selection_path, stringsAsFactors = FALSE)
selection$row_id <- seq_len(nrow(selection))

out_dir <- file.path("tools", "merge_reports", "original288_metric_comparison_20260409")
ensure_dir_metric_cmp(out_dir)

suppressPackageStartupMessages({
  library(exdqlm)
  library(mvtnorm)
})

metric_rows <- lapply(seq_len(nrow(selection)), function(i) {
  row <- selection[i, , drop = FALSE]
  res <- tryCatch(
    if (identical(row$root_kind[[1]], "dynamic")) extract_dynamic_metrics(row) else extract_static_metrics(row),
    error = function(e) metric_error_row(row, conditionMessage(e))
  )
  res$row_id <- row$row_id[[1]]
  res$gate_overall <- row$gate_overall[[1]]
  res$healthy <- row$healthy[[1]]
  res
})

all_metric_cols <- Reduce(union, lapply(metric_rows, names))
metric_rows <- lapply(metric_rows, function(x) {
  missing_cols <- setdiff(all_metric_cols, names(x))
  for (nm in missing_cols) {
    x[[nm]] <- NA
  }
  x[all_metric_cols]
})

metric_long <- do.call(rbind, metric_rows)
metric_long <- metric_long[order(metric_long$row_id), , drop = FALSE]
utils::write.csv(metric_long, file.path(out_dir, "original288_metric_long_20260409.csv"), row.names = FALSE)

static_df <- subset(metric_long, metric_scope == "static")
dynamic_df <- subset(metric_long, metric_scope == "dynamic")

utils::write.csv(
  aggregate_summary(static_df, c("block", "prior_semantics", "inference", "model"), c("q_rmse", "cie", "beta_rmse_mean", "beta_coverage_mean", "beta_coverage_gap", "runtime_sec")),
  file.path(out_dir, "original288_static_metric_summary_by_method_20260409.csv"),
  row.names = FALSE
)
utils::write.csv(
  aggregate_summary(dynamic_df, c("inference", "model"), c("q_rmse", "pplc", "crps", "interval_score_mean", "coverage95", "coverage95_gap", "runtime_sec")),
  file.path(out_dir, "original288_dynamic_metric_summary_by_method_20260409.csv"),
  row.names = FALSE
)

static_pairs <- build_static_pairs(static_df)
dynamic_pairs <- build_dynamic_pairs(dynamic_df)

utils::write.csv(static_pairs, file.path(out_dir, "original288_static_metric_pair_comparison_20260409.csv"), row.names = FALSE)
utils::write.csv(dynamic_pairs, file.path(out_dir, "original288_dynamic_metric_pair_comparison_20260409.csv"), row.names = FALSE)

static_pair_summary <- summarize_pair_groups(
  static_pairs,
  c("block", "prior_semantics", "inference"),
  c(
    "q_rmse_delta_exal_minus_al", "cie_delta_exal_minus_al",
    "beta_rmse_delta_exal_minus_al", "beta_coverage_gap_delta_exal_minus_al",
    "runtime_ratio_exal_over_al"
  ),
  c("exal_better_q_rmse", "exal_better_cie", "exal_better_beta_rmse", "exal_better_beta_coverage")
)
utils::write.csv(static_pair_summary, file.path(out_dir, "original288_static_metric_pair_summary_20260409.csv"), row.names = FALSE)

dynamic_pair_summary <- summarize_pair_groups(
  dynamic_pairs,
  c("inference"),
  c(
    "q_rmse_delta_exdqlm_minus_dqlm", "pplc_delta_exdqlm_minus_dqlm",
    "crps_delta_exdqlm_minus_dqlm", "interval_score_delta_exdqlm_minus_dqlm",
    "coverage95_gap_delta_exdqlm_minus_dqlm", "runtime_ratio_exdqlm_over_dqlm"
  ),
  c("exdqlm_better_q_rmse", "exdqlm_better_pplc", "exdqlm_better_crps", "exdqlm_better_interval_score", "exdqlm_better_coverage95")
)
utils::write.csv(dynamic_pair_summary, file.path(out_dir, "original288_dynamic_metric_pair_summary_20260409.csv"), row.names = FALSE)

meta <- data.frame(
  selection_rows = nrow(selection),
  metric_rows = nrow(metric_long),
  static_rows = nrow(static_df),
  dynamic_rows = nrow(dynamic_df),
  stringsAsFactors = FALSE
)
utils::write.csv(meta, file.path(out_dir, "original288_metric_meta_20260409.csv"), row.names = FALSE)

cat(sprintf("Wrote broader original288 metric comparison outputs to %s\n", out_dir))
