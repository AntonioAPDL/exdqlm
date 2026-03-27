`%||%` <- function(a, b) if (is.null(a)) b else a

.qdesn_rhs_campaign_strict_gate <- function(pair_df, cfg = list()) {
  if (!is.data.frame(pair_df)) {
    stop("pair_df must be a data.frame.", call. = FALSE)
  }

  require_zero_fail <- isTRUE(cfg$require_zero_fail %||% TRUE)
  require_all_eligible <- isTRUE(cfg$require_all_eligible %||% TRUE)
  require_all_finite_domain <- isTRUE(cfg$require_all_finite_domain %||% TRUE)
  require_zero_trace_unavailable <- isTRUE(cfg$require_zero_trace_unavailable %||% FALSE)

  n_pairs <- nrow(pair_df)
  n_pair_fail <- if (n_pairs) sum(toupper(as.character(pair_df$pair_signoff_grade %||% "")) == "FAIL", na.rm = TRUE) else 0L
  n_pair_eligible <- if (n_pairs) sum(as.logical(pair_df$pair_comparison_eligible %||% FALSE), na.rm = TRUE) else 0L
  all_finite_ok <- if (n_pairs) all(as.logical(pair_df$both_finite_ok %||% FALSE), na.rm = TRUE) else FALSE
  all_domain_ok <- if (n_pairs) all(as.logical(pair_df$both_domain_ok %||% FALSE), na.rm = TRUE) else FALSE
  all_finite_domain_ok <- isTRUE(all_finite_ok) && isTRUE(all_domain_ok)

  trace_signoff <- if (n_pairs) {
    sum(grepl("rhs_trace_unavailable", as.character(pair_df$mcmc_signoff_reason %||% ""), fixed = TRUE), na.rm = TRUE)
  } else {
    0L
  }
  trace_unhealthy <- if (n_pairs) {
    sum(grepl("rhs_trace_unavailable", as.character(pair_df$mcmc_unhealthy_reason %||% ""), fixed = TRUE), na.rm = TRUE)
  } else {
    0L
  }
  n_trace_unavailable_total <- trace_signoff + trace_unhealthy

  pass_zero_fail <- !isTRUE(require_zero_fail) || (n_pair_fail == 0L)
  pass_all_eligible <- !isTRUE(require_all_eligible) || (n_pairs > 0L && n_pair_eligible == n_pairs)
  pass_finite_domain <- !isTRUE(require_all_finite_domain) || isTRUE(all_finite_domain_ok)
  pass_trace <- !isTRUE(require_zero_trace_unavailable) || (n_trace_unavailable_total == 0L)

  pass <- isTRUE(pass_zero_fail) && isTRUE(pass_all_eligible) && isTRUE(pass_finite_domain) && isTRUE(pass_trace)

  list(
    pass = isTRUE(pass),
    n_pairs = n_pairs,
    n_pair_fail = n_pair_fail,
    n_pair_eligible = n_pair_eligible,
    all_finite_ok = isTRUE(all_finite_ok),
    all_domain_ok = isTRUE(all_domain_ok),
    all_finite_domain_ok = isTRUE(all_finite_domain_ok),
    n_trace_unavailable_total = n_trace_unavailable_total,
    pass_zero_fail = isTRUE(pass_zero_fail),
    pass_all_eligible = isTRUE(pass_all_eligible),
    pass_finite_domain = isTRUE(pass_finite_domain),
    pass_trace = isTRUE(pass_trace),
    require_zero_fail = isTRUE(require_zero_fail),
    require_all_eligible = isTRUE(require_all_eligible),
    require_all_finite_domain = isTRUE(require_all_finite_domain),
    require_zero_trace_unavailable = isTRUE(require_zero_trace_unavailable)
  )
}
