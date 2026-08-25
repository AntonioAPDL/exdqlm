testthat::test_that("dispersion diagnostics reproduce primary draws and isolate recursion", {
  n_target <- 12L
  n_draw <- 40L
  q_true <- seq(-0.5, 0.5, length.out = n_target)
  y <- q_true + rep(c(-0.2, 0.3), length.out = n_target)
  common <- seq(-1, 1, length.out = n_draw)
  native_q <- outer(q_true, rep(1, n_draw)) +
    outer(rep(1, n_target), common)
  plugin_q <- outer(q_true, rep(1, n_draw)) +
    outer(rep(1, n_target), 0.2 * common)
  native <- .qdesn_validation_dispersion_metric_vectors(native_q, q_true, y, 0.25)
  draws <- data.frame(
    chain_id = 1L,
    draw_id = seq_len(n_draw),
    source_draw_index = seq_len(n_draw),
    fit_rmse = rep(1, n_draw),
    forecast_mae = native$forecast_mae,
    forecast_check_loss = native$forecast_check_loss
  )
  attr(draws, "metric_dispersion_context") <- list(
    schema_version = imid_v1_schema,
    native_q = native_q,
    plugin_q = plugin_q,
    q_true = q_true,
    y = y,
    grid = data.frame(
      origin_sequence_id = rep(1:4, each = 3),
      forecast_origin_source_index = rep(seq(9000, 9090, by = 30), each = 3),
      forecast_lead = rep(1:3, 4),
      target_source_index = 9001:9012
    ),
    tau = 0.25,
    draw_parameters = data.frame(
      source_draw_index = seq_len(n_draw), beta_intercept = common,
      beta_norm = abs(common), sigma = rep(1, n_draw), gamma = rep(0, n_draw)
    ),
    posterior_source_draw_index = seq_len(n_draw),
    fit = NULL,
    recursion_contract = list(same_posterior_draws = TRUE)
  )
  coupling <- rbind(
    data.frame(chain_id = 1L, draw_id = seq_len(n_draw),
               coupling_mode = "native_aligned",
               forecast_mae = native$forecast_mae,
               forecast_check_loss = native$forecast_check_loss),
    data.frame(chain_id = 1L, draw_id = seq_len(n_draw),
               coupling_mode = "origin_independent_permutation",
               forecast_mae = 0.3 * native$forecast_mae,
               forecast_check_loss = 0.3 * native$forecast_check_loss)
  )
  out <- .qdesn_validation_metric_dispersion_artifacts(draws, coupling)
  testthat::expect_equal(out$draw_diagnostics$forecast_mae_native,
                         draws$forecast_mae)
  testthat::expect_lt(out$mechanism_summary$plugin_to_native_width_ratio, 0.5)
  testthat::expect_true(out$mechanism_summary$same_posterior_draws)
  testthat::expect_equal(nrow(out$target_summary), n_target)
  testthat::expect_true(all(c("lead", "origin") %in%
                              unique(out$group_summary$group_type)))
})

testthat::test_that("sentinel authority and launch scripts remain lane scoped", {
  selection <- imid_v1_read_selection(repo_root)
  testthat::expect_equal(nrow(selection), 7L)
  testthat::expect_setequal(unique(selection$family), c("normal", "laplace", "gausmix"))
  testthat::expect_true(all(selection$model_variant %in%
                              c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")))
  scripts <- file.path(harness_root, "scripts", c(
    "materialize_independent_interval_dispersion_diagnostic_v1.R",
    "verify_independent_interval_dispersion_diagnostic_v1_plan.R",
    "closeout_independent_interval_dispersion_diagnostic_v1.R",
    "run_independent_interval_dispersion_diagnostic_v1_pipeline.sh"
  ))
  testthat::expect_true(all(file.exists(scripts)))
  text <- paste(unlist(lapply(scripts, readLines, warn = FALSE)), collapse = "\n")
  testthat::expect_false(grepl("Article-Q-DESN---Version-2/main.tex", text, fixed = TRUE))
  testthat::expect_false(grepl("git push origin main", text, fixed = TRUE))
  testthat::expect_match(text, "conditional_mean_plugin", fixed = TRUE)
  testthat::expect_match(text, "OMP_NUM_THREADS=1", fixed = TRUE)
})

testthat::test_that("both pipeline entrypoints export the recursion counterfactual", {
  pipelines <- file.path(repo_root, "scripts", c(
    "pipeline_sim_main.R",
    "pipeline_real_main.R"
  ))
  testthat::expect_true(all(file.exists(pipelines)))
  for (pipeline in pipelines) {
    text <- paste(readLines(pipeline, warn = FALSE), collapse = "\n")
    testthat::expect_match(text, "dispersion_diagnostic", fixed = TRUE)
    testthat::expect_match(text, "recursion_mode = \"conditional_mean_plugin\"",
                           fixed = TRUE)
    testthat::expect_match(text, "mu_by_origin_conditional_mean_plugin",
                           fixed = TRUE)
    testthat::expect_match(text, "dispersion_diagnostic_contract", fixed = TRUE)
  }
})

testthat::test_that("tau0-only follow-up is mechanism gated", {
  pooled <- data.frame(
    replay_id = c("a", "b"), model_variant = "qdesn_al_rhs_ns",
    family = "normal", tau = c(0.05, 0.25),
    mechanism = c("recursive_innovation_dominant", "posterior_parameter_scale_dominant"),
    recommended_next_stage = c("review", "prior"),
    tau0_only_screen_authorized = c(FALSE, TRUE)
  )
  gate <- imid_v1_followup_gate(pooled)
  testthat::expect_identical(gate$tau0_only_screen_authorized, c(FALSE, TRUE))
  testthat::expect_false(any(gate$automatic_followup_launch_authorized))
  testthat::expect_false(any(gate$article_update_authorized))
})
