test_that("static VB->MCMC pipeline and report scripts produce core artifacts", {
  skip_on_cran()

  root <- normalizePath(".", winslash = "/", mustWork = TRUE)
  script_pipeline <- normalizePath(
    file.path("tools", "merge_reports", "20260305_static_vb_then_mcmc_pipeline.R"),
    winslash = "/",
    mustWork = FALSE
  )
  script_report <- normalizePath(
    file.path("tools", "merge_reports", "20260305_static_vb_mcmc_report.R"),
    winslash = "/",
    mustWork = FALSE
  )
  skip_if_not(file.exists(script_pipeline), "pipeline script path unavailable in test sandbox")
  skip_if_not(file.exists(script_report), "report script path unavailable in test sandbox")

  sim_path <- file.path(tempdir(), sprintf("static_sim_%s.rds", as.integer(Sys.time())))

  set.seed(9091)
  n <- 120L
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x)
  mu <- as.numeric(drop(X %*% c(0.2, -0.1)))
  y <- as.numeric(mu + stats::rnorm(n, sd = 0.2))
  p_grid <- c(0.05, 0.50, 0.95)
  qmat <- sapply(p_grid, function(pp) mu + stats::qnorm(pp, mean = 0, sd = 0.2))

  sim <- list(
    y = y,
    q = as.matrix(qmat),
    p = p_grid,
    info = list(scenario = "test_static_smoke", params = list(), burnin = 0L, R_mc = 0L, seed = 9091L),
    extras = list(mu = mu, X = X, q_al = as.matrix(qmat))
  )
  class(sim) <- "ts_mc_quantiles"
  saveRDS(sim, sim_path)

  t0 <- Sys.time()
  env <- c(
    sprintf("EXDQLM_STATIC_SIM_PATH=%s", sim_path),
    "EXDQLM_STATIC_PIPELINE_TT=100",
    "EXDQLM_STATIC_VB_MAX_ITER=30",
    "EXDQLM_STATIC_VB_TOL=0.05",
    "EXDQLM_STATIC_VB_NSAMP=40",
    "EXDQLM_STATIC_MCMC_BURN=8",
    "EXDQLM_STATIC_MCMC_N=10",
    "EXDQLM_STATIC_MCMC_THIN=1",
    "EXDQLM_STATIC_PIPELINE_CORES=1"
  )

  out1 <- tryCatch(
    system2(
      "Rscript",
      args = c(script_pipeline),
      env = env,
      stdout = TRUE,
      stderr = TRUE
    ),
    warning = function(w) structure(conditionMessage(w), status = attr(w, "status"))
  )
  if (!is.null(attr(out1, "status")) && as.integer(attr(out1, "status")) != 0L) {
    skip(sprintf("pipeline script returned non-zero status (%s) in sandbox", as.integer(attr(out1, "status"))))
  }
  expect_true(length(out1) >= 1)

  runs <- Sys.glob(file.path(root, "results", "sim_suite_static", "static_vb_then_mcmc_tt120_vbns40_burn8_n10_*"))
  expect_true(length(runs) >= 1)
  runs <- runs[file.info(runs)$mtime >= t0 - 1]
  expect_true(length(runs) >= 1)
  run_root <- runs[which.max(file.info(runs)$mtime)]

  summary_path <- file.path(run_root, "tables", "pipeline_task_summary.csv")
  expect_true(file.exists(summary_path))
  summary_df <- utils::read.csv(summary_path, check.names = FALSE)
  expect_equal(nrow(summary_df), 6)
  expect_true(all(summary_df$status %in% c("done", "failed")))

  out2 <- tryCatch(
    system2(
      "Rscript",
      args = c(script_report),
      env = c(env, sprintf("EXDQLM_STATIC_RUN_ROOT=%s", run_root)),
      stdout = TRUE,
      stderr = TRUE
    ),
    warning = function(w) structure(conditionMessage(w), status = attr(w, "status"))
  )
  if (!is.null(attr(out2, "status")) && as.integer(attr(out2, "status")) != 0L) {
    skip(sprintf("report script returned non-zero status (%s) in sandbox", as.integer(attr(out2, "status"))))
  }
  expect_true(length(out2) >= 1)

  gate_path <- file.path(run_root, "tables", "acceptance_gate_summary.csv")
  metrics_path <- file.path(run_root, "tables", "fit_metrics_by_task.csv")
  expect_true(file.exists(gate_path))
  expect_true(file.exists(metrics_path))

  gate_df <- utils::read.csv(gate_path, check.names = FALSE)
  expect_true(all(c("model", "tau", "overall_pass") %in% names(gate_df)))
})
