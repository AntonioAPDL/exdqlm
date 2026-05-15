# Quantile-model diagnostics for benchmarked Q-DESN candidates.

bench_qdesn_prob_label <- function(prob) {
  formatC(as.numeric(prob), format = "f", digits = 3)
}

bench_qdesn_quantile_band <- function(prob) {
  prob <- as.numeric(prob)
  ifelse(
    prob <= 0.15, "lower_tail",
    ifelse(
      prob <= 0.40, "lower_shoulder",
      ifelse(
        prob <= 0.55, "center",
        ifelse(prob <= 0.80, "upper_shoulder", "upper_tail")
      )
    )
  )
}

bench_qdesn_quantile_metrics_table <- function(bundle, p_vec, quantile_draws, tail_threshold = 0.10) {
  y_true <- as.numeric(bundle$eval_y)
  p_vec <- as.numeric(p_vec)
  tail_threshold <- as.numeric(tail_threshold %||% 0.10)[1L]

  if (!length(p_vec) || !length(quantile_draws)) {
    return(data.table::data.table())
  }

  rows <- lapply(seq_along(p_vec), function(i) {
    draws <- as.matrix(quantile_draws[[i]])
    if (!nrow(draws) || nrow(draws) != length(y_true)) {
      return(NULL)
    }

    p0 <- p_vec[[i]]
    qhat <- apply(draws, 1L, stats::quantile, probs = p0, names = FALSE, na.rm = TRUE)
    pit <- vapply(seq_len(nrow(draws)), function(j) bench_qdesn_pit_value(y_true[[j]], draws[j, ]), numeric(1))
    empirical_coverage <- mean(y_true <= qhat, na.rm = TRUE)

    data.table::data.table(
      dataset = bundle$dataset,
      source_family = bundle$source_family,
      benchmark_pool = bundle$benchmark_pool,
      route_key = bundle$route_key %||% "global",
      series_id = bundle$series_id,
      stage = bundle$stage,
      benchmark_split_protocol = bundle$benchmark_split_protocol,
      selection_protocol = bundle$selection_protocol,
      quantile_p = p0,
      quantile_label = bench_qdesn_prob_label(p0),
      is_tail = as.logical(p0 <= tail_threshold || p0 >= (1 - tail_threshold)),
      n_leads = length(y_true),
      empirical_coverage = empirical_coverage,
      target_coverage = p0,
      coverage_dev = empirical_coverage - p0,
      abs_coverage_dev = abs(empirical_coverage - p0),
      pinball_mean = mean(bench_qdesn_pinball_loss(y_true, qhat, p0), na.rm = TRUE),
      pit_mean = mean(pit, na.rm = TRUE),
      pit_var = stats::var(pit, na.rm = TRUE),
      abs_pit_dev_mean = abs(mean(pit, na.rm = TRUE) - 0.5),
      qhat_mean = mean(qhat, na.rm = TRUE),
      qhat_sd = stats::sd(qhat, na.rm = TRUE)
    )
  })

  data.table::rbindlist(rows, fill = TRUE)
}

bench_qdesn_quantile_summary_row <- function(quantile_metrics) {
  dt <- data.table::as.data.table(quantile_metrics)
  safe_mean <- function(x) if (all(!is.finite(x))) NA_real_ else mean(x, na.rm = TRUE)
  safe_max <- function(x) if (all(!is.finite(x))) NA_real_ else max(x, na.rm = TRUE)
  if (!nrow(dt)) {
    return(list(
      n_quantiles = 0L,
      n_tail_quantiles = 0L,
      quantile_pinball_mean = NA_real_,
      tail_pinball_mean = NA_real_,
      quantile_abs_coverage_dev_mean = NA_real_,
      max_abs_quantile_coverage_dev = NA_real_,
      tail_abs_quantile_coverage_dev_mean = NA_real_,
      tail_abs_quantile_coverage_dev_max = NA_real_,
      quantile_abs_pit_dev_mean = NA_real_,
      max_abs_pit_dev_mean = NA_real_,
      shoulder_pinball_mean = NA_real_,
      reference_pinball_mean = NA_real_,
      shoulder_pinball_ratio = NA_real_,
      shoulder_qhat_abs_mean = NA_real_,
      reference_qhat_abs_mean = NA_real_,
      shoulder_qhat_ratio = NA_real_
    ))
  }

  tail_dt <- dt[is_tail == TRUE]
  if (!nrow(tail_dt)) tail_dt <- dt
  dt[, quantile_band := bench_qdesn_quantile_band(quantile_p)]
  dt[, qhat_abs_mean := abs(qhat_mean)]
  shoulder_dt <- dt[quantile_band %chin% c("lower_shoulder", "upper_shoulder")]
  reference_dt <- dt[quantile_band %chin% c("lower_tail", "center", "upper_tail")]
  if (!nrow(shoulder_dt)) shoulder_dt <- dt
  if (!nrow(reference_dt)) reference_dt <- dt

  shoulder_pinball_mean <- safe_mean(shoulder_dt$pinball_mean)
  reference_pinball_mean <- safe_mean(reference_dt$pinball_mean)
  shoulder_qhat_abs_mean <- safe_mean(shoulder_dt$qhat_abs_mean)
  reference_qhat_abs_mean <- safe_mean(reference_dt$qhat_abs_mean)

  list(
    n_quantiles = as.integer(nrow(dt)),
    n_tail_quantiles = as.integer(nrow(tail_dt)),
    quantile_pinball_mean = safe_mean(dt$pinball_mean),
    tail_pinball_mean = safe_mean(tail_dt$pinball_mean),
    quantile_abs_coverage_dev_mean = safe_mean(dt$abs_coverage_dev),
    max_abs_quantile_coverage_dev = safe_max(dt$abs_coverage_dev),
    tail_abs_quantile_coverage_dev_mean = safe_mean(tail_dt$abs_coverage_dev),
    tail_abs_quantile_coverage_dev_max = safe_max(tail_dt$abs_coverage_dev),
    quantile_abs_pit_dev_mean = safe_mean(dt$abs_pit_dev_mean),
    max_abs_pit_dev_mean = safe_max(dt$abs_pit_dev_mean),
    shoulder_pinball_mean = shoulder_pinball_mean,
    reference_pinball_mean = reference_pinball_mean,
    shoulder_pinball_ratio = shoulder_pinball_mean / pmax(reference_pinball_mean, 1e-12),
    shoulder_qhat_abs_mean = shoulder_qhat_abs_mean,
    reference_qhat_abs_mean = reference_qhat_abs_mean,
    shoulder_qhat_ratio = shoulder_qhat_abs_mean / pmax(reference_qhat_abs_mean, 1e-12)
  )
}

bench_qdesn_rhs_diagnostics_row <- function(qfit, p0, candidate_cfg, seed = NA_integer_) {
  fit_exal <- qfit$fit %||% NULL
  if (is.null(fit_exal)) {
    return(data.table::data.table())
  }

  fit_beta_prior <- fit_exal$beta_prior %||% list(type = "ridge", hypers = list(), state = list())
  beta_type <- as.character(fit_beta_prior$type %||% "ridge")[1L]
  qbeta_mean <- as.numeric(fit_exal$qbeta$m %||% numeric(0))
  is_rhs_family <- beta_type %in% c("rhs", "rhs_ns")

  if (!is_rhs_family) {
    return(data.table::data.table(
      quantile_p = as.numeric(p0),
      quantile_label = bench_qdesn_prob_label(p0),
      seed = as.integer(seed),
      beta_prior_type = beta_type,
      beta_ridge_tau2 = as.numeric(fit_beta_prior$hypers$tau2 %||% candidate_cfg$vb_args$beta_ridge_tau2 %||% NA_real_),
      tau0 = NA_real_,
      nu = NA_real_,
      s_used = NA_real_,
      s2_used = NA_real_,
      init_log_tau = NA_real_,
      eta_tau_lower_bound = NA_real_,
      eta_tau_upper_bound = NA_real_,
      tau_last = NA_real_,
      log_tau_last = NA_real_,
      c2_last = NA_real_,
      lambda_med = NA_real_,
      lambda_min = NA_real_,
      lambda_max = NA_real_,
      E_invV_med_last = NA_real_,
      beta_l2_last = sqrt(sum(qbeta_mean^2)),
      near_bound_flag = FALSE,
      collapse_flag = FALSE
    ))
  }

  beta_state <- fit_beta_prior$state %||% list()
  beta_hypers <- fit_beta_prior$hypers %||% list()
  beta_obj <- beta_prior(beta_type, rhs = beta_hypers)
  p_dim <- length(qbeta_mean)
  prec <- tryCatch(beta_obj$expected_prec(beta_state, p_dim), error = function(...) rep(NA_real_, p_dim))

  shrink_intercept <- isTRUE(beta_state$shrink_intercept %||% beta_hypers$shrink_intercept %||% TRUE)
  active_beta <- qbeta_mean
  active_prec <- as.numeric(prec)
  if (!shrink_intercept && length(active_beta) >= 1L) {
    active_beta <- active_beta[-1L]
    active_prec <- active_prec[-1L]
  }

  eta_tau_bounds <- candidate_cfg$vb_args$beta_rhs$eta_bounds$tau %||% c(NA_real_, NA_real_)
  eta_tau_bounds <- as.numeric(unlist(eta_tau_bounds, use.names = FALSE))
  if (length(eta_tau_bounds) < 2L) {
    eta_tau_bounds <- c(NA_real_, NA_real_)
  }

  log_tau_last <- as.numeric(beta_state$eta_tau_hat %||% NA_real_)
  tau_last <- exp(log_tau_last)
  c2_last <- exp(as.numeric(beta_state$eta_c_hat %||% NA_real_))
  lambda_hat <- exp(as.numeric(beta_state$eta_lambda_hat %||% numeric(0)))
  beta_l2 <- sqrt(sum(active_beta^2, na.rm = TRUE))
  E_invV_med <- if (length(active_prec[is.finite(active_prec)])) {
    stats::median(active_prec[is.finite(active_prec)], na.rm = TRUE)
  } else {
    NA_real_
  }
  near_bound_flag <- is.finite(log_tau_last) && is.finite(eta_tau_bounds[[1L]]) &&
    abs(log_tau_last - eta_tau_bounds[[1L]]) < 1e-3
  collapse_flag <- isTRUE(near_bound_flag) &&
    isTRUE(is.finite(E_invV_med) && E_invV_med > 1e12) &&
    isTRUE(is.finite(beta_l2) && beta_l2 < 1e-6)

  data.table::data.table(
    quantile_p = as.numeric(p0),
    quantile_label = bench_qdesn_prob_label(p0),
    seed = as.integer(seed),
    beta_prior_type = beta_type,
    beta_ridge_tau2 = NA_real_,
    tau0 = as.numeric(beta_hypers$tau0 %||% NA_real_),
    nu = as.numeric(beta_hypers$nu %||% NA_real_),
    s_used = as.numeric(beta_hypers$s %||% NA_real_),
    s2_used = as.numeric(beta_hypers$s2 %||% NA_real_),
    init_log_tau = as.numeric(candidate_cfg$vb_args$beta_rhs$init_log_tau %||% NA_real_),
    eta_tau_lower_bound = as.numeric(eta_tau_bounds[[1L]]),
    eta_tau_upper_bound = as.numeric(eta_tau_bounds[[2L]]),
    tau_last = tau_last,
    log_tau_last = log_tau_last,
    c2_last = c2_last,
    lambda_med = if (length(lambda_hat)) stats::median(lambda_hat, na.rm = TRUE) else NA_real_,
    lambda_min = if (length(lambda_hat)) min(lambda_hat, na.rm = TRUE) else NA_real_,
    lambda_max = if (length(lambda_hat)) max(lambda_hat, na.rm = TRUE) else NA_real_,
    E_invV_med_last = E_invV_med,
    beta_l2_last = beta_l2,
    near_bound_flag = as.logical(near_bound_flag),
    collapse_flag = as.logical(collapse_flag)
  )
}

bench_qdesn_rhs_summary_row <- function(rhs_diagnostics) {
  dt <- data.table::as.data.table(rhs_diagnostics)
  rhs_dt <- dt[beta_prior_type %chin% c("rhs", "rhs_ns")]
  if (!nrow(rhs_dt)) {
    return(list(
      rhs_quantile_rows = 0L,
      rhs_collapse_n = 0L,
      rhs_near_bound_n = 0L,
      rhs_tau_last_min = NA_real_,
      rhs_tau_last_median = NA_real_,
      rhs_E_invV_med_max = NA_real_,
      rhs_beta_l2_min = NA_real_
    ))
  }

  list(
    rhs_quantile_rows = as.integer(nrow(rhs_dt)),
    rhs_collapse_n = as.integer(sum(rhs_dt$collapse_flag, na.rm = TRUE)),
    rhs_near_bound_n = as.integer(sum(rhs_dt$near_bound_flag, na.rm = TRUE)),
    rhs_tau_last_min = min(rhs_dt$tau_last, na.rm = TRUE),
    rhs_tau_last_median = stats::median(rhs_dt$tau_last, na.rm = TRUE),
    rhs_E_invV_med_max = max(rhs_dt$E_invV_med_last, na.rm = TRUE),
    rhs_beta_l2_min = min(rhs_dt$beta_l2_last, na.rm = TRUE)
  )
}

bench_qdesn_apply_selection_guards <- function(summary_dt, cfg) {
  summary_dt <- data.table::as.data.table(summary_dt)
  if (!nrow(summary_dt)) {
    return(summary_dt)
  }

  guard <- cfg$evaluation$selection$quantile_guard %||% list()
  enabled <- isTRUE(guard$enabled %||% TRUE)
  summary_dt[, eligible := TRUE]
  summary_dt[, eligibility_reason := NA_character_]
  if (!enabled) {
    return(summary_dt)
  }

  max_cov <- as.numeric(guard$max_abs_coverage_dev %||% 0.35)
  max_tail_cov <- as.numeric(guard$max_abs_tail_coverage_dev %||% 0.35)
  max_pit_dev <- as.numeric(guard$max_abs_pit_dev_mean %||% 0.35)
  max_shoulder_pinball_ratio <- as.numeric(guard$max_shoulder_pinball_ratio %||% Inf)
  max_shoulder_qhat_ratio <- as.numeric(guard$max_shoulder_qhat_ratio %||% Inf)
  forbid_rhs_collapse <- isTRUE(guard$forbid_rhs_collapse %||% TRUE)
  forbid_rhs_near_bound <- isTRUE(guard$forbid_rhs_near_bound %||% TRUE)
  relax_if_no_eligible <- isTRUE(guard$relax_if_no_eligible_candidates %||% FALSE)

  for (i in seq_len(nrow(summary_dt))) {
    reasons <- character(0)
    row <- summary_dt[i]
    if (is.finite(max_cov) && is.finite(row$max_abs_quantile_coverage_dev[[1L]]) &&
        row$max_abs_quantile_coverage_dev[[1L]] > max_cov) {
      reasons <- c(reasons, "coverage_dev")
    }
    if (is.finite(max_tail_cov) && is.finite(row$tail_abs_quantile_coverage_dev_max[[1L]]) &&
        row$tail_abs_quantile_coverage_dev_max[[1L]] > max_tail_cov) {
      reasons <- c(reasons, "tail_coverage_dev")
    }
    if (is.finite(max_pit_dev) && is.finite(row$max_abs_pit_dev_mean[[1L]]) &&
        row$max_abs_pit_dev_mean[[1L]] > max_pit_dev) {
      reasons <- c(reasons, "pit_dev")
    }
    if (is.finite(max_shoulder_pinball_ratio) && is.finite(row$shoulder_pinball_ratio[[1L]]) &&
        row$shoulder_pinball_ratio[[1L]] > max_shoulder_pinball_ratio) {
      reasons <- c(reasons, "shoulder_pinball_explosion")
    }
    if (is.finite(max_shoulder_qhat_ratio) && is.finite(row$shoulder_qhat_ratio[[1L]]) &&
        row$shoulder_qhat_ratio[[1L]] > max_shoulder_qhat_ratio) {
      reasons <- c(reasons, "shoulder_qhat_explosion")
    }
    if (forbid_rhs_collapse && is.finite(row$rhs_collapse_n[[1L]]) && row$rhs_collapse_n[[1L]] > 0L) {
      reasons <- c(reasons, "rhs_collapse")
    }
    if (forbid_rhs_near_bound && is.finite(row$rhs_near_bound_n[[1L]]) && row$rhs_near_bound_n[[1L]] > 0L) {
      reasons <- c(reasons, "rhs_near_bound")
    }

    if (length(reasons)) {
      summary_dt$eligible[[i]] <- FALSE
      summary_dt$eligibility_reason[[i]] <- paste(reasons, collapse = "|")
    }
  }

  if (!any(summary_dt$eligible %in% TRUE) && isTRUE(relax_if_no_eligible)) {
    summary_dt[, eligible := TRUE]
    summary_dt[, eligibility_reason := "guard_relaxed_no_eligible_candidates"]
  }

  summary_dt
}
