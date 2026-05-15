.qdesn_rhs_stageg_gate_eval <- function(stageg_df, baseline_profile_id, gate_cfg = list()) {
  if (!is.data.frame(stageg_df) || !nrow(stageg_df)) {
    stop("stageg_df must be a non-empty data.frame.", call. = FALSE)
  }
  baseline <- stageg_df[as.character(stageg_df$profile_id) == as.character(baseline_profile_id), , drop = FALSE]
  if (!nrow(baseline)) {
    stop(sprintf("Baseline profile '%s' not found in Stage-G results.", baseline_profile_id), call. = FALSE)
  }
  b <- baseline[1L, , drop = FALSE]

  req_zero_fail <- isTRUE(gate_cfg$require_zero_fail %||% TRUE)
  req_eligible <- isTRUE(gate_cfg$require_eligible_true %||% TRUE)
  req_non_deg <- isTRUE(gate_cfg$require_non_degraded_finite_domain %||% TRUE)
  req_improve <- isTRUE(gate_cfg$require_improved_geweke_half_drift %||% TRUE)

  min_g <- as.numeric(gate_cfg$min_geweke_improve %||% 0.0)[1L]
  min_h <- as.numeric(gate_cfg$min_half_drift_improve %||% 0.0)[1L]
  fb_g <- as.numeric(gate_cfg$fallback_geweke_cap %||% 3.0)[1L]
  fb_h <- as.numeric(gate_cfg$fallback_half_drift_cap %||% 0.50)[1L]

  out <- stageg_df
  out$gate_zero_fail <- !(toupper(as.character(out$pair_signoff_grade)) == "FAIL")
  out$gate_eligible_true <- as.logical(out$pair_comparison_eligible %||% rep(FALSE, nrow(out)))

  if (isTRUE(req_non_deg)) {
    baseline_finite <- isTRUE(as.logical(b$both_finite_ok[1L]))
    baseline_domain <- isTRUE(as.logical(b$both_domain_ok[1L]))
    out$gate_non_degraded_finite_domain <- ((!baseline_finite) | as.logical(out$both_finite_ok)) &
      ((!baseline_domain) | as.logical(out$both_domain_ok))
  } else {
    out$gate_non_degraded_finite_domain <- rep(TRUE, nrow(out))
  }

  out$gate_improved_geweke_half_drift <- vapply(seq_len(nrow(out)), function(i) {
    gi <- as.numeric(out$mcmc_max_geweke_absz_rhs[i])
    hi <- as.numeric(out$mcmc_max_half_drift_rhs[i])
    gb <- as.numeric(b$mcmc_max_geweke_absz_rhs[1L])
    hb <- as.numeric(b$mcmc_max_half_drift_rhs[1L])
    g_ok <- if (is.finite(gi) && is.finite(gb)) gi <= (gb - min_g) else if (is.finite(gi)) gi <= fb_g else FALSE
    h_ok <- if (is.finite(hi) && is.finite(hb)) hi <= (hb - min_h) else if (is.finite(hi)) hi <= fb_h else FALSE
    isTRUE(g_ok) && isTRUE(h_ok)
  }, logical(1))

  out$gate_pass <- rep(TRUE, nrow(out))
  if (isTRUE(req_zero_fail)) out$gate_pass <- out$gate_pass & out$gate_zero_fail
  if (isTRUE(req_eligible)) out$gate_pass <- out$gate_pass & out$gate_eligible_true
  if (isTRUE(req_non_deg)) out$gate_pass <- out$gate_pass & out$gate_non_degraded_finite_domain
  if (isTRUE(req_improve)) out$gate_pass <- out$gate_pass & out$gate_improved_geweke_half_drift

  out
}
