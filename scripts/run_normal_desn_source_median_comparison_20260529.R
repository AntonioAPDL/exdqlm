#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(flag, default = NULL) {
  hit <- which(args == flag)
  if (!length(hit) || hit[[1L]] >= length(args)) return(default)
  args[[hit[[1L]] + 1L]]
}

arg_flag <- function(flag) any(args == flag)

arg_int <- function(flag, default) {
  value <- suppressWarnings(as.integer(arg_value(flag, as.character(default))))
  if (!length(value) || !is.finite(value)) stop(sprintf("%s must be a finite integer.", flag), call. = FALSE)
  value
}

repo_root <- normalizePath(arg_value("--repo", getwd()), mustWork = TRUE)
output_dir <- arg_value(
  "--output-dir",
  file.path(repo_root, "results", "normal_desn_source_median_comparison_20260529")
)
source_dir <- arg_value(
  "--source-dir",
  "/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast/normal/tau_0p50/fit_input_lastTT500"
)
seed <- arg_int("--seed", 20260529L)
D <- arg_int("--D", 1L)
n_res <- arg_int("--n", 5L)
m_lag <- arg_int("--m", 1L)
washout <- arg_int("--washout", 25L)
chunk_size <- arg_int("--chunk-size", 64L)
max_iter <- arg_int("--max-iter", 15L)
stochastic_max_iter <- arg_int("--stochastic-max-iter", 40L)
synthetic_n <- arg_int("--synthetic-n", 0L)
run_stochastic <- !arg_flag("--skip-stochastic")

if (D != 1L) stop("This comparison harness currently supports D = 1 only.", call. = FALSE)
if (n_res < 1L) stop("--n must be positive.", call. = FALSE)
if (m_lag < 0L) stop("--m must be non-negative.", call. = FALSE)
if (washout < 0L) stop("--washout must be non-negative.", call. = FALSE)
if (chunk_size < 1L) stop("--chunk-size must be positive.", call. = FALSE)
if (max_iter < 1L || stochastic_max_iter < 1L) stop("iteration controls must be positive.", call. = FALSE)
if (synthetic_n < 0L) stop("--synthetic-n must be non-negative.", call. = FALSE)

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
setwd(repo_root)

`%||%` <- function(x, y) if (is.null(x)) y else x

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("This comparison requires pkgload.", call. = FALSE)
}
pkgload::load_all(repo_root, quiet = TRUE)

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, quote = TRUE)
  invisible(path)
}

git_value <- function(cmd) {
  out <- tryCatch(system2("git", cmd, stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  if (!length(out)) return(NA_character_)
  out[[1L]]
}

max_abs <- function(x) {
  x <- as.numeric(x)
  if (!length(x) || all(is.na(x))) return(NA_real_)
  max(abs(x), na.rm = TRUE)
}

pinball_loss <- function(y, q, tau = 0.5) {
  u <- as.numeric(y) - as.numeric(q)
  mean((tau - as.numeric(u < 0)) * u)
}

rmse <- function(y, mu) sqrt(mean((as.numeric(y) - as.numeric(mu))^2))
mae <- function(y, mu) mean(abs(as.numeric(y) - as.numeric(mu)))

read_series <- function() {
  if (synthetic_n > 0L) {
    set.seed(seed)
    t <- seq_len(synthetic_n)
    mu <- as.numeric(0.25 * sin(t / 6) + 0.004 * t + 0.1 * cos(t / 13))
    y <- mu + stats::rnorm(synthetic_n, sd = 0.08)
    return(list(
      series = data.frame(t = t, y = y, mu = mu, q_target = mu, eps = y - mu),
      source_kind = "synthetic",
      source_dir = NA_character_,
      source_hash = NA_character_
    ))
  }
  source_dir_norm <- normalizePath(source_dir, mustWork = TRUE)
  series_path <- file.path(source_dir_norm, "series_wide.csv")
  series <- utils::read.csv(series_path)
  required <- c("t", "y", "mu", "q_target", "eps")
  if (!identical(names(series), required)) {
    stop("series_wide.csv must have columns t,y,mu,q_target,eps.", call. = FALSE)
  }
  if (max(abs(series$mu - series$q_target), na.rm = TRUE) > 0) {
    stop("This harness expects the Gaussian median source with q_target equal to mu.", call. = FALSE)
  }
  list(
    series = series,
    source_kind = "frozen_source_last500",
    source_dir = source_dir_norm,
    source_hash = unname(tools::md5sum(series_path))
  )
}

fit_qdesn_normal <- function(label, y, normal_args) {
  tm <- system.time({
    fit <- exdqlm::qdesn_fit_normal(
      y = y,
      p0 = 0.5,
      D = D,
      n = n_res,
      n_tilde = integer(0),
      m = m_lag,
      washout = washout,
      add_bias = TRUE,
      seed = seed + 10L,
      normal_args = normal_args
    )
  })
  list(label = label, family = "normal", fit = fit, elapsed_sec = unname(tm[["elapsed"]]))
}

fit_qdesn_vb <- function(label, y, family, vb_args) {
  tm <- system.time({
    fit <- exdqlm::qdesn_fit_vb(
      y = y,
      p0 = 0.5,
      D = D,
      n = n_res,
      n_tilde = integer(0),
      m = m_lag,
      washout = washout,
      add_bias = TRUE,
      seed = seed + 10L,
      vb_args = vb_args
    )
  })
  list(label = label, family = family, fit = fit, elapsed_sec = unname(tm[["elapsed"]]))
}

predict_fit <- function(obj) {
  if (inherits(obj$fit, "qdesn_normal_fit")) {
    return(list(
      y_fit = obj$fit$y_fit,
      point = as.numeric(obj$fit$mu_hat),
      beta_mean = as.numeric(obj$fit$fit$beta$mean),
      beta_cov = as.matrix(obj$fit$fit$beta$cov),
      sigma = sqrt(obj$fit$fit$omega2$mean %||% obj$fit$fit$omega2$mode),
      gamma = NA_real_,
      converged = !isTRUE(obj$fit$fit$uses_vb) || isTRUE(obj$fit$fit$converged),
      iter = if (is.null(obj$fit$fit$trace)) NA_integer_ else nrow(obj$fit$fit$trace),
      target_label = obj$fit$fit$target_label,
      chunking = obj$fit$fit$misc$chunking %||% list(enabled = FALSE, mode = "none"),
      design_hash = obj$fit$meta$normal$design_hash %||% NA_character_,
      feature_settings_hash = obj$fit$meta$normal$feature_settings_hash %||% NA_character_
    ))
  }
  readout <- obj$fit$fit
  point <- as.numeric(obj$fit$X %*% as.numeric(readout$qbeta$m))
  misc <- readout$misc %||% list()
  list(
    y_fit = obj$fit$y_fit,
    point = point,
    beta_mean = as.numeric(readout$qbeta$m),
    beta_cov = as.matrix(readout$qbeta$V),
    sigma = tail(as.numeric(misc$sigma_trace %||% NA_real_), 1L),
    gamma = tail(as.numeric(misc$gamma_trace %||% NA_real_), 1L),
    converged = isTRUE(readout$converged),
    iter = as.integer(readout$iter %||% NA_integer_),
    target_label = obj$fit$meta$target_label %||% paste0(obj$family, "_vb"),
    chunking = misc$chunking %||% list(enabled = FALSE, mode = "none"),
    design_hash = exdqlm:::.qdesn_vb_design_hash(obj$fit$X),
    feature_settings_hash = exdqlm:::.qdesn_vb_feature_settings_hash(obj$fit$meta)
  )
}

method_summary_row <- function(obj, reference = NULL) {
  pred <- predict_fit(obj)
  ref_pred <- if (is.null(reference)) NULL else predict_fit(reference)
  chunking_mode <- if (isTRUE(pred$chunking$enabled)) as.character(pred$chunking$mode %||% "unknown") else "none"
  beta_cov_diag <- diag(pred$beta_cov)
  data.frame(
    method = obj$label,
    likelihood_family = obj$family,
    target_label = pred$target_label,
    target = if (identical(obj$family, "normal")) "conditional_mean" else "tau_0p50_quantile",
    exact_status = if (grepl("exact_chunked", pred$target_label) || identical(chunking_mode, "exact")) {
      "full_data_exact_chunked"
    } else if (grepl("stochastic", obj$label)) {
      "full_data_approx_stochastic"
    } else if (identical(obj$family, "normal") && grepl("vb_approx", pred$target_label)) {
      "full_data_vb_approx"
    } else {
      "full_data_exact_or_cavi"
    },
    prior_family = if (grepl("rhs", obj$label)) "rhs_ns" else "ridge",
    init_source = "none",
    n_fit = length(pred$y_fit),
    p = length(pred$beta_mean),
    rmse_y = rmse(pred$y_fit, pred$point),
    mae_y = mae(pred$y_fit, pred$point),
    pinball_tau_0p50 = pinball_loss(pred$y_fit, pred$point, tau = 0.5),
    beta_l2 = sqrt(sum(pred$beta_mean^2)),
    beta_cov_diag_min = min(beta_cov_diag),
    beta_cov_diag_max = max(beta_cov_diag),
    sigma = as.numeric(pred$sigma)[1L],
    gamma = as.numeric(pred$gamma)[1L],
    converged = isTRUE(pred$converged),
    iter = as.integer(pred$iter),
    finite_state = all(is.finite(pred$point)) &&
      all(is.finite(pred$beta_mean)) &&
      all(is.finite(beta_cov_diag)) &&
      is.finite(as.numeric(pred$sigma)[1L]),
    elapsed_sec = as.numeric(obj$elapsed_sec),
    chunking_mode = chunking_mode,
    design_hash = pred$design_hash,
    feature_settings_hash = pred$feature_settings_hash,
    beta_mean_max_abs_diff_vs_reference = if (is.null(ref_pred)) NA_real_ else max_abs(pred$beta_mean - ref_pred$beta_mean),
    beta_cov_max_abs_diff_vs_reference = if (is.null(ref_pred)) NA_real_ else max_abs(pred$beta_cov - ref_pred$beta_cov),
    prediction_max_abs_diff_vs_reference = if (is.null(ref_pred)) NA_real_ else max_abs(pred$point - ref_pred$point),
    stringsAsFactors = FALSE
  )
}

exact_pair_row <- function(left, right, tolerance = 1e-7) {
  lp <- predict_fit(left)
  rp <- predict_fit(right)
  gate <- max(
    max_abs(lp$beta_mean - rp$beta_mean),
    max_abs(lp$beta_cov - rp$beta_cov),
    max_abs(lp$point - rp$point),
    abs(as.numeric(lp$sigma)[1L] - as.numeric(rp$sigma)[1L]),
    abs(as.numeric(lp$gamma)[1L] - as.numeric(rp$gamma)[1L]),
    na.rm = TRUE
  )
  data.frame(
    reference_method = left$label,
    exact_chunked_method = right$label,
    tolerance = tolerance,
    beta_mean_max_abs_diff = max_abs(lp$beta_mean - rp$beta_mean),
    beta_cov_max_abs_diff = max_abs(lp$beta_cov - rp$beta_cov),
    prediction_max_abs_diff = max_abs(lp$point - rp$point),
    sigma_abs_diff = abs(as.numeric(lp$sigma)[1L] - as.numeric(rp$sigma)[1L]),
    gamma_abs_diff = abs(as.numeric(lp$gamma)[1L] - as.numeric(rp$gamma)[1L]),
    max_gate_diff = gate,
    passed = is.finite(gate) && gate <= tolerance,
    stringsAsFactors = FALSE
  )
}

cat("Normal DESN source-median comparison\n")
cat("repo:", repo_root, "\n")
cat("output_dir:", output_dir, "\n")
cat("seed:", seed, "\n")

src <- read_series()
y <- as.numeric(src$series$y)
if (washout >= length(y)) stop("--washout must be smaller than the selected series length.", call. = FALSE)

normal_ridge_args <- list(
  beta_prior_type = "scaled_ridge",
  prior = list(beta_ridge_tau2 = 50, intercept_var = 1e6),
  omega_prior = list(a = 2, b = 1)
)
normal_ridge_chunked_args <- normal_ridge_args
normal_ridge_chunked_args$control <- list(chunking = list(
  enabled = TRUE,
  mode = "exact",
  chunk_size = chunk_size,
  order = "sequential"
))
normal_rhs_args <- list(
  beta_prior_type = "rhs_ns",
  omega_prior = list(a = 2, b = 1),
  rhs = list(
    tau0 = 0.8,
    a_zeta = 2,
    b_zeta = 1,
    zeta2_fixed = 1.25,
    s2 = 1.25,
    shrink_intercept = FALSE,
    intercept_prec = 1e-12,
    n_inner = 1L
  ),
  control = list(max_iter = max_iter, min_iter = min(5L, max_iter), tol = 0)
)

base_vb <- list(
  max_iter = max_iter,
  min_iter_elbo = min(8L, max_iter),
  tol = 0,
  tol_par = 0,
  n_samp_xi = 32L,
  verbose = FALSE,
  beta_prior_type = "ridge",
  beta_ridge_tau2 = 50
)
exact_chunking <- list(enabled = TRUE, mode = "exact", chunk_size = chunk_size, order = "sequential")
stochastic_chunking <- list(
  enabled = TRUE,
  mode = "stochastic",
  chunk_size = chunk_size,
  order = "random",
  seed = seed + 200L,
  learning_rate = list(t0 = 10, kappa = 0.75, rho_min = 0.02),
  refresh = list(full_every = 20L, objective_every = 20L, sigma_every = 5L, rhs_every = 20L, local_every = 20L),
  diagnostics = list(trace = TRUE, store_batch_ids = FALSE, check_finite_every = 1L)
)

fits <- list()
fits$normal_scaled_ridge <- fit_qdesn_normal("normal_scaled_ridge", y, normal_ridge_args)
fits$normal_scaled_ridge_exact_chunked <- fit_qdesn_normal(
  "normal_scaled_ridge_exact_chunked",
  y,
  normal_ridge_chunked_args
)
fits$normal_rhs_ns_vb <- fit_qdesn_normal("normal_rhs_ns_vb", y, normal_rhs_args)

fits$qdesn_al_ridge <- fit_qdesn_vb("qdesn_al_ridge", y, "al", utils::modifyList(base_vb, list(
  likelihood_family = "al",
  al_fixed_gamma = 0
)))
fits$qdesn_al_ridge_exact_chunked <- fit_qdesn_vb("qdesn_al_ridge_exact_chunked", y, "al", utils::modifyList(base_vb, list(
  likelihood_family = "al",
  al_fixed_gamma = 0,
  chunking = exact_chunking
)))
if (isTRUE(run_stochastic)) {
  fits$qdesn_al_ridge_stochastic <- fit_qdesn_vb("qdesn_al_ridge_stochastic", y, "al", utils::modifyList(base_vb, list(
    likelihood_family = "al",
    al_fixed_gamma = 0,
    max_iter = stochastic_max_iter,
    chunking = stochastic_chunking
  )))
}
fits$qdesn_exal_ridge <- fit_qdesn_vb("qdesn_exal_ridge", y, "exal", utils::modifyList(base_vb, list(
  likelihood_family = "exal"
)))
fits$qdesn_exal_ridge_exact_chunked <- fit_qdesn_vb("qdesn_exal_ridge_exact_chunked", y, "exal", utils::modifyList(base_vb, list(
  likelihood_family = "exal",
  chunking = exact_chunking
)))

refs <- list(
  normal_scaled_ridge_exact_chunked = fits$normal_scaled_ridge,
  qdesn_al_ridge_exact_chunked = fits$qdesn_al_ridge,
  qdesn_al_ridge_stochastic = fits$qdesn_al_ridge,
  qdesn_exal_ridge_exact_chunked = fits$qdesn_exal_ridge
)
summary <- do.call(rbind, lapply(names(fits), function(nm) method_summary_row(fits[[nm]], refs[[nm]])))
exact <- do.call(rbind, list(
  exact_pair_row(fits$normal_scaled_ridge, fits$normal_scaled_ridge_exact_chunked),
  exact_pair_row(fits$qdesn_al_ridge, fits$qdesn_al_ridge_exact_chunked),
  exact_pair_row(fits$qdesn_exal_ridge, fits$qdesn_exal_ridge_exact_chunked)
))
predictions <- do.call(rbind, lapply(fits, function(obj) {
  pred <- predict_fit(obj)
  data.frame(method = obj$label, row_id = seq_along(pred$y_fit), y = pred$y_fit, point = pred$point)
}))
repo_state <- data.frame(
  repo = repo_root,
  package_head = git_value(c("rev-parse", "--short", "HEAD")),
  package_dirty = nzchar(git_value(c("status", "--porcelain"))),
  source_kind = src$source_kind,
  source_dir = src$source_dir,
  source_hash = src$source_hash,
  seed = seed,
  D = D,
  n = n_res,
  m = m_lag,
  washout = washout,
  chunk_size = chunk_size,
  max_iter = max_iter,
  stochastic_max_iter = stochastic_max_iter,
  stringsAsFactors = FALSE
)

write_csv(repo_state, file.path(output_dir, "repo_state.csv"))
write_csv(summary, file.path(output_dir, "method_summary.csv"))
write_csv(exact, file.path(output_dir, "exact_equivalence.csv"))
write_csv(predictions, file.path(output_dir, "predictions_by_method.csv"))

md <- c(
  "# Normal DESN Source-Median Comparison",
  "",
  sprintf("- Package HEAD: `%s`", repo_state$package_head[[1L]]),
  sprintf("- Package dirty at run time: `%s`", repo_state$package_dirty[[1L]]),
  sprintf("- Source kind: `%s`", repo_state$source_kind[[1L]]),
  sprintf("- Source rows: `%d`", length(y)),
  sprintf("- DESN: D=%d, n=%d, m=%d, washout=%d", D, n_res, m_lag, washout),
  sprintf("- Seed: `%d`", seed),
  "",
  "## Exact Equivalence",
  "",
  paste(utils::capture.output(print(exact, row.names = FALSE)), collapse = "\n"),
  "",
  "## Method Summary",
  "",
  paste(utils::capture.output(print(summary[, intersect(
    c("method", "likelihood_family", "target", "exact_status", "rmse_y", "pinball_tau_0p50", "converged", "finite_state", "elapsed_sec"),
    names(summary)
  )], row.names = FALSE)), collapse = "\n"),
  "",
  "## Interpretation",
  "",
  "Normal DESN rows are conditional-mean Gaussian readouts. Q-DESN rows are tau=0.50 quantile readouts.",
  "For this Gaussian median source, the true mean and median coincide, so tau=0.50 pinball is a useful descriptive metric.",
  "Exact chunked rows must match their unchunked references; stochastic AL is approximate when included."
)
writeLines(md, file.path(output_dir, "normal_desn_source_median_comparison_summary.md"))

cat("wrote:", output_dir, "\n")
cat("exact gates passed:", all(exact$passed), "\n")
if (!all(exact$passed)) quit(status = 1L)
