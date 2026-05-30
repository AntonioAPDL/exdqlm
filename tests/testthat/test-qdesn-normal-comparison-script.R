`%||%` <- function(x, y) if (is.null(x)) y else x

test_that("Normal DESN source comparison script runs on synthetic data", {
  script <- test_path("../../scripts/run_normal_desn_source_median_comparison_20260529.R")
  if (!file.exists(script)) {
    script <- file.path(getwd(), "scripts", "run_normal_desn_source_median_comparison_20260529.R")
  }
  skip_if_not(file.exists(script))
  repo <- normalizePath(file.path(dirname(script), ".."), mustWork = TRUE)

  out_dir <- tempfile("normal-desn-comparison-")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(out_dir, recursive = TRUE, force = TRUE), add = TRUE)

  status <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(
      script,
      "--repo", repo,
      "--output-dir", out_dir,
      "--synthetic-n", "36",
      "--D", "1",
      "--n", "3",
      "--m", "1",
      "--washout", "5",
      "--chunk-size", "7",
      "--max-iter", "3",
      "--stochastic-max-iter", "5",
      "--skip-stochastic",
      "--ridge-tau2", "30",
      "--rhs-tau0", "0.01",
      "--seed", "20260529"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  expect_equal(attr(status, "status") %||% 0L, 0L, info = paste(status, collapse = "\n"))

  expected <- file.path(out_dir, c(
    "repo_state.csv",
    "method_summary.csv",
    "exact_equivalence.csv",
    "predictions_by_method.csv",
    "normal_desn_source_median_comparison_summary.md"
  ))
  expect_true(all(file.exists(expected)))

  repo_state <- utils::read.csv(file.path(out_dir, "repo_state.csv"))
  methods <- utils::read.csv(file.path(out_dir, "method_summary.csv"))
  exact <- utils::read.csv(file.path(out_dir, "exact_equivalence.csv"))
  preds <- utils::read.csv(file.path(out_dir, "predictions_by_method.csv"))

  expect_identical(repo_state$source_kind[[1L]], "synthetic")
  expect_equal(repo_state$ridge_tau2[[1L]], 30)
  expect_equal(repo_state$rhs_tau0[[1L]], 0.01)
  expect_true(all(c(
    "normal_scaled_ridge",
    "normal_scaled_ridge_exact_chunked",
    "normal_rhs_ns_vb",
    "qdesn_al_ridge",
    "qdesn_al_ridge_exact_chunked",
    "qdesn_exal_ridge",
    "qdesn_exal_ridge_exact_chunked"
  ) %in% methods$method))
  expect_true(all(exact$passed))
  expect_true(all(c("ridge_tau2", "rhs_tau0") %in% names(methods)))
  expect_equal(methods$rhs_tau0[methods$method == "normal_rhs_ns_vb"][[1L]], 0.01)
  expect_true(all(is.finite(methods$rmse_y)))
  expect_true(all(methods$finite_state))
  expect_true(all(is.finite(preds$point)))
})
