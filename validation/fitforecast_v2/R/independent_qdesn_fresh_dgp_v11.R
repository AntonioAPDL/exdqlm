ifd11_schema <- "independent_qdesn_fresh_dgp_v11"
ifd11_stages <- c("smoke", "warm", "confirmation")
ifd11_parent <- paste0("/data/jaguir26/local/src/",
  "exdqlm__wt__independent_qdesn_layerwise_readout_v10_20261012/",
  "validation/fitforecast_v2/local_trackers/",
  "independent_qdesn_layerwise_readout_v10_20261012_065546__git-fffbb8d8")

ifd11_arm_id <- function(structure, tau, slab, g1, g2) {
  digest::digest(jsonlite::toJSON(list(structure = as.character(structure),
    tau = as.numeric(tau), slab = as.numeric(slab),
    layer1 = as.numeric(g1), layer2 = as.numeric(g2), layer3 = 1.0),
    auto_unbox = TRUE, digits = NA), serialize = FALSE, algo = "sha256")
}

ifd11_window <- function(replica, stage = "confirmation") {
  stopifnot(replica %in% c("F1", "F2"), stage %in% ifd11_stages)
  list(N = 2000L, fold = replica, train = 7001:9000, washout = 6501:7000,
    buffer = 6001:6500, origins = if (stage == "confirmation")
      seq.int(9000L, 9990L, 30L) else 9000L,
    end = if (stage == "confirmation") 10000L else
      if (stage == "smoke") 9002L else 9001L,
    horizon = if (stage == "confirmation") 30L else
      if (stage == "smoke") 2L else 1L, origin_stride = 30L)
}

ifd11_dgp_helper <- function(repo) {
  helper <- new.env(parent = asNamespace("exdqlm"))
  sys.source(file.path(repo,
    "tools/merge_reports/20260305_dynamic_dgp_model_helpers.R"), helper)
  # The historical helper predates the public '+' model-composition API.
  helper$combineMods <- function(m1, m2) m1 + m2
  helper
}

ifd11_dgp <- function(helper, latent_seed, noise_seed) {
  model <- helper$build_dynamic_dgp_matched_model(list(period = 90L,
    harmonics = c(1L, 2L), C0_scale = .01,
    m0 = helper$dynamic_dgp_make_m0(45, .014, c(32, 12), c(.85, -1.25))),
    TT = 12000L, backend = "R")
  latent <- helper$simulate_dynamic_dgp_latent_path(model, 12000L,
    c(.005, .00002, .004, .004, .003, .003), latent_seed,
    initial_state_mode = "deterministic_m0")
  noise <- helper$simulate_dynamic_family_errors("gausmix", 10000L, .05,
    noise_seed, gausmix_sigma = c(.5, 15),
    gausmix_weights = c(.1, .9), gausmix_offset = 1)
  mu <- latent$mu[2001:12000]
  eps <- noise$centered_eps[[1L]]
  list(source = data.frame(t = 1:10000, y = mu + eps, mu = mu,
    q_target = mu, eps = eps), shift = unname(noise$quantile_shifts[1L]),
    latent_seed = latent_seed, noise_seed = noise_seed)
}

ifd11_runtime <- function(repo, library) {
  e <- ism1_runtime(repo, library)
  e$iqt12_loaded_files <- unique(c(e$iqt12_loaded_files,
    file.path(repo, "R/exal_online_vbld.R")))
  e
}

ifd11_sources <- function(repo, e) {
  unique(c(e$iqt12_loaded_files, ilr10_source_files(repo),
    file.path(repo, "tools/merge_reports/20260305_dynamic_dgp_model_helpers.R"),
    file.path(repo, "validation/fitforecast_v2", c(
      "R/independent_qdesn_fresh_dgp_v11.R",
      "scripts/independent_qdesn_fresh_dgp_v11.R",
      "scripts/run_independent_qdesn_fresh_dgp_v11.sh",
      "tests/test_independent_qdesn_fresh_dgp_v11.R",
      "docs/INDEPENDENT_QDESN_FRESH_DGP_V11_20261012.md"))))
}

ifd11_config <- function(state, arm, replica, stage, chain = 1L) {
  cfg <- state$template
  cfg$schema <- ifd11_schema
  cfg$repo <- state$repo; cfg$run <- state$run; cfg$library <- state$library
  cfg$arm <- arm; cfg$replica <- replica; cfg$stage <- stage
  cfg$chain <- as.integer(chain)
  cfg$model <- if (arm == "dqlm") "baseline" else "qdesn"
  cfg$engine <- if (stage == "warm") "vb" else "mcmc"
  cfg$estimator <- if (cfg$engine == "vb") "quantile_vb" else "quantile_mcmc"
  cfg$window <- ifd11_window(replica, stage)
  cfg$base_window <- cfg$window
  cfg$rolling_window <- 0L; cfg$origin_offset <- NULL
  cfg$source_path <- state$sources[[replica]]$path
  cfg$source_sha <- state$sources[[replica]]$sha256
  cfg$layer1_scale <- 1.0
  cfg$layer2_scale <- if (arm == "retained") .25 else 1.0
  cfg$layer3_scale <- 1.0
  cfg$scale_id <- ifd11_arm_id(cfg$candidate$structure_id,
    cfg$candidate$tau_source, cfg$candidate$slab_source,
    cfg$layer1_scale, cfg$layer2_scale)
  cfg$candidate$readout_scale_id <- cfg$scale_id
  cfg$candidate$id <- if (arm == "dqlm") "frozen_calibrated_dqlm" else
    substr(cfg$scale_id, 1L, 20L)
  cfg$id <- paste(stage, replica, arm, paste0("c", chain), sep = "__")
  cfg$path <- file.path(state$run, "configs", paste0(cfg$id, ".json"))
  cfg$status_path <- file.path(state$run, "status", paste0(cfg$id, ".json"))
  cfg$evidence <- file.path(state$run, "evidence", cfg$id)
  cfg$seed <- as.integer(81200000L + match(replica, c("F1", "F2")) *
    10000L + match(stage, ifd11_stages) * 100L + chain)
  cfg$outer <- if (stage == "confirmation") 300L else
    if (stage == "smoke") 8L else 4L
  cfg$inner <- if (stage == "confirmation") 128L else 8L
  cfg$burn <- if (stage == "smoke") 20L else 3000L
  cfg$retained <- if (stage == "smoke") 40L else 10000L
  cfg$vb_iter <- if (stage == "smoke") 50L else 800L
  cfg$normal_iter <- if (stage == "smoke") 40L else 300L
  cfg$timeout <- if (stage == "confirmation") 259200L else 86400L
  cfg$warm_path <- NULL; cfg$warm_sha <- NULL
  scientific_baseline_fields <- c("models", "calibration_id", "latent_clock_mode",
    "latent_clock_offset", "model_C0_scale", "trend_C0_scale", "seasonal_C0_scale",
    "df_value", "dim_df", "period", "harmonics", "C0_scale", "level0", "slope0",
    "harmonic1_amplitude", "harmonic1_phase", "harmonic2_amplitude", "harmonic2_phase",
    "TT_total", "TT_warmup", "TT_main")
  cfg$baseline <- cfg$baseline[intersect(scientific_baseline_fields, names(cfg$baseline))]
  cfg$baseline$train_start_source_index <- min(cfg$window$train)
  cfg$baseline$train_end_source_index <- max(cfg$window$train)
  cfg$baseline$latent_clock_start_source_index <- NULL
  if (stage == "confirmation") {
    warm_id <- paste("warm", replica, arm, "c1", sep = "__")
    cfg$warm_path <- file.path(state$run, "evidence", warm_id,
      "mcmc_initializer.json")
    stopifnot(file.exists(cfg$warm_path))
    cfg$warm_sha <- unname(tools::sha256sum(cfg$warm_path))
  }
  cfg
}

ifd11_plan <- function(state, stage, configs) {
  path <- file.path(state$run, "plans", paste0(stage, ".csv"))
  stopifnot(!file.exists(path), length(configs) > 0L)
  plan <- do.call(rbind, lapply(configs, function(cfg) {
    iqt12_json(cfg, cfg$path)
    data.frame(id = cfg$id, stage = stage, arm = cfg$arm,
      replica = cfg$replica, chain = cfg$chain, seed = cfg$seed,
      candidate_id = cfg$candidate$id, config_path = cfg$path,
      config_sha = unname(tools::sha256sum(cfg$path)),
      status_path = cfg$status_path, timeout = cfg$timeout)
  }))
  stopifnot(!anyDuplicated(plan$id))
  iqt12_csv(plan, path)
  iqt12_hash(c(path, plan$config_path), file.path(state$run, "plans",
    paste0(stage, "_hashes.csv")))
  invisible(plan)
}

ifd11_materialize <- function(repo, run, library, parent = ifd11_parent) {
  stopifnot(!dir.exists(run), !length(system2("git",
    c("-C", repo, "status", "--porcelain"), stdout = TRUE)))
  iqt12_verify(file.path(parent, "closeout_manifest.csv"))
  old <- iqt12_read(file.path(parent, "closeout.json"))
  stopifnot(old$jobs == 73L, old$failures == 0L, old$active_jobs == 0L,
    old$scientific_decision == "SMALL_LAYERWISE_GAIN_RETAIN_BUT_STOP_TARGETED_RESCUE")
  pp <- read.csv(file.path(parent, "plans/confirmation.csv"))
  row <- which(pp$layer1_scale == 1 & pp$layer2_scale == 1)[1L]
  stopifnot(unname(tools::sha256sum(pp$config_path[row])) == pp$config_sha[row])
  template <- iqt12_read(pp$config_path[row])
  stopifnot(template$window$N == 2000L, template$burn == 3000L,
    template$retained == 10000L, template$outer == 300L,
    template$inner == 128L, template$likelihood == "al")
  e <- ifd11_runtime(repo, library)
  helper <- ifd11_dgp_helper(repo)
  original_path <- paste0("/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/",
    "sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast/",
    "gausmix/tau_0p05/series_wide.csv")
  reproduced <- ifd11_dgp(helper, 32011L, 32012L)
  original <- read.csv(original_path)
  error <- max(abs(as.matrix(original) - as.matrix(reproduced$source)))
  stopifnot(is.finite(error), error <= 1e-6,
    abs(helper$.dynamic_dgp_gausmix_cdf(reproduced$shift,
      c(.5, 15), c(.1, .9), 1) - .05) <= 1e-10)
  for (dir in c("sources", "plans", "configs", "status", "evidence",
      "control", "references", "review"))
    dir.create(file.path(run, dir), recursive = TRUE, showWarnings = FALSE)
  state <- list(schema = ifd11_schema, repo = normalizePath(repo),
    run = normalizePath(run), library = normalizePath(library),
    head = system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE),
    parent = normalizePath(parent), template = template,
    arms = c("dqlm", "anchor", "retained"), replicas = c("F1", "F2"),
    sources = list(), expected_jobs = c(smoke = 2L, warm = 6L, confirmation = 18L),
    max_workers = 30L, frozen_before_fresh_score_inspection = TRUE,
    promotion = "none_automatic_diagnostic_pilot_only",
    native_coupling = list(qdesn = "shared_coefficients_across_origins_leads",
      dqlm = "existing_latent_marginal_product_coupling"))
  iqt12_csv(data.frame(check = c("historical_DGP_reconstruction_max_abs",
    "mixture_quantile_CDF_residual"), value = c(error,
      abs(helper$.dynamic_dgp_gausmix_cdf(reproduced$shift,
        c(.5, 15), c(.1, .9), 1) - .05)), pass = TRUE),
    file.path(run, "preflight_checks.csv"))
  seeds <- data.frame(replica = state$replicas,
    latent_seed = c(81112001L, 81113001L), noise_seed = c(81112002L, 81113002L))
  iqt12_csv(seeds, file.path(run, "dgp_seeds.csv"))
  for (i in seq_len(nrow(seeds))) {
    dgp <- ifd11_dgp(helper, seeds$latent_seed[i], seeds$noise_seed[i])
    path <- file.path(run, "sources", paste0(seeds$replica[i], ".csv"))
    iqt12_csv(dgp$source, path)
    state$sources[[seeds$replica[i]]] <- list(path = path,
      sha256 = unname(tools::sha256sum(path)), latent_seed = seeds$latent_seed[i],
      noise_seed = seeds$noise_seed[i], quantile_shift = dgp$shift)
  }
  iqt12_json(state, file.path(run, "campaign.json"))
  contract <- expand.grid(replica = state$replicas, arm = state$arms,
    chain = 1:3, stringsAsFactors = FALSE)
  iqt12_csv(contract, file.path(run, "confirmation_contract.csv"))
  env <- list(exdqlm = as.character(utils::packageVersion("exdqlm")),
    repository = utils::packageDescription("exdqlm")$Repository,
    package_path = find.package("exdqlm"), R = R.version.string,
    session = capture.output(sessionInfo()), external = as.list(extSoftVersion()),
    rng = RNGkind(), source_head = state$head,
    threads = as.list(Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS",
      "MKL_NUM_THREADS", "BLIS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS",
      "RCPP_PARALLEL_NUM_THREADS"))),
    compiler = system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CXX"),
      stdout = TRUE), forecast = "frozen_v10_current_recursive",
    private_extensions = "full_loaded_source_hash_closure_not_unmodified_CRAN")
  stopifnot(env$exdqlm == "1.1.2", env$repository == "CRAN",
    all(unlist(env$threads) == "1"))
  iqt12_json(env, file.path(run, "environment.json"))
  iqt12_hash(ifd11_sources(repo, e), file.path(run, "source_hashes.csv"))
  iqt12_hash(list.files(file.path(library, "exdqlm"), recursive = TRUE,
    full.names = TRUE), file.path(run, "package_hashes.csv"))
  iqt12_hash(c(original_path, pp$config_path[row],
    file.path(parent, c("closeout.json", "closeout_manifest.csv"))),
    file.path(run, "input_hashes.csv"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "dgp_seeds.csv", "preflight_checks.csv", "confirmation_contract.csv",
    "source_hashes.csv", "package_hashes.csv", "input_hashes.csv")),
    vapply(state$sources, `[[`, "", "path")), file.path(run, "frozen_hashes.csv"))
  ifd11_plan(state, "smoke", lapply(c("dqlm", "retained"), function(arm)
    ifd11_config(state, arm, "F1", "smoke")))
  ifd11_plan(state, "warm", unlist(lapply(state$replicas, function(replica)
    lapply(state$arms, function(arm) ifd11_config(state, arm, replica, "warm"))),
    recursive = FALSE))
  invisible(state)
}

ifd11_worker <- function(path) {
  cfg <- iqt12_read(path)
  assign("iqt12_runtime_hook", ifd11_runtime, envir = .GlobalEnv)
  if (cfg$model == "qdesn") ilr10_worker(path) else iqt12_worker(path)
  status <- iqt12_read(cfg$status_path)
  stopifnot(status$status == "SUCCESS")
  iqt12_verify(status$manifest)
  diag <- iqt12_read(file.path(cfg$evidence, "diagnostics.json"))
  diag$fresh_dgp_v11 <- list(replica = cfg$replica, arm = cfg$arm,
    likelihood = "al", native_coupling = if (cfg$model == "qdesn")
      "shared_coefficients_across_origins_leads" else
      "existing_latent_marginal_product_coupling", promotion = "not_authorized")
  iqt12_json(diag, file.path(cfg$evidence, "diagnostics.json"))
  files <- list.files(cfg$evidence, full.names = TRUE)
  iqt12_hash(files[basename(files) != "manifest.csv"], status$manifest)
  iqt12_verify(status$manifest)
  status$fresh_dgp_v11 <- "VERIFIED"
  iqt12_json(status, cfg$status_path)
  invisible(TRUE)
}

ifd11_plan_status <- function(run, stage) {
  plan_path <- file.path(run, "plans", paste0(stage, ".csv"))
  if (!file.exists(plan_path)) return(NULL)
  p <- read.csv(plan_path, stringsAsFactors = FALSE)
  p$status <- vapply(p$status_path, function(path) if (file.exists(path))
    iqt12_read(path)$status else "PENDING", "")
  p
}

ifd11_health <- function(run) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  do.call(rbind, lapply(ifd11_stages, function(stage) {
    p <- ifd11_plan_status(run, stage)
    status <- if (is.null(p)) rep("NOT_MATERIALIZED", state$expected_jobs[[stage]])
      else p$status
    data.frame(stage = stage, planned = length(status),
      complete = sum(status == "SUCCESS"), failed = sum(grepl("^FAILED", status)),
      running = sum(status == "RUNNING"),
      remaining = sum(status != "SUCCESS"),
      pending = sum(status %in% c("PENDING", "NOT_MATERIALIZED")))
  }))
}

ifd11_verify <- function(run) {
  for (name in c("source", "package", "input", "frozen"))
    iqt12_verify(file.path(run, paste0(name, "_hashes.csv")))
  for (stage in ifd11_stages) {
    p <- ifd11_plan_status(run, stage)
    if (is.null(p)) next
    iqt12_verify(file.path(run, "plans", paste0(stage, "_hashes.csv")))
    for (path in p$status_path[p$status == "SUCCESS"])
      iqt12_verify(iqt12_read(path)$manifest)
  }
  if (file.exists(file.path(run, "closeout_manifest.csv")))
    iqt12_verify(file.path(run, "closeout_manifest.csv"))
  invisible(ifd11_health(run))
}

ifd11_advance <- function(run, stage) {
  stopifnot(stage %in% ifd11_stages)
  p <- ifd11_plan_status(run, stage)
  stopifnot(!is.null(p), all(p$status == "SUCCESS"))
  ifd11_verify(run)
  state <- iqt12_read(file.path(run, "campaign.json"))
  if (stage == "warm" && !file.exists(file.path(run, "plans/confirmation.csv"))) {
    configs <- unlist(lapply(state$replicas, function(replica)
      unlist(lapply(state$arms, function(arm) lapply(1:3, function(chain)
        ifd11_config(state, arm, replica, "confirmation", chain))),
        recursive = FALSE)), recursive = FALSE)
    ifd11_plan(state, "confirmation", configs)
  }
  if (stage == "confirmation" && !file.exists(file.path(run, "closeout.json")))
    ifd11_closeout(run)
  invisible(TRUE)
}

ifd11_score_companions <- function(fit, forecast, source, w, p) {
  g <- iqt12_grid(w)
  draw <- iqt12_scores(fit, forecast, source, w, p)
  point <- iqt12_scores(matrix(rowMeans(fit), ncol = 1L),
    matrix(rowMeans(forecast), ncol = 1L), source, w, p)$summary
  point <- point[, c("metric", "mean")]
  names(point)[2L] <- "mean_path_score"
  out <- merge(draw$summary, point, by = "metric")
  out$width <- out$upper - out$lower
  error <- abs(forecast - source$q_target[g$target])
  diagonal <- sum(apply(error, 1L, var)) / nrow(error)^2
  total <- var(colMeans(error))
  bands <- t(apply(forecast, 1L, quantile, probs = c(.025, .975), type = 8))
  draw$profile$q025 <- bands[, 1L]
  draw$profile$q975 <- bands[, 2L]
  oracle <- source$q_target[g$target]
  interval <- bands[, 2L] - bands[, 1L] +
    40 * pmax(bands[, 1L] - oracle, 0) +
    40 * pmax(oracle - bands[, 2L], 0)
  list(summary = out, draws = draw$draws, profile = cbind(draw$profile,
    band_width = bands[, 2L] - bands[, 1L], interval_score = interval),
    attribution = data.frame(total_metric_variance = total,
      diagonal_variance = diagonal, off_diagonal_variance = total - diagonal,
      variance_ratio_to_independent_marginals = total / diagonal,
      average_pointwise_band_width = mean(bands[, 2L] - bands[, 1L]),
      oracle_inside_band_fraction = mean(oracle >= bands[, 1L] & oracle <= bands[, 2L]),
      average_interval_score = mean(interval)))
}

ifd11_review_pdf <- function(run, records, summary) {
  colors <- c(dqlm = "#245FA6", anchor = "#B94B45", retained = "#247C59")
  labels <- c(dqlm = "DQLM", anchor = "Q-DESN anchor", retained = "Q-DESN retained")
  grDevices::pdf(file.path(run, "review/fresh_dgp_v11_review.pdf"),
    width = 11.7, height = 8.3, useDingbats = FALSE, onefile = TRUE)
  on.exit(grDevices::dev.off())
  band <- function(x, mu, low, high, truth, arm, title, limits) {
    plot(x, truth, type = "n", ylim = limits,
      xlab = "Source index", ylab = "Target quantile", main = title)
    polygon(c(x, rev(x)), c(low, rev(high)),
      col = grDevices::adjustcolor(colors[arm], .16), border = NA)
    lines(x, truth, lwd = 1.4, col = "#202020")
    lines(x, mu, lwd = 1.3, col = colors[arm])
  }
  for (replica in c("F1", "F2")) {
    graphics::par(mfrow = c(1, 3), mar = c(4, 7.5, 4, 1), oma = c(0, 0, 3, 0))
    for (metric in c("fit_rmse", "forecast_mae", "forecast_check_loss")) {
      x <- summary[summary$replica == replica & summary$metric == metric, ]
      x <- x[match(names(colors), x$arm), ]
      plot(x$mean, 3:1, type = "n", xlim = range(0, x$upper, x$mean),
        ylim = c(.5, 3.5), yaxt = "n", ylab = "", xlab = "Score (lower is better)",
        main = gsub("_", " ", metric))
      axis(2, at = 3:1, labels = labels, las = 1, cex.axis = .8)
      for (i in 1:3) {
        segments(x$lower[i], 4 - i, x$upper[i], 4 - i, col = colors[i], lwd = 3)
        points(x$mean[i], 4 - i, pch = 4, cex = 1.2, lwd = 2, col = colors[i])
        points(x$mean_path_score[i], 4 - i, pch = 1, col = colors[i])
      }
    }
    mtext(paste(replica, "| pooled chains within replicate | x: draw-score mean; o: mean-path score"),
      outer = TRUE, line = 1, cex = 1.05)
    for (region in c("fit_full", "fit_last300", "forecast_full", "forecast_first120", "forecast_last120")) {
      graphics::par(mfrow = c(3, 1), mar = c(3, 4, 3, 1), oma = c(0, 0, 3, 0))
      limits <- range(unlist(lapply(names(colors), function(arm) {
        z <- records[[paste(replica, arm, sep = "__")]]
        is_fit <- grepl("^fit", region)
        times <- if (is_fit) z$w$train else iqt12_grid(z$w)$target
        draws <- if (is_fit) z$fit else z$forecast
        ids <- seq_along(times)
        if (grepl("last300", region)) ids <- tail(ids, 300L)
        if (grepl("first120", region)) ids <- head(ids, 120L)
        if (grepl("last120", region)) ids <- tail(ids, 120L)
        c(z$source$q_target[times[ids]],
          apply(draws[ids, , drop = FALSE], 1L, quantile, c(.025, .975), type = 8))
      })))
      for (arm in names(colors)) {
        z <- records[[paste(replica, arm, sep = "__")]]
        is_fit <- grepl("^fit", region)
        draws <- if (is_fit) z$fit else z$forecast
        times <- if (is_fit) z$w$train else iqt12_grid(z$w)$target
        ids <- seq_along(times)
        if (grepl("last300", region)) ids <- tail(ids, 300L)
        if (grepl("first120", region)) ids <- head(ids, 120L)
        if (grepl("last120", region)) ids <- tail(ids, 120L)
        q <- draws[ids, , drop = FALSE]
        ci <- t(apply(q, 1L, quantile, c(.025, .975), type = 8))
        band(times[ids], rowMeans(q), ci[, 1L], ci[, 2L],
          z$source$q_target[times[ids]], arm, labels[arm], limits)
      }
      mtext(paste(replica, "|", gsub("_", " ", region),
        "| black: oracle; color: posterior mean and pointwise 95% band"),
        outer = TRUE, line = 1, cex = 1)
    }
    graphics::par(mfrow = c(2, 2), mar = c(4, 4, 3, 1), oma = c(0, 0, 3, 0))
    for (by in c("lead", "origin")) for (score in c("mae", "band_width")) {
      curves <- lapply(names(colors), function(arm) {
        z <- records[[paste(replica, arm, sep = "__")]]$profile
        aggregate(z[[score]], list(position = z[[by]]), mean)
      })
      plot(range(curves[[1L]]$position), range(0, unlist(lapply(curves, `[[`, "x"))),
        type = "n", xlab = by, ylab = score, main = paste(score, "by", by))
      for (i in 1:3) lines(curves[[i]]$position, curves[[i]]$x, col = colors[i], lwd = 2)
      legend("topleft", labels, col = colors, lty = 1, lwd = 2, bty = "n", cex = .75)
    }
    mtext(paste(replica, "| native posterior forecast summaries"), outer = TRUE, line = 1)
    graphics::par(mfrow = c(2, 3), mar = c(4, 4, 3, 1), oma = c(0, 0, 3, 0))
    for (score in c("mae", "band_width")) {
      ceiling <- max(vapply(names(colors), function(arm)
        max(records[[paste(replica, arm, sep = "__")]]$profile[[score]]), 0))
      for (arm in names(colors)) {
        z <- records[[paste(replica, arm, sep = "__")]]$profile
        origins <- sort(unique(z$origin)); leads <- 1:30
        surface <- matrix(NA_real_, length(origins), 30L)
        surface[cbind(match(z$origin, origins), z$lead)] <- z[[score]]
        image(origins, leads, surface, zlim = c(0, ceiling),
          col = grDevices::hcl.colors(60, "YlGnBu", rev = TRUE),
          xlab = "Origin", ylab = "Lead", main = paste(labels[arm], score))
        mtext(sprintf("common scale: 0 to %.2f", ceiling), side = 3, line = .2, cex = .7)
      }
    }
    mtext(paste(replica, "| origin-by-lead surfaces; final horizon truncated"), outer = TRUE, line = 1)
  }
  invisible(TRUE)
}

ifd11_closeout <- function(run) {
  ifd11_verify(run)
  health <- ifd11_health(run)
  stopifnot(sum(health$complete) == 26L, sum(health$remaining) == 0L,
    sum(health$failed) == 0L)
  p <- ifd11_plan_status(run, "confirmation")
  summaries <- attributions <- chains <- leads <- origins <- list()
  records <- list()
  for (replica in c("F1", "F2")) for (arm in c("dqlm", "anchor", "retained")) {
    sub <- p[p$replica == replica & p$arm == arm, ]
    stopifnot(nrow(sub) == 3L)
    cfg <- iqt12_read(sub$config_path[1L])
    source <- read.csv(cfg$source_path)
    fits <- forecasts <- list()
    for (i in 1:3) {
      job <- iqt12_read(sub$config_path[i])
      fit <- as.matrix(read.csv(file.path(job$evidence, "fit_location_draws.csv.gz"))[, -1L])
      forecast <- as.matrix(read.csv(file.path(job$evidence,
        "forecast_location_draws.csv.gz"))[, -(1:3)])
      recalculated <- iqt12_scores(fit, forecast, source, cfg$window, cfg$p)
      stored <- read.csv(file.path(job$evidence, "metric_draws.csv.gz"))
      stopifnot(identical(names(stored), names(recalculated$draws)),
        max(abs(as.matrix(stored) - as.matrix(recalculated$draws))) <= 1e-6)
      diag <- iqt12_read(file.path(job$evidence, "diagnostics.json"))
      chains[[length(chains) + 1L]] <- cbind(data.frame(replica = replica,
        arm = arm, chain = i, sigma_ESS = diag$trace_diagnostics$sigma_ESS,
        intercept_ESS = diag$trace_diagnostics$intercept_ESS %||% NA_real_),
        recalculated$summary)
      fits[[i]] <- fit; forecasts[[i]] <- forecast
    }
    fit <- do.call(cbind, fits); forecast <- do.call(cbind, forecasts)
    z <- ifd11_score_companions(fit, forecast, source, cfg$window, cfg$p)
    key <- data.frame(replica = replica, arm = arm)
    summaries[[length(summaries) + 1L]] <- cbind(key, z$summary)
    attributions[[length(attributions) + 1L]] <- cbind(key, z$attribution)
    profile <- z$profile
    iqt12_csv(profile, file.path(run, "review", paste0(replica, "__", arm, "__origin_lead.csv.gz")))
    lead <- aggregate(profile[c("mae", "check_loss", "band_width", "interval_score")],
      list(lead = profile$lead), mean)
    era <- cut(profile$origin - 9000L, c(-1, 333, 666, 1000),
      labels = c("early", "middle", "late"))
    origin <- aggregate(profile[c("mae", "check_loss", "band_width", "interval_score")],
      list(era = era), mean)
    leads[[length(leads) + 1L]] <- cbind(key, lead)
    origins[[length(origins) + 1L]] <- cbind(key, origin)
    records[[paste(replica, arm, sep = "__")]] <- list(fit = fit,
      forecast = forecast, source = source, w = cfg$window, profile = profile)
  }
  summary <- do.call(rbind, summaries)
  comparison <- merge(summary[summary$arm == "retained", ],
    summary[summary$arm != "retained", ], by = c("replica", "metric"),
    suffixes = c("_retained", "_comparator"))
  comparison$mean_ratio <- comparison$mean_retained / comparison$mean_comparator
  comparison$strict_mean_gain <- comparison$mean_retained < comparison$mean_comparator
  comparison$width_ratio <- comparison$width_retained / comparison$width_comparator
  for (name in c("summary", "comparison", "attribution", "chains", "lead", "era")) {
    value <- switch(name, summary = summary, comparison = comparison,
      attribution = do.call(rbind, attributions), chains = do.call(rbind, chains),
      lead = do.call(rbind, leads), era = do.call(rbind, origins))
    iqt12_csv(value, file.path(run, "review", paste0(name, ".csv")))
  }
  ifd11_review_pdf(run, records, summary)
  forecast <- comparison[comparison$metric == "forecast_mae", ]
  report <- c("# Fresh-DGP v11 pilot closeout", "",
    "All 26 jobs complete. No article result was changed.", "",
    "## Native forecast-MAE comparison",
    "", "Replicate | comparator | retained/comparator mean | strict gain | width ratio",
    "---|---|---:|---|---:", apply(forecast, 1L, function(row)
      paste(row[c("replica", "arm_comparator", "mean_ratio", "strict_mean_gain", "width_ratio")],
        collapse = " | ")), "",
    "The companion CSVs contain all five criteria, mean-path scores, mixing",
    "diagnostics, pointwise interval scores, and lead/era profiles. The PDF",
    "contains two replicates separately. Intervals pool three chains within",
    "replicate/model, never replicates. Coupling differs between Q-DESN and",
    "the frozen DQLM comparator. Width parity is not an inferential gate.", "",
    "This small pilot supports review, not automatic article replacement.",
    "Do not resume screening on these newly inspected holdouts.")
  writeLines(report, file.path(run, "review/REPORT.md"))
  decision <- list(schema = ifd11_schema, status = "COMPLETE_REVIEW_REQUIRED",
    scientific_decision = "FRESH_DGP_PILOT_COMPLETE_REVIEW_TRANSFER_AND_TRADEOFFS",
    jobs = 26L, failures = 0L, active_jobs = 0L, article_changed = FALSE,
    fitted_binary_payloads = 0L, completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE))
  iqt12_json(decision, file.path(run, "closeout.json"))
  manifests <- vapply(p$status_path, function(path) iqt12_read(path)$manifest, "")
  iqt12_hash(c(file.path(run, c("closeout.json", "frozen_hashes.csv")),
    list.files(file.path(run, "review"), full.names = TRUE),
    unlist(lapply(ifd11_stages, function(stage) {
      q <- ifd11_plan_status(run, stage)
      c(q$config_path, q$status_path,
        vapply(q$status_path, function(path) iqt12_read(path)$manifest, ""),
        file.path(run, "plans", paste0(stage, c(".csv", "_hashes.csv"))))
    }))), file.path(run, "closeout_manifest.csv"))
  invisible(decision)
}

ifd11_cpu_list <- function(text) {
  unlist(lapply(strsplit(text, ",", fixed = TRUE)[[1L]], function(token) {
    range <- as.integer(strsplit(token, "-", fixed = TRUE)[[1L]])
    if (length(range) == 1L) range else seq.int(range[1L], range[2L])
  }), use.names = FALSE)
}

ifd11_resources <- function(count = 30L, evidence = NULL) {
  cpu_times <- function() {
    lines <- readLines("/proc/stat")
    rows <- strsplit(trimws(lines[grepl("^cpu[0-9]+ ", lines)]), " +")
    do.call(rbind, lapply(rows, function(row) {
      times <- as.numeric(row[-1L])
      data.frame(cpu = as.integer(sub("cpu", "", row[1L])),
        total = sum(head(times, 8L)), idle = sum(times[c(4L, 5L)]))
    }))
  }
  a <- cpu_times(); Sys.sleep(2); b <- cpu_times()
  load <- 1 - (b$idle - a$idle) / pmax(1, b$total - a$total)
  topo <- read.csv(text = paste(system2("lscpu", "-p=CPU,CORE,SOCKET,ONLINE",
    stdout = TRUE), collapse = "\n"), comment.char = "#", header = FALSE)
  names(topo) <- c("cpu", "core", "socket", "online")
  allowed <- sub("^Cpus_allowed_list:\\s*", "", readLines("/proc/self/status")[
    grepl("^Cpus_allowed_list:", readLines("/proc/self/status"))])
  topo <- topo[topo$online == "Y" & topo$cpu %in% ifd11_cpu_list(allowed), ]
  topo$physical <- paste(topo$socket, topo$core, sep = ":")
  full_topology <- topo
  topo$load <- load[match(topo$cpu, b$cpu)]
  physical <- aggregate(topo$load, list(physical = topo$physical), max)
  topo <- topo[order(topo$load, topo$cpu), ]
  topo <- topo[!duplicated(topo$physical), ]
  topo$physical_load <- physical$x[match(topo$physical, physical$physical)]
  busy <- character()
  for (pid in list.files("/proc", pattern = "^[0-9]+$")) {
    path <- file.path("/proc", pid, "status")
    lines <- tryCatch(readLines(path, warn = FALSE), error = function(e) character())
    if (!length(lines)) next
    name <- sub("^Name:\\s*", "", lines[grepl("^Name:", lines)])
    if (!name %in% c("R", "Rscript", "python", "python3")) next
    affinity <- sub("^Cpus_allowed_list:\\s*", "", lines[grepl("^Cpus_allowed_list:", lines)])
    cpus <- ifd11_cpu_list(affinity)
    if (length(cpus) <= 4L) busy <- c(busy,
      full_topology$physical[match(cpus, full_topology$cpu)])
  }
  topo <- topo[is.finite(topo$physical_load) & topo$physical_load <= .15 &
    !topo$physical %in% busy, ]
  mem <- readLines("/proc/meminfo")
  available <- as.numeric(gsub("[^0-9]", "", mem[grepl("^MemAvailable:", mem)]))
  stopifnot(available >= 128 * 1024^2, nrow(topo) > 0L,
    is.finite(count), count >= 1L, count <= 30L)
  selected <- head(topo, count)
  if (!is.null(evidence)) iqt12_csv(selected, evidence)
  selected$cpu
}
