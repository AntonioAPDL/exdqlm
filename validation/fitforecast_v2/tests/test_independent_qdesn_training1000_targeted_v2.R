repo <- normalizePath(Sys.getenv("IQT12_REPO", "."), mustWork = TRUE)
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_campaign_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_targeted_v2.R"))

iqt12t_test_state <- function() {
  root <- tempfile(); dir.create(root)
  base <- list(n = "20;20", m = 120L, alpha = .6, rho = .9,
    input_gain = 1, input_fanin = 20L, recurrent_indegree = 10L,
    interlayer_fanin = 10L, matrix_seed = 920001L,
    center_scale = "mean_sd", input_bound = "none")
  prior <- list(tau_source = .3, slab_source = 4, sigma_b_source = 1, omega_b_source = 1)
  anchor <- iqt12_candidate(base, prior)
  pool <- list(anchor)
  for (i in 1:6) {
    c <- base; c$alpha <- .5 + i / 100; c$m <- 30L * i
    pool[[length(pool) + 1L]] <- iqt12_candidate(c, prior, role = "local_capacity_search")
  }
  for (widths in c("500", "500;64;300", "500;64;64;64")) {
    c <- base; c$n <- widths; c$alpha <- .95
    pool[[length(pool) + 1L]] <- iqt12_candidate(c, prior, role = "stratified_unseen")
  }
  c <- base; c$alpha <- .05; c$m <- 390L; c$input_gain <- .05
  pool[[length(pool) + 1L]] <- iqt12_candidate(c, prior, role = "stratified_unseen")
  state <- list(protocol = "training1000_targeted_v2_case_specific_continuation",
    run = root, repo = repo, library = "synthetic", references = list(),
    bank = setNames(rep(list(pool), 3), c("normal", "laplace", "gausmix")),
    priority = iqt12t_priority, signals = iqt12t_signals)
  for (family in c("normal", "laplace", "gausmix")) for (p in c(.05, .25, .5))
    for (likelihood in c("al", "exal")) {
      cell <- iqt12_cell(family, p, likelihood)
      state$references[[cell]] <- list(family = family, p = p, likelihood = likelihood,
        candidate = anchor, source_path = "synthetic", source_sha = "synthetic", baseline = list())
    }
  state$portfolios <- setNames(lapply(state$priority, function(cell)
    iqt12t_portfolio(state, cell)), state$priority)
  iqt12_csv(do.call(rbind, lapply(state$priority, function(cell)
    data.frame(cell = cell, id = vapply(state$portfolios[[cell]], function(c) c$id, "")))),
    file.path(root, "candidate_banks/targeted_pairs.csv"))
  input <- file.path(root, "input.txt"); writeLines("synthetic", input)
  iqt12_hash(input, file.path(root, "input_hashes.csv"))
  iqt12_json(state, file.path(root, "campaign.json"))
  state
}

iqt12t_test_complete <- function(plan, equality = FALSE) {
  for (p in plan$config_path) {
    cfg <- iqt12_read(p)
    score <- if (equality) 3 else if (cfg$window$N == 500L) 4 else
      if (cfg$candidate$role == "exact_anchor" || cfg$candidate$role == "anchor") 3 else
        if (cfg$candidate$role == "capacity_deep") 1 else 2
    z <- data.frame(id = cfg$id, cell = cfg$cell, candidate_id = cfg$candidate$id,
      model = cfg$model, engine = cfg$engine, N = cfg$window$N,
      metric = c("fit_rmse", "fit_check_loss", "forecast_mae", "forecast_rmse", "forecast_check_loss"),
      mean = score, lower = score / 2, upper = score * 2, diagnostic = "FAIL")
    iqt12_csv(z, file.path(cfg$evidence, "summary.csv"))
    iqt12_json(list(design_hash = "synthetic", initial = list(beta = 1, sigma = 1)),
      file.path(cfg$evidence, "mcmc_initializer.json"))
    m <- file.path(cfg$evidence, "manifest.csv")
    iqt12_hash(list.files(cfg$evidence, full.names = TRUE), m)
    iqt12_json(list(status = "SUCCESS", manifest = m), cfg$status_path)
  }
}

testthat::test_that("matrix and MCMC columns retain physical parameter labels", {
  sigma <- coda::mcmc(matrix(c(1, 2, 3), ncol = 1))
  gamma <- coda::mcmc(matrix(c(.1, .2, .3), ncol = 1))
  z <- iqt12_nuisance_trace(sigma, gamma, matrix(4:6, ncol = 1))
  testthat::expect_identical(names(z), c("iteration", "sigma", "gamma", "intercept"))
  testthat::expect_equal(z$sigma, 1:3)
  p <- tempfile(fileext = ".csv.gz"); iqt12_csv(z, p)
  testthat::expect_identical(names(read.csv(p)), names(z))
  testthat::expect_error(iqt12_nuisance_trace(c(1, -1), c(0, 0)))
  testthat::expect_error(iqt12_nuisance_trace(1:3, 0))
})

testthat::test_that("gate count equality and median failure are reported separately", {
  z <- data.frame(strict_gain = c(rep(TRUE, 9), rep(FALSE, 9)),
    ratio_1000_over_500 = c(rep(.999, 9), rep(1.02, 9)))
  g <- iqt12_size_gate(z)
  testthat::expect_true(g$count_pass)
  testthat::expect_false(g$median_pass)
  testthat::expect_identical(g$reason, "median_forecast_MAE_ratio_above_one")
  z$ratio_1000_over_500 <- c(rep(.9, 9), rep(1.1, 9))
  testthat::expect_true(iqt12_size_gate(z)$pass)
  z$strict_gain[1] <- FALSE
  testthat::expect_identical(iqt12_size_gate(z)$reason, "improvement_count_below_half")
  z$ratio_1000_over_500[1] <- NA
  testthat::expect_error(iqt12_size_gate(z))
})

testthat::test_that("portfolios are bounded, diverse and use case-specific priors", {
  state <- iqt12t_test_state()
  for (cell in state$priority) {
    p <- state$portfolios[[cell]]
    testthat::expect_length(p, 24L)
    testthat::expect_equal(length(unique(vapply(p, function(c) c$structure_id, ""))), 8L)
    testthat::expect_equal(sort(unique(vapply(p, function(c) c$tau_source, 0.0))), c(.03, .3, 3))
    testthat::expect_true(any(vapply(p, function(c) c$role == "capacity_deep" && c$D >= 3L &&
      max(iqt12_unpack(c$n)) >= 500L, TRUE)))
    testthat::expect_true(any(vapply(p, function(c) c$id == state$references[[cell]]$candidate$id, TRUE)))
  }
})

testthat::test_that("finite tiny case gains count despite diagnostic FAIL labels", {
  state <- iqt12t_test_state()
  configs <- list()
  for (cell in state$priority) {
    for (c in state$portfolios[[cell]][1:4]) configs[[length(configs) + 1L]] <-
      iqt12_config(state, cell, c, "bridge", "mcmc", fold = "B")
  }
  for (cell in state$signals) for (N in c(500L, 1000L))
    configs[[length(configs) + 1L]] <- iqt12_config(state, cell,
      state$references[[cell]]$candidate, "bridge", "mcmc", N = N, fold = "B")
  plan <- iqt12_plan(state, configs, "bridge"); iqt12t_test_complete(plan, equality = TRUE)
  results <- iqt12_results(state$run, "bridge")
  testthat::expect_false(any(iqt12t_forecast_decision(results, state)$strict_gain))
  ix <- results$cell == state$priority[1] & results$candidate_id !=
    state$references[[state$priority[1]]]$candidate$id & results$metric == "forecast_mae"
  results$mean[ix] <- 3 - 1e-9
  testthat::expect_true(any(iqt12t_forecast_decision(results, state)$strict_gain))
})

testthat::test_that("all staged plans preserve anchors, controls, warm starts and complete final surface", {
  state <- iqt12t_test_state(); root <- state$run
  configs <- unlist(lapply(state$priority, function(cell) lapply(state$portfolios[[cell]],
    function(c) iqt12_config(state, cell, c, "quantile_A"))), recursive = FALSE)
  plan <- iqt12_plan(state, configs, "quantile_A"); iqt12t_test_complete(plan)
  testthat::expect_equal(nrow(plan), 96L)
  testthat::expect_identical(iqt12t_advance(root, "quantile_A"), "quantile_B")
  b <- read.csv(file.path(root, "plans/quantile_B.csv"))
  testthat::expect_equal(nrow(b), 48L)
  for (cell in state$priority) {
    nom <- read.csv(file.path(root, "selections", paste0("frozen_B_", cell, ".csv")))
    testthat::expect_equal(nrow(nom), 4L)
    testthat::expect_true(any(nom$selection_role %in% c("capacity_shallow", "capacity_deep")))
    testthat::expect_true(state$references[[cell]]$candidate$id %in% nom$candidate_id)
  }
  iqt12t_test_complete(b)
  testthat::expect_identical(iqt12t_advance(root, "quantile_B"), "bridge")
  m <- read.csv(file.path(root, "plans/bridge.csv"))
  testthat::expect_equal(nrow(m), 66L)
  testthat::expect_equal(sum(m$N == 500L), 18L)
  testthat::expect_true(all(m$fold == "B"))
  warm <- lapply(m$config_path[m$N == 1000L], iqt12_read)
  testthat::expect_true(all(vapply(warm, function(c) file.exists(c$warm_path), TRUE)))
  iqt12t_test_complete(m)
  testthat::expect_identical(iqt12t_advance(root, "bridge"), "final_vb")
  final <- read.csv(file.path(root, "plans/final_vb.csv"))
  testthat::expect_equal(nrow(final), 36L)
  testthat::expect_true(all(final$N == 1000L & final$fold == "final"))
  winners <- read.csv(file.path(root, "selections/frozen_final_winners.csv"))
  testthat::expect_equal(nrow(winners), 36L)
  iqt12t_test_complete(final)
  testthat::expect_identical(iqt12t_advance(root, "final_vb"), "final_warm")
  warms <- read.csv(file.path(root, "plans/final_warm.csv")); iqt12t_test_complete(warms)
  testthat::expect_identical(iqt12t_advance(root, "final_warm"), "final_mcmc")
  mc <- read.csv(file.path(root, "plans/final_mcmc.csv"))
  testthat::expect_equal(nrow(mc), 108L)
  testthat::expect_true(all(vapply(mc$config_path, function(p) {
    c <- iqt12_read(p)
    c$burn == 5000L && c$retained == 20000L && c$outer == 300L && c$inner == 128L &&
      file.exists(c$warm_path)
  }, TRUE)))
})

testthat::test_that("no gain closes development without scoring final targets", {
  state <- iqt12t_test_state()
  configs <- list()
  for (cell in c(state$priority, state$signals)) for (N in c(500L, 1000L))
    configs[[length(configs) + 1L]] <- iqt12_config(state, cell,
      state$references[[cell]]$candidate, "bridge", "mcmc", N = N, fold = "B")
  plan <- iqt12_plan(state, configs, "bridge"); iqt12t_test_complete(plan, equality = TRUE)
  testthat::expect_identical(iqt12t_advance(state$run, "bridge"),
    "COMPLETE_NO_MCMC_DEVELOPMENT_FORECAST_GAIN")
  testthat::expect_false(file.exists(file.path(state$run, "plans/final_vb.csv")))
  testthat::expect_true(iqt12_verify(file.path(state$run, "development_closeout_manifest.csv")))
})
