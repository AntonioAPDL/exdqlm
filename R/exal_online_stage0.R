# Deterministic Stage-0 baseline benchmark for online VB-LD (single quantile)

.online_stage0_round_numeric <- function(x, digits = 12L) {
  if (is.numeric(x)) return(round(x, digits = digits))
  if (is.matrix(x)) return(round(x, digits = digits))
  if (is.data.frame(x)) {
    out <- x
    for (nm in names(out)) {
      if (is.numeric(out[[nm]])) out[[nm]] <- round(out[[nm]], digits = digits)
    }
    return(out)
  }
  if (is.list(x)) return(lapply(x, .online_stage0_round_numeric, digits = digits))
  x
}

.online_stage0_hash_object <- function(x, digits = 12L) {
  obj <- .online_stage0_round_numeric(x, digits = digits)
  raw_vec <- serialize(obj, connection = NULL, version = 2L)
  tf <- tempfile("online_stage0_hash_", fileext = ".bin")
  on.exit(unlink(tf), add = TRUE)
  con <- file(tf, open = "wb")
  writeBin(raw_vec, con)
  close(con)
  as.character(unname(tools::md5sum(tf)))
}

.online_stage0_check_loss <- function(y, mu, p0) {
  u <- as.numeric(y - mu)
  mean(u * (p0 - as.numeric(u < 0)))
}

.online_stage0_fixture <- function(seed, n, k) {
  seed <- as.integer(seed)[1L]
  n <- as.integer(n)[1L]
  k <- as.integer(k)[1L]
  if (!is.finite(seed)) .stopf("stage0 fixture: seed must be finite integer.")
  if (!is.finite(n) || n < 16L) .stopf("stage0 fixture: n must be >= 16.")
  if (!is.finite(k) || k < 2L) .stopf("stage0 fixture: k must be >= 2.")

  set.seed(seed)
  X <- cbind(1, matrix(rnorm(n * (k - 1L)), nrow = n, ncol = k - 1L))
  beta_tpl <- c(0.65, -0.55, 0.35, 0.20, -0.15, 0.10, -0.07, 0.04)
  beta_true <- rep(beta_tpl, length.out = k)
  eps <- 0.35 * rt(n, df = 8)
  trend <- seq(-0.20, 0.20, length.out = n)
  y <- as.numeric(X %*% beta_true + 0.15 * sin(seq_len(n) / 5) + trend + eps)

  list(y = y, X = X, beta_true = beta_true, seed = seed, n = n, k = k)
}

.online_stage0_run_once <- function(dat,
                                    t0,
                                    p0,
                                    ridge_tau2,
                                    batch_vb_control,
                                    online_control,
                                    run_seed,
                                    return_trace = TRUE) {
  set.seed(as.integer(run_seed)[1L])

  y <- dat$y
  X <- dat$X
  n <- nrow(X)
  k <- ncol(X)
  t0 <- as.integer(t0)[1L]

  beta_obj <- beta_prior("ridge", ridge = list(tau2 = as.numeric(ridge_tau2)[1L]))
  gamma_bounds <- get_gamma_bounds(p0)

  t_batch_full <- system.time({
    fit_full <- exal_ldvb_fit(
      y = y,
      X = X,
      p0 = p0,
      gamma_bounds = gamma_bounds,
      vb_control = batch_vb_control,
      beta_prior_obj = beta_obj
    )
  })["elapsed"]

  t_batch_init <- system.time({
    fit_init <- exal_ldvb_fit(
      y = y[seq_len(t0)],
      X = X[seq_len(t0), , drop = FALSE],
      p0 = p0,
      gamma_bounds = gamma_bounds,
      vb_control = batch_vb_control,
      beta_prior_obj = beta_obj
    )
  })["elapsed"]

  st <- exal_online_init(
    y = y[seq_len(t0)],
    X = X[seq_len(t0), , drop = FALSE],
    p0 = p0,
    gamma_bounds = gamma_bounds,
    control = online_control,
    batch_fit = fit_init,
    beta_prior_obj = beta_obj
  )

  idx_new <- seq.int(t0 + 1L, n)
  t_online <- system.time({
    out <- exal_online_run(
      state = st,
      y_new = y[idx_new],
      X_new = X[idx_new, , drop = FALSE],
      keep_trace = isTRUE(return_trace)
    )
  })["elapsed"]

  if (isTRUE(return_trace)) {
    st <- out$state
    trace <- out$trace
  } else {
    st <- out
    trace <- NULL
  }

  pred_batch <- as.numeric(X %*% fit_full$qbeta$m)
  pred_online <- as.numeric(X %*% st$qbeta$m)

  metrics <- list(
    l2_beta_mu = as.numeric(sqrt(sum((st$qbeta$m - fit_full$qbeta$m)^2))),
    linf_beta_mu = as.numeric(max(abs(st$qbeta$m - fit_full$qbeta$m))),
    l2_diagV = as.numeric(sqrt(sum((diag(st$qbeta$V) - diag(fit_full$qbeta$V))^2))),
    rmse_pred_mean = as.numeric(sqrt(mean((pred_online - pred_batch)^2))),
    check_loss_batch = as.numeric(.online_stage0_check_loss(y, pred_batch, p0)),
    check_loss_online = as.numeric(.online_stage0_check_loss(y, pred_online, p0)),
    delta_check_loss = as.numeric(
      .online_stage0_check_loss(y, pred_online, p0) - .online_stage0_check_loss(y, pred_batch, p0)
    ),
    abs_sigma_mean_diff = as.numeric(abs(st$qsiggam$sigma_mean - fit_full$qsiggam$sigma_mean)),
    abs_gamma_mean_diff = as.numeric(abs(st$qsiggam$gamma_mean - fit_full$qsiggam$gamma_mean))
  )

  trace_summary <- list(
    n_steps = as.integer(length(idx_new)),
    barw_min = NA_real_,
    barw_median = NA_real_,
    barw_max = NA_real_,
    barm_mean = NA_real_,
    rhs_refresh_events = NA_integer_,
    sigmagam_refresh_events = NA_integer_
  )
  if (is.data.frame(trace) && nrow(trace) > 0L) {
    trace_summary <- list(
      n_steps = as.integer(nrow(trace)),
      barw_min = as.numeric(min(trace$barw)),
      barw_median = as.numeric(stats::median(trace$barw)),
      barw_max = as.numeric(max(trace$barw)),
      barm_mean = as.numeric(mean(trace$barm)),
      rhs_refresh_events = as.integer(sum(trace$rhs_refreshed)),
      sigmagam_refresh_events = as.integer(sum(trace$sigmagam_refreshed))
    )
  }

  trace_diag <- NULL
  if (is.data.frame(trace) && nrow(trace) > 0L) {
    trace_diag <- exal_online_trace_diagnostics(trace = trace, p0 = p0, rolling_window = 20L)
  }

  health <- exal_online_health_check(st, trace = trace, p0 = p0, rolling_window = 20L)

  hash_payload <- list(
    n = n,
    k = k,
    t0 = t0,
    p0 = p0,
    qbeta_online_m = as.numeric(st$qbeta$m),
    qbeta_batch_m = as.numeric(fit_full$qbeta$m),
    qbeta_online_diagV = as.numeric(diag(st$qbeta$V)),
    qbeta_batch_diagV = as.numeric(diag(fit_full$qbeta$V)),
    qsiggam_online = c(
      eta = as.numeric(st$qsiggam$eta_hat),
      ell = as.numeric(st$qsiggam$ell_hat),
      sigma_mean = as.numeric(st$qsiggam$sigma_mean),
      gamma_mean = as.numeric(st$qsiggam$gamma_mean)
    ),
    qsiggam_batch = c(
      eta = as.numeric(fit_full$qsiggam$eta_hat),
      ell = as.numeric(fit_full$qsiggam$ell_hat),
      sigma_mean = as.numeric(fit_full$qsiggam$sigma_mean),
      gamma_mean = as.numeric(fit_full$qsiggam$gamma_mean)
    ),
    metrics = metrics,
    health = health,
    trace_diag = trace_diag,
    refresh_counts = st$refresh_counts
  )

  list(
    hash = .online_stage0_hash_object(hash_payload),
    metrics = metrics,
    health = health,
    trace_summary = trace_summary,
    trace_diag = trace_diag,
    timing_sec = list(
      batch_full = as.numeric(t_batch_full),
      batch_init = as.numeric(t_batch_init),
      online = as.numeric(t_online)
    ),
    convergence = list(
      batch_full = isTRUE(fit_full$converged),
      batch_init = isTRUE(fit_init$converged)
    ),
    refresh_counts = st$refresh_counts,
    qbeta_online_m = as.numeric(st$qbeta$m),
    qbeta_batch_m = as.numeric(fit_full$qbeta$m),
    trace = trace
  )
}

#' Deterministic Stage-0 baseline benchmark for online VB-LD
#'
#' Runs a fixed-seed benchmark that compares:
#' - full batch VB-LD on all data,
#' - online VB-LD initialized on a prefix and updated sequentially.
#'
#' The benchmark reports alignment metrics, health diagnostics, timings, and
#' a deterministic hash. Optionally, it runs the same benchmark twice and checks
#' hash equality to validate reproducibility.
#'
#' @param seed Integer fixture seed.
#' @param n Integer sample size for fixture.
#' @param k Integer design dimension (includes intercept column).
#' @param t0 Integer warm-start prefix size used for online initialization.
#' @param p0 Quantile level in (0,1).
#' @param ridge_tau2 Ridge prior variance used in the benchmark.
#' @param batch_vb_control List of controls forwarded to `exal_ldvb_fit()`.
#' @param online_control List of controls forwarded to `exal_online_init()`.
#' @param check_repro Logical; if `TRUE`, run the benchmark twice and compare hashes.
#' @param return_trace Logical; if `TRUE`, include per-step trace for each run.
#' @return List with benchmark config, run summaries, and reproducibility check.
#' @export
exal_online_stage0_benchmark <- function(
    seed = 20260223L,
    n = 72L,
    k = 5L,
    t0 = 48L,
    p0 = 0.5,
    ridge_tau2 = 5,
    batch_vb_control = list(max_iter = 35L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE),
    online_control = list(M = 2L, K = 4L, W = 24L, L_loc = 2L, window_passes = 1L, jitter = 1e-10),
    check_repro = TRUE,
    return_trace = TRUE) {

  assert_scalar_numeric(p0, "p0")
  if (!(p0 > 0 && p0 < 1)) .stopf("p0 must be in (0,1).")

  n <- as.integer(n)[1L]
  k <- as.integer(k)[1L]
  t0 <- as.integer(t0)[1L]
  if (!is.finite(n) || !is.finite(k) || !is.finite(t0)) .stopf("n, k, t0 must be finite integers.")
  if (n < 16L) .stopf("n must be >= 16.")
  if (k < 2L) .stopf("k must be >= 2.")
  if (t0 <= k + 2L || t0 >= n) .stopf("t0 must satisfy k+2 < t0 < n.")

  if (!is.list(batch_vb_control)) .stopf("batch_vb_control must be a list.")
  if (!is.list(online_control)) .stopf("online_control must be a list.")

  batch_vb_control <- modifyList(
    list(max_iter = 35L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE),
    batch_vb_control
  )
  online_control <- modifyList(
    list(M = 2L, K = 4L, W = 24L, L_loc = 2L, window_passes = 1L, jitter = 1e-10),
    online_control
  )

  dat <- .online_stage0_fixture(seed = as.integer(seed)[1L], n = n, k = k)
  run_seed <- as.integer(seed)[1L] + 1000L

  run1 <- .online_stage0_run_once(
    dat = dat,
    t0 = t0,
    p0 = p0,
    ridge_tau2 = ridge_tau2,
    batch_vb_control = batch_vb_control,
    online_control = online_control,
    run_seed = run_seed,
    return_trace = return_trace
  )

  run2 <- NULL
  hashes_equal <- NA
  max_abs_beta_mu_diff <- NA_real_
  if (isTRUE(check_repro)) {
    run2 <- .online_stage0_run_once(
      dat = dat,
      t0 = t0,
      p0 = p0,
      ridge_tau2 = ridge_tau2,
      batch_vb_control = batch_vb_control,
      online_control = online_control,
      run_seed = run_seed,
      return_trace = return_trace
    )
    hashes_equal <- identical(run1$hash, run2$hash)
    max_abs_beta_mu_diff <- as.numeric(max(abs(run1$qbeta_online_m - run2$qbeta_online_m)))
  }

  list(
    benchmark = "online_vbld_stage0",
    created_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
    config = list(
      seed = as.integer(seed)[1L],
      n = n,
      k = k,
      t0 = t0,
      p0 = as.numeric(p0),
      ridge_tau2 = as.numeric(ridge_tau2),
      batch_vb_control = batch_vb_control,
      online_control = online_control
    ),
    run1 = run1,
    run2 = run2,
    reproducibility = list(
      check_repro = isTRUE(check_repro),
      hash_run1 = run1$hash,
      hash_run2 = if (is.null(run2)) NA_character_ else run2$hash,
      hashes_equal = hashes_equal,
      max_abs_beta_mu_diff = max_abs_beta_mu_diff
    )
  )
}

#' Persist Stage-0 benchmark artifacts to disk
#'
#' Writes benchmark outputs to an output directory:
#' - `stage0_baseline_summary.rds` (always),
#' - `stage0_baseline_summary.json` (if `jsonlite` is available),
#' - trace CSV files (if present and requested).
#'
#' @param benchmark_result Result from `exal_online_stage0_benchmark()`.
#' @param out_dir Output directory.
#' @param write_trace Logical; if `TRUE`, write trace CSV files when available.
#' @return Named list with paths for written artifacts.
#' @export
exal_online_stage0_write_artifacts <- function(benchmark_result, out_dir,
                                               write_trace = TRUE) {
  if (!is.list(benchmark_result) || is.null(benchmark_result$run1)) {
    .stopf("benchmark_result must come from exal_online_stage0_benchmark().")
  }
  out_dir <- as.character(out_dir)[1L]
  if (!nzchar(out_dir)) .stopf("out_dir must be a non-empty path.")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  p_rds <- file.path(out_dir, "stage0_baseline_summary.rds")
  saveRDS(benchmark_result, p_rds)

  p_json <- NA_character_
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    p_json <- file.path(out_dir, "stage0_baseline_summary.json")
    json_obj <- benchmark_result
    if (!is.null(json_obj$run1$trace)) json_obj$run1$trace <- NULL
    if (!is.null(json_obj$run2) && !is.null(json_obj$run2$trace)) json_obj$run2$trace <- NULL
    jsonlite::write_json(json_obj, path = p_json, pretty = TRUE, auto_unbox = TRUE, digits = NA)
  }

  p_trace1 <- NA_character_
  p_trace2 <- NA_character_
  if (isTRUE(write_trace)) {
    if (is.data.frame(benchmark_result$run1$trace)) {
      p_trace1 <- file.path(out_dir, "stage0_run1_trace.csv")
      utils::write.csv(benchmark_result$run1$trace, file = p_trace1, row.names = FALSE)
    }
    if (!is.null(benchmark_result$run2) && is.data.frame(benchmark_result$run2$trace)) {
      p_trace2 <- file.path(out_dir, "stage0_run2_trace.csv")
      utils::write.csv(benchmark_result$run2$trace, file = p_trace2, row.names = FALSE)
    }
  }

  invisible(list(
    out_dir = out_dir,
    rds = p_rds,
    json = p_json,
    trace_run1_csv = p_trace1,
    trace_run2_csv = p_trace2
  ))
}
