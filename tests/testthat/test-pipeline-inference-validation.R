local_sim_file <- function() {
  file.path(test_path("..", ".."), "results", "sim_suite_dlm", "series", "dlm_constV_smallW", "series_long.csv")
}

local_real_file <- function() {
  file.path(test_path("..", ".."), "results", "sim_suite_dlm", "series", "dlm_constV_smallW", "series_wide.csv")
}

make_smoke_cfg <- function(mode = c("sim", "real"), method = c("vb", "mcmc"), beta_type = c("ridge", "rhs")) {
  mode <- match.arg(mode)
  method <- match.arg(method)
  beta_type <- match.arg(beta_type)

  cfg <- list(
    pipeline = list(mode = mode, verbose = FALSE),
    split = list(use_last = TRUE, T_use = 80L, train_prop = 0.85),
    p_vec = c(0.25, 0.50, 0.75),
    desn = list(
      D = 1L,
      n = 10L,
      n_tilde = integer(0),
      m = 4L,
      alpha = 0.2,
      rho = 0.9,
      act_f = "tanh",
      act_k = "identity",
      pi_w = 0.15,
      pi_in = 1.0,
      washout = 4L,
      add_bias = TRUE,
      seed = 123L
    ),
    readout = list(include_input = identical(mode, "sim"), reservoir_lags = 1L, input_position = "after_reservoir"),
    sampling = list(nd_draws = 24L, chunk = 12L),
    forecast = list(mode = "origin", horizon = 3L, train_last_window = 15L, fore_last_window = 15L),
    synthesis = list(isotonic = TRUE, rearrange = TRUE, grid_M = 151L, n_samp = 24L, seed = 123L),
    diagnostics = list(calibration = FALSE, pit = FALSE, scores = TRUE, lead_eval = FALSE, fan_charts = FALSE, plots = FALSE),
    cpp = list(use_postpred = FALSE, postpred_omp = FALSE, postpred_precompute = FALSE, postpred_threads = 1L),
    outputs = list(save = TRUE, keep_draws = FALSE, thesis_subset = FALSE),
    inference = list(method = method, readout_scale = TRUE)
  )

  if (identical(mode, "real")) {
    cfg$columns <- list(y = "y", x = list())
    cfg$lags <- list(m_y = 8L, m_x = 0L)
    cfg$readout$include_input <- FALSE
  }

  if (identical(method, "vb")) {
    cfg$inference$vb <- list(
      max_iter = 12L,
      min_iter_elbo = 4L,
      n_samp_xi = 30L,
      verbose = FALSE,
      diagnostics = list(rhs_trace = FALSE, rhs_deep = FALSE),
      rhs = list(freeze_tau_iters = 3L, freeze_tau_warmup_iters = 3L),
      priors = list(beta = list(type = beta_type))
    )
    if (identical(beta_type, "ridge")) {
      cfg$inference$vb$priors$beta$ridge <- list(tau2 = 20)
    } else {
      cfg$inference$vb$priors$beta$rhs <- list(
        tau0 = 0.01,
        nu = 4,
        s2 = 0.5,
        shrink_intercept = FALSE,
        intercept_prec = 1e-10,
        eta_bounds = list(lambda = c(-8, 8), tau = c(-8, 8), c2 = c(-8, 8)),
        h_curv = 1e-8,
        var_floor = 1e-8
      )
    }
  } else {
    cfg$inference$mcmc <- list(
      n_burn = 12L,
      n_mcmc = 18L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = TRUE,
      store_latent_draws = FALSE,
      store_rhs_draws = FALSE,
      slice = list(width_gamma = 0.8, width_rhs_lambda = 0.6, width_rhs_tau = 0.6, width_rhs_c2 = 0.6, max_steps_out = 30L, max_shrink = 100L),
      priors = list(beta = list(type = beta_type))
    )
    if (identical(beta_type, "ridge")) {
      cfg$inference$mcmc$priors$beta$ridge <- list(tau2 = 20)
    } else {
      cfg$inference$mcmc$priors$beta$rhs <- list(
        tau0 = 0.01,
        nu = 4,
        s2 = 0.5,
        shrink_intercept = FALSE,
        intercept_prec = 1e-10,
        eta_bounds = list(lambda = c(-8, 8), tau = c(-8, 8), c2 = c(-8, 8)),
        h_curv = 1e-8,
        var_floor = 1e-8
      )
    }
  }

  cfg
}

test_that("sim pipeline smoke supports VB inference summaries", {
  sim_file <- normalizePath(local_sim_file(), winslash = "/", mustWork = FALSE)
  skip_if_not(file.exists(sim_file))

  out_dir <- file.path(tempdir(), "pipeline-smoke-sim-vb")
  unlink(out_dir, recursive = TRUE, force = TRUE)

  res <- exdqlm::run_esn_pipeline_from_cfg(
    cfg = make_smoke_cfg(mode = "sim", method = "vb", beta_type = "ridge"),
    file_long = sim_file,
    out_dir = out_dir,
    save_outputs = TRUE,
    verbose = FALSE
  )

  expect_identical(res$status, 0L)
  expect_true(file.exists(file.path(out_dir, "tables", "timing_summary.csv")))
  expect_true(file.exists(file.path(out_dir, "models", "forecast_objects.rds")))

  summary_obj <- exdqlm:::collect_pipeline_run_summary(out_dir)
  expect_identical(summary_obj$summary$mode[[1L]], "sim")
  expect_identical(summary_obj$summary$inference_method[[1L]], "vb")
  expect_identical(summary_obj$summary$beta_prior_type[[1L]], "ridge")
  expect_true(is.finite(summary_obj$summary$total_stage_seconds[[1L]]))
  expect_true(is.finite(summary_obj$summary$forecast_CRPS_mean[[1L]]))
})

test_that("real pipeline smoke supports MCMC inference summaries", {
  real_file <- normalizePath(local_real_file(), winslash = "/", mustWork = FALSE)
  skip_if_not(file.exists(real_file))

  out_dir <- file.path(tempdir(), "pipeline-smoke-real-mcmc")
  unlink(out_dir, recursive = TRUE, force = TRUE)

  res <- exdqlm::run_esn_pipeline_from_cfg(
    cfg = make_smoke_cfg(mode = "real", method = "mcmc", beta_type = "rhs"),
    file_long = real_file,
    file_obs = real_file,
    out_dir = out_dir,
    save_outputs = TRUE,
    verbose = FALSE
  )

  expect_identical(res$status, 0L)
  expect_true(file.exists(file.path(out_dir, "tables", "timing_summary.csv")))
  expect_true(file.exists(file.path(out_dir, "models", "forecast_objects.rds")))

  summary_obj <- exdqlm:::collect_pipeline_run_summary(out_dir)
  expect_identical(summary_obj$summary$mode[[1L]], "real")
  expect_identical(summary_obj$summary$inference_method[[1L]], "mcmc")
  expect_identical(summary_obj$summary$beta_prior_type[[1L]], "rhs")
  expect_true(is.finite(summary_obj$summary$total_stage_seconds[[1L]]))
  expect_true(is.finite(summary_obj$summary$forecast_CRPS_mean[[1L]]))
  expect_true(nrow(summary_obj$timing_breakdown) >= 1L)
  expect_true(nrow(summary_obj$rhs_run_summary) >= 1L)
  expect_true(any(as.logical(summary_obj$rhs_run_summary$rhs_trace_available), na.rm = TRUE))
  if ("unhealthy_reason" %in% names(summary_obj$rhs_run_summary)) {
    expect_false(any(as.character(summary_obj$rhs_run_summary$unhealthy_reason) == "rhs_trace_unavailable", na.rm = TRUE))
  }
})
