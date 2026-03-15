test_that("rhs repair candidate assessment chooses representative when rhs broadening improves", {
  tmp <- withr::local_tempdir()
  base_root <- file.path(tmp, "baseline")
  cand_root <- file.path(tmp, "candidate")
  out_root <- file.path(tmp, "decision")
  dir.create(file.path(base_root, "tables"), recursive = TRUE)
  dir.create(file.path(cand_root, "tables"), recursive = TRUE)

  pair_base <- data.frame(
    scenario = c("a", "a", "a", "a"),
    tau = c(0.25, 0.50, 0.25, 0.50),
    beta_prior_type = c("rhs", "rhs", "ridge", "ridge"),
    reservoir_profile = "tiny_d1_n8",
    pair_comparison_eligible_rate = c(0.0, 0.5, 0.8, 1.0),
    stringsAsFactors = FALSE
  )
  pair_cand <- pair_base
  pair_cand$pair_comparison_eligible_rate[pair_cand$beta_prior_type == "rhs" & pair_cand$tau == 0.25] <- 0.5
  pair_cand$pair_comparison_eligible_rate[pair_cand$beta_prior_type == "rhs" & pair_cand$tau == 0.50] <- 1.0

  meth_base <- data.frame(
    scenario = c("a", "a"),
    tau = c(0.25, 0.50),
    beta_prior_type = c("rhs", "rhs"),
    reservoir_profile = "tiny_d1_n8",
    method = "mcmc",
    n_signoff_fail = c(2L, 1L),
    stringsAsFactors = FALSE
  )
  meth_cand <- meth_base
  meth_cand$n_signoff_fail <- c(1L, 0L)

  utils::write.csv(pair_base, file.path(base_root, "tables", "campaign_pair_group_summary.csv"), row.names = FALSE)
  utils::write.csv(pair_cand, file.path(cand_root, "tables", "campaign_pair_group_summary.csv"), row.names = FALSE)
  utils::write.csv(meth_base, file.path(base_root, "tables", "campaign_method_group_summary.csv"), row.names = FALSE)
  utils::write.csv(meth_cand, file.path(cand_root, "tables", "campaign_method_group_summary.csv"), row.names = FALSE)

  res <- exdqlm:::qdesn_validation_assess_rhs_repair_candidate(cand_root, base_root, out_root)
  expect_identical(res$decision_mode, "representative")
})

test_that("rhs repair candidate assessment falls back to candidate_failures when rhs remains weak", {
  tmp <- withr::local_tempdir()
  base_root <- file.path(tmp, "baseline")
  cand_root <- file.path(tmp, "candidate")
  out_root <- file.path(tmp, "decision")
  dir.create(file.path(base_root, "tables"), recursive = TRUE)
  dir.create(file.path(cand_root, "tables"), recursive = TRUE)

  pair_base <- data.frame(
    scenario = c("a", "a"),
    tau = c(0.25, 0.25),
    beta_prior_type = c("rhs", "ridge"),
    reservoir_profile = "tiny_d1_n8",
    pair_comparison_eligible_rate = c(0.5, 1.0),
    stringsAsFactors = FALSE
  )
  pair_cand <- pair_base
  pair_cand$pair_comparison_eligible_rate[pair_cand$beta_prior_type == "rhs"] <- 0.0
  meth_base <- data.frame(
    scenario = "a",
    tau = 0.25,
    beta_prior_type = "rhs",
    reservoir_profile = "tiny_d1_n8",
    method = "mcmc",
    n_signoff_fail = 0L,
    stringsAsFactors = FALSE
  )
  meth_cand <- meth_base
  meth_cand$n_signoff_fail <- 2L

  utils::write.csv(pair_base, file.path(base_root, "tables", "campaign_pair_group_summary.csv"), row.names = FALSE)
  utils::write.csv(pair_cand, file.path(cand_root, "tables", "campaign_pair_group_summary.csv"), row.names = FALSE)
  utils::write.csv(meth_base, file.path(base_root, "tables", "campaign_method_group_summary.csv"), row.names = FALSE)
  utils::write.csv(meth_cand, file.path(cand_root, "tables", "campaign_method_group_summary.csv"), row.names = FALSE)

  res <- exdqlm:::qdesn_validation_assess_rhs_repair_candidate(cand_root, base_root, out_root)
  expect_identical(res$decision_mode, "candidate_failures")
})

test_that("failed rhs grid extraction writes rhs fails from candidate progress", {
  tmp <- withr::local_tempdir()
  cand_root <- file.path(tmp, "candidate")
  dir.create(file.path(cand_root, "tables"), recursive = TRUE)
  progress <- data.frame(
    scenario = c("const_small", "sin_asym_small", "toy_sine_small"),
    tau = c(0.25, 0.25, 0.50),
    beta_prior_type = c("rhs", "rhs", "ridge"),
    seed = c(123L, 123L, 123L),
    reservoir_profile = "tiny_d1_n8",
    mcmc_signoff_grade = c("FAIL", "WARN", "FAIL"),
    stringsAsFactors = FALSE
  )
  utils::write.csv(progress, file.path(cand_root, "tables", "campaign_progress.csv"), row.names = FALSE)
  out_grid <- file.path(tmp, "failed_rhs.csv")
  exdqlm:::qdesn_validation_extract_failed_rhs_grid(cand_root, out_grid)
  got <- utils::read.csv(out_grid, stringsAsFactors = FALSE)
  expect_equal(nrow(got), 1L)
  expect_identical(got$scenario[[1L]], "const_small")
  expect_identical(got$beta_prior_type[[1L]], "rhs")
})

test_that("split rhat helper distinguishes stable and unstable chains", {
  stable <- list(rnorm(200, mean = 0), rnorm(200, mean = 0.02), rnorm(200, mean = -0.01))
  unstable <- list(rnorm(200, mean = 0), rnorm(200, mean = 1.5), rnorm(200, mean = -1.5))
  rhat_stable <- exdqlm:::.qdesn_validation_safe_rhat(stable, split = TRUE)
  rhat_unstable <- exdqlm:::.qdesn_validation_safe_rhat(unstable, split = TRUE)
  expect_true(is.finite(rhat_stable))
  expect_true(is.finite(rhat_unstable))
  expect_lt(rhat_stable, 1.10)
  expect_gt(rhat_unstable, rhat_stable)
})
