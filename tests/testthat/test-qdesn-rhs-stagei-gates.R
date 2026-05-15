test_that("Stage-I gate marks strict pass only for healthy fully eligible profiles", {
  df <- data.frame(
    profile_id = c("P1_baseline", "P1_candidate_good", "P1_bad_fail"),
    n_pairs = c(3, 3, 3),
    n_pair_fail = c(1, 0, 2),
    n_pair_eligible = c(2, 3, 1),
    all_finite_domain_ok = c(TRUE, TRUE, FALSE),
    mcmc_signoff_fail = c(1, 0, 2),
    n_trace_unavailable_total = c(0, 0, 1),
    mcmc_max_geweke_absz_rhs_max = c(2.8, 1.9, 4.1),
    mcmc_max_half_drift_rhs_max = c(0.48, 0.22, 0.71),
    stringsAsFactors = FALSE
  )

  out <- exdqlm:::.qdesn_rhs_stagei_gate_eval(
    profile_df = df,
    gate_cfg = list(
      require_zero_fail = TRUE,
      require_all_eligible = TRUE,
      require_all_finite_domain = TRUE,
      require_zero_trace_unavailable = TRUE,
      require_improved_vs_baseline = FALSE
    ),
    baseline_profile_id = "P1_baseline"
  )

  expect_equal(out$gate_pass, c(FALSE, TRUE, FALSE))
})

test_that("Stage-I improvement gate requires better Geweke and half-drift than baseline", {
  df <- data.frame(
    profile_id = c("P2_baseline_from_phase1", "P2_improved", "P2_worse"),
    n_pairs = c(3, 3, 3),
    n_pair_fail = c(0, 0, 0),
    n_pair_eligible = c(3, 3, 3),
    all_finite_domain_ok = c(TRUE, TRUE, TRUE),
    mcmc_signoff_fail = c(0, 0, 0),
    n_trace_unavailable_total = c(0, 0, 0),
    mcmc_max_geweke_absz_rhs_max = c(2.6, 2.3, 2.5),
    mcmc_max_half_drift_rhs_max = c(0.45, 0.35, 0.44),
    stringsAsFactors = FALSE
  )

  out <- exdqlm:::.qdesn_rhs_stagei_gate_eval(
    profile_df = df,
    gate_cfg = list(
      require_zero_fail = TRUE,
      require_all_eligible = TRUE,
      require_all_finite_domain = TRUE,
      require_zero_trace_unavailable = TRUE,
      require_improved_vs_baseline = TRUE,
      min_geweke_improve = 0.05,
      min_half_drift_improve = 0.02,
      fallback_geweke_cap = 3.0,
      fallback_half_drift_cap = 0.5
    ),
    baseline_profile_id = "P2_baseline_from_phase1"
  )

  expect_equal(out$gate_improved_vs_baseline, c(FALSE, TRUE, FALSE))
  expect_equal(out$gate_pass, c(FALSE, TRUE, FALSE))
})
