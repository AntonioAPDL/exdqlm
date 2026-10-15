testthat::test_that("the reporting policy prohibits new inference and historical deletion", {
  path <- file.path(ifr_repo, "validation/fitforecast_v2/config/independent_forecast_reporting_300_500_v1.json")
  p <- ifr_policy(path)
  testthat::expect_equal(p$primary_cutoff, 300L)
  testthat::expect_equal(p$sensitivity_cutoff, 500L)
  for (field in c("allow_refit", "allow_forecast_resimulation", "allow_winner_reselection")) {
    invalid <- p; invalid[[field]] <- TRUE
    tmp <- tempfile(fileext = ".json"); jsonlite::write_json(invalid, tmp, auto_unbox = TRUE)
    testthat::expect_error(ifr_policy(tmp), "authorized scope")
  }
  invalid <- p; invalid$retain_historical_evidence <- FALSE
  tmp <- tempfile(fileext = ".json"); jsonlite::write_json(invalid, tmp, auto_unbox = TRUE)
  testthat::expect_error(ifr_policy(tmp), "authorized scope")
})

ifr_fixture <- function() {
  x <- expand.grid(inference = "mcmc", family = ifr_families, tau = ifr_levels,
    model_variant = ifr_models, metric_role = ifr_metrics, cutoff = c(300L, 500L), stringsAsFactors = FALSE)
  x$replay_id <- paste(x$family, x$tau, x$model_variant, x$metric_role)
  x$forecast_pairs <- x$cutoff; x$forecast_origins <- ceiling(x$cutoff / 30)
  x$last_target <- 9000L + x$cutoff
  x$posterior_mean <- 2; x$posterior_median <- 2; x$cri_lower <- 1; x$cri_upper <- 3
  x$n_draws <- 12000L; x$n_chains <- 3L
  x
}

testthat::test_that("publication requires all models and exactly the authorized windows", {
  p <- ifr_policy(file.path(ifr_repo, "validation/fitforecast_v2/config/independent_forecast_reporting_300_500_v1.json"))
  x <- ifr_fixture()
  testthat::expect_true(ifr_check_display(x, p))
  testthat::expect_error(ifr_check_display(x[-1L, ], p), "144 approved")
  invalid <- x; invalid$cutoff[1L] <- 1000L
  testthat::expect_error(ifr_check_display(invalid, p), "deprecated window")
  invalid <- x; invalid$inference[1L] <- "vb"
  testthat::expect_error(ifr_check_display(invalid, p), "144 approved")
  invalid <- x; invalid$replay_id[1L] <- "another_source"
  testthat::expect_error(ifr_check_display(invalid, p), "Source selection")
  invalid <- x; invalid$n_chains[1L] <- 2L
  testthat::expect_error(ifr_check_display(invalid, p), "draws, intervals")
  invalid <- x; invalid$posterior_mean[1L] <- Inf
  testthat::expect_error(ifr_check_display(invalid, p), "draws, intervals")
  invalid <- x; invalid$last_target[1L] <- 9301L
  testthat::expect_error(ifr_check_display(invalid, p), "forecast grid")
})

testthat::test_that("fit-only validation is not confused with a forecast window", {
  x <- ifr_fixture(); x <- x[x$cutoff == 300L & x$metric_role == "forecast_mae", ]
  x$metric_role <- "fit_rmse"
  vb <- x; vb$inference <- "vb"
  x <- rbind(x, vb)
  testthat::expect_true(ifr_check_fit(x))
  testthat::expect_error(ifr_check_fit(x[-1L, ]), "fit surface")
})

testthat::test_that("prefix scores weight targets rather than partial origins", {
  grid <- fpf_grid(n = 500L)
  testthat::expect_equal(length(unique(grid$origin[1:300])), 10L)
  testthat::expect_equal(length(unique(grid$origin)), 17L)
  testthat::expect_equal(tail(grid$lead, 1), 20L)
  q <- matrix(rep(c(rep(1, 480), rep(10, 20)), 2L), ncol = 2L)
  d <- fpf_score_paths(q, grid, rep(0, 500), rep(0, 500), .5, cutoffs = c(300L, 500L), origin_snapshots = FALSE)
  testthat::expect_equal(d$forecast_mae[d$cutoff == 500], rep((480 + 200) / 500, 2))
  testthat::expect_false(isTRUE(all.equal((480 + 200) / 500, (16 + 10) / 17)))
  testthat::expect_equal(d$forecast_check_loss, .5 * d$forecast_mae)
})

testthat::test_that("posterior metric means and limits are draw-wise and source specific", {
  grid <- fpf_grid(n = 300L)
  q <- matrix(rep(c(-2, 2, -1, 1), each = 300L), nrow = 300L)
  d <- fpf_score_paths(q, grid, rep(0, 300), rep(0, 300), .25,
    cutoffs = 300L, origin_snapshots = FALSE)
  s7 <- fpf_pool(d, 7L); s8 <- fpf_pool(d, 8L)
  testthat::expect_equal(s7$posterior_mean[s7$metric == "forecast_mae"], 1.5)
  testthat::expect_equal(mean(abs(rowMeans(q))), 0)
  testthat::expect_equal(s7$quantile_type, rep(7L, 2L))
  testthat::expect_equal(s8$quantile_type, rep(8L, 2L))
  testthat::expect_equal(s7$cri_lower[s7$metric == "forecast_check_loss"],
    unname(quantile(d$forecast_check_loss, .025, type = 7L)))
})

testthat::test_that("DGP population check references agree with independent quadrature", {
  for (f in ifr_families) for (p in ifr_levels) {
    testthat::expect_equal(idor_v1_expected_check_analytic(f, p),
      idor_v1_expected_check_numerical(f, p), tolerance = 1e-6)
  }
})
