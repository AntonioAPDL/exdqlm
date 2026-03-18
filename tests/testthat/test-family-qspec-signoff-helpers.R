test_that("family-qspec signoff helpers classify diagnostics consistently", {
  repo_root <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
  helper_path <- file.path(repo_root, "tools", "merge_reports", "20260314_family_qspec_signoff_common.R")
  skip_if_not(file.exists(helper_path), "family-qspec signoff helper unavailable")
  source(helper_path)

  acf1 <- fqsg_safe_acf1(seq_len(50))
  expect_true(is.finite(acf1))
  expect_true(abs(acf1) <= 1)

  expect_equal(fqsg_halfchain_drift(rep(1, 20)), 0)
  expect_true(is.finite(fqsg_halfchain_drift(c(rep(0, 10), rep(3, 10)))))

  tail <- fqsg_trace_tail_metrics(c(1, 1.01, 1.02, 1.03, 1.04), tail_window = 5L)
  expect_equal(tail$n_total, 5L)
  expect_equal(tail$n_tail, 5L)
  expect_true(tail$rel_range > 0)
  expect_true(tail$rel_step_max > 0)

  theta_arr <- array(seq_len(2 * 3 * 4), dim = c(2, 3, 4))
  theta_norm <- fqsg_iteration_norm(theta_arr)
  expect_equal(length(theta_norm), 4L)
  expect_true(all(is.finite(theta_norm)))

  expect_identical(fqsg_pair_grade("PASS", "PASS"), "PASS")
  expect_identical(fqsg_pair_grade("PASS", "WARN"), "WARN")
  expect_identical(fqsg_pair_grade("WARN", "WARN"), "WARN")
  expect_identical(fqsg_pair_grade("PASS", "FAIL"), "FAIL")

  cfg <- fqsg_signoff_cfg()
  expect_true(cfg$vb$tail_window >= 2L)
  expect_true(cfg$mcmc$min_keep_pass >= cfg$mcmc$min_keep_warn)

  old_env <- Sys.getenv(
    c(
      "EXDQLM_FQSG_MCMC_ESS_SIGMA_WARN",
      "EXDQLM_FQSG_MCMC_ACF1_WARN",
      "EXDQLM_FQSG_MCMC_GEWEKE_ABSZ_WARN",
      "EXDQLM_FQSG_MCMC_HALF_DRIFT_WARN"
    ),
    unset = NA_character_
  )
  on.exit({
    for (nm in names(old_env)) {
      val <- old_env[[nm]]
      if (is.na(val)) {
        Sys.unsetenv(nm)
      } else {
        do.call(Sys.setenv, stats::setNames(list(val), nm))
      }
    }
  }, add = TRUE)
  Sys.setenv(
    EXDQLM_FQSG_MCMC_ESS_SIGMA_WARN = "5",
    EXDQLM_FQSG_MCMC_ACF1_WARN = "0.995",
    EXDQLM_FQSG_MCMC_GEWEKE_ABSZ_WARN = "5.0",
    EXDQLM_FQSG_MCMC_HALF_DRIFT_WARN = "0.75"
  )
  cfg_override <- fqsg_signoff_cfg()
  expect_equal(cfg_override$mcmc$ess_sigma_warn, 5)
  expect_equal(cfg_override$mcmc$acf1_warn, 0.995)
  expect_equal(cfg_override$mcmc$geweke_absz_warn, 5.0)
  expect_equal(cfg_override$mcmc$half_drift_warn, 0.75)
})
