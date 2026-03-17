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

test_that("multichain campaign collection reads multichain root metadata cleanly", {
  tmp <- withr::local_tempdir()
  results_root <- file.path(tmp, "results")
  report_root <- file.path(tmp, "report")
  root_dir <- file.path(results_root, "roots", "scenario-a__tau-0p25__prior-rhs__seed-123__res-tiny")
  dir.create(file.path(root_dir, "manifest"), recursive = TRUE)
  dir.create(file.path(root_dir, "tables"), recursive = TRUE)

  exdqlm:::.qdesn_validation_write_json(file.path(root_dir, "manifest", "multichain_root_manifest.json"), list(
    root_spec = list(
      root_id = "scenario-a__tau-0p25__prior-rhs__seed-123__res-tiny",
      scenario = "a",
      tau = 0.25,
      beta_prior_type = "rhs",
      seed = 123L,
      reservoir_profile = "tiny"
    )
  ))

  utils::write.csv(data.frame(
    root_id = "scenario-a__tau-0p25__prior-rhs__seed-123__res-tiny",
    scenario = "a",
    tau = 0.25,
    beta_prior_type = "rhs",
    seed = 123L,
    reservoir_profile = "tiny",
    vb_signoff_grade = "PASS",
    n_chains = 4L,
    n_chain_pass = 4L,
    n_chain_warn = 0L,
    n_chain_fail = 0L,
    max_split_rhat = 1.02,
    confirmation_grade = "PASS",
    confirmation_reason = "acceptable_split_rhat",
    stringsAsFactors = FALSE
  ), file.path(root_dir, "tables", "root_confirmation.csv"), row.names = FALSE)

  utils::write.csv(data.frame(
    parameter = c("gamma", "rhs_tau"),
    n_chains = c(4L, 4L),
    min_chain_length = c(300L, 300L),
    rhat = c(1.01, 1.04),
    chain_mean_min = c(-0.1, 0.01),
    chain_mean_max = c(0.1, 0.02),
    chain_sd_min = c(0.2, 0.03),
    chain_sd_max = c(0.3, 0.04),
    stringsAsFactors = FALSE
  ), file.path(root_dir, "tables", "multichain_rhat_summary.csv"), row.names = FALSE)

  utils::write.csv(data.frame(
    chain_id = 1:4,
    mcmc_seed = 1:4,
    status = rep("SUCCESS", 4),
    signoff_grade = rep("PASS", 4),
    signoff_reason = rep("ok", 4),
    stringsAsFactors = FALSE
  ), file.path(root_dir, "tables", "chain_signoff.csv"), row.names = FALSE)

  collected <- exdqlm:::.qdesn_validation_collect_multichain_results(results_root)
  expect_equal(nrow(collected$root_confirmation), 1L)
  expect_equal(nrow(collected$rhat_summary), 2L)
  expect_equal(nrow(collected$chain_signoff), 4L)
  expect_true(all(collected$rhat_summary$root_id == "scenario-a__tau-0p25__prior-rhs__seed-123__res-tiny"))
  expect_true(all(collected$chain_signoff$scenario == "a"))

  exdqlm:::qdesn_validation_collect_multichain_campaign(results_root, report_root, create_plots = FALSE)
  campaign_root <- utils::read.csv(file.path(report_root, "tables", "campaign_root_confirmation.csv"), stringsAsFactors = FALSE)
  expect_equal(nrow(campaign_root), 1L)
})

test_that("multichain campaign rejects invalid output roots", {
  tmp <- withr::local_tempdir()
  grid <- data.frame(
    scenario = "toy_sine_small",
    tau = 0.25,
    beta_prior_type = "rhs",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8",
    enabled = TRUE,
    stringsAsFactors = FALSE
  )
  defaults <- exdqlm:::qdesn_validation_load_defaults(file.path("config", "validation", "qdesn_mcmc_compare_rhs_structural_defaults.yaml"))
  expect_error(
    exdqlm:::qdesn_validation_run_multichain_campaign(
      grid = grid,
      defaults = defaults,
      results_root = NA_character_,
      report_root = file.path(tmp, "report"),
      n_chains = 2L,
      create_plots = FALSE,
      verbose = FALSE
    ),
    "results_root and report_root must both be non-empty paths"
  )
})

test_that("multichain follow-up assessment chooses structural repair when failures remain", {
  tmp <- withr::local_tempdir()
  report_root <- file.path(tmp, "multichain")
  out_root <- file.path(tmp, "decision")
  dir.create(file.path(report_root, "tables"), recursive = TRUE)

  utils::write.csv(data.frame(
    root_id = c("r1", "r2", "r3"),
    scenario = c("toy", "const", "sin"),
    tau = c(0.25, 0.25, 0.50),
    beta_prior_type = c("rhs", "rhs", "rhs"),
    seed = c(1L, 1L, 1L),
    reservoir_profile = c("tiny", "tiny", "tiny"),
    confirmation_grade = c("FAIL", "WARN", "FAIL"),
    stringsAsFactors = FALSE
  ), file.path(report_root, "tables", "campaign_root_confirmation.csv"), row.names = FALSE)

  utils::write.csv(data.frame(
    root_id = rep(c("r1", "r2", "r3"), each = 2),
    scenario = rep(c("toy", "const", "sin"), each = 2),
    tau = rep(c(0.25, 0.25, 0.50), each = 2),
    beta_prior_type = "rhs",
    seed = 1L,
    reservoir_profile = "tiny",
    parameter = rep(c("gamma", "rhs_tau"), 3),
    rhat = c(1.03, 1.14, 1.02, 1.08, 1.05, 1.16),
    stringsAsFactors = FALSE
  ), file.path(report_root, "tables", "campaign_multichain_rhat.csv"), row.names = FALSE)

  res <- exdqlm:::qdesn_validation_assess_multichain_followup(report_root, out_root)
  expect_identical(res$decision_mode, "structural_rhs_repair")
})

test_that("multichain follow-up assessment chooses representative confirmation when confirmation is strong", {
  tmp <- withr::local_tempdir()
  report_root <- file.path(tmp, "multichain")
  out_root <- file.path(tmp, "decision")
  dir.create(file.path(report_root, "tables"), recursive = TRUE)

  utils::write.csv(data.frame(
    root_id = c("r1", "r2", "r3"),
    scenario = c("toy", "const", "sin"),
    tau = c(0.25, 0.25, 0.50),
    beta_prior_type = c("rhs", "rhs", "rhs"),
    seed = c(1L, 1L, 1L),
    reservoir_profile = c("tiny", "tiny", "tiny"),
    confirmation_grade = c("PASS", "WARN", "WARN"),
    stringsAsFactors = FALSE
  ), file.path(report_root, "tables", "campaign_root_confirmation.csv"), row.names = FALSE)

  utils::write.csv(data.frame(
    root_id = rep(c("r1", "r2", "r3"), each = 2),
    scenario = rep(c("toy", "const", "sin"), each = 2),
    tau = rep(c(0.25, 0.25, 0.50), each = 2),
    beta_prior_type = "rhs",
    seed = 1L,
    reservoir_profile = "tiny",
    parameter = rep(c("gamma", "rhs_tau"), 3),
    rhat = c(1.02, 1.04, 1.03, 1.08, 1.01, 1.05),
    stringsAsFactors = FALSE
  ), file.path(report_root, "tables", "campaign_multichain_rhat.csv"), row.names = FALSE)

  res <- exdqlm:::qdesn_validation_assess_multichain_followup(report_root, out_root)
  expect_identical(res$decision_mode, "representative_confirmation")
})

test_that("representative default candidate assessment promotes when multichain confirmation improves", {
  tmp <- withr::local_tempdir()
  base_root <- file.path(tmp, "baseline")
  cand_root <- file.path(tmp, "candidate")
  out_root <- file.path(tmp, "decision")
  dir.create(file.path(base_root, "tables"), recursive = TRUE)
  dir.create(file.path(cand_root, "tables"), recursive = TRUE)

  base_confirm <- data.frame(
    root_id = c("r1", "r2"),
    scenario = c("a", "b"),
    tau = c(0.25, 0.50),
    beta_prior_type = c("rhs", "rhs"),
    seed = c(1L, 1L),
    reservoir_profile = c("tiny", "tiny"),
    confirmation_grade = c("FAIL", "PASS"),
    stringsAsFactors = FALSE
  )
  cand_confirm <- base_confirm
  cand_confirm$confirmation_grade <- c("PASS", "PASS")

  base_rhat <- data.frame(
    root_id = c("r1", "r2"),
    scenario = c("a", "b"),
    tau = c(0.25, 0.50),
    beta_prior_type = c("rhs", "rhs"),
    seed = c(1L, 1L),
    reservoir_profile = c("tiny", "tiny"),
    parameter = c("rhs_c2", "rhs_c2"),
    rhat = c(1.12, 1.03),
    stringsAsFactors = FALSE
  )
  cand_rhat <- base_rhat
  cand_rhat$rhat <- c(1.04, 1.02)

  utils::write.csv(base_confirm, file.path(base_root, "tables", "campaign_root_confirmation.csv"), row.names = FALSE)
  utils::write.csv(cand_confirm, file.path(cand_root, "tables", "campaign_root_confirmation.csv"), row.names = FALSE)
  utils::write.csv(base_rhat, file.path(base_root, "tables", "campaign_multichain_rhat.csv"), row.names = FALSE)
  utils::write.csv(cand_rhat, file.path(cand_root, "tables", "campaign_multichain_rhat.csv"), row.names = FALSE)

  cmp <- exdqlm:::qdesn_validation_compare_multichain_reports(base_root, cand_root, file.path(tmp, "compare"))
  expect_equal(nrow(cmp$root_confirmation_compare), 2L)

  res <- exdqlm:::qdesn_validation_assess_representative_default_candidate(cand_root, base_root, out_root)
  expect_identical(res$decision_mode, "promote_representative_default")
})

test_that("remaining-fail structural follow-up grid isolates the representative failure root", {
  grid_path <- exdqlm:::.qdesn_validation_resolve_path(
    file.path("config", "validation", "qdesn_mcmc_multichain_remaining_rhs_fail_grid.csv"),
    must_work = TRUE
  )
  grid <- utils::read.csv(
    grid_path,
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(grid), 1L)
  expect_identical(grid$scenario[[1L]], "sin_asym_small")
  expect_equal(grid$tau[[1L]], 0.25)
  expect_identical(grid$beta_prior_type[[1L]], "rhs")
})
