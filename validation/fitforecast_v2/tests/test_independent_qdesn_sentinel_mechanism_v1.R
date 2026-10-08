repo <- normalizePath(Sys.getenv("ISM1_REPO", "."), mustWork = TRUE)
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_campaign_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_sentinel_mechanism_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_sentinel_mechanism_recovery_v1.R"))

testthat::test_that("scale-aware first-step identity retains strict semantic checks", {
  huge <- ism1_numeric_identity(1e11, 1e11 + 1e-5)
  testthat::expect_true(huge$pass)
  testthat::expect_lte(huge$max_relative_error, 1e-10)
  changed <- ism1_numeric_identity(c(1, 2, 3), c(1, 2.01, 3),
    absolute_tolerance = 1e-10, relative_tolerance = 1e-10)
  testthat::expect_false(changed$pass)
  nonfinite <- ism1_numeric_identity(1, Inf)
  testthat::expect_false(nonfinite$pass)
})

testthat::test_that("recovery stage contract starts at the interrupted quantile screen", {
  testthat::expect_identical(ism1r_source_stages,
    c("smoke", "normal_screen", "quantile_screen"))
  testthat::expect_identical(ism1r_run_stages,
    c("quantile_screen", "online_pilot", "short_mcmc", "full_mcmc",
      "controls_vb", "controls_mcmc"))
  scheduler <- file.path(repo, "validation/fitforecast_v2/scripts",
    "run_independent_qdesn_sentinel_mechanism_recovery_v1.sh")
  testthat::expect_equal(system2("bash", c("-n", scheduler)), 0L)
  text <- paste(readLines(scheduler, warn = FALSE), collapse = "\n")
  testthat::expect_match(text,
    "for stage in quantile_screen online_pilot short_mcmc full_mcmc controls_vb controls_mcmc",
    fixed = TRUE)
  testthat::expect_false(grepl("for stage in smoke normal_screen", text, fixed = TRUE))
})

ism1_test_reference <- function() list(n = "40", m = 120L, alpha = .4,
  rho = .5, center_scale = "mean_sd", input_bound = "none",
  input_gain = 1, recurrent_indegree = 20L, input_fanin = 60L,
  interlayer_fanin = 1L, matrix_seed = 920001L, tau_source = .01,
  slab_source = 4, sigma_b_source = 2, omega_b_source = 4)

testthat::test_that("space-filling bank covers all mechanisms without duplicate identities", {
  counts <- c(reservoir_only = 8L, hybrid_direct_lags = 8L, lag_only = 8L)
  bank <- ism1_generate_bank(ism1_test_reference(), counts)
  z <- ism1_bank_frame(bank)
  testthat::expect_equal(nrow(z), 24L)
  testthat::expect_equal(length(unique(z$id)), 24L)
  testthat::expect_equal(as.integer(table(factor(z$readout_mode,
    levels = names(counts)))), as.integer(counts))
  testthat::expect_true(all(z$D >= 1L & z$D <= 6L))
  testthat::expect_true(all(z$total_states <= 1500L))
  testthat::expect_true(all(z$m >= 1L & z$m <= 500L))
  testthat::expect_true(all(z$readout_dimension == ifelse(z$readout_mode == "reservoir_only",
    1L + z$total_states, ifelse(z$readout_mode == "lag_only", 1L + z$m,
      1L + z$total_states + z$m))))
  lag <- z[z$readout_mode == "lag_only", ]
  testthat::expect_true(all(lag$n == "20"))
  testthat::expect_true(all(lag$total_states == 20L))
  testthat::expect_true(all(lag$alpha == .5 & lag$rho == .5))
  testthat::expect_true(all(lag$input_gain == 1))
})

testthat::test_that("all selection folds are internal and causal", {
  candidate <- ism1_candidate(ism1_test_reference(), ism1_test_reference())
  for (fold in ism1_folds) {
    w <- ism1_window(fold, candidate, "quantile_screen")
    testthat::expect_equal(length(w$train), 1000L)
    testthat::expect_equal(length(w$washout), 500L)
    testthat::expect_equal(length(w$buffer), candidate$m)
    testthat::expect_lte(max(w$train), 8750L)
    testthat::expect_lte(w$end, 9000L)
    testthat::expect_true(all(w$origins >= max(w$train)))
    testthat::expect_equal(w$horizon, 30L)
  }
})

testthat::test_that("readout rows have exact declared dimensions", {
  n <- c(4L, 3L); count <- 5L
  h <- list(matrix(0, 4L, count), matrix(0, 3L, count))
  z <- matrix(0, 6L, count)
  for (mode in c("reservoir_only", "lag_only", "hybrid_direct_lags")) {
    object <- list(reservoir = list(D = 2L), meta = list(sentinel_readout_mode = mode))
    x <- ism1_readout_row(object, h, z)
    expected <- switch(mode, reservoir_only = 1L + sum(n), lag_only = 7L,
      hybrid_direct_lags = 1L + sum(n) + 6L)
    testthat::expect_equal(dim(x), c(expected, count))
  }
})

testthat::test_that("effective model size controls dimension-aware global shrinkage", {
  ref <- ism1_test_reference()
  small <- ref; small$n <- "40"
  large <- ref; large$n <- "500;500"
  a <- ism1_candidate(small, ref, effective_p0 = 15)
  b <- ism1_candidate(large, ref, effective_p0 = 15)
  testthat::expect_gt(a$tau_source, b$tau_source)
  testthat::expect_true(a$tau_source > 0 && b$tau_source > 0)
})

testthat::test_that("candidate-specific lag shrinkage alters only direct-lag precision", {
  ref <- ism1_test_reference()
  c <- ism1_candidate(ref, ref, "hybrid_direct_lags", 15, 4)
  cfg <- list(candidate = c)
  e <- new.env(parent = emptyenv())
  e$exal_make_beta_prior <- function(type, rhs) list(
    expected_prec = function(state, p) seq_len(p), rhs = rhs)
  old <- ism1_base_prior
  on.exit(assign("ism1_base_prior", old, envir = .GlobalEnv))
  assign("ism1_base_prior", function(e, cfg, scale) list(beta = list(
    expected_prec = function(state, p) rep(1, p)), rhs = list()), envir = .GlobalEnv)
  prior <- ism1_prior(e, cfg, 1)
  z <- prior$beta$expected_prec(list(), c$readout_dimension)
  lag <- seq.int(2L + sum(iqt12_unpack(c$n)), c$readout_dimension)
  testthat::expect_true(all(z[lag] == 4))
  testthat::expect_true(all(z[-lag] == 1))
})

testthat::test_that("stage configs preserve one-model-per-process budgets and M0 likelihood", {
  ref <- ism1_test_reference(); c <- ism1_candidate(ref, ref, "hybrid_direct_lags")
  state <- list(run = tempfile(), repo = repo, library = tempfile(),
    references = setNames(list(list(family = "normal", p = .05, likelihood = "exal",
      source_path = tempfile(), source_sha = "x", baseline = list())), ism1_sentinel))
  cfg <- ism1_config(state, ism1_sentinel, c, "full_mcmc", "mcmc", "S4", chain = 3L)
  testthat::expect_equal(cfg$burn, 5000L)
  testthat::expect_equal(cfg$retained, 20000L)
  testthat::expect_equal(cfg$outer, 200L)
  testthat::expect_equal(cfg$inner, 128L)
  testthat::expect_false(cfg$online_update)
  testthat::expect_equal(cfg$likelihood, "exal")
})

ism1_test_complete <- function(plan) {
  for (path in plan$config_path) {
    cfg <- iqt12_read(path)
    key <- strtoi(substr(digest::digest(cfg$candidate$id, algo = "sha256"), 1L, 6L), 16L)
    base <- 1 + (key %% 1000) / 1000
    if (cfg$model == "baseline") base <- 1.5
    if (isTRUE(cfg$online_update)) base <- base * .98
    z <- data.frame(id = cfg$id, cell = cfg$cell, candidate_id = cfg$candidate$id,
      model = cfg$model, engine = cfg$engine, family = cfg$family, p = cfg$p,
      N = cfg$window$N, fold = cfg$window$fold, chain = cfg$chain,
      normal_observed_mae = base,
      metric = c("fit_rmse", "fit_check_loss", "forecast_mae", "forecast_rmse",
        "forecast_check_loss"), mean = base * c(.8, .5, 1, 1.2, .6),
      lower = base * c(.7, .4, .9, 1.1, .5),
      upper = base * c(.9, .6, 1.1, 1.3, .7))
    iqt12_csv(z, file.path(cfg$evidence, "summary.csv"))
    iqt12_json(list(design_hash = "synthetic", initial = list(beta = 0,
      sigma = 1, gamma = 0, v = 1, s = 1)),
      file.path(cfg$evidence, "mcmc_initializer.json"))
    manifest <- iqt12_hash(list.files(cfg$evidence, full.names = TRUE),
      file.path(cfg$evidence, "manifest.csv"))
    iqt12_json(list(status = "SUCCESS", id = cfg$id, manifest = manifest,
      elapsed = 1, cpu_seconds = 1, fitted_binary_payloads = 0L), cfg$status_path)
  }
}

testthat::test_that("the complete sentinel stage graph is deterministic and closable", {
  root <- tempfile(); dir.create(root)
  ref <- ism1_test_reference()
  base <- ism1_candidate(ref, ref, "reservoir_only", 15, 1, "control_anchor")
  references <- list()
  for (cell in c(ism1_sentinel, ism1_controls)) {
    part <- strsplit(cell, "__", fixed = TRUE)[[1L]]
    references[[cell]] <- list(family = part[1L], p = .05,
      likelihood = part[2L], candidate = base, source_path = "synthetic",
      source_sha = "synthetic", baseline = list())
  }
  state <- list(schema = ism1_schema, run = root, repo = repo, library = "synthetic",
    references = references, sentinel = ism1_sentinel, controls = ism1_controls,
    bank = ism1_generate_bank(ref,
      c(reservoir_only = 8L, hybrid_direct_lags = 8L, lag_only = 8L)),
    max_workers = 15L)
  iqt12_json(state, file.path(root, "campaign.json"))
  iqt12_json(list(synthetic = TRUE), file.path(root, "environment.json"))
  iqt12_csv(ism1_bank_frame(state$bank), file.path(root, "candidate_bank.csv"))
  for (name in c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv",
      "frozen_hashes.csv")) writeLines("synthetic", file.path(root, name))
  anchors <- state$bank[vapply(state$bank, function(c)
    c$role == "exact_anchor_readout_ablation", TRUE)]
  configs <- unlist(lapply(anchors, function(c) list(
    ism1_config(state, ism1_sentinel, c, "smoke", "normal", "S1"),
    ism1_config(state, ism1_sentinel, c, "smoke", "vb", "S1"))), recursive = FALSE)
  ism1_plan(state, configs, "smoke")
  for (stage in ism1_stages) {
    plan <- read.csv(file.path(root, "plans", paste0(stage, ".csv")),
      stringsAsFactors = FALSE)
    ism1_test_complete(plan)
    result <- ism1_advance(root, stage)
    if (stage != tail(ism1_stages, 1L))
      testthat::expect_identical(result, ism1_stages[match(stage, ism1_stages) + 1L])
  }
  testthat::expect_identical(result, "COMPLETE_REVIEW_REQUIRED")
  testthat::expect_true(file.exists(file.path(root, "closeout.json")))
  testthat::expect_true(iqt12_verify(file.path(root, "closeout_manifest.csv")))
  testthat::expect_equal(ism1_health(root)$failed, 0L)
})
