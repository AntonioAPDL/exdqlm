# Run from the repository root. Arguments are environment variables documented
# in README.md. Source all implementation files once; do not edit during a run.
source("validation/autodesn/load_checkout.R")
source("validation/autodesn/long_horizon/helpers.R")

main <- function() {
  out <- Sys.getenv("AUTODESN_LONG_OUT", "validation/autodesn/long_horizon/artifacts")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  specs <- lh_specs()
  cfg <- list(schema = "autodesn_500_500_100_v1", washout = 500L,
    conditioning = 500L, n_train = 500L, H = 100L,
    repetitions = as.integer(Sys.getenv("AUTODESN_LONG_REPS", "3")),
    kinds = c("dynamic_seasonal", "linear", "nonlinear"),
    chains = 3L, n_burn = 1500L, n_mcmc = 4000L,
    outer_draws = 192L, inner_paths = 64L, max_inner_paths = 128L,
    quantile_type = 8L, fixed_index = specs$fixed_index,
    specifications = specs$specifications,
    retry_rule = "Before forecast evaluation only: one retry at burn=3000 and retained=8000 if Rhat>1.01, ESS<400 or max model chain range>.05.",
    source_revision_at_launch = system2("/usr/bin/git", c("rev-parse", "HEAD"), stdout = TRUE),
    scope = "Fresh fixed-origin forecasts; no fitting, tuning or teacher forcing inside the 100 held-out observations.")
  stopifnot(cfg$repetitions >= 1L, cfg$max_inner_paths == 2L * cfg$inner_paths)
  config_path <- file.path(out, "configuration.R")
  if (file.exists(config_path)) stop("Output already contains a frozen configuration; choose a new output directory.")
  dput(cfg, config_path)
  utils::write.csv(specs$grid, file.path(out, "specifications.csv"), row.names = FALSE)
  paths <- unique(c(list.files("R", pattern = "\\.R$", full.names = TRUE),
    list.files("validation/autodesn/long_horizon", pattern = "\\.(R|py|md)$", full.names = TRUE),
    "tools/merge_reports/20260305_dynamic_dgp_model_helpers.R",
    "docs/implementation_notes/independent_qdesn_corrected_forecast_v3_20260930.md",
    "config/validation/independent_qdesn_corrected_forecast_v3/protocol_defaults.yaml"))
  utils::write.csv(data.frame(path = paths, md5 = unname(tools::md5sum(paths))),
    file.path(out, "launch_source_manifest.csv"), row.names = FALSE)
  started <- proc.time()[[3L]]
  scores <- probability <- diagnostics <- observed <- audit <- sensitivity <- list()
  qualify <- function(dg) all(is.finite(dg$parameters$rhat)) &&
    max(dg$parameters$rhat) <= 1.01 && min(dg$parameters$ess_spectral) >= 400 &&
    max(dg$models$chain_range) <= .05
  fit_checked <- function(bank, seed, kind, r, method) {
    for (attempt in 1:2) {
      control <- cfg
      if (attempt == 2L) { control$n_burn <- 3000L; control$n_mcmc <- 8000L }
      fitted <- lh_fit(bank, control, seed + (attempt - 1L) * 10000L)
      dg <- fitted$diagnostics
      diagnostics[[length(diagnostics) + 1L]] <<- cbind(dgp = kind, repetition = r,
        method = method, attempt = attempt, diagnostic_screen_pass = qualify(dg),
        n_burn = control$n_burn, retained_per_chain = control$n_mcmc,
        max_model_chain_range = max(dg$models$chain_range), dg$parameters)
      if (qualify(dg) || attempt == 2L) break
      cat("  Diagnostic-only retry before examining future forecasts\n"); flush.console()
    }
    fitted
  }
  origin <- cfg$washout + cfg$n_train
  for (kind in cfg$kinds) for (r in seq_len(cfg$repetitions)) {
    case_started <- proc.time()[[3L]]
    id <- sprintf("%s_r%02d", kind, r)
    seed <- 742000L + match(kind, cfg$kinds) * 1000L + r * 20L
    cat(sprintf("\n%s: warmup 1:500, fit 501:1000, forecast 1001:1100\n", id)); flush.console()
    dgp <- lh_simulate(kind, origin + cfg$H, seed)
    history <- dgp$y[seq_len(origin)]
    bank <- autodesn_build_bank(history, cfg$specifications,
      conditioning = cfg$conditioning, washout = cfg$washout)
    stopifnot(identical(bank$keep_idx, 501:1000), bank$n == cfg$n_train,
      all(vapply(bank$templates, function(z) all(z$reservoir$Q_is_identity), TRUE)),
      all(vapply(bank$templates, function(z) ncol(z$X) == sum(z$reservoir$n) + 1L, TRUE)))
    auto_fit <- fit_checked(bank, seed + 100L, kind, r, "AutoDESN")
    probability[[length(probability) + 1L]] <- cbind(dgp = kind, repetition = r,
      auto_fit$diagnostics$models, specs$grid[, c("width", "profile")])
    fixed_bank <- autodesn_build_bank(history, cfg$specifications[cfg$fixed_index],
      conditioning = cfg$conditioning, washout = cfg$washout)
    fixed_fit <- fit_checked(fixed_bank, seed + 200L, kind, r, "Fixed_DESN")
    pooled <- auto_fit$fit
    ids <- .autodesn_seed(seed + 300L, function() sample.int(nrow(pooled$draws), cfg$outer_draws, replace = TRUE))
    noise <- .autodesn_seed(seed + 400L, function() matrix(stats::rnorm(cfg$H * cfg$outer_draws * cfg$max_inner_paths), cfg$H))
    choose_inner <- function(K) as.vector(outer(seq_len(K),
      (seq_len(cfg$outer_draws) - 1L) * cfg$max_inner_paths, "+"))
    cols <- choose_inner(cfg$inner_paths)
    auto <- forecast_paths.autodesn_fit(pooled, cfg$H, draw_index = ids,
      inner_paths = cfg$inner_paths, innovations = noise[, cols], backend = "batched")
    plugin <- forecast_paths.autodesn_fit(pooled, cfg$H, draw_index = ids,
      backend = "batched", recursion_mode = "conditional_mean_plugin")
    fixed <- forecast_paths.autodesn_fit(fixed_fit$fit, cfg$H, nd = cfg$outer_draws,
      inner_paths = cfg$inner_paths, seed = seed + 500L, backend = "batched")
    N <- cfg$outer_draws * cfg$inner_paths
    oracle <- lh_oracle(kind, dgp, history, cfg$H, N, seed + 600L)
    candidates <- list(AutoDESN = auto, Fixed_DESN = fixed,
      Gaussian_AR1 = lh_ar(bank, 1L, cfg$H, N, seed + 700L),
      Gaussian_AR90 = lh_ar(bank, 90L, cfg$H, N, seed + 800L),
      Seasonal_naive90 = lh_reference(history, bank$keep_idx, cfg$H, N, seed + 900L, 90L),
      Constant = lh_reference(history, bank$keep_idx, cfg$H, N, seed + 1000L),
      Oracle_DGP = oracle)
    actual <- dgp$y[origin + seq_len(cfg$H)]
    latent <- dgp$mu[origin + seq_len(cfg$H)]
    for (method in names(candidates)) {
      score <- lh_score(candidates[[method]], actual, latent, rowMeans(oracle$mu_draws))
      scores[[length(scores) + 1L]] <- cbind(dgp = kind, repetition = r, method = method, score)
    }
    # Retain every lead for 64 prespecified illustrative paths, plus outer-draw
    # location means for all 192 parameter draws. Full MC arrays are reproducible
    # from source and seeds and are not retained as fitted-model binaries.
    show <- as.integer(round(seq.int(1L, N, length.out = 64L)))
    utils::write.csv(data.frame(horizon = seq_len(cfg$H), auto$yrep[, show]),
      file.path(out, paste0(id, "_paths.csv")), row.names = FALSE)
    utils::write.csv(data.frame(path = seq_along(show), column = show,
      source_draw = auto$draw_index[show], outer_draw = auto$outer_draw_index[show],
      inner_path = auto$inner_path_index[show], model = auto$model[show]),
      file.path(out, paste0(id, "_path_indices.csv")), row.names = FALSE)
    utils::write.csv(data.frame(horizon = seq_len(cfg$H), auto$mean_conditional_location),
      file.path(out, paste0(id, "_mean_location_by_draw.csv")), row.names = FALSE)
    utils::write.csv(data.frame(horizon = seq_len(cfg$H), plugin$mu_draws),
      file.path(out, paste0(id, "_plugin_by_draw.csv")), row.names = FALSE)
    # K sensitivity uses the same outer draws and paired subsets of the same
    # innovation bank. It never changes the selected model bank or priors.
    if (kind == "dynamic_seasonal" && r == 1L) {
      for (K in c(32L, 64L, 128L)) {
        fc <- if (K == cfg$inner_paths) auto else forecast_paths.autodesn_fit(pooled,
          cfg$H, draw_index = ids, inner_paths = K,
          innovations = noise[, choose_inner(K)], backend = "batched")
        qs <- t(apply(fc$yrep, 1L, stats::quantile, probs = c(.05, .5, .95), type = 8))
        sensitivity[[length(sensitivity) + 1L]] <- data.frame(dgp = kind, repetition = r,
          K = K, horizon = seq_len(cfg$H), mean_location = rowMeans(fc$mu_draws),
          lower90 = qs[, 1L], median = qs[, 2L], upper90 = qs[, 3L])
      }
    }
    observed[[length(observed) + 1L]] <- data.frame(dgp = kind, repetition = r,
      time = seq_along(dgp$y), y = dgp$y, latent_location = dgp$mu,
      split = c(rep("washout", 500), rep("training", 500), rep("forecast", 100)))
    audit[[length(audit) + 1L]] <- data.frame(dgp = kind, repetition = r,
      dgp_seed = seed, conditioning_start = 1L, conditioning_end = 500L,
      fit_start = min(bank$keep_idx), fit_end = max(bank$keep_idx), n_train = bank$n,
      forecast_origin = auto$origin, horizon = nrow(auto$yrep),
      outer_draws = auto$n_outer, inner_paths = auto$inner_paths,
      total_paths = ncol(auto$yrep), all_forecasts_finite = all(vapply(candidates, function(x) all(is.finite(x$yrep)), TRUE)),
      center = bank$preprocessing$center, scale = bank$preprocessing$scale,
      auto_diagnostic_pass = qualify(auto_fit$diagnostics),
      fixed_diagnostic_pass = qualify(fixed_fit$diagnostics),
      elapsed_seconds = proc.time()[[3L]] - case_started)
    for (name in c("scores", "probability", "diagnostics", "observed", "audit", "sensitivity")) {
      x <- get(name)
      if (length(x)) utils::write.csv(do.call(rbind, x), file.path(out, paste0(name, ".csv")), row.names = FALSE)
    }
    cat(sprintf("%s complete in %.1f seconds\n", id, proc.time()[[3L]] - case_started)); flush.console()
    rm(bank, auto_fit, fixed_bank, fixed_fit, pooled, auto, fixed, plugin, oracle, candidates, noise)
    invisible(gc())
  }
  tab <- do.call(rbind, scores)
  tab$band <- cut(tab$horizon, c(0, 10, 30, 60, 100), labels = c("1-10", "11-30", "31-60", "61-100"))
  fields <- c("squared_error", "absolute_error", "crps", "covered90", "width90", "latent_squared_error", "oracle_mean_squared_error")
  aggregate_scores <- function(groups) {
    x <- stats::aggregate(tab[fields], tab[groups], mean)
    x$rmse <- sqrt(x$squared_error)
    x$latent_rmse <- sqrt(x$latent_squared_error)
    x$oracle_mean_rmse <- sqrt(x$oracle_mean_squared_error)
    x
  }
  utils::write.csv(aggregate_scores(c("dgp", "method")), file.path(out, "summary.csv"), row.names = FALSE)
  utils::write.csv(aggregate_scores(c("dgp", "method", "band")), file.path(out, "lead_bands.csv"), row.names = FALSE)
  utils::write.csv(aggregate_scores(c("dgp", "method", "horizon")), file.path(out, "by_horizon.csv"), row.names = FALSE)
  utils::write.csv(aggregate_scores(c("dgp", "method", "repetition")), file.path(out, "by_replication.csv"), row.names = FALSE)
  stopifnot(nrow(tab) == length(cfg$kinds) * cfg$repetitions * 7L * cfg$H,
    !anyDuplicated(tab[c("dgp", "repetition", "method", "horizon")]))
  writeLines(c(sprintf("Elapsed seconds: %.3f", proc.time()[[3L]] - started),
    "500 unscored scaling/warmup observations, 500 likelihood rows, 100 fixed-origin held-out leads.",
    "Three independent series per process by default; horizons and paths are not independent data replications.",
    "Known-DGP comparator uses true parameters and only history available at the forecast origin.",
    "Latent realized-path errors are diagnostics; they do not redefine marginal predictive quantiles.",
    "No ranking requirement or post-test tuning. Quantiles use type 8.",
    R.version.string, capture.output(sessionInfo())), file.path(out, "session.txt"))
  print(utils::read.csv(file.path(out, "summary.csv"))[, c("dgp", "method", "rmse", "crps", "covered90")], row.names = FALSE)
}
main()
