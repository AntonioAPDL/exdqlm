test_that("Stage-J/K strict gate passes only when all strict constraints hold", {
  pair_df <- data.frame(
    pair_signoff_grade = c("WARN", "WARN"),
    pair_comparison_eligible = c(TRUE, TRUE),
    both_finite_ok = c(TRUE, TRUE),
    both_domain_ok = c(TRUE, TRUE),
    mcmc_signoff_reason = c("chain_marginal_but_usable", "chain_marginal_but_usable"),
    mcmc_unhealthy_reason = c(NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )

  gate <- exdqlm:::.qdesn_rhs_campaign_strict_gate(
    pair_df,
    cfg = list(
      require_zero_fail = TRUE,
      require_all_eligible = TRUE,
      require_all_finite_domain = TRUE,
      require_zero_trace_unavailable = TRUE
    )
  )
  expect_true(isTRUE(gate$pass))
  expect_equal(gate$n_pair_fail, 0L)
  expect_equal(gate$n_pair_eligible, 2L)
})

test_that("Stage-J/K strict gate catches fail, ineligible, and trace-unavailable", {
  pair_df <- data.frame(
    pair_signoff_grade = c("FAIL", "WARN"),
    pair_comparison_eligible = c(FALSE, TRUE),
    both_finite_ok = c(TRUE, TRUE),
    both_domain_ok = c(TRUE, TRUE),
    mcmc_signoff_reason = c("geweke_drift", "rhs_trace_unavailable"),
    mcmc_unhealthy_reason = c(NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )

  gate <- exdqlm:::.qdesn_rhs_campaign_strict_gate(
    pair_df,
    cfg = list(
      require_zero_fail = TRUE,
      require_all_eligible = TRUE,
      require_all_finite_domain = TRUE,
      require_zero_trace_unavailable = TRUE
    )
  )
  expect_false(isTRUE(gate$pass))
  expect_false(isTRUE(gate$pass_zero_fail))
  expect_false(isTRUE(gate$pass_all_eligible))
  expect_false(isTRUE(gate$pass_trace))
})
