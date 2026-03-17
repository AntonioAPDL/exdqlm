test_that("rhs experiment matrix deep merge updates nested fields only", {
  base <- list(
    a = 1,
    b = list(
      c = 2,
      d = list(e = 3, f = 4)
    )
  )
  patch <- list(
    b = list(
      c = 20,
      d = list(f = 40)
    )
  )
  out <- exdqlm:::.qdesn_rhs_exp_matrix_deep_merge(base, patch)
  expect_equal(out$a, 1)
  expect_equal(out$b$c, 20)
  expect_equal(out$b$d$e, 3)
  expect_equal(out$b$d$f, 40)
})

test_that("rhs experiment matrix ranking prioritizes convergence before runtime", {
  df <- data.frame(
    experiment_id = c("A", "B", "C"),
    status = c("COMPLETED", "COMPLETED", "COMPLETED"),
    n_missing_diag = c(0, 0, 0),
    n_pipeline_fail = c(0, 0, 0),
    n_chain_fail = c(0, 0, 0),
    n_root_fail = c(1, 0, 0),
    max_split_rhat = c(1.03, 1.11, 1.07),
    min_ess_rhs = c(50, 40, 80),
    wall_minutes = c(10, 8, 12),
    stringsAsFactors = FALSE
  )
  ranked <- exdqlm:::.qdesn_rhs_exp_matrix_rank(df, top_n = 2)
  expect_equal(as.character(ranked$experiment_id[1L]), "C")
  expect_equal(as.character(ranked$experiment_id[2L]), "B")
  expect_true(isTRUE(ranked$is_topk[1L]))
  expect_true(isTRUE(ranked$is_topk[2L]))
  expect_false(isTRUE(ranked$is_topk[3L]))
})

test_that("rhs experiment matrix trigger evaluation handles threshold logic", {
  summary_df <- data.frame(
    experiment_id = c("E10", "E11"),
    max_split_rhat = c(1.08, 1.12),
    stringsAsFactors = FALSE
  )
  trig <- list(source_experiment = "E11", metric = "max_split_rhat", op = ">", threshold = 1.10)
  out <- exdqlm:::.qdesn_rhs_exp_matrix_evaluate_trigger(trig, summary_df)
  expect_true(isTRUE(out$run_phase))
  expect_equal(as.numeric(out$metric_value), 1.12)
})

test_that("rhs experiment matrix health collector summarizes diagnostics", {
  root <- tempfile("rhs-exp-health-")
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "tables"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "manifest"), recursive = TRUE, showWarnings = FALSE)

  utils::write.csv(
    data.frame(
      root_id = c("r1", "r2"),
      confirmation_grade = c("FAIL", "WARN"),
      max_split_rhat = c(1.11, 1.03),
      stringsAsFactors = FALSE
    ),
    file.path(root, "tables", "campaign_root_confirmation.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(
      chain_id = 1:2,
      signoff_grade = c("WARN", "FAIL"),
      signoff_reason = c("chain_marginal_but_usable", "missing_chain_diagnostics; pipeline"),
      mcmc_min_ess_rhs = c(25, 12),
      mcmc_max_acf1_rhs = c(0.95, 0.99),
      mcmc_max_geweke_absz_rhs = c(2.1, 3.4),
      mcmc_max_half_drift_rhs = c(0.3, 0.8),
      comparison_eligible = c(TRUE, FALSE),
      stringsAsFactors = FALSE
    ),
    file.path(root, "tables", "campaign_chain_signoff.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(
      parameter = c("rhs_tau", "rhs_c2", "gamma"),
      rhat = c(1.08, 1.15, 1.02),
      stringsAsFactors = FALSE
    ),
    file.path(root, "tables", "campaign_multichain_rhat.csv"),
    row.names = FALSE
  )
  exdqlm:::.qdesn_validation_write_json(file.path(root, "manifest", "campaign_started.json"), list(started_at = "2026-03-17 01:00:00"))
  exdqlm:::.qdesn_validation_write_json(file.path(root, "manifest", "campaign_completed.json"), list(finished_at = "2026-03-17 01:30:00"))

  out <- exdqlm:::.qdesn_rhs_exp_matrix_collect_health(root)
  expect_equal(as.integer(out$n_root_fail), 1L)
  expect_equal(as.integer(out$n_chain_fail), 1L)
  expect_equal(as.integer(out$n_missing_diag), 1L)
  expect_equal(as.integer(out$n_pipeline_fail), 1L)
  expect_equal(as.numeric(out$max_split_rhat), 1.11)
  expect_equal(as.numeric(out$max_rhs_rhat), 1.15)
  expect_true(is.finite(as.numeric(out$wall_minutes)))
})

