iqtf_test_legacy <- "/data/jaguir26/local/src/exdqlm__wt__independent_qdesn_frozen_preprocessing_v10_20261003/validation/fitforecast_v2/local_trackers/independent_qdesn_frozen_preprocessing_v10_recovery_20261004__git-054df26f"
iqtf_test_history <- "/data/jaguir26/local/src/exdqlm__wt__independent_qdesn_corrected_broad_v4_20261001/validation/fitforecast_v2/local_trackers/independent_qdesn_corrected_broad_v4_20261001_021752__git-af1b60b3bd/manifests/broad_candidates.csv"
iqtf_test_refs <- function() {
  skip_if_not(file.exists(file.path(iqtf_test_legacy, "plan.csv")))
  p <- read.csv(file.path(iqtf_test_legacy, "plan.csv"))
  lapply(c("normal_al_p005", "normal_exal_p025"), function(case) {
    role <- if (case == "normal_al_p005") "control" else "challenger"
    r <- iqfr_v2_read_json(p$config_path[p$case_id == case & p$inference == "mcmc" & p$pair_role == role][1])
    iqfr_v2_read_json(r$reference_config_path)
  })
}

test_that("bounded candidates retain controlled tau contrasts and genuinely richer identities", {
  refs <- iqtf_test_refs()
  b <- read.csv(iqtf_test_history)
  for (ref in refs) {
    cs <- iqtf_v11_bank(ref, b)
    expect_length(cs, 18)
    expect_length(unique(vapply(cs, function(c) c$structure_id, "")), 7)
    expect_false(anyDuplicated(vapply(cs, function(c) c$candidate_signature, "")) > 0)
    expect_equal(vapply(cs[1:6], function(c) c$rhs_tau0 / ref$candidate$rhs_tau0, 1),
      c(1, .1, .01, .001, .0001, 3))
    expect_true(all(vapply(cs[1:6], function(c)
      identical(c$canonical_structure_signature, cs[[1]]$canonical_structure_signature), TRUE)))
    expect_equal(max(vapply(cs, function(c) c$readout_dimension, 1)), 501)
    expect_true(all(vapply(cs, function(c) c$matrix_seed == 920001, TRUE)))
    novel <- Filter(function(c) c$representation_role == "novel_richer_identity_Q", cs)
    expect_true(all(vapply(novel, function(c)
      !c$canonical_structure_signature %in% b$canonical_structure_signature, TRUE)))
    expect_true(all(vapply(novel, function(c)
      identical(iqcb_v4_unpack_n(c$n_tilde), head(iqcb_v4_unpack_n(c$n), -1)), TRUE)))
  }
})

test_that("VB is not a gain gate and MCMC selects case-specific criteria without a global winner", {
  rows <- data.frame(case_id = rep(c("a", "b"), each = 4),
    candidate_id = rep(c("anchor", "c1", "c2", "c3"), 2),
    config_path = paste0("p", 1:8),
    forecast_qtrue_mae = c(1, 2, 3, 4, 1, 4, 3, 2),
    forecast_check_loss = c(1, 3, 2, 4, 1, 2, 3, 4))
  anchors <- list(a = "anchor", b = "anchor")
  expect_setequal(iqtf_v11_pick(rows, anchors), c("p2", "p3", "p8", "p6"))
  expect_length(iqtf_v11_pick(rows, anchors, TRUE), 0)
  rows$forecast_qtrue_mae[2] <- 1 - 1e-9
  rows$forecast_check_loss[7] <- .9
  expect_setequal(iqtf_v11_pick(rows, anchors, TRUE), c("p2", "p7"))
  rows$forecast_qtrue_mae[2] <- NA_real_
  expect_setequal(iqtf_v11_pick(rows, anchors, TRUE), "p7")
})

test_that("manifest checks fail closed on missing empty or changed files", {
  root <- tempfile(); dir.create(root)
  f <- file.path(root, "input"); writeLines("a", f)
  m <- file.path(root, "manifest.csv")
  expect_error(iqtf_v11_hash(c(f, paste0(f, "_absent")), m))
  iqtf_v11_hash(f, m); expect_silent(iqtf_v11_verify(m))
  writeLines("changed", f); expect_error(iqtf_v11_verify(m))
  write.csv(data.frame(path = character(), sha256 = character()), m, row.names = FALSE)
  expect_error(iqtf_v11_verify(m))
})

test_that("real AL and exAL workers preserve the basis and execute explicit kernels", {
  refs <- iqtf_test_refs(); root <- file.path(test_output, "real_worker_smoke")
  dir.create(root, recursive = TRUE)
  configs <- lapply(refs, function(ref) {
    c <- ref$candidate; c$D <- 1L; c$n <- "6"; c$n_tilde <- ""
    c$total_states <- 6L; c$readout_dimension <- 7L; c$m <- 30L
    c$recurrent_indegree <- 3L; c$input_fanin <- 8L; c$interlayer_fanin <- 3L
    c$alpha <- .6; c$rho <- .8; c$input_gain <- .3
    c <- iqtf_v11_candidate(c, ref$candidate, "runtime_smoke_only", .1)
    cfg <- iqtf_v11_config(ref, c, "cost", root, repo_root)
    cfg$budget$max_iter <- 12L; cfg$budget$n_samp_xi <- 8L
    cfg$horizon <- 2L; cfg$inner_path_grid <- 4L
    cfg$mcmc_burn <- 10L; cfg$mcmc_retained <- 20L
    cfg
  })
  iqtf_v11_plan(configs, "cost", root)
  iqtf_v11_hash(file.path(repo_root, c("src/exdqlm.so",
    "validation/fitforecast_v2/R/independent_qdesn_targeted_forecast_v11.R")),
    file.path(root, "source_hashes.csv"))
  iqtf_v11_hash(file.path(root, "source_hashes.csv"), file.path(root, "materialization_hashes.csv"))
  for (cfg in configs) {
    iqtf_v11_worker(cfg$config_path)
    expect_true(iqtf_v11_valid(cfg))
    evidence <- file.path(root, "evidence", cfg$job_id)
    checks <- read.csv(file.path(evidence, "checks.csv"))
    expect_true(all(checks$pass)); expect_lte(max(checks$maximum_absolute_error), 1e-6)
    kernel <- iqfr_v2_read_json(file.path(evidence, "cost_kernel.json"))
    expect_identical(kernel$kernel, if (cfg$likelihood_family == "al")
      "sigma_then_gamma" else "m0_v_collapsed_support_logit")
    expect_true(kernel$state_only_init)
    metrics <- read.csv(file.path(evidence, "metric_draws.csv.gz"))
    expect_true(all(is.finite(metrics$fit_qtrue_rmse)))
    expect_error(iqtf_v11_worker(cfg$config_path), "overwrite")
    state <- iqfr_v2_read_json(file.path(evidence, "mcmc_initializer.json"))
    expect_identical(state$policy, "state_only_fresh_RHS_prior_not_posterior_reinforcement")
  }
  expect_equal(iqtf_v11_health(root)$counts$SUCCESS, 2)
  pilots <- lapply(configs, function(c) {
    ref <- refs[[which(vapply(refs, function(r) r$case_id == c$case_id, TRUE))]]
    cfg <- iqtf_v11_config(ref, c$candidate, "pilot", root, repo_root)
    cfg$origins <- c$origins; cfg$horizon <- 2L
    cfg$outer_draws <- 4L; cfg$inner_path_grid <- 4L
    cfg$mcmc_burn <- 10L; cfg$mcmc_retained <- 20L
    cfg$mcmc_initializer_path <- file.path(root, "evidence", c$job_id, "mcmc_initializer.json")
    cfg$mcmc_initializer_sha256 <- iqfr_v2_sha256(cfg$mcmc_initializer_path)
    cfg
  })
  iqtf_v11_plan(pilots, "pilot", root)
  for (cfg in pilots) {
    iqtf_v11_worker(cfg$config_path)
    expect_true(iqtf_v11_valid(cfg))
    d <- iqfr_v2_read_json(file.path(root, "evidence", cfg$job_id, "mcmc_diagnostics.json"))
    expect_false(d$control$init_from_vb)
    expect_equal(d$control$rng_seed, cfg$chain_seed)
    expect_equal(d$prior$tau0, cfg$candidate$rhs_tau0)
    expect_equal(nrow(read.csv(file.path(root, "evidence", cfg$job_id, "parameter_draws.csv.gz"))), 20L)
  }
  expect_equal(iqtf_v11_health(root)$counts$SUCCESS, 4)
  expect_length(list.files(root, pattern = "[.](rds|rda|rdata)$", recursive = TRUE,
    ignore.case = TRUE), 0)
})

test_that("conditional planning freezes validated stage transitions and retains all small gains", {
  refs <- iqtf_test_refs(); names(refs) <- vapply(refs, function(r) r$case_id, "")
  specs <- lapply(refs, function(r) iqtf_v11_bank(r, read.csv(iqtf_test_history))[1:2])
  root <- tempfile("v11-stage-smoke-"); dir.create(root)
  iqfr_v2_write_json(list(references = refs, candidates = specs), file.path(root, "campaign.json"))
  iqtf_v11_hash(file.path(root, "campaign.json"), file.path(root, "source_hashes.csv"))
  iqtf_v11_hash(file.path(root, "source_hashes.csv"), file.path(root, "materialization_hashes.csv"))
  finish <- function(cfg) {
    evidence <- file.path(root, "evidence", cfg$job_id)
    paths <- cfg$config_path
    if (cfg$stage == "initializers") {
      paths <- c(paths, iqfr_v2_write_json(list(test_fixture = TRUE), cfg$normal_initializer_path))
    } else {
      anchor <- cfg$candidate$candidate_id == specs[[cfg$case_id]][[1L]]$candidate_id
      score <- if (anchor) 5 else 4.999999999
      paths <- c(paths, iqfr_v2_write_csv(data.frame(estimator = "mean_conditional_location",
        forecast_qtrue_mae = score, forecast_qtrue_rmse = score + 1,
        forecast_check_loss = score, fit_point_rmse = score,
        fit_point_check_loss = score, case_id = cfg$case_id,
        candidate_id = cfg$candidate$candidate_id, arm = cfg$candidate$representation_role,
        stage = cfg$stage, chain_index = cfg$chain_index), cfg$result_path))
      paths <- c(paths, iqfr_v2_write_json(list(test_fixture = TRUE),
        file.path(evidence, "mcmc_initializer.json")))
      paths <- c(paths, iqfr_v2_write_csv_gz(data.frame(
        estimator = "mean_conditional_location", posterior_draw = 1:4,
        fit_qtrue_rmse = score + seq(-.15, .15, length.out = 4),
        forecast_qtrue_mae = score + seq(-.15, .15, length.out = 4),
        forecast_qtrue_rmse = score + seq(-.15, .15, length.out = 4),
        forecast_check_loss = score + seq(-.15, .15, length.out = 4)),
        file.path(evidence, "metric_draws.csv.gz")),
        iqfr_v2_write_csv_gz(data.frame(estimator = "mean_conditional_location",
          source_origin = rep(c(8750L, 8755L, 8760L), each = 2), lead = rep(1:2, 3),
          point_prediction = score, q_target = 0, absolute_oracle_error = score,
          check_loss = score, posterior_sd = .1), file.path(evidence, "origin_lead.csv.gz")))
      if (cfg$stage %in% c("cost", "pilot")) paths <- c(paths, iqfr_v2_write_json(list(fit_seconds = 1,
        forecast_seconds = if (cfg$stage == "cost") 4 else 1, cost_mcmc_seconds = 1, vb_max_iter = 80,
        origins = 2, outer = 4, inner = 8, mcmc_iterations = 200), file.path(evidence, "timing.json")))
    }
    iqtf_v11_hash(cfg$config_path, file.path(evidence, "input_hashes.csv"))
    iqtf_v11_hash(paths, file.path(evidence, "artifacts.csv"))
    iqfr_v2_write_json(list(status = "SUCCESS", config_sha256 = iqfr_v2_sha256(cfg$config_path),
      manifest = file.path(evidence, "artifacts.csv"), input_manifest = file.path(evidence, "input_hashes.csv")),
      cfg$status_path)
  }
  costs <- lapply(names(refs), function(case)
    iqtf_v11_config(refs[[case]], specs[[case]][[1L]], "cost", root, repo_root))
  iqtf_v11_plan(costs, "cost", root)
  expected <- c(cost = 2L, initializers = 2L, discovery = 4L, pilot = 4L, confirmation = 12L)
  for (stage in iqtf_v11_stages) {
    p <- read.csv(file.path(root, "plans", paste0(stage, ".csv")))
    expect_equal(nrow(p), expected[[stage]])
    for (path in p$config_path) finish(iqfr_v2_read_json(path))
    expect_silent(iqtf_v11_advance(repo_root, root, stage))
  }
  expect_equal(iqtf_v11_health(root)$counts$SUCCESS, sum(expected))
  expect_error(iqtf_v11_plan(costs, "cost", root), "overwrite")
  selection <- iqfr_v2_read_json(file.path(root, "pilot_selection.json"))
  expect_false(selection$diagnostic_veto); expect_length(selection$selected, 2L)
  plan <- read.csv(file.path(root, "plans/confirmation.csv"))
  cfg <- lapply(plan$config_path, iqfr_v2_read_json)
  expect_true(all(vapply(cfg, function(c) c$mcmc_burn == 5000 && c$mcmc_retained == 20000, TRUE)))
  expect_true(all(vapply(cfg, function(c) c$worker_timeout_seconds == 172800L, TRUE)))
  expect_true(all(read.csv(file.path(root, "cost_gate.csv"))$estimated_confirmation_seconds > 43200))
  expect_true(all(read.csv(file.path(root, "selected_confirmation_cost_gate.csv"))$
    estimated_confirmation_seconds < 172800))
  for (case in names(refs)) for (chain in 1:3) {
    pairs <- Filter(function(c) c$case_id == case && c$chain_index == chain, cfg)
    expect_equal(pairs[[1]]$seed, pairs[[2]]$seed)
    expect_equal(pairs[[1]]$chain_seed, pairs[[2]]$chain_seed)
  }
  expect_silent(iqtf_v11_closeout(root))
  expect_identical(iqfr_v2_read_json(file.path(root, "closeout.json"))$decision,
    "CONFIRMED_INTERNAL_FORECAST_GAIN")
  gains <- read.csv(file.path(root, "confirmed_forecast_gains.csv"))
  expect_true(all(gains$strict_gain)); expect_equal(nrow(gains), 4L)
  intervals <- read.csv(file.path(root, "posterior_score_intervals.csv"))
  expect_equal(nrow(intervals), 16L); expect_true(all(intervals$chains == 3L))
  expect_true(all(intervals$lower_025 <= intervals$posterior_score_mean &
    intervals$upper_975 >= intervals$posterior_score_mean))
  expect_silent(iqtf_v11_verify(file.path(root, "final_artifact_manifest.csv")))
  expect_gt(file.info(file.path(root, "targeted_forecast_review.pdf"))$size, 0)
})
