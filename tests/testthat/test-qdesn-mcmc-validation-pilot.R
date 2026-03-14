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
  expect_true(file.exists(file.path(res$root_dir, "fits", "vb", "fit_summary.json")))
  expect_true(file.exists(file.path(res$root_dir, "fits", "mcmc", "fit_summary.json")))
  expect_true(file.exists(file.path(res$root_dir, "fits", "mcmc", "chain_summary.csv")))

  camp <- exdqlm:::qdesn_validation_collect_campaign(
    results_root = results_root,
    report_root = reports_root,
    create_plots = FALSE
  )

  expect_true(nrow(camp$root_summary) >= 1L)
  expect_true(nrow(camp$method_summary) >= 2L)
  expect_true(nrow(camp$method_group) >= 2L)
  expect_true(nrow(camp$pair_group) >= 1L)
  expect_true(nrow(camp$stage_group) >= 1L)
  expect_true(nrow(camp$chain_group) >= 1L)
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_root_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_method_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_method_group_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_pair_group_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_stage_group_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_chain_group_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "campaign_summary.md")))
  expect_true(any(camp$method_summary$method == "vb"))
  expect_true(any(camp$method_summary$method == "mcmc"))
})
