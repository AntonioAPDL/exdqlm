test_that("Q-DESN VB simplification ladder writes gated comparison outputs", {
  wd <- normalizePath(getwd(), mustWork = TRUE)
  repo <- if (identical(basename(wd), "testthat")) {
    normalizePath(file.path(wd, "..", ".."), mustWork = TRUE)
  } else {
    wd
  }
  script <- file.path(repo, "scripts", "run_qdesn_vb_simplification_ladder_20260528.R")
  expect_true(file.exists(script))

  out <- file.path(tempdir(), paste0("qdesn_ladder_", Sys.getpid()))
  unlink(out, recursive = TRUE, force = TRUE)
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(out, recursive = TRUE, force = TRUE), add = TRUE)

  env <- c(
    "OMP_NUM_THREADS=1",
    "OPENBLAS_NUM_THREADS=1",
    "MKL_NUM_THREADS=1",
    "VECLIB_MAXIMUM_THREADS=1",
    "NUMEXPR_NUM_THREADS=1"
  )
  status <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(
      script,
      "--repo", repo,
      "--output-dir", out,
      "--seed", "20260528",
      "--series-length", "36",
      "--reservoir-size", "4",
      "--washout", "4",
      "--max-iter", "12",
      "--stochastic-max-iter", "24",
      "--exact-tolerance", "1e-5",
      "--stochastic-tolerance", "0.15"
    ),
    env = env,
    stdout = TRUE,
    stderr = TRUE
  )
  exit_status <- attr(status, "status")
  expect_true(is.null(exit_status) || identical(exit_status, 0L))

  required <- c(
    "repo_state.csv",
    "ladder_method_summary.csv",
    "exact_equivalence.csv",
    "stochastic_diagnostics.csv",
    "prior_diagnostics.csv",
    "forbidden_modes.csv",
    "prediction_metrics.csv",
    "predictions_by_method.csv",
    "qdesn_vb_simplification_ladder_summary.md"
  )
  expect_true(all(file.exists(file.path(out, required))))

  method_summary <- utils::read.csv(file.path(out, "ladder_method_summary.csv"))
  exact <- utils::read.csv(file.path(out, "exact_equivalence.csv"))
  stochastic <- utils::read.csv(file.path(out, "stochastic_diagnostics.csv"))
  priors <- utils::read.csv(file.path(out, "prior_diagnostics.csv"))
  forbidden <- utils::read.csv(file.path(out, "forbidden_modes.csv"))
  predictions <- utils::read.csv(file.path(out, "prediction_metrics.csv"))

  expect_setequal(unique(method_summary$likelihood_family), c("al", "exal"))
  expect_setequal(unique(method_summary$prior_family), c("ridge", "rhs", "rhs_ns"))
  expect_true(all(c("none", "exact", "stochastic") %in% unique(method_summary$batching_mode)))
  expect_true(all(method_summary$finite_qbeta))
  expect_true(all(method_summary$finite_qv))
  expect_true(all(method_summary$finite_sigma_gamma))
  expect_true(all(nzchar(method_summary$design_hash)))

  expect_equal(nrow(exact), 6L)
  expect_true(all(exact$passed))
  expect_true(all(exact$max_gate_diff <= exact$tolerance))

  expect_equal(nrow(stochastic), 3L)
  expect_true(all(stochastic$likelihood_family == "al"))
  expect_true(all(stochastic$approximate))
  expect_true(all(stochastic$stochastic_label_present))
  expect_true(all(stochastic$approximate_note_present))
  expect_true(all(stochastic$finite_state))
  expect_true(all(stochastic$reproducible))
  expect_true(all(stochastic$passed_distance_gate))
  expect_true(all(stochastic$max_abs_beta_diff_repeat <= 1e-12))

  rhs_rows <- subset(priors, prior_family %in% c("rhs", "rhs_ns"))
  expect_gt(nrow(rhs_rows), 0L)
  expect_true(all(rhs_rows$shrink_intercept == FALSE))
  expect_true(all(is.finite(rhs_rows$intercept_prec)))
  expect_true(all(rhs_rows$rhs_trace_rows > 0L))

  expect_equal(nrow(forbidden), 3L)
  expect_true(all(forbidden$likelihood_family == "exal"))
  expect_true(all(forbidden$failed_early))
  expect_true(all(grepl("supported only for likelihood_family = 'al'", forbidden$message, fixed = TRUE)))

  expect_equal(nrow(predictions), nrow(method_summary))
  expect_true(all(is.finite(predictions$pinball_y)))
  expect_true(all(is.finite(predictions$rmse_y)))
})
