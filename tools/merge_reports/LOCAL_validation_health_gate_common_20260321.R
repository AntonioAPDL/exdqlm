#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (is.null(x)) y else x

vhg_env_num <- function(name, default) {
  raw <- Sys.getenv(name, unset = NA_character_)
  val <- suppressWarnings(as.numeric(raw)[1])
  if (!is.finite(val)) default else val
}

vhg_signoff_cfg <- function() {
  list(
    ess_per1k_warn = vhg_env_num("EXDQLM_FQSG_MCMC_ESS_SIGMA_WARN", 5),
    ess_per1k_pass = vhg_env_num("EXDQLM_FQSG_MCMC_ESS_SIGMA_PASS", 10),
    acf1_warn = vhg_env_num("EXDQLM_FQSG_MCMC_ACF1_WARN", 0.995),
    acf1_pass = vhg_env_num("EXDQLM_FQSG_MCMC_ACF1_PASS", 0.98),
    geweke_absz_warn = vhg_env_num("EXDQLM_FQSG_MCMC_GEWEKE_ABSZ_WARN", 5),
    geweke_absz_pass = vhg_env_num("EXDQLM_FQSG_MCMC_GEWEKE_ABSZ_PASS", 2.5),
    half_drift_warn = vhg_env_num("EXDQLM_FQSG_MCMC_HALF_DRIFT_WARN", 0.75),
    half_drift_pass = vhg_env_num("EXDQLM_FQSG_MCMC_HALF_DRIFT_PASS", 0.5)
  )
}

vhg_safe_ess <- function(x) {
  x <- as.numeric(x)
  if (length(x) < 10L || any(!is.finite(x))) return(NA_real_)
  tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(x))), error = function(e) NA_real_)
}

vhg_safe_acf1 <- function(x) {
  x <- as.numeric(x)
  if (length(x) < 10L || any(!is.finite(x))) return(NA_real_)
  ac <- tryCatch(stats::acf(x, lag.max = 1L, plot = FALSE)$acf, error = function(e) NULL)
  if (is.null(ac) || length(ac) < 2L) return(NA_real_)
  as.numeric(ac[2L])
}

vhg_safe_geweke_absz <- function(x) {
  x <- as.numeric(x)
  if (length(x) < 20L || any(!is.finite(x))) return(NA_real_)
  gz <- tryCatch(coda::geweke.diag(coda::as.mcmc(x))$z, error = function(e) NA_real_)
  as.numeric(abs(gz[1]))
}

vhg_safe_half_drift <- function(x) {
  x <- as.numeric(x)
  n <- length(x)
  if (n < 20L || any(!is.finite(x))) return(NA_real_)
  i <- floor(n / 2)
  if (i < 5L || (n - i) < 5L) return(NA_real_)
  s <- stats::sd(x)
  if (!is.finite(s) || s <= 0) return(NA_real_)
  as.numeric(abs(mean(x[(i + 1L):n]) - mean(x[1L:i])) / s)
}

vhg_extract_rhs_collapse <- function(fit) {
  probes <- list(
    beta_prior_summary = fit$beta_prior$summary$collapse_flag,
    rhs_diag_summary = fit$rhs.diagnostics$summary$collapse_flag,
    diagnostics_rhs_summary = fit$diagnostics$rhs$summary$collapse_flag,
    diagnostics_rhs_flag = fit$diagnostics$rhs$collapse_flag,
    diagnostics_rhs_trace_last = {
      tr <- fit$diagnostics$rhs$trace
      if (is.data.frame(tr) && nrow(tr) > 0L && "rhs_collapse_flag" %in% names(tr)) {
        tr$rhs_collapse_flag[nrow(tr)]
      } else {
        NA
      }
    }
  )
  probe_vals <- vapply(probes, function(x) {
    if (is.null(x) || length(x) == 0L) return(NA)
    as.logical(x[1])
  }, logical(1))

  flagged <- names(probe_vals)[which(isTRUE(probe_vals))]
  list(
    collapse_flag = length(flagged) > 0L,
    collapse_sources = if (length(flagged)) paste(flagged, collapse = ";") else NA_character_,
    probe_values = probe_vals
  )
}

vhg_metric_grade <- function(value, pass_rule, warn_rule) {
  if (!is.finite(value)) return("FAIL")
  if (isTRUE(pass_rule(value))) return("PASS")
  if (isTRUE(warn_rule(value))) return("WARN")
  "FAIL"
}

vhg_pair_grade <- function(a, b) {
  vals <- c(a, b)
  vals <- vals[!is.na(vals)]
  if (!length(vals)) return("FAIL")
  if (any(vals == "FAIL")) return("FAIL")
  if (any(vals == "WARN")) return("WARN")
  "PASS"
}

vhg_collect_mcmc_metrics <- function(wrapped, case_id, variant, candidate_path = NA_character_) {
  fit <- wrapped$fit %||% wrapped
  sigma <- as.numeric(fit$samp.sigma)
  gamma <- as.numeric(fit$samp.gamma)
  has_gamma <- length(gamma) > 0L && any(is.finite(gamma))

  n_keep <- as.numeric(fit$n.mcmc %||% length(sigma))[1]
  ch_sigma <- fit$diagnostics$chain_health$sigma %||% NULL
  ch_gamma <- fit$diagnostics$chain_health$gamma %||% NULL

  ess_sigma <- as.numeric(ch_sigma$ess %||% vhg_safe_ess(sigma))[1]
  ess_gamma <- if (has_gamma) as.numeric(ch_gamma$ess %||% vhg_safe_ess(gamma))[1] else NA_real_
  ess_sigma_per1k <- as.numeric(ch_sigma$ess_per1k %||% NA_real_)[1]
  if (!is.finite(ess_sigma_per1k) && is.finite(ess_sigma) && is.finite(n_keep) && n_keep > 0) {
    ess_sigma_per1k <- ess_sigma / n_keep * 1000
  }
  ess_gamma_per1k <- as.numeric(ch_gamma$ess_per1k %||% NA_real_)[1]
  if (!is.finite(ess_gamma_per1k) && is.finite(ess_gamma) && is.finite(n_keep) && n_keep > 0) {
    ess_gamma_per1k <- ess_gamma / n_keep * 1000
  }
  acf1_sigma <- as.numeric(ch_sigma$acf1 %||% vhg_safe_acf1(sigma))[1]
  acf1_gamma <- if (has_gamma) as.numeric(ch_gamma$acf1 %||% vhg_safe_acf1(gamma))[1] else NA_real_
  geweke_sigma <- as.numeric(ch_sigma$geweke_absz %||% vhg_safe_geweke_absz(sigma))[1]
  geweke_gamma <- if (has_gamma) as.numeric(ch_gamma$geweke_absz %||% vhg_safe_geweke_absz(gamma))[1] else NA_real_
  half_drift_sigma <- as.numeric(ch_sigma$half_drift %||% vhg_safe_half_drift(sigma))[1]
  half_drift_gamma <- if (has_gamma) as.numeric(ch_gamma$half_drift %||% vhg_safe_half_drift(gamma))[1] else NA_real_

  rhs <- vhg_extract_rhs_collapse(fit)

  data.frame(
    case_id = case_id,
    variant = variant,
    mh_kernel = as.character(fit$mh.diagnostics$proposal %||% fit$mh.diagnostics$proposal_mode %||% NA),
    kernel_exact = as.logical(fit$mh.diagnostics$kernel_exact %||% NA),
    rhs_collapse_flag = rhs$collapse_flag,
    rhs_collapse_sources = rhs$collapse_sources,
    ess_sigma = ess_sigma,
    ess_gamma = ess_gamma,
    ess_sigma_per1k = ess_sigma_per1k,
    ess_gamma_per1k = ess_gamma_per1k,
    acf1_sigma = acf1_sigma,
    acf1_gamma = acf1_gamma,
    geweke_sigma = geweke_sigma,
    geweke_gamma = geweke_gamma,
    half_drift_sigma = half_drift_sigma,
    half_drift_gamma = half_drift_gamma,
    accept_keep = as.numeric(fit$mh.diagnostics$accept$keep %||% fit$accept.rate.keep %||% NA_real_)[1],
    n_burn = as.numeric(fit$n.burn %||% NA_real_)[1],
    n_mcmc = n_keep,
    run_time_sec = as.numeric(wrapped$meta$runtime_sec %||% fit$run.time %||% NA_real_)[1],
    candidate_path = candidate_path,
    stringsAsFactors = FALSE
  )
}

vhg_apply_health_gates <- function(metrics_row, cfg = vhg_signoff_cfg()) {
  row <- metrics_row

  g_ess_sigma <- vhg_metric_grade(
    row$ess_sigma_per1k,
    pass_rule = function(v) v >= cfg$ess_per1k_pass,
    warn_rule = function(v) v >= cfg$ess_per1k_warn
  )
  g_acf_sigma <- vhg_metric_grade(
    row$acf1_sigma,
    pass_rule = function(v) is.finite(v) && abs(v) <= cfg$acf1_pass,
    warn_rule = function(v) is.finite(v) && abs(v) <= cfg$acf1_warn
  )
  g_geweke_sigma <- vhg_metric_grade(
    row$geweke_sigma,
    pass_rule = function(v) v <= cfg$geweke_absz_pass,
    warn_rule = function(v) v <= cfg$geweke_absz_warn
  )
  g_drift_sigma <- vhg_metric_grade(
    row$half_drift_sigma,
    pass_rule = function(v) v <= cfg$half_drift_pass,
    warn_rule = function(v) v <= cfg$half_drift_warn
  )

  if (is.finite(row$ess_gamma_per1k) || is.finite(row$acf1_gamma) || is.finite(row$geweke_gamma) || is.finite(row$half_drift_gamma)) {
    g_ess_gamma <- vhg_metric_grade(
      row$ess_gamma_per1k,
      pass_rule = function(v) v >= cfg$ess_per1k_pass,
      warn_rule = function(v) v >= cfg$ess_per1k_warn
    )
    g_acf_gamma <- vhg_metric_grade(
      row$acf1_gamma,
      pass_rule = function(v) is.finite(v) && abs(v) <= cfg$acf1_pass,
      warn_rule = function(v) is.finite(v) && abs(v) <= cfg$acf1_warn
    )
    g_geweke_gamma <- vhg_metric_grade(
      row$geweke_gamma,
      pass_rule = function(v) v <= cfg$geweke_absz_pass,
      warn_rule = function(v) v <= cfg$geweke_absz_warn
    )
    g_drift_gamma <- vhg_metric_grade(
      row$half_drift_gamma,
      pass_rule = function(v) v <= cfg$half_drift_pass,
      warn_rule = function(v) v <= cfg$half_drift_warn
    )
  } else {
    g_ess_gamma <- g_acf_gamma <- g_geweke_gamma <- g_drift_gamma <- NA_character_
  }

  grade_sigma <- vhg_pair_grade(vhg_pair_grade(g_ess_sigma, g_acf_sigma), vhg_pair_grade(g_geweke_sigma, g_drift_sigma))
  grade_gamma <- if (is.na(g_ess_gamma)) NA_character_ else {
    vhg_pair_grade(vhg_pair_grade(g_ess_gamma, g_acf_gamma), vhg_pair_grade(g_geweke_gamma, g_drift_gamma))
  }

  grade_overall <- if (isTRUE(row$rhs_collapse_flag)) {
    "FAIL"
  } else {
    vhg_pair_grade(grade_sigma, ifelse(is.na(grade_gamma), "PASS", grade_gamma))
  }

  unhealthy_reason <- if (isTRUE(row$rhs_collapse_flag)) {
    "rhs_collapse"
  } else if (identical(grade_overall, "FAIL")) {
    "gate_fail"
  } else {
    NA_character_
  }

  cbind(
    row,
    gate_ess_sigma = g_ess_sigma,
    gate_acf1_sigma = g_acf_sigma,
    gate_geweke_sigma = g_geweke_sigma,
    gate_half_drift_sigma = g_drift_sigma,
    gate_ess_gamma = g_ess_gamma,
    gate_acf1_gamma = g_acf_gamma,
    gate_geweke_gamma = g_geweke_gamma,
    gate_half_drift_gamma = g_drift_gamma,
    gate_sigma = grade_sigma,
    gate_gamma = grade_gamma,
    gate_overall = grade_overall,
    healthy = grade_overall %in% c("PASS", "WARN") && !isTRUE(row$rhs_collapse_flag),
    unhealthy_reason = unhealthy_reason,
    stringsAsFactors = FALSE
  )
}

vhg_append_checkpoint <- function(path, row_named_list) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  row_df <- as.data.frame(row_named_list, stringsAsFactors = FALSE)
  if (!file.exists(path)) {
    utils::write.csv(row_df, path, row.names = FALSE)
  } else {
    old <- tryCatch(utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
    if (is.null(old)) {
      utils::write.csv(row_df, path, row.names = FALSE)
    } else {
      all_cols <- union(names(old), names(row_df))
      for (nm in setdiff(all_cols, names(old))) old[[nm]] <- NA
      for (nm in setdiff(all_cols, names(row_df))) row_df[[nm]] <- NA
      old <- old[, all_cols, drop = FALSE]
      row_df <- row_df[, all_cols, drop = FALSE]
      utils::write.csv(rbind(old, row_df), path, row.names = FALSE)
    }
  }
}
