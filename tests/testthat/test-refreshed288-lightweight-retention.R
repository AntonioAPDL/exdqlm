source_refreshed288_helpers_for_test <- function() {
  repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/", mustWork = TRUE)
  old <- setwd(repo_root)
  on.exit(setwd(old), add = TRUE)
  source("tools/merge_reports/LOCAL_refreshed288_helpers_20260422_p90_full288.R", local = parent.frame())
}

test_that("refreshed288 plot summaries preserve fitted quantile bands", {
  source_refreshed288_helpers_for_test()

  row <- data.frame(
    row_id = 1L,
    original_case_key = "dynamic::normal::0p50::5::default::dqlm::vb",
    block = "dynamic",
    root_kind = "dynamic",
    family = "normal",
    tau = 0.5,
    tau_label = "0p50",
    fit_size = 5L,
    prior_semantics = "default",
    model = "dqlm",
    inference = "vb",
    stringsAsFactors = FALSE
  )
  draws <- matrix(rep(1:5, times = 4L), nrow = 5L)
  out <- plot_summary_from_draws_refreshed288(
    row = row,
    y = 1:5,
    q_true = 1:5,
    draw_mat = draws,
    source_index = 101:105
  )

  expect_equal(nrow(out), 5L)
  expect_equal(out$q_fit_tau, as.numeric(1:5))
  expect_equal(out$pred_q500, as.numeric(1:5))
  expect_true(all(out$covered95))
  expect_equal(out$source_index, 101:105)
})

test_that("refreshed288 static parameter summaries keep beta truth alignment", {
  source_refreshed288_helpers_for_test()

  row <- data.frame(
    row_id = 2L,
    original_case_key = "static_paper::normal::0p50::4::paper::exal::mcmc",
    block = "static",
    root_kind = "static_paper",
    family = "normal",
    tau = 0.5,
    tau_label = "0p50",
    fit_size = 4L,
    prior_semantics = "paper",
    model = "exal",
    inference = "mcmc",
    stringsAsFactors = FALSE
  )
  beta_draws <- matrix(
    c(
      1, 2, 0,
      1, 3, 0,
      1, 4, 0,
      1, 5, 0
    ),
    ncol = 3L,
    byrow = TRUE
  )
  colnames(beta_draws) <- c("(Intercept)", "x01", "x02")
  coef_truth <- data.frame(
    term = c("x01", "x02"),
    beta_truth = c(3.5, 0),
    is_signal = c(TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  design <- list(
    y = c(1, 2, 3, 4),
    X_slopes = matrix(c(1, 2, 3, 4, 0, 1, 0, 1), ncol = 2L),
    X = matrix(1, nrow = 4L, ncol = 3L)
  )
  colnames(design$X_slopes) <- c("x01", "x02")

  out <- parameter_summary_from_static_draws_refreshed288(
    row = row,
    beta_draws = beta_draws,
    sigma_draws = c(1, 2, 3, 4),
    gamma_draws = c(-0.2, 0, 0.2, 0.4),
    coef_truth = coef_truth,
    design = design
  )

  expect_true(all(c("beta", "sigma", "gamma") %in% out$parameter_group))
  x01 <- out[out$parameter_group == "beta" & out$term == "x01", , drop = FALSE]
  expect_equal(x01$truth, 3.5)
  expect_true(x01$is_signal)
  expect_true(isTRUE(x01$covered95))
  expect_true(is.finite(x01$p_abs_standardized_gt_0p1))
})

test_that("refreshed288 retention policy defaults to comparison plus plot", {
  source_refreshed288_helpers_for_test()

  policy <- retention_policy_refreshed288()
  expect_equal(policy$mode, "comparison_plus_plot")
  expect_true(policy$write_plot_summary)
  expect_false(policy$retain_candidate_fit_binaries)
  expect_false(policy$retain_draw_binaries)
  expect_false(policy$retain_vb_init_binaries)
})
