#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(flag, default = NULL) {
  hit <- which(args == flag)
  if (!length(hit) || hit[[1L]] >= length(args)) return(default)
  args[[hit[[1L]] + 1L]]
}

repo_root <- normalizePath(arg_value("--repo", getwd()), mustWork = TRUE)
output_dir <- arg_value(
  "--output-dir",
  file.path(repo_root, "results", "qdesn_vb_posterior_as_prior_gate_20260528")
)
seed <- as.integer(arg_value("--seed", "20260528"))
series_length <- as.integer(arg_value("--series-length", "36"))
window_size <- as.integer(arg_value("--window-size", "18"))
max_iter <- as.integer(arg_value("--max-iter", "8"))
chunk_size <- as.integer(arg_value("--chunk-size", "5"))

if (!is.finite(seed)) stop("--seed must be a finite integer.", call. = FALSE)
if (!is.finite(series_length) || series_length < 30L) {
  stop("--series-length must be a finite integer >= 30.", call. = FALSE)
}
if (!is.finite(window_size) || window_size < 12L || window_size >= series_length) {
  stop("--window-size must be finite, >= 12, and smaller than --series-length.", call. = FALSE)
}
if (!is.finite(max_iter) || max_iter < 4L) {
  stop("--max-iter must be a finite integer >= 4.", call. = FALSE)
}
if (!is.finite(chunk_size) || chunk_size < 1L) {
  stop("--chunk-size must be a finite positive integer.", call. = FALSE)
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
setwd(repo_root)

`%||%` <- function(a, b) if (is.null(a)) b else a

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("The posterior-as-prior gate requires pkgload.", call. = FALSE)
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

pinball_loss <- function(y, mu, tau = 0.5) {
  r <- y - mu
  mean(ifelse(r >= 0, tau * r, (tau - 1) * r))
}

make_series <- function(n, seed) {
  set.seed(seed)
  t <- seq_len(n)
  signal <- 0.20 * sin(t / 4) + 0.08 * cos(t / 7) + 0.003 * t
  y <- signal + stats::rnorm(n, sd = 0.04)
  data.frame(t = t, y = as.numeric(y), signal = as.numeric(signal))
}

prediction_metrics_one <- function(fit_obj, method, origin) {
  y <- as.numeric(fit_obj$y_fit)
  mu <- as.numeric(fit_obj$mu_hat)
  data.frame(
    method = method,
    origin = as.integer(origin),
    effective_rows = as.integer(length(y)),
    mae_y = mean(abs(y - mu)),
    rmse_y = sqrt(mean((y - mu)^2)),
    pinball_y = pinball_loss(y, mu, tau = 0.5),
    finite_predictions = all(is.finite(mu)),
    stringsAsFactors = FALSE
  )
}

run_forbidden <- function(label, expr, pattern) {
  msg <- NA_character_
  ok <- FALSE
  tryCatch(
    {
      force(expr)
      msg <<- "unexpected success"
    },
    error = function(e) {
      msg <<- conditionMessage(e)
      ok <<- grepl(pattern, msg, fixed = TRUE)
    }
  )
  data.frame(
    mode = label,
    expected_fail = TRUE,
    failed_early = ok,
    message = msg,
    stringsAsFactors = FALSE
  )
}

dat <- make_series(series_length, seed)
origins <- as.integer(c(series_length - 12L, series_length - 6L, series_length))

desn_args <- list(
  D = 1L,
  n = 4L,
  m = 1L,
  washout = 3L,
  add_bias = TRUE,
  seed = seed + 101L
)
vb_args <- list(
  likelihood_family = "al",
  al_fixed_gamma = 0,
  beta_prior_type = "ridge",
  beta_ridge_tau2 = 10,
  max_iter = max_iter,
  min_iter_elbo = 2L,
  tol = 0,
  tol_par = 0,
  n_samp_xi = 16L,
  verbose = FALSE
)
exact_vb_args <- vb_args
exact_vb_args$chunking <- list(enabled = TRUE, mode = "exact", chunk_size = chunk_size)

repo_state <- data.frame(
  repo = repo_root,
  branch = git_value(c("branch", "--show-current")),
  head = git_value(c("rev-parse", "HEAD")),
  upstream = git_value(c("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")),
  status_short = paste(git_value(c("status", "--short")), collapse = "\n"),
  stringsAsFactors = FALSE
)
write_csv(repo_state, file.path(output_dir, "repo_state.csv"))

elapsed <- list()

t0 <- proc.time()[["elapsed"]]
independent <- qdesn_vb_fit_rolling(
  y = dat$y,
  p0 = 0.5,
  origins = origins,
  window_size = window_size,
  desn_args = desn_args,
  vb_args = vb_args,
  keep_fits = TRUE
)
elapsed$independent <- proc.time()[["elapsed"]] - t0

t0 <- proc.time()[["elapsed"]]
pap <- qdesn_vb_fit_rolling(
  y = dat$y,
  p0 = 0.5,
  origins = origins,
  window_size = window_size,
  desn_args = desn_args,
  vb_args = vb_args,
  posterior_as_prior = list(enabled = TRUE, mode = "gaussian_beta"),
  keep_fits = TRUE
)
elapsed$posterior_as_prior <- proc.time()[["elapsed"]] - t0

t0 <- proc.time()[["elapsed"]]
pap_exact <- qdesn_vb_fit_rolling(
  y = dat$y,
  p0 = 0.5,
  origins = origins,
  window_size = window_size,
  desn_args = desn_args,
  vb_args = exact_vb_args,
  posterior_as_prior = list(enabled = TRUE, mode = "gaussian_beta"),
  keep_fits = TRUE
)
elapsed$posterior_as_prior_exact <- proc.time()[["elapsed"]] - t0

method_summary <- rbind(
  transform(independent$summary, method = "independent_rolling_al_ridge"),
  transform(pap$summary, method = "posterior_as_prior_al_ridge"),
  transform(pap_exact$summary, method = "posterior_as_prior_al_ridge_exact_chunked")
)
elapsed_map <- c(
  independent_rolling_al_ridge = elapsed$independent,
  posterior_as_prior_al_ridge = elapsed$posterior_as_prior,
  posterior_as_prior_al_ridge_exact_chunked = elapsed$posterior_as_prior_exact
)
method_summary$elapsed_sec <- unname(elapsed_map[method_summary$method])
write_csv(method_summary, file.path(output_dir, "rolling_method_summary.csv"))

write_csv(independent$windows, file.path(output_dir, "window_metadata.csv"))
write_csv(pap$state_handoffs, file.path(output_dir, "state_handoff_checks.csv"))
write_csv(pap$summary, file.path(output_dir, "posterior_as_prior_summary.csv"))

prediction_metrics <- do.call(rbind, c(
  Map(prediction_metrics_one, independent$fits, "independent_rolling_al_ridge", independent$origins),
  Map(prediction_metrics_one, pap$fits, "posterior_as_prior_al_ridge", pap$origins),
  Map(prediction_metrics_one, pap_exact$fits, "posterior_as_prior_al_ridge_exact_chunked", pap_exact$origins)
))
write_csv(prediction_metrics, file.path(output_dir, "prediction_metrics.csv"))

exact_equivalence <- data.frame(
  origin = origins,
  max_abs_beta_mean = vapply(seq_along(origins), function(i) {
    max(abs(pap_exact$fits[[i]]$fit$qbeta$m - pap$fits[[i]]$fit$qbeta$m))
  }, numeric(1)),
  max_abs_beta_cov = vapply(seq_along(origins), function(i) {
    max(abs(pap_exact$fits[[i]]$fit$qbeta$V - pap$fits[[i]]$fit$qbeta$V))
  }, numeric(1)),
  max_abs_prediction = vapply(seq_along(origins), function(i) {
    max(abs(pap_exact$fits[[i]]$mu_hat - pap$fits[[i]]$mu_hat))
  }, numeric(1)),
  stringsAsFactors = FALSE
)
write_csv(exact_equivalence, file.path(output_dir, "exact_equivalence.csv"))

forbidden <- rbind(
  run_forbidden(
    "posterior_as_prior_exal",
    qdesn_vb_fit_rolling(
      y = dat$y, p0 = 0.5, origins = origins[1L], window_size = window_size,
      desn_args = desn_args,
      vb_args = modifyList(vb_args, list(likelihood_family = "exal", al_fixed_gamma = NULL)),
      posterior_as_prior = TRUE
    ),
    "likelihood_family = 'al' only"
  ),
  run_forbidden(
    "posterior_as_prior_rhs_ns",
    qdesn_vb_fit_rolling(
      y = dat$y, p0 = 0.5, origins = origins[1L], window_size = window_size,
      desn_args = desn_args,
      vb_args = modifyList(vb_args, list(beta_prior_type = "rhs_ns")),
      posterior_as_prior = TRUE
    ),
    "beta_prior_type = 'ridge' only"
  ),
  run_forbidden(
    "posterior_as_prior_stochastic",
    qdesn_vb_fit_rolling(
      y = dat$y, p0 = 0.5, origins = origins[1L], window_size = window_size,
      desn_args = desn_args,
      vb_args = modifyList(vb_args, list(chunking = list(enabled = TRUE, mode = "stochastic", chunk_size = 5L))),
      posterior_as_prior = TRUE
    ),
    "unchunked or exact chunked"
  )
)
write_csv(forbidden, file.path(output_dir, "forbidden_modes.csv"))

timing <- data.frame(
  method = names(elapsed),
  elapsed_sec = as.numeric(elapsed),
  stringsAsFactors = FALSE
)
write_csv(timing, file.path(output_dir, "timing.csv"))

summary_md <- c(
  "# Q-DESN VB Posterior-as-Prior Gate",
  "",
  sprintf("- repo: `%s`", repo_root),
  sprintf("- HEAD: `%s`", repo_state$head),
  sprintf("- seed: `%d`", seed),
  sprintf("- series_length: `%d`", series_length),
  sprintf("- window_size: `%d`", window_size),
  sprintf("- origins: `%s`", paste(origins, collapse = ", ")),
  sprintf("- max_iter: `%d`", max_iter),
  "",
  "## Results",
  "",
  sprintf("- posterior-as-prior handoffs: `%d` rows", nrow(pap$state_handoffs)),
  sprintf("- max exact beta-mean difference: `%.3e`", max(exact_equivalence$max_abs_beta_mean)),
  sprintf("- max exact prediction difference: `%.3e`", max(exact_equivalence$max_abs_prediction)),
  sprintf("- forbidden modes failed early: `%s`", all(forbidden$failed_early)),
  "",
  "Posterior-as-prior is a target-changing workflow: each origin uses the previous origin's beta posterior as the next Gaussian beta prior."
)
writeLines(summary_md, file.path(output_dir, "qdesn_vb_posterior_as_prior_gate_summary.md"))

cat(sprintf("Wrote posterior-as-prior gate outputs to %s\n", output_dir))
