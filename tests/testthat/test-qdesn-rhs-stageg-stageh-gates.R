test_that("Stage-G gate evaluation is vectorized across profiles", {
  stageg_df <- data.frame(
    profile_id = c("G0_baseline", "G1_transformed_block_only", "G2_bad_fail"),
    pair_signoff_grade = c("WARN", "WARN", "FAIL"),
    pair_comparison_eligible = c(TRUE, FALSE, TRUE),
    both_finite_ok = c(TRUE, TRUE, FALSE),
    both_domain_ok = c(TRUE, TRUE, TRUE),
    mcmc_max_geweke_absz_rhs = c(1.70, 1.20, 1.10),
    mcmc_max_half_drift_rhs = c(0.27, 0.20, 0.30),
    stringsAsFactors = FALSE
  )

  gate_cfg <- list(
    require_zero_fail = TRUE,
    require_eligible_true = TRUE,
    require_non_degraded_finite_domain = TRUE,
    require_improved_geweke_half_drift = TRUE,
    min_geweke_improve = 0.05,
    min_half_drift_improve = 0.02
  )

  out <- exdqlm:::.qdesn_rhs_stageg_gate_eval(stageg_df, baseline_profile_id = "G0_baseline", gate_cfg = gate_cfg)

  expect_equal(out$gate_eligible_true, c(TRUE, FALSE, TRUE))
  expect_equal(out$gate_non_degraded_finite_domain, c(TRUE, TRUE, FALSE))
  expect_equal(out$gate_zero_fail, c(TRUE, TRUE, FALSE))
  expect_equal(out$gate_improved_geweke_half_drift, c(FALSE, TRUE, FALSE))
  expect_equal(out$gate_pass, c(FALSE, FALSE, FALSE))
})

test_that("Stage-G gate toggles behave correctly when constraints are disabled", {
  stageg_df <- data.frame(
    profile_id = c("G0_baseline", "G1_candidate", "G2_fail"),
    pair_signoff_grade = c("WARN", "WARN", "FAIL"),
    pair_comparison_eligible = c(TRUE, FALSE, FALSE),
    both_finite_ok = c(TRUE, FALSE, FALSE),
    both_domain_ok = c(TRUE, FALSE, FALSE),
    mcmc_max_geweke_absz_rhs = c(1.0, 1.2, 1.5),
    mcmc_max_half_drift_rhs = c(0.25, 0.22, 0.40),
    stringsAsFactors = FALSE
  )

  gate_cfg <- list(
    require_zero_fail = TRUE,
    require_eligible_true = FALSE,
    require_non_degraded_finite_domain = FALSE,
    require_improved_geweke_half_drift = FALSE
  )

  out <- exdqlm:::.qdesn_rhs_stageg_gate_eval(stageg_df, baseline_profile_id = "G0_baseline", gate_cfg = gate_cfg)

  expect_equal(out$gate_non_degraded_finite_domain, c(TRUE, TRUE, TRUE))
  expect_equal(out$gate_pass, c(TRUE, TRUE, FALSE))
})
