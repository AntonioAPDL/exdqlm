test_that("benchmark split plan preserves Monash and M4 contracts", {
  cfg <- list(
    evaluation = list(selection = list(min_train_points = 24L)),
    split = list(validation = list(min_train_points = 24L))
  )

  monash_row <- data.table::data.table(
    train_end = 40L,
    val_start = 41L,
    val_end = 52L,
    test_start = 53L,
    test_end = 64L
  )
  monash_val <- exdqlm:::bench_qdesn_split_plan(monash_row, "monash", "validation", cfg)
  monash_test <- exdqlm:::bench_qdesn_split_plan(monash_row, "monash", "test", cfg)

  expect_equal(monash_val$fit_idx, 1:40)
  expect_equal(monash_val$eval_idx, 41:52)
  expect_equal(monash_test$fit_idx, 1:52)
  expect_equal(monash_test$eval_idx, 53:64)

  m4_row <- data.table::data.table(
    official_train_end = 48L,
    official_test_start = 49L,
    official_test_end = 54L,
    forecast_horizon = 6L
  )
  m4_val <- exdqlm:::bench_qdesn_split_plan(m4_row, "m4", "validation", cfg)
  m4_test <- exdqlm:::bench_qdesn_split_plan(m4_row, "m4", "test", cfg)

  expect_true(max(m4_val$fit_idx) < min(m4_val$eval_idx))
  expect_equal(max(m4_val$eval_idx), 48L)
  expect_equal(m4_test$fit_idx, 1:48)
  expect_equal(m4_test$eval_idx, 49:54)
})

test_that("Q-DESN synthesized benchmark runner returns scored outputs on a toy series", {
  withr::local_seed(42)
  cfg <- list(
    evaluation = list(
      selection = list(min_train_points = 16L),
      routing = list(enabled = FALSE)
    )
  )

  y <- as.numeric(10 + sin(seq_len(64) / 4) + 0.2 * stats::rnorm(64))
  bundle <- list(
    dataset = "toy_dataset",
    dataset_label = "Toy Dataset",
    source_family = "monash",
    benchmark_pool = "toy_pool",
    series_id = "S1",
    frequency_label = "monthly",
    seasonal_period = 12L,
    forecast_horizon = 8L,
    stage = "test",
    benchmark_split_protocol = "train_val_test_tail",
    selection_protocol = "stored_monash_test",
    route_key = "global",
    fit_idx = 1:56,
    eval_idx = 57:64,
    fit_y = y[1:56],
    eval_y = y[57:64],
    y = y,
    timestamp = as.character(seq.Date(as.Date("2000-01-01"), by = "month", length.out = 64)),
    t_index = seq_len(64)
  )

  candidate_cfg <- exdqlm:::bench_qdesn_normalize_model_cfg(list(
    candidate_id = "toy_cfg",
    p_vec = c(0.05, 0.50, 0.95),
    fit = list(
      D = 1L,
      n = 12L,
      m = 4L,
      alpha = 0.30,
      rho = 0.90,
      act_f = "tanh",
      act_k = "identity",
      pi_w = 0.20,
      pi_in = 1.00,
      washout = 4L,
      add_bias = TRUE,
      standardize_inputs = FALSE,
      seed = 99L
    ),
    vb_args = list(
      max_iter = 5L,
      min_iter_elbo = 2L,
      tol = 1e-3,
      n_samp_xi = 30L,
      verbose = FALSE
    ),
    sampling = list(
      nd_draws = 24L,
      chunk = 12L
    ),
    synthesis = list(
      n_samp = 32L,
      grid_M = 41L,
      isotonic = TRUE,
      rearrange = FALSE,
      seed = 123L
    ),
    preproc = list(scale_y = TRUE),
    calibration = list(mode = "bias", tail_h = 8L, min_points = 6L),
    metrics = list(probs = c(0.05, 0.50, 0.95))
  ))

  expect_equal(candidate_cfg$readout_approximation, "laplace_delta")

  res <- exdqlm:::bench_qdesn_run_qdesn_series(bundle, candidate_cfg, cfg = cfg, keep_artifacts = TRUE)

  expect_true(res$ok)
  expect_equal(nrow(res$series_metrics), 1L)
  expect_equal(nrow(res$lead_metrics), length(bundle$eval_y))
  expect_equal(nrow(res$forecast_summary), length(bundle$eval_y))
  expect_equal(res$series_metrics$model_name[[1L]], "qdesn_synth")
  expect_equal(res$series_metrics$candidate_id[[1L]], "toy_cfg")
  expect_true(is.matrix(res$artifacts$synth_draws))
  expect_equal(nrow(res$artifacts$synth_draws), length(bundle$eval_y))
  expect_true(length(res$artifacts$fit_seed_set) >= 1L)
  expect_true(res$artifacts$calibration_h >= 0L)
})

test_that("benchmark Q-DESN config rejects non-LD readout approximations", {
  expect_error(
    exdqlm:::bench_qdesn_normalize_model_cfg(list(
      candidate_id = "bad_approx",
      readout_approximation = "gaussian_moment_matching",
      p_vec = c(0.45, 0.50, 0.55)
    )),
    "readout_approximation = 'laplace_delta'"
  )
})

test_that("RHS stability state distinguishes stable, fragile, and collapsed fits", {
  expect_equal(
    exdqlm:::bench_qdesn_rhs_stability_state(
      collapse_flag = FALSE,
      tau_last = 10,
      beta_l2_last = 1
    ),
    "stable"
  )
  expect_equal(
    exdqlm:::bench_qdesn_rhs_stability_state(
      collapse_flag = FALSE,
      tau_last = 1e-8,
      beta_l2_last = 1e-4
    ),
    "fragile_noncollapsed"
  )
  expect_equal(
    exdqlm:::bench_qdesn_rhs_stability_state(
      collapse_flag = TRUE,
      tau_last = 1e-9,
      beta_l2_last = 1e-16
    ),
    "collapsed"
  )
})

test_that("benchmark Q-DESN candidate grid expands into normalized candidate configs", {
  cfg <- list(
    models = list(
      qdesn_synth = list(
        base = list(
          p_vec = c(0.05, 0.50, 0.95),
          fit = list(
            D = 1L,
            n = 24L,
            m = 12L,
            alpha = 0.30,
            rho = 0.90,
            washout = 24L,
            add_bias = TRUE,
            seed = 99L
          )
        ),
        grid = list(
          blocks = list(
            list(
              prefix = "d1",
              values = list(
                fit = list(
                  D = 1L,
                  n = list(c(16L), c(24L)),
                  m = c(12L, 18L),
                  alpha = list(c(0.25), c(0.30)),
                  rho = list(c(0.85), c(0.90))
                )
              ),
              budget = list(
                max_candidates = 3L,
                seed = 123L
              )
            )
          )
        )
      )
    )
  )

  out <- exdqlm:::bench_qdesn_candidate_configs(cfg)

  expect_length(out, 3L)
  expect_equal(length(unique(names(out))), 3L)
  expect_true(all(vapply(out, function(x) x$fit$D == 1L, logical(1))))
})

test_that("Naive2 baseline returns finite point forecasts and draws", {
  withr::local_seed(1)
  train_y <- as.numeric(10 + rep(c(1, 2, 3, 4), 8) + stats::rnorm(32, sd = 0.1))

  res <- exdqlm:::bench_qdesn_run_baseline(
    model_name = "naive2",
    train_y = train_y,
    h = 6L,
    seasonal_period = 4L,
    n_draws = 20L,
    seed = 123L
  )

  expect_equal(length(res$point), 6L)
  expect_equal(dim(res$draws), c(6L, 20L))
  expect_true(all(is.finite(res$point)))
  expect_true(all(is.finite(res$draws)))
})

test_that("forecast-package baselines produce simulated draws when available", {
  testthat::skip_if_not_installed("forecast")
  withr::local_seed(1)
  train_y <- as.numeric(20 + rep(c(1, 2, 3, 4), 12) + stats::rnorm(48, sd = 0.2))

  ets_res <- exdqlm:::bench_qdesn_run_baseline(
    model_name = "ets",
    train_y = train_y,
    h = 6L,
    seasonal_period = 4L,
    n_draws = 12L,
    seed = 123L
  )
  arima_res <- exdqlm:::bench_qdesn_run_baseline(
    model_name = "auto_arima",
    train_y = train_y,
    h = 6L,
    seasonal_period = 4L,
    n_draws = 12L,
    seed = 123L
  )

  expect_equal(dim(ets_res$draws), c(6L, 12L))
  expect_equal(dim(arima_res$draws), c(6L, 12L))
  expect_true(all(is.finite(ets_res$draws)))
  expect_true(all(is.finite(arima_res$draws)))
})

test_that("M4 comparability table computes OWA relative to Naive2", {
  series_metrics <- data.table::data.table(
    dataset = c("m4_monthly", "m4_monthly", "m4_monthly", "m4_monthly"),
    source_family = "m4",
    model_name = c("naive2", "naive2", "qdesn_synth", "qdesn_synth"),
    series_id = c("S1", "S2", "S1", "S2"),
    smape_mean = c(10, 12, 8, 10),
    mase_mean = c(1.0, 1.2, 0.8, 0.9),
    msis95_mean = c(3.0, 3.2, 2.4, 2.6),
    coverage95_mean = c(0.95, 0.95, 0.90, 1.00)
  )

  out <- exdqlm:::bench_qdesn_m4_comparability_table(series_metrics)
  row <- out[dataset == "m4_monthly" & model_name == "qdesn_synth"][1L]

  expect_true(nrow(out) >= 2L)
  expect_equal(row$smape_naive2[[1L]], 11)
  expect_equal(row$mase_naive2[[1L]], 1.1)
  expect_equal(round(row$owa[[1L]], 6), round(0.5 * ((9 / 11) + (0.85 / 1.1)), 6))
})

test_that("audit diagnostics tables are built from saved synthesis artifacts", {
  artifact <- list(
    dataset = "toy_dataset",
    dataset_label = "Toy Dataset",
    source_family = "monash",
    series_id = "S1",
    stage = "test",
    model_name = "qdesn_synth",
    candidate_id = "toy_cfg",
    seasonal_period = 12L,
    forecast_horizon = 4L,
    fit_y = c(10, 11, 12, 13, 14, 15),
    eval_y = c(15.5, 16.2, 16.8, 17.0),
    fit_idx = 1:6,
    eval_idx = 7:10,
    timestamp = seq.Date(as.Date("2000-01-01"), by = "month", length.out = 10),
    timestamp_eval = seq.Date(as.Date("2000-07-01"), by = "month", length.out = 4),
    synth_draws = matrix(
      c(
        15.1, 15.4, 15.6, 15.8,
        15.9, 16.0, 16.3, 16.5,
        16.3, 16.6, 16.8, 17.1,
        16.7, 16.9, 17.0, 17.2
      ),
      nrow = 4L,
      byrow = TRUE
    )
  )

  audit_long <- exdqlm:::bench_qdesn_audit_long_from_artifact(artifact)
  audit_summary <- exdqlm:::bench_qdesn_audit_summary_table(audit_long)
  calib <- exdqlm:::bench_qdesn_audit_calibration_bins(audit_long, n_bins = 4L)

  expect_equal(nrow(audit_long), 4L)
  expect_true(all(c("pit", "coverage95", "interval_width95") %in% names(audit_long)))
  expect_true(nrow(audit_summary) >= 1L)
  expect_true(nrow(calib) >= 1L)
})

test_that("candidate applicability and routing helpers respect fit-length regimes", {
  cfg <- list(
    evaluation = list(
      routing = list(
        enabled = TRUE,
        breaks = c(50L, 200L),
        labels = c("short", "medium", "long")
      )
    )
  )
  candidate_cfg <- exdqlm:::bench_qdesn_normalize_model_cfg(list(
    candidate_id = "route_cfg",
    fit = list(seed = 123L),
    applicability = list(route_keys = c("medium", "long"))
  ))

  expect_equal(exdqlm:::bench_qdesn_route_key_for_fit_n(40L, cfg), "short")
  expect_equal(exdqlm:::bench_qdesn_route_key_for_fit_n(120L, cfg), "medium")
  expect_equal(exdqlm:::bench_qdesn_route_key_for_fit_n(600L, cfg), "long")
  expect_false(exdqlm:::bench_qdesn_candidate_applicable(candidate_cfg, fit_n = 40L, route_key = "short"))
  expect_true(exdqlm:::bench_qdesn_candidate_applicable(candidate_cfg, fit_n = 120L, route_key = "medium"))
})

test_that("fit config normalization recovers YAML boolean-key parsing for quoted reservoir width", {
  fit_cfg <- exdqlm:::bench_qdesn_normalize_fit_cfg(list(
    D = 1L,
    `FALSE` = list(64L),
    m = 12L,
    alpha = 0.30,
    rho = 0.90,
    washout = 24L,
    add_bias = TRUE
  ))

  expect_equal(fit_cfg$n, 64L)
})

test_that("series override helper pins benchmark selection ids by dataset", {
  cfg <- exdqlm:::bench_qdesn_default_cfg(list(
    evaluation = list(
      selection = list(enabled = TRUE),
      series_overrides = list(
        evaluation = list(toy_dataset = c("S2")),
        selection = list(toy_dataset = c("S1")),
        audit = list(toy_dataset = c("S2"))
      )
    )
  ))
  meta_dt <- data.table::data.table(
    dataset = "toy_dataset",
    series_id = c("S1", "S2", "S3")
  )

  expect_equal(
    exdqlm:::bench_qdesn_override_series_ids(meta_dt, cfg, "toy_dataset", "evaluation"),
    "S2"
  )
  expect_equal(
    exdqlm:::bench_qdesn_override_series_ids(meta_dt, cfg, "toy_dataset", "selection"),
    "S1"
  )
  expect_equal(
    exdqlm:::bench_qdesn_override_series_ids(meta_dt, cfg, "toy_dataset", "audit"),
    "S2"
  )
})

test_that("quantile metrics helper summarizes per-quantile pinball and coverage deviations", {
  bundle <- list(
    dataset = "toy_dataset",
    source_family = "monash",
    benchmark_pool = "toy_pool",
    route_key = "global",
    series_id = "S1",
    stage = "validation",
    benchmark_split_protocol = "train_val_test_tail",
    selection_protocol = "stored_monash_validation",
    eval_y = c(1, 2, 3, 4)
  )
  quantile_draws <- list(
    matrix(c(0.5, 0.8, 1.0, 1.2,
             1.0, 1.4, 1.6, 1.8,
             2.0, 2.4, 2.6, 2.8,
             3.0, 3.4, 3.6, 3.8), nrow = 4, byrow = TRUE),
    matrix(c(0.9, 1.0, 1.1, 1.2,
             1.9, 2.0, 2.1, 2.2,
             2.9, 3.0, 3.1, 3.2,
             3.9, 4.0, 4.1, 4.2), nrow = 4, byrow = TRUE),
    matrix(c(1.2, 1.4, 1.6, 1.8,
             2.2, 2.4, 2.6, 2.8,
             3.2, 3.4, 3.6, 3.8,
             4.2, 4.4, 4.6, 4.8), nrow = 4, byrow = TRUE)
  )

  out <- exdqlm:::bench_qdesn_quantile_metrics_table(
    bundle = bundle,
    p_vec = c(0.10, 0.50, 0.90),
    quantile_draws = quantile_draws,
    tail_threshold = 0.10
  )
  summary_row <- exdqlm:::bench_qdesn_quantile_summary_row(out)

  expect_equal(nrow(out), 3L)
  expect_true(all(c("pinball_mean", "abs_coverage_dev", "abs_pit_dev_mean") %in% names(out)))
  expect_true(isTRUE(summary_row$n_quantiles == 3L))
  expect_true(is.finite(summary_row$tail_pinball_mean))
})

test_that("RHS diagnostics detect near-bound tau collapse patterns", {
  prior <- exdqlm::beta_prior(
    "rhs",
    rhs = list(
      tau0 = 10000,
      nu = 4,
      s2 = 10000,
      shrink_intercept = FALSE,
      intercept_prec = 1e-24,
      eta_bounds = list(lambda = c(-12, 12), tau = c(-12, 12), c2 = c(-12, 12)),
      init_log_tau = -12
    )
  )
  state <- prior$init(3L)
  state$eta_lambda_hat <- rep(-5, 3L)
  state$eta_tau_hat <- -12
  state$eta_c_hat <- 0
  qfit <- list(
    fit = list(
      beta_prior = list(type = "rhs", hypers = prior$hypers, state = state),
      qbeta = list(m = c(0, 0, 0))
    )
  )
  candidate_cfg <- exdqlm:::bench_qdesn_normalize_model_cfg(list(
    candidate_id = "rhs_cfg",
    fit = list(seed = 123L),
    vb_args = list(
      beta_prior_type = "rhs",
      beta_rhs = list(
        tau0 = 10000,
        nu = 4,
        s2 = 10000,
        shrink_intercept = FALSE,
        intercept_prec = 1e-24,
        eta_bounds = list(lambda = c(-12, 12), tau = c(-12, 12), c2 = c(-12, 12)),
        init_log_tau = -12
      )
    )
  ))

  out <- exdqlm:::bench_qdesn_rhs_diagnostics_row(qfit, p0 = 0.95, candidate_cfg = candidate_cfg, seed = 123L)

  expect_equal(nrow(out), 1L)
  expect_true(out$near_bound_flag[[1L]])
  expect_true(out$collapse_flag[[1L]])
})

test_that("selection guards can reject collapsing candidates", {
  summary_dt <- data.table::data.table(
    dataset = "toy_dataset",
    route_key = "global",
    candidate_id = c("bad", "good"),
    max_abs_quantile_coverage_dev = c(0.45, 0.10),
    tail_abs_quantile_coverage_dev_max = c(0.50, 0.12),
    max_abs_pit_dev_mean = c(0.30, 0.05),
    rhs_collapse_n = c(1L, 0L),
    rhs_near_bound_n = c(1L, 0L)
  )
  cfg <- list(
    evaluation = list(
      selection = list(
        quantile_guard = list(
          enabled = TRUE,
          max_abs_coverage_dev = 0.35,
          max_abs_tail_coverage_dev = 0.40,
          max_abs_pit_dev_mean = 0.25,
          forbid_rhs_collapse = TRUE,
          forbid_rhs_near_bound = FALSE
        )
      )
    )
  )

  out <- exdqlm:::bench_qdesn_apply_selection_guards(summary_dt, cfg)

  expect_false(out[candidate_id == "bad"]$eligible[[1L]])
  expect_true(out[candidate_id == "good"]$eligible[[1L]])
})

test_that("quantile summary tracks shoulder-pathology ratios separately from tails and center", {
  quantile_metrics <- data.table::data.table(
    quantile_p = c(0.05, 0.20, 0.35, 0.50, 0.65, 0.80, 0.95),
    is_tail = c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE),
    pinball_mean = c(1, 100, 120, 2, 130, 140, 1.5),
    abs_coverage_dev = c(0.02, 0.10, 0.12, 0.03, 0.11, 0.13, 0.02),
    abs_pit_dev_mean = c(0.03, 0.15, 0.18, 0.04, 0.16, 0.17, 0.03),
    qhat_mean = c(-4, -900, -1000, 1, 950, 1100, 5)
  )

  out <- exdqlm:::bench_qdesn_quantile_summary_row(quantile_metrics)

  expect_equal(out$n_quantiles, 7L)
  expect_equal(out$n_tail_quantiles, 2L)
  expect_gt(out$shoulder_pinball_mean, out$reference_pinball_mean)
  expect_gt(out$shoulder_pinball_ratio, 10)
  expect_gt(out$shoulder_qhat_abs_mean, out$reference_qhat_abs_mean)
  expect_gt(out$shoulder_qhat_ratio, 10)
})

test_that("selection guards veto near-bound RHS and shoulder explosions without implicit relaxation", {
  summary_dt <- data.table::data.table(
    dataset = "toy_dataset",
    route_key = "global",
    candidate_id = c("near_bound", "shoulder_blowup"),
    max_abs_quantile_coverage_dev = c(0.10, 0.10),
    tail_abs_quantile_coverage_dev_max = c(0.12, 0.12),
    max_abs_pit_dev_mean = c(0.05, 0.05),
    shoulder_pinball_ratio = c(1.5, 500),
    shoulder_qhat_ratio = c(1.2, 250),
    rhs_collapse_n = c(0L, 0L),
    rhs_near_bound_n = c(1L, 0L)
  )
  cfg <- list(
    evaluation = list(
      selection = list(
        quantile_guard = list(
          enabled = TRUE,
          max_abs_coverage_dev = 0.35,
          max_abs_tail_coverage_dev = 0.40,
          max_abs_pit_dev_mean = 0.25,
          max_shoulder_pinball_ratio = 100,
          max_shoulder_qhat_ratio = 100,
          forbid_rhs_collapse = TRUE,
          forbid_rhs_near_bound = TRUE,
          relax_if_no_eligible_candidates = FALSE
        )
      )
    )
  )

  out <- exdqlm:::bench_qdesn_apply_selection_guards(summary_dt, cfg)

  expect_false(any(out$eligible))
  expect_match(out[candidate_id == "near_bound"]$eligibility_reason[[1L]], "rhs_near_bound")
  expect_match(out[candidate_id == "shoulder_blowup"]$eligibility_reason[[1L]], "shoulder_pinball_explosion")
  expect_match(out[candidate_id == "shoulder_blowup"]$eligibility_reason[[1L]], "shoulder_qhat_explosion")
})

test_that("failure-state writer persists partial benchmark diagnostics", {
  td <- withr::local_tempdir()
  run_dirs <- list(
    run_dir = td,
    tables_dir = file.path(td, "tables"),
    manifests_dir = file.path(td, "manifest"),
    reports_dir = file.path(td, "reports"),
    figures_dir = file.path(td, "figures"),
    artifacts_dir = file.path(td, "artifacts"),
    logs_dir = file.path(td, "logs")
  )
  invisible(lapply(run_dirs[-1L], dir.create, recursive = TRUE, showWarnings = FALSE))

  partial_results <- list(
    series_metrics = data.table::data.table(),
    lead_metrics = data.table::data.table(),
    forecast_summary = data.table::data.table(),
    quantile_model_metrics = data.table::data.table(
      dataset = "toy_dataset",
      series_id = "S1",
      quantile_p = 0.50,
      pinball_mean = 1
    ),
    rhs_diagnostics = data.table::data.table(
      dataset = "toy_dataset",
      series_id = "S1",
      quantile_p = 0.50,
      collapse_flag = TRUE
    ),
    series_status = data.table::data.table(),
    model_selection_summary = data.table::data.table(
      dataset = "toy_dataset",
      route_key = "global",
      candidate_id = "bad_cfg",
      eligible = FALSE,
      eligibility_reason = "rhs_collapse",
      selection_failed = TRUE,
      selection_error_message = "No successful validation runs."
    ),
    model_selection_detail = data.table::data.table(
      dataset = "toy_dataset",
      route_key = "global",
      series_id = "S1",
      candidate_id = "bad_cfg",
      selection_failed = TRUE,
      selection_error_message = "No successful validation runs."
    ),
    candidate_registry = data.table::data.table(candidate_id = "bad_cfg"),
    m4_comparability = data.table::data.table()
  )

  exdqlm:::bench_qdesn_write_failure_state(
    run_dirs = run_dirs,
    failure = list(
      type = "selection_error",
      dataset = "toy_dataset",
      route_key = "global",
      selection_metric = "crps_mean",
      message = "No successful validation runs.",
      veto_counts = list(rhs_collapse = 1L)
    ),
    partial_results = partial_results,
    summary_dt = data.table::data.table()
  )

  expect_true(file.exists(file.path(run_dirs$logs_dir, "failure_state.json")))
  expect_true(file.exists(file.path(run_dirs$logs_dir, "failure_state.yaml")))
  expect_true(file.exists(file.path(run_dirs$logs_dir, "failure_state.txt")))
  expect_true(file.exists(file.path(run_dirs$tables_dir, "model_selection_summary.rds")))
  expect_true(file.exists(file.path(run_dirs$tables_dir, "model_selection_detail.rds")))
  expect_true(file.exists(file.path(run_dirs$tables_dir, "quantile_model_metrics.rds")))
  expect_true(file.exists(file.path(run_dirs$tables_dir, "rhs_diagnostics.rds")))
})

test_that("candidate registry records RHS benchmark settings", {
  candidate_cfgs <- exdqlm:::bench_qdesn_candidate_configs(list(
    models = list(
      qdesn_synth = list(
        base = list(
          p_vec = c(0.05, 0.50, 0.95),
          fit = list(seed = 99L),
          vb_args = list(
            beta_prior_type = "rhs",
            rhs = list(
              freeze_tau_iters = 25L,
              freeze_tau_warmup_iters = 25L
            ),
            beta_rhs = list(
              tau0 = 5000,
              nu = 4,
              s2 = 5000,
              init_log_tau = -1
            )
          )
        )
      )
    )
  ))

  reg <- exdqlm:::bench_qdesn_candidate_registry_table(candidate_cfgs)

  expect_equal(reg$vb_beta_prior_type[[1L]], "rhs")
  expect_equal(reg$vb_rhs_tau0[[1L]], 5000)
  expect_equal(reg$vb_rhs_init_log_tau[[1L]], -1)
  expect_equal(reg$vb_rhs_freeze_tau_iters[[1L]], 25L)
  expect_equal(reg$vb_rhs_freeze_tau_warmup_iters[[1L]], 25L)
})

test_that("Stage A RHS summary flags collapse and ranks non-collapsing candidates first", {
  selection_summary <- data.table::data.table(
    dataset = c("toy_dataset", "toy_dataset"),
    route_key = c("global", "global"),
    candidate_id = c("good_rhs", "bad_rhs"),
    n_series = 1L,
    n_applicable = 1L,
    n_failed = 0L,
    n_inapplicable = 0L,
    runtime_sec = c(10, 20),
    selected = c(TRUE, FALSE)
  )
  quantile_model_metrics <- data.table::data.table(
    dataset = rep("toy_dataset", 6L),
    route_key = rep("global", 6L),
    candidate_id = rep(c("good_rhs", "bad_rhs"), each = 3L),
    series_id = rep("S1", 6L),
    stage = rep("validation", 6L),
    quantile_p = rep(c(0.45, 0.50, 0.55), 2L),
    quantile_label = rep(c("0.450", "0.500", "0.550"), 2L),
    pinball_mean = c(1, 0.8, 1.1, 4, 3.5, 4.2),
    abs_coverage_dev = c(0.05, 0.02, 0.06, 0.40, 0.35, 0.45),
    abs_pit_dev_mean = c(0.04, 0.02, 0.05, 0.30, 0.25, 0.35)
  )
  rhs_diagnostics <- data.table::data.table(
    dataset = rep("toy_dataset", 6L),
    route_key = rep("global", 6L),
    candidate_id = rep(c("good_rhs", "bad_rhs"), each = 3L),
    series_id = rep("S1", 6L),
    stage = rep("validation", 6L),
    tau_last = c(0.8, 0.9, 1.0, 1e-9, 1e-9, 1e-9),
    beta_l2_last = c(0.2, 0.3, 0.4, 1e-16, 1e-16, 1e-16),
    E_invV_med_last = c(10, 12, 14, 1e18, 1e18, 1e18),
    collapse_flag = c(FALSE, FALSE, FALSE, TRUE, TRUE, TRUE),
    near_bound_flag = c(FALSE, FALSE, FALSE, TRUE, TRUE, TRUE)
  )
  candidate_registry <- data.table::data.table(
    candidate_id = c("good_rhs", "bad_rhs"),
    p_vec = c("0.45|0.5|0.55", "0.45|0.5|0.55"),
    fit_D = c(1L, 1L),
    fit_n = c("32", "32"),
    fit_m = c(12L, 12L),
    fit_rho = c("0.9", "0.9"),
    fit_washout = c(24L, 24L),
    vb_rhs_tau0 = c(1, 0.001),
    vb_rhs_s2 = c(1, 0.1),
    vb_rhs_init_log_tau = c(0, NA_real_),
    vb_rhs_freeze_tau_iters = c(50L, 20L),
    vb_rhs_freeze_tau_warmup_iters = c(50L, 20L)
  )

  candidate_summary <- exdqlm:::bench_qdesn_rhs_stageA_candidate_summary(
    selection_summary = selection_summary,
    quantile_model_metrics = quantile_model_metrics,
    rhs_diagnostics = rhs_diagnostics,
    candidate_registry = candidate_registry,
    stage = "validation"
  )
  overall_summary <- exdqlm:::bench_qdesn_rhs_stageA_overall_summary(candidate_summary)

  expect_true(candidate_summary[candidate_id == "good_rhs"]$stageA_pass[[1L]])
  expect_false(candidate_summary[candidate_id == "bad_rhs"]$stageA_pass[[1L]])
  expect_equal(candidate_summary[stageA_rank == 1L]$candidate_id[[1L]], "good_rhs")
  expect_equal(overall_summary[stageA_overall_rank == 1L]$candidate_id[[1L]], "good_rhs")
})

test_that("route map helper returns only series assigned to the requested route", {
  route_map <- data.table::data.table(
    dataset = "toy_dataset",
    series_id = c("S1", "S2", "S3", "S4"),
    route_key = c("short", "medium", "medium", "long")
  )

  out <- exdqlm:::bench_qdesn_series_ids_for_route(route_map, c("S1", "S2", "S4"), "medium")
  expect_equal(out, "S2")
})

test_that("internal recalibration returns transformed draws when enabled", {
  candidate_cfg <- exdqlm:::bench_qdesn_normalize_model_cfg(list(
    candidate_id = "cal_cfg",
    fit = list(
      D = 1L,
      n = 12L,
      m = 4L,
      alpha = 0.30,
      rho = 0.90,
      washout = 4L,
      add_bias = TRUE,
      seed = 123L
    ),
    vb_args = list(
      max_iter = 5L,
      min_iter_elbo = 2L,
      tol = 1e-3,
      n_samp_xi = 30L,
      verbose = FALSE
    ),
    sampling = list(
      nd_draws = 20L,
      chunk = 10L
    ),
    synthesis = list(
      n_samp = 24L,
      grid_M = 41L,
      isotonic = TRUE,
      rearrange = FALSE,
      seed = 123L
    ),
    calibration = list(mode = "affine", tail_h = 6L, min_points = 4L)
  ))
  cfg <- list(
    evaluation = list(
      selection = list(min_train_points = 10L)
    )
  )
  fit_y <- seq(10, 40, length.out = 30)
  target_draws <- matrix(rep(seq(20, 25, length.out = 4), each = 20), nrow = 4)

  recal <- exdqlm:::bench_qdesn_recalibrate_draws(
    fit_y = fit_y,
    candidate_cfg = candidate_cfg,
    cfg = cfg,
    seed_tag = "toy",
    target_draws = target_draws,
    forecast_horizon = 4L
  )

  expect_true(is.matrix(recal$draws))
  expect_equal(nrow(recal$draws), 4L)
  expect_true(recal$cal_h >= 0L)
  expect_true(recal$recalibration$mode %in% c("affine", "bias", "none"))
})
