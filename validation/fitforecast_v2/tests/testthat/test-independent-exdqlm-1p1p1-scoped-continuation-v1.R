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
  expect_identical(i111s_point_estimator_id, "fixed_path_point_metric_chain_mean_v1")
  expect_identical(
    i111s_interval_estimator_id,
    "posterior_mean_draw_metric_equal_tailed_95cri_v1"
  )
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
  expect_match(text, "candidate_point_exdqlm_rows.csv", fixed = TRUE)
  expect_match(text, "candidate_interval_exdqlm_roles.csv", fixed = TRUE)
  expect_match(text, "role$point_mean[[1L]]", fixed = TRUE)
  expect_false(grepl(
    "point_candidate[[point_columns[[metric_role]]]][match_row] <- role$posterior_mean",
    text, fixed = TRUE
  ))
  expect_match(text, "non_exdqlm_interval_invariance_ledger.csv", fixed = TRUE)
  expect_match(text, "must not cherry-pick only favorable cells", fixed = TRUE)
  expect_match(text, 'integration_owner = "ARTICLE_QDESN_INTEGRATION"', fixed = TRUE)
  expect_match(text, "article_write_performed = FALSE", fixed = TRUE)
  expect_false(grepl("git push", text, fixed = TRUE))
})

test_that("granular diagnostic metadata is injected and conflicts are rejected", {
  job <- data.frame(
    replay_id = "source_1", inference = "mcmc", model_variant = "exdqlm",
    family = "normal", tau = 0.25, chain_id = 2L, stringsAsFactors = FALSE
  )
  path <- data.frame(source_index = 1:2, q_true = c(0, 1), qhat = c(0.1, 0.9))
  augmented <- i111s_add_job_metadata(path, job, "test path")
  expect_true(all(c("family", "tau", "chain_id", "replay_id") %in%
                    names(augmented)))
  expect_true(all(augmented$family == "normal"))
  expect_true(all(augmented$tau == 0.25))
  expect_true(all(augmented$chain_id == 2L))
  path$family <- "laplace"
  expect_error(
    i111s_add_job_metadata(path, job, "test path"),
    "conflicting family metadata", fixed = TRUE
  )
})

test_that("the interval invariance ledger detects only targeted changes", {
  parent <- expand.grid(
    inference = "mcmc", model_variant = c("dqlm", "exdqlm"),
    family = "normal", tau = 0.05, metric_role = c("fit", "forecast_mae"),
    stringsAsFactors = FALSE
  )
  parent$posterior_mean <- seq_len(nrow(parent))
  candidate <- parent
  candidate$posterior_mean[candidate$model_variant == "exdqlm"] <-
    candidate$posterior_mean[candidate$model_variant == "exdqlm"] + 1
  ledger <- i111s_invariance_ledger(parent, candidate)
  expect_true(all(ledger$unchanged[ledger$inherited_role]))
  expect_true(all(!ledger$unchanged[!ledger$inherited_role]))
  expect_true(all(ledger$changed_fields[!ledger$inherited_role] == "posterior_mean"))
})

test_that("diagnostic recovery is additive and does not rerun models", {
  scripts <- file.path(ffv2_repo_root(), "validation", "fitforecast_v2", "scripts")
  diagnostic <- paste(readLines(file.path(
    scripts, "build_independent_exdqlm_1p1p1_scoped_diagnostic_packet_v1.R"
  ), warn = FALSE), collapse = "\n")
  recovery <- paste(readLines(file.path(
    scripts, "recover_independent_exdqlm_1p1p1_scoped_postprocessing_v2.R"
  ), warn = FALSE), collapse = "\n")
  freezer <- paste(readLines(file.path(
    scripts, "freeze_independent_exdqlm_1p1p1_scoped_integration_v2.R"
  ), warn = FALSE), collapse = "\n")
  expect_match(diagnostic, "i111s_add_job_metadata", fixed = TRUE)
  expect_match(diagnostic, "closeout-root", fixed = TRUE)
  expect_false(grepl("geom_errorbarh", diagnostic, fixed = TRUE))
  expect_match(recovery, "closeout_v2", fixed = TRUE)
  expect_match(recovery, "scientific_jobs_reexecuted = 0L", fixed = TRUE)
  expect_match(recovery, "original_pipeline_status_retained", fixed = TRUE)
  expect_match(recovery, "i111s_assert_clean_synced_branch", fixed = TRUE)
  expect_match(recovery, '"--closeout-root", closeout_root', fixed = TRUE)
  expect_false(grepl("orchestrate_independent_metric_intervals", recovery, fixed = TRUE))
  expect_false(grepl("git push", recovery, fixed = TRUE))
  expect_match(freezer, "candidate_point_interface_exdqlm_only_replacement.csv",
               fixed = TRUE)
  expect_match(freezer, "candidate_interval_roles_exdqlm_only_replacement.csv",
               fixed = TRUE)
  expect_match(freezer, "integration_owner = \"ARTICLE_QDESN_INTEGRATION\"",
               fixed = TRUE)
  expect_match(freezer, "i111s_assert_clean_synced_branch", fixed = TRUE)
  expect_match(freezer, 'normalize_text = identical(target, "environment/sessionInfo.txt")',
               fixed = TRUE)
  expect_false(grepl("git push", freezer, fixed = TRUE))
})
