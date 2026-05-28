#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(flag, default = NULL) {
  hit <- which(args == flag)
  if (!length(hit) || hit[[1L]] >= length(args)) return(default)
  args[[hit[[1L]] + 1L]]
}

arg_int <- function(flag, default) {
  value <- as.integer(arg_value(flag, as.character(default)))
  if (!is.finite(value)) stop(sprintf("%s must be a finite integer.", flag), call. = FALSE)
  value
}

repo_root <- normalizePath(getwd(), mustWork = TRUE)
source_dir <- normalizePath(
  arg_value(
    "--source-dir",
    "/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast/normal/tau_0p50/fit_input_lastTT500"
  ),
  mustWork = TRUE
)
output_dir <- arg_value(
  "--output-dir",
  file.path(repo_root, "results", "qdesn_vb_batching_source_tt500_median_20260528")
)
output_prefix <- arg_value("--output-prefix", "qdesn_vb_batching_source_tt500_median")
seed <- as.integer(arg_value("--seed", "20260528"))
if (!is.finite(seed)) stop("--seed must be a finite integer.", call. = FALSE)

tail_rows <- arg_int("--tail-rows", 0L)
expected_effective_rows <- arg_int("--expected-effective-rows", 0L)
qdesn_D <- arg_int("--D", 1L)
qdesn_n <- arg_int("--n", 50L)
qdesn_m <- arg_int("--m", 1L)
qdesn_washout <- arg_int("--washout", 50L)
chunk_size <- arg_int("--chunk-size", 64L)
max_iter <- arg_int("--max-iter", 50L)
stochastic_max_iter <- arg_int("--stochastic-max-iter", 100L)
hybrid_max_iter <- arg_int("--hybrid-max-iter", stochastic_max_iter)
hybrid_full_every <- arg_int("--hybrid-full-every", 20L)
cores <- arg_int("--cores", 1L)
exact_tolerance <- as.numeric(arg_value("--exact-tolerance", "1e-7"))

if (qdesn_D != 1L) {
  stop("This source comparison script currently supports D = 1 only; use --n for the reservoir size.", call. = FALSE)
}
if (qdesn_n < 1L) stop("--n must be positive.", call. = FALSE)
if (qdesn_m < 0L) stop("--m must be non-negative.", call. = FALSE)
if (qdesn_washout < 0L) stop("--washout must be non-negative.", call. = FALSE)
if (chunk_size < 1L) stop("--chunk-size must be positive.", call. = FALSE)
if (max_iter < 1L || stochastic_max_iter < 1L || hybrid_max_iter < 1L) {
  stop("max iteration controls must be positive.", call. = FALSE)
}
if (hybrid_full_every < 1L) stop("--hybrid-full-every must be positive.", call. = FALSE)
if (cores < 1L) stop("--cores must be positive.", call. = FALSE)
if (!is.finite(exact_tolerance) || exact_tolerance <= 0) {
  stop("--exact-tolerance must be a positive finite number.", call. = FALSE)
}
if (cores > 1L && !identical(.Platform$OS.type, "unix")) {
  stop("--cores > 1 requires a Unix-like platform for parallel::mclapply().", call. = FALSE)
}

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

`%||%` <- function(a, b) if (is.null(a)) b else a

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("The source TT500 comparison requires pkgload.", call. = FALSE)
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

num_summary <- function(x) {
  x <- as.numeric(x)
  c(
    min = min(x),
    q1 = unname(stats::quantile(x, 0.25)),
    median = stats::median(x),
    mean = mean(x),
    q3 = unname(stats::quantile(x, 0.75)),
    max = max(x),
    sd = stats::sd(x)
  )
}

as_summary_df <- function(name, x) {
  s <- num_summary(x)
  data.frame(
    variable = name,
    min = s[["min"]],
    q1 = s[["q1"]],
    median = s[["median"]],
    mean = s[["mean"]],
    q3 = s[["q3"]],
    max = s[["max"]],
    sd = s[["sd"]],
    stringsAsFactors = FALSE
  )
}

max_abs <- function(x) {
  x <- as.numeric(x)
  if (!length(x)) return(NA_real_)
  max(abs(x), na.rm = TRUE)
}

pinball_loss <- function(y, q, tau = 0.5) {
  u <- as.numeric(y) - as.numeric(q)
  mean((tau - as.numeric(u < 0)) * u)
}

rmse <- function(x) sqrt(mean(as.numeric(x)^2))

fit_qdesn <- function(label, y, vb_args, qdesn_seed) {
  cat("Fitting", label, "\n")
  tm <- system.time({
    fit <- exdqlm::qdesn_fit_vb(
      y = y,
      p0 = 0.5,
      D = qdesn_D,
      n = qdesn_n,
      n_tilde = integer(0),
      m = qdesn_m,
      washout = qdesn_washout,
      add_bias = TRUE,
      seed = qdesn_seed,
      vb_args = vb_args
    )
  })
  cat("Finished", label, "elapsed_sec=", unname(tm[["elapsed"]]), "\n")
  list(label = label, fit = fit, elapsed_sec = unname(tm[["elapsed"]]))
}

extract_readout_fit <- function(obj) obj$fit$fit

fitted_values <- function(obj) {
  as.numeric(obj$fit$mu_hat)
}

fit_keep_idx <- function(obj) {
  as.integer(obj$fit$meta$keep_idx)
}

finite_fit_state <- function(fit) {
  all(is.finite(as.numeric(fit$qbeta$m))) &&
    all(is.finite(as.matrix(fit$qbeta$V))) &&
    all(is.finite(as.numeric(fit$qv$E_v))) &&
    all(is.finite(as.numeric(fit$qv$E_inv_v))) &&
    all(is.finite(as.numeric(fit$misc$sigma_trace %||% NA_real_))) &&
    all(is.finite(as.numeric(fit$misc$gamma_trace %||% NA_real_)))
}

method_summary_row <- function(obj, series, q_target) {
  fit <- extract_readout_fit(obj)
  qbeta_m <- as.numeric(fit$qbeta$m)
  qbeta_vdiag <- diag(as.matrix(fit$qbeta$V))
  misc <- fit$misc %||% list()
  chunk_cfg <- misc$chunking %||% list()
  chunking_mode <- if (isTRUE(chunk_cfg$enabled)) as.character(chunk_cfg$mode %||% "unknown") else "none"
  pred <- fitted_values(obj)
  idx <- fit_keep_idx(obj)
  y_eval <- series$y[idx]
  q_eval <- q_target[idx]

  data.frame(
    label = obj$label,
    likelihood_family = as.character(fit$likelihood_family),
    chunking_mode = chunking_mode,
    stochastic = isTRUE(misc$stochastic),
    approximate = isTRUE(misc$stochastic),
    converged = isTRUE(fit$converged),
    iter = as.integer(fit$iter),
    elapsed_sec = as.numeric(obj$elapsed_sec),
    effective_rows = length(idx),
    readout_p = length(qbeta_m),
    beta_mean_min = min(qbeta_m),
    beta_mean_median = stats::median(qbeta_m),
    beta_mean_mean = mean(qbeta_m),
    beta_mean_max = max(qbeta_m),
    beta_cov_diag_min = min(qbeta_vdiag),
    beta_cov_diag_median = stats::median(qbeta_vdiag),
    beta_cov_diag_max = max(qbeta_vdiag),
    sigma_tail = tail(as.numeric(misc$sigma_trace %||% NA_real_), 1L),
    gamma_tail = tail(as.numeric(misc$gamma_trace %||% NA_real_), 1L),
    finite_state = finite_fit_state(fit),
    pinball_y = pinball_loss(y_eval, pred, tau = 0.5),
    mae_y = mean(abs(y_eval - pred)),
    rmse_y = rmse(y_eval - pred),
    mae_q_target = mean(abs(q_eval - pred)),
    rmse_q_target = rmse(q_eval - pred),
    cor_q_target = as.numeric(stats::cor(q_eval, pred)),
    stringsAsFactors = FALSE
  )
}

prediction_rows <- function(obj, series, q_target) {
  idx <- fit_keep_idx(obj)
  data.frame(
    label = obj$label,
    row_index = seq_along(idx),
    source_t = series$t[idx],
    y = series$y[idx],
    mu = series$mu[idx],
    q_target = q_target[idx],
    fitted_median = fitted_values(obj),
    stringsAsFactors = FALSE
  )
}

exact_compare <- function(left, right, series, tolerance = 1e-7) {
  lf <- extract_readout_fit(left)
  rf <- extract_readout_fit(right)
  beta_mean_diff <- max_abs(as.numeric(lf$qbeta$m) - as.numeric(rf$qbeta$m))
  beta_cov_diff <- max_abs(as.matrix(lf$qbeta$V) - as.matrix(rf$qbeta$V))
  fitted_diff <- max_abs(fitted_values(left) - fitted_values(right))
  sigma_trace_diff <- max_abs(as.numeric(lf$misc$sigma_trace) - as.numeric(rf$misc$sigma_trace))
  gamma_trace_diff <- max_abs(as.numeric(lf$misc$gamma_trace) - as.numeric(rf$misc$gamma_trace))
  elbo_trace_diff <- max_abs(as.numeric(lf$misc$elbo_trace) - as.numeric(rf$misc$elbo_trace))
  design_diff <- max_abs(left$fit$X - right$fit$X)
  gate_diff <- max(
    beta_mean_diff, beta_cov_diff, fitted_diff, sigma_trace_diff,
    gamma_trace_diff, elbo_trace_diff, design_diff,
    na.rm = TRUE
  )
  data.frame(
    left_label = left$label,
    right_label = right$label,
    same_keep_idx = identical(fit_keep_idx(left), fit_keep_idx(right)),
    same_design = is.finite(design_diff) && design_diff == 0,
    same_convergence_status = identical(isTRUE(lf$converged), isTRUE(rf$converged)),
    left_iter = as.integer(lf$iter),
    right_iter = as.integer(rf$iter),
    beta_mean_max_abs_diff = beta_mean_diff,
    beta_cov_max_abs_diff = beta_cov_diff,
    fitted_median_max_abs_diff = fitted_diff,
    sigma_trace_max_abs_diff = sigma_trace_diff,
    gamma_trace_max_abs_diff = gamma_trace_diff,
    elbo_trace_max_abs_diff = elbo_trace_diff,
    qdesn_design_max_abs_diff = design_diff,
    max_gate_diff = gate_diff,
    tolerance = tolerance,
    passed = is.finite(gate_diff) && gate_diff <= tolerance,
    stringsAsFactors = FALSE
  )
}

stochastic_compare <- function(reference, stochastic, stochastic_repeat, series) {
  rf <- extract_readout_fit(reference)
  sf <- extract_readout_fit(stochastic)
  sf2 <- extract_readout_fit(stochastic_repeat)
  ref_pred <- fitted_values(reference)
  stoch_pred <- fitted_values(stochastic)
  stoch_pred2 <- fitted_values(stochastic_repeat)

  data.frame(
    reference_label = reference$label,
    stochastic_label = stochastic$label,
    repeat_label = stochastic_repeat$label,
    stochastic_label_present = isTRUE(sf$misc$stochastic),
    approximate_note_present = grepl("approximate", as.character(sf$misc$stochastic_objective_note %||% "")),
    stochastic_trace_rows = if (is.data.frame(sf$misc$stochastic_trace)) nrow(sf$misc$stochastic_trace) else 0L,
    finite_state = finite_fit_state(sf),
    reproducible_beta_mean_max_abs_diff = max_abs(as.numeric(sf$qbeta$m) - as.numeric(sf2$qbeta$m)),
    reproducible_fitted_median_max_abs_diff = max_abs(stoch_pred - stoch_pred2),
    beta_mean_max_abs_diff_vs_unchunked = max_abs(as.numeric(sf$qbeta$m) - as.numeric(rf$qbeta$m)),
    fitted_median_max_abs_diff_vs_unchunked = max_abs(stoch_pred - ref_pred),
    pinball_diff_vs_unchunked = pinball_loss(series$y[fit_keep_idx(stochastic)], stoch_pred, 0.5) -
      pinball_loss(series$y[fit_keep_idx(reference)], ref_pred, 0.5),
    mae_y_diff_vs_unchunked = mean(abs(series$y[fit_keep_idx(stochastic)] - stoch_pred)) -
      mean(abs(series$y[fit_keep_idx(reference)] - ref_pred)),
    rmse_y_diff_vs_unchunked = rmse(series$y[fit_keep_idx(stochastic)] - stoch_pred) -
      rmse(series$y[fit_keep_idx(reference)] - ref_pred),
    stringsAsFactors = FALSE
  )
}

series_path <- file.path(source_dir, "series_wide.csv")
selection_path <- file.path(source_dir, "selection_indices.csv")
series_raw <- utils::read.csv(series_path)
selection_raw <- utils::read.csv(selection_path)

required_cols <- c("t", "y", "mu", "q_target", "eps")
if (!identical(names(series_raw), required_cols)) {
  stop("series_wide.csv must have columns: t,y,mu,q_target,eps.", call. = FALSE)
}
if (nrow(selection_raw) != nrow(series_raw) ||
    !all(c("t", "source_index") %in% names(selection_raw))) {
  stop("selection_indices.csv must align with series_wide.csv and include t,source_index.", call. = FALSE)
}
if (tail_rows > 0L) {
  if (tail_rows > nrow(series_raw)) {
    stop("--tail-rows cannot exceed the number of available source rows.", call. = FALSE)
  }
  keep_raw <- seq.int(nrow(series_raw) - tail_rows + 1L, nrow(series_raw))
  series <- series_raw[keep_raw, , drop = FALSE]
  selection <- selection_raw[keep_raw, , drop = FALSE]
} else {
  series <- series_raw
  selection <- selection_raw
}
if (max(abs(series$mu - series$q_target)) != 0) {
  stop("q_target must equal mu exactly for the median diagnostic target.", call. = FALSE)
}
if (anyNA(series[c("y", "mu", "q_target")])) {
  stop("series_wide.csv contains missing y, mu, or q_target values.", call. = FALSE)
}
if (qdesn_washout >= nrow(series)) {
  stop("--washout must be smaller than the selected number of source rows.", call. = FALSE)
}

effective_rows_expected <- nrow(series) - max(qdesn_m, qdesn_washout)
if (expected_effective_rows > 0L && effective_rows_expected != expected_effective_rows) {
  stop(sprintf(
    "Selected rows and washout imply %d effective rows, not requested %d.",
    effective_rows_expected,
    expected_effective_rows
  ), call. = FALSE)
}

dataset_summary <- rbind(
  data.frame(
    variable = "metadata",
    min = NA_real_,
    q1 = NA_real_,
    median = NA_real_,
    mean = NA_real_,
    q3 = NA_real_,
    max = NA_real_,
    sd = NA_real_,
    n_rows = nrow(series),
    raw_n_rows = nrow(series_raw),
    tail_rows = if (tail_rows > 0L) tail_rows else NA_integer_,
    washout = qdesn_washout,
    effective_rows_expected = effective_rows_expected,
    source_index_min = min(selection$source_index),
    source_index_max = max(selection$source_index),
    eval_source_index_min = min(selection$source_index[seq.int(max(qdesn_m, qdesn_washout) + 1L, nrow(selection))]),
    eval_source_index_max = max(selection$source_index[seq.int(max(qdesn_m, qdesn_washout) + 1L, nrow(selection))]),
    max_abs_mu_q_target = max(abs(series$mu - series$q_target)),
    missing_y = sum(is.na(series$y)),
    missing_mu = sum(is.na(series$mu)),
    missing_q_target = sum(is.na(series$q_target)),
    stringsAsFactors = FALSE
  ),
  transform(as_summary_df("y", series$y), n_rows = nrow(series), raw_n_rows = nrow(series_raw), tail_rows = if (tail_rows > 0L) tail_rows else NA_integer_,
            washout = qdesn_washout, effective_rows_expected = effective_rows_expected, source_index_min = NA_integer_, source_index_max = NA_integer_,
            eval_source_index_min = NA_integer_, eval_source_index_max = NA_integer_,
            max_abs_mu_q_target = NA_real_, missing_y = NA_integer_, missing_mu = NA_integer_, missing_q_target = NA_integer_),
  transform(as_summary_df("mu", series$mu), n_rows = nrow(series), raw_n_rows = nrow(series_raw), tail_rows = if (tail_rows > 0L) tail_rows else NA_integer_,
            washout = qdesn_washout, effective_rows_expected = effective_rows_expected, source_index_min = NA_integer_, source_index_max = NA_integer_,
            eval_source_index_min = NA_integer_, eval_source_index_max = NA_integer_,
            max_abs_mu_q_target = NA_real_, missing_y = NA_integer_, missing_mu = NA_integer_, missing_q_target = NA_integer_),
  transform(as_summary_df("q_target", series$q_target), n_rows = nrow(series), raw_n_rows = nrow(series_raw), tail_rows = if (tail_rows > 0L) tail_rows else NA_integer_,
            washout = qdesn_washout, effective_rows_expected = effective_rows_expected, source_index_min = NA_integer_, source_index_max = NA_integer_,
            eval_source_index_min = NA_integer_, eval_source_index_max = NA_integer_,
            max_abs_mu_q_target = NA_real_, missing_y = NA_integer_, missing_mu = NA_integer_, missing_q_target = NA_integer_),
  transform(as_summary_df("eps", series$eps), n_rows = nrow(series), raw_n_rows = nrow(series_raw), tail_rows = if (tail_rows > 0L) tail_rows else NA_integer_,
            washout = qdesn_washout, effective_rows_expected = effective_rows_expected, source_index_min = NA_integer_, source_index_max = NA_integer_,
            eval_source_index_min = NA_integer_, eval_source_index_max = NA_integer_,
            max_abs_mu_q_target = NA_real_, missing_y = NA_integer_, missing_mu = NA_integer_, missing_q_target = NA_integer_)
)

qdesn_seed <- seed + 100L
base_vb <- list(
  likelihood_family = "al",
  al_fixed_gamma = 0,
  max_iter = max_iter,
  min_iter_elbo = 10L,
  tol = 0,
  tol_par = 0,
  n_samp_xi = 32L,
  verbose = FALSE,
  beta_prior_type = "ridge",
  beta_ridge_tau2 = 50
)
exact_vb <- utils::modifyList(base_vb, list(
  chunking = list(
    enabled = TRUE,
    mode = "exact",
    chunk_size = chunk_size,
    order = "sequential"
  )
))
stochastic_chunking <- list(
  enabled = TRUE,
  mode = "stochastic",
  chunk_size = chunk_size,
  order = "random",
  seed = seed,
  learning_rate = list(t0 = 10, kappa = 0.75, rho_min = 0.02),
  refresh = list(
    full_every = 20L,
    objective_every = 20L,
    sigma_every = 5L,
    rhs_every = 20L,
    local_every = 20L
  ),
  diagnostics = list(
    trace = TRUE,
    store_batch_ids = TRUE,
    check_finite_every = 1L
  )
)
stoch_vb <- utils::modifyList(base_vb, list(max_iter = stochastic_max_iter, chunking = stochastic_chunking))
hybrid_chunking <- stochastic_chunking
hybrid_chunking$mode <- "hybrid"
hybrid_chunking$refresh$full_every <- hybrid_full_every
hybrid_chunking$refresh$objective_every <- hybrid_full_every
hybrid_chunking$refresh$sigma_every <- hybrid_full_every
hybrid_chunking$refresh$rhs_every <- hybrid_full_every
hybrid_chunking$refresh$local_every <- hybrid_full_every
hybrid_vb <- utils::modifyList(base_vb, list(max_iter = hybrid_max_iter, chunking = hybrid_chunking))
exal_vb <- base_vb
exal_vb$likelihood_family <- "exal"
exal_vb$al_fixed_gamma <- NULL
exal_exact_vb <- utils::modifyList(exal_vb, list(
  chunking = list(
    enabled = TRUE,
    mode = "exact",
    chunk_size = chunk_size,
    order = "sequential"
  )
))

cat("Source Q-DESN VB batching comparison\n")
cat("source_dir:", source_dir, "\n")
cat("output_dir:", output_dir, "\n")
cat("seed:", seed, "\n")
cat("qdesn_seed:", qdesn_seed, "\n")
cat("selected_rows:", nrow(series), "\n")
cat("effective_rows:", effective_rows_expected, "\n")
cat("D:", qdesn_D, "n:", qdesn_n, "washout:", qdesn_washout, "chunk_size:", chunk_size, "cores:", cores, "\n")
cat("hybrid_full_every:", hybrid_full_every, "\n")

fit_specs <- list(
  list(label = "qdesn_al_unchunked", vb_args = base_vb),
  list(label = "qdesn_al_exact_chunked", vb_args = exact_vb),
  list(label = "qdesn_al_stochastic", vb_args = stoch_vb),
  list(label = "qdesn_al_stochastic_repeat", vb_args = stoch_vb),
  list(label = "qdesn_al_hybrid", vb_args = hybrid_vb),
  list(label = "qdesn_al_hybrid_repeat", vb_args = hybrid_vb),
  list(label = "qdesn_exal_unchunked", vb_args = exal_vb),
  list(label = "qdesn_exal_exact_chunked", vb_args = exal_exact_vb)
)
fit_one_spec <- function(spec) fit_qdesn(spec$label, series$y, spec$vb_args, qdesn_seed)
if (cores > 1L) {
  fits <- parallel::mclapply(
    fit_specs,
    fit_one_spec,
    mc.cores = min(cores, length(fit_specs)),
    mc.preschedule = FALSE,
    mc.set.seed = FALSE
  )
} else {
  fits <- lapply(fit_specs, fit_one_spec)
}
names(fits) <- vapply(fits, `[[`, character(1), "label")

bad_exal_stochastic <- exal_vb
bad_exal_stochastic$chunking <- stochastic_chunking
forbidden_stochastic_message <- tryCatch({
  fit_qdesn("qdesn_exal_stochastic_forbidden", series$y, bad_exal_stochastic, qdesn_seed)
  NA_character_
}, error = function(e) conditionMessage(e))
bad_exal_hybrid <- exal_vb
bad_exal_hybrid$chunking <- hybrid_chunking
forbidden_hybrid_message <- tryCatch({
  fit_qdesn("qdesn_exal_hybrid_forbidden", series$y, bad_exal_hybrid, qdesn_seed)
  NA_character_
}, error = function(e) conditionMessage(e))

method_summary <- do.call(rbind, lapply(
  fits[c(
    "qdesn_al_unchunked",
    "qdesn_al_exact_chunked",
    "qdesn_al_stochastic",
    "qdesn_al_hybrid",
    "qdesn_exal_unchunked",
    "qdesn_exal_exact_chunked"
  )],
  method_summary_row,
  series = series,
  q_target = series$q_target
))

prediction_metrics <- method_summary[, c(
  "label", "likelihood_family", "chunking_mode", "stochastic",
  "pinball_y", "mae_y", "rmse_y", "mae_q_target", "rmse_q_target",
  "cor_q_target"
)]

predictions <- do.call(rbind, lapply(
  fits[c(
    "qdesn_al_unchunked",
    "qdesn_al_exact_chunked",
    "qdesn_al_stochastic",
    "qdesn_al_hybrid",
    "qdesn_exal_unchunked",
    "qdesn_exal_exact_chunked"
  )],
  prediction_rows,
  series = series,
  q_target = series$q_target
))

exact_equivalence <- rbind(
  exact_compare(fits$qdesn_al_unchunked, fits$qdesn_al_exact_chunked, series, tolerance = exact_tolerance),
  exact_compare(fits$qdesn_exal_unchunked, fits$qdesn_exal_exact_chunked, series, tolerance = exact_tolerance)
)

stochastic_diagnostics <- rbind(
  stochastic_compare(
    fits$qdesn_al_unchunked,
    fits$qdesn_al_stochastic,
    fits$qdesn_al_stochastic_repeat,
    series
  ),
  stochastic_compare(
    fits$qdesn_al_unchunked,
    fits$qdesn_al_hybrid,
    fits$qdesn_al_hybrid_repeat,
    series
  )
)

forbidden_modes <- rbind(
  data.frame(
    method = "qdesn_exal_stochastic",
    attempted = TRUE,
    failed_early = is.character(forbidden_stochastic_message) &&
      grepl("supported only for likelihood_family = 'al'", forbidden_stochastic_message, fixed = TRUE),
    message = as.character(forbidden_stochastic_message),
    stringsAsFactors = FALSE
  ),
  data.frame(
    method = "qdesn_exal_hybrid",
    attempted = TRUE,
    failed_early = is.character(forbidden_hybrid_message) &&
      grepl("supported only for likelihood_family = 'al'", forbidden_hybrid_message, fixed = TRUE),
    message = as.character(forbidden_hybrid_message),
    stringsAsFactors = FALSE
  )
)

repo_state <- data.frame(
  repo = repo_root,
  branch = git_value(c("rev-parse", "--abbrev-ref", "HEAD")),
  head = git_value(c("rev-parse", "HEAD")),
  upstream = git_value(c("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")),
  source_dir = source_dir,
  raw_n_rows = nrow(series_raw),
  selected_rows = nrow(series),
  tail_rows = tail_rows,
  expected_effective_rows = expected_effective_rows,
  seed = seed,
  qdesn_seed = qdesn_seed,
  D = qdesn_D,
  n = qdesn_n,
  m = qdesn_m,
  washout = qdesn_washout,
  max_iter = max_iter,
  stochastic_max_iter = stochastic_max_iter,
  hybrid_max_iter = hybrid_max_iter,
  hybrid_full_every = hybrid_full_every,
  chunk_size = chunk_size,
  exact_tolerance = exact_tolerance,
  cores = cores,
  add_bias = TRUE,
  stringsAsFactors = FALSE
)

write_csv(repo_state, file.path(output_dir, "repo_state.csv"))
write_csv(dataset_summary, file.path(output_dir, "dataset_summary.csv"))
write_csv(method_summary, file.path(output_dir, "method_summary.csv"))
write_csv(exact_equivalence, file.path(output_dir, "exact_equivalence.csv"))
write_csv(stochastic_diagnostics, file.path(output_dir, "stochastic_diagnostics.csv"))
write_csv(prediction_metrics, file.path(output_dir, "prediction_metrics.csv"))
write_csv(predictions, file.path(output_dir, "predictions_by_method.csv"))
write_csv(forbidden_modes, file.path(output_dir, "forbidden_modes.csv"))

plot_path <- file.path(output_dir, paste0(output_prefix, "_diagnostic.png"))
plot_written <- FALSE
if (capabilities("png")) {
  plot_written <- tryCatch(local({
    wide <- reshape(
      predictions[, c("source_t", "label", "y", "q_target", "fitted_median")],
      idvar = c("source_t", "y", "q_target"),
      timevar = "label",
      direction = "wide"
    )
    png_args <- list(filename = plot_path, width = 1600, height = 900, res = 140)
    if (isTRUE(capabilities("cairo"))) {
      png_args$type <- "cairo"
    }
    do.call(grDevices::png, png_args)
    on.exit(grDevices::dev.off(), add = TRUE)
    matplot(
      wide$source_t,
      cbind(
        wide$y,
        wide$q_target,
        wide$fitted_median.qdesn_al_unchunked,
        wide$fitted_median.qdesn_al_exact_chunked,
        wide$fitted_median.qdesn_al_stochastic,
        wide$fitted_median.qdesn_al_hybrid,
        wide$fitted_median.qdesn_exal_unchunked,
        wide$fitted_median.qdesn_exal_exact_chunked
      ),
      type = "l",
      lty = c(1, 1, 1, 2, 1, 1, 1, 2),
      lwd = c(1, 2, 2, 2, 2, 2, 1, 1),
      col = c("grey55", "black", "#1b9e77", "#66a61e", "#d95f02", "#e6ab02", "#7570b3", "#e7298a"),
      xlab = "source t",
      ylab = "response / fitted median",
      main = sprintf("Q-DESN VB batching comparison (%s)", output_prefix)
    )
    legend(
      "topleft",
      legend = c("y", "q_target/mu", "AL unchunked", "AL exact", "AL stochastic", "AL hybrid", "exAL unchunked", "exAL exact"),
      col = c("grey55", "black", "#1b9e77", "#66a61e", "#d95f02", "#e6ab02", "#7570b3", "#e7298a"),
      lty = c(1, 1, 1, 2, 1, 1, 1, 2),
      lwd = c(1, 2, 2, 2, 2, 2, 1, 1),
      bty = "n"
    )
    TRUE
  }), error = function(e) {
    message("Skipping optional diagnostic figure: ", conditionMessage(e))
    FALSE
  })
}

md_path <- file.path(output_dir, paste0(output_prefix, "_summary.md"))
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
      if (is.numeric(x)) format(x, digits = 12, scientific = TRUE) else as.character(x)
    }, character(1))
    w("| ", paste(vals, collapse = " | "), " |")
  }
}

w("# Q-DESN VB Source Median Comparison")
w("")
w("Source directory: `", source_dir, "`")
w("")
w("Selected rows: `", nrow(series), "` from raw rows `", nrow(series_raw), "`")
w("")
w("Effective post-washout rows: `", effective_rows_expected, "`")
w("")
w("Q-DESN settings: `D=", qdesn_D, "`, `n=", qdesn_n, "`, `m=", qdesn_m, "`, `washout=", qdesn_washout, "`")
w("")
w("Chunk size: `", chunk_size, "`; worker cores requested: `", cores, "`")
w("")
w("Exact-equivalence tolerance: `", exact_tolerance, "`")
w("")
w("Seed: `", seed, "`; Q-DESN seed: `", qdesn_seed, "`")
w("")
w("The model uses `y` only. `mu` and `q_target` are diagnostics.")
w("")
w("## Dataset")
md_table(dataset_summary)
w("")
w("## Method Summary")
md_table(method_summary)
w("")
w("## Prediction Metrics")
md_table(prediction_metrics)
w("")
w("## Exact Equivalence")
md_table(exact_equivalence)
w("")
w("## Stochastic/Hybrid Diagnostics")
md_table(stochastic_diagnostics)
w("")
w("## Forbidden Modes")
md_table(forbidden_modes)

cat("Wrote outputs to:", output_dir, "\n")
cat("Summary:", md_path, "\n")
if (file.exists(plot_path)) cat("Figure:", plot_path, "\n")

if (!all(method_summary$finite_state)) {
  stop("At least one fit has a non-finite state.", call. = FALSE)
}
if (expected_effective_rows > 0L && !all(method_summary$effective_rows == expected_effective_rows)) {
  stop("At least one fit used an unexpected number of effective rows.", call. = FALSE)
}
if (!all(exact_equivalence$passed)) {
  stop("At least one exact chunked equivalence gate failed.", call. = FALSE)
}
if (!all(stochastic_diagnostics$finite_state) ||
    !all(stochastic_diagnostics$stochastic_label_present) ||
    !all(stochastic_diagnostics$approximate_note_present) ||
    any(stochastic_diagnostics$reproducible_beta_mean_max_abs_diff > 1e-10) ||
    any(stochastic_diagnostics$reproducible_fitted_median_max_abs_diff > 1e-10)) {
  stop("Stochastic/hybrid AL reproducibility/labeling/finite-state gate failed.", call. = FALSE)
}
if (!all(forbidden_modes$failed_early)) {
  stop("Stochastic/hybrid exAL did not fail early as expected.", call. = FALSE)
}

cat("All source comparison gates passed.\n")
