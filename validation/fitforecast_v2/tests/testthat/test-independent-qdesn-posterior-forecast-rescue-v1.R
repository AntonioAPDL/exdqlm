testthat::test_that("posterior rescue protocol protects the scientific lane", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_posterior_forecast_rescue_v1.R"))
  protocol <- iqpfr_v1_read_protocol(repo_root)
  testthat::expect_true(all(iqpfr_v1_protocol_checks(protocol)$pass))
  cells <- iqpfr_v1_hard_cells(protocol)
  testthat::expect_equal(nrow(cells), 17L)
  testthat::expect_false(any(
    cells$family == "laplace" & cells$tau == 0.05 &
      cells$likelihood_family == "al"
  ))
  testthat::expect_false(protocol$protocol$article_write_permitted)
  testthat::expect_false(
    protocol$selection$sealed_window_access_before_finalist_freeze
  )
})

testthat::test_that("candidate mining is nonduplicated and broadly supported", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_posterior_forecast_rescue_v1.R"))
  protocol <- iqpfr_v1_read_protocol(repo_root)
  testthat::expect_true(all(iqpfr_v1_verify_authorities(protocol)$pass))
  pool <- iqpfr_v1_build_candidate_pool(repo_root, protocol)
  testthat::expect_equal(nrow(pool), 180L)
  testthat::expect_true(all(table(pool$family) == 60L))
  testthat::expect_identical(anyDuplicated(pool$candidate_id), 0L)
  testthat::expect_identical(anyDuplicated(pool$candidate_signature), 0L)
  novel <- pool[grepl("^novel_", pool$candidate_origin), , drop = FALSE]
  testthat::expect_equal(nrow(novel), 30L)
  testthat::expect_true(all(table(novel$family) == 10L))
  testthat::expect_lte(min(novel$alpha), 0.30)
  testthat::expect_gte(max(novel$alpha), 0.80)
  testthat::expect_lte(min(novel$rho), 0.40)
  testthat::expect_gte(max(novel$rho), 0.80)
  for (x in split(novel, novel$family)) {
    testthat::expect_lte(min(x$rhs_tau0), 0.03)
    testthat::expect_gte(max(x$rhs_tau0), 10)
  }
})

testthat::test_that("screen ranking is forecast-first and cell specific", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_posterior_forecast_rescue_v1.R"))
  x <- data.frame(
    family = "normal", tau = 0.25, likelihood_family = "exal",
    candidate_id = c("a", "b", "c"),
    estimator = "mean_readout_state_recursive",
    forecast_qtrue_mae_mean = c(2, 1, 3),
    forecast_qtrue_mae_lower = c(1, 0.5, 2),
    forecast_qtrue_mae_upper = c(3, 1.5, 4),
    forecast_check_loss_mean = c(1, 100, 0.5),
    fit_qtrue_rmse_mean = c(1, 10, 0.5), stringsAsFactors = FALSE
  )
  ranked <- iqpfr_v1_rank_screen(x)
  testthat::expect_identical(ranked$candidate_id, c("b", "a", "c"))
  testthat::expect_identical(ranked$selection_rank, 1:3)
})

testthat::test_that("MCMC metric accumulator accepts an explicit source offset", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  lattice <- list(mu_by_origin = list(matrix(c(1, 2, 1.5, 2.5), nrow = 2)))
  x <- data.frame(t = 101:103, q_target = c(0, 1, 2), y = c(0, 1, 2))
  out <- iqfr_v2_draw_metric_accumulator(
    lattice, origins_local = 0L, x = x, tau = 0.5, source_offset = 101L
  )
  testthat::expect_equal(out$pairs, 2L)
  testthat::expect_equal(unique(out$point$source_origin), 101L)
  testthat::expect_equal(out$point$source_target, 102:103)
})
