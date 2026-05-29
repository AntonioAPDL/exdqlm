test_that("Normal/Q-DESN unified comparison wrapper runs on a tiny source", {
  script <- test_path("../../scripts/run_normal_qdesn_unified_source_median_20260529.R")
  if (!file.exists(script)) {
    script <- file.path(getwd(), "scripts", "run_normal_qdesn_unified_source_median_20260529.R")
  }
  skip_if_not(file.exists(script))
  repo <- normalizePath(file.path(dirname(script), ".."), mustWork = TRUE)

  source_dir <- tempfile("normal-qdesn-source-")
  out_dir <- tempfile("normal-qdesn-unified-")
  dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(c(source_dir, out_dir), recursive = TRUE, force = TRUE), add = TRUE)

  set.seed(2026052907L)
  t <- seq_len(48L)
  mu <- as.numeric(0.2 * sin(t / 5) + 0.003 * t)
  y <- mu + stats::rnorm(length(t), sd = 0.1)
  utils::write.csv(
    data.frame(t = t, y = y, mu = mu, q_target = mu, eps = y - mu),
    file.path(source_dir, "series_wide.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(t = t, source_index = t),
    file.path(source_dir, "selection_indices.csv"),
    row.names = FALSE
  )

  status <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(
      script,
      "--repo", repo,
      "--source-dir", source_dir,
      "--output-dir", out_dir,
      "--seed", "20260529",
      "--D", "1",
      "--n", "3",
      "--m", "1",
      "--washout", "6",
      "--chunk-size", "8",
      "--subset-size", "8",
      "--max-iter", "3",
      "--stochastic-max-iter", "4",
      "--hybrid-max-iter", "4",
      "--hybrid-full-every", "2",
      "--skip-workflows"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  expect_equal(attr(status, "status") %||% 0L, 0L, info = paste(status, collapse = "\n"))

  expected <- file.path(out_dir, c(
    "repo_state.csv",
    "component_runs.csv",
    "method_summary.csv",
    "prediction_metrics.csv",
    "exact_equivalence.csv",
    "approximate_diagnostics.csv",
    "target_changing_diagnostics.csv",
    "initializer_diagnostics.csv",
    "forbidden_modes.csv",
    "predictions_by_method.csv",
    "normal_qdesn_unified_comparison_summary.md"
  ))
  expect_true(all(file.exists(expected)))

  repo_state <- utils::read.csv(file.path(out_dir, "repo_state.csv"))
  methods <- utils::read.csv(file.path(out_dir, "method_summary.csv"))
  exact <- utils::read.csv(file.path(out_dir, "exact_equivalence.csv"))
  init <- utils::read.csv(file.path(out_dir, "initializer_diagnostics.csv"))

  expect_identical(repo_state$head[[1L]], as.character(repo_state$head[[1L]]))
  expect_true(all(c("normal_source", "normal_init", "qdesn_implemented_modes") %in% methods$component))
  expect_true(any(methods$method_id == "normal_scaled_ridge"))
  expect_true(any(methods$method_id == "qdesn_al_ridge_full"))
  expect_true(any(init$component == "normal_init_warm_start"))
  expect_true(all(exact$passed))
})
