`%||%` <- function(a, b) if (is.null(a)) b else a

.qdesn_rhs_stagei_gate_eval <- function(profile_df, gate_cfg = list(), baseline_profile_id = NULL) {
  if (!is.data.frame(profile_df) || !nrow(profile_df)) {
    stop("profile_df must be a non-empty data.frame.", call. = FALSE)
  }

  out <- profile_df

  req_zero_fail <- isTRUE(gate_cfg$require_zero_fail %||% TRUE)
  req_all_eligible <- isTRUE(gate_cfg$require_all_eligible %||% TRUE)
  req_finite_domain <- isTRUE(gate_cfg$require_all_finite_domain %||% TRUE)
  req_zero_trace <- isTRUE(gate_cfg$require_zero_trace_unavailable %||% FALSE)
  req_improved <- isTRUE(gate_cfg$require_improved_vs_baseline %||% FALSE)

  out$gate_zero_fail <- (as.numeric(out$n_pair_fail %||% Inf) <= 0) &
    (as.numeric(out$mcmc_signoff_fail %||% Inf) <= 0)
  out$gate_all_eligible <- (as.numeric(out$n_pairs %||% 0) > 0) &
    (as.numeric(out$n_pair_eligible %||% -1) == as.numeric(out$n_pairs %||% 0))
  out$gate_finite_domain <- as.logical(out$all_finite_domain_ok %||% rep(FALSE, nrow(out)))
  out$gate_no_trace_unavailable <- as.numeric(out$n_trace_unavailable_total %||% 0) <= 0
  out$gate_improved_vs_baseline <- rep(TRUE, nrow(out))

  baseline_id <- as.character(baseline_profile_id %||% gate_cfg$baseline_profile_id %||% "")[1L]
  if (isTRUE(req_improved)) {
    if (!nzchar(baseline_id)) {
      stop("baseline_profile_id is required when require_improved_vs_baseline = TRUE.", call. = FALSE)
    }
    baseline <- out[as.character(out$profile_id) == baseline_id, , drop = FALSE]
    if (!nrow(baseline)) {
      stop(sprintf("Baseline profile '%s' not found in profile_df.", baseline_id), call. = FALSE)
    }
    b <- baseline[1L, , drop = FALSE]
    min_g <- as.numeric(gate_cfg$min_geweke_improve %||% 0.0)[1L]
    min_h <- as.numeric(gate_cfg$min_half_drift_improve %||% 0.0)[1L]
    fb_g <- as.numeric(gate_cfg$fallback_geweke_cap %||% 3.0)[1L]
    fb_h <- as.numeric(gate_cfg$fallback_half_drift_cap %||% 0.50)[1L]

    out$gate_improved_vs_baseline <- vapply(seq_len(nrow(out)), function(i) {
      if (identical(as.character(out$profile_id[i]), baseline_id)) {
        return(FALSE)
      }

      gi <- as.numeric(out$mcmc_max_geweke_absz_rhs_max[i])
      hi <- as.numeric(out$mcmc_max_half_drift_rhs_max[i])
      gb <- as.numeric(b$mcmc_max_geweke_absz_rhs_max[1L])
      hb <- as.numeric(b$mcmc_max_half_drift_rhs_max[1L])

      g_ok <- if (is.finite(gi) && is.finite(gb)) {
        gi <= (gb - min_g)
      } else if (is.finite(gi)) {
        gi <= fb_g
      } else {
        FALSE
      }
      h_ok <- if (is.finite(hi) && is.finite(hb)) {
        hi <= (hb - min_h)
      } else if (is.finite(hi)) {
        hi <= fb_h
      } else {
        FALSE
      }
      isTRUE(g_ok) && isTRUE(h_ok)
    }, logical(1))
  }

  out$gate_pass <- rep(TRUE, nrow(out))
  if (isTRUE(req_zero_fail)) out$gate_pass <- out$gate_pass & out$gate_zero_fail
  if (isTRUE(req_all_eligible)) out$gate_pass <- out$gate_pass & out$gate_all_eligible
  if (isTRUE(req_finite_domain)) out$gate_pass <- out$gate_pass & out$gate_finite_domain
  if (isTRUE(req_zero_trace)) out$gate_pass <- out$gate_pass & out$gate_no_trace_unavailable
  if (isTRUE(req_improved)) out$gate_pass <- out$gate_pass & out$gate_improved_vs_baseline

  out
}
