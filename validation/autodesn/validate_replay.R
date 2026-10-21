# Replay the first prespecified study case against the final checkout. This
# also checks that later API/provenance cleanup did not change scored forecasts.
main <- function() {
  artifact_dir <- Sys.getenv("AUTODESN_OUT", "validation/autodesn/artifacts")
  previous <- Sys.getenv("AUTODESN_OUT", unset = NA_character_)
  Sys.setenv(AUTODESN_OUT = tempfile("autodesn-replay-"))
  on.exit(if (is.na(previous)) Sys.unsetenv("AUTODESN_OUT") else Sys.setenv(AUTODESN_OUT = previous))
  expressions <- parse("validation/autodesn/run_simulations.R")
  for (expression in expressions) {
    if (is.call(expression) && identical(expression[[1L]], as.name("for"))) break
    eval(expression, envir = .GlobalEnv)
  }
  kind <- "linear"
  r <- 1L
  origin <- 180L
  dgp_seed <- 71001L
  y <- simulate(kind, max(origins) + H, dgp_seed)
  train <- y[seq_len(origin)]
  bank <- autodesn_build_bank(train, specs, conditioning = configuration$conditioning)
  fits <- lapply(1:2, function(k) autodesn_fit_bank(bank, n_burn = configuration$n_burn,
    n_mcmc = configuration$n_mcmc, initial_variance = c(0.2, 2)[k],
    ridge_precision = c(0.3, 3)[k], seed = dgp_seed + origin * 10L + k))
  pooled <- pool_chains(fits)
  auto <- forecast_paths.autodesn_fit(pooled, H, nd, seed = dgp_seed + origin + 400L)$yrep
  fixed_bank <- autodesn_build_bank(train, fixed_spec, conditioning = configuration$conditioning)
  fixed <- autodesn_fit_bank(fixed_bank, n_burn = 1000L, n_mcmc = 2500L, seed = dgp_seed + origin + 800L)
  candidates <- list(AutoDESN = auto,
    Fixed_DESN = forecast_paths.autodesn_fit(fixed, H, nd, seed = dgp_seed + origin + 900L)$yrep,
    Gaussian_AR1 = forecast_ar(bank, 1L, dgp_seed + origin + 1000L),
    Gaussian_AR12 = forecast_ar(bank, 12L, dgp_seed + origin + 1100L))
  expected <- utils::read.csv(file.path(artifact_dir, "scores.csv"))
  expected <- expected[expected$dgp == kind & expected$repetition == r & expected$origin == origin, ]
  checks <- do.call(rbind, lapply(names(candidates), function(method) {
    actual <- score_paths(candidates[[method]], y[origin + seq_len(H)], train)
    target <- expected[expected$method == method, names(actual), drop = FALSE]
    stopifnot(nrow(target) == H)
    difference <- vapply(names(actual), function(nm) max(abs(as.numeric(actual[[nm]]) - as.numeric(target[[nm]]))), numeric(1))
    data.frame(method = method, quantity = names(difference), max_absolute_difference = unname(difference),
                pass = unname(difference) < 1e-10)
  }))
  utils::write.csv(checks, file.path(artifact_dir, "replay.csv"), row.names = FALSE)
  utils::write.csv(.autodesn_source_manifest, file.path(artifact_dir, "delivery_source_manifest.csv"), row.names = FALSE)
  print(stats::aggregate(max_absolute_difference ~ method, checks, max), row.names = FALSE)
  stopifnot(all(checks$pass))
}
main()
