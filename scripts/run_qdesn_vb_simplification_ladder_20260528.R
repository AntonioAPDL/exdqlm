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
  file.path(repo_root, "results", "qdesn_vb_simplification_ladder_20260528")
)
seed <- as.integer(arg_value("--seed", "20260528"))
series_length <- as.integer(arg_value("--series-length", "48"))
reservoir_size <- as.integer(arg_value("--reservoir-size", "6"))
washout <- as.integer(arg_value("--washout", "6"))
max_iter <- as.integer(arg_value("--max-iter", "24"))
stochastic_max_iter <- as.integer(arg_value("--stochastic-max-iter", "48"))
exact_tolerance <- as.numeric(arg_value("--exact-tolerance", "1e-6"))
stochastic_tolerance <- as.numeric(arg_value("--stochastic-tolerance", "0.10"))

if (!is.finite(seed)) stop("--seed must be a finite integer.", call. = FALSE)
if (!is.finite(series_length) || series_length <= washout + 8L) {
  stop("--series-length must be finite and larger than washout + 8.", call. = FALSE)
}
if (!is.finite(reservoir_size) || reservoir_size < 2L) {
  stop("--reservoir-size must be a finite integer >= 2.", call. = FALSE)
}
if (!is.finite(washout) || washout < 1L) {
  stop("--washout must be a finite positive integer.", call. = FALSE)
}
if (!is.finite(max_iter) || max_iter < 5L) {
  stop("--max-iter must be a finite integer >= 5.", call. = FALSE)
}
if (!is.finite(stochastic_max_iter) || stochastic_max_iter < max_iter) {
  stop("--stochastic-max-iter must be finite and >= --max-iter.", call. = FALSE)
}
if (!is.finite(exact_tolerance) || exact_tolerance <= 0) {
  stop("--exact-tolerance must be finite and > 0.", call. = FALSE)
}
if (!is.finite(stochastic_tolerance) || stochastic_tolerance <= 0) {
  stop("--stochastic-tolerance must be finite and > 0.", call. = FALSE)
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
setwd(repo_root)

`%||%` <- function(a, b) if (is.null(a)) b else a

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("The Q-DESN VB simplification ladder requires pkgload.", call. = FALSE)
}
pkgload::load_all(repo_root, quiet = TRUE)

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, quote = TRUE)
  invisible(path)
}

git_value <- function(cmd) {
  out <- tryCatch(
    system2("git", cmd, stdout = TRUE, stderr = TRUE),
    error = function(e) NA_character_
  )
  if (!length(out)) return(NA_character_)
  out[[1L]]
}

hash_object <- function(x) {
  tf <- tempfile(fileext = ".rds")
  on.exit(unlink(tf), add = TRUE)
  saveRDS(x, tf, version = 2)
  unname(tools::md5sum(tf))
}

max_abs <- function(x) {
  x <- as.numeric(x)
  if (!length(x)) return(NA_real_)
  max(abs(x), na.rm = TRUE)
}

safe_tail <- function(x) {
  x <- as.numeric(x)
  if (!length(x)) return(NA_real_)
  tail(x, 1L)
}

summarize_numeric <- function(x, prefix) {
  x <- as.numeric(x)
  stats <- if (length(x) && any(is.finite(x))) {
    c(
      min = min(x, na.rm = TRUE),
      mean = mean(x, na.rm = TRUE),
      max = max(x, na.rm = TRUE)
    )
  } else {
    c(min = NA_real_, mean = NA_real_, max = NA_real_)
  }
  setNames(as.list(stats), paste0(prefix, "_", names(stats)))
}

pinball_loss <- function(y, mu, tau = 0.5) {
  r <- y - mu
  mean(ifelse(r >= 0, tau * r, (tau - 1) * r))
}

make_series <- function(n, seed) {
  set.seed(seed)
  t <- seq_len(n)
  signal <- 0.25 * sin(t / 4) + 0.10 * cos(t / 7) + 0.02 * (t - mean(t)) / n
  y <- signal + stats::rnorm(n, sd = 0.03)
  data.frame(t = t, y = as.numeric(y), signal = as.numeric(signal))
}

prior_specs <- function() {
  list(
    ridge = list(
      beta_prior_type = "ridge",
      beta_ridge_tau2 = 10
    ),
    rhs = list(
      beta_prior_type = "rhs",
      beta_rhs = list(
        tau0 = 0.5,
        nu = 4,
        s2 = 1,
        shrink_intercept = FALSE,
        n_inner = 1L
      )
    ),
    rhs_ns = list(
      beta_prior_type = "rhs_ns",
      beta_rhs = list(
        tau0 = 0.5,
        s2 = 1,
        shrink_intercept = FALSE,
        n_inner = 1L
      )
    )
  )
}

base_qdesn_args <- function(likelihood_family, prior_cfg, chunking = NULL,
                            iter = max_iter, stochastic = FALSE) {
  out <- c(
    list(
      likelihood_family = likelihood_family,
      al_fixed_gamma = if (identical(likelihood_family, "al")) 0 else NULL,
      max_iter = as.integer(iter),
      min_iter_elbo = 5L,
      tol = 0,
      tol_par = 0,
      n_samp_xi = 16L,
      verbose = FALSE,
      diagnostics = list(rhs_trace = TRUE)
    ),
    prior_cfg
  )
  if (!is.null(chunking)) out$chunking <- chunking
  if (isTRUE(stochastic)) out$max_iter <- as.integer(stochastic_max_iter)
  out
}

fit_qdesn <- function(label, series, likelihood_family, prior_name, prior_cfg,
                      chunking_mode, chunking = NULL, seed_fit = seed) {
  vb_args <- base_qdesn_args(
    likelihood_family = likelihood_family,
    prior_cfg = prior_cfg,
    chunking = chunking,
    iter = max_iter,
    stochastic = identical(chunking_mode, "stochastic")
  )
  tm <- system.time({
    fit <- exdqlm::qdesn_fit_vb(
      y = series$y,
      p0 = 0.5,
      D = 1L,
      n = as.integer(reservoir_size),
      n_tilde = integer(0),
      m = 1L,
      washout = as.integer(washout),
      add_bias = TRUE,
      seed = as.integer(seed_fit),
      fit_readout = TRUE,
      vb_args = vb_args
    )
  })
  list(
    label = label,
    likelihood_family = likelihood_family,
    prior_family = prior_name,
    chunking_mode = chunking_mode,
    fit = fit,
    elapsed_sec = unname(tm[["elapsed"]])
  )
}

readout_fit <- function(obj) obj$fit$fit

predictions_for_fit <- function(obj, series) {
  keep_idx <- as.integer(obj$fit$meta$keep_idx %||% seq_along(obj$fit$y_fit))
  fit <- readout_fit(obj)
  pred <- as.numeric(obj$fit$mu_hat)
  data.frame(
    method = obj$label,
    likelihood_family = obj$likelihood_family,
    prior_family = obj$prior_family,
    chunking_mode = obj$chunking_mode,
    t = series$t[keep_idx],
    row_id = keep_idx,
    y = series$y[keep_idx],
    signal = series$signal[keep_idx],
    fitted_median = pred,
    residual_y = series$y[keep_idx] - pred,
    residual_signal = series$signal[keep_idx] - pred,
    iter = as.integer(fit$iter),
    stringsAsFactors = FALSE
  )
}

prediction_metrics <- function(obj, series) {
  pred <- predictions_for_fit(obj, series)
  data.frame(
    method = obj$label,
    likelihood_family = obj$likelihood_family,
    prior_family = obj$prior_family,
    chunking_mode = obj$chunking_mode,
    target_type = if (identical(obj$chunking_mode, "stochastic")) {
      "approximate stochastic AL VB"
    } else {
      "full-data VB"
    },
    effective_rows = nrow(pred),
    pinball_y = pinball_loss(pred$y, pred$fitted_median, tau = 0.5),
    mae_y = mean(abs(pred$residual_y)),
    rmse_y = sqrt(mean(pred$residual_y^2)),
    mae_signal = mean(abs(pred$residual_signal)),
    rmse_signal = sqrt(mean(pred$residual_signal^2)),
    corr_signal = suppressWarnings(stats::cor(pred$signal, pred$fitted_median)),
    stringsAsFactors = FALSE
  )
}

rhs_metadata <- function(fit) {
  bp <- fit$beta_prior %||% list()
  hypers <- bp$hypers %||% list()
  state <- bp$state %||% list()
  misc <- fit$misc %||% list()
  data.frame(
    prior_family = as.character(bp$type %||% NA_character_),
    shrink_intercept = if (is.null(hypers$shrink_intercept)) NA else isTRUE(hypers$shrink_intercept),
    intercept_prec = as.numeric(hypers$intercept_prec %||% NA_real_),
    tau0 = as.numeric(hypers$tau0 %||% NA_real_),
    nu = as.numeric(hypers$nu %||% NA_real_),
    s2 = as.numeric(hypers$s2 %||% NA_real_),
    tau2 = as.numeric(state$tau2 %||% NA_real_),
    zeta2 = as.numeric(state$zeta2 %||% NA_real_),
    lambda2_mean = if (!is.null(state$lambda2)) mean(as.numeric(state$lambda2)) else NA_real_,
    lambda2_min = if (!is.null(state$lambda2)) min(as.numeric(state$lambda2)) else NA_real_,
    lambda2_max = if (!is.null(state$lambda2)) max(as.numeric(state$lambda2)) else NA_real_,
    rhs_trace_rows = if (is.data.frame(misc$rhs_trace)) nrow(misc$rhs_trace) else 0L,
    rhs_tau_trace_last = safe_tail(misc$rhs_tau_trace),
    stringsAsFactors = FALSE
  )
}

summarize_fit <- function(obj, series) {
  fit <- readout_fit(obj)
  misc <- fit$misc %||% list()
  chunk_cfg <- misc$chunking %||% list()
  beta_m <- as.numeric(fit$qbeta$m)
  beta_vdiag <- diag(as.matrix(fit$qbeta$V))
  qv_ev <- as.numeric(fit$qv$E_v %||% fit$qv$m)
  qv_eiv <- as.numeric(fit$qv$E_inv_v %||% fit$qv$m_inv)
  qs_es <- as.numeric(fit$qs$E_s %||% fit$qs$m)
  pred <- predictions_for_fit(obj, series)
  rhs_meta <- rhs_metadata(fit)
  cbind(
    data.frame(
      method = obj$label,
      likelihood_family = obj$likelihood_family,
      prior_family = obj$prior_family,
      batching_mode = obj$chunking_mode,
      target_type = if (isTRUE(misc$stochastic)) "approximate stochastic AL VB" else "full-data VB",
      exact_or_approximate = if (isTRUE(misc$stochastic)) "approximate" else "exact",
      seed = as.integer(seed),
      qdesn_seed = as.integer(seed),
      design_hash = hash_object(obj$fit$X),
      feature_settings_hash = hash_object(obj$fit$meta),
      converged = isTRUE(fit$converged),
      iter = as.integer(fit$iter),
      elapsed_sec = as.numeric(obj$elapsed_sec),
      effective_rows = nrow(pred),
      p = length(beta_m),
      finite_qbeta = all(is.finite(beta_m)) && all(is.finite(beta_vdiag)),
      finite_qv = all(is.finite(qv_ev)) && all(is.finite(qv_eiv)) && all(qv_ev > 0) && all(qv_eiv > 0),
      finite_qs = all(is.finite(qs_es)),
      finite_sigma_gamma = all(is.finite(as.numeric(misc$sigma_trace))) &&
        all(is.finite(as.numeric(misc$gamma_trace))) &&
        all(as.numeric(misc$sigma_trace) > 0),
      stochastic_label = isTRUE(misc$stochastic),
      stochastic_trace_rows = if (is.data.frame(misc$stochastic_trace)) nrow(misc$stochastic_trace) else 0L,
      chunking_enabled = isTRUE(chunk_cfg$enabled),
      chunking_mode_resolved = if (isTRUE(chunk_cfg$enabled)) as.character(chunk_cfg$mode) else "none",
      chunk_size = as.integer(chunk_cfg$chunk_size %||% NA_integer_),
      sigma_last = safe_tail(misc$sigma_trace),
      gamma_last = safe_tail(misc$gamma_trace),
      elbo_last = safe_tail(misc$elbo_trace),
      beta_l2 = sqrt(sum(beta_m^2)),
      beta_first = beta_m[[1L]],
      posterior_var_min = min(beta_vdiag),
      posterior_var_max = max(beta_vdiag),
      stringsAsFactors = FALSE
    ),
    rhs_meta[, setdiff(names(rhs_meta), "prior_family"), drop = FALSE],
    as.data.frame(summarize_numeric(beta_m, "beta_mean")),
    as.data.frame(summarize_numeric(beta_vdiag, "beta_var"))
  )
}

compare_exact_pair <- function(reference, exact, series, tolerance = exact_tolerance) {
  rf <- readout_fit(reference)
  ef <- readout_fit(exact)
  rp <- predictions_for_fit(reference, series)
  ep <- predictions_for_fit(exact, series)
  beta_mean_diff <- max_abs(as.numeric(rf$qbeta$m) - as.numeric(ef$qbeta$m))
  beta_cov_diff <- max_abs(as.matrix(rf$qbeta$V) - as.matrix(ef$qbeta$V))
  fitted_diff <- max_abs(rp$fitted_median - ep$fitted_median)
  sigma_trace_diff <- max_abs(as.numeric(rf$misc$sigma_trace) - as.numeric(ef$misc$sigma_trace))
  gamma_trace_diff <- max_abs(as.numeric(rf$misc$gamma_trace) - as.numeric(ef$misc$gamma_trace))
  elbo_trace_diff <- max_abs(as.numeric(rf$misc$elbo_trace) - as.numeric(ef$misc$elbo_trace))
  design_diff <- max_abs(reference$fit$X - exact$fit$X)
  gate <- max(
    beta_mean_diff, beta_cov_diff, fitted_diff, sigma_trace_diff,
    gamma_trace_diff, elbo_trace_diff, design_diff,
    na.rm = TRUE
  )
  data.frame(
    reference_method = reference$label,
    exact_chunked_method = exact$label,
    likelihood_family = reference$likelihood_family,
    prior_family = reference$prior_family,
    same_design_hash = identical(hash_object(reference$fit$X), hash_object(exact$fit$X)),
    same_convergence_status = identical(isTRUE(rf$converged), isTRUE(ef$converged)),
    reference_iter = as.integer(rf$iter),
    exact_iter = as.integer(ef$iter),
    beta_mean_max_abs_diff = beta_mean_diff,
    beta_cov_max_abs_diff = beta_cov_diff,
    fitted_median_max_abs_diff = fitted_diff,
    sigma_trace_max_abs_diff = sigma_trace_diff,
    gamma_trace_max_abs_diff = gamma_trace_diff,
    elbo_trace_max_abs_diff = elbo_trace_diff,
    qdesn_design_max_abs_diff = design_diff,
    max_gate_diff = gate,
    tolerance = tolerance,
    passed = is.finite(gate) && gate <= tolerance,
    stringsAsFactors = FALSE
  )
}

compare_stochastic <- function(reference, stochastic, repeat_fit, series,
                               tolerance = stochastic_tolerance) {
  rf <- readout_fit(reference)
  sf <- readout_fit(stochastic)
  repf <- readout_fit(repeat_fit)
  rp <- predictions_for_fit(reference, series)
  sp <- predictions_for_fit(stochastic, series)
  repp <- predictions_for_fit(repeat_fit, series)
  misc <- sf$misc %||% list()
  beta_diff <- max_abs(as.numeric(sf$qbeta$m) - as.numeric(rf$qbeta$m))
  fitted_diff <- max_abs(sp$fitted_median - rp$fitted_median)
  pinball_diff <- pinball_loss(sp$y, sp$fitted_median) - pinball_loss(rp$y, rp$fitted_median)
  data.frame(
    reference_method = reference$label,
    stochastic_method = stochastic$label,
    repeat_method = repeat_fit$label,
    likelihood_family = reference$likelihood_family,
    prior_family = reference$prior_family,
    approximate = TRUE,
    stochastic_label_present = isTRUE(misc$stochastic),
    approximate_note_present = grepl("approximate", as.character(misc$stochastic_objective_note %||% "")),
    stochastic_trace_rows = if (is.data.frame(misc$stochastic_trace)) nrow(misc$stochastic_trace) else 0L,
    max_abs_beta_diff_vs_reference = beta_diff,
    max_abs_beta_var_diff_vs_reference = max_abs(diag(as.matrix(sf$qbeta$V)) - diag(as.matrix(rf$qbeta$V))),
    max_abs_fitted_diff_vs_reference = fitted_diff,
    max_abs_beta_diff_repeat = max_abs(as.numeric(sf$qbeta$m) - as.numeric(repf$qbeta$m)),
    max_abs_fitted_diff_repeat = max_abs(sp$fitted_median - repp$fitted_median),
    pinball_diff_vs_reference = pinball_diff,
    finite_state = all(is.finite(as.numeric(sf$qbeta$m))) &&
      all(is.finite(diag(as.matrix(sf$qbeta$V)))) &&
      all(is.finite(as.numeric(sf$qv$E_v))) &&
      all(is.finite(as.numeric(sf$qv$E_inv_v))) &&
      all(as.numeric(sf$qv$E_v) > 0) &&
      all(as.numeric(sf$qv$E_inv_v) > 0) &&
      all(is.finite(as.numeric(sf$misc$sigma_trace))) &&
      all(as.numeric(sf$misc$sigma_trace) > 0),
    reproducible = max_abs(as.numeric(sf$qbeta$m) - as.numeric(repf$qbeta$m)) <= 1e-12 &&
      max_abs(sp$fitted_median - repp$fitted_median) <= 1e-12,
    fitted_tolerance = tolerance,
    pinball_tolerance = 0.02,
    passed_distance_gate = is.finite(fitted_diff) &&
      fitted_diff <= tolerance &&
      is.finite(pinball_diff) &&
      abs(pinball_diff) <= 0.02,
    stringsAsFactors = FALSE
  )
}

forbidden_stochastic_exal <- function(series, prior_name, prior_cfg) {
  stoch <- list(
    enabled = TRUE,
    mode = "stochastic",
    chunk_size = 5L,
    order = "random",
    seed = as.integer(seed),
    learning_rate = list(t0 = 5, kappa = 0.75, rho_min = 0.02),
    refresh = list(full_every = 10L, objective_every = 10L, sigma_every = 5L, rhs_every = 10L, local_every = 10L),
    diagnostics = list(trace = TRUE, store_batch_ids = TRUE, check_finite_every = 1L)
  )
  err <- tryCatch({
    fit_qdesn(
      label = paste("qdesn_exal", prior_name, "stochastic_forbidden", sep = "_"),
      series = series,
      likelihood_family = "exal",
      prior_name = prior_name,
      prior_cfg = prior_cfg,
      chunking_mode = "stochastic",
      chunking = stoch,
      seed_fit = seed
    )
    NA_character_
  }, error = function(e) conditionMessage(e))
  data.frame(
    method = paste("qdesn_exal", prior_name, "stochastic", sep = "_"),
    likelihood_family = "exal",
    prior_family = prior_name,
    batching_mode = "stochastic",
    attempted = TRUE,
    failed_early = is.character(err) &&
      grepl("supported only for likelihood_family = 'al'", err, fixed = TRUE),
    message = as.character(err),
    stringsAsFactors = FALSE
  )
}

cat("Q-DESN VB simplification ladder\n")
cat("repo:", repo_root, "\n")
cat("output_dir:", output_dir, "\n")
cat("seed:", seed, "\n")

series <- make_series(series_length, seed)
priors <- prior_specs()

exact_chunking <- list(enabled = TRUE, mode = "exact", chunk_size = 5L, order = "sequential")
stochastic_chunking <- list(
  enabled = TRUE,
  mode = "stochastic",
  chunk_size = 5L,
  order = "random",
  seed = as.integer(seed),
  learning_rate = list(t0 = 5, kappa = 0.75, rho_min = 0.02),
  refresh = list(
    full_every = 10L,
    objective_every = 10L,
    sigma_every = 5L,
    rhs_every = 10L,
    local_every = 10L
  ),
  diagnostics = list(trace = TRUE, store_batch_ids = TRUE, check_finite_every = 1L)
)

fits <- list()
repeat_fits <- list()
for (prior_name in names(priors)) {
  prior_cfg <- priors[[prior_name]]
  for (family in c("al", "exal")) {
    base_label <- paste("qdesn", family, prior_name, "unchunked", sep = "_")
    exact_label <- paste("qdesn", family, prior_name, "exact_chunked", sep = "_")
    fits[[base_label]] <- fit_qdesn(
      label = base_label,
      series = series,
      likelihood_family = family,
      prior_name = prior_name,
      prior_cfg = prior_cfg,
      chunking_mode = "none",
      seed_fit = seed
    )
    fits[[exact_label]] <- fit_qdesn(
      label = exact_label,
      series = series,
      likelihood_family = family,
      prior_name = prior_name,
      prior_cfg = prior_cfg,
      chunking_mode = "exact",
      chunking = exact_chunking,
      seed_fit = seed
    )
    if (identical(family, "al")) {
      stochastic_label <- paste("qdesn", family, prior_name, "stochastic", sep = "_")
      repeat_label <- paste(stochastic_label, "repeat", sep = "_")
      fits[[stochastic_label]] <- fit_qdesn(
        label = stochastic_label,
        series = series,
        likelihood_family = family,
        prior_name = prior_name,
        prior_cfg = prior_cfg,
        chunking_mode = "stochastic",
        chunking = stochastic_chunking,
        seed_fit = seed
      )
      repeat_fits[[stochastic_label]] <- fit_qdesn(
        label = repeat_label,
        series = series,
        likelihood_family = family,
        prior_name = prior_name,
        prior_cfg = prior_cfg,
        chunking_mode = "stochastic",
        chunking = stochastic_chunking,
        seed_fit = seed
      )
    }
  }
}

method_summary <- do.call(rbind, lapply(fits, summarize_fit, series = series))
prediction_metrics_rows <- do.call(rbind, lapply(fits, prediction_metrics, series = series))
predictions <- do.call(rbind, lapply(fits, predictions_for_fit, series = series))

exact_rows <- do.call(rbind, unlist(lapply(names(priors), function(prior_name) {
  lapply(c("al", "exal"), function(family) {
    compare_exact_pair(
      reference = fits[[paste("qdesn", family, prior_name, "unchunked", sep = "_")]],
      exact = fits[[paste("qdesn", family, prior_name, "exact_chunked", sep = "_")]],
      series = series
    )
  })
}), recursive = FALSE))

stochastic_rows <- do.call(rbind, lapply(names(priors), function(prior_name) {
  key <- paste("qdesn", "al", prior_name, "stochastic", sep = "_")
  compare_stochastic(
    reference = fits[[paste("qdesn", "al", prior_name, "unchunked", sep = "_")]],
    stochastic = fits[[key]],
    repeat_fit = repeat_fits[[key]],
    series = series
  )
}))

prior_rows <- do.call(rbind, lapply(fits, function(obj) {
  fit <- readout_fit(obj)
  meta <- rhs_metadata(fit)
  cbind(
    data.frame(
      method = obj$label,
      likelihood_family = obj$likelihood_family,
      batching_mode = obj$chunking_mode,
      stringsAsFactors = FALSE
    ),
    meta
  )
}))

forbidden_rows <- do.call(rbind, lapply(names(priors), function(prior_name) {
  forbidden_stochastic_exal(series, prior_name, priors[[prior_name]])
}))

repo_state <- data.frame(
  repo = repo_root,
  branch = git_value(c("rev-parse", "--abbrev-ref", "HEAD")),
  head = git_value(c("rev-parse", "HEAD")),
  upstream = git_value(c("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")),
  dirty = paste(git_value(c("status", "--short")), collapse = "\\n"),
  seed = as.integer(seed),
  series_length = as.integer(series_length),
  washout = as.integer(washout),
  reservoir_size = as.integer(reservoir_size),
  max_iter = as.integer(max_iter),
  stochastic_max_iter = as.integer(stochastic_max_iter),
  exact_tolerance = exact_tolerance,
  stochastic_tolerance = stochastic_tolerance,
  stringsAsFactors = FALSE
)

write_csv(repo_state, file.path(output_dir, "repo_state.csv"))
write_csv(method_summary, file.path(output_dir, "ladder_method_summary.csv"))
write_csv(exact_rows, file.path(output_dir, "exact_equivalence.csv"))
write_csv(stochastic_rows, file.path(output_dir, "stochastic_diagnostics.csv"))
write_csv(prior_rows, file.path(output_dir, "prior_diagnostics.csv"))
write_csv(forbidden_rows, file.path(output_dir, "forbidden_modes.csv"))
write_csv(prediction_metrics_rows, file.path(output_dir, "prediction_metrics.csv"))
write_csv(predictions, file.path(output_dir, "predictions_by_method.csv"))

md_path <- file.path(output_dir, "qdesn_vb_simplification_ladder_summary.md")
con <- file(md_path, open = "wt")
on.exit(close(con), add = TRUE)
w <- function(...) writeLines(paste0(...), con)
md_table <- function(df) {
  cols <- names(df)
  w("| ", paste(cols, collapse = " | "), " |")
  w("| ", paste(rep("---", length(cols)), collapse = " | "), " |")
  for (i in seq_len(nrow(df))) {
    vals <- vapply(df[i, , drop = FALSE], function(x) {
      x <- x[[1L]]
      if (is.numeric(x)) format(x, digits = 8, scientific = TRUE) else as.character(x)
    }, character(1))
    w("| ", paste(vals, collapse = " | "), " |")
  }
}

w("# Q-DESN VB Simplification Ladder")
w("")
w("Seed: `", seed, "`")
w("")
w("Package HEAD: `", repo_state$head, "`")
w("")
w("This harness uses already implemented Q-DESN VB modes only. Exact chunking is full-data equivalent; stochastic AL is approximate; stochastic exAL is expected to fail early.")
w("")
w("## Method Summary")
md_table(method_summary[, c(
  "method", "likelihood_family", "prior_family", "batching_mode",
  "target_type", "converged", "iter", "elapsed_sec", "finite_qbeta",
  "finite_qv", "finite_sigma_gamma", "design_hash"
)])
w("")
w("## Exact Equivalence")
md_table(exact_rows)
w("")
w("## Stochastic Diagnostics")
md_table(stochastic_rows)
w("")
w("## Prior Diagnostics")
md_table(prior_rows[, c(
  "method", "prior_family", "shrink_intercept", "intercept_prec",
  "tau0", "tau2", "lambda2_mean", "rhs_trace_rows"
)])
w("")
w("## Forbidden Modes")
md_table(forbidden_rows)
w("")
w("## Prediction Metrics")
md_table(prediction_metrics_rows)

cat("Wrote:\n")
for (path in c(
  "repo_state.csv",
  "ladder_method_summary.csv",
  "exact_equivalence.csv",
  "stochastic_diagnostics.csv",
  "prior_diagnostics.csv",
  "forbidden_modes.csv",
  "prediction_metrics.csv",
  "predictions_by_method.csv",
  "qdesn_vb_simplification_ladder_summary.md"
)) {
  cat(" -", file.path(output_dir, path), "\n")
}

if (!all(method_summary$finite_qbeta) ||
    !all(method_summary$finite_qv) ||
    !all(method_summary$finite_sigma_gamma)) {
  stop("At least one ladder rung produced a non-finite variational state.", call. = FALSE)
}
if (!all(exact_rows$passed)) {
  stop("At least one exact chunked equivalence gate failed.", call. = FALSE)
}
if (!all(stochastic_rows$stochastic_label_present) ||
    !all(stochastic_rows$approximate_note_present) ||
    !all(stochastic_rows$finite_state) ||
    !all(stochastic_rows$reproducible) ||
    !all(stochastic_rows$passed_distance_gate)) {
  stop("At least one stochastic AL diagnostic gate failed.", call. = FALSE)
}
if (!all(forbidden_rows$failed_early)) {
  stop("At least one stochastic exAL forbidden-mode check did not fail early.", call. = FALSE)
}

cat("All simplification ladder gates passed.\n")
