iqct_test_load <- function() {
  source(file.path(harness_root, "R/independent_qdesn_coupled_tau_v6.R"), local = FALSE)
  iqct_v6_source(repo_root)
}

iqct_test_configs <- function() {
  original <- setNames(rep(list(1), length(iqbs_v5_science_fields)), iqbs_v5_science_fields)
  original$candidate <- list(rhs_tau0 = .01, rhs_tau0_source_scale = .2, D = 2, n = "4;3", m = 12,
    candidate_id = "fixture", tau0_multiplier = 1)
  cfg <- original
  cfg$beta_covariance_approximation <- "full"
  cfg$tau_multiplier <- 30
  cfg$candidate$rhs_tau0 <- .3
  cfg$candidate$rhs_tau0_source_scale <- 6
  cfg$candidate$tau0_multiplier <- 30
  cfg$candidate$candidate_id <- "new_identity"
  list(original = original, cfg = cfg)
}

test_that("v6 paired intervention changes only declared tau fields", {
  iqct_test_load()
  fixture <- iqct_test_configs()
  expect_true(iqct_v6_science_check(fixture$original, fixture$cfg))
  changed <- fixture$cfg; changed$candidate$m <- 13
  expect_false(iqct_v6_science_check(fixture$original, changed))
  changed <- fixture$cfg; changed$seed <- 2
  expect_false(iqct_v6_science_check(fixture$original, changed))
  changed <- fixture$cfg; changed$beta_covariance_approximation <- "diagonal"
  expect_false(iqct_v6_science_check(fixture$original, changed))
  changed <- fixture$cfg; changed$candidate$rhs_tau0_source_scale <- .3
  expect_false(iqct_v6_science_check(fixture$original, changed))
  changed <- fixture$cfg; changed$tau_multiplier <- 500
  expect_false(iqct_v6_science_check(fixture$original, changed))
})

test_that("frozen initializer roundtrips correlated covariance and restores RNG", {
  iqct_test_load()
  root <- tempfile("v6_init_test_"); dir.create(root)
  init <- list(beta_m = c(.3, -.1, .05), beta_V = matrix(c(2,.3,0,.3,1,.1,0,.1,.4), 3), sigma = .5)
  set.seed(193)
  rng <- .Random.seed; expected <- runif(4)
  payload <- list(schema = iqct_v6_schema, initialization = init,
    initialization_digest = iqct_v6_init_digest(init), source_sha256 = "source",
    design_sha256 = "design", reference_config_sha256 = "config",
    reference_tau0 = .01, probability = .25, likelihood = "exal",
    rng_kind = RNGkind(), rng_after_normal = rng)
  path <- file.path(root, "init.json"); iqfr_v2_write_json(payload, path)
  cfg <- list(job_id = "smoke", run_root = root, frozen_initializer_path = path,
    frozen_initializer_sha256 = iqfr_v2_sha256(path), source = list(frozen_sha256 = "source"),
    baseline_config_sha256 = "config", probability = .25, likelihood_family = "exal",
    candidate = list(rhs_tau0 = .3), rhs_s2 = 1)
  loaded <- iqct_v6_load_initializer(cfg)
  expect_equal(loaded$init$beta_m, init$beta_m, tolerance = 1e-12)
  expect_equal(loaded$init$beta_V, init$beta_V, tolerance = 1e-12)
  expect_equal(runif(4), expected, tolerance = 1e-12)
  expect_null(loaded$init$beta_state)
  info <- iqfr_v2_read_json(loaded$artifact)
  expect_equal(info$initial_tau2, .09, tolerance = 1e-12)
  expect_equal(info$initial_intercept_precision, 1e-16, tolerance = 1e-12)
  expect_false(info$beta_state_transferred)
  damaged <- cfg; damaged$frozen_initializer_sha256 <- "wrong"
  expect_error(iqct_v6_load_initializer(damaged))
  payload$initialization$beta_state <- list(tau2 = .0001)
  iqfr_v2_write_json(payload, path)
  cfg$frozen_initializer_sha256 <- iqfr_v2_sha256(path)
  expect_error(iqct_v6_load_initializer(cfg))
})

test_that("prior state starts at each arm scale and leaves intercept unshrunk", {
  iqct_test_load()
  precision <- lapply(iqct_v6_multipliers, function(multiplier) {
    tau0 <- .00332871332649303 * multiplier
    prior <- exdqlm:::exal_make_beta_prior(type = "rhs_ns",
      rhs = list(tau0 = tau0, s2 = 1, shrink_intercept = FALSE, n_inner = 2L))
    state <- prior$init(8L)
    expect_equal(state$tau2, tau0^2, tolerance = 1e-12)
    expect_equal(state$iter, 0L)
    prior$expected_prec(state, 8L)
  })
  expect_true(all(vapply(precision, function(x) x[1] == 1e-16, TRUE)))
  expect_true(all(diff(vapply(precision, function(x) median(x[-1L]), 1.0)) < 0))
})

test_that("reference replay gate fails closed on unfinished controls", {
  iqct_test_load()
  root <- tempfile("v6_gate_test_"); dir.create(root)
  configs <- file.path(root, paste0("cfg", 1:2, ".json"))
  for (i in 1:2) iqfr_v2_write_json(list(job_id = paste0("control", i)), configs[i])
  iqfr_v2_write_csv(data.frame(stage = "reference_replay", config_path = configs,
    status_path = file.path(root, paste0("missing", 1:2, ".json"))), file.path(root, "plan.csv"))
  expect_error(iqct_v6_replay_gate(root), "hold all tau scheduling")
  audit <- read.csv(file.path(root, "reference_replay_audit.csv"))
  expect_true(all(!audit$pass))
})

test_that("frozen input verification rejects changed comparator scores", {
  iqct_test_load()
  root <- tempfile("v6_manifest_test_"); dir.create(root)
  comparator <- file.path(root, "development_comparators.csv")
  iqfr_v2_write_csv(data.frame(forecast_qtrue_mae = 2), comparator)
  for (name in c("source_hashes.csv", "input_hashes.csv", "materialization_hashes.csv")) {
    iqbs_v5_hash_manifest(comparator, file.path(root, name))
  }
  expect_true(iqct_v6_verify_inputs(root))
  iqfr_v2_write_csv(data.frame(forecast_qtrue_mae = 3), comparator)
  expect_error(iqct_v6_verify_inputs(root), "Manifest hash mismatch")
})

test_that("v6 runner gates six arms behind two replays and bounds the benchmark", {
  iqct_test_load()
  shell <- paste(readLines(file.path(harness_root, "scripts/run_independent_qdesn_coupled_tau_v6.sh")), collapse = "\n")
  replay <- regexpr("replay-gate", shell, fixed = TRUE)[1]
  arms <- regexpr("run_stage tau_screen 6", shell, fixed = TRUE)[1]
  expect_lt(replay, arms)
  expect_match(shell, "run_stage reference_replay 2", fixed = TRUE)
  expect_match(shell, "OMP_NUM_THREADS=1", fixed = TRUE)
  expect_match(shell, "7200s", fixed = TRUE)
  expect_match(shell, "1800s", fixed = TRUE)
  expect_match(shell, "flock -n 9", fixed = TRUE)
  expect_false(grepl("git push|killall|pkill|rm -rf", shell))
})
