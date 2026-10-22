# Matched-output timing audit, separate from predictive performance evaluation.
source("validation/autodesn/load_checkout.R")
source("validation/autodesn/long_horizon/helpers.R")
main <- function() {
  specs <- lh_specs()
  index <- with(specs$grid, which(D == 3L & width == 50L & m == 90L & profile == "fast" & seed == 11L))
  dgp <- lh_simulate("dynamic_seasonal", 1000L, 743020L)
  bank <- autodesn_build_bank(dgp$y, specs$specifications[index], conditioning = 500L, washout = 500L)
  # This short fit is only a source of realistic benchmark inputs, not a fitted
  # result used in the scientific comparison or a claim about convergence.
  fit <- autodesn_fit_bank(bank, n_burn = 50L, n_mcmc = 200L, seed = 719L)
  ids <- rep(1:128, length.out = 128)
  noise <- .autodesn_seed(720L, function() matrix(stats::rnorm(100L * 512L), 100L, 512L))
  serial_time <- system.time(serial <- forecast_paths.autodesn_fit(fit, 100L,
    draw_index = ids, inner_paths = 4L, innovations = noise, backend = "serial"))[["elapsed"]]
  batched_time <- system.time(batched <- forecast_paths.autodesn_fit(fit, 100L,
    draw_index = ids, inner_paths = 4L, innovations = noise, backend = "batched"))[["elapsed"]]
  difference <- max(abs(serial$yrep - batched$yrep), abs(serial$mu_draws - batched$mu_draws))
  stopifnot(difference < 1e-9)
  tab <- data.frame(D = 3L, width = 50L, m = 90L, H = 100L, total_paths = 512L,
    serial_seconds = serial_time, batched_seconds = batched_time,
    speed_ratio = serial_time / batched_time, max_absolute_difference = difference,
    qualification = "Single timing on this R/BLAS/host; numerical parity audit, not a general speed guarantee.")
  out <- Sys.getenv("AUTODESN_LONG_OUT", "validation/autodesn/long_horizon/artifacts")
  utils::write.csv(tab, file.path(out, "forecast_backend_benchmark.csv"), row.names = FALSE)
  print(tab, row.names = FALSE)
}
main()
