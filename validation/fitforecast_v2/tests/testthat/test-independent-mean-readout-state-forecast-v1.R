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

testthat::test_that("native metrics align by retained position, not sampler index", {
  native <- data.frame(
    source_draw_index = 1:5,
    forecast_mae = seq_len(5), forecast_check_loss = seq_len(5) / 10
  )
  posterior <- list(
    beta = matrix(seq_len(15L), nrow = 5L),
    source_draw_index = c(5619L, 6540L, 7090L, 10264L, 17219L)
  )
  alignment <- imrs_v1_validate_native_posterior_alignment(
    native, posterior, c(1L, 3L, 5L)
  )
  testthat::expect_equal(alignment$native_position, c(1L, 3L, 5L))
  testthat::expect_equal(
    alignment$posterior_original_draw_index, c(5619L, 7090L, 17219L)
  )

  malformed <- native
  malformed$source_draw_index <- rev(malformed$source_draw_index)
  testthat::expect_error(
    imrs_v1_validate_native_posterior_alignment(
      malformed, posterior, c(1L, 3L, 5L)
    ),
    "native_position_schema"
  )
  testthat::expect_error(
    imrs_v1_validate_native_posterior_alignment(
      native[-1L, ], posterior, c(1L, 3L)
    ),
    "native_rows"
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

imrs_v1_test_compatibility_policy <- function() list(
  schema_version = imrs_v1_historical_compatibility_schema,
  source_package_version = "1.0.0",
  fit_jobs = 96L, metrics_per_fit = 2L, familywise_alpha = 0.01,
  exact_summary_tolerance = 1e-6, mean_relative_tolerance = 0.05,
  interval_endpoint_width_tolerance = 0.10,
  interval_overlap_min = 0.90, absolute_floor = 1e-6
)

testthat::test_that("historical authority identity and compatibility are distinct", {
  set.seed(44)
  authority <- data.frame(
    forecast_mae = 3 + stats::rnorm(1000L, sd = 0.3),
    forecast_check_loss = 0.8 + stats::rnorm(1000L, sd = 0.07),
    chain_id = 1L
  )
  exact <- imrs_v1_native_authority_compatibility(
    authority, authority, imrs_v1_test_compatibility_policy()
  )
  testthat::expect_true(all(exact$exact_pass))
  testthat::expect_true(all(exact$pass))
  testthat::expect_true(all(exact$gate_mode == "exact"))

  permuted <- authority[rev(seq_len(nrow(authority))), , drop = FALSE]
  compatible <- imrs_v1_native_authority_compatibility(
    permuted, authority, imrs_v1_test_compatibility_policy()
  )
  testthat::expect_false(any(compatible$exact_pass))
  testthat::expect_true(all(compatible$compatibility_pass))
  testthat::expect_true(all(compatible$pass))
  testthat::expect_true(all(compatible$gate_mode == "distributional"))
})

testthat::test_that("independent stochastic replays use familywise compatibility", {
  set.seed(101)
  authority <- data.frame(
    forecast_mae = 4 + stats::rnorm(5000L, sd = 0.35),
    forecast_check_loss = 1 + stats::rnorm(5000L, sd = 0.08),
    chain_id = 1L
  )
  set.seed(202)
  observed <- data.frame(
    forecast_mae = 4 + stats::rnorm(5000L, sd = 0.35),
    forecast_check_loss = 1 + stats::rnorm(5000L, sd = 0.08),
    chain_id = 1L
  )
  compatible <- imrs_v1_native_authority_compatibility(
    observed, authority, imrs_v1_test_compatibility_policy()
  )
  testthat::expect_false(any(compatible$exact_pass))
  testthat::expect_true(all(compatible$pass))
  testthat::expect_true(all(compatible$mean_pass))
  testthat::expect_true(all(compatible$ks_pass))
  testthat::expect_true(all(compatible$endpoint_pass))
  testthat::expect_true(all(compatible$overlap_pass))

  shifted <- observed
  shifted$forecast_mae <- shifted$forecast_mae + 1
  shifted$forecast_check_loss <- shifted$forecast_check_loss + 0.25
  rejected <- imrs_v1_native_authority_compatibility(
    shifted, authority, imrs_v1_test_compatibility_policy()
  )
  testthat::expect_false(any(rejected$pass))
  testthat::expect_true(any(
    !rejected$mean_pass | !rejected$ks_pass | !rejected$endpoint_pass |
      !rejected$overlap_pass
  ))
})

testthat::test_that("historical compatibility rejects malformed draw contracts", {
  authority <- data.frame(
    forecast_mae = seq(1, 2, length.out = 100L),
    forecast_check_loss = seq(0.2, 0.4, length.out = 100L)
  )
  mismatched <- imrs_v1_native_authority_compatibility(
    authority[-1L, ], authority, imrs_v1_test_compatibility_policy()
  )
  testthat::expect_false(any(mismatched$pass))
  testthat::expect_false(any(mismatched$row_count_pass))

  nonfinite <- authority
  nonfinite$forecast_mae[[1L]] <- Inf
  nonfinite$forecast_check_loss[[2L]] <- NA_real_
  rejected <- imrs_v1_native_authority_compatibility(
    nonfinite, authority, imrs_v1_test_compatibility_policy()
  )
  testthat::expect_false(any(rejected$pass))
  testthat::expect_false(any(rejected$finite_contract))
})

testthat::test_that("historical compatibility policy controls all 192 metrics", {
  policy <- imrs_v1_historical_compatibility_policy(
    imrs_v1_test_compatibility_policy()
  )
  testthat::expect_equal(policy$familywise_comparisons, 192L)
  testthat::expect_equal(policy$per_comparison_alpha, 0.01 / 192)
  testthat::expect_gt(policy$mean_z_critical, 3.9)
  testthat::expect_gt(policy$ks_constant, 2)
})

testthat::test_that("scheduler status labels preserve an empty job set", {
  testthat::expect_identical(imrs_v1_label_ids("fit:", character()), character())
  testthat::expect_identical(
    imrs_v1_label_ids("forecast:", c("a", "b")),
    c("forecast:a", "forecast:b")
  )
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
  testthat::expect_match(
    text, "historical_native_authority_compatibility", fixed = TRUE
  )
  testthat::expect_false(grepl(
    "historical_native_authority_parity[.]csv", text
  ))
  testthat::expect_match(
    text, "native_posterior_alignment_ledger", fixed = TRUE
  )
  testthat::expect_match(text, "innovation_pairing_ledger", fixed = TRUE)
})

testthat::test_that("materialization freezes authority versions and policy", {
  package_root <- normalizePath(
    file.path(harness_root, "..", ".."), winslash = "/", mustWork = TRUE
  )
  defaults <- yaml::read_yaml(file.path(
    package_root, "config", "validation",
    "independent_mean_readout_state_forecast_v1", "campaign_defaults.yaml"
  ))
  policy <- imrs_v1_historical_compatibility_policy(
    defaults$historical_authority_compatibility
  )
  testthat::expect_identical(policy$source_package_version, "1.0.0")
  testthat::expect_match(
    defaults$historical_authority_compatibility$imi_source_git_commit,
    "^[0-9a-f]{40}$"
  )
  testthat::expect_match(
    defaults$historical_authority_compatibility$idolp_source_git_commit,
    "^[0-9a-f]{40}$"
  )
  materializer <- paste(readLines(file.path(
    harness_root, "scripts",
    "materialize_independent_mean_readout_state_forecast_v1.R"
  ), warn = FALSE), collapse = "\n")
  testthat::expect_match(
    materializer, "git_description_version", fixed = TRUE
  )
  testthat::expect_match(
    materializer, "historical_authority_compatibility", fixed = TRUE
  )
})
