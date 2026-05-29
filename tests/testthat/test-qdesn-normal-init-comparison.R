`%||%` <- function(x, y) if (is.null(x)) y else x

test_that("Normal DESN initialization comparison script runs on synthetic data", {
  script <- test_path("../../scripts/run_normal_desn_init_comparison_20260529.R")
  if (!file.exists(script)) {
    script <- file.path(getwd(), "scripts", "run_normal_desn_init_comparison_20260529.R")
  }
  skip_if_not(file.exists(script))
  repo <- normalizePath(file.path(dirname(script), ".."), mustWork = TRUE)

  out_dir <- tempfile("normal-desn-init-comparison-")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(out_dir, recursive = TRUE, force = TRUE), add = TRUE)

  status <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(
      script,
      "--repo", repo,
      "--output-dir", out_dir,
      "--synthetic-n", "34",
      "--D", "1",
      "--n", "3",
      "--m", "1",
      "--washout", "5",
      "--max-iter", "3",
      "--seed", "20260529"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  expect_equal(attr(status, "status") %||% 0L, 0L, info = paste(status, collapse = "\n"))

  expected <- file.path(out_dir, c(
    "repo_state.csv",
    "init_method_summary.csv",
    "normal_desn_init_comparison_summary.md"
  ))
  expect_true(all(file.exists(expected)))

  repo_state <- utils::read.csv(file.path(out_dir, "repo_state.csv"))
  methods <- utils::read.csv(file.path(out_dir, "init_method_summary.csv"))

  expect_identical(repo_state$source_kind[[1L]], "synthetic")
  expect_false(isTRUE(repo_state$run_mcmc[[1L]]))
  expect_true(all(c(
    "normal_scaled_ridge",
    "normal_rhs_ns_vb",
    "al_vb_cold",
    "al_vb_normal_scaled_ridge_init",
    "al_vb_normal_rhs_ns_init",
    "exal_vb_cold",
    "exal_vb_normal_scaled_ridge_init",
    "exal_vb_normal_rhs_ns_init"
  ) %in% methods$method))
  expect_true(all(methods$finite_state))
  expect_true(all(is.finite(methods$rmse_y)))
  expect_true(all(is.finite(methods$pinball_tau_0p50)))
  expect_true(all(methods$init_source[grepl("_init$", methods$method)] != "none"))
})
