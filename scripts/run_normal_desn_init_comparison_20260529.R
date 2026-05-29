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
  file.path(repo_root, "results", "normal_desn_init_comparison_20260529")
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
max_iter <- arg_int("--max-iter", 15L)
synthetic_n <- arg_int("--synthetic-n", 0L)
run_mcmc <- arg_flag("--run-mcmc")
mcmc_burn <- arg_int("--mcmc-burn", 20L)
mcmc_draws <- arg_int("--mcmc-draws", 20L)

if (D != 1L) stop("This initialization harness currently supports D = 1 only.", call. = FALSE)
if (n_res < 1L) stop("--n must be positive.", call. = FALSE)
if (m_lag < 0L) stop("--m must be non-negative.", call. = FALSE)
if (washout < 0L) stop("--washout must be non-negative.", call. = FALSE)
if (max_iter < 1L) stop("--max-iter must be positive.", call. = FALSE)
if (synthetic_n < 0L) stop("--synthetic-n must be non-negative.", call. = FALSE)
if (mcmc_burn < 1L || mcmc_draws < 1L) stop("MCMC controls must be positive.", call. = FALSE)

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

git_dirty <- function() {
  out <- tryCatch(system2("git", c("status", "--porcelain"), stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  length(out) > 0L && any(nzchar(out))
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

normal_fit <- function(label, y, normal_args) {
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

vb_fit <- function(label, y, family, init = NULL) {
  vb_args <- list(
    likelihood_family = family,
    max_iter = max_iter,
    min_iter_elbo = min(8L, max_iter),
    tol = 0,
    tol_par = 0,
    n_samp_xi = 32L,
    verbose = FALSE,
    beta_prior_type = "ridge",
    beta_ridge_tau2 = 50
  )
  if (identical(family, "al")) vb_args$al_fixed_gamma <- 0
  if (!is.null(init)) vb_args$init <- init
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

mcmc_fit <- function(label, y, init = NULL) {
  mcmc_args <- list(
    likelihood_family = "al",
    al_fixed_gamma = 0,
    beta_prior_type = "ridge",
    beta_ridge_tau2 = 50,
    n_burn = mcmc_burn,
    n_mcmc = mcmc_draws,
    thin = 1L,
    verbose = FALSE,
    progress_every = max(mcmc_burn + mcmc_draws + 1L, 100L)
  )
  if (!is.null(init)) mcmc_args$init <- init
  tm <- system.time({
    fit <- exdqlm::qdesn_fit_mcmc(
      y = y,
      p0 = 0.5,
      D = D,
      n = n_res,
      n_tilde = integer(0),
      m = m_lag,
      washout = washout,
      add_bias = TRUE,
      seed = seed + 10L,
      mcmc_args = mcmc_args
    )
  })
  list(label = label, family = "al_mcmc", fit = fit, elapsed_sec = unname(tm[["elapsed"]]))
}

extract_prediction <- function(obj) {
  if (inherits(obj$fit, "qdesn_normal_fit")) {
    return(list(
      y_fit = obj$fit$y_fit,
      point = as.numeric(obj$fit$mu_hat),
      beta_mean = as.numeric(obj$fit$fit$beta$mean),
      sigma = sqrt(obj$fit$fit$omega2$mean %||% obj$fit$fit$omega2$mode),
      gamma = NA_real_,
      converged = !isTRUE(obj$fit$fit$uses_vb) || isTRUE(obj$fit$fit$converged),
      iter = if (is.null(obj$fit$fit$trace)) NA_integer_ else nrow(obj$fit$fit$trace),
      design_hash = obj$fit$meta$normal$design_hash %||% NA_character_
    ))
  }
  if (identical(obj$family, "al_mcmc")) {
    beta_mean <- as.numeric(obj$fit$fit$summary$beta_mean)
    return(list(
      y_fit = obj$fit$y_fit,
      point = as.numeric(obj$fit$X %*% beta_mean),
      beta_mean = beta_mean,
      sigma = as.numeric(obj$fit$fit$summary$sigma_mean %||% NA_real_)[1L],
      gamma = as.numeric(obj$fit$fit$summary$gamma_mean %||% 0)[1L],
      converged = TRUE,
      iter = mcmc_burn + mcmc_draws,
      design_hash = exdqlm:::.qdesn_vb_design_hash(obj$fit$X)
    ))
  }
  readout <- obj$fit$fit
  misc <- readout$misc %||% list()
  beta_mean <- as.numeric(readout$qbeta$m)
  list(
    y_fit = obj$fit$y_fit,
    point = as.numeric(obj$fit$X %*% beta_mean),
    beta_mean = beta_mean,
    sigma = tail(as.numeric(misc$sigma_trace %||% NA_real_), 1L),
    gamma = tail(as.numeric(misc$gamma_trace %||% NA_real_), 1L),
    converged = isTRUE(readout$converged),
    iter = as.integer(readout$iter %||% NA_integer_),
    design_hash = exdqlm:::.qdesn_vb_design_hash(obj$fit$X)
  )
}

summary_row <- function(obj, init_source = "none", reference = NULL) {
  pred <- extract_prediction(obj)
  ref <- if (is.null(reference)) NULL else extract_prediction(reference)
  data.frame(
    method = obj$label,
    likelihood_family = obj$family,
    init_source = init_source,
    n_fit = length(pred$y_fit),
    p = length(pred$beta_mean),
    rmse_y = rmse(pred$y_fit, pred$point),
    mae_y = mae(pred$y_fit, pred$point),
    pinball_tau_0p50 = pinball_loss(pred$y_fit, pred$point, tau = 0.5),
    beta_l2 = sqrt(sum(pred$beta_mean^2)),
    sigma = as.numeric(pred$sigma)[1L],
    gamma = as.numeric(pred$gamma)[1L],
    converged = isTRUE(pred$converged),
    iter = as.integer(pred$iter),
    finite_state = all(is.finite(pred$point)) &&
      all(is.finite(pred$beta_mean)) &&
      is.finite(as.numeric(pred$sigma)[1L]),
    elapsed_sec = as.numeric(obj$elapsed_sec),
    design_hash = pred$design_hash,
    beta_mean_max_abs_diff_vs_cold = if (is.null(ref)) NA_real_ else max(abs(pred$beta_mean - ref$beta_mean)),
    prediction_max_abs_diff_vs_cold = if (is.null(ref)) NA_real_ else max(abs(pred$point - ref$point)),
    stringsAsFactors = FALSE
  )
}

cat("Normal DESN initialization comparison\n")
cat("repo:", repo_root, "\n")
cat("output_dir:", output_dir, "\n")
cat("seed:", seed, "\n")

src <- read_series()
y <- as.numeric(src$series$y)
if (washout >= length(y)) stop("--washout must be smaller than the selected series length.", call. = FALSE)

normal_ridge <- normal_fit("normal_scaled_ridge", y, list(
  beta_prior_type = "scaled_ridge",
  prior = list(beta_ridge_tau2 = 50, intercept_var = 1e6),
  omega_prior = list(a = 2, b = 1)
))
normal_rhs <- normal_fit("normal_rhs_ns_vb", y, list(
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
))

warm_ridge <- exdqlm::qdesn_normal_make_warm_start(normal_ridge$fit)
warm_rhs <- exdqlm::qdesn_normal_make_warm_start(normal_rhs$fit)
stopifnot(isTRUE(exdqlm::qdesn_normal_validate_warm_start(
  warm_ridge,
  X = normal_ridge$fit$X,
  meta = normal_ridge$fit$meta
)))
stopifnot(isTRUE(exdqlm::qdesn_normal_validate_warm_start(
  warm_rhs,
  X = normal_rhs$fit$X,
  meta = normal_rhs$fit$meta
)))

warm_start_summary <- data.frame(
  warm_start_id = c("normal_scaled_ridge", "normal_rhs_ns_vb"),
  normal_target = c(warm_ridge$target$label, warm_rhs$target$label),
  exact_status = c(warm_ridge$target$exact_status, warm_rhs$target$exact_status),
  prior_family = c(warm_ridge$prior$family, warm_rhs$prior$family),
  beta_dim = c(warm_ridge$beta$dim, warm_rhs$beta$dim),
  design_hash = c(warm_ridge$design$design_hash, warm_rhs$design$design_hash),
  feature_settings_hash = c(warm_ridge$qdesn$feature_settings_hash, warm_rhs$qdesn$feature_settings_hash),
  package_sha = c(warm_ridge$package$sha, warm_rhs$package$sha),
  stringsAsFactors = FALSE
)

init_al_ridge <- exdqlm::qdesn_normal_warm_start_to_vb_init(warm_ridge, likelihood_family = "al", beta_prior_type = "ridge")
init_al_rhs <- exdqlm::qdesn_normal_warm_start_to_vb_init(warm_rhs, likelihood_family = "al", beta_prior_type = "ridge")
init_exal_ridge <- exdqlm::qdesn_normal_warm_start_to_vb_init(warm_ridge, likelihood_family = "exal", beta_prior_type = "ridge")
init_exal_rhs <- exdqlm::qdesn_normal_warm_start_to_vb_init(warm_rhs, likelihood_family = "exal", beta_prior_type = "ridge")

fits <- list(
  normal_scaled_ridge = normal_ridge,
  normal_rhs_ns_vb = normal_rhs,
  al_vb_cold = vb_fit("al_vb_cold", y, "al"),
  al_vb_normal_scaled_ridge_init = vb_fit("al_vb_normal_scaled_ridge_init", y, "al", init_al_ridge),
  al_vb_normal_rhs_ns_init = vb_fit("al_vb_normal_rhs_ns_init", y, "al", init_al_rhs),
  exal_vb_cold = vb_fit("exal_vb_cold", y, "exal"),
  exal_vb_normal_scaled_ridge_init = vb_fit("exal_vb_normal_scaled_ridge_init", y, "exal", init_exal_ridge),
  exal_vb_normal_rhs_ns_init = vb_fit("exal_vb_normal_rhs_ns_init", y, "exal", init_exal_rhs)
)

init_sources <- c(
  normal_scaled_ridge = "fit",
  normal_rhs_ns_vb = "fit",
  al_vb_cold = "none",
  al_vb_normal_scaled_ridge_init = "normal_scaled_ridge",
  al_vb_normal_rhs_ns_init = "normal_rhs_ns_vb",
  exal_vb_cold = "none",
  exal_vb_normal_scaled_ridge_init = "normal_scaled_ridge",
  exal_vb_normal_rhs_ns_init = "normal_rhs_ns_vb"
)
refs <- list(
  al_vb_normal_scaled_ridge_init = fits$al_vb_cold,
  al_vb_normal_rhs_ns_init = fits$al_vb_cold,
  exal_vb_normal_scaled_ridge_init = fits$exal_vb_cold,
  exal_vb_normal_rhs_ns_init = fits$exal_vb_cold
)

if (isTRUE(run_mcmc)) {
  fits$al_mcmc_cold_tiny <- mcmc_fit("al_mcmc_cold_tiny", y)
  fits$al_mcmc_normal_scaled_ridge_init_tiny <- mcmc_fit(
    "al_mcmc_normal_scaled_ridge_init_tiny",
    y,
    exdqlm::qdesn_normal_warm_start_to_mcmc_init(warm_ridge, likelihood_family = "al", beta_prior_type = "ridge")
  )
  init_sources <- c(init_sources, al_mcmc_cold_tiny = "none", al_mcmc_normal_scaled_ridge_init_tiny = "normal_scaled_ridge")
  refs$al_mcmc_normal_scaled_ridge_init_tiny <- fits$al_mcmc_cold_tiny
}

summary <- do.call(rbind, lapply(names(fits), function(nm) {
  summary_row(fits[[nm]], init_source = init_sources[[nm]] %||% "none", reference = refs[[nm]])
}))
repo_state <- data.frame(
  repo = repo_root,
  package_head = git_value(c("rev-parse", "--short", "HEAD")),
  package_dirty = git_dirty(),
  source_kind = src$source_kind,
  source_dir = src$source_dir,
  source_hash = src$source_hash,
  seed = seed,
  D = D,
  n = n_res,
  m = m_lag,
  washout = washout,
  max_iter = max_iter,
  run_mcmc = run_mcmc,
  stringsAsFactors = FALSE
)

write_csv(repo_state, file.path(output_dir, "repo_state.csv"))
write_csv(summary, file.path(output_dir, "init_method_summary.csv"))
write_csv(warm_start_summary, file.path(output_dir, "warm_start_summary.csv"))

md <- c(
  "# Normal DESN Initialization Comparison",
  "",
  sprintf("- Package HEAD: `%s`", repo_state$package_head[[1L]]),
  sprintf("- Package dirty at run time: `%s`", repo_state$package_dirty[[1L]]),
  sprintf("- Source kind: `%s`", repo_state$source_kind[[1L]]),
  sprintf("- Source rows: `%d`", length(y)),
  sprintf("- DESN: D=%d, n=%d, m=%d, washout=%d", D, n_res, m_lag, washout),
  sprintf("- Seed: `%d`", seed),
  "",
  "## Method Summary",
  "",
  paste(utils::capture.output(print(summary[, intersect(
    c("method", "likelihood_family", "init_source", "rmse_y", "pinball_tau_0p50", "converged", "finite_state", "elapsed_sec", "beta_mean_max_abs_diff_vs_cold"),
    names(summary)
  )], row.names = FALSE)), collapse = "\n"),
  "",
  "## Warm-Start States",
  "",
  paste(utils::capture.output(print(warm_start_summary[, intersect(
    c("warm_start_id", "normal_target", "exact_status", "prior_family", "beta_dim"),
    names(warm_start_summary)
  )], row.names = FALSE)), collapse = "\n"),
  "",
  "## Interpretation",
  "",
  "Normal initialization is a workflow mechanism, not a new posterior target. This harness validates serialized Normal DESN warm-start states before converting them into AL/exAL initializers.",
  "Cold and initialized AL/exAL rows should be interpreted through convergence diagnostics, finite-state checks, and runtime behavior."
)
writeLines(md, file.path(output_dir, "normal_desn_init_comparison_summary.md"))

cat("wrote:", output_dir, "\n")
cat("all finite:", all(summary$finite_state), "\n")
if (!all(summary$finite_state)) quit(status = 1L)
