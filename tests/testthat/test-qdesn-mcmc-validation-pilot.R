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

test_that("validation generator supports dynamic DLM scenarios via simulation backend", {
  toy <- exdqlm:::qdesn_validation_generate_toy_series(
    scenario = "dlm_constV_smallW",
    seed = 321L,
    p_grid = c(0.05, 0.50, 0.95),
    scenario_cfg = list(
      T_use = 24L,
      n_train = 18L,
      burnin = 120L,
      R_mc = 400L,
      params = list(period = 24L, V = 0.25, alpha = 1e-4, no_trend = TRUE)
    )
  )

  expect_equal(nrow(toy$wide), 24L)
  expect_equal(nrow(toy$long), 72L)
  expect_true(all(c("q_005", "q_050", "q_095") %in% names(toy$wide)))
  expect_true(all(c("t", "p", "q", "y", "mu") %in% names(toy$long)))
  expect_identical(as.character(toy$meta$source), "simulate_ts_mc_quantiles")
  expect_equal(as.integer(toy$split$n_train[[1L]]), 18L)
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
  expect_true(nrow(camp$tau_method_group) >= 2L)
  expect_true(nrow(camp$tau_pair_group) >= 1L)
  expect_true(nrow(camp$stage_group) >= 1L)
  expect_true(nrow(camp$chain_group) >= 1L)
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_root_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_method_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_method_signoff.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_method_group_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_pair_group_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_tau_set_method_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_tau_set_pair_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_stage_group_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "tables", "campaign_chain_group_summary.csv")))
  expect_true(file.exists(file.path(reports_root, "campaign_summary.md")))
  expect_true(any(camp$method_summary$method == "vb"))
  expect_true(any(camp$method_summary$method == "mcmc"))
  expect_true(all(c("signoff_grade", "comparison_eligible") %in% names(camp$method_summary)))
  expect_true("pair_signoff_grade" %in% names(camp$pair_summary))
  expect_true("pair_comparison_eligible" %in% names(camp$pair_summary))

  cmp_root <- file.path(tempdir(), paste0("qdesn-validation-compare-", Sys.getpid()))
  cmp <- exdqlm:::qdesn_validation_compare_campaign_reports(
    baseline_report_root = reports_root,
    tuned_report_root = reports_root,
    output_root = cmp_root,
    create_plots = FALSE
  )
  expect_true(nrow(cmp$method_group_compare) >= 2L)
  expect_true(nrow(cmp$pair_group_compare) >= 1L)
  expect_true(file.exists(file.path(cmp_root, "tables", "method_group_compare.csv")))
  expect_true(file.exists(file.path(cmp_root, "tables", "pair_group_compare.csv")))
  expect_true(file.exists(file.path(cmp_root, "comparison_summary.md")))
  expect_true(all(abs(cmp$pair_group_compare$pair_comparison_eligible_rate_delta_tuned_minus_baseline) < 1e-12 | is.na(cmp$pair_group_compare$pair_comparison_eligible_rate_delta_tuned_minus_baseline)))

  if (requireNamespace("ggplot2", quietly = TRUE)) {
    cmp_plot_root <- file.path(tempdir(), paste0("qdesn-validation-compare-plots-", Sys.getpid()))
    exdqlm:::qdesn_validation_compare_campaign_reports(
      baseline_report_root = reports_root,
      tuned_report_root = reports_root,
      output_root = cmp_plot_root,
      create_plots = TRUE
    )
    expect_true(file.exists(file.path(cmp_plot_root, "plots", "pair_eligibility_rate_compare.png")))
    expect_true(file.exists(file.path(cmp_plot_root, "plots", "runtime_ratio_compare.png")))
    expect_true(file.exists(file.path(cmp_plot_root, "plots", "score_delta_change_compare.png")))
  }
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

test_that("validation config builder applies prior-specific inference overrides", {
  defaults <- exdqlm:::qdesn_validation_load_defaults(file.path("config", "validation", "qdesn_mcmc_compare_tuned_defaults.yaml"))
  ridge_spec <- exdqlm:::qdesn_validation_enrich_root_spec(list(
    scenario = "toy_sine_small",
    tau = 0.25,
    beta_prior_type = "ridge",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8"
  ), defaults)
  rhs_spec <- exdqlm:::qdesn_validation_enrich_root_spec(list(
    scenario = "toy_sine_small",
    tau = 0.25,
    beta_prior_type = "rhs",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8"
  ), defaults)

  vb_ridge <- exdqlm:::qdesn_validation_build_pipeline_cfg(ridge_spec, defaults, method = "vb")
  vb_rhs <- exdqlm:::qdesn_validation_build_pipeline_cfg(rhs_spec, defaults, method = "vb")
  mc_ridge <- exdqlm:::qdesn_validation_build_pipeline_cfg(ridge_spec, defaults, method = "mcmc")
  mc_rhs <- exdqlm:::qdesn_validation_build_pipeline_cfg(rhs_spec, defaults, method = "mcmc")

  expect_equal(vb_ridge$inference$vb$max_iter, 35L)
  expect_equal(vb_rhs$inference$vb$max_iter, 60L)
  expect_equal(vb_rhs$inference$vb$rhs$freeze_tau_warmup_iters, 10L)
  expect_equal(vb_rhs$inference$vb$n_samp_xi, 128L)
  expect_equal(mc_ridge$inference$mcmc$n_burn, 300L)
  expect_equal(mc_rhs$inference$mcmc$n_burn, 500L)
  expect_equal(mc_rhs$inference$mcmc$slice$width_rhs_tau, 0.25)
  expect_equal(mc_rhs$inference$mcmc$slice$max_steps_out, 50L)
})

test_that("validation config builder falls back rhs_ns overrides from rhs block", {
  defaults <- exdqlm:::qdesn_validation_load_defaults(file.path("config", "validation", "qdesn_mcmc_compare_tuned_defaults.yaml"))
  defaults$pipeline$inference$vb$prior_overrides$rhs_ns <- NULL
  defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns <- NULL

  rhs_ns_spec <- exdqlm:::qdesn_validation_enrich_root_spec(list(
    scenario = "toy_sine_small",
    tau = 0.50,
    beta_prior_type = "rhs_ns",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8"
  ), defaults)

  vb_cfg <- exdqlm:::qdesn_validation_build_pipeline_cfg(rhs_ns_spec, defaults, method = "vb")
  mc_cfg <- exdqlm:::qdesn_validation_build_pipeline_cfg(rhs_ns_spec, defaults, method = "mcmc")

  expect_equal(vb_cfg$inference$vb$max_iter, 60L)
  expect_equal(vb_cfg$inference$vb$min_iter_elbo, 12L)
  expect_equal(vb_cfg$inference$vb$n_samp_xi, 128L)
  expect_equal(mc_cfg$inference$mcmc$n_burn, 500L)
  expect_equal(mc_cfg$inference$mcmc$n_mcmc, 1000L)
  expect_equal(mc_cfg$inference$mcmc$slice$width_rhs_tau, 0.25)
})

test_that("validation config builder honors validation_p_vec override", {
  defaults <- exdqlm:::qdesn_validation_load_defaults(file.path("config", "validation", "qdesn_mcmc_compare_tuned_defaults.yaml"))
  defaults$pipeline$validation_p_vec <- c(0.05, 0.50, 0.95)

  spec <- exdqlm:::qdesn_validation_enrich_root_spec(list(
    scenario = "toy_sine_small",
    tau = 0.50,
    beta_prior_type = "rhs_ns",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8"
  ), defaults)

  vb_cfg <- exdqlm:::qdesn_validation_build_pipeline_cfg(spec, defaults, method = "vb")
  mc_cfg <- exdqlm:::qdesn_validation_build_pipeline_cfg(spec, defaults, method = "mcmc")

  expect_equal(vb_cfg$p_vec, c(0.05, 0.50, 0.95))
  expect_equal(mc_cfg$p_vec, c(0.05, 0.50, 0.95))
  expect_equal(spec$tau, 0.50)
})

test_that("validation root spec and config route likelihood family", {
  defaults <- exdqlm:::qdesn_validation_load_defaults(file.path("config", "validation", "qdesn_mcmc_compare_tuned_defaults.yaml"))
  spec <- exdqlm:::qdesn_validation_enrich_root_spec(list(
    scenario = "toy_sine_small",
    tau = 0.50,
    likelihood_family = "al",
    beta_prior_type = "ridge",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8"
  ), defaults)

  expect_identical(spec$likelihood_family, "al")
  expect_true(grepl("__lik-al__", spec$root_id, fixed = TRUE))

  vb_cfg <- exdqlm:::qdesn_validation_build_pipeline_cfg(spec, defaults, method = "vb")
  mc_cfg <- exdqlm:::qdesn_validation_build_pipeline_cfg(spec, defaults, method = "mcmc")
  expect_identical(vb_cfg$inference$likelihood_family, "al")
  expect_identical(mc_cfg$inference$likelihood_family, "al")
})

test_that("validation config routes AL with rhs_ns prior and preserves root keying", {
  defaults <- exdqlm:::qdesn_validation_load_defaults(file.path("config", "validation", "qdesn_dynamic_family_prior_defaults.yaml"))
  spec <- exdqlm:::qdesn_validation_enrich_root_spec(list(
    scenario = "dlm_constV_smallW",
    tau = 0.50,
    likelihood_family = "al",
    beta_prior_type = "rhs_ns",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8"
  ), defaults)

  expect_true(grepl("__lik-al__", spec$root_id, fixed = TRUE))
  expect_true(grepl("__prior-rhs_ns__", spec$root_id, fixed = TRUE))

  vb_cfg <- exdqlm:::qdesn_validation_build_pipeline_cfg(spec, defaults, method = "vb")
  mc_cfg <- exdqlm:::qdesn_validation_build_pipeline_cfg(spec, defaults, method = "mcmc")
  expect_identical(vb_cfg$inference$likelihood_family, "al")
  expect_identical(vb_cfg$inference$vb$priors$beta$type, "rhs_ns")
  expect_identical(mc_cfg$inference$likelihood_family, "al")
  expect_identical(mc_cfg$inference$mcmc$priors$beta$type, "rhs_ns")
})

test_that("MCMC signoff for AL does not require gamma diagnostics", {
  cfg <- exdqlm:::.qdesn_validation_signoff_cfg(NULL)$mcmc
  cfg$min_keep_pass <- 60L
  cfg$ess_pass <- 1
  cfg$ess_warn <- 1
  cfg$acf1_pass <- 0.999
  cfg$acf1_warn <- 0.999
  cfg$geweke_absz_pass <- 10
  cfg$geweke_absz_warn <- 10
  cfg$half_drift_pass <- 10
  cfg$half_drift_warn <- 10

  meta <- data.frame(
    root_id = "root",
    scenario = "dlm_constV_smallW",
    tau = 0.50,
    likelihood_family = "al",
    beta_prior_type = "rhs_ns",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8",
    stringsAsFactors = FALSE
  )
  health <- data.frame(
    status = "SUCCESS",
    finite_ok = TRUE,
    domain_ok = TRUE,
    mcmc_n_keep = 120L,
    likelihood_family = "al",
    stringsAsFactors = FALSE
  )
  progress <- data.frame(
    method = "mcmc",
    step = 1:120,
    sigma = 1 + 0.05 * sin((1:120) / 8),
    beta_norm = 0.8 + 0.02 * cos((1:120) / 6),
    stringsAsFactors = FALSE
  )

  out <- exdqlm:::.qdesn_validation_mcmc_signoff_from_rows(meta, health, progress, cfg)
  expect_false(grepl("missing_chain_diagnostics", as.character(out$signoff_reason), fixed = TRUE))
  expect_true(out$signoff_grade %in% c("PASS", "WARN"))
})

test_that("rhs_ns VB emits RHS diagnostics traces for signoff health checks", {
  defaults <- exdqlm:::qdesn_validation_load_defaults(file.path("config", "validation", "qdesn_rhs_vs_rhs_ns_median_defaults.yaml"))
  defaults$toy$scenarios$toy_sine_small$T_use <- 48L
  defaults$toy$scenarios$toy_sine_small$n_train <- 36L
  defaults$pipeline$sampling$nd_draws <- 24L
  defaults$pipeline$sampling$chunk <- 12L
  defaults$pipeline$synthesis$n_samp <- 24L
  defaults$pipeline$inference$vb$max_iter <- 12L
  defaults$pipeline$inference$vb$min_iter_elbo <- 4L
  defaults$pipeline$inference$vb$n_samp_xi <- 24L
  defaults$pipeline$inference$mcmc$n_burn <- 8L
  defaults$pipeline$inference$mcmc$n_mcmc <- 12L
  defaults$pipeline$inference$mcmc$progress_every <- 4L

  output_root <- file.path(tempdir(), paste0("qdesn-rhsns-root-", Sys.getpid()))
  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

  root_spec <- list(
    scenario = "toy_sine_small",
    tau = 0.50,
    beta_prior_type = "rhs_ns",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8"
  )

  res <- exdqlm:::qdesn_validation_run_root(
    root_spec = root_spec,
    defaults = defaults,
    output_root = output_root,
    create_plots = FALSE,
    verbose = FALSE
  )
  expect_true(dir.exists(res$root_dir))

  vb_health <- utils::read.csv(file.path(res$root_dir, "fits", "vb", "health_summary.csv"), stringsAsFactors = FALSE)
  vb_trace <- utils::read.csv(file.path(res$root_dir, "fits", "vb", "progress_trace.csv"), stringsAsFactors = FALSE)
  unhealthy_reason <- if ("unhealthy_reason" %in% names(vb_health)) as.character(vb_health$unhealthy_reason[1L]) else ""

  expect_true(isTRUE(as.logical(vb_health$rhs_diag_available[1L])))
  expect_false(grepl("rhs_diagnostics_missing", unhealthy_reason, fixed = TRUE))
  expect_true(all(c("rhs_tau", "rhs_c2", "rhs_lambda_mean") %in% names(vb_trace)))
  expect_true(any(is.finite(as.numeric(vb_trace$rhs_tau))))
})

test_that("validation config builder enforces non-DLM input mode", {
  defaults <- exdqlm:::qdesn_validation_load_defaults(file.path("config", "validation", "qdesn_mcmc_compare_tuned_defaults.yaml"))
  root_spec <- exdqlm:::qdesn_validation_enrich_root_spec(list(
    scenario = "toy_sine_small",
    tau = 0.25,
    beta_prior_type = "rhs",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8"
  ), defaults)

  defaults_bad_input <- defaults
  defaults_bad_input$pipeline$readout$input_mode <- "dlm_decomp_lags"
  expect_error(
    exdqlm:::qdesn_validation_build_pipeline_cfg(root_spec, defaults_bad_input, method = "vb"),
    "raw_y_lags"
  )

  defaults_bad_decomp <- defaults
  defaults_bad_decomp$pipeline$decomposition <- list(enabled = TRUE)
  expect_error(
    exdqlm:::qdesn_validation_build_pipeline_cfg(root_spec, defaults_bad_decomp, method = "vb"),
    "decomposition.enabled=FALSE"
  )
})

test_that("validation config builder stamps explicit raw input-mode defaults", {
  defaults <- exdqlm:::qdesn_validation_load_defaults(file.path("config", "validation", "qdesn_mcmc_compare_tuned_defaults.yaml"))
  root_spec <- exdqlm:::qdesn_validation_enrich_root_spec(list(
    scenario = "toy_sine_small",
    tau = 0.25,
    beta_prior_type = "ridge",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8"
  ), defaults)
  cfg <- exdqlm:::qdesn_validation_build_pipeline_cfg(root_spec, defaults, method = "vb")
  expect_identical(cfg$readout$input_mode, "raw_y_lags")
  expect_true(identical(cfg$decomposition$enabled, FALSE))
})

test_that("rhs repair candidate defaults promote the B2 and C3 controls", {
  defaults <- exdqlm:::qdesn_validation_load_defaults(file.path("config", "validation", "qdesn_mcmc_compare_rhs_repair_defaults.yaml"))
  rhs_spec <- exdqlm:::qdesn_validation_enrich_root_spec(list(
    scenario = "sin_asym_small",
    tau = 0.25,
    beta_prior_type = "rhs",
    seed = 123L,
    reservoir_profile = "tiny_d1_n8"
  ), defaults)

  mc_rhs <- exdqlm:::qdesn_validation_build_pipeline_cfg(rhs_spec, defaults, method = "mcmc")

  expect_equal(mc_rhs$inference$mcmc$n_burn, 800L)
  expect_equal(mc_rhs$inference$mcmc$n_mcmc, 1600L)
  expect_equal(mc_rhs$inference$mcmc$progress_every, 200L)
  expect_equal(mc_rhs$inference$mcmc$slice$width_rhs_tau, 0.15)
  expect_equal(mc_rhs$inference$mcmc$rhs$freeze_tau_burnin_iters, 50L)
  expect_true(isTRUE(mc_rhs$inference$mcmc$rhs$freeze_tau_only_during_burn))
  expect_equal(mc_rhs$inference$mcmc$vb_warm_start_control$max_iter, 80L)
  expect_equal(mc_rhs$inference$mcmc$vb_warm_start_control$n_samp_xi, 200L)
  expect_equal(mc_rhs$inference$mcmc$vb_warm_start_control$rhs$freeze_tau_iters, 40L)
})
