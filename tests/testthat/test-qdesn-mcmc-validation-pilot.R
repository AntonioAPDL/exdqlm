test_that("toy validation generator returns consistent long and wide outputs", {
  toy <- exdqlm:::qdesn_validation_generate_toy_series(
    scenario = "toy_sine_small",
    seed = 123L,
    p_grid = c(0.25, 0.50),
    scenario_cfg = list(T_use = 24L, n_train = 18L, amplitude = 0.7, period = 12, noise_sd = 0.12)
  )

  expect_equal(nrow(toy$wide), 24L)
  expect_equal(nrow(toy$long), 48L)
  expect_true(all(c("t", "y", "mu", "q_025", "q_050") %in% names(toy$wide)))
  expect_true(all(c("t", "p", "q", "y", "mu") %in% names(toy$long)))

  q25_long <- subset(toy$long, abs(p - 0.25) < 1e-12)$q
  expect_equal(as.numeric(toy$wide$q_025), as.numeric(q25_long), tolerance = 1e-10)
  expect_equal(as.integer(toy$split$n_train[[1L]]), 18L)
  expect_equal(as.integer(toy$split$H_forecast[[1L]]), 6L)
})

test_that("toy validation generator supports expanded phase-1 scenarios", {
  scenarios <- list(
    const_small = list(T_use = 24L, n_train = 18L, level = 0.4, noise_sd = 0.08),
    sin_asym_small = list(T_use = 24L, n_train = 18L, amplitude = 0.5, period = 12, meanlog = -0.3, sdlog = 0.35, noise_scale = 0.25),
    level_shift_small = list(T_use = 24L, n_train = 18L, break_1 = 8L, break_2 = 16L, level_1 = 0.1, level_2 = 0.7, level_3 = -0.1, noise_sd = 0.1)
  )
  p_grid <- c(0.05, 0.25, 0.50)

  for (nm in names(scenarios)) {
    toy <- exdqlm:::qdesn_validation_generate_toy_series(
      scenario = nm,
      seed = 123L,
      p_grid = p_grid,
      scenario_cfg = scenarios[[nm]]
    )
    expect_equal(nrow(toy$wide), 24L)
    expect_equal(nrow(toy$long), 24L * length(p_grid))
    expect_true(all(c("q_005", "q_025", "q_050") %in% names(toy$wide)))
    expect_true(all(toy$wide$q_005 <= toy$wide$q_025 + 1e-10))
    expect_true(all(toy$wide$q_025 <= toy$wide$q_050 + 1e-10))
  }
})

test_that("pilot validation root writes method summaries and campaign summaries", {
  defaults <- exdqlm:::qdesn_validation_load_defaults()
  defaults$toy$scenarios$toy_sine_small$T_use <- 48L
  defaults$toy$scenarios$toy_sine_small$n_train <- 36L
  defaults$pipeline$sampling$nd_draws <- 24L
  defaults$pipeline$sampling$chunk <- 12L
  defaults$pipeline$synthesis$n_samp <- 24L
  defaults$pipeline$inference$vb$max_iter <- 12L
  defaults$pipeline$inference$vb$min_iter_elbo <- 4L
  defaults$pipeline$inference$vb$n_samp_xi <- 24L
  defaults$pipeline$inference$mcmc$n_burn <- 12L
  defaults$pipeline$inference$mcmc$n_mcmc <- 18L
  defaults$pipeline$inference$mcmc$progress_every <- 5L

  results_root <- file.path(tempdir(), paste0("qdesn-validation-results-", Sys.getpid()))
  reports_root <- file.path(tempdir(), paste0("qdesn-validation-reports-", Sys.getpid()))
  dir.create(file.path(results_root, "roots"), recursive = TRUE, showWarnings = FALSE)

  root_spec <- list(
    scenario = "toy_sine_small",
    tau = 0.25,
    beta_prior_type = "ridge",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8"
  )

  res <- exdqlm:::qdesn_validation_run_root(
    root_spec = root_spec,
    defaults = defaults,
    output_root = file.path(results_root, "roots"),
    create_plots = FALSE,
    verbose = FALSE
  )

  expect_identical(res$root_status, "SUCCESS")
  expect_true(file.exists(file.path(res$root_dir, "manifest", "root_status.txt")))
  expect_true(file.exists(file.path(res$root_dir, "tables", "method_compare_long.csv")))
  expect_true(file.exists(file.path(res$root_dir, "tables", "method_compare_summary.csv")))
  expect_true(file.exists(file.path(res$root_dir, "tables", "method_signoff_long.csv")))
  expect_true(file.exists(file.path(res$root_dir, "fits", "vb", "fit_summary.json")))
  expect_true(file.exists(file.path(res$root_dir, "fits", "mcmc", "fit_summary.json")))
  expect_true(file.exists(file.path(res$root_dir, "fits", "mcmc", "chain_summary.csv")))

  camp <- exdqlm:::qdesn_validation_collect_campaign(
    results_root = results_root,
    report_root = reports_root,
    create_plots = FALSE,
    defaults = defaults
  )

  expect_true(nrow(camp$root_summary) >= 1L)
  expect_true(nrow(camp$method_summary) >= 2L)
  expect_true(nrow(camp$method_signoff) >= 2L)
  expect_true(nrow(camp$method_group) >= 2L)
  expect_true(nrow(camp$pair_group) >= 1L)
  expect_true(nrow(camp$stage_group) >= 1L)
  expect_true(nrow(camp$chain_group) >= 1L)
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_root_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_method_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_method_signoff.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_method_group_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_pair_group_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_stage_group_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_chain_group_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "campaign_summary.md")))
  expect_true(any(camp$method_summary$method == "vb"))
  expect_true(any(camp$method_summary$method == "mcmc"))
  expect_true(all(c("signoff_grade", "comparison_eligible") %in% names(camp$method_summary)))
  expect_true("pair_signoff_grade" %in% names(camp$pair_summary))
  expect_true("pair_comparison_eligible" %in% names(camp$pair_summary))
})

test_that("VB signoff distinguishes stable converged from stable unconverged traces", {
  meta <- data.frame(
    root_id = "root",
    scenario = "toy_sine_small",
    tau = 0.25,
    beta_prior_type = "ridge",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8",
    stringsAsFactors = FALSE
  )
  cfg <- exdqlm:::.qdesn_validation_signoff_cfg(NULL)$vb
  progress <- data.frame(
    method = "vb",
    step = 1:8,
    gamma = c(1.00, 1.02, 1.01, 1.009, 1.008, 1.0085, 1.0084, 1.00845),
    sigma = c(0.60, 0.61, 0.605, 0.604, 0.6035, 0.6033, 0.6034, 0.60335),
    elbo = c(-1.20, -1.05, -1.00, -0.995, -0.994, -0.9938, -0.9937, -0.99365),
    beta_norm = c(0.80, 0.82, 0.815, 0.814, 0.8138, 0.8137, 0.81375, 0.81374),
    stringsAsFactors = FALSE
  )
  health_pass <- data.frame(status = "SUCCESS", finite_ok = TRUE, domain_ok = TRUE, vb_converged = TRUE, stringsAsFactors = FALSE)
  health_warn <- data.frame(status = "SUCCESS", finite_ok = TRUE, domain_ok = TRUE, vb_converged = FALSE, stringsAsFactors = FALSE)

  pass_row <- exdqlm:::.qdesn_validation_vb_signoff_from_rows(meta, health_pass, progress, cfg)
  warn_row <- exdqlm:::.qdesn_validation_vb_signoff_from_rows(meta, health_warn, progress, cfg)

  expect_identical(pass_row$signoff_grade, "PASS")
  expect_true(pass_row$comparison_eligible)
  expect_identical(warn_row$signoff_grade, "WARN")
  expect_true(warn_row$comparison_eligible)
})

test_that("MCMC signoff fails clearly drifting low-information chains", {
  set.seed(42)
  meta <- data.frame(
    root_id = "root",
    scenario = "toy_sine_small",
    tau = 0.25,
    beta_prior_type = "rhs",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8",
    stringsAsFactors = FALSE
  )
  cfg <- exdqlm:::.qdesn_validation_signoff_cfg(NULL)$mcmc
  x <- seq(0, 1, length.out = 40)
  progress <- data.frame(
    method = "mcmc",
    step = seq_along(x),
    gamma = x,
    sigma = 0.2 + x / 10,
    beta_norm = 1 + x,
    rhs_tau = exp(-4 + x),
    rhs_c2 = 0.5 + x,
    rhs_lambda_mean = 1 + x / 2,
    stringsAsFactors = FALSE
  )
  health <- data.frame(
    status = "SUCCESS",
    finite_ok = TRUE,
    domain_ok = TRUE,
    mcmc_n_keep = 40L,
    stringsAsFactors = FALSE
  )

  row <- exdqlm:::.qdesn_validation_mcmc_signoff_from_rows(meta, health, progress, cfg)

  expect_identical(row$signoff_grade, "FAIL")
  expect_false(row$comparison_eligible)
  expect_match(row$signoff_reason, "short_chain|low_ess|geweke_drift|half_chain_drift")
})
