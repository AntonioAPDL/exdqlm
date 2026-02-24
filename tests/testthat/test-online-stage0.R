test_that("stage0 benchmark is deterministic and healthy", {
  res <- exal_online_stage0_benchmark(
    seed = 20260223L,
    n = 30L,
    k = 4L,
    t0 = 18L,
    p0 = 0.5,
    batch_vb_control = list(max_iter = 20L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE),
    online_control = list(M = 2L, K = 3L, W = 8L, L_loc = 2L, window_passes = 1L),
    check_repro = TRUE,
    return_trace = TRUE
  )

  expect_true(is.list(res))
  expect_true(isTRUE(res$reproducibility$hashes_equal))
  expect_true(is.finite(res$run1$metrics$l2_beta_mu))
  expect_true(is.finite(res$run1$metrics$rmse_pred_mean))
  expect_true(isTRUE(res$run1$health$P_spd))
  expect_true(isTRUE(res$run1$health$is_finite_beta))
  expect_true(isTRUE(res$run1$health$is_finite_sigmagam))
  expect_equal(res$run1$trace_summary$n_steps, as.integer(12L))
})

test_that("stage0 artifacts writer persists summary and trace files", {
  res <- exal_online_stage0_benchmark(
    seed = 20260224L,
    n = 26L,
    k = 3L,
    t0 = 16L,
    p0 = 0.5,
    batch_vb_control = list(max_iter = 18L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE),
    online_control = list(M = 2L, K = 3L, W = 6L, L_loc = 2L, window_passes = 1L),
    check_repro = FALSE,
    return_trace = TRUE
  )

  out_dir <- tempfile("stage0_artifacts_")
  dir.create(out_dir, recursive = TRUE)
  paths <- exal_online_stage0_write_artifacts(res, out_dir = out_dir, write_trace = TRUE)

  expect_true(file.exists(paths$rds))
  expect_true(file.exists(paths$trace_run1_csv))
  if (!is.na(paths$json)) expect_true(file.exists(paths$json))
})
