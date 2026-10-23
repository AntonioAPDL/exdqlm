# Separate follow-up for failed frozen-study diagnostic screens. It changes
# only sampler duration and seeds; original study outputs are never replaced.
source("validation/autodesn/load_checkout.R")
source("validation/autodesn/long_horizon/helpers.R")
main <- function() {
  out <- Sys.getenv("AUTODESN_LONG_OUT", "validation/autodesn/long_horizon/artifacts")
  cfg <- dget(file.path(out, "configuration.R"))
  audit <- utils::read.csv(file.path(out, "audit.csv"))
  stopifnot(nrow(audit) == length(cfg$kinds) * cfg$repetitions)
  cases <- audit[!audit$auto_diagnostic_pass, ]
  original <- utils::read.csv(file.path(out, "scores.csv"))
  probabilities <- utils::read.csv(file.path(out, "probability.csv"))
  scores <- diagnostic <- model_comparison <- overview <- list()
  control <- cfg; control$n_burn <- 5000L; control$n_mcmc <- 32000L
  dput(list(rule = "All and only AutoDESN cases failing the frozen diagnostic screen; no future-based case selection.",
    chains = 3L, n_burn = control$n_burn, n_mcmc = control$n_mcmc,
    changed_target_or_candidates = FALSE, original_outputs_replaced = FALSE,
    cases = cases[c("dgp", "repetition", "dgp_seed")]), file.path(out, "confirmation_configuration.R"))
  for (i in seq_len(nrow(cases))) {
    row <- cases[i, ]; kind <- row$dgp; r <- row$repetition; seed <- row$dgp_seed
    cat(sprintf("Confirmation: %s repetition %d\n", kind, r)); flush.console()
    dgp <- lh_simulate(kind, 1100L, seed)
    bank <- autodesn_build_bank(dgp$y[1:1000], cfg$specifications,
      conditioning = 500L, washout = 500L)
    fit <- lh_fit(bank, control, seed + 40100L)
    dg <- fit$diagnostics
    diagnostic[[i]] <- cbind(dgp = kind, repetition = r,
      max_model_chain_range = max(dg$models$chain_range), dg$parameters)
    oldp <- probabilities[probabilities$dgp == kind & probabilities$repetition == r, ]
    stopifnot(identical(oldp$candidate, dg$models$candidate))
    model_comparison[[i]] <- data.frame(dgp = kind, repetition = r,
      candidate = oldp$candidate, original = oldp$posterior_probability,
      confirmation = dg$models$posterior_probability,
      confirmation_chain_range = dg$models$chain_range)
    ids <- .autodesn_seed(seed + 300L, function() sample.int(nrow(fit$fit$draws), cfg$outer_draws, replace = TRUE))
    noise <- .autodesn_seed(seed + 400L, function() matrix(stats::rnorm(cfg$H * cfg$outer_draws * cfg$max_inner_paths), cfg$H))
    cols <- as.vector(outer(seq_len(cfg$inner_paths),
      (seq_len(cfg$outer_draws) - 1L) * cfg$max_inner_paths, "+"))
    fc <- forecast_paths.autodesn_fit(fit$fit, cfg$H, draw_index = ids,
      inner_paths = cfg$inner_paths, innovations = noise[, cols], backend = "batched")
    old <- original[original$dgp == kind & original$repetition == r & original$method == "AutoDESN", ]
    oracle <- original[original$dgp == kind & original$repetition == r & original$method == "Oracle_DGP", ]
    score <- lh_score(fc, dgp$y[1001:1100], dgp$mu[1001:1100], oracle$mean_location)
    scores[[i]] <- cbind(dgp = kind, repetition = r, method = "AutoDESN_longer_sampler", score)
    overview[[i]] <- data.frame(dgp = kind, repetition = r,
      max_rhat = max(dg$parameters$rhat), min_spectral_ess = min(dg$parameters$ess_spectral),
      max_model_chain_range = max(dg$models$chain_range),
      diagnostic_screen_pass = max(dg$parameters$rhat) <= 1.01 &&
        min(dg$parameters$ess_spectral) >= 400 && max(dg$models$chain_range) <= .05,
      model_probability_total_variation = sum(abs(oldp$posterior_probability - dg$models$posterior_probability)) / 2,
      original_rmse = sqrt(mean(old$squared_error)), confirmation_rmse = sqrt(mean(score$squared_error)),
      original_crps = mean(old$crps), confirmation_crps = mean(score$crps),
      mean_location_RMS_difference = sqrt(mean((old$mean_location - score$mean_location)^2)))
    for (name in c("scores", "diagnostic", "model_comparison", "overview"))
      utils::write.csv(do.call(rbind, get(name)), file.path(out, paste0("confirmation_", name, ".csv")), row.names = FALSE)
  }
  if (length(overview)) print(do.call(rbind, overview), row.names = FALSE) else cat("No failed screens to confirm.\n")
}
main()
