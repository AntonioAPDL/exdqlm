testthat::test_that("origin-horizon attribution exactly reconstructs aggregate metrics", {
  n_draw <- 40L
  origin <- c(rep(seq(9000, 9960, by = 30), each = 30), rep(9990, 10))
  lead <- c(rep(1:30, 33), 1:10)
  target <- 9001:10000
  q_true <- sin(target / 17)
  y <- q_true + cos(target / 13)
  draw_shift <- seq(-0.4, 0.4, length.out = n_draw)
  q <- outer(q_true, rep(1, n_draw)) +
    outer((lead - 15) / 30, draw_shift) +
    outer(rep(1, length(q_true)), draw_shift)
  error <- sweep(q, 1L, q_true, "-")
  check <- .qdesn_validation_metric_check_loss(
    matrix(y, nrow = length(y), ncol = n_draw), q, 0.25
  )
  draws <- data.frame(
    chain_id = 1L, draw_id = seq_len(n_draw),
    source_draw_index = seq_len(n_draw), fit_rmse = 1,
    forecast_mae = colMeans(abs(error)),
    forecast_check_loss = colMeans(check),
    stringsAsFactors = FALSE
  )
  attr(draws, "metric_dispersion_context") <- list(
    native_q = q, plugin_q = q, q_true = q_true, y = y,
    grid = data.frame(
      origin_sequence_id = match(origin, unique(origin)),
      forecast_origin_source_index = origin,
      forecast_lead = lead, target_source_index = target
    ),
    tau = 0.25,
    draw_parameters = data.frame(
      source_draw_index = seq_len(n_draw), beta_intercept = draw_shift,
      beta_norm = abs(draw_shift), sigma = 1, gamma = 0
    ),
    posterior_source_draw_index = seq_len(n_draw), fit = NULL
  )
  defaults <- list(metrics = list(posterior_metric_intervals = list(
    origin_horizon_attribution = list(
      enabled = TRUE, required = TRUE, balanced_complete_origins = TRUE
    )
  )))
  out <- .qdesn_validation_origin_horizon_artifacts(draws, defaults)
  testthat::expect_equal(nrow(out$group_draws), 5640L)
  testthat::expect_setequal(unique(out$group_draws$scope),
                            c("all_targets", "balanced_complete_origins"))
  testthat::expect_true(all(out$reconstruction_audit$pass))
  testthat::expect_lte(
    max(out$reconstruction_audit$forecast_mae_max_abs_error), 1e-12
  )
  testthat::expect_equal(
    sum(out$path_structure$fraction), 1, tolerance = 1e-10
  )
  testthat::expect_equal(nrow(out$target_summary), 1000L)
  testthat::expect_true(all(c("origin", "lead", "lead_band") %in%
                              unique(out$variance_decomposition$group_type)))
})

testthat::test_that("origin-horizon writer is storage-light and self-hashing", {
  n_draw <- 12L
  origin <- c(rep(seq(9000, 9960, by = 30), each = 30), rep(9990, 10))
  lead <- c(rep(1:30, 33), 1:10)
  q_true <- rep(0, 1000L)
  q <- outer(rep(1, 1000L), seq(-0.2, 0.2, length.out = n_draw))
  y <- rep(c(-1, 1), 500L)
  draws <- data.frame(
    chain_id = 1L, draw_id = seq_len(n_draw),
    source_draw_index = seq_len(n_draw), fit_rmse = 1,
    forecast_mae = colMeans(abs(q)),
    forecast_check_loss = colMeans(.qdesn_validation_metric_check_loss(
      matrix(y, nrow = 1000L, ncol = n_draw), q, 0.5
    ))
  )
  attr(draws, "metric_dispersion_context") <- list(
    native_q = q, plugin_q = q, q_true = q_true, y = y,
    grid = data.frame(
      origin_sequence_id = match(origin, unique(origin)),
      forecast_origin_source_index = origin,
      forecast_lead = lead, target_source_index = 9001:10000
    ),
    tau = 0.5,
    draw_parameters = data.frame(source_draw_index = seq_len(n_draw)),
    posterior_source_draw_index = seq_len(n_draw), fit = NULL
  )
  defaults <- list(metrics = list(posterior_metric_intervals = list(
    origin_horizon_attribution = list(enabled = TRUE, required = TRUE)
  )))
  root <- tempfile("origin-horizon-writer-")
  dir.create(root)
  result <- .qdesn_validation_write_origin_horizon_attribution(
    draws, root, defaults
  )
  testthat::expect_identical(result$status, "PASS")
  manifest <- jsonlite::read_json(result$manifest_path, simplifyVector = TRUE)
  testthat::expect_false(manifest$full_forecast_draw_matrix_retained)
  testthat::expect_true(all(file.exists(unname(unlist(manifest$artifact_paths)))))
  testthat::expect_false(any(list.files(root, pattern = "[.](rds|rda|RData)$",
                                        recursive = TRUE, ignore.case = TRUE)))
})

testthat::test_that("origin-horizon campaign remains lane scoped and staged", {
  selection <- imoh_v1_read_selection(repo_root)
  testthat::expect_equal(nrow(selection), 7L)
  testthat::expect_equal(sum(selection$pilot_selected), 2L)
  testthat::expect_setequal(selection$replay_id[selection$pilot_selected],
                            c("imi_v1_source_055", "imi_v1_source_078"))
  scripts <- file.path(harness_root, "scripts", c(
    "materialize_independent_origin_horizon_attribution_v1.R",
    "verify_independent_origin_horizon_attribution_v1_plan.R",
    "closeout_independent_origin_horizon_attribution_v1.R",
    "run_independent_origin_horizon_attribution_v1_pipeline.sh"
  ))
  testthat::expect_true(all(file.exists(scripts)))
  text <- paste(unlist(lapply(scripts, readLines, warn = FALSE)), collapse = "\n")
  testthat::expect_false(grepl("git push origin main", text, fixed = TRUE))
  testthat::expect_false(grepl("Article-Q-DESN---Version-2/main.tex", text,
                               fixed = TRUE))
  testthat::expect_match(text, "no_automatic_tau0_launch", fixed = TRUE)
  testthat::expect_match(text, "OMP_NUM_THREADS=1", fixed = TRUE)
})
