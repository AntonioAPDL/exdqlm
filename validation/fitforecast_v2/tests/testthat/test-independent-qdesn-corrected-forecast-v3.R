iqcf_v3_load_test_code <- function() {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(
    repo_root, "validation", "fitforecast_v2", "R",
    "independent_qdesn_full_redesign_v2.R"
  ), local = globalenv())
  source(file.path(
    repo_root, "validation", "fitforecast_v2", "R",
    "independent_qdesn_full_redesign_v2_runtime.R"
  ), local = globalenv())
  source(file.path(
    repo_root, "validation", "fitforecast_v2", "R",
    "independent_qdesn_corrected_forecast_v3.R"
  ), local = globalenv())
  source(file.path(
    repo_root, "validation", "fitforecast_v2", "R",
    "independent_qdesn_cellwise_refinement_v2_superseded_closeout.R"
  ), local = globalenv())
  source(file.path(
    repo_root, "validation", "fitforecast_v2", "R",
    "independent_qdesn_corrected_forecast_v3_campaign.R"
  ), local = globalenv())
  repo_root
}

iqcf_v3_test_fixture <- function() {
  withr::local_seed(93001)
  y <- as.numeric(stats::arima.sim(list(ar = 0.55), n = 95, sd = 0.25))
  design_args <- list(
    p0 = 0.25, D = 2L, n = c(7L, 5L), n_tilde = 7L,
    m = 2L, alpha = c(0.25, 0.35), rho = c(0.85, 0.80),
    pi_w = 1, pi_in = 1, washout = 5L, add_bias = TRUE,
    seed = 93002
  )
  fit <- do.call(exdqlm:::qdesn_fit_vb, c(list(y = y), design_args, list(
    fit_readout = TRUE,
    vb_args = list(max_iter = 8L, min_iter_elbo = 2L, tol = 1e-3,
                   tol_par = 1e-3, verbose = FALSE)
  )))
  list(y = y, fit = fit, design_args = design_args)
}

test_that("corrected-forecast protocol is gated and internally coherent", {
  repo_root <- iqcf_v3_load_test_code()
  checks <- iqcf_v3_protocol_checks(iqcf_v3_read_protocol(repo_root))
  expect_true(all(checks$pass), info = paste(
    checks$check[!checks$pass], collapse = ", "
  ))
})

test_that("nested posterior draws and paired noise preserve outer identity", {
  iqcf_v3_load_test_code()
  draws <- list(
    beta = matrix(seq_len(12), nrow = 3L),
    sigma = c(0.5, 1, 2), gamma = c(-0.2, 0, 0.3),
    source_draw_index = c(11L, 22L, 33L)
  )
  repeated <- iqcf_v3_repeat_draws(draws, 4L)
  expect_identical(repeated$outer_draw_index, rep(1:3, each = 4L))
  expect_identical(repeated$inner_path_index, rep(1:4, times = 3L))
  expect_identical(repeated$source_draw_index,
                   rep(c(11L, 22L, 33L), each = 4L))

  bank <- iqcf_v3_make_noise_bank(draws, 3L, 2L, 8L, 93003L)
  small <- iqcf_v3_subset_noise_bank(bank, 4L)
  large <- iqcf_v3_subset_noise_bank(bank, 8L)
  ids <- unlist(lapply(0:2, function(j) j * 8L + 1:4), use.names = FALSE)
  expect_equal(small[[1L]]$s, large[[1L]]$s[, ids, drop = FALSE],
               tolerance = 0)
  expect_equal(small[[2L]]$v, large[[2L]]$v[, ids, drop = FALSE],
               tolerance = 0)
})

test_that("recursive one-step quantile substitution is not a marginal H-step quantile", {
  iqcf_v3_load_test_code()
  audit <- iqcf_v3_ar1_quantile_contract(
    phi = 0.7, innovation_sd = 1, probability = 0.05, horizon = 2L
  )
  expect_gt(abs(audit$difference), 0.1)
  median_audit <- iqcf_v3_ar1_quantile_contract(
    phi = 0.7, innovation_sd = 1, probability = 0.5, horizon = 2L
  )
  expect_equal(median_audit$difference, 0, tolerance = 1e-12)
})

test_that("dimension-aware tau0 contract is positive and centered", {
  iqcf_v3_load_test_code()
  reference <- iqcf_v3_tau0_reference(
    readout_dimension = 101L, effective_sample_size = 500,
    sigma = 2, target_nonzero = 5
  )
  expect_gt(reference, 0)
  expect_equal(
    iqcf_v3_tau0_arms(reference), reference * c(0.1, 1, 10),
    tolerance = 1e-14
  )
  expect_error(iqcf_v3_tau0_reference(10, 500, 1, 9), "Invalid")
})

test_that("canary tau0 policy spans reference, continuity, and absolute high", {
  repo_root <- iqcf_v3_load_test_code()
  source_path <- tempfile(fileext = ".csv")
  on.exit(unlink(source_path, force = TRUE), add = TRUE)
  t <- 8111:10000
  source <- data.frame(
    t = t, y = seq_along(t) / 10, mu = 0, q_target = 0, eps = 0
  )
  utils::write.csv(source, source_path, row.names = FALSE)
  structure <- data.frame(
    family = "normal", likelihood_family = "al",
    representation_role = "current_authority_anchor",
    canary_structure_id = "normal__al__anchor",
    source_candidate_id = "source", source_prior_scale = 30,
    structure_id = "structure", structure_signature = "signature",
    generation = "test", D = 1L, n = "20", n_tilde = "",
    total_states = 20L, readout_dimension = 21L, m = 30L,
    alpha = 0.2, rho = 0.8, center_scale = "mean_sd",
    input_bound = "none", input_gain = 0.1, recurrent_indegree = 5L,
    input_fanin_fraction = 0.25, input_fanin = 8L,
    interlayer_fanin = 5L, matrix_seed = 920001L,
    stringsAsFactors = FALSE
  )
  manifest <- data.frame(
    family = "normal", tau = 0.5, frozen_path = source_path,
    stringsAsFactors = FALSE
  )
  candidates <- iqcf_v3_canary_candidates(
    structure, manifest, iqcf_v3_read_protocol(repo_root)
  )
  expect_identical(
    candidates$tau_arm,
    c("dimension_reference", "source_equivalent_continuity",
      "source_equivalent_high_100")
  )
  response_scale <- stats::sd(source$y[source$t >= 8501 & source$t <= 8750])
  expect_equal(candidates$rhs_tau0[candidates$tau_arm ==
                                      "source_equivalent_continuity"],
               30 / response_scale)
  expect_equal(candidates$rhs_tau0[candidates$tau_arm ==
                                      "source_equivalent_high_100"],
               100 / response_scale)
  expect_equal(candidates$rhs_tau0_source_scale, c(
    candidates$tau0_reference_source_scale[[1L]], 30, 100
  ))
})

test_that("slab scale is materialized rather than hardcoded by workers", {
  repo_root <- iqcf_v3_load_test_code()
  campaign <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "R",
    "independent_qdesn_corrected_forecast_v3_campaign.R"
  ), warn = FALSE), collapse = "\n")
  expect_match(campaign, "rhs_s2 = as.numeric(protocol$shrinkage$slab_s2)",
               fixed = TRUE)
  expect_match(campaign, "rhs_s2 <- iqfr_v2_number(cfg$rhs_s2)", fixed = TRUE)
  expect_match(campaign, '"rhs_tau0_source_scale", "rhs_s2"', fixed = TRUE)
  expect_false(grepl("s2 = 1,", campaign, fixed = TRUE))
})

test_that("training quantile benchmark uses only fitting rows", {
  iqcf_v3_load_test_code()
  source <- data.frame(t = 1:20, y = 1:20, q_target = rep(5, 20))
  fit_rows <- source$t <= 10
  baseline <- iqcf_v3_training_quantile_baseline(
    source, fit_rows, origins = 10L, horizon = 2L,
    probability = 0.5, source_offset = 0L
  )
  expected <- stats::quantile(1:10, 0.5, names = FALSE, type = 8)
  expect_equal(baseline$baseline_quantile, expected)
  changed <- source
  changed$y[11:20] <- 1e6
  expect_equal(
    iqcf_v3_training_quantile_baseline(
      changed, fit_rows, 10L, 2L, 0.5, 0L
    )$baseline_quantile,
    expected
  )
})

test_that("response transport is training-only and exactly invertible", {
  iqcf_v3_load_test_code()
  source <- data.frame(t = 1:20, y = seq(-2, 17))
  fit_rows <- source$t <= 10
  transport <- iqcf_v3_response_transport(source, fit_rows)
  expect_equal(
    transport$inverse(transport$forward(source$y)), source$y,
    tolerance = 1e-12
  )
  changed <- source
  changed$y[!fit_rows] <- 1e9
  changed_transport <- iqcf_v3_response_transport(changed, fit_rows)
  expect_equal(changed_transport$center, transport$center, tolerance = 0)
  expect_equal(changed_transport$scale, transport$scale, tolerance = 0)
  expect_equal(transport$fit_t_start, 1)
  expect_equal(transport$fit_t_end, 10)
})

test_that("corrected nested lattice is causal, reproducible, and separates estimands", {
  iqcf_v3_load_test_code()
  fixture <- iqcf_v3_test_fixture()
  draws <- exdqlm::exal_posterior_draws(fixture$fit$fit, nd = 4L, seed = 93004L)
  bank <- iqcf_v3_make_noise_bank(draws, 3L, 1L, 8L, 93005L)
  run <- function(y) iqcf_v3_nested_lattice(
    fixture$fit, y_all = y, origins = 70L, horizon = 3L,
    draws = draws, probability = 0.25, inner_paths = 8L,
    seed = 93005L, noise_bank = bank, include_mean_readout_state = TRUE
  )
  first <- run(fixture$y)
  second <- run(fixture$y)
  future_changed <- fixture$y
  future_changed[71:95] <- future_changed[71:95] + 1000
  replaced <- run(future_changed)

  expect_identical(first, second)
  expect_equal(first$oracle_location$mean_conditional_location,
               replaced$oracle_location$mean_conditional_location,
               tolerance = 0)
  expect_equal(first$pooled_predictive_quantile,
               replaced$pooled_predictive_quantile, tolerance = 0)
  expect_equal(dim(first$oracle_location$conditional_location_plugin[[1L]]),
               c(3L, 4L))
  expect_equal(dim(first$predictive_quantile_by_draw[[1L]]), c(3L, 4L))
  expect_true(first$metadata$parameter_draw_static_within_path)
  expect_false(isTRUE(all.equal(
    rowMeans(first$predictive_quantile_by_draw[[1L]]),
    first$pooled_predictive_quantile[[1L]], tolerance = 1e-12
  )))
})

test_that("teacher forcing updates a later origin without leaking inside an origin", {
  iqcf_v3_load_test_code()
  fixture <- iqcf_v3_test_fixture()
  draws <- exdqlm::exal_posterior_draws(fixture$fit$fit, nd = 3L, seed = 93006L)
  run <- function(object, y) iqcf_v3_nested_lattice(
    object, y_all = y, origins = c(70L, 75L), horizon = 2L,
    draws = draws, probability = 0.25, inner_paths = 4L,
    seed = 93007L, include_mean_readout_state = FALSE
  )
  base <- run(fixture$fit, fixture$y)
  changed <- fixture$y
  changed[73L] <- changed[73L] + 10
  changed_design <- do.call(
    exdqlm:::qdesn_fit_vb,
    c(list(y = changed), fixture$design_args,
      list(fit_readout = FALSE, vb_args = list()))
  )
  changed_fit <- iqfr_v2_attach_quantile_readout(
    changed_design, fixture$fit
  )
  updated <- run(changed_fit, changed)
  expect_equal(base$pooled_predictive_quantile[[1L]],
               updated$pooled_predictive_quantile[[1L]], tolerance = 0)
  expect_gt(max(abs(base$pooled_predictive_quantile[[2L]] -
                    updated$pooled_predictive_quantile[[2L]])), 0)
})

test_that("corrected scoring keeps posterior and origin uncertainty separate", {
  iqcf_v3_load_test_code()
  fixture <- iqcf_v3_test_fixture()
  draws <- exdqlm::exal_posterior_draws(fixture$fit$fit, nd = 4L, seed = 93008L)
  lattice <- iqcf_v3_nested_lattice(
    fixture$fit, y_all = fixture$y, origins = c(70L, 75L), horizon = 3L,
    draws = draws, probability = 0.25, inner_paths = 4L, seed = 93009L
  )
  source <- data.frame(t = seq_along(fixture$y), y = fixture$y,
                       q_target = rep(0, length(fixture$y)))
  score <- iqcf_v3_score_nested_lattice(lattice, source, source_offset = 0L)
  expect_true(all(is.finite(score$point_metrics$forecast_check_loss)))
  expect_equal(length(unique(score$metric_draws$posterior_draw)), 4L)
  expect_equal(nrow(score$origin_lead), 4L * 2L * 3L)
  block <- iqcf_v3_origin_block_intervals(
    score$origin_lead, replicates = 100L, seed = 93010L
  )
  expect_true(all(block$uncertainty_unit == "forecast_origin_block"))
  expect_true(all(block$lower <= block$upper))
})

test_that("compact canary control keeps exact identity dimensions", {
  iqcf_v3_load_test_code()
  template <- data.frame(
    family = "normal", candidate_id = "old", prior_scale = 1,
    structure_id = "old", structure_signature = "old", generation = "old",
    D = 2L, n = "40;40", n_tilde = "40", total_states = 80L,
    readout_dimension = 81L, m = 90L, alpha = 0.5, rho = 0.9,
    center_scale = "median_mad", input_bound = "tanh_z_over_3",
    input_gain = 1, recurrent_indegree = 10L,
    input_fanin_fraction = 0.5, input_fanin = 46L,
    interlayer_fanin = 40L, matrix_seed = 1L,
    stringsAsFactors = FALSE
  )
  control <- iqcf_v3_compact_control(template, "normal")
  expect_equal(control$D, 1L)
  expect_identical(control$n, "20")
  expect_identical(control$n_tilde, "")
  expect_equal(control$readout_dimension, 21L)
  expect_equal(control$m, 30L)
  expect_equal(control$matrix_seed, 920001L)
})

test_that("superseded closeout preserves success hashes and pending work", {
  repo_root <- iqcf_v3_load_test_code()
  run_root <- tempfile("iqcf-v3-old-run-")
  output <- tempfile("iqcf-v3-closeout-")
  on.exit(unlink(c(run_root, output), recursive = TRUE, force = TRUE), add = TRUE)
  for (path in c("configs/stage", "status/stage", "results/stage")) {
    dir.create(file.path(run_root, path), recursive = TRUE,
               showWarnings = FALSE)
  }
  make_config <- function(id) {
    config_path <- file.path(run_root, "configs", "stage", paste0(id, ".json"))
    status_path <- file.path(run_root, "status", "stage", paste0(id, ".json"))
    result_path <- file.path(run_root, "results", "stage", paste0(id, ".csv"))
    iqfr_v2_write_json(list(
      stage = "stage", job_id = id, status_path = status_path,
      result_path = result_path
    ), config_path)
    list(config = config_path, status = status_path, result = result_path)
  }
  done <- make_config("done")
  pending <- make_config("pending")
  iqfr_v2_write_csv(data.frame(value = 1), done$result)
  iqfr_v2_write_json(list(
    status = "SUCCESS", pid = NA_integer_, result_path = done$result,
    result_sha256 = iqfr_v2_sha256(done$result)
  ), done$status)
  result <- iqcr_v2_superseded_closeout(repo_root, run_root, output)
  expect_equal(result$stage_summary$planned, 2L)
  expect_equal(result$stage_summary$success, 1L)
  expect_equal(result$stage_summary$pending, 1L)
  expect_true(all(result$inventory$result_hash_pass[
    result$inventory$state == "SUCCESS"
  ]))
  expect_true(file.exists(file.path(output, "artifact_manifest.csv")))
})

test_that("launch scripts enforce smoke and canary gates", {
  repo_root <- iqcf_v3_load_test_code()
  smoke <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_independent_qdesn_corrected_forecast_v3_operator_smoke.sh"
  ), warn = FALSE), collapse = "\n")
  canary <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_independent_qdesn_corrected_forecast_v3_canary.sh"
  ), warn = FALSE), collapse = "\n")
  expect_match(smoke, "--process-slot-var=IQCF_SLOT", fixed = TRUE)
  expect_match(smoke, "OMP_NUM_THREADS=1", fixed = TRUE)
  expect_match(smoke, "artifact_sha256", fixed = TRUE)
  expect_match(canary, "PASS_UNLOCK_FORECAST_CANARY", fixed = TRUE)
  expect_match(canary, "--process-slot-var=IQCF_SLOT", fixed = TRUE)
  expect_match(canary, "artifact_sha256", fixed = TRUE)
  expect_false(grepl("origin/main", paste(smoke, canary)))
})

test_that("production materialization requires a clean committed worktree", {
  repo_root <- iqcf_v3_load_test_code()
  materializer <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "materialize_independent_qdesn_corrected_forecast_v3.R"
  ), warn = FALSE), collapse = "\n")
  campaign <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "R",
    "independent_qdesn_corrected_forecast_v3_campaign.R"
  ), warn = FALSE), collapse = "\n")
  expect_match(materializer, "--allow-dirty", fixed = TRUE)
  expect_match(campaign, "Production materialization requires a clean committed worktree",
               fixed = TRUE)
})
