repo <- normalizePath(Sys.getenv("IFU8_REPO", "."), mustWork = TRUE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_training_size_mechanism_v6.R",
    "independent_qdesn_gausmix_conditioning_v7.R",
    "independent_qdesn_forecast_uncertainty_v8.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))

stopifnot(identical(ifu8_stages, c("replay", "smoke", "warm", "discovery",
    "confirm_warm", "confirmation")),
  identical(ifu8_tau_multipliers, c(0.5, 0.75, 1, 1.5, 2, 2.5, 3)),
  max(itm6_folds) + 240L < 9001L)

window <- list(origins = c(10L, 12L), horizon = 2L, end = 14L,
  train = 1:4, N = 4L)
source_data <- data.frame(y = seq_len(20), q_target = seq_len(20) / 2)
forecast <- matrix(rep(source_data$q_target[iqt12_grid(window)$target], 3),
  ncol = 3) + matrix(c(-1, 0, 1), nrow = 4, ncol = 3, byrow = TRUE)
draws <- ifu8_metric_draws(forecast, source_data, window, .25)
stopifnot(nrow(draws) == 3L, all(draws$forecast_mae == c(1, 0, 1)),
  all(is.finite(draws$forecast_check_loss)))
summary <- ifu8_metric_summary(draws)
stopifnot(setequal(summary$metric,
    c("forecast_mae", "forecast_rmse", "forecast_check_loss")),
  all(summary$width >= 0))

set.seed(1)
truth <- rnorm(20)
independent <- matrix(rnorm(20 * 100, truth), 20, 100)
coherent <- truth + outer(rep(1, 20), rnorm(100))
ind_diag <- ifu8_path_diagnostics(independent, truth)
coherent_diag <- ifu8_path_diagnostics(coherent, truth)
stopifnot(coherent_diag[["first_pc_share"]] > ind_diag[["first_pc_share"]],
  coherent_diag[["effective_rank"]] < ind_diag[["effective_rank"]])

fake_results <- do.call(rbind, lapply(ifu8_tau_multipliers, function(tau)
  rbind(data.frame(metric = "forecast_mae", mean = 3 + abs(tau - 2) / 10,
      lower = 2, upper = 4, tau_multiplier = tau, fold = c("S1", "S3")),
    data.frame(metric = "forecast_check_loss", mean = 1.5,
      lower = 1.4, upper = 1.6, tau_multiplier = tau,
      fold = c("S1", "S3")))))
fake_uncertainty <- do.call(rbind, lapply(ifu8_tau_multipliers, function(tau)
  data.frame(estimator = "current_recursive", metric = "forecast_mae",
    mean_interval_score = 2 + tau / 10,
    pointwise_interval_width = 1 + tau / 10,
    tau_multiplier = tau, fold = c("S1", "S3"))))
selection <- ifu8_select_taus(fake_results, fake_uncertainty)
stopifnot(length(selection$selected) == 2L, 3 %in% selection$selected,
  sum(selection$rank$selected) == 2L)

shell <- file.path(repo, "validation/fitforecast_v2/scripts",
  "run_independent_qdesn_forecast_uncertainty_v8.sh")
stopifnot(file.exists(shell),
  system2("bash", c("-n", shell)) == 0L)

cat("independent_qdesn_forecast_uncertainty_v8: PASS\n")
