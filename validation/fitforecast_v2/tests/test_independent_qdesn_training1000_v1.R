repo <- normalizePath(Sys.getenv("IQT12_REPO", "."), mustWork = TRUE)
while (!file.exists(file.path(repo, "R/qdesn_vb.R"))) {
  parent <- dirname(repo)
  if (parent == repo) stop("Cannot locate IND repository root.")
  repo <- parent
}
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_campaign_v1.R"))

testthat::test_that("likelihood masks, complete washout and forecast grids are fixed", {
  for (N in c(500L, 1000L)) for (fold in c("A", "B", "final")) {
    w <- iqt12_window(fold, N)
    testthat::expect_length(w$train, N)
    testthat::expect_length(w$washout, 500L)
    testthat::expect_length(w$buffer, 390L)
    testthat::expect_equal(max(w$washout) + 1L, min(w$train))
    grid <- iqt12_grid(w)
    testthat::expect_true(all(grid$target == grid$origin + grid$lead))
    testthat::expect_true(all(grid$lead <= 30L))
    testthat::expect_equal(nrow(grid), if (fold == "final") 1000L else 1350L)
  }
  testthat::expect_equal(iqt12_window("final")$train, 8001:9000)
  testthat::expect_error(iqt12_window("A", 1500), "N %in%")
})

testthat::test_that("nominal precision is preserved rather than jittered", {
  set.seed(5); X <- matrix(rnorm(240), 60, 4)
  A <- crossprod(X) + diag(c(1e-2, 1e3, 1e5, 1e7))
  b <- c(3, -1, 4, 9); z <- iqt12_solve(A, b)
  testthat::expect_equal(z$jitter_eps, 0)
  testthat::expect_equal(z$x, as.numeric(solve(A, b)), tolerance = 1e-6)
  testthat::expect_equal(z$inv, solve(A), tolerance = 1e-6)
  testthat::expect_lt(z$nominal_residual, 1e-6)
  testthat::expect_equal(z$logdet, as.numeric(determinant(A, logarithm = TRUE)$modulus))
  testthat::expect_error(iqt12_solve(diag(c(-1, 1))), "not SPD")
})

testthat::test_that("source-scale priors and identity dimensions participate in candidate identity", {
  c <- list(n = "500;500;500;500", m = 390L, alpha = .99, rho = .995,
    center_scale = "mean_sd", input_bound = "none", input_gain = 1,
    recurrent_indegree = 20, input_fanin = 40, interlayer_fanin = 20, matrix_seed = 1)
  ref <- list(tau_source = .3, slab_source = 400, sigma_b_source = 20, omega_b_source = 400)
  z <- iqt12_candidate(c, ref, .1)
  testthat::expect_equal(z$readout_dimension, 2001L)
  testthat::expect_equal(z$n_tilde, "500;500;500")
  testthat::expect_equal(z$tau_source, .03)
  testthat::expect_equal(z$matrix_seed, 920001L)
  testthat::expect_false(identical(z$id, iqt12_candidate(c, ref, 1)$id))
  c$input_gain <- .2
  testthat::expect_false(identical(z$structure_id, iqt12_candidate(c, ref, .1)$structure_id))
})

testthat::test_that("canonical identities describe feasible effective fan-in", {
  c <- list(n = "20;40", m = 15L, alpha = .7, rho = .9,
    center_scale = "mean_sd", input_bound = "none", input_gain = 1,
    recurrent_indegree = 40L, input_fanin = 80L, interlayer_fanin = 30L, matrix_seed = 1L)
  normalized <- iqt12_topology(c)
  testthat::expect_equal(normalized$input_fanin, 16L)
  testthat::expect_equal(normalized$recurrent_indegree, 20L)
  testthat::expect_equal(normalized$interlayer_fanin, 20L)
  testthat::expect_identical(iqt12_signature(c), iqt12_signature(normalized))
  c$n <- "20"; c$interlayer_fanin <- 20L
  equivalent <- c; equivalent$interlayer_fanin <- 1L
  testthat::expect_identical(iqt12_signature(c), iqt12_signature(equivalent))
  equivalent$m <- as.numeric(equivalent$m)
  testthat::expect_identical(iqt12_signature(c), iqt12_signature(equivalent))
  reference <- list(tau_source = .3, slab_source = 400, sigma_b_source = 20, omega_b_source = 400)
  candidate <- iqt12_candidate(c, reference)
  p <- tempfile(fileext = ".json"); iqt12_json(candidate, p)
  replay <- iqt12_candidate(iqt12_read(p), reference)
  testthat::expect_identical(candidate$id, replay$id)
  testthat::expect_identical(candidate$structure_id, replay$structure_id)
})

testthat::test_that("every posterior draw receives its own properly oriented loss", {
  w <- iqt12_window("A", 500); w$origins <- 8500L; w$horizon <- 2L
  s <- data.frame(q_target = rep(1, 8750), y = rep(1, 8750))
  fit <- matrix(1, 500, 2); forecast <- matrix(c(0, 2, 2, 0), 2, 2)
  z <- iqt12_scores(fit, forecast, s, w, .25)
  testthat::expect_equal(z$draws$fit_rmse, c(0, 0))
  testthat::expect_equal(z$draws$forecast_mae, c(1, 1))
  testthat::expect_equal(z$draws$forecast_rmse, c(1, 1))
  testthat::expect_equal(z$draws$forecast_check_loss, c(.5, .5))
  testthat::expect_equal(mean(abs(rowMeans(forecast) - 1)), 0)
  testthat::expect_error(iqt12_scores(fit, matrix(NA, 2, 2), s, w, .25))
})

testthat::test_that("JSON initializers and hash manifests survive round trips", {
  root <- tempfile(); dir.create(root)
  p <- file.path(root, "warm.json")
  x <- list(initial = list(beta = 1:3, sigma = 4, v = c(.1, .2),
    theta.out = list(sm = matrix(1:8, 2, 4))), design_hash = "abc")
  iqt12_json(x, p); y <- iqt12_read(p)
  testthat::expect_equal(y$initial$beta, x$initial$beta)
  testthat::expect_equal(as.matrix(y$initial$theta.out$sm), x$initial$theta.out$sm)
  m <- file.path(root, "manifest.csv"); iqt12_hash(p, m)
  testthat::expect_true(iqt12_verify(m))
  iqt12_json(list(changed = TRUE), p)
  testthat::expect_error(iqt12_verify(m))
})

testthat::test_that("plans are immutable and final MCMC uses declared lengths", {
  root <- tempfile(); dir.create(root)
  cell <- iqt12_cell("normal", .25, "exal")
  c <- list(id = "abc", readout_dimension = 21L)
  state <- list(run = root, repo = repo, library = "pinned",
    references = setNames(list(list(family = "normal", p = .25, likelihood = "exal",
      source_path = "source", source_sha = "hash", baseline = list())), cell))
  cfg <- iqt12_config(state, cell, c, "final_mcmc", "mcmc", fold = "final")
  testthat::expect_equal(cfg$burn, 5000L)
  testthat::expect_equal(cfg$retained, 20000L)
  testthat::expect_equal(cfg$outer, 300L)
  testthat::expect_equal(cfg$inner, 128L)
  plan <- iqt12_plan(state, list(cfg), "final_mcmc")
  testthat::expect_equal(nrow(plan), 1L)
  testthat::expect_error(iqt12_plan(state, list(cfg), "final_mcmc"), "Frozen")
  health <- iqt12_health(root)
  testthat::expect_equal(health$pending, 1L)
  testthat::expect_equal(health$failed, 0L)
  iqt12_plan(state, list(), "final_warm")
  testthat::expect_true(is.null(iqt12_results(root, "final_warm")))
})

testthat::test_that("ranking is per case and never filters diagnostic grades", {
  root <- tempfile(); dir.create(root)
  z <- do.call(rbind, lapply(1:2, function(i) {
    path <- file.path(root, paste0(i, ".json"))
    iqt12_json(list(candidate = list(readout_dimension = 10L + i)), path)
    data.frame(config_path = path, candidate_id = as.character(i),
      metric = c("forecast_mae", "forecast_check_loss", "fit_rmse"),
      mean = c(if (i == 1) 1 else 1 - 1e-9, 2, 3), diagnostic = c("PASS", "FAIL")[i])
  }))
  testthat::expect_equal(iqt12_rank(z)$candidate_id[1], "2")
})

testthat::test_that("shared fan-in supports deeper identity-Q layers", {
  lib <- file.path(repo, "validation/fitforecast_v2/local_trackers/training1000_exdqlm112_runtime/Rlib")
  testthat::skip_if_not(dir.exists(file.path(lib, "exdqlm")))
  e <- iqt12_runtime(repo, lib)
  testthat::expect_error(e$.normal_desn_sym_solve(diag(c(-1, 1))), "not SPD")
  s <- data.frame(y = 10 + sin((1:10000) / 10))
  c <- list(m = 30L, alpha = .7, rho = .7, input_gain = .2,
    center_scale = "mean_sd", input_bound = "none", recurrent_indegree = 2L,
    input_fanin = 8L, interlayer_fanin = 2L, matrix_seed = 920001L)
  for (widths in list(c(6, 5, 4), c(6, 5, 4, 3))) {
    c$n <- paste(widths, collapse = ";")
    cfg <- list(window = iqt12_window("A", 1000L), candidate = c, p = .25)
    z <- iqt12_design(e, cfg, s)
    testthat::expect_equal(ncol(z$object$X), sum(widths) + 1L)
    testthat::expect_true(all(z$object$reservoir$Q_is_identity))
  }
})

testthat::test_that("compact quantile warm starts reproduce full initialization", {
  lib <- file.path(repo, "validation/fitforecast_v2/local_trackers/training1000_exdqlm112_runtime/Rlib")
  testthat::skip_if_not(dir.exists(file.path(lib, "exdqlm")))
  e <- iqt12_runtime(repo, lib)
  set.seed(77)
  s <- data.frame(y = 10 + sin((1:10000) / 10) + rnorm(10000), q_target = rep(10, 10000))
  w <- iqt12_window("A", 500L)
  w$N <- 80L; w$train <- 8421:8500; w$washout <- 7921:8420; w$buffer <- 7531:7920
  c <- list(n = "8", m = 30L, alpha = .7, rho = .7, input_gain = .2,
    center_scale = "mean_sd", input_bound = "none", recurrent_indegree = 4L,
    input_fanin = 8L, interlayer_fanin = 4L, matrix_seed = 920001L,
    tau_source = .3, slab_source = 4, sigma_b_source = 1, omega_b_source = 1)
  cfg <- list(window = w, candidate = c, p = .25, seed = 442L, normal_iter = 20L,
    vb_iter = 25L, engine = "vb", burn = 10L, retained = 20L)
  cx <- iqt12_design(e, cfg, s)
  for (likelihood in c("al", "exal")) {
    cfg$likelihood <- likelihood; cfg$engine <- "vb"
    vb <- iqt12_quantile(e, cx, cfg)
    path <- tempfile(fileext = ".json")
    iqt12_json(list(design_hash = cx$design_hash, initial = list(beta = as.numeric(vb$qbeta$m),
      sigma = vb$qsiggam$sigma_mean, gamma = if (likelihood == "al") 0 else vb$qsiggam$gamma_mean,
      v = vb$qv$E_v, s = vb$qs$E_s)), path)
    cfg$engine <- "mcmc"; cfg$warm_path <- NULL
    full <- iqt12_quantile(e, cx, cfg)
    cfg$warm_path <- path; cfg$warm_sha <- unname(tools::sha256sum(path))
    compact <- iqt12_quantile(e, cx, cfg)
    testthat::expect_equal(full$samp.beta, compact$samp.beta, tolerance = 1e-6)
    testthat::expect_equal(full$samp.sigma, compact$samp.sigma, tolerance = 1e-6)
    testthat::expect_equal(full$samp.gamma, compact$samp.gamma, tolerance = 1e-6)
  }
})

testthat::test_that("review figures and compact tables cover the full comparison surface", {
  root <- tempfile(); dir.create(root); dir.create(file.path(root, "review"))
  grid <- expand.grid(family = c("normal", "laplace", "gausmix"), p = c(.05, .25, .5),
    model = c("baseline", "qdesn"), likelihood = c("al", "exal"),
    engine = c("vb", "mcmc"), metric = c("fit_rmse", "forecast_mae", "forecast_check_loss"),
    stringsAsFactors = FALSE)
  grid$cell <- mapply(iqt12_cell, grid$family, grid$p, grid$likelihood)
  grid$mean <- 2; grid$lower <- 1; grid$upper <- 3
  refs <- unique(grid[c("family", "p")]); refs$expected_check <- 1.5
  iqt12_csv(refs, file.path(root, "oracle_references.csv"))
  pdf <- iqt12_review_pdf(root, grid)
  testthat::expect_true(file.exists(pdf))
  testthat::expect_gt(file.info(pdf)$size, 1000)
  iqt12_export_tables(root, grid)
  files <- list.files(file.path(root, "review"), pattern = "[.]tex$", full.names = TRUE)
  testthat::expect_length(files, 6L)
  lines <- readLines(files[1])
  testthat::expect_true(any(grepl("Forecast check loss", lines, fixed = TRUE)))
  testthat::expect_equal(sum(grepl(" [1, 3]", lines, fixed = TRUE)), 12L)
})

testthat::test_that("vectorized normal recursion agrees with serial reference paths", {
  lib <- file.path(repo, "validation/fitforecast_v2/local_trackers/training1000_exdqlm112_runtime/Rlib")
  testthat::skip_if_not(dir.exists(file.path(lib, "exdqlm")))
  e <- iqt12_runtime(repo, lib)
  set.seed(78); s <- data.frame(y = 10 + sin((1:10000) / 10) + rnorm(10000))
  w <- iqt12_window("A", 500L)
  w$N <- 80L; w$train <- 8421:8500; w$washout <- 7921:8420; w$buffer <- 7531:7920
  w$origins <- 8500L; w$horizon <- 3L; w$end <- 8503L
  c <- list(n = "8;6", m = 30L, alpha = .7, rho = .7, input_gain = .2,
    center_scale = "mean_sd", input_bound = "none", recurrent_indegree = 4L,
    input_fanin = 8L, interlayer_fanin = 4L, matrix_seed = 920001L,
    tau_source = .3, slab_source = 4, sigma_b_source = 1, omega_b_source = 1)
  cfg <- list(window = w, candidate = c, p = .25, seed = 442L, normal_iter = 20L,
    outer = 2L, inner = 3L)
  cx <- iqt12_design(e, cfg, s, 8503L); object <- iqt12_normal(e, cx, cfg)
  draws <- e$normal_desn_posterior_draws(object, cfg$outer, cfg$seed)
  fast <- iqt12_normal_forecast(e, cx, cfg, object, draws)
  idx <- rep(1:2, each = 3)
  repeated <- list(beta = draws$beta[idx, , drop = FALSE], omega2 = draws$omega2[idx])
  local <- 8500L - cx$first + 1L
  reference <- e$forecast_paths.qdesn_normal_fit(object, H = 3, nd = 6,
    y_hist = cx$y[seq_len(local)], origin_state = lapply(object$states$H_all, function(h) h[local, ]),
    draws = repeated, seed = cfg$seed + 8500L)
  expected <- e$iqcf_v3_matrix_by_outer_draw(reference$mu_draws, 2L, 3L, "mean") * cx$scale
  testthat::expect_equal(fast, expected, tolerance = 1e-6)
})

testthat::test_that("complete closeout assembles all four models without binary payloads", {
  root <- tempfile(); dir.create(root)
  cells <- expand.grid(family = c("normal", "laplace", "gausmix"),
    p = c(.05, .25, .5), likelihood = c("al", "exal"), stringsAsFactors = FALSE)
  references <- list(); old <- list()
  src <- file.path(root, "source.csv")
  iqt12_csv(data.frame(t = 6611:10000, y = 1, q_target = 1), src)
  for (i in seq_len(nrow(cells))) {
    row <- cells[i, ]; cell <- iqt12_cell(row$family, row$p, row$likelihood)
    references[[cell]] <- c(as.list(row), list(source_path = src, source_sha = "synthetic",
      candidate = list(id = "anchor", readout_dimension = 3L), baseline = list()))
    for (engine in c("vb", "mcmc")) for (model in c("baseline", "qdesn"))
      old[[length(old) + 1L]] <- data.frame(family = row$family, tau = row$p,
        inference = engine, model_variant = if (model == "baseline")
          if (row$likelihood == "al") "dqlm" else "exdqlm" else
          if (row$likelihood == "al") "qdesn_al_rhs_ns" else "qdesn_exal_rhs_ns",
        fit_qtrue_rmse = 2, forecast_qtrue_mae_H1000 = 2, forecast_check_loss_H1000 = 2)
  }
  state <- list(run = root, repo = repo, library = "synthetic", references = references)
  iqt12_json(state, file.path(root, "campaign.json"))
  iqt12_csv(do.call(rbind, old), file.path(root, "previous_article_summary.csv"))
  refs <- unique(cells[c("family", "p")]); refs$expected_check <- .5
  iqt12_csv(refs, file.path(root, "oracle_references.csv"))
  for (engine in c("vb", "mcmc")) {
    configs <- list(); stage <- paste0("final_", engine)
    for (cell in names(references)) for (model in c("baseline", "qdesn"))
      for (chain in if (engine == "mcmc") 1:3 else 1L) {
        cfg <- iqt12_config(state, cell, references[[cell]]$candidate, stage,
          engine, fold = "final", model = model, chain = chain)
        configs[[length(configs) + 1L]] <- cfg
        path <- matrix(rep(c(.8, 1, 1.2), each = 1000), 1000, 3)
        iqt12_csv(cbind(source_index = cfg$window$train, path),
          file.path(cfg$evidence, "fit_location_draws.csv.gz"))
        iqt12_csv(cbind(iqt12_grid(cfg$window), path),
          file.path(cfg$evidence, "forecast_location_draws.csv.gz"))
        metric <- iqt12_scores(path, path, data.frame(y = rep(1, 10000),
          q_target = rep(1, 10000)), cfg$window, cfg$p)
        iqt12_csv(metric$draws, file.path(cfg$evidence, "metric_draws.csv.gz"))
        iqt12_csv(cbind(data.frame(cell = cell, model = model, engine = engine,
          candidate_id = "anchor"), metric$summary), file.path(cfg$evidence, "summary.csv"))
        iqt12_csv(data.frame(iteration = 1:40, sigma = 1 + sin(1:40 + chain),
          gamma = if (cfg$likelihood == "al") 0 else cos(1:40 + chain)),
          file.path(cfg$evidence, "nuisance_trace.csv.gz"))
        manifest <- iqt12_hash(list.files(cfg$evidence, full.names = TRUE),
          file.path(cfg$evidence, "manifest.csv"))
        iqt12_json(list(status = "SUCCESS", manifest = manifest), cfg$status_path)
      }
    iqt12_plan(state, configs, stage)
  }
  testthat::expect_identical(iqt12_closeout(root), "COMPLETE")
  closed <- iqt12_read(file.path(root, "closeout.json"))
  testthat::expect_equal(closed$primary_fit_jobs, 144L)
  testthat::expect_equal(closed$interval_rows, 360L)
  testthat::expect_equal(closed$fitted_model_binaries, 0L)
  testthat::expect_false(closed$article_changed)
  testthat::expect_true(iqt12_verify(file.path(root, "review_manifest.csv")))
  history <- read.csv(file.path(root, "review/historical_authority_comparison.csv"))
  testthat::expect_equal(nrow(history), 216L)
  leads <- read.csv(file.path(root, "review/lead_profiles.csv"))
  testthat::expect_equal(nrow(leads), 2160L)
  nuisance <- read.csv(file.path(root, "review/multichain_nuisance_diagnostics.csv"))
  testthat::expect_true(any(nuisance$diagnostic_scope == "constant_or_nonfinite_trace"))
})

testthat::test_that("scheduler drains rather than dispatching after a worker failure", {
  root <- tempfile(); dir.create(root); dir.create(file.path(root, "plans"))
  for (stage in iqt12_stages) writeLines("id", file.path(root, "plans", paste0(stage, ".csv")))
  stub <- file.path(root, "rscript_stub")
  affinity <- system2("taskset", c("-pc", Sys.getpid()), stdout = TRUE)
  first <- as.integer(strsplit(sub(".*: ", "", tail(affinity, 1)), "[,-]")[[1]][1])
  writeLines(c("#!/usr/bin/env bash", "set -eu", "action=$2",
    paste0("if [[ $action == resources ]]; then echo ", first, "; exit 0; fi"),
    "if [[ $action == pending && $5 == cost ]]; then printf 'one\\tdummy\\t10\\ntwo\\tdummy\\t10\\n'; exit 0; fi",
    "if [[ $action == worker ]]; then exit 7; fi",
    "if [[ $action == exit ]]; then exit 1; fi", "exit 0"), stub)
  Sys.chmod(stub, "0755")
  old <- Sys.getenv("RSCRIPT"); Sys.setenv(RSCRIPT = stub)
  on.exit(Sys.setenv(RSCRIPT = old), add = TRUE)
  code <- system2("bash", c(file.path(repo, "validation/fitforecast_v2/scripts/run_independent_qdesn_training1000_v1.sh"), repo, root),
    stdout = file.path(root, "log"), stderr = file.path(root, "log"))
  testthat::expect_equal(code, 1L)
  testthat::expect_match(readLines(file.path(root, "scheduler.status")), "PAUSED_REVIEW_REQUIRED")
  testthat::expect_length(readLines(file.path(root, "receipts/exits.tsv")), 1L)
  testthat::expect_false(file.exists(file.path(root, "logs/two.log")))
})
