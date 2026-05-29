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

arg_num <- function(flag, default) {
  value <- suppressWarnings(as.numeric(arg_value(flag, as.character(default))))
  if (!length(value) || !is.finite(value)) stop(sprintf("%s must be finite numeric.", flag), call. = FALSE)
  value
}

arg_int_optional <- function(flag) {
  raw <- arg_value(flag, NULL)
  if (is.null(raw)) return(NA_integer_)
  value <- suppressWarnings(as.integer(raw))
  if (!length(value) || !is.finite(value)) stop(sprintf("%s must be a finite integer.", flag), call. = FALSE)
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
  file.path(repo_root, "results", "qdesn_vb_implemented_modes_source_median_20260528")
)
seed <- arg_int("--seed", 20260528L)
qdesn_D <- arg_int("--D", 1L)
qdesn_n <- arg_int("--n", 50L)
qdesn_m <- arg_int("--m", 1L)
qdesn_washout <- arg_int("--washout", 50L)
chunk_size <- arg_int("--chunk-size", 64L)
subset_size <- arg_int("--subset-size", 180L)
max_iter <- arg_int("--max-iter", 25L)
stochastic_max_iter <- arg_int("--stochastic-max-iter", 60L)
hybrid_max_iter <- arg_int("--hybrid-max-iter", stochastic_max_iter)
hybrid_full_every <- arg_int("--hybrid-full-every", 15L)
cores <- arg_int("--cores", 1L)
exact_tolerance <- arg_num("--exact-tolerance", 1e-6)
exact_relative_tolerance <- arg_num("--exact-relative-tolerance", 1e-8)
tail_rows <- arg_int_optional("--tail-rows")
expected_effective_rows <- arg_int_optional("--expected-effective-rows")
skip_workflows <- arg_flag("--skip-workflows")

if (qdesn_D != 1L) stop("This implemented-mode comparison currently supports D = 1 only.", call. = FALSE)
if (qdesn_n < 1L) stop("--n must be positive.", call. = FALSE)
if (qdesn_m < 0L) stop("--m must be non-negative.", call. = FALSE)
if (qdesn_washout < 0L) stop("--washout must be non-negative.", call. = FALSE)
if (chunk_size < 1L) stop("--chunk-size must be positive.", call. = FALSE)
if (subset_size < 1L) stop("--subset-size must be positive.", call. = FALSE)
if (max_iter < 1L || stochastic_max_iter < 1L || hybrid_max_iter < 1L) {
  stop("iteration controls must be positive.", call. = FALSE)
}
if (hybrid_full_every < 1L) stop("--hybrid-full-every must be positive.", call. = FALSE)
if (cores < 1L) stop("--cores must be positive.", call. = FALSE)
if (!is.finite(exact_tolerance) || exact_tolerance <= 0) {
  stop("--exact-tolerance must be positive.", call. = FALSE)
}
if (!is.finite(exact_relative_tolerance) || exact_relative_tolerance <= 0) {
  stop("--exact-relative-tolerance must be positive.", call. = FALSE)
}
if (!is.na(tail_rows) && tail_rows < 0L) stop("--tail-rows must be non-negative when supplied.", call. = FALSE)
if (!is.na(expected_effective_rows) && expected_effective_rows < 1L) {
  stop("--expected-effective-rows must be positive when supplied.", call. = FALSE)
}
if (cores > 1L && !identical(.Platform$OS.type, "unix")) {
  stop("--cores > 1 requires a Unix-like platform.", call. = FALSE)
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
  stop("This comparison requires pkgload.", call. = FALSE)
}
pkgload::load_all(repo_root, quiet = TRUE)

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, quote = TRUE)
  invisible(path)
}

rbind_fill <- function(dfs) {
  dfs <- Filter(Negate(is.null), dfs)
  if (!length(dfs)) return(data.frame())
  cols <- unique(unlist(lapply(dfs, names), use.names = FALSE))
  dfs <- lapply(dfs, function(x) {
    missing <- setdiff(cols, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[cols]
  })
  do.call(rbind, dfs)
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

rmse <- function(x) sqrt(mean(as.numeric(x)^2))

hash_or_na <- function(expr) {
  tryCatch(expr, error = function(e) NA_character_)
}

num_summary_row <- function(name, x) {
  x <- as.numeric(x)
  data.frame(
    variable = name,
    n = length(x),
    min = min(x),
    q1 = unname(stats::quantile(x, 0.25)),
    median = stats::median(x),
    mean = mean(x),
    q3 = unname(stats::quantile(x, 0.75)),
    max = max(x),
    sd = stats::sd(x),
    stringsAsFactors = FALSE
  )
}

series_path <- file.path(source_dir, "series_wide.csv")
selection_path <- file.path(source_dir, "selection_indices.csv")
series <- utils::read.csv(series_path)
selection <- utils::read.csv(selection_path)
source_n_rows <- nrow(series)

required_cols <- c("t", "y", "mu", "q_target", "eps")
if (!identical(names(series), required_cols)) {
  stop("series_wide.csv must have columns: t,y,mu,q_target,eps.", call. = FALSE)
}
if (nrow(selection) != nrow(series) || !all(c("t", "source_index") %in% names(selection))) {
  stop("selection_indices.csv must align with series_wide.csv and include t,source_index.", call. = FALSE)
}
if (!is.na(tail_rows) && tail_rows > 0L) {
  if (tail_rows > nrow(series)) {
    stop("--tail-rows cannot exceed the available source row count.", call. = FALSE)
  }
  tail_idx <- seq.int(nrow(series) - tail_rows + 1L, nrow(series))
  series <- series[tail_idx, , drop = FALSE]
  selection <- selection[tail_idx, , drop = FALSE]
  row.names(series) <- NULL
  row.names(selection) <- NULL
}
if (nrow(series) < 2L) stop("The selected source slice must contain at least two rows.", call. = FALSE)
if (anyNA(selection$source_index) || any(!is.finite(selection$source_index))) {
  stop("selection_indices.csv contains missing or non-finite source_index values.", call. = FALSE)
}
if (any(diff(as.integer(selection$source_index)) != 1L)) {
  stop("The selected source_index values must be contiguous and increasing.", call. = FALSE)
}
if (max(abs(series$mu - series$q_target)) != 0) {
  stop("q_target must equal mu exactly for this median source.", call. = FALSE)
}
if (anyNA(series[c("y", "mu", "q_target")])) {
  stop("series_wide.csv contains missing y, mu, or q_target values.", call. = FALSE)
}
if (qdesn_washout >= nrow(series)) {
  stop(sprintf("--washout must be smaller than the selected row count (%d).", nrow(series)), call. = FALSE)
}

effective_rows <- nrow(series) - max(qdesn_m, qdesn_washout)
if (!is.na(expected_effective_rows) && effective_rows != expected_effective_rows) {
  stop(sprintf(
    "Selected source slice yields %d effective rows, not --expected-effective-rows=%d.",
    effective_rows, expected_effective_rows
  ), call. = FALSE)
}
subset_size <- min(subset_size, effective_rows)
fixed_subset_rows <- unique(as.integer(round(seq.int(1L, effective_rows, length.out = subset_size))))
if (length(fixed_subset_rows) < subset_size) {
  fixed_subset_rows <- sort(unique(c(fixed_subset_rows, seq_len(effective_rows))))[seq_len(subset_size)]
}
stratified_subset_cfg <- list(
  enabled = TRUE,
  mode = "stratified",
  strata = "time_block",
  size = subset_size,
  n_strata = min(5L, subset_size),
  seed = seed + 700L
)
stratified_equal_subset_cfg <- stratified_subset_cfg
stratified_equal_subset_cfg$allocation <- "equal"
stratified_equal_subset_cfg$seed <- seed + 701L
stratified_response_subset_cfg <- stratified_subset_cfg
stratified_response_subset_cfg$strata <- "response_quantile"
stratified_response_subset_cfg$seed <- seed + 702L
stratified_leverage_subset_cfg <- stratified_subset_cfg
stratified_leverage_subset_cfg$strata <- "design_leverage"
stratified_leverage_subset_cfg$seed <- seed + 703L

qdesn_seed <- seed + 100L
desn_args <- list(
  p0 = 0.5,
  D = qdesn_D,
  n = qdesn_n,
  n_tilde = integer(0),
  m = qdesn_m,
  washout = qdesn_washout,
  add_bias = TRUE,
  seed = qdesn_seed,
  fit_readout = TRUE
)

base_vb <- list(
  likelihood_family = "al",
  al_fixed_gamma = 0,
  max_iter = max_iter,
  min_iter_elbo = 8L,
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
  refresh = list(
    full_every = 20L,
    objective_every = 20L,
    sigma_every = 5L,
    rhs_every = 20L,
    local_every = 20L
  ),
  diagnostics = list(trace = TRUE, store_batch_ids = TRUE, check_finite_every = 1L)
)
hybrid_chunking <- stochastic_chunking
hybrid_chunking$mode <- "hybrid"
hybrid_chunking$refresh$full_every <- hybrid_full_every
hybrid_chunking$refresh$objective_every <- hybrid_full_every
hybrid_chunking$refresh$sigma_every <- hybrid_full_every
hybrid_chunking$refresh$rhs_every <- hybrid_full_every
hybrid_chunking$refresh$local_every <- hybrid_full_every

rhs_controls <- list(
  tau0 = 0.8,
  nu = 4,
  s2 = 1.25,
  shrink_intercept = FALSE,
  intercept_prec = 1e-12,
  n_inner = 1L,
  eta_bounds = list(lambda = c(-8, 8), tau = c(-8, 8), c2 = c(-8, 8)),
  init_log_lambda = 0,
  init_log_tau = 0,
  init_log_c2 = 0
)
rhs_ns_controls <- list(
  tau0 = 0.8,
  a_zeta = 2,
  b_zeta = 1,
  zeta2_fixed = 1.25,
  s2 = 1.25,
  shrink_intercept = FALSE,
  intercept_prec = 1e-12,
  n_inner = 1L,
  init_lambda2 = 1,
  init_tau2 = 1,
  init_xi = 1,
  init_zeta2 = 1.25
)

with_exact <- function(vb) utils::modifyList(vb, list(chunking = exact_chunking))
with_cov_diag <- function(vb) utils::modifyList(vb, list(beta_covariance = list(approximation = "diagonal")))
with_subset <- function(vb, subset_fit) utils::modifyList(vb, list(subset_fit = subset_fit))
with_likelihood <- function(vb, family) {
  vb$likelihood_family <- family
  if (identical(family, "al")) {
    vb$al_fixed_gamma <- 0
  } else {
    vb$al_fixed_gamma <- NULL
  }
  vb
}
with_prior <- function(vb, type) {
  type <- match.arg(type, c("ridge", "rhs", "rhs_ns"))
  vb$beta_prior_type <- type
  if (identical(type, "ridge")) {
    vb$beta_ridge_tau2 <- 50
    vb$beta_rhs <- NULL
  } else if (identical(type, "rhs")) {
    vb$beta_rhs <- rhs_controls
  } else {
    vb$beta_rhs <- rhs_ns_controls
  }
  vb
}

make_spec <- function(method_id, vb_args) {
  list(method_id = method_id, vb_args = vb_args)
}

al_ridge <- with_prior(with_likelihood(base_vb, "al"), "ridge")
exal_ridge <- with_prior(with_likelihood(base_vb, "exal"), "ridge")
al_rhs <- with_prior(with_likelihood(base_vb, "al"), "rhs")
al_rhs_ns <- with_prior(with_likelihood(base_vb, "al"), "rhs_ns")
exal_rhs <- with_prior(with_likelihood(base_vb, "exal"), "rhs")
exal_rhs_ns <- with_prior(with_likelihood(base_vb, "exal"), "rhs_ns")

fit_specs <- list(
  make_spec("qdesn_al_ridge_full", al_ridge),
  make_spec("qdesn_al_ridge_exact", with_exact(al_ridge)),
  make_spec("qdesn_al_ridge_stochastic", utils::modifyList(al_ridge, list(max_iter = stochastic_max_iter, chunking = stochastic_chunking))),
  make_spec("qdesn_al_ridge_stochastic_repeat", utils::modifyList(al_ridge, list(max_iter = stochastic_max_iter, chunking = stochastic_chunking))),
  make_spec("qdesn_al_ridge_hybrid", utils::modifyList(al_ridge, list(max_iter = hybrid_max_iter, chunking = hybrid_chunking))),
  make_spec("qdesn_al_ridge_hybrid_repeat", utils::modifyList(al_ridge, list(max_iter = hybrid_max_iter, chunking = hybrid_chunking))),
  make_spec("qdesn_al_ridge_diagonal", with_cov_diag(al_ridge)),
  make_spec("qdesn_al_ridge_diagonal_exact", with_exact(with_cov_diag(al_ridge))),
  make_spec("qdesn_al_ridge_fixed_subset", with_subset(al_ridge, list(enabled = TRUE, mode = "fixed", rows = fixed_subset_rows))),
  make_spec("qdesn_al_ridge_fixed_subset_exact", with_exact(with_subset(al_ridge, list(enabled = TRUE, mode = "fixed", rows = fixed_subset_rows)))),
  make_spec("qdesn_al_ridge_stratified_subset", with_subset(al_ridge, stratified_subset_cfg)),
  make_spec("qdesn_al_ridge_stratified_subset_exact", with_exact(with_subset(al_ridge, stratified_subset_cfg))),
  make_spec("qdesn_al_ridge_stratified_equal_subset", with_subset(al_ridge, stratified_equal_subset_cfg)),
  make_spec("qdesn_al_ridge_stratified_equal_subset_exact", with_exact(with_subset(al_ridge, stratified_equal_subset_cfg))),
  make_spec("qdesn_al_ridge_stratified_response_subset", with_subset(al_ridge, stratified_response_subset_cfg)),
  make_spec("qdesn_al_ridge_stratified_response_subset_exact", with_exact(with_subset(al_ridge, stratified_response_subset_cfg))),
  make_spec("qdesn_al_ridge_stratified_leverage_subset", with_subset(al_ridge, stratified_leverage_subset_cfg)),
  make_spec("qdesn_al_ridge_stratified_leverage_subset_exact", with_exact(with_subset(al_ridge, stratified_leverage_subset_cfg))),
  make_spec("qdesn_al_rhs_full", al_rhs),
  make_spec("qdesn_al_rhs_exact", with_exact(al_rhs)),
  make_spec("qdesn_al_rhs_diagonal", with_cov_diag(al_rhs)),
  make_spec("qdesn_al_rhs_diagonal_exact", with_exact(with_cov_diag(al_rhs))),
  make_spec("qdesn_al_rhs_ns_full", al_rhs_ns),
  make_spec("qdesn_al_rhs_ns_exact", with_exact(al_rhs_ns)),
  make_spec("qdesn_al_rhs_ns_diagonal", with_cov_diag(al_rhs_ns)),
  make_spec("qdesn_al_rhs_ns_diagonal_exact", with_exact(with_cov_diag(al_rhs_ns))),
  make_spec("qdesn_exal_ridge_full", exal_ridge),
  make_spec("qdesn_exal_ridge_exact", with_exact(exal_ridge)),
  make_spec("qdesn_exal_ridge_diagonal", with_cov_diag(exal_ridge)),
  make_spec("qdesn_exal_ridge_diagonal_exact", with_exact(with_cov_diag(exal_ridge))),
  make_spec("qdesn_exal_ridge_hybrid", utils::modifyList(exal_ridge, list(max_iter = hybrid_max_iter, chunking = hybrid_chunking))),
  make_spec("qdesn_exal_ridge_hybrid_repeat", utils::modifyList(exal_ridge, list(max_iter = hybrid_max_iter, chunking = hybrid_chunking))),
  make_spec("qdesn_exal_rhs_full", exal_rhs),
  make_spec("qdesn_exal_rhs_exact", with_exact(exal_rhs)),
  make_spec("qdesn_exal_rhs_hybrid", utils::modifyList(exal_rhs, list(max_iter = hybrid_max_iter, chunking = hybrid_chunking))),
  make_spec("qdesn_exal_rhs_hybrid_repeat", utils::modifyList(exal_rhs, list(max_iter = hybrid_max_iter, chunking = hybrid_chunking))),
  make_spec("qdesn_exal_rhs_ns_full", exal_rhs_ns),
  make_spec("qdesn_exal_rhs_ns_exact", with_exact(exal_rhs_ns)),
  make_spec("qdesn_exal_rhs_ns_hybrid", utils::modifyList(exal_rhs_ns, list(max_iter = hybrid_max_iter, chunking = hybrid_chunking))),
  make_spec("qdesn_exal_rhs_ns_hybrid_repeat", utils::modifyList(exal_rhs_ns, list(max_iter = hybrid_max_iter, chunking = hybrid_chunking)))
)

fit_qdesn_spec <- function(spec) {
  cat("Fitting", spec$method_id, "\n")
  fit_args <- c(list(y = series$y), desn_args, list(vb_args = spec$vb_args))
  tm <- system.time({
    fit <- do.call(exdqlm::qdesn_fit_vb, fit_args)
  })
  cat("Finished", spec$method_id, "elapsed_sec=", unname(tm[["elapsed"]]), "\n")
  list(method_id = spec$method_id, fit = fit, elapsed_sec = unname(tm[["elapsed"]]))
}

cat("Implemented-mode Q-DESN VB comparison\n")
cat("source_dir:", source_dir, "\n")
cat("output_dir:", output_dir, "\n")
cat("seed:", seed, " qdesn_seed:", qdesn_seed, "\n")
cat("D:", qdesn_D, " n:", qdesn_n, " m:", qdesn_m, " washout:", qdesn_washout, "\n")
cat("effective_rows:", effective_rows, " subset_size:", subset_size, " chunk_size:", chunk_size, "\n")
cat("cores:", cores, "\n")

if (cores > 1L) {
  fits <- parallel::mclapply(
    fit_specs,
    fit_qdesn_spec,
    mc.cores = min(cores, length(fit_specs)),
    mc.preschedule = FALSE,
    mc.set.seed = FALSE
  )
} else {
  fits <- lapply(fit_specs, fit_qdesn_spec)
}
names(fits) <- vapply(fits, `[[`, character(1), "method_id")

readout_fit <- function(obj) obj$fit$fit
fitted_values <- function(obj) as.numeric(obj$fit$mu_hat)
keep_idx <- function(obj) as.integer(obj$fit$meta$keep_idx)
design_hash <- function(obj) hash_or_na(exdqlm:::.qdesn_vb_design_hash(obj$fit$X))

finite_fit_state <- function(fit) {
  all(is.finite(as.numeric(fit$qbeta$m))) &&
    all(is.finite(as.matrix(fit$qbeta$V))) &&
    all(is.finite(as.numeric(fit$qv$E_v))) &&
    all(is.finite(as.numeric(fit$qv$E_inv_v))) &&
    all(is.finite(as.numeric(fit$qs$E_s))) &&
    all(is.finite(as.numeric(fit$qs$E_s2))) &&
    is.finite(as.numeric(fit$qsiggam$sigma_mean)) &&
    is.finite(as.numeric(fit$qsiggam$gamma_mean))
}

target_label_for <- function(fit) {
  misc <- fit$misc %||% list()
  chunking <- misc$chunking %||% list()
  mode <- if (isTRUE(chunking$enabled)) as.character(chunking$mode %||% "unknown") else "none"
  if (identical(as.character(misc$target_label %||% ""), "subset_data_vb")) return("subset_target")
  if (isTRUE(misc$approximate_covariance)) return("covariance_approximation")
  if (identical(mode, "exact")) return("full_data_exact_chunked")
  if (identical(mode, "stochastic")) return("full_data_approx_stochastic")
  if (identical(mode, "hybrid")) return("full_data_approx_hybrid")
  "full_data_exact"
}

method_summary_row <- function(obj) {
  fit <- readout_fit(obj)
  misc <- fit$misc %||% list()
  chunking <- misc$chunking %||% list()
  chunking_mode <- if (isTRUE(chunking$enabled)) as.character(chunking$mode %||% "unknown") else "none"
  target_label <- target_label_for(fit)
  qbeta_m <- as.numeric(fit$qbeta$m)
  qbeta_vdiag <- diag(as.matrix(fit$qbeta$V))
  idx <- keep_idx(obj)
  pred <- fitted_values(obj)
  y_eval <- series$y[idx]
  q_eval <- series$q_target[idx]
  data.frame(
    method_id = obj$method_id,
    likelihood_family = as.character(fit$likelihood_family),
    prior_family = as.character(fit$beta_prior$type %||% NA_character_),
    covariance_form = as.character(fit$qbeta$covariance_approximation %||% "full"),
    chunking_mode = chunking_mode,
    target_label = target_label,
    preserves_full_data_target = isTRUE(misc$preserves_full_data_target %||% TRUE) && !identical(target_label, "subset_target"),
    approximate = isTRUE(misc$approximate_chunking) || isTRUE(misc$approximate_covariance),
    target_changes = identical(target_label, "subset_target"),
    stochastic = isTRUE(misc$stochastic),
    hybrid = isTRUE(misc$hybrid),
    seed = seed,
    qdesn_seed = qdesn_seed,
    D = qdesn_D,
    reservoir_n = qdesn_n,
    m = qdesn_m,
    washout = qdesn_washout,
    source_index_min = min(selection$source_index),
    source_index_max = max(selection$source_index),
    eval_source_index_min = min(selection$source_index[idx]),
    eval_source_index_max = max(selection$source_index[idx]),
    prediction_rows = length(idx),
    engine_rows = as.integer(misc$n %||% length(fit$qv$E_v)),
    original_engine_rows = as.integer(misc$original_n %||% length(idx)),
    subset_rows = length(misc$subset_rows %||% integer(0)),
    design_hash = design_hash(obj),
    package_sha = hash_or_na(exdqlm:::.qdesn_vb_package_sha()),
    converged = isTRUE(fit$converged),
    iter = as.integer(fit$iter),
    elapsed_sec = as.numeric(obj$elapsed_sec),
    finite_state = finite_fit_state(fit),
    beta_mean_min = min(qbeta_m),
    beta_mean_median = stats::median(qbeta_m),
    beta_mean_mean = mean(qbeta_m),
    beta_mean_max = max(qbeta_m),
    beta_cov_diag_min = min(qbeta_vdiag),
    beta_cov_diag_median = stats::median(qbeta_vdiag),
    beta_cov_diag_max = max(qbeta_vdiag),
    sigma_tail = as.numeric(fit$qsiggam$sigma_mean),
    gamma_tail = as.numeric(fit$qsiggam$gamma_mean),
    pinball_y = pinball_loss(y_eval, pred, 0.5),
    mae_y = mean(abs(y_eval - pred)),
    rmse_y = rmse(y_eval - pred),
    mae_q_target = mean(abs(q_eval - pred)),
    rmse_q_target = rmse(q_eval - pred),
    cor_q_target = as.numeric(stats::cor(q_eval, pred)),
    stringsAsFactors = FALSE
  )
}

prediction_rows <- function(obj) {
  idx <- keep_idx(obj)
  data.frame(
    method_id = obj$method_id,
    row_index = seq_along(idx),
    source_t = series$t[idx],
    source_index = selection$source_index[idx],
    y = series$y[idx],
    mu = series$mu[idx],
    q_target = series$q_target[idx],
    fitted_median = fitted_values(obj),
    stringsAsFactors = FALSE
  )
}

exact_compare <- function(reference, candidate, comparison_type = "exact_chunking") {
  rf <- readout_fit(reference)
  cf <- readout_fit(candidate)
  beta_mean_diff <- max_abs(as.numeric(rf$qbeta$m) - as.numeric(cf$qbeta$m))
  beta_cov_diff <- max_abs(as.matrix(rf$qbeta$V) - as.matrix(cf$qbeta$V))
  fitted_diff <- max_abs(fitted_values(reference) - fitted_values(candidate))
  sigma_trace_diff <- max_abs(as.numeric(rf$misc$sigma_trace) - as.numeric(cf$misc$sigma_trace))
  gamma_trace_diff <- max_abs(as.numeric(rf$misc$gamma_trace) - as.numeric(cf$misc$gamma_trace))
  elbo_trace_diff <- max_abs(as.numeric(rf$misc$elbo_trace) - as.numeric(cf$misc$elbo_trace))
  design_diff <- max_abs(reference$fit$X - candidate$fit$X)
  gate_diff <- max(
    beta_mean_diff, beta_cov_diff, fitted_diff, sigma_trace_diff,
    gamma_trace_diff, elbo_trace_diff, design_diff,
    na.rm = TRUE
  )
  gate_scale <- max(
    1,
    max_abs(rf$qbeta$m),
    max_abs(rf$qbeta$V),
    max_abs(fitted_values(reference)),
    max_abs(rf$misc$sigma_trace),
    max_abs(rf$misc$gamma_trace),
    max_abs(rf$misc$elbo_trace),
    max_abs(reference$fit$X),
    na.rm = TRUE
  )
  relative_gate_diff <- gate_diff / gate_scale
  data.frame(
    comparison_type = comparison_type,
    reference_method = reference$method_id,
    candidate_method = candidate$method_id,
    reference_target_label = target_label_for(rf),
    candidate_target_label = target_label_for(cf),
    same_keep_idx = identical(keep_idx(reference), keep_idx(candidate)),
    same_design = is.finite(design_diff) && design_diff == 0,
    same_convergence_status = identical(isTRUE(rf$converged), isTRUE(cf$converged)),
    reference_iter = as.integer(rf$iter),
    candidate_iter = as.integer(cf$iter),
    beta_mean_max_abs_diff = beta_mean_diff,
    beta_cov_max_abs_diff = beta_cov_diff,
    fitted_median_max_abs_diff = fitted_diff,
    sigma_trace_max_abs_diff = sigma_trace_diff,
    gamma_trace_max_abs_diff = gamma_trace_diff,
    elbo_trace_max_abs_diff = elbo_trace_diff,
    qdesn_design_max_abs_diff = design_diff,
    max_gate_diff = gate_diff,
    gate_scale = gate_scale,
    relative_gate_diff = relative_gate_diff,
    tolerance = exact_tolerance,
    relative_tolerance = exact_relative_tolerance,
    passed = is.finite(gate_diff) &&
      (gate_diff <= exact_tolerance || relative_gate_diff <= exact_relative_tolerance),
    stringsAsFactors = FALSE
  )
}

approx_compare <- function(reference, candidate, repeat_fit = NULL, comparison_type = "approximate") {
  rf <- readout_fit(reference)
  cf <- readout_fit(candidate)
  pred_ref <- fitted_values(reference)
  pred_cand <- fitted_values(candidate)
  idx_ref <- keep_idx(reference)
  idx_cand <- keep_idx(candidate)
  out <- data.frame(
    comparison_type = comparison_type,
    reference_method = reference$method_id,
    candidate_method = candidate$method_id,
    target_label = target_label_for(cf),
    approximate = isTRUE(cf$misc$approximate_chunking) || isTRUE(cf$misc$approximate_covariance),
    finite_state = finite_fit_state(cf),
    repeat_method = NA_character_,
    reproducible_beta_mean_max_abs_diff = NA_real_,
    reproducible_fitted_median_max_abs_diff = NA_real_,
    beta_mean_max_abs_diff_vs_reference = max_abs(as.numeric(cf$qbeta$m) - as.numeric(rf$qbeta$m)),
    beta_cov_diag_max_abs_diff_vs_reference = max_abs(diag(as.matrix(cf$qbeta$V)) - diag(as.matrix(rf$qbeta$V))),
    fitted_median_max_abs_diff_vs_reference = max_abs(pred_cand - pred_ref),
    pinball_diff_vs_reference = pinball_loss(series$y[idx_cand], pred_cand, 0.5) -
      pinball_loss(series$y[idx_ref], pred_ref, 0.5),
    mae_y_diff_vs_reference = mean(abs(series$y[idx_cand] - pred_cand)) -
      mean(abs(series$y[idx_ref] - pred_ref)),
    rmse_y_diff_vs_reference = rmse(series$y[idx_cand] - pred_cand) -
      rmse(series$y[idx_ref] - pred_ref),
    stringsAsFactors = FALSE
  )
  if (!is.null(repeat_fit)) {
    repf <- readout_fit(repeat_fit)
    out$repeat_method <- repeat_fit$method_id
    out$reproducible_beta_mean_max_abs_diff <- max_abs(as.numeric(cf$qbeta$m) - as.numeric(repf$qbeta$m))
    out$reproducible_fitted_median_max_abs_diff <- max_abs(pred_cand - fitted_values(repeat_fit))
  }
  out
}

workflow_summary <- function(label, obj, elapsed_sec) {
  summary_df <- obj$summary
  data.frame(
    method_id = label,
    workflow_class = class(obj)[[1L]],
    target_label = as.character((obj$target %||% list())$type %||% NA_character_),
    preserves_full_data_target = isTRUE((obj$target %||% list())$preserves_full_data_target),
    order_sensitive = isTRUE((obj$target %||% list())$order_sensitive),
    posterior_as_prior = isTRUE((obj$target %||% list())$posterior_as_prior),
    no_future_leakage = isTRUE((obj$target %||% list())$no_future_leakage),
    n_units = nrow(summary_df),
    first_start = min(summary_df[[grep("start$", names(summary_df), value = TRUE)[1L]]]),
    last_end = max(summary_df[[grep("(end|origin)$", names(summary_df), value = TRUE)[1L]]]),
    final_beta_l2 = tail(summary_df$beta_l2, 1L),
    final_sigma_mean = tail(summary_df$sigma_mean, 1L),
    final_gamma_mean = tail(summary_df$gamma_mean, 1L),
    all_finite_qbeta = all(summary_df$finite_qbeta),
    all_finite_sigma_gamma = all(summary_df$finite_sigma_gamma),
    elapsed_sec = as.numeric(elapsed_sec),
    package_sha = hash_or_na(exdqlm:::.qdesn_vb_package_sha()),
    stringsAsFactors = FALSE
  )
}

target_change_compare <- function(reference, candidate) {
  rf <- readout_fit(reference)
  cf <- readout_fit(candidate)
  pred_ref <- fitted_values(reference)
  pred_cand <- fitted_values(candidate)
  data.frame(
    reference_method = reference$method_id,
    candidate_method = candidate$method_id,
    candidate_target_label = target_label_for(cf),
    candidate_preserves_full_data_target = isTRUE(cf$misc$preserves_full_data_target %||% TRUE),
    candidate_subset_rows = length(cf$misc$subset_rows %||% integer(0)),
    candidate_original_rows = as.integer(cf$misc$original_n %||% length(pred_cand)),
    beta_mean_max_abs_diff_vs_reference = max_abs(as.numeric(cf$qbeta$m) - as.numeric(rf$qbeta$m)),
    fitted_median_max_abs_diff_vs_reference = max_abs(pred_cand - pred_ref),
    pinball_diff_vs_reference = pinball_loss(series$y[keep_idx(candidate)], pred_cand, 0.5) -
      pinball_loss(series$y[keep_idx(reference)], pred_ref, 0.5),
    finite_state = finite_fit_state(cf),
    stringsAsFactors = FALSE
  )
}

main_methods <- setdiff(
  names(fits),
  c(
    "qdesn_al_ridge_stochastic_repeat",
    "qdesn_al_ridge_hybrid_repeat",
    "qdesn_exal_ridge_hybrid_repeat",
    "qdesn_exal_rhs_hybrid_repeat",
    "qdesn_exal_rhs_ns_hybrid_repeat"
  )
)
method_summary <- rbind_fill(lapply(fits[main_methods], method_summary_row))
prediction_metrics <- method_summary[, c(
  "method_id", "likelihood_family", "prior_family", "covariance_form",
  "chunking_mode", "target_label", "preserves_full_data_target", "approximate",
  "target_changes", "pinball_y", "mae_y", "rmse_y", "mae_q_target",
  "rmse_q_target", "cor_q_target"
)]
predictions <- rbind_fill(lapply(fits[main_methods], prediction_rows))

exact_equivalence <- rbind_fill(list(
  exact_compare(fits$qdesn_al_ridge_full, fits$qdesn_al_ridge_exact),
  exact_compare(fits$qdesn_al_ridge_diagonal, fits$qdesn_al_ridge_diagonal_exact, "diagonal_exact_chunking"),
  exact_compare(fits$qdesn_al_ridge_fixed_subset, fits$qdesn_al_ridge_fixed_subset_exact, "subset_exact_chunking"),
  exact_compare(fits$qdesn_al_ridge_stratified_subset, fits$qdesn_al_ridge_stratified_subset_exact, "subset_exact_chunking"),
  exact_compare(fits$qdesn_al_ridge_stratified_equal_subset, fits$qdesn_al_ridge_stratified_equal_subset_exact, "subset_exact_chunking"),
  exact_compare(fits$qdesn_al_ridge_stratified_response_subset, fits$qdesn_al_ridge_stratified_response_subset_exact, "subset_exact_chunking"),
  exact_compare(fits$qdesn_al_ridge_stratified_leverage_subset, fits$qdesn_al_ridge_stratified_leverage_subset_exact, "subset_exact_chunking"),
  exact_compare(fits$qdesn_al_rhs_full, fits$qdesn_al_rhs_exact),
  exact_compare(fits$qdesn_al_rhs_diagonal, fits$qdesn_al_rhs_diagonal_exact, "diagonal_exact_chunking"),
  exact_compare(fits$qdesn_al_rhs_ns_full, fits$qdesn_al_rhs_ns_exact),
  exact_compare(fits$qdesn_al_rhs_ns_diagonal, fits$qdesn_al_rhs_ns_diagonal_exact, "diagonal_exact_chunking"),
  exact_compare(fits$qdesn_exal_ridge_full, fits$qdesn_exal_ridge_exact),
  exact_compare(fits$qdesn_exal_ridge_diagonal, fits$qdesn_exal_ridge_diagonal_exact, "diagonal_exact_chunking"),
  exact_compare(fits$qdesn_exal_rhs_full, fits$qdesn_exal_rhs_exact),
  exact_compare(fits$qdesn_exal_rhs_ns_full, fits$qdesn_exal_rhs_ns_exact)
))

approximate_diagnostics <- rbind_fill(list(
  approx_compare(fits$qdesn_al_ridge_full, fits$qdesn_al_ridge_stochastic, fits$qdesn_al_ridge_stochastic_repeat, "stochastic_al"),
  approx_compare(fits$qdesn_al_ridge_full, fits$qdesn_al_ridge_hybrid, fits$qdesn_al_ridge_hybrid_repeat, "hybrid_al"),
  approx_compare(fits$qdesn_exal_ridge_full, fits$qdesn_exal_ridge_hybrid, fits$qdesn_exal_ridge_hybrid_repeat, "hybrid_exal"),
  approx_compare(fits$qdesn_exal_rhs_full, fits$qdesn_exal_rhs_hybrid, fits$qdesn_exal_rhs_hybrid_repeat, "hybrid_exal"),
  approx_compare(fits$qdesn_exal_rhs_ns_full, fits$qdesn_exal_rhs_ns_hybrid, fits$qdesn_exal_rhs_ns_hybrid_repeat, "hybrid_exal"),
  approx_compare(fits$qdesn_al_ridge_full, fits$qdesn_al_ridge_diagonal, NULL, "diagonal_covariance"),
  approx_compare(fits$qdesn_al_rhs_full, fits$qdesn_al_rhs_diagonal, NULL, "diagonal_covariance"),
  approx_compare(fits$qdesn_al_rhs_ns_full, fits$qdesn_al_rhs_ns_diagonal, NULL, "diagonal_covariance"),
  approx_compare(fits$qdesn_exal_ridge_full, fits$qdesn_exal_ridge_diagonal, NULL, "diagonal_covariance")
))

target_changing_diagnostics <- rbind_fill(list(
  target_change_compare(fits$qdesn_al_ridge_full, fits$qdesn_al_ridge_fixed_subset),
  target_change_compare(fits$qdesn_al_ridge_full, fits$qdesn_al_ridge_stratified_subset),
  target_change_compare(fits$qdesn_al_ridge_full, fits$qdesn_al_ridge_stratified_equal_subset),
  target_change_compare(fits$qdesn_al_ridge_full, fits$qdesn_al_ridge_stratified_response_subset),
  target_change_compare(fits$qdesn_al_ridge_full, fits$qdesn_al_ridge_stratified_leverage_subset)
))

if (!isTRUE(skip_workflows)) {
  desn_args_workflow <- desn_args
  desn_args_workflow$p0 <- NULL
  desn_args_workflow$fit_readout <- NULL
  vb_online <- al_ridge
  workflow_min_rows <- max(qdesn_m, qdesn_washout) + 10L
  workflow_window_size <- min(nrow(series), max(250L, workflow_min_rows))
  batch_ends <- unique(as.integer(c(workflow_window_size, nrow(series))))
  origins <- batch_ends

  cat("Running rolling/posterior-as-prior/online workflow diagnostics\n")
  workflow_rows <- list()
  workflow_exact_rows <- list()
  tm_roll <- system.time({
    rolling <- exdqlm::qdesn_vb_fit_rolling(
      y = series$y,
      p0 = 0.5,
      origins = origins,
      window_size = workflow_window_size,
      mode = "rolling",
      desn_args = desn_args_workflow,
      vb_args = vb_online,
      posterior_as_prior = FALSE,
      keep_fits = TRUE
    )
  })
  workflow_rows[[length(workflow_rows) + 1L]] <- workflow_summary("qdesn_al_ridge_rolling", rolling, tm_roll[["elapsed"]])

  tm_pap <- system.time({
    pap <- exdqlm::qdesn_vb_fit_rolling(
      y = series$y,
      p0 = 0.5,
      origins = origins,
      window_size = workflow_window_size,
      mode = "rolling",
      desn_args = desn_args_workflow,
      vb_args = vb_online,
      posterior_as_prior = TRUE,
      keep_fits = TRUE
    )
  })
  workflow_rows[[length(workflow_rows) + 1L]] <- workflow_summary("qdesn_al_ridge_posterior_as_prior", pap, tm_pap[["elapsed"]])

  tm_online <- system.time({
    online <- exdqlm::qdesn_vb_fit_online(
      y = series$y,
      p0 = 0.5,
      batch_ends = batch_ends,
      desn_args = desn_args_workflow,
      vb_args = vb_online,
      posterior_as_prior = TRUE,
      keep_fits = TRUE,
      keep_states = TRUE
    )
  })
  workflow_rows[[length(workflow_rows) + 1L]] <- workflow_summary("qdesn_al_ridge_online", online, tm_online[["elapsed"]])

  tm_online_exact <- system.time({
    online_exact <- exdqlm::qdesn_vb_fit_online(
      y = series$y,
      p0 = 0.5,
      batch_ends = batch_ends,
      desn_args = desn_args_workflow,
      vb_args = with_exact(vb_online),
      posterior_as_prior = TRUE,
      keep_fits = TRUE,
      keep_states = TRUE
    )
  })
  workflow_rows[[length(workflow_rows) + 1L]] <- workflow_summary("qdesn_al_ridge_online_exact", online_exact, tm_online_exact[["elapsed"]])

  workflow_target_diagnostics <- rbind_fill(workflow_rows)
  workflow_exact_rows[[1L]] <- data.frame(
    comparison_type = "online_exact_chunking",
    reference_method = "qdesn_al_ridge_online",
    candidate_method = "qdesn_al_ridge_online_exact",
    final_beta_l2_abs_diff = abs(tail(online$summary$beta_l2, 1L) - tail(online_exact$summary$beta_l2, 1L)),
    final_sigma_mean_abs_diff = abs(tail(online$summary$sigma_mean, 1L) - tail(online_exact$summary$sigma_mean, 1L)),
    final_gamma_mean_abs_diff = abs(tail(online$summary$gamma_mean, 1L) - tail(online_exact$summary$gamma_mean, 1L)),
    no_future_leakage_reference = isTRUE(online$target$no_future_leakage),
    no_future_leakage_candidate = isTRUE(online_exact$target$no_future_leakage),
    passed = isTRUE(online$target$no_future_leakage) && isTRUE(online_exact$target$no_future_leakage),
    stringsAsFactors = FALSE
  )
  target_changing_diagnostics <- rbind_fill(list(target_changing_diagnostics, workflow_target_diagnostics, rbind_fill(workflow_exact_rows)))
} else {
  cat("Skipping rolling/posterior-as-prior/online workflow diagnostics by request.\n")
  target_changing_diagnostics <- rbind_fill(list(
    target_changing_diagnostics,
    data.frame(
      method_id = "qdesn_al_ridge_workflows",
      target_label = "workflow_skipped",
      preserves_full_data_target = NA,
      order_sensitive = NA,
      posterior_as_prior = NA,
      no_future_leakage = NA,
      reason = "Skipped with --skip-workflows; source-scale gate focuses on implemented static/readout modes.",
      stringsAsFactors = FALSE
    )
  ))
}

forbidden_attempt <- function(method, expr, pattern = NULL) {
  msg <- tryCatch({
    force(expr)
    NA_character_
  }, error = function(e) conditionMessage(e))
  data.frame(
    method = method,
    attempted = TRUE,
    failed_early = is.character(msg) && !is.na(msg) &&
      (is.null(pattern) || grepl(pattern, msg, fixed = TRUE)),
    message = as.character(msg),
    reason = NA_character_,
    stringsAsFactors = FALSE
  )
}

bad_exal_stochastic <- utils::modifyList(exal_ridge, list(max_iter = 5L, chunking = stochastic_chunking))
bad_exal_rhs_diag <- with_cov_diag(exal_rhs)
forbidden_modes <- rbind_fill(list(
  forbidden_attempt(
    "qdesn_exal_stochastic",
    do.call(exdqlm::qdesn_fit_vb, c(list(y = series$y), desn_args, list(vb_args = bad_exal_stochastic))),
    "stochastic exAL VB chunking is not implemented"
  ),
  forbidden_attempt(
    "qdesn_exal_rhs_diagonal_covariance",
    do.call(exdqlm::qdesn_fit_vb, c(list(y = series$y), desn_args, list(vb_args = bad_exal_rhs_diag))),
    "exAL diagonal beta covariance approximation is currently supported only for ridge beta priors"
  ),
  data.frame(
    method = "divide_and_combine_vb",
    attempted = FALSE,
    failed_early = NA,
    message = NA_character_,
    reason = "Explicitly deferred research mode.",
    stringsAsFactors = FALSE
  ),
  data.frame(
    method = "variational_coresets",
    attempted = FALSE,
    failed_early = NA,
    message = NA_character_,
    reason = "Explicitly deferred research mode.",
    stringsAsFactors = FALSE
  )
))

repo_state <- data.frame(
  repo = repo_root,
  branch = git_value(c("rev-parse", "--abbrev-ref", "HEAD")),
  head = git_value(c("rev-parse", "HEAD")),
  upstream = git_value(c("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")),
  source_dir = source_dir,
  source_n_rows = source_n_rows,
  selected_n_rows = nrow(series),
  tail_rows = if (is.na(tail_rows)) NA_integer_ else as.integer(tail_rows),
  n_rows = nrow(series),
  source_index_min = min(selection$source_index),
  source_index_max = max(selection$source_index),
  seed = seed,
  qdesn_seed = qdesn_seed,
  D = qdesn_D,
  reservoir_n = qdesn_n,
  m = qdesn_m,
  washout = qdesn_washout,
  effective_rows = effective_rows,
  expected_effective_rows = if (is.na(expected_effective_rows)) NA_integer_ else as.integer(expected_effective_rows),
  skip_workflows = isTRUE(skip_workflows),
  subset_size = subset_size,
  chunk_size = chunk_size,
  max_iter = max_iter,
  stochastic_max_iter = stochastic_max_iter,
  hybrid_max_iter = hybrid_max_iter,
  hybrid_full_every = hybrid_full_every,
  exact_tolerance = exact_tolerance,
  exact_relative_tolerance = exact_relative_tolerance,
  cores = cores,
  package_sha = hash_or_na(exdqlm:::.qdesn_vb_package_sha()),
  stringsAsFactors = FALSE
)

dataset_summary <- rbind_fill(list(
  data.frame(
    variable = "metadata",
    n = nrow(series),
    min = NA_real_, q1 = NA_real_, median = NA_real_, mean = NA_real_,
    q3 = NA_real_, max = NA_real_, sd = NA_real_,
    source_index_min = min(selection$source_index),
    source_index_max = max(selection$source_index),
    source_n_rows = source_n_rows,
    selected_n_rows = nrow(series),
    tail_rows = if (is.na(tail_rows)) NA_integer_ else as.integer(tail_rows),
    effective_rows = effective_rows,
    max_abs_mu_q_target = max(abs(series$mu - series$q_target)),
    missing_y = sum(is.na(series$y)),
    missing_mu = sum(is.na(series$mu)),
    missing_q_target = sum(is.na(series$q_target)),
    stringsAsFactors = FALSE
  ),
  transform(num_summary_row("y", series$y), source_index_min = NA, source_index_max = NA, max_abs_mu_q_target = NA, missing_y = NA, missing_mu = NA, missing_q_target = NA),
  transform(num_summary_row("mu", series$mu), source_index_min = NA, source_index_max = NA, max_abs_mu_q_target = NA, missing_y = NA, missing_mu = NA, missing_q_target = NA),
  transform(num_summary_row("q_target", series$q_target), source_index_min = NA, source_index_max = NA, max_abs_mu_q_target = NA, missing_y = NA, missing_mu = NA, missing_q_target = NA),
  transform(num_summary_row("eps", series$eps), source_index_min = NA, source_index_max = NA, max_abs_mu_q_target = NA, missing_y = NA, missing_mu = NA, missing_q_target = NA)
))

write_csv(repo_state, file.path(output_dir, "repo_state.csv"))
write_csv(dataset_summary, file.path(output_dir, "dataset_summary.csv"))
write_csv(method_summary, file.path(output_dir, "method_summary.csv"))
write_csv(prediction_metrics, file.path(output_dir, "prediction_metrics.csv"))
write_csv(predictions, file.path(output_dir, "predictions_by_method.csv"))
write_csv(exact_equivalence, file.path(output_dir, "exact_equivalence.csv"))
write_csv(approximate_diagnostics, file.path(output_dir, "approximate_diagnostics.csv"))
write_csv(target_changing_diagnostics, file.path(output_dir, "target_changing_diagnostics.csv"))
write_csv(forbidden_modes, file.path(output_dir, "forbidden_modes.csv"))

md_table <- function(df, con) {
  cols <- names(df)
  writeLines(paste0("| ", paste(cols, collapse = " | "), " |"), con)
  writeLines(paste0("| ", paste(rep("---", length(cols)), collapse = " | "), " |"), con)
  for (i in seq_len(nrow(df))) {
    vals <- vapply(df[i, , drop = FALSE], function(x) {
      x <- x[[1L]]
      if (is.numeric(x)) format(x, digits = 8, scientific = TRUE) else as.character(x)
    }, character(1))
    writeLines(paste0("| ", paste(vals, collapse = " | "), " |"), con)
  }
}

summary_path <- file.path(output_dir, "implemented_modes_comparison_summary.md")
con <- file(summary_path, open = "wt")
on.exit(close(con), add = TRUE)
writeLines("# Q-DESN VB Implemented-Mode Source Median Comparison", con)
writeLines("", con)
writeLines(paste0("Source: `", source_dir, "`"), con)
writeLines("", con)
writeLines("The univariate Q-DESN is fit to `y` only. `mu`/`q_target` are median diagnostics.", con)
writeLines("", con)
writeLines("## Repo State", con)
md_table(repo_state, con)
writeLines("", con)
writeLines("## Dataset", con)
md_table(dataset_summary, con)
writeLines("", con)
writeLines("## Method Summary", con)
md_table(method_summary[, c(
  "method_id", "likelihood_family", "prior_family", "covariance_form",
  "chunking_mode", "target_label", "preserves_full_data_target",
  "approximate", "target_changes", "converged", "iter", "elapsed_sec",
  "finite_state", "pinball_y", "rmse_q_target"
)], con)
writeLines("", con)
writeLines("## Exact Equivalence", con)
md_table(exact_equivalence[, c(
  "comparison_type", "reference_method", "candidate_method",
  "max_gate_diff", "relative_gate_diff", "tolerance", "relative_tolerance", "passed"
)], con)
writeLines("", con)
writeLines("## Approximate Diagnostics", con)
md_table(approximate_diagnostics[, c(
  "comparison_type", "reference_method", "candidate_method", "target_label",
  "finite_state", "beta_mean_max_abs_diff_vs_reference",
  "fitted_median_max_abs_diff_vs_reference", "pinball_diff_vs_reference"
)], con)
writeLines("", con)
writeLines("## Target-Changing Diagnostics", con)
md_table(target_changing_diagnostics, con)
writeLines("", con)
writeLines("## Forbidden/Deferred Modes", con)
md_table(forbidden_modes, con)

cat("Wrote outputs to", output_dir, "\n")
cat("Summary:", summary_path, "\n")

if (!all(method_summary$finite_state)) {
  stop("At least one implemented-mode fit has a non-finite state.", call. = FALSE)
}
if (!all(exact_equivalence$passed)) {
  stop("At least one exact-equivalence gate failed.", call. = FALSE)
}
stoch_row <- approximate_diagnostics[approximate_diagnostics$candidate_method == "qdesn_al_ridge_stochastic", , drop = FALSE]
hybrid_row <- approximate_diagnostics[approximate_diagnostics$candidate_method == "qdesn_al_ridge_hybrid", , drop = FALSE]
hybrid_exal_rows <- approximate_diagnostics[approximate_diagnostics$comparison_type == "hybrid_exal", , drop = FALSE]
if (!nrow(stoch_row) || !isTRUE(stoch_row$finite_state) ||
    !is.finite(stoch_row$reproducible_beta_mean_max_abs_diff) ||
    stoch_row$reproducible_beta_mean_max_abs_diff > 1e-10) {
  stop("Stochastic AL reproducibility/finite-state gate failed.", call. = FALSE)
}
if (!nrow(hybrid_row) || !isTRUE(hybrid_row$finite_state) ||
    !is.finite(hybrid_row$reproducible_beta_mean_max_abs_diff) ||
    hybrid_row$reproducible_beta_mean_max_abs_diff > 1e-10) {
  stop("Hybrid AL reproducibility/finite-state gate failed.", call. = FALSE)
}
if (!nrow(hybrid_exal_rows) || !all(hybrid_exal_rows$finite_state) ||
    any(!is.finite(hybrid_exal_rows$reproducible_beta_mean_max_abs_diff)) ||
    any(hybrid_exal_rows$reproducible_beta_mean_max_abs_diff > 1e-10)) {
  stop("Hybrid exAL reproducibility/finite-state gate failed.", call. = FALSE)
}
attempted_forbidden <- forbidden_modes[isTRUE(forbidden_modes$attempted), , drop = FALSE]
if (nrow(attempted_forbidden) && !all(attempted_forbidden$failed_early)) {
  stop("At least one forbidden mode did not fail early as expected.", call. = FALSE)
}

cat("All implemented-mode comparison gates passed.\n")
