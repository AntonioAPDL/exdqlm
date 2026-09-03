# Focused single-origin ablation: current Q-DESN versus an inter-layer
# residual Q-DESN.  This workflow intentionally excludes rolling origins,
# external competitors, exAL shape estimation, MCMC, and quantile synthesis.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, alt) if (!is.null(x)) x else alt
}

#' Candidate set for the residual Q-DESN ablation
#'
#' Returns the fixed 18-run mixed-level screening design plus the current
#' central anchor.  Only D, n, m, alpha, and rho vary.
#'
#' @return A data frame with 19 pre-specified candidates.
#' @export
qdesn_residual_ablation_candidates <- function() {
  out <- data.frame(
    candidate_id = c(
      "A00",
      sprintf("C%02d", seq_len(18L))
    ),
    D = c(2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L,
          3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L),
    n = c(30L, 20L, 20L, 20L, 30L, 30L, 30L, 50L, 50L, 50L,
          20L, 20L, 20L, 30L, 30L, 30L, 50L, 50L, 50L),
    m = c(12L, 3L, 12L, 24L, 3L, 12L, 24L, 3L, 12L, 24L,
          3L, 12L, 24L, 3L, 12L, 24L, 3L, 12L, 24L),
    alpha = c(0.30, 0.10, 0.30, 0.50, 0.10, 0.30, 0.50, 0.30, 0.50, 0.10,
              0.50, 0.10, 0.30, 0.30, 0.50, 0.10, 0.50, 0.10, 0.30),
    rho = c(0.85, 0.70, 0.85, 0.95, 0.85, 0.95, 0.70, 0.95, 0.70, 0.85,
            0.85, 0.95, 0.70, 0.70, 0.85, 0.95, 0.95, 0.70, 0.85),
    stringsAsFactors = FALSE
  )
  stopifnot(nrow(out) == 19L, !anyDuplicated(out$candidate_id))
  out
}

#' Fixed protocol for the residual Q-DESN ablation
#'
#' @return A list documenting the immutable split, likelihood, prior, and
#'   computational settings.  The RHS global scale is `tau0 = 0.1`.
#' @export
qdesn_residual_ablation_protocol <- function() {
  list(
    series_length = 1100L,
    validation = list(
      observed_end = 900L,
      washout = 500L,
      readout_start = 501L,
      readout_end = 900L,
      origin = 900L,
      target_start = 901L,
      target_end = 1000L,
      horizon = 100L
    ),
    final = list(
      observed_end = 1000L,
      washout = 500L,
      readout_start = 501L,
      readout_end = 1000L,
      origin = 1000L,
      target_start = 1001L,
      target_end = 1100L,
      horizon = 100L
    ),
    p_vec = c(0.50, 0.75, 0.95),
    likelihood_family = "al",
    al_fixed_gamma = 0,
    inference = "vb",
    beta_prior = "rhs_ns",
    rhs_tau0 = 0.1,
    tuned = c("D", "n", "m", "alpha", "rho"),
    fixed = list(
      n_tilde = "equal to lower-layer width",
      skip_scale = 1,
      pi_w = 0.10,
      pi_in = 1.00,
      act_f = "tanh",
      act_k = "identity",
      standardize_inputs = TRUE,
      standardize_response = TRUE,
      standardize_readout = TRUE,
      add_bias = TRUE
    ),
    screening = list(seeds = c(1101L, 1102L), nd = 400L),
    confirmation = list(
      additional_seeds = c(1201L, 1202L, 1203L, 1204L),
      all_seeds = c(1101L, 1102L, 1201L, 1202L, 1203L, 1204L),
      nd = 1000L,
      reuse_screening_fits = TRUE
    ),
    final_evaluation = list(
      seeds = 1301:1310,
      nd = 2000L,
      horizon_blocks = list(c(1L, 10L), c(11L, 30L), c(31L, 60L), c(61L, 100L))
    )
  )
}

.qdesn_ablation_seed <- function(...) {
  txt <- paste(..., collapse = "|")
  values <- utf8ToInt(enc2utf8(txt))
  hash <- 104729
  modulus <- 2147483629
  for (value in values) hash <- (hash * 33 + value) %% modulus
  as.integer(max(1, floor(hash)))
}

.qdesn_ablation_noise <- function(H, nd, seed) {
  set.seed(as.integer(seed)[1L])
  list(
    exp = matrix(stats::rexp(H * nd), nrow = H, ncol = nd),
    z = matrix(stats::rnorm(H * nd), nrow = H, ncol = nd)
  )
}

.qdesn_pinball <- function(y, qhat, p) {
  u <- as.numeric(y) - as.numeric(qhat)
  u * (p - (u < 0))
}

.qdesn_horizon_block <- function(h) {
  cut(
    h,
    breaks = c(0, 10, 30, 60, 100),
    labels = c("01-10", "11-30", "31-60", "61-100"),
    include.lowest = TRUE,
    right = TRUE
  )
}

.qdesn_cache_compute <- function(path, resume, fun) {
  if (isTRUE(resume) && file.exists(path)) return(readRDS(path))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  value <- fun()
  tmp <- paste0(path, ".tmp-", Sys.getpid())
  saveRDS(value, tmp)
  if (!file.rename(tmp, path)) {
    unlink(tmp)
    stop("Could not atomically write cache file: ", path, call. = FALSE)
  }
  value
}


.qdesn_vb_status <- function(fit) {
  converged_values <- c(
    fit$converged %||% NULL,
    fit$misc$converged %||% NULL,
    fit$diagnostics$converged %||% NULL,
    fit$trace$converged %||% NULL
  )
  converged_values <- as.logical(unlist(converged_values, use.names = FALSE))
  converged_values <- converged_values[!is.na(converged_values)]

  iter_values <- c(
    fit$iter %||% NULL,
    fit$n_iter %||% NULL,
    fit$misc$iter %||% NULL,
    fit$misc$n_iter %||% NULL,
    fit$diagnostics$n_iter %||% NULL
  )
  iter_values <- suppressWarnings(as.integer(unlist(iter_values, use.names = FALSE)))
  iter_values <- iter_values[is.finite(iter_values)]

  list(
    converged = if (length(converged_values)) all(converged_values) else NA,
    iterations = if (length(iter_values)) max(iter_values) else NA_integer_
  )
}

.qdesn_candidate_list <- function(candidate) {
  list(
    candidate_id = as.character(candidate$candidate_id[[1L]]),
    D = as.integer(candidate$D[[1L]]),
    n = as.integer(candidate$n[[1L]]),
    m = as.integer(candidate$m[[1L]]),
    alpha = as.numeric(candidate$alpha[[1L]]),
    rho = as.numeric(candidate$rho[[1L]])
  )
}

.qdesn_architecture_design_name <- function(architecture) {
  switch(
    architecture,
    plain = "plain",
    interlayer_residual = "interlayer_residual",
    stop("Unknown architecture: ", architecture, call. = FALSE)
  )
}

.qdesn_ablation_design_pair <- function(y_observed, candidate, reservoir_seed,
                                        skip_scale, fixed, cache_path, resume) {
  cand <- .qdesn_candidate_list(candidate)
  .qdesn_cache_compute(cache_path, resume, function() {
    qdesn_build_paired_architecture_designs(
      y = y_observed,
      D = cand$D,
      n = cand$n,
      n_tilde = if (cand$D <= 1L) integer(0) else rep(cand$n, cand$D - 1L),
      m = cand$m,
      alpha = cand$alpha,
      rho = cand$rho,
      pi_w = fixed$pi_w,
      pi_in = fixed$pi_in,
      washout = fixed$washout,
      add_bias = fixed$add_bias,
      standardize_inputs = fixed$standardize_inputs,
      input_bound = fixed$input_bound,
      act_f = fixed$act_f,
      act_k = fixed$act_k,
      seed = reservoir_seed,
      skip_scale = skip_scale
    )
  })
}

.qdesn_ablation_fit_forecast_cell <- function(
    design,
    y_observed,
    p0,
    tau0,
    H,
    nd,
    stage,
    candidate_id,
    reservoir_seed,
    architecture,
    vb_control,
    standardize_readout,
    fit_cache_path,
    forecast_cache_path,
    resume) {
  # Fitting depends on the observed history, architecture, candidate, seed, and
  # quantile, but not on whether the result is used for screening or
  # confirmation.  A phase-level fit cache therefore lets confirmation increase
  # the Monte Carlo path count without repeating the VB optimization.
  fit_seed <- .qdesn_ablation_seed(
    "fit", length(y_observed), candidate_id, reservoir_seed, p0
  )
  fit_cache <- .qdesn_cache_compute(fit_cache_path, resume, function() {
    started <- proc.time()[3]
    ans <- tryCatch({
      fit_object <- qdesn_fit_al_vb_from_design(
        design = design,
        p0 = p0,
        tau0 = tau0,
        standardize_readout = standardize_readout,
        vb_control = vb_control,
        fit_seed = fit_seed
      )
      status <- .qdesn_vb_status(fit_object$fit)
      list(
        ok = TRUE,
        error = NA_character_,
        readout_fit = fit_object$fit,
        readout_scale = fit_object$meta$readout_scale,
        vb_converged = status$converged,
        vb_iterations = status$iterations
      )
    }, error = function(e) {
      list(
        ok = FALSE,
        error = conditionMessage(e),
        readout_fit = NULL,
        readout_scale = NULL,
        vb_converged = FALSE,
        vb_iterations = NA_integer_
      )
    })
    ans$fit_runtime_sec <- as.numeric(proc.time()[3] - started)
    ans$fit_seed <- fit_seed
    ans
  })

  posterior_seed <- .qdesn_ablation_seed(
    stage, candidate_id, reservoir_seed, p0, "posterior"
  )
  noise_seed <- .qdesn_ablation_seed(
    stage, candidate_id, reservoir_seed, p0, "forecast-noise"
  )

  forecast_cache <- .qdesn_cache_compute(forecast_cache_path, resume, function() {
    if (!isTRUE(fit_cache$ok)) {
      return(list(
        ok = FALSE,
        error = fit_cache$error,
        qhat = rep(NA_real_, H),
        forecast_runtime_sec = 0,
        posterior_seed = posterior_seed,
        noise_seed = noise_seed,
        n_paths = nd
      ))
    }

    forecast_object <- design
    forecast_object$fit <- fit_cache$readout_fit
    forecast_object$meta$p0 <- p0
    forecast_object$meta$likelihood_family <- "al"
    forecast_object$meta$al_fixed_gamma <- 0
    forecast_object$meta$rhs_tau0 <- tau0
    forecast_object$meta$readout_scale <- fit_cache$readout_scale
    forecast_object$meta$standardize_readout <- isTRUE(standardize_readout)
    forecast_object$meta$fit_seed <- fit_seed
    class(forecast_object) <- "qdesn_fit"

    noise <- .qdesn_ablation_noise(H = H, nd = nd, seed = noise_seed)
    started <- proc.time()[3]
    ans <- tryCatch({
      forecast <- qdesn_forecast_single_origin_al_vb(
        object = forecast_object,
        y_history = y_observed,
        H = H,
        nd = nd,
        posterior_seed = posterior_seed,
        noise_draws = noise
      )
      list(
        ok = TRUE,
        error = NA_character_,
        qhat = as.numeric(forecast$qhat),
        posterior_seed = posterior_seed,
        noise_seed = noise_seed,
        n_paths = forecast$nd
      )
    }, error = function(e) {
      list(
        ok = FALSE,
        error = conditionMessage(e),
        qhat = rep(NA_real_, H),
        posterior_seed = posterior_seed,
        noise_seed = noise_seed,
        n_paths = nd
      )
    })
    ans$forecast_runtime_sec <- as.numeric(proc.time()[3] - started)
    ans
  })

  state_summary <- design$meta$state_summary %||% data.frame()
  list(
    ok = isTRUE(fit_cache$ok) && isTRUE(forecast_cache$ok),
    error = if (!isTRUE(fit_cache$ok)) fit_cache$error else forecast_cache$error,
    qhat = as.numeric(forecast_cache$qhat),
    vb_converged = fit_cache$vb_converged,
    vb_iterations = fit_cache$vb_iterations,
    max_abs_state = if (nrow(state_summary)) max(state_summary$max_abs_state, na.rm = TRUE) else NA_real_,
    max_abs_preactivation = if (nrow(state_summary)) max(state_summary$max_abs_preactivation, na.rm = TRUE) else NA_real_,
    tanh_saturation_rate = if (nrow(state_summary)) mean(state_summary$tanh_saturation_rate, na.rm = TRUE) else NA_real_,
    state_finite = if (nrow(state_summary)) all(state_summary$finite) else all(is.finite(unlist(design$states$H_all))),
    fit_runtime_sec = as.numeric(fit_cache$fit_runtime_sec %||% NA_real_),
    forecast_runtime_sec = as.numeric(forecast_cache$forecast_runtime_sec %||% NA_real_),
    runtime_sec = as.numeric(fit_cache$fit_runtime_sec %||% 0) +
      as.numeric(forecast_cache$forecast_runtime_sec %||% 0),
    posterior_seed = posterior_seed,
    noise_seed = noise_seed,
    fit_seed = fit_seed,
    n_paths = as.integer(forecast_cache$n_paths %||% nd),
    architecture = architecture,
    p0 = p0
  )
}
