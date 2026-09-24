testthat::test_that("mean-readout-state authority ledger is complete and case specific", {
  roles <- imrs_v1_role_map()
  checks <- imrs_v1_validate_role_map(roles)
  testthat::expect_true(all(checks))
  testthat::expect_equal(nrow(roles), 72L)
  testthat::expect_equal(length(unique(roles$source_id)), 44L)
  testthat::expect_equal(
    sum(roles$pooling_policy == "basis_specific_then_score_pool"), 2L
  )
  testthat::expect_equal(length(imrs_v1_vb_sources), 18L)
  testthat::expect_equal(length(imrs_v1_mcmc_sources), 25L)
})

testthat::test_that("posterior balancing preserves equal chain weight and basis guards", {
  make_chain <- function(chain, n, hash = "same") list(
    chain_id = chain, feature_basis_hash = hash,
    beta = matrix(seq_len(n * 3L), nrow = n, ncol = 3L),
    sigma = rep(chain, n), gamma = rep(0, n),
    source_draw_index = seq_len(n)
  )
  out <- imrs_v1_balance_posteriors(list(
    make_chain(1L, 8L), make_chain(2L, 6L), make_chain(3L, 10L)
  ))
  testthat::expect_equal(out$draws_per_chain, 6L)
  testthat::expect_equal(as.integer(table(out$chain_id)), rep(6L, 3L))
  testthat::expect_error(
    imrs_v1_balance_posteriors(list(
      make_chain(1L, 8L, "a"), make_chain(2L, 8L, "b")
    )),
    "incompatible feature bases"
  )
})

testthat::test_that("paired innovations reproduce full and tail pipeline streams", {
  draws <- list(
    beta = matrix(seq_len(15L), nrow = 5L),
    sigma = c(0.5, 0.75, 1, 1.25, 1.5),
    gamma = rep(0, 5L)
  )
  origins <- c(10L, 15L, 20L)
  selected <- c(2L, 5L)
  observed <- imrs_v1_generate_pipeline_noise(
    draws = draws,
    draw_indices = selected,
    origins = origins,
    horizon = 5L,
    y_obs_last = 20L,
    seed = 881L
  )
  full <- imrs_v1_generate_chain_noise(draws, origins[1:2], 5L, 881L)
  tail <- imrs_v1_generate_chain_noise(draws, origins[3L], 5L, 912L)
  expected <- c(full, tail)
  expected <- lapply(expected, function(x) {
    lapply(x, function(z) z[, selected, drop = FALSE])
  })

  contract <- attr(observed, "pairing_contract")
  attr(observed, "pairing_contract") <- NULL
  testthat::expect_equal(observed, expected, tolerance = 0)
  testthat::expect_equal(contract$complete_origin_count, 2L)
  testthat::expect_equal(contract$tail_origin_count, 1L)
  testthat::expect_equal(contract$source_draw_count, 5L)
  testthat::expect_equal(contract$selected_draw_count, 2L)
  testthat::expect_error(
    imrs_v1_generate_pipeline_noise(
      draws, c(1L, 1L), origins, 5L, 20L, 881L
    ),
    "Invalid source draw indices"
  )
})

testthat::test_that("stability distances retain matched structural missingness", {
  out <- imrs_v1_stability_distance(
    c(1, NA, 4, 8), c(2, NA, 1, 8), "fixture"
  )
  testthat::expect_equal(out[["max_abs_difference"]], 3)
  testthat::expect_equal(out[["rms_difference"]], sqrt(10 / 3))
  testthat::expect_equal(out[["compared_values"]], 3)
  testthat::expect_equal(out[["structural_missing_values"]], 1)
  testthat::expect_error(
    imrs_v1_stability_distance(c(1, NA), c(1, 2), "fixture"),
    "incompatible non-finite structure"
  )
})

testthat::test_that("score reconstruction enforces the 1000-target forecast contract", {
  root <- tempfile("imrs_score_fixture_")
  dir.create(root, recursive = TRUE)
  path <- file.path(root, "series.csv")
  t <- seq_len(10000L)
  utils::write.csv(data.frame(
    source_index = t, y = rep(c(-1, 1), length.out = length(t)),
    q_target = rep(0, length(t))
  ), path, row.names = FALSE)
  analysis_source_index <- 8111:10000
  origins <- seq.int(890L, 1880L, by = 30L)
  lattice <- list(
    origins = origins,
    mu_by_origin = lapply(origins, function(...) matrix(0, 30L, 4L))
  )
  basis <- list(
    source_series_path = path, y_all = rep(0, length(analysis_source_index)),
    analysis_source_index = analysis_source_index,
    lead_export_scale = list(center = 0, scale = 1),
    root_spec = list(tau = 0.25)
  )
  scored <- imrs_v1_score_lattice(
    lattice, basis, chain_id = c(1L, 1L, 2L, 2L),
    within_chain_draw_id = c(1L, 2L, 1L, 2L)
  )
  testthat::expect_equal(nrow(scored$grid), 1000L)
  testthat::expect_equal(length(unique(scored$grid$target_source_index)), 1000L)
  testthat::expect_equal(scored$draw_metrics$forecast_mae, rep(0, 4L))
  testthat::expect_true(all(is.finite(scored$draw_metrics$forecast_check_loss)))
})

testthat::test_that("native artifacts are internally verified without a duplicate replay", {
  draws <- data.frame(
    forecast_mae = seq(1, 2, length.out = 20L),
    forecast_check_loss = seq(0.2, 0.4, length.out = 20L),
    chain_id = 1L
  )
  summary <- imrs_v1_interval_summary(draws, "native")
  parity <- imrs_v1_native_artifact_parity(draws, summary)
  testthat::expect_true(all(parity$pass))
  summary$posterior_mean[[1L]] <- summary$posterior_mean[[1L]] + 1e-3
  testthat::expect_false(all(
    imrs_v1_native_artifact_parity(draws, summary)$pass
  ))

  origin_source <- seq.int(9000L, 9990L, by = 30L)
  counts <- c(rep(30L, 33L), 10L)
  origin <- rep(origin_source, counts)
  lead <- unlist(lapply(counts, seq_len), use.names = FALSE)
  target <- origin + lead
  base <- data.frame(
    forecast_origin_source_index = origin,
    forecast_lead = lead,
    target_source_index = target,
    local_origin_t = origin - 8110L,
    local_target_t = target - 8110L,
    qhat = 0,
    q_true = 0,
    y = rep(c(-1, 1), length.out = length(target))
  )
  shifted <- base
  shifted$qhat <- 2
  scored <- imrs_v1_score_native_paths(list(base, shifted), tau = 0.25)
  testthat::expect_equal(nrow(scored$point_path), 1000L)
  testthat::expect_equal(scored$point_path$q_point, rep(1, 1000L))
  testthat::expect_equal(scored$point_metrics$forecast_mae, 1)
})

testthat::test_that("reconstructed native scores must reproduce frozen authority", {
  authority <- data.frame(
    forecast_mae = seq(1, 2, length.out = 20L),
    forecast_check_loss = seq(0.2, 0.4, length.out = 20L),
    chain_id = 1L
  )
  observed <- authority
  parity <- imrs_v1_native_authority_parity(observed, authority)
  testthat::expect_true(all(parity$pass))
  observed$forecast_mae <- observed$forecast_mae + 2e-6
  parity <- imrs_v1_native_authority_parity(observed, authority)
  testthat::expect_false(parity$pass[parity$metric == "forecast_mae"])
})

testthat::test_that("campaign scripts preserve eight-core lane ownership", {
  scripts <- file.path(harness_root, "scripts", c(
    "materialize_independent_mean_readout_state_forecast_v1.R",
    "run_independent_mean_readout_state_fit_job.R",
    "run_independent_mean_readout_state_forecast_job.R",
    "orchestrate_independent_mean_readout_state_forecast_v1.R",
    "healthcheck_independent_mean_readout_state_forecast_v1.R",
    "closeout_independent_mean_readout_state_forecast_v1.R",
    "verify_independent_mean_readout_state_forecast_v1.R",
    "launch_independent_mean_readout_state_forecast_v1.sh"
  ))
  testthat::expect_true(all(file.exists(scripts)))
  text <- paste(unlist(lapply(scripts, readLines, warn = FALSE)), collapse = "\n")
  testthat::expect_false(grepl("git push.*main", text))
  testthat::expect_false(grepl(
    "git[^\\n]*(overleaf|Article-Q-DESN---Version-2)", text,
    ignore.case = TRUE
  ))
  testthat::expect_match(text, "exactly eight worker slots", fixed = TRUE)
  testthat::expect_match(text, "BLOCKED_PROVENANCE_OR_IMPLEMENTATION_FAILURE",
                         fixed = TRUE)
  testthat::expect_match(
    text, "native_artifact_consistency_tolerance", fixed = TRUE
  )
  testthat::expect_match(text, "historical_native_authority", fixed = TRUE)
  testthat::expect_match(text, "innovation_pairing_ledger", fixed = TRUE)
})
