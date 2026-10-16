#!/usr/bin/env Rscript

# Execute the focused plain-versus-residual Q-DESN ablation on a fixed,
# reproducible heteroskedastic asymmetric-Laplace time series.  This script is
# intentionally self-contained so that GitHub Actions can produce reviewable
# tables and figures without modifying the scientific engine.

`%||%` <- function(x, alt) if (!is.null(x)) x else alt

args <- commandArgs(trailingOnly = TRUE)
quick <- "--quick" %in% args
arg_value <- function(flag, default = NULL) {
  hit <- match(flag, args)
  if (is.na(hit) || hit == length(args)) return(default)
  args[[hit + 1L]]
}

output_dir <- arg_value(
  "--output",
  if (quick) "artifacts/qdesn_residual_smoke" else "artifacts/qdesn_residual_full"
)
workers <- suppressWarnings(as.integer(Sys.getenv("QDESN_ABLATION_WORKERS", unset = "2")))
if (!is.finite(workers) || workers < 1L) workers <- 1L

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_dir, "figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_dir, "manifest"), recursive = TRUE, showWarnings = FALSE)

suppressPackageStartupMessages(library(exdqlm))
options(exdqlm.use_cpp_postpred = FALSE)

p_vec <- c(0.50, 0.75, 0.95)
simulation_seed <- 20260903L
simulation_burnin <- 2000L
simulation_parameters <- list(
  p0 = 0.50,
  a1 = 0.50,
  sigma0 = 0.30,
  sigma1 = 0.40,
  kappa = 1.00,
  gamma = 0.00
)

# DGP: y_t = 0.5 y_{t-1} + eps_t, with median-zero AL innovations and
# sigma_t = 0.3 + 0.4 logistic(y_{t-1}).  It is deliberately aligned with the
# fitted AL likelihood while retaining nonlinear, time-varying upper quantiles.
sim <- simulate_ts_mc_quantiles(
  T = 1100L,
  p_grid = p_vec,
  R_mc = 10L,                 # MC quantiles are ignored; exact AL truth follows.
  scenario = "hetero_exal",
  params = simulation_parameters,
  burnin = simulation_burnin,
  seed = simulation_seed,
  keep_latents = TRUE,
  keep_draws = FALSE
)

y <- as.numeric(sim$y)
mu_true <- as.numeric(sim$extras$mu)
sigma_true <- as.numeric(sim$extras$sigma_t)
stopifnot(length(y) == 1100L, length(mu_true) == 1100L, length(sigma_true) == 1100L)

# With p0=0.5 and gamma=0, the innovation law is Laplace(mu, b=2*sigma).
# All requested probabilities are at or above the median, so these are exact.
q_true <- vapply(p_vec, function(prob) {
  if (isTRUE(all.equal(prob, 0.5, tolerance = 0))) {
    mu_true
  } else {
    mu_true - 2 * sigma_true * log(2 * (1 - prob))
  }
}, numeric(length(y)))
colnames(q_true) <- sprintf("q_%0.2f", p_vec)

series_table <- data.frame(
  t = seq_along(y),
  y = y,
  mu_true = mu_true,
  sigma_true = sigma_true,
  q_0.50 = q_true[, 1L],
  q_0.75 = q_true[, 2L],
  q_0.95 = q_true[, 3L],
  stringsAsFactors = FALSE
)
utils::write.csv(series_table, file.path(output_dir, "tables", "simulated_series_and_truth.csv"), row.names = FALSE)

writeLines(
  c(
    "DGP: hetero_exal",
    sprintf("simulation_seed: %d", simulation_seed),
    sprintf("burnin: %d", simulation_burnin),
    "series_length: 1100",
    "equation: y_t = 0.5*y_{t-1} + epsilon_t",
    "epsilon_t: quantile-fixed AL with p0=0.5, gamma=0",
    "sigma_t: 0.3 + 0.4*plogis(y_{t-1})",
    "truth: exact Laplace conditional quantiles",
    "quantiles: 0.50, 0.75, 0.95",
    "R forecast backend: forced",
    "RHS tau0: 0.1"
  ),
  file.path(output_dir, "manifest", "dgp_contract.txt")
)

message(sprintf("[execution] quick=%s workers=%d output=%s", quick, workers, output_dir))
started <- proc.time()[3]
result <- qdesn_run_residual_ablation(
  y = y,
  output_dir = output_dir,
  tau0 = 0.1,
  p_vec = p_vec,
  workers = workers,
  resume = TRUE,
  quick = quick
)
execution_seconds <- as.numeric(proc.time()[3] - started)

# ---------------------------------------------------------------------------
# Add in-sample fit diagnostics for the final fitted window, t=501,...,1000.
# The core ablation intentionally scores held-out recursive forecasts only.
# These diagnostics read the already-computed design and VB-fit caches, so no
# additional model fitting is performed.
# ---------------------------------------------------------------------------
scale_design <- function(X, scale_info) {
  X <- as.matrix(X)
  if (is.null(scale_info) || !isTRUE(scale_info$scaled)) return(X)
  center <- as.numeric(scale_info$center)
  scale <- as.numeric(scale_info$scale)
  stopifnot(ncol(X) == length(center), ncol(X) == length(scale))
  sweep(sweep(X, 2L, center, "-"), 2L, scale, "/")
}

pinball <- function(y_obs, qhat, prob) {
  u <- as.numeric(y_obs) - as.numeric(qhat)
  u * (prob - (u < 0))
}

cache_root <- file.path(output_dir, "cache", result$run_signature_sha256)
selected <- result$selected_models[result$selected_models$evaluated_final, , drop = FALSE]
final_seeds <- sort(unique(as.integer(result$final_summary$reservoir_seed)))
fit_rows <- list()
fit_seed_rows <- list()
row_index <- 0L
seed_index <- 0L

for (im in seq_len(nrow(selected))) {
  model_id <- as.character(selected$model_id[[im]])
  architecture <- as.character(selected$architecture[[im]])
  candidate_id <- as.character(selected$candidate_id[[im]])

  for (reservoir_seed in final_seeds) {
    design_path <- file.path(
      cache_root,
      "origin-1000",
      "design",
      sprintf("%s__seed-%d.rds", candidate_id, reservoir_seed)
    )
    if (!file.exists(design_path)) stop("Missing final design cache: ", design_path)
    paired_design <- readRDS(design_path)
    design <- paired_design[[architecture]]
    if (is.null(design)) stop("Missing architecture in paired design: ", architecture)
    keep_idx <- as.integer(design$meta$keep_idx)
    X_raw <- as.matrix(design$X_raw %||% design$X)

    for (p0 in p_vec) {
      fit_path <- file.path(
        cache_root,
        "origin-1000",
        "fits",
        sprintf(
          "%s__seed-%d__%s__p-%0.2f.rds",
          candidate_id, reservoir_seed, architecture, p0
        )
      )
      if (!file.exists(fit_path)) stop("Missing final VB-fit cache: ", fit_path)
      fit_cache <- readRDS(fit_path)
      if (!isTRUE(fit_cache$ok)) stop("Cached final fit failed: ", fit_cache$error %||% "unknown error")

      X_fit <- scale_design(X_raw, fit_cache$readout_scale)
      qhat_model <- as.numeric(X_fit %*% fit_cache$readout_fit$qbeta$m)

      summary_match <- result$final_summary[
        result$final_summary$model_id == model_id &
          result$final_summary$reservoir_seed == reservoir_seed &
          abs(result$final_summary$p0 - p0) < 1e-12,
        , drop = FALSE
      ]
      if (nrow(summary_match) != 1L) {
        stop("Could not identify a unique final summary row for cached fit.")
      }
      response_center <- as.numeric(summary_match$response_center[[1L]])
      response_scale <- as.numeric(summary_match$response_scale[[1L]])
      qhat <- qhat_model * response_scale + response_center

      truth_col <- match(p0, p_vec)
      y_fit_obs <- y[keep_idx]
      q_fit_true <- q_true[keep_idx, truth_col]
      loss <- pinball(y_fit_obs, qhat, p0)
      error_true <- qhat - q_fit_true

      row_index <- row_index + 1L
      fit_rows[[row_index]] <- data.frame(
        model_id = model_id,
        architecture = architecture,
        candidate_id = candidate_id,
        reservoir_seed = reservoir_seed,
        p0 = p0,
        t = keep_idx,
        y = y_fit_obs,
        q_true = q_fit_true,
        qhat = qhat,
        pinball = loss,
        qerror_true = error_true,
        hit = as.numeric(y_fit_obs <= qhat),
        stringsAsFactors = FALSE
      )

      seed_index <- seed_index + 1L
      fit_seed_rows[[seed_index]] <- data.frame(
        period = "fit",
        model_id = model_id,
        architecture = architecture,
        candidate_id = candidate_id,
        reservoir_seed = reservoir_seed,
        p0 = p0,
        mean_pinball = mean(loss),
        qrmse_true = sqrt(mean(error_true^2)),
        qbias_true = mean(error_true),
        hit_rate = mean(y_fit_obs <= qhat),
        n = length(qhat),
        stringsAsFactors = FALSE
      )
    }
  }
}

fit_pointwise <- do.call(rbind, fit_rows)
fit_by_seed <- do.call(rbind, fit_seed_rows)

# Add known conditional-quantile truth to held-out final forecasts.
forecast_pointwise <- result$final_pointwise
truth_lookup <- expand.grid(
  p0 = p_vec,
  horizon = seq_len(100L),
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
truth_lookup$q_true <- vapply(seq_len(nrow(truth_lookup)), function(i) {
  q_true[1000L + truth_lookup$horizon[[i]], match(truth_lookup$p0[[i]], p_vec)]
}, numeric(1L))
forecast_pointwise <- merge(
  forecast_pointwise,
  truth_lookup,
  by = c("p0", "horizon"),
  all.x = TRUE,
  sort = FALSE
)
forecast_pointwise$qerror_true <- forecast_pointwise$qhat - forecast_pointwise$q_true

forecast_keys <- unique(forecast_pointwise[, c(
  "model_id", "architecture", "candidate_id", "reservoir_seed", "p0"
), drop = FALSE])
forecast_seed_rows <- lapply(seq_len(nrow(forecast_keys)), function(i) {
  key <- forecast_keys[i, , drop = FALSE]
  z <- forecast_pointwise[
    forecast_pointwise$model_id == key$model_id &
      forecast_pointwise$reservoir_seed == key$reservoir_seed &
      abs(forecast_pointwise$p0 - key$p0) < 1e-12,
    , drop = FALSE
  ]
  data.frame(
    period = "forecast",
    model_id = key$model_id,
    architecture = key$architecture,
    candidate_id = key$candidate_id,
    reservoir_seed = key$reservoir_seed,
    p0 = key$p0,
    mean_pinball = mean(z$pinball),
    qrmse_true = sqrt(mean(z$qerror_true^2)),
    qbias_true = mean(z$qerror_true),
    hit_rate = mean(z$hit),
    n = nrow(z),
    stringsAsFactors = FALSE
  )
})
forecast_by_seed <- do.call(rbind, forecast_seed_rows)
seed_metrics <- rbind(fit_by_seed, forecast_by_seed)

summarise_seed_metrics <- function(x) {
  keys <- unique(x[, c("period", "model_id", "architecture", "candidate_id", "p0"), drop = FALSE])
  do.call(rbind, lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, , drop = FALSE]
    z <- x[
      x$period == key$period &
        x$model_id == key$model_id &
        abs(x$p0 - key$p0) < 1e-12,
      , drop = FALSE
    ]
    data.frame(
      period = key$period,
      model_id = key$model_id,
      architecture = key$architecture,
      candidate_id = key$candidate_id,
      p0 = key$p0,
      mean_pinball = mean(z$mean_pinball),
      median_pinball = stats::median(z$mean_pinball),
      iqr_pinball = stats::IQR(z$mean_pinball),
      mean_qrmse_true = mean(z$qrmse_true),
      median_qrmse_true = stats::median(z$qrmse_true),
      mean_qbias_true = mean(z$qbias_true),
      mean_hit_rate = mean(z$hit_rate),
      seed_count = nrow(z),
      stringsAsFactors = FALSE
    )
  }))
}
fit_forecast_summary <- summarise_seed_metrics(seed_metrics)

# Pairwise old-versus-residual summaries on the same selected hyperparameters.
main_models <- c("M0_plain_selected", "M1_residual_same_hyperparameters")
main_seed <- seed_metrics[seed_metrics$model_id %in% main_models, , drop = FALSE]
plain_seed <- main_seed[main_seed$model_id == main_models[[1L]], ]
resid_seed <- main_seed[main_seed$model_id == main_models[[2L]], ]
pair_seed <- merge(
  plain_seed,
  resid_seed,
  by = c("period", "reservoir_seed", "p0"),
  suffixes = c("_plain", "_residual")
)
pair_seed$pinball_difference_residual_minus_plain <-
  pair_seed$mean_pinball_residual - pair_seed$mean_pinball_plain
pair_seed$pinball_improvement_percent <-
  100 * (pair_seed$mean_pinball_plain - pair_seed$mean_pinball_residual) /
  pmax(pair_seed$mean_pinball_plain, sqrt(.Machine$double.eps))
pair_seed$qrmse_difference_residual_minus_plain <-
  pair_seed$qrmse_true_residual - pair_seed$qrmse_true_plain

pair_keys <- unique(pair_seed[, c("period", "p0"), drop = FALSE])
pair_summary <- do.call(rbind, lapply(seq_len(nrow(pair_keys)), function(i) {
  z <- pair_seed[
    pair_seed$period == pair_keys$period[[i]] &
      abs(pair_seed$p0 - pair_keys$p0[[i]]) < 1e-12,
    , drop = FALSE
  ]
  data.frame(
    period = pair_keys$period[[i]],
    p0 = pair_keys$p0[[i]],
    median_pinball_improvement_percent = stats::median(z$pinball_improvement_percent),
    mean_pinball_improvement_percent = mean(z$pinball_improvement_percent),
    residual_pinball_wins = sum(z$pinball_difference_residual_minus_plain < 0),
    seed_count = nrow(z),
    median_qrmse_difference_residual_minus_plain =
      stats::median(z$qrmse_difference_residual_minus_plain),
    stringsAsFactors = FALSE
  )
}))

# Mean fitted/forecast quantile trajectories across held-out reservoir seeds.
mean_curve <- function(x, time_name) {
  keys <- unique(x[, c("model_id", "architecture", "p0", time_name), drop = FALSE])
  keys$qhat <- vapply(seq_len(nrow(keys)), function(i) {
    idx <- x$model_id == keys$model_id[[i]] &
      abs(x$p0 - keys$p0[[i]]) < 1e-12 &
      x[[time_name]] == keys[[time_name]][[i]]
    mean(x$qhat[idx])
  }, numeric(1L))
  keys
}
fit_mean_curve <- mean_curve(fit_pointwise, "t")
forecast_pointwise$t <- 1000L + forecast_pointwise$horizon
forecast_mean_curve <- mean_curve(forecast_pointwise, "t")

# Tables.
utils::write.csv(fit_pointwise, file.path(output_dir, "tables", "fit_pointwise.csv"), row.names = FALSE)
utils::write.csv(forecast_pointwise, file.path(output_dir, "tables", "forecast_pointwise_with_truth.csv"), row.names = FALSE)
utils::write.csv(seed_metrics, file.path(output_dir, "tables", "fit_forecast_metrics_by_seed.csv"), row.names = FALSE)
utils::write.csv(fit_forecast_summary, file.path(output_dir, "tables", "fit_forecast_summary.csv"), row.names = FALSE)
utils::write.csv(pair_seed, file.path(output_dir, "tables", "plain_residual_pairwise_by_seed.csv"), row.names = FALSE)
utils::write.csv(pair_summary, file.path(output_dir, "tables", "plain_residual_pairwise_summary.csv"), row.names = FALSE)
utils::write.csv(fit_mean_curve, file.path(output_dir, "tables", "fit_mean_curve.csv"), row.names = FALSE)
utils::write.csv(forecast_mean_curve, file.path(output_dir, "tables", "forecast_mean_curve.csv"), row.names = FALSE)

# A direct six-panel fit/forecast comparison using the mean trajectory over the
# final, previously unused reservoir seeds.
plot_file <- file.path(output_dir, "figures", "fit_forecast_comparison.png")
grDevices::png(plot_file, width = 2400, height = 1450, res = 180)
old_par <- graphics::par(no.readonly = TRUE)
on.exit({
  graphics::par(old_par)
  grDevices::dev.off()
}, add = TRUE)
graphics::par(mfrow = c(2, 3), mar = c(3.7, 4.1, 3.1, 1.0), oma = c(0, 0, 2.4, 0))

model_labels <- c(
  M0_plain_selected = "Plain Q-DESN",
  M1_residual_same_hyperparameters = "Residual Q-DESN"
)
model_cols <- c(
  M0_plain_selected = "#2166AC",
  M1_residual_same_hyperparameters = "#B2182B"
)

for (ip in seq_along(p_vec)) {
  p0 <- p_vec[[ip]]
  idx_time <- 801:1000
  y_lim <- range(
    y[idx_time],
    q_true[idx_time, ip],
    fit_mean_curve$qhat[
      fit_mean_curve$model_id %in% names(model_labels) &
        abs(fit_mean_curve$p0 - p0) < 1e-12 &
        fit_mean_curve$t %in% idx_time
    ],
    finite = TRUE
  )
  graphics::plot(idx_time, y[idx_time], type = "l", col = "grey65", lwd = 1,
                 xlab = "Time", ylab = "Response / quantile", ylim = y_lim,
                 main = sprintf("Fit: q = %.2f", p0))
  graphics::lines(idx_time, q_true[idx_time, ip], col = "black", lwd = 2, lty = 2)
  for (mid in names(model_labels)) {
    z <- fit_mean_curve[
      fit_mean_curve$model_id == mid &
        abs(fit_mean_curve$p0 - p0) < 1e-12 &
        fit_mean_curve$t %in% idx_time,
      , drop = FALSE
    ]
    z <- z[order(z$t), ]
    graphics::lines(z$t, z$qhat, col = model_cols[[mid]], lwd = 1.8)
  }
  if (ip == 1L) {
    graphics::legend(
      "topleft",
      legend = c("Observed y", "True conditional quantile", unname(model_labels)),
      col = c("grey65", "black", unname(model_cols)),
      lty = c(1, 2, 1, 1),
      lwd = c(1, 2, 1.8, 1.8),
      bty = "n",
      cex = 0.78
    )
  }
}

for (ip in seq_along(p_vec)) {
  p0 <- p_vec[[ip]]
  idx_time <- 1001:1100
  y_lim <- range(
    y[idx_time],
    q_true[idx_time, ip],
    forecast_mean_curve$qhat[
      forecast_mean_curve$model_id %in% names(model_labels) &
        abs(forecast_mean_curve$p0 - p0) < 1e-12
    ],
    finite = TRUE
  )
  graphics::plot(idx_time, y[idx_time], type = "l", col = "grey55", lwd = 1.2,
                 xlab = "Forecast target time", ylab = "Response / quantile", ylim = y_lim,
                 main = sprintf("100-step forecast: q = %.2f", p0))
  graphics::lines(idx_time, q_true[idx_time, ip], col = "black", lwd = 2, lty = 2)
  for (mid in names(model_labels)) {
    z <- forecast_mean_curve[
      forecast_mean_curve$model_id == mid &
        abs(forecast_mean_curve$p0 - p0) < 1e-12,
      , drop = FALSE
    ]
    z <- z[order(z$t), ]
    graphics::lines(z$t, z$qhat, col = model_cols[[mid]], lwd = 1.8)
  }
}
graphics::mtext(
  "Plain versus inter-layer residual AL-VB Q-DESN (RHS tau0 = 0.1)",
  outer = TRUE,
  side = 3,
  line = 0.4,
  font = 2,
  cex = 1.15
)
graphics::par(old_par)
grDevices::dev.off()
on.exit(NULL, add = FALSE)

# Paired seed-level aggregate forecast differences.
paired <- result$final_paired_differences
paired_file <- file.path(output_dir, "figures", "paired_forecast_loss_difference.png")
grDevices::png(paired_file, width = 1400, height = 900, res = 160)
graphics::par(mar = c(4.5, 4.8, 3.5, 1.0))
cols <- ifelse(paired$difference_M1_minus_M0 < 0, "#2166AC", "#B2182B")
graphics::barplot(
  paired$difference_M1_minus_M0,
  names.arg = paired$reservoir_seed,
  col = cols,
  border = NA,
  xlab = "Held-out reservoir seed",
  ylab = "Scaled pinball difference: residual - plain",
  main = "Paired 100-step forecast loss difference"
)
graphics::abline(h = 0, lwd = 1.5)
graphics::mtext("Negative values favor the residual architecture", side = 3, line = 0.2, cex = 0.85)
grDevices::dev.off()

saveRDS(
  list(
    simulation = list(
      info = sim$info,
      y = y,
      mu_true = mu_true,
      sigma_true = sigma_true,
      q_true = q_true
    ),
    ablation = result,
    fit_pointwise = fit_pointwise,
    forecast_pointwise = forecast_pointwise,
    seed_metrics = seed_metrics,
    summary = fit_forecast_summary,
    pairwise_summary = pair_summary,
    execution_seconds = execution_seconds,
    session_info = utils::sessionInfo()
  ),
  file.path(output_dir, "qdesn_residual_execution_result.rds"),
  compress = "xz"
)

capture.output(utils::sessionInfo(), file = file.path(output_dir, "manifest", "session_info.txt"))
writeLines(
  c(
    sprintf("quick: %s", quick),
    sprintf("workers: %d", workers),
    sprintf("execution_seconds: %.6f", execution_seconds),
    sprintf("run_signature_sha256: %s", result$run_signature_sha256),
    sprintf("series_sha256: %s", result$series_sha256),
    sprintf("retain_residual: %s", isTRUE(result$decision$retain_residual))
  ),
  file.path(output_dir, "manifest", "execution_summary.txt")
)

cat("\n=== SELECTED MODELS ===\n")
print(result$selected_models, row.names = FALSE)
cat("\n=== FIT AND FORECAST SUMMARY ===\n")
print(fit_forecast_summary, row.names = FALSE)
cat("\n=== PLAIN VS RESIDUAL PAIRED SUMMARY ===\n")
print(pair_summary, row.names = FALSE)
cat("\n=== FINAL DECISION ===\n")
print(result$decision)
cat(sprintf("\nCompleted in %.2f seconds. Outputs: %s\n", execution_seconds, output_dir))
