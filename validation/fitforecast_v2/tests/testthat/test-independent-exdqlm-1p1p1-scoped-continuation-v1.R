test_that("the scoped contract contains only the 36 exDQLM jobs", {
  contract <- i111s_contract(ffv2_repo_root())
  expect_identical(contract$schema_version, i111s_schema)
  expect_identical(contract$scope_id, "exdqlm_only")
  expect_identical(contract$model_variant, "exdqlm")
  expect_identical(contract$expected_jobs, 36L)
  expect_identical(contract$expected_vb_jobs, 9L)
  expect_identical(contract$expected_mcmc_jobs, 27L)
  expect_identical(contract$expected_source_identities, 18L)
  expect_identical(contract$expected_metric_roles, 54L)
  expect_identical(contract$mcmc$proposal, "collapsed_slice")
  expect_identical(contract$vb$factorization, "structured")
  expect_true(all(c("dqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns") %in%
                    contract$exclusions))
})

test_that("scope selection rejects every non-exDQLM row", {
  cases <- expand.grid(
    family = c("normal", "laplace", "gausmix"),
    tau = c(0.05, 0.25, 0.50), stringsAsFactors = FALSE
  )
  make_rows <- function(model_variant, inference, chains) {
    do.call(rbind, lapply(seq_len(nrow(cases)), function(i) {
      data.frame(
        job_id = paste(model_variant, inference, i, seq_len(chains), sep = "_"),
        engine = if (grepl("^qdesn", model_variant)) "qdesn" else "dqlm",
        replay_id = paste(model_variant, inference, i, sep = "_"),
        source_identity = paste(model_variant, inference, i, sep = "|"),
        model_variant = model_variant, family = cases$family[[i]],
        tau = cases$tau[[i]], inference = inference,
        chain_id = seq_len(chains), config_path = tempfile(),
        config_sha256 = "hash", job_root = tempfile(), expected_draws = 1L,
        stringsAsFactors = FALSE
      )
    }))
  }
  parent <- rbind(
    make_rows("dqlm", "vb", 1L), make_rows("dqlm", "mcmc", 3L),
    make_rows("exdqlm", "vb", 1L), make_rows("exdqlm", "mcmc", 3L),
    make_rows("qdesn_al_rhs_ns", "vb", 1L),
    make_rows("qdesn_exal_rhs_ns", "mcmc", 3L)
  )
  parent$config_path <- rep(normalizePath(file.path(ffv2_repo_root(), "DESCRIPTION")),
                            nrow(parent))
  scoped <- i111s_filter_plan(parent)
  expect_equal(nrow(scoped), 36L)
  expect_true(all(scoped$model_variant == "exdqlm"))
  expect_true(all(scoped$engine == "dqlm"))
  expect_true(all(i111s_plan_checks(scoped)))
})

test_that("the scoped launcher cannot execute the broad campaign", {
  scripts <- file.path(ffv2_repo_root(), "validation", "fitforecast_v2", "scripts")
  launcher <- paste(readLines(file.path(
    scripts, "run_independent_exdqlm_1p1p1_scoped_continuation_v1_pipeline.sh"
  ), warn = FALSE), collapse = "\n")
  preparer <- paste(readLines(file.path(
    scripts, "prepare_independent_exdqlm_1p1p1_scoped_continuation_v1.R"
  ), warn = FALSE), collapse = "\n")
  verifier <- paste(readLines(file.path(
    scripts, "verify_independent_exdqlm_1p1p1_scoped_continuation_v1.R"
  ), warn = FALSE), collapse = "\n")
  expect_match(launcher, "prepare_independent_exdqlm_1p1p1_scoped_continuation_v1.R",
               fixed = TRUE)
  expect_match(launcher, "closeout_independent_exdqlm_1p1p1_scoped_continuation_v1.R",
               fixed = TRUE)
  expect_false(grepl("closeout_independent_metric_intervals_v1.R", launcher, fixed = TRUE))
  expect_match(launcher, "pre-existing IND validation workers remain", fixed = TRUE)
  expect_match(preparer, 'model_variant == "exdqlm"', fixed = TRUE)
  expect_match(verifier, "no_out_of_scope_jobs", fixed = TRUE)
  expect_match(verifier, "no_mcmc_status_before_launch", fixed = TRUE)
})

test_that("the scoped closeout preserves the integration boundary", {
  path <- file.path(
    ffv2_repo_root(), "validation", "fitforecast_v2", "scripts",
    "closeout_independent_exdqlm_1p1p1_scoped_continuation_v1.R"
  )
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(text, "candidate_exdqlm_rows.csv", fixed = TRUE)
  expect_match(text, "must not cherry-pick only favorable cells", fixed = TRUE)
  expect_match(text, 'integration_owner = "ARTICLE_QDESN_INTEGRATION"', fixed = TRUE)
  expect_match(text, "article_write_performed = FALSE", fixed = TRUE)
  expect_false(grepl("git push", text, fixed = TRUE))
})
