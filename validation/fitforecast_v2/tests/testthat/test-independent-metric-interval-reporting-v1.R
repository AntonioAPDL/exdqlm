testthat::test_that("v10 reporting input is a complete factorial interval record", {
  roles <- imir_v1_read_roles(repo_root)
  plot_data <- imir_v1_prepare_plot_data(roles)
  checks <- imir_v1_contract_checks(plot_data)
  testthat::expect_equal(nrow(plot_data), 216L)
  testthat::expect_true(all(checks$pass), info = paste(checks$check[!checks$pass], collapse = ", "))
  testthat::expect_equal(as.integer(table(plot_data$inference)), c(108L, 108L))
  testthat::expect_equal(as.integer(table(plot_data$inference, plot_data$metric_role)),
                         rep(36L, 6L))
})

testthat::test_that("native estimator contracts are explicit and do not claim a common copula", {
  ledger <- imir_v1_contract_ledger()
  testthat::expect_equal(nrow(ledger), 2L)
  testthat::expect_true(all(ledger$implementation_status ==
                              "MATCHES_DECLARED_NATIVE_CONTRACT"))
  testthat::expect_true(all(ledger$primary_interval_status == "RETAIN"))
  testthat::expect_false(any(ledger$response_predictive_draws_used))
  testthat::expect_match(
    ledger$forecast_draw_contract[ledger$engine == "dqlm"],
    "product coupling", fixed = TRUE
  )
})

testthat::test_that("fresh-chain replay uses statistical rather than deterministic equivalence", {
  replay_path <- file.path(
    repo_root, "reports", "shared_fitforecast_v2_orchestration",
    "independent_metric_interval_coupling_pilot_v1_20260825_000726", "closeout",
    "primary_replay_vs_v10.csv"
  )
  testthat::skip_if_not(file.exists(replay_path), "Completed pilot runtime evidence unavailable")
  out <- imir_v1_fresh_chain_equivalence(ffv2_read_csv(replay_path))
  testthat::expect_equal(nrow(out), 22L)
  testthat::expect_equal(sum(out$deterministic_all_summary_match), 8L)
  testthat::expect_true(all(out$fresh_chain_statistical_equivalence))
  testthat::expect_lte(max(out$standardized_mean_difference), 0.10)
  testthat::expect_gte(min(out$interval_overlap_fraction), 0.95)
})

testthat::test_that("figure factory covers every inference and metric without changing values", {
  roles <- imir_v1_read_roles(repo_root)
  plot_data <- imir_v1_prepare_plot_data(roles)
  spec <- imir_v1_figure_spec()
  testthat::expect_equal(nrow(spec), 6L)
  testthat::expect_true(all(spec$expected_rows == 36L))
  for (i in seq_len(nrow(spec))) {
    block <- plot_data[plot_data$inference == spec$inference[[i]] &
                         plot_data$metric_role == spec$metric_role[[i]], , drop = FALSE]
    testthat::expect_equal(nrow(block), 36L)
    testthat::expect_true(all(block$cri_lower <= block$posterior_mean))
    testthat::expect_true(all(block$posterior_mean <= block$cri_upper))
  }
  testthat::expect_equal(length(imir_v1_palette), 4L)
  testthat::expect_identical(anyDuplicated(unname(imir_v1_palette)), 0L)
})

testthat::test_that("reporting remains validation-owned and coordinator-integrated", {
  script <- file.path(harness_root, "scripts",
                      "generate_independent_metric_interval_reporting_v1.R")
  text <- paste(readLines(script, warn = FALSE), collapse = "\n")
  testthat::expect_true(file.exists(script))
  testthat::expect_false(grepl("git push", text, fixed = TRUE))
  testthat::expect_false(grepl("Article-Q-DESN---Version-2/main.tex", text, fixed = TRUE))
  testthat::expect_match(text, "ARTICLE_QDESN_INTEGRATION", fixed = TRUE)
  testthat::expect_match(text, "RETAIN_V10_NATIVE_INTERVALS", fixed = TRUE)
})
