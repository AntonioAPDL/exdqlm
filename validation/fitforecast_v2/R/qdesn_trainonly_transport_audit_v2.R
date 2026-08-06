`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_ttav2_scale_train_only <- function(y, X, n_train) {
  n_train <- as.integer(n_train)
  y_center <- mean(y[seq_len(n_train)])
  y_scale <- stats::sd(y[seq_len(n_train)])
  if (!is.finite(y_scale) || y_scale <= 1e-12) y_scale <- 1
  out_X <- X
  x_center <- x_scale <- numeric(0)
  if (!is.null(X) && ncol(X)) {
    x_center <- colMeans(X[seq_len(n_train), , drop = FALSE])
    x_scale <- apply(X[seq_len(n_train), , drop = FALSE], 2L, stats::sd)
    x_scale[!is.finite(x_scale) | x_scale <= 1e-12] <- 1
    out_X <- sweep(sweep(X, 2L, x_center, "-"), 2L, x_scale, "/")
  }
  list(y = (y - y_center) / y_scale, X = out_X, y_center = y_center,
       y_scale = y_scale, x_center = x_center, x_scale = x_scale)
}

qdesn_ttav2_matrix_diagnostics <- function(X_train, X_forecast, X_res_train = NULL,
                                           X_res_forecast = NULL) {
  X_train <- as.matrix(X_train); X_forecast <- as.matrix(X_forecast)
  sds <- apply(X_train, 2L, stats::sd)
  active <- is.finite(sds) & sds > 1e-10
  Zt <- sweep(sweep(X_train[, active, drop = FALSE], 2L,
                    colMeans(X_train[, active, drop = FALSE]), "-"), 2L, sds[active], "/")
  Zf <- sweep(sweep(X_forecast[, active, drop = FALSE], 2L,
                    colMeans(X_train[, active, drop = FALSE]), "-"), 2L, sds[active], "/")
  singular <- svd(Zt, nu = 0L, nv = 0L)$d
  condition <- if (length(singular) && min(singular) > 0) max(singular) / min(singular) else Inf
  corr <- if (ncol(Zt) > 1L) suppressWarnings(stats::cor(Zt)) else matrix(0, 1L, 1L)
  diag(corr) <- 0
  res_stat <- function(M, fun, default = NA_real_) {
    if (is.null(M) || !length(M)) return(default)
    fun(as.numeric(M))
  }
  data.frame(
    n_train = nrow(X_train), n_forecast = nrow(X_forecast), p = ncol(X_train),
    p_active = sum(active), rank = qr(X_train)$rank, condition_number = condition,
    max_abs_feature_correlation = max(abs(corr), na.rm = TRUE),
    standardized_centroid_shift = sqrt(mean(colMeans(Zf)^2)),
    standardized_scale_ratio_median = median(apply(Zf, 2L, stats::sd), na.rm = TRUE),
    reservoir_abs_mean_train = res_stat(X_res_train, function(x) mean(abs(x))),
    reservoir_abs_mean_forecast = res_stat(X_res_forecast, function(x) mean(abs(x))),
    reservoir_saturation_train = res_stat(X_res_train, function(x) mean(abs(x) >= 0.95)),
    reservoir_saturation_forecast = res_stat(X_res_forecast, function(x) mean(abs(x) >= 0.95)),
    stringsAsFactors = FALSE
  )
}

qdesn_ttav2_intercept_shift <- function(train_path, tau, window) {
  train_path <- train_path[train_path$effective_train %in% TRUE, , drop = FALSE]
  z <- utils::tail(train_path, min(as.integer(window), nrow(train_path)))
  as.numeric(stats::quantile(z$y - z$q_pred, probs = tau, type = 8L, na.rm = TRUE))
}

qdesn_ttav2_apply_shift <- function(train_path, forecast_path, tau, shift) {
  train <- train_path[train_path$effective_train %in% TRUE, , drop = FALSE]
  qfit <- train$q_pred + shift
  qfore <- forecast_path$qhat + shift
  loss <- (tau - as.numeric(forecast_path$y < qfore)) * (forecast_path$y - qfore)
  data.frame(
    shift = shift,
    fit_rmse = sqrt(mean((qfit - train$q_true)^2)),
    forecast_mae = mean(abs(qfore - forecast_path$q_true)),
    forecast_check = mean(loss),
    forecast_bias = mean(qfore - forecast_path$q_true),
    stringsAsFactors = FALSE
  )
}

qdesn_ttav2_candidate_gate <- function(summary) {
  overall <- summary[summary$calibration_window > 0L, , drop = FALSE]
  keys <- unique(overall[, c("arm_code", "calibration_window"), drop = FALSE])
  eligible <- character(0)
  for (i in seq_len(nrow(keys))) {
    z <- overall[overall$arm_code == keys$arm_code[[i]] &
                   overall$calibration_window == keys$calibration_window[[i]], , drop = FALSE]
    if (all(c("frozen_article", "untouched_confirmation") %in% z$source_role) &&
        all(z$median_forecast_mae_ratio <= 0.95) &&
        all(z$median_fit_rmse_ratio <= 1.05) &&
        all(z$median_forecast_check_ratio <= 1.05) &&
        all(z$worst_seed_forecast_mae_ratio <= 1.10)) {
      eligible <- c(eligible, sprintf("%s:k%d", keys$arm_code[[i]], keys$calibration_window[[i]]))
    }
  }
  unique(eligible)
}

qdesn_ttav2_exal_capabilities <- function() {
  data.frame(
    model_lane = c("exDQLM", "exDQLM", "Q-DESN exAL", "Q-DESN exAL"),
    control = c("fix.gamma", "fix.sigma", "fixed gamma", "fixed sigma"),
    package_api = c("exdqlmMCMC", "exdqlmMCMC", "exal_mcmc_fit", "exal_mcmc_fit"),
    supported_in_1p0p0 = c(TRUE, TRUE, FALSE, FALSE),
    evidence = c(
      "formal argument fix.gamma with gam.init",
      "formal argument fix.sigma with sig.init",
      "al_fixed_gamma is restricted to likelihood_family=al",
      "no fixed-sigma formal argument or normalized control"
    ),
    action = c("available_for_exdqlm_diagnostic", "available_for_exdqlm_diagnostic",
               "do_not_launch_without_package_change", "do_not_launch_without_package_change"),
    stringsAsFactors = FALSE
  )
}
