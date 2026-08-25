testthat::test_that("coupling sensitivity is opt-in", {
  testthat::expect_false(ffv2_metric_coupling_cfg(list())$enabled)
  testthat::expect_false(.qdesn_validation_metric_coupling_cfg(list())$enabled)
  enabled <- list(metric_intervals = list(coupling_sensitivity = list(enabled = TRUE)))
  testthat::expect_true(ffv2_metric_coupling_cfg(enabled)$enabled)
})

testthat::test_that("config hash comparisons ignore incidental vector names", {
  observed <- stats::setNames(c("abc", "def"), c("/tmp/a", "/tmp/b"))
  testthat::expect_true(imic_v1_hash_vectors_equal(observed, c("abc", "def")))
  testthat::expect_false(imic_v1_hash_vectors_equal(observed, c("abc", "xyz")))
  testthat::expect_false(imic_v1_hash_vectors_equal(observed, "abc"))
})

testthat::test_that("Q-DESN origin permutations are deterministic marginal bijections", {
  a <- .qdesn_validation_origin_permutation(400L, seed = 8123L,
                                            origin_source_index = 9000L)
  b <- .qdesn_validation_origin_permutation(400L, seed = 8123L,
                                            origin_source_index = 9000L)
  c <- .qdesn_validation_origin_permutation(400L, seed = 8123L,
                                            origin_source_index = 9030L)
  testthat::expect_identical(a, b)
  testthat::expect_setequal(a, seq_len(400L))
  testthat::expect_false(identical(a, c))
})

testthat::test_that("DQLM common-rank construction preserves finite marginals", {
  independent <- matrix(c(3, 1, 4, 2, 8, 5, 7, 6), nrow = 2L, byrow = TRUE)
  common_rank <- do.call(rbind, lapply(seq_len(nrow(independent)), function(i) {
    sort(independent[i, ])
  }))
  testthat::expect_equal(rowMeans(common_rank), rowMeans(independent))
  testthat::expect_setequal(common_rank[1, ], independent[1, ])
  testthat::expect_setequal(common_rank[2, ], independent[2, ])
})

testthat::test_that("coupling summaries preserve mode-specific draw counts", {
  draws <- rbind(
    data.frame(chain_id = 1L, coupling_mode = "native_aligned",
               forecast_mae = 1:20, forecast_check_loss = 2:21),
    data.frame(chain_id = 1L, coupling_mode = "origin_independent_permutation",
               forecast_mae = rev(1:20), forecast_check_loss = rev(2:21))
  )
  out <- ffv2_metric_coupling_summary(draws)
  testthat::expect_equal(nrow(out), 4L)
  testthat::expect_true(all(out$n_draws == 20L))
  testthat::expect_equal(length(unique(out$coupling_mode)), 2L)
  testthat::expect_equal(
    out$posterior_mean[out$metric == "forecast_mae" &
                         out$coupling_mode == "native_aligned"],
    out$posterior_mean[out$metric == "forecast_mae" &
                         out$coupling_mode == "origin_independent_permutation"]
  )
})

testthat::test_that("paired decision statistics use predeclared thresholds", {
  fixture <- do.call(rbind, lapply(c("forecast_mae", "forecast_check_loss"), function(metric) {
    rbind(
      data.frame(replay_id = "fixture", engine = "qdesn",
                 model_variant = "qdesn_al_rhs_ns", family = "normal", tau = 0.25,
                 coupling_mode = "native_aligned", metric = metric,
                 posterior_mean = 2, posterior_sd = 0.2, cri_lower = 1,
                 posterior_median = 2, cri_upper = 3, n_draws = 100, n_chains = 1),
      data.frame(replay_id = "fixture", engine = "qdesn",
                 model_variant = "qdesn_al_rhs_ns", family = "normal", tau = 0.25,
                 coupling_mode = "origin_independent_permutation", metric = metric,
                 posterior_mean = 2, posterior_sd = 0.2, cri_lower = 0.95,
                 posterior_median = 2, cri_upper = 3.05, n_draws = 100, n_chains = 1)
    )
  }))
  out <- imic_v1_compare_coupling_modes(fixture)
  testthat::expect_true(all(out$severity == "PASS"))
  testthat::expect_true(all(out$relative_mean_shift == 0))
})

testthat::test_that("pilot source ledger resolves exact v10 article roles", {
  selection <- imic_v1_read_selection(repo_root)
  roles <- ffv2_read_csv(file.path(imic_v1_promotion_dir(repo_root),
                                   "article_metric_role_intervals.csv"))
  selected_roles <- roles[roles$replay_id %in% selection$replay_id, , drop = FALSE]
  testthat::expect_equal(nrow(selection), 11L)
  testthat::expect_setequal(unique(selection$family), c("normal", "gausmix"))
  testthat::expect_true(all(selection$replay_id %in% selected_roles$replay_id))
  testthat::expect_true(all(selected_roles$inference == "mcmc"))
})

testthat::test_that("coupling pipeline remains validation-lane scoped", {
  scripts <- file.path(harness_root, "scripts", c(
    "prepare_independent_metric_interval_evidence_bundle_v1.R",
    "verify_independent_metric_interval_evidence_bundle_v1.R",
    "materialize_independent_metric_interval_coupling_pilot_v1.R",
    "verify_independent_metric_interval_coupling_pilot_v1_plan.R",
    "closeout_independent_metric_interval_coupling_pilot_v1.R",
    "run_independent_metric_interval_coupling_pilot_v1_pipeline.sh"
  ))
  testthat::expect_true(all(file.exists(scripts)))
  text <- paste(unlist(lapply(scripts, readLines, warn = FALSE)), collapse = "\n")
  testthat::expect_false(grepl("Article-Q-DESN---Version-2/main.tex", text, fixed = TRUE))
  testthat::expect_false(grepl("git push origin main", text, fixed = TRUE))
  testthat::expect_match(text, "V10_1_MATCHED_COUPLING_REPLAY_REQUIRED", fixed = TRUE)
  testthat::expect_match(text, "OMP_NUM_THREADS=1", fixed = TRUE)
})
