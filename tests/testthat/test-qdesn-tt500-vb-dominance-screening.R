test_that("dominance screening profiles are period-90 compact and unique", {
  profiles <- exdqlm:::qdesn_dynamic_fitforecast_dominance_profiles()

  expect_equal(nrow(profiles), 72L)
  expect_equal(length(unique(profiles$screening_profile_id)), 72L)
  expect_true(all(profiles$D %in% c(1L, 2L)))
  expect_true(all(profiles$n_each %in% c(20L, 30L, 50L)))
  expect_true(all(profiles$m == 90L))
  expect_true(all(profiles$readout_y_lags == 90L))
  expect_true(all(profiles$washout == 300L))
  expect_true(all(profiles$rhs_tau0 == 1e-4))
  expect_true(all(profiles$p_over_n_tt500 <= 0.50))
  expect_equal(sort(unique(profiles$profile_role)), c("seasonal_balanced", "seasonal_input_rich", "seasonal_sparse"))
  expect_equal(sort(unique(profiles$pi_in)), c(0.30, 0.50, 0.80))
  expect_equal(sort(unique(profiles$pi_w)), c(0.05, 0.10, 0.20))
})

test_that("deterministic period-90 feature staging is future-known and named", {
  defaults <- list(
    deterministic_features = list(
      enabled = TRUE,
      period = 90,
      harmonics = c(1, 2),
      include_trend = TRUE,
      include_index = FALSE,
      prefix = "period90"
    )
  )
  features <- exdqlm:::.qdesn_dynamic_crossstudy_make_deterministic_features(8501:8510, defaults)

  expect_equal(nrow(features), 10L)
  expect_equal(
    names(features),
    c("period90_sin_h1", "period90_cos_h1", "period90_sin_h2", "period90_cos_h2", "period90_trend_z")
  )
  expect_true(all(vapply(features, function(x) all(is.finite(x)), logical(1L))))
  expect_false("period90_source_index" %in% names(features))
})

test_that("explicit x lag zero is passed to the pipeline config", {
  root_spec <- list(
    root_id = "root",
    beta_prior_type = "rhs_ns",
    tau = 0.5,
    fit_size = 500L,
    reservoir_profile = "tiny"
  )
  defaults <- list(
    reservoir_profiles = list(
      tiny = list(
        D = 1L,
        n = 10L,
        n_tilde = integer(0),
        m = 90L,
        alpha = 0.1,
        rho = 0.7,
        act_f = "tanh",
        act_k = "identity",
        pi_w = 0.1,
        pi_in = 0.5,
        washout = 300L,
        add_bias = TRUE,
        seed = 123L
      )
    ),
    external_data = list(holdout_n = 1000L, y_column = "y"),
    lags = list(m_y = 90L, m_x = 0L, x = 0L),
    pipeline = list(
      inference = list(vb = list(priors = list(beta = list(rhs_ns = list(tau0 = 1e-4)))))
    )
  )
  cfg <- exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec,
    defaults = defaults,
    method = "vb",
    likelihood_family = "exal",
    x_cols = c("period90_sin_h1", "period90_cos_h1"),
    T_use = 1500L
  )

  expect_equal(cfg$columns$x, c("period90_sin_h1", "period90_cos_h1"))
  expect_equal(cfg$lags$m_y, 90L)
  expect_equal(cfg$lags$x, 0L)
})

test_that("dominance ranker compares Q-DESN cells with best VB baseline", {
  tmp <- tempfile("qdesn_dominance_test_")
  dir.create(tmp)
  q_path <- file.path(tmp, "qdesn_tt500_vb_screen_fit_forecast_summary.csv")
  baseline_path <- file.path(tmp, "baseline.csv")
  q <- data.frame(
    screening_profile_id = rep(c("tt500vb_dom_a", "tt500vb_dom_b"), each = 2L),
    family = rep(c("normal", "laplace"), times = 2L),
    tau = rep(c(0.5, 0.5), times = 2L),
    fit_size = 500L,
    D = c(1L, 1L, 2L, 2L),
    n_each = c(20L, 20L, 30L, 30L),
    alpha = c(0.1, 0.1, 0.2, 0.2),
    rho = c(0.7, 0.7, 0.8, 0.8),
    forecast_all_qtrue_mae = c(0.8, 0.9, 1.2, 0.9),
    forecast_all_pinball_mean = c(0.4, 0.4, 0.6, 0.4),
    train_qtrue_rmse = c(0.8, 0.8, 1.1, 0.8),
    train_pinball_tau = c(0.4, 0.4, 0.6, 0.4),
    runtime_sec = c(10, 11, 8, 9),
    dimension_p_estimate = c(100L, 100L, 140L, 140L),
    p_over_n_tt500 = c(0.2, 0.2, 0.28, 0.28),
    stringsAsFactors = FALSE
  )
  baseline <- data.frame(
    model_family = "exdqlm_dqlm",
    model_variant = rep(c("dqlm", "exdqlm"), each = 2L),
    inference = "vb",
    family = rep(c("normal", "laplace"), times = 2L),
    tau = 0.5,
    fit_size = 500L,
    forecast_qtrue_mae_lead_weighted = 1,
    forecast_pinball_mean_lead_weighted = 0.5,
    fit_qtrue_rmse = 1,
    fit_pinball_mean = 0.5,
    stringsAsFactors = FALSE
  )
  utils::write.csv(q, q_path, row.names = FALSE)
  utils::write.csv(baseline, baseline_path, row.names = FALSE)

  out <- exdqlm:::qdesn_dynamic_fitforecast_rank_screen_against_vb_baseline(
    fit_forecast_summary_path = q_path,
    baseline_path = baseline_path,
    out_dir = tmp
  )
  ranking <- out$profile_ranking
  expect_equal(ranking$screening_profile_base[[1L]], "tt500vb_dom_a")
  expect_true(ranking$dominance_pass[[1L]])
  expect_false(ranking$dominance_pass[[2L]])
  expect_true(file.exists(out$output_paths$summary))
})
