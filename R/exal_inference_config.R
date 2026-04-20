.exal_default_rhs_cfg <- function() {
  list(
    tau0 = 10000,
    nu = 4.0,
    s2 = 10000,
    shrink_intercept = FALSE,
    intercept_prec = 1e-24,
    n_inner = 1L,
    eta_bounds = list(
      lambda = c(-12, 12),
      tau = c(-12, 12),
      c2 = c(-12, 12)
    ),
    h_curv = 1e-24,
    var_floor = 1e-24,
    verbose = FALSE,
    init_log_lambda = 0.0,
    # Keep legacy default behavior: initialize tau at exp(0)=1 unless explicitly overridden.
    init_log_tau = 0.0,
    init_log_c2 = 0.0
  )
}

.exal_default_rhs_ns_cfg <- function() {
  list(
    tau0 = 1.0,
    a_zeta = 2.0,
    b_zeta = 1.0,
    zeta2_fixed = NULL,
    s2 = 1.0,
    shrink_intercept = FALSE,
    intercept_prec = 1e-24,
    n_inner = 2L,
    var_floor = 1e-24,
    verbose = FALSE,
    init_lambda2 = 1.0,
    init_nu = 1.0,
    init_log_tau = 0.0,
    init_tau2 = NULL,
    init_xi = 1.0,
    init_zeta2 = NULL
  )
}

.exal_enforce_rhs_no_intercept_shrink <- function(rhs_cfg, context = "inference") {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  rhs_cfg <- rhs_cfg %||% list()
  rhs_cfg$shrink_intercept <- .qdesn_force_rhs_no_intercept_shrink(
    rhs_cfg$shrink_intercept %||% FALSE,
    context = context
  )
  rhs_cfg
}

.exal_default_vb_args_base <- function() {
  list(
    max_iter = 150L,
    min_iter_elbo = 10L,
    tol = 1e-4,
    n_samp_xi = 500L,
    verbose = TRUE,
    sigmagam = list(
      freeze_warmup_iters = 0L,
      force_after_warmup = TRUE,
      postwarmup_damping = 1.0,
      postwarmup_damping_iters = 0L,
      min_postwarmup_updates = 0L
    )
  )
}

.exal_default_vb_online_cfg <- function() {
  list(
    enabled = FALSE,
    strict = FALSE,
    M = 10L,
    K = 40L,
    W = 100L,
    L_loc = 2L,
    window_passes = 1L,
    maxit_sigmagam = 500L,
    jitter = 1e-10,
    warm_start_n = NULL,
    warm_start_frac = 0.7,
    keep_trace = FALSE,
    update_rhs = TRUE,
    update_sigmagam = TRUE
  )
}

.exal_default_mcmc_control <- function() {
  list(
    n_burn = 2000L,
    n_mcmc = 1500L,
    thin = 1L,
    verbose = FALSE,
    progress_every = 100L,
    init_from_vb = TRUE,
    vb_warm_start_seed = NULL,
    vb_warm_start_control = list(),
    sigmagam = list(
      freeze_burnin_iters = 0L,
      freeze_only_during_burn = TRUE,
      force_after_warmup = TRUE,
      delay_adapt_until_after_warmup = TRUE,
      delay_laplace_refresh_until_after_warmup = TRUE
    ),
    theta = list(
      enabled = FALSE,
      freeze_burnin_iters = 0L,
      freeze_only_during_burn = TRUE,
      sparse_update_every = 1L,
      sparse_update_until_iter = 0L,
      force_first_postwarmup_update = TRUE,
      trace = TRUE
    ),
    latent_v = list(
      enabled = FALSE,
      freeze_burnin_iters = 0L,
      freeze_only_during_burn = TRUE,
      sparse_update_every = 1L,
      sparse_update_until_iter = 0L,
      force_first_postwarmup_update = TRUE,
      rescue_on_invalid = FALSE,
      rescue_strategy = "previous_state",
      rescue_max_consecutive = 0L,
      rescue_burn_only = FALSE,
      rescue_force_retry_next_iter = TRUE,
      record_rescue_trace = TRUE,
      trace = TRUE
    ),
    latent_s = list(
      enabled = FALSE,
      freeze_burnin_iters = 0L,
      freeze_only_during_burn = TRUE,
      sparse_update_every = 1L,
      sparse_update_until_iter = 0L,
      force_first_postwarmup_update = TRUE,
      trace = TRUE
    ),
    store_latent_draws = FALSE,
    store_rhs_draws = FALSE,
    transforms = list(
      use_log_sigma = FALSE,
      sigma_eta_bounds = c(-20, 20)
    ),
    conditioning = list(
      mode = "none",
      scale_metric = "sd",
      scale_floor = 1e-8,
      intercept_column = 1L,
      constant_tol = 1e-12
    ),
    precision_beta = list(
      enabled = FALSE,
      symmetrize = TRUE,
      jitter_ladder = c(0, 1e-10, 1e-8, 1e-6, 1e-4),
      eigen_fallback = FALSE,
      eigen_floor_abs = 1e-6,
      eigen_floor_rel = 1e-8,
      trace = TRUE
    ),
    rhs = list(
      freeze_tau_burnin_iters = 0L,
      freeze_tau_only_during_burn = TRUE,
      width_adapt = list(
        enabled = FALSE,
        warmup_iters = 0L,
        only_during_burn = TRUE,
        target_score_low = -1.5,
        target_score_high = 1.5,
        step_size = 0.05,
        width_min = 0.02,
        width_max = 2.5
      )
    ),
    slice = list(
      core_update_mode = "sigma_then_gamma",
      width_gamma = 1.0,
      width_rhs_lambda = 1.0,
      width_rhs_tau = 1.0,
      width_rhs_c2 = 1.0,
      width_rhs_tau_c2_block = 1.0,
      width_rhs_tau_c2_transformed_z1 = 1.0,
      width_rhs_tau_c2_transformed_z2 = 1.0,
      rhs_global_block_update = "coordinate",
      rhs_transformed_block_passes = 1L,
      core_extra_passes = 0L,
      max_steps_out = 100L,
      max_shrink = 1000L
    ),
    multi_start = list(
      enabled = FALSE,
      n_starts = 4L,
      pilot_n_burn = 120L,
      pilot_n_mcmc = 160L,
      pilot_seed = NULL,
      perturb_sd_log_tau = 0.35,
      perturb_sd_log_c2 = 0.35,
      perturb_sd_log_lambda = 0.20,
      perturb_sd_beta = 0.05,
      diagnostics = list(
        ess_min = 20,
        geweke_max = 3.0,
        half_drift_max = 0.5,
        collapse_tau_floor = 1e-7,
        collapse_beta_norm_floor = 1e-4
      )
    )
  )
}

.exal_list_or_empty <- function(x) {
  if (is.list(x)) x else list()
}

.exal_normalize_vb_sigmagam_cfg <- function(sigmagam_cfg = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  sigmagam_cfg <- .exal_list_or_empty(sigmagam_cfg)

  freeze_warmup_iters <- suppressWarnings(as.integer(
    sigmagam_cfg$freeze_warmup_iters %||%
      sigmagam_cfg$freeze_sigmagam_warmup_iters %||%
      0L
  )[1L])
  if (!is.finite(freeze_warmup_iters) || freeze_warmup_iters < 0L) freeze_warmup_iters <- 0L

  postwarmup_damping <- as.numeric(
    sigmagam_cfg$postwarmup_damping %||%
      sigmagam_cfg$sigmagam_postwarmup_damping %||%
      1.0
  )[1L]
  if (!is.finite(postwarmup_damping) || postwarmup_damping <= 0 || postwarmup_damping > 1) {
    postwarmup_damping <- 1.0
  }

  postwarmup_damping_iters <- suppressWarnings(as.integer(
    sigmagam_cfg$postwarmup_damping_iters %||%
      sigmagam_cfg$sigmagam_postwarmup_damping_iters %||%
      0L
  )[1L])
  if (!is.finite(postwarmup_damping_iters) || postwarmup_damping_iters < 0L) {
    postwarmup_damping_iters <- 0L
  }

  min_postwarmup_updates <- suppressWarnings(as.integer(
    sigmagam_cfg$min_postwarmup_updates %||%
      sigmagam_cfg$sigmagam_min_postwarmup_updates %||%
      0L
  )[1L])
  if (!is.finite(min_postwarmup_updates) || min_postwarmup_updates < 0L) {
    min_postwarmup_updates <- 0L
  }

  list(
    freeze_warmup_iters = freeze_warmup_iters,
    force_after_warmup = if (is.null(sigmagam_cfg$force_after_warmup)) TRUE else isTRUE(sigmagam_cfg$force_after_warmup),
    postwarmup_damping = postwarmup_damping,
    postwarmup_damping_iters = postwarmup_damping_iters,
    min_postwarmup_updates = min_postwarmup_updates
  )
}

.exal_normalize_mcmc_sigmagam_cfg <- function(sigmagam_cfg = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  sigmagam_cfg <- .exal_list_or_empty(sigmagam_cfg)

  freeze_burnin_iters <- suppressWarnings(as.integer(
    sigmagam_cfg$freeze_burnin_iters %||%
      sigmagam_cfg$freeze_sigmagam_burnin_iters %||%
      0L
  )[1L])
  if (!is.finite(freeze_burnin_iters) || freeze_burnin_iters < 0L) freeze_burnin_iters <- 0L

  list(
    freeze_burnin_iters = freeze_burnin_iters,
    freeze_only_during_burn = if (is.null(sigmagam_cfg$freeze_only_during_burn)) TRUE else isTRUE(sigmagam_cfg$freeze_only_during_burn),
    force_after_warmup = if (is.null(sigmagam_cfg$force_after_warmup)) TRUE else isTRUE(sigmagam_cfg$force_after_warmup),
    delay_adapt_until_after_warmup = if (is.null(sigmagam_cfg$delay_adapt_until_after_warmup)) TRUE else isTRUE(sigmagam_cfg$delay_adapt_until_after_warmup),
    delay_laplace_refresh_until_after_warmup = if (is.null(sigmagam_cfg$delay_laplace_refresh_until_after_warmup)) TRUE else isTRUE(sigmagam_cfg$delay_laplace_refresh_until_after_warmup)
  )
}

.exal_normalize_mcmc_latent_v_cfg <- function(latent_v_cfg = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  latent_v_cfg <- .exal_list_or_empty(latent_v_cfg)

  freeze_burnin_iters <- suppressWarnings(as.integer(
    latent_v_cfg$freeze_burnin_iters %||%
      latent_v_cfg$freeze_latent_v_burnin_iters %||%
      0L
  )[1L])
  if (!is.finite(freeze_burnin_iters) || freeze_burnin_iters < 0L) freeze_burnin_iters <- 0L

  sparse_update_every <- suppressWarnings(as.integer(
    latent_v_cfg$sparse_update_every %||%
      latent_v_cfg$update_every_warmup %||%
      1L
  )[1L])
  if (!is.finite(sparse_update_every) || sparse_update_every < 1L) sparse_update_every <- 1L

  sparse_update_until_iter <- suppressWarnings(as.integer(
    latent_v_cfg$sparse_update_until_iter %||%
      latent_v_cfg$update_every_warmup_iters %||%
      0L
  )[1L])
  if (!is.finite(sparse_update_until_iter) || sparse_update_until_iter < 0L) {
    sparse_update_until_iter <- 0L
  }
  if (sparse_update_every <= 1L) sparse_update_until_iter <- max(0L, sparse_update_until_iter)
  enabled <- if (is.null(latent_v_cfg$enabled)) {
    freeze_burnin_iters > 0L || (sparse_update_every > 1L && sparse_update_until_iter > 0L)
  } else {
    isTRUE(latent_v_cfg$enabled)
  }

  list(
    enabled = isTRUE(enabled),
    freeze_burnin_iters = freeze_burnin_iters,
    freeze_only_during_burn = if (is.null(latent_v_cfg$freeze_only_during_burn)) TRUE else isTRUE(latent_v_cfg$freeze_only_during_burn),
    sparse_update_every = sparse_update_every,
    sparse_update_until_iter = sparse_update_until_iter,
    force_first_postwarmup_update = if (is.null(latent_v_cfg$force_first_postwarmup_update)) TRUE else isTRUE(latent_v_cfg$force_first_postwarmup_update),
    rescue_on_invalid = if (is.null(latent_v_cfg$rescue_on_invalid)) {
      isTRUE(latent_v_cfg$rescue_enabled)
    } else {
      isTRUE(latent_v_cfg$rescue_on_invalid)
    },
    rescue_strategy = {
      strategy <- tolower(trimws(as.character(
        latent_v_cfg$rescue_strategy %||%
          latent_v_cfg$invalid_draw_strategy %||%
          "previous_state"
      )[1L]))
      if (!strategy %in% c("previous_state")) strategy <- "previous_state"
      strategy
    },
    rescue_max_consecutive = {
      max_consecutive <- suppressWarnings(as.integer(
        latent_v_cfg$rescue_max_consecutive %||%
          latent_v_cfg$max_consecutive_rescues %||%
          0L
      )[1L])
      if (!is.finite(max_consecutive) || max_consecutive < 0L) max_consecutive <- 0L
      max_consecutive
    },
    rescue_burn_only = if (is.null(latent_v_cfg$rescue_burn_only)) FALSE else isTRUE(latent_v_cfg$rescue_burn_only),
    rescue_force_retry_next_iter = if (is.null(latent_v_cfg$rescue_force_retry_next_iter)) TRUE else isTRUE(latent_v_cfg$rescue_force_retry_next_iter),
    record_rescue_trace = if (is.null(latent_v_cfg$record_rescue_trace)) {
      if (is.null(latent_v_cfg$rescue_trace)) TRUE else isTRUE(latent_v_cfg$rescue_trace)
    } else {
      isTRUE(latent_v_cfg$record_rescue_trace)
    },
    trace = if (is.null(latent_v_cfg$trace)) TRUE else isTRUE(latent_v_cfg$trace)
  )
}

.exal_normalize_mcmc_latent_s_cfg <- function(latent_s_cfg = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  latent_s_cfg <- .exal_list_or_empty(latent_s_cfg)

  freeze_burnin_iters <- suppressWarnings(as.integer(
    latent_s_cfg$freeze_burnin_iters %||%
      latent_s_cfg$freeze_latent_s_burnin_iters %||%
      0L
  )[1L])
  if (!is.finite(freeze_burnin_iters) || freeze_burnin_iters < 0L) freeze_burnin_iters <- 0L

  sparse_update_every <- suppressWarnings(as.integer(
    latent_s_cfg$sparse_update_every %||%
      latent_s_cfg$update_every_warmup %||%
      1L
  )[1L])
  if (!is.finite(sparse_update_every) || sparse_update_every < 1L) sparse_update_every <- 1L

  sparse_update_until_iter <- suppressWarnings(as.integer(
    latent_s_cfg$sparse_update_until_iter %||%
      latent_s_cfg$update_every_warmup_iters %||%
      0L
  )[1L])
  if (!is.finite(sparse_update_until_iter) || sparse_update_until_iter < 0L) {
    sparse_update_until_iter <- 0L
  }
  if (sparse_update_every <= 1L) sparse_update_until_iter <- max(0L, sparse_update_until_iter)

  enabled <- if (is.null(latent_s_cfg$enabled)) {
    freeze_burnin_iters > 0L || (sparse_update_every > 1L && sparse_update_until_iter > 0L)
  } else {
    isTRUE(latent_s_cfg$enabled)
  }

  list(
    enabled = isTRUE(enabled),
    freeze_burnin_iters = freeze_burnin_iters,
    freeze_only_during_burn = if (is.null(latent_s_cfg$freeze_only_during_burn)) TRUE else isTRUE(latent_s_cfg$freeze_only_during_burn),
    sparse_update_every = sparse_update_every,
    sparse_update_until_iter = sparse_update_until_iter,
    force_first_postwarmup_update = if (is.null(latent_s_cfg$force_first_postwarmup_update)) TRUE else isTRUE(latent_s_cfg$force_first_postwarmup_update),
    trace = if (is.null(latent_s_cfg$trace)) TRUE else isTRUE(latent_s_cfg$trace)
  )
}

.exal_normalize_mcmc_theta_cfg <- function(theta_cfg = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  theta_cfg <- .exal_list_or_empty(theta_cfg)

  freeze_burnin_iters <- suppressWarnings(as.integer(
    theta_cfg$freeze_burnin_iters %||%
      theta_cfg$freeze_theta_burnin_iters %||%
      theta_cfg$freeze_beta_burnin_iters %||%
      0L
  )[1L])
  if (!is.finite(freeze_burnin_iters) || freeze_burnin_iters < 0L) freeze_burnin_iters <- 0L

  sparse_update_every <- suppressWarnings(as.integer(
    theta_cfg$sparse_update_every %||%
      theta_cfg$update_every_warmup %||%
      1L
  )[1L])
  if (!is.finite(sparse_update_every) || sparse_update_every < 1L) sparse_update_every <- 1L

  sparse_update_until_iter <- suppressWarnings(as.integer(
    theta_cfg$sparse_update_until_iter %||%
      theta_cfg$update_every_warmup_iters %||%
      0L
  )[1L])
  if (!is.finite(sparse_update_until_iter) || sparse_update_until_iter < 0L) {
    sparse_update_until_iter <- 0L
  }
  if (sparse_update_every <= 1L) sparse_update_until_iter <- max(0L, sparse_update_until_iter)

  enabled <- if (is.null(theta_cfg$enabled)) {
    freeze_burnin_iters > 0L || (sparse_update_every > 1L && sparse_update_until_iter > 0L)
  } else {
    isTRUE(theta_cfg$enabled)
  }

  list(
    enabled = isTRUE(enabled),
    freeze_burnin_iters = freeze_burnin_iters,
    freeze_only_during_burn = if (is.null(theta_cfg$freeze_only_during_burn)) TRUE else isTRUE(theta_cfg$freeze_only_during_burn),
    sparse_update_every = sparse_update_every,
    sparse_update_until_iter = sparse_update_until_iter,
    force_first_postwarmup_update = if (is.null(theta_cfg$force_first_postwarmup_update)) TRUE else isTRUE(theta_cfg$force_first_postwarmup_update),
    trace = if (is.null(theta_cfg$trace)) TRUE else isTRUE(theta_cfg$trace)
  )
}

.exal_normalize_mcmc_precision_beta_cfg <- function(precision_cfg = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  precision_cfg <- .exal_list_or_empty(precision_cfg)

  enabled <- if (is.null(precision_cfg$enabled)) {
    isTRUE(precision_cfg$repair) || isTRUE(precision_cfg$eigen_fallback)
  } else {
    isTRUE(precision_cfg$enabled)
  }

  jitter_ladder <- precision_cfg$jitter_ladder %||%
    precision_cfg$ridge_ladder %||%
    c(0, 1e-10, 1e-8, 1e-6, 1e-4)
  jitter_ladder <- suppressWarnings(as.numeric(jitter_ladder))
  jitter_ladder <- jitter_ladder[is.finite(jitter_ladder) & jitter_ladder >= 0]
  if (!length(jitter_ladder)) jitter_ladder <- c(0, 1e-10, 1e-8, 1e-6, 1e-4)
  jitter_ladder <- unique(jitter_ladder)

  eigen_floor_abs <- as.numeric(
    precision_cfg$eigen_floor_abs %||%
      precision_cfg$eigen_floor %||%
      1e-6
  )[1L]
  if (!is.finite(eigen_floor_abs) || eigen_floor_abs <= 0) eigen_floor_abs <- 1e-6

  eigen_floor_rel <- as.numeric(
    precision_cfg$eigen_floor_rel %||%
      precision_cfg$relative_eigen_floor %||%
      1e-8
  )[1L]
  if (!is.finite(eigen_floor_rel) || eigen_floor_rel <= 0) eigen_floor_rel <- 1e-8

  list(
    enabled = isTRUE(enabled),
    symmetrize = if (is.null(precision_cfg$symmetrize)) TRUE else isTRUE(precision_cfg$symmetrize),
    jitter_ladder = as.numeric(jitter_ladder),
    eigen_fallback = if (is.null(precision_cfg$eigen_fallback)) FALSE else isTRUE(precision_cfg$eigen_fallback),
    eigen_floor_abs = eigen_floor_abs,
    eigen_floor_rel = eigen_floor_rel,
    trace = if (is.null(precision_cfg$trace)) TRUE else isTRUE(precision_cfg$trace)
  )
}

.exal_recycle_quantile_param <- function(x, len_p, nm, verbose = FALSE, method = NULL) {
  if (is.null(x)) return(NULL)
  x <- as.numeric(x)
  if (length(x) == 1L && len_p > 1L) {
    if (isTRUE(verbose)) {
      prefix <- if (nzchar(method %||% "")) sprintf("%s.", method) else ""
      message(sprintf(
        "Note: recycling %s%s=%s to length(p_vec)=%d",
        prefix, nm, paste(x, collapse = ","), len_p
      ))
    }
    return(rep(x, len_p))
  }
  if (length(x) != len_p) {
    prefix <- if (nzchar(method %||% "")) sprintf("%s.", method) else ""
    .stopf("Config error: length(%s%s)=%d but length(p_vec)=%d",
           prefix, nm, length(x), len_p)
  }
  x
}

.exal_normalize_inference_method <- function(cfg) {
  `%||%` <- function(a, b) if (is.null(a)) b else a

  inference_cfg <- cfg$inference %||% list()
  raw_method <- inference_cfg$method %||% cfg[["inference.method"]] %||% cfg$method %||% "vb"
  method <- tolower(as.character(raw_method)[1L])
  if (!method %in% c("vb", "mcmc")) {
    .stopf("Unsupported inference method '%s'. Expected 'vb' or 'mcmc'.", method)
  }
  method
}

.exal_normalize_likelihood_family <- function(cfg) {
  `%||%` <- function(a, b) if (is.null(a)) b else a

  inference_cfg <- cfg$inference %||% list()
  raw_family <- inference_cfg$likelihood_family %||%
    cfg[["inference.likelihood_family"]] %||%
    cfg$likelihood_family %||%
    "exal"
  family <- tolower(as.character(raw_family)[1L])
  if (!family %in% c("exal", "al")) {
    .stopf("Unsupported likelihood family '%s'. Expected 'exal' or 'al'.", family)
  }
  family
}

.exal_resolve_beta_prior_settings <- function(beta_cfg, default_rhs_cfg, default_rhs_ns_cfg = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  if (is.null(default_rhs_ns_cfg)) default_rhs_ns_cfg <- .exal_default_rhs_ns_cfg()

  resolve_init_log_tau <- function(rhs_cfg, default_rhs_cfg) {
    # Guardrail: canonical fallback is always 0.0 (tau=1 at init),
    # independent of nullable YAML values.
    default_val <- 0.0

    raw <- rhs_cfg[["init_log_tau", exact = TRUE]]
    # Guardrail: YAML null and missing values are treated as "unset".
    if (is.null(raw) || (length(raw) == 1L && is.na(raw))) return(default_val)

    val <- suppressWarnings(as.numeric(raw)[1L])
    if (is.finite(val)) return(val)

    warning(
      sprintf(
        "[inference] RHS init_log_tau override is non-numeric (%s); falling back to default %.6f.",
        paste(class(raw), collapse = "/"),
        default_val
      ),
      call. = FALSE
    )
    default_val
  }

  resolve_tau_bounds <- function(rhs_cfg, default_rhs_cfg) {
    default_bounds <- as.numeric((default_rhs_cfg$eta_bounds %||% list())$tau %||% c(-12, 12))
    if (length(default_bounds) < 2L || any(!is.finite(default_bounds[1:2])) ||
        default_bounds[1L] >= default_bounds[2L]) {
      default_bounds <- c(-12, 12)
    }
    default_bounds <- default_bounds[1:2]

    tau_bounds <- as.numeric(((rhs_cfg$eta_bounds %||% list())$tau) %||% default_bounds)
    if (length(tau_bounds) < 2L || any(!is.finite(tau_bounds[1:2])) ||
        tau_bounds[1L] >= tau_bounds[2L]) {
      warning(
        sprintf(
          "[inference] RHS eta_bounds$tau is invalid; falling back to defaults [%s, %s].",
          format(default_bounds[1L], digits = 6),
          format(default_bounds[2L], digits = 6)
        ),
        call. = FALSE
      )
      tau_bounds <- default_bounds
    }
    tau_bounds[1:2]
  }

  beta_cfg <- beta_cfg %||% list()
  beta_type <- tolower(as.character(beta_cfg$type %||% "rhs_ns")[1L])
  if (!beta_type %in% c("ridge", "rhs", "rhs_ns")) {
    .stopf("Unsupported beta prior type '%s'. Expected 'ridge', 'rhs', or 'rhs_ns'.", beta_type)
  }

  tau2_val <- NULL
  if (!is.null(beta_cfg$ridge) && !is.null(beta_cfg$ridge$tau2)) {
    tau2_val <- as.numeric(beta_cfg$ridge$tau2)[1L]
  } else if (!is.null(beta_cfg$tau2)) {
    tau2_val <- as.numeric(beta_cfg$tau2)[1L]
  }

  if (identical(beta_type, "rhs")) {
    rhs_cfg <- .exal_enforce_rhs_no_intercept_shrink(default_rhs_cfg, context = "inference.rhs")
    if (!is.null(beta_cfg$rhs)) {
      rhs_cfg <- modifyList(rhs_cfg, beta_cfg$rhs)
      rhs_names <- names(beta_cfg$rhs)
      if (!is.null(rhs_names)) {
        # Legacy compatibility: explicit NULL init values in YAML should behave like "unset"
        # and must not override the stable defaults from rhs_cfg.
        nullable_init_keys <- c(
          "init_lambda", "init_log_lambda",
          "init_tau", "init_log_tau",
          "init_c2", "init_log_c2"
        )
        nullable_init_defaults <- list(
          init_lambda = default_rhs_cfg$init_lambda %||% NULL,
          init_log_lambda = default_rhs_cfg$init_log_lambda %||% 0.0,
          init_tau = default_rhs_cfg$init_tau %||% NULL,
          init_log_tau = default_rhs_cfg$init_log_tau %||% 0.0,
          init_c2 = default_rhs_cfg$init_c2 %||% NULL,
          init_log_c2 = default_rhs_cfg$init_log_c2 %||% 0.0
        )
        for (nm in intersect(rhs_names, nullable_init_keys)) {
          if (is.null(beta_cfg$rhs[[nm]])) {
            rhs_cfg[[nm]] <- nullable_init_defaults[[nm]]
          } else {
            rhs_cfg[[nm]] <- beta_cfg$rhs[[nm]]
          }
        }
      }
    }
    rhs_cfg <- .exal_enforce_rhs_no_intercept_shrink(rhs_cfg, context = "inference.rhs")

    # Guardrail: resolved init_log_tau is always numeric and defaults to 0.0
    # unless a numeric override is explicitly provided.
    rhs_cfg$init_log_tau <- resolve_init_log_tau(rhs_cfg, default_rhs_cfg)
    rhs_cfg$eta_bounds <- rhs_cfg$eta_bounds %||% list()
    rhs_cfg$eta_bounds$tau <- resolve_tau_bounds(rhs_cfg, default_rhs_cfg)

    return(list(
      type = beta_type,
      tau2 = tau2_val,
      rhs = rhs_cfg
    ))
  }

  if (identical(beta_type, "rhs_ns")) {
    rhs_ns_cfg <- .exal_enforce_rhs_no_intercept_shrink(default_rhs_ns_cfg, context = "inference.rhs_ns")
    if (!is.null(beta_cfg$rhs) && is.list(beta_cfg$rhs)) {
      rhs_ns_cfg <- modifyList(rhs_ns_cfg, beta_cfg$rhs)
    }
    if (!is.null(beta_cfg$rhs_ns) && is.list(beta_cfg$rhs_ns)) {
      rhs_ns_cfg <- modifyList(rhs_ns_cfg, beta_cfg$rhs_ns)
    }
    rhs_ns_cfg <- .exal_enforce_rhs_no_intercept_shrink(rhs_ns_cfg, context = "inference.rhs_ns")

    rhs_ns_cfg$zeta2_fixed <- rhs_ns_cfg$zeta2_fixed %||% rhs_ns_cfg$c2_fixed %||% NULL
    rhs_ns_cfg$a_zeta <- as.numeric(rhs_ns_cfg$a_zeta %||% 2.0)[1L]
    rhs_ns_cfg$b_zeta <- as.numeric(rhs_ns_cfg$b_zeta %||% 1.0)[1L]
    rhs_ns_cfg$tau0 <- as.numeric(rhs_ns_cfg$tau0 %||% 1.0)[1L]
    rhs_ns_cfg$s2 <- as.numeric(rhs_ns_cfg$s2 %||% rhs_ns_cfg$zeta2 %||% 1.0)[1L]
    rhs_ns_cfg$init_log_tau <- resolve_init_log_tau(rhs_ns_cfg, default_rhs_ns_cfg)

    if (!is.null(rhs_ns_cfg$init_log_tau) && is.null(rhs_ns_cfg$init_tau2)) {
      ilt <- suppressWarnings(as.numeric(rhs_ns_cfg$init_log_tau)[1L])
      if (is.finite(ilt)) {
        rhs_ns_cfg$init_tau2 <- exp(2 * ilt)
      }
    }
    if (!is.null(rhs_ns_cfg$init_tau) && is.null(rhs_ns_cfg$init_tau2)) {
      itau <- suppressWarnings(as.numeric(rhs_ns_cfg$init_tau)[1L])
      if (is.finite(itau) && itau > 0) rhs_ns_cfg$init_tau2 <- itau^2
    }
    if (!is.null(rhs_ns_cfg$init_lambda) && is.null(rhs_ns_cfg$init_lambda2)) {
      ilam <- suppressWarnings(as.numeric(rhs_ns_cfg$init_lambda))
      rhs_ns_cfg$init_lambda2 <- ilam^2
    }
    if (!is.null(rhs_ns_cfg$init_log_lambda) && is.null(rhs_ns_cfg$init_lambda2)) {
      ilogl <- suppressWarnings(as.numeric(rhs_ns_cfg$init_log_lambda))
      rhs_ns_cfg$init_lambda2 <- exp(2 * ilogl)
    }
    if (!is.null(rhs_ns_cfg$init_c2) && is.null(rhs_ns_cfg$init_zeta2)) {
      rhs_ns_cfg$init_zeta2 <- suppressWarnings(as.numeric(rhs_ns_cfg$init_c2)[1L])
    }
    if (!is.null(rhs_ns_cfg$init_log_c2) && is.null(rhs_ns_cfg$init_zeta2)) {
      ilogc2 <- suppressWarnings(as.numeric(rhs_ns_cfg$init_log_c2)[1L])
      if (is.finite(ilogc2)) rhs_ns_cfg$init_zeta2 <- exp(ilogc2)
    }
    if (is.null(rhs_ns_cfg$init_zeta2)) rhs_ns_cfg$init_zeta2 <- rhs_ns_cfg$s2 %||% 1.0

    return(list(
      type = beta_type,
      tau2 = tau2_val,
      rhs = rhs_ns_cfg
    ))
  }

  list(
    type = beta_type,
    tau2 = tau2_val,
    rhs = default_rhs_cfg
  )
}

.exal_resolve_vb_config <- function(vb_cfg, p_vec, verbose = FALSE) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  `%nz%` <- function(x, alt) if (!is.null(x)) x else alt

  len_p <- length(p_vec)
  vb_cfg <- .exal_list_or_empty(vb_cfg)
  vb_args_base <- .exal_default_vb_args_base()
  vb_online_cfg <- .exal_default_vb_online_cfg()
  default_rhs_cfg <- .exal_default_rhs_cfg()
  default_rhs_ns_cfg <- .exal_default_rhs_ns_cfg()

  rhs_trace_on <- FALSE
  rhs_deep_on <- FALSE
  rhs_trace_thresholds <- c(1e3, 1e6, 1e9)
  rhs_trace_top_k <- 20L
  rhs_trace_eps <- c(1e-6, 1e-4, 1e-2)
  rhs_freeze_tau_iters <- 0L
  rhs_freeze_tau_warmup_iters <- 0L
  rhs_update_every <- 1L
  rhs_update_every_warmup <- 1L
  rhs_update_every_warmup_iters <- 0L
  rhs_beta_presteps <- 1L
  rhs_beta_presteps_iters <- 0L
  rhs_gradcheck_on <- FALSE
  rhs_gradcheck_iters <- c(1L, 5L)
  rhs_gradcheck_h <- 1e-5
  rhs_tau_local_tol <- NA_real_
  rhs_min_tau_updates <- 1L
  rhs_max_tau_updates <- NA_integer_
  rhs_force_tau_after_warmup <- TRUE
  rhs_recompute_elbo_after_tau_update <- TRUE

  tol50 <- 1e-4
  tolext <- 1e-5
  tol_par_50 <- tol50
  tol_par_ext <- tolext

  if (!is.null(vb_cfg$max_iter)) vb_args_base$max_iter <- as.integer(vb_cfg$max_iter)[1L]
  if (!is.null(vb_cfg$min_iter_elbo)) vb_args_base$min_iter_elbo <- as.integer(vb_cfg$min_iter_elbo)[1L]
  if (!is.null(vb_cfg$n_samp_xi)) vb_args_base$n_samp_xi <- as.integer(vb_cfg$n_samp_xi)[1L]
  if (!is.null(vb_cfg$verbose)) vb_args_base$verbose <- isTRUE(vb_cfg$verbose)

  if (!is.null(vb_cfg$diagnostics)) {
    diag_cfg <- vb_cfg$diagnostics
    if (!is.null(diag_cfg$rhs_trace)) rhs_trace_on <- isTRUE(diag_cfg$rhs_trace)
    if (!is.null(diag_cfg$rhs_deep)) rhs_deep_on <- isTRUE(diag_cfg$rhs_deep)
    if (!is.null(diag_cfg$rhs_trace_thresholds)) rhs_trace_thresholds <- as.numeric(diag_cfg$rhs_trace_thresholds)
    if (!is.null(diag_cfg$rhs_trace_top_k)) rhs_trace_top_k <- as.integer(diag_cfg$rhs_trace_top_k)[1L]
    if (!is.null(diag_cfg$rhs_trace_eps)) rhs_trace_eps <- as.numeric(diag_cfg$rhs_trace_eps)
  }

  if (!is.null(vb_cfg$rhs)) {
    rhs_cfg <- vb_cfg$rhs
    if (!is.null(rhs_cfg$verbose_trace)) rhs_trace_on <- isTRUE(rhs_cfg$verbose_trace)
    if (!is.null(rhs_cfg$trace)) rhs_trace_on <- isTRUE(rhs_cfg$trace)
    if (!is.null(rhs_cfg$freeze_tau_iters)) {
      rhs_freeze_tau_iters <- as.integer(rhs_cfg$freeze_tau_iters)[1L]
    }
    if (!is.null(rhs_cfg$freeze_tau_warmup_iters)) {
      rhs_freeze_tau_warmup_iters <- as.integer(rhs_cfg$freeze_tau_warmup_iters)[1L]
    } else {
      rhs_freeze_tau_warmup_iters <- rhs_freeze_tau_iters
    }
    if (!is.null(rhs_cfg$update_every)) rhs_update_every <- as.integer(rhs_cfg$update_every)[1L]
    if (!is.null(rhs_cfg$update_every_warmup)) rhs_update_every_warmup <- as.integer(rhs_cfg$update_every_warmup)[1L]
    if (!is.null(rhs_cfg$update_every_warmup_iters)) rhs_update_every_warmup_iters <- as.integer(rhs_cfg$update_every_warmup_iters)[1L]
    if (!is.null(rhs_cfg$beta_presteps)) rhs_beta_presteps <- as.integer(rhs_cfg$beta_presteps)[1L]
    if (!is.null(rhs_cfg$beta_presteps_iters)) rhs_beta_presteps_iters <- as.integer(rhs_cfg$beta_presteps_iters)[1L]
    if (!is.null(rhs_cfg$gradcheck)) rhs_gradcheck_on <- isTRUE(rhs_cfg$gradcheck)
    if (!is.null(rhs_cfg$gradcheck_iters)) rhs_gradcheck_iters <- as.integer(rhs_cfg$gradcheck_iters)
    if (!is.null(rhs_cfg$gradcheck_h)) rhs_gradcheck_h <- as.numeric(rhs_cfg$gradcheck_h)[1L]
    if (!is.null(rhs_cfg$tau_local_tol)) rhs_tau_local_tol <- as.numeric(rhs_cfg$tau_local_tol)[1L]
    if (!is.null(rhs_cfg$min_tau_updates)) rhs_min_tau_updates <- as.integer(rhs_cfg$min_tau_updates)[1L]
    if (!is.null(rhs_cfg$max_tau_updates)) rhs_max_tau_updates <- as.integer(rhs_cfg$max_tau_updates)[1L]
    if (!is.null(rhs_cfg$force_tau_after_warmup)) rhs_force_tau_after_warmup <- isTRUE(rhs_cfg$force_tau_after_warmup)
    if (!is.null(rhs_cfg$recompute_elbo_after_tau_update)) {
      rhs_recompute_elbo_after_tau_update <- isTRUE(rhs_cfg$recompute_elbo_after_tau_update)
    }
  }

  if (rhs_deep_on && !rhs_trace_on) rhs_trace_on <- TRUE

  tol50 <- as.numeric(vb_cfg$tol_50 %nz% tol50)[1L]
  tolext <- as.numeric(vb_cfg$tol_extreme %nz% tolext)[1L]
  tol_par_50 <- as.numeric(vb_cfg$tol_par_50 %nz% tol50)[1L]
  tol_par_ext <- as.numeric(vb_cfg$tol_par_extreme %nz% tolext)[1L]

  vb_args_base$rhs_trace <- isTRUE(rhs_trace_on)
  vb_args_base$rhs_deep <- isTRUE(rhs_deep_on)
  vb_args_base$rhs_trace_thresholds <- rhs_trace_thresholds
  vb_args_base$rhs_trace_top_k <- rhs_trace_top_k
  vb_args_base$rhs_trace_eps <- rhs_trace_eps
  vb_args_base$rhs_freeze_tau_iters <- rhs_freeze_tau_iters
  vb_args_base$rhs_freeze_tau_warmup_iters <- rhs_freeze_tau_warmup_iters
  vb_args_base$rhs_update_every <- rhs_update_every
  vb_args_base$rhs_update_every_warmup <- rhs_update_every_warmup
  vb_args_base$rhs_update_every_warmup_iters <- rhs_update_every_warmup_iters
  vb_args_base$rhs_beta_presteps <- rhs_beta_presteps
  vb_args_base$rhs_beta_presteps_iters <- rhs_beta_presteps_iters
  vb_args_base$rhs_gradcheck <- rhs_gradcheck_on
  vb_args_base$rhs_gradcheck_iters <- rhs_gradcheck_iters
  vb_args_base$rhs_gradcheck_h <- rhs_gradcheck_h
  vb_args_base$rhs_tau_local_tol <- rhs_tau_local_tol
  vb_args_base$rhs_min_tau_updates <- rhs_min_tau_updates
  vb_args_base$rhs_max_tau_updates <- rhs_max_tau_updates
  vb_args_base$rhs_force_tau_after_warmup <- rhs_force_tau_after_warmup
  vb_args_base$rhs_recompute_elbo_after_tau_update <- rhs_recompute_elbo_after_tau_update

  if (!is.null(vb_cfg$online) && is.list(vb_cfg$online)) {
    vb_online_cfg <- modifyList(vb_online_cfg, vb_cfg$online)
  }
  vb_args_base$sigmagam <- .exal_normalize_vb_sigmagam_cfg(vb_cfg$sigmagam %||% vb_args_base$sigmagam %||% list())
  vb_online_cfg$enabled <- isTRUE(vb_online_cfg$enabled)
  vb_online_cfg$strict <- isTRUE(vb_online_cfg$strict)
  vb_online_cfg$M <- max(0L, as.integer(vb_online_cfg$M %||% 10L))
  vb_online_cfg$K <- max(0L, as.integer(vb_online_cfg$K %||% 40L))
  vb_online_cfg$W <- max(0L, as.integer(vb_online_cfg$W %||% 100L))
  vb_online_cfg$L_loc <- max(1L, as.integer(vb_online_cfg$L_loc %||% 2L))
  vb_online_cfg$window_passes <- max(0L, as.integer(vb_online_cfg$window_passes %||% 1L))
  vb_online_cfg$maxit_sigmagam <- max(50L, as.integer(vb_online_cfg$maxit_sigmagam %||% 500L))
  vb_online_cfg$jitter <- as.numeric(vb_online_cfg$jitter %||% 1e-10)
  if (!is.finite(vb_online_cfg$jitter) || vb_online_cfg$jitter <= 0) vb_online_cfg$jitter <- 1e-10
  vb_online_cfg$warm_start_n <- if (is.null(vb_online_cfg$warm_start_n)) NULL else as.integer(vb_online_cfg$warm_start_n)
  vb_online_cfg$warm_start_frac <- as.numeric(vb_online_cfg$warm_start_frac %||% 0.7)
  if (!is.finite(vb_online_cfg$warm_start_frac)) vb_online_cfg$warm_start_frac <- 0.7
  vb_online_cfg$keep_trace <- isTRUE(vb_online_cfg$keep_trace)
  vb_online_cfg$update_rhs <- if (is.null(vb_online_cfg$update_rhs)) TRUE else isTRUE(vb_online_cfg$update_rhs)
  vb_online_cfg$update_sigmagam <- if (is.null(vb_online_cfg$update_sigmagam)) TRUE else isTRUE(vb_online_cfg$update_sigmagam)
  if (vb_online_cfg$K < vb_online_cfg$M) vb_online_cfg$K <- vb_online_cfg$M
  if (isTRUE(vb_online_cfg$strict)) vb_online_cfg$W <- 0L

  init_cfg <- .exal_list_or_empty(vb_cfg$init)
  priors_cfg <- .exal_list_or_empty(vb_cfg$priors)
  beta_prior <- .exal_resolve_beta_prior_settings(priors_cfg$beta, default_rhs_cfg, default_rhs_ns_cfg)
  if (identical(beta_prior$type, "rhs_ns") && !is.null(vb_cfg$rhs) && is.list(vb_cfg$rhs)) {
    for (nm in c("freeze_tau_iters", "freeze_tau_warmup_iters", "force_tau_after_warmup")) {
      if (is.null(beta_prior$rhs[[nm]]) && !is.null(vb_cfg$rhs[[nm]])) {
        beta_prior$rhs[[nm]] <- vb_cfg$rhs[[nm]]
      }
    }
  }

  list(
    args_base = vb_args_base,
    online = vb_online_cfg,
    tol50 = tol50,
    tolext = tolext,
    tol_par_50 = tol_par_50,
    tol_par_ext = tol_par_ext,
    tol_for = function(p0) if (abs(as.numeric(p0) - 0.50) < 1e-12) tol50 else tolext,
    tol_par_for = function(p0) if (abs(as.numeric(p0) - 0.50) < 1e-12) tol_par_50 else tol_par_ext,
    readout_scale = isTRUE(vb_cfg$readout_scale %||% FALSE),
    init_gamma = .exal_recycle_quantile_param(init_cfg$gamma, len_p, "init$gamma", verbose = verbose, method = "vb"),
    init_sigma = .exal_recycle_quantile_param(init_cfg$sigma, len_p, "init$sigma", verbose = verbose, method = "vb"),
    prior_gamma_mu0 = .exal_recycle_quantile_param(.exal_list_or_empty(priors_cfg$gamma)$mu0, len_p, "priors$gamma$mu0", verbose = verbose, method = "vb"),
    prior_gamma_s20 = .exal_recycle_quantile_param(.exal_list_or_empty(priors_cfg$gamma)$s20, len_p, "priors$gamma$s20", verbose = verbose, method = "vb"),
    prior_sigma_a = .exal_recycle_quantile_param(.exal_list_or_empty(priors_cfg$sigma)$a, len_p, "priors$sigma$a", verbose = verbose, method = "vb"),
    prior_sigma_b = .exal_recycle_quantile_param(.exal_list_or_empty(priors_cfg$sigma)$b, len_p, "priors$sigma$b", verbose = verbose, method = "vb"),
    beta_prior_type = beta_prior$type,
    beta_prior_tau2 = beta_prior$tau2,
    beta_prior_rhs = beta_prior$rhs
  )
}

.exal_resolve_mcmc_config <- function(mcmc_cfg, p_vec, verbose = FALSE) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  len_p <- length(p_vec)
  mcmc_cfg <- .exal_list_or_empty(mcmc_cfg)
  default_rhs_cfg <- .exal_default_rhs_cfg()
  default_rhs_ns_cfg <- .exal_default_rhs_ns_cfg()

  control <- .exal_default_mcmc_control()
  control <- modifyList(control, mcmc_cfg$mcmc_control %||% mcmc_cfg$control %||% list())

  if (!is.null(mcmc_cfg$n_burn)) control$n_burn <- as.integer(mcmc_cfg$n_burn)[1L]
  if (!is.null(mcmc_cfg$n_mcmc)) control$n_mcmc <- as.integer(mcmc_cfg$n_mcmc)[1L]
  if (!is.null(mcmc_cfg$thin)) control$thin <- as.integer(mcmc_cfg$thin)[1L]
  if (!is.null(mcmc_cfg$verbose)) control$verbose <- isTRUE(mcmc_cfg$verbose)
  if (!is.null(mcmc_cfg$progress_every)) control$progress_every <- as.integer(mcmc_cfg$progress_every)[1L]
  if (!is.null(mcmc_cfg$init_from_vb)) control$init_from_vb <- isTRUE(mcmc_cfg$init_from_vb)
  if (!is.null(mcmc_cfg$vb_warm_start_seed)) control$vb_warm_start_seed <- as.integer(mcmc_cfg$vb_warm_start_seed)[1L]
  if (!is.null(mcmc_cfg$vb_warm_start_control) && is.list(mcmc_cfg$vb_warm_start_control)) {
    control$vb_warm_start_control <- modifyList(control$vb_warm_start_control %||% list(), mcmc_cfg$vb_warm_start_control)
  }
  control$sigmagam <- .exal_normalize_mcmc_sigmagam_cfg(mcmc_cfg$sigmagam %||% control$sigmagam %||% list())
  control$theta <- .exal_normalize_mcmc_theta_cfg(mcmc_cfg$theta %||% mcmc_cfg$beta %||% control$theta %||% list())
  control$latent_v <- .exal_normalize_mcmc_latent_v_cfg(mcmc_cfg$latent_v %||% control$latent_v %||% list())
  control$latent_s <- .exal_normalize_mcmc_latent_s_cfg(mcmc_cfg$latent_s %||% control$latent_s %||% list())
  control$vb_warm_start_control <- .exal_list_or_empty(control$vb_warm_start_control)
  control$vb_warm_start_control$sigmagam <- .exal_normalize_vb_sigmagam_cfg(
    control$vb_warm_start_control$sigmagam %||% list()
  )
  if (!is.null(mcmc_cfg$store_latent_draws)) control$store_latent_draws <- isTRUE(mcmc_cfg$store_latent_draws)
  if (!is.null(mcmc_cfg$store_rhs_draws)) control$store_rhs_draws <- isTRUE(mcmc_cfg$store_rhs_draws)
  if (!is.null(mcmc_cfg$rhs) && is.list(mcmc_cfg$rhs)) {
    control$rhs <- modifyList(control$rhs %||% list(), mcmc_cfg$rhs)
  }
  if (!is.null(mcmc_cfg$slice) && is.list(mcmc_cfg$slice)) {
    control$slice <- modifyList(control$slice %||% list(), mcmc_cfg$slice)
  }
  if (!is.null(mcmc_cfg$transforms) && is.list(mcmc_cfg$transforms)) {
    control$transforms <- modifyList(control$transforms %||% list(), mcmc_cfg$transforms)
  }
  if (!is.null(mcmc_cfg$transform) && is.list(mcmc_cfg$transform)) {
    control$transforms <- modifyList(control$transforms %||% list(), mcmc_cfg$transform)
  }
  if (!is.null(mcmc_cfg$conditioning) && is.list(mcmc_cfg$conditioning)) {
    control$conditioning <- modifyList(control$conditioning %||% list(), mcmc_cfg$conditioning)
  }
  control$precision_beta <- .exal_normalize_mcmc_precision_beta_cfg(
    mcmc_cfg$precision_beta %||% mcmc_cfg$precision %||% control$precision_beta %||% list()
  )
  if (!is.null(mcmc_cfg$multi_start) && is.list(mcmc_cfg$multi_start)) {
    control$multi_start <- modifyList(control$multi_start %||% list(), mcmc_cfg$multi_start)
  }

  init_cfg <- .exal_list_or_empty(mcmc_cfg$init)
  priors_cfg <- .exal_list_or_empty(mcmc_cfg$priors)
  beta_prior <- .exal_resolve_beta_prior_settings(priors_cfg$beta, default_rhs_cfg, default_rhs_ns_cfg)

  list(
    control_base = control,
    readout_scale = isTRUE(mcmc_cfg$readout_scale %||% FALSE),
    init_gamma = .exal_recycle_quantile_param(init_cfg$gamma, len_p, "init$gamma", verbose = verbose, method = "mcmc"),
    init_sigma = .exal_recycle_quantile_param(init_cfg$sigma, len_p, "init$sigma", verbose = verbose, method = "mcmc"),
    prior_gamma_mu0 = .exal_recycle_quantile_param(.exal_list_or_empty(priors_cfg$gamma)$mu0, len_p, "priors$gamma$mu0", verbose = verbose, method = "mcmc"),
    prior_gamma_s20 = .exal_recycle_quantile_param(.exal_list_or_empty(priors_cfg$gamma)$s20, len_p, "priors$gamma$s20", verbose = verbose, method = "mcmc"),
    prior_sigma_a = .exal_recycle_quantile_param(.exal_list_or_empty(priors_cfg$sigma)$a, len_p, "priors$sigma$a", verbose = verbose, method = "mcmc"),
    prior_sigma_b = .exal_recycle_quantile_param(.exal_list_or_empty(priors_cfg$sigma)$b, len_p, "priors$sigma$b", verbose = verbose, method = "mcmc"),
    beta_prior_type = beta_prior$type,
    beta_prior_tau2 = beta_prior$tau2,
    beta_prior_rhs = beta_prior$rhs
  )
}

resolve_exal_inference_config <- function(cfg, p_vec, verbose = FALSE) {
  `%||%` <- function(a, b) if (is.null(a)) b else a

  cfg <- cfg %||% list()
  inference_cfg <- .exal_list_or_empty(cfg$inference)
  method <- .exal_normalize_inference_method(cfg)
  likelihood_family <- .exal_normalize_likelihood_family(cfg)

  legacy_vb_cfg <- .exal_list_or_empty(cfg$vb)
  legacy_mcmc_cfg <- .exal_list_or_empty(cfg$mcmc)

  vb_cfg <- modifyList(legacy_vb_cfg, .exal_list_or_empty(inference_cfg$vb))
  mcmc_cfg <- modifyList(legacy_mcmc_cfg, .exal_list_or_empty(inference_cfg$mcmc))
  if (is.null((.exal_list_or_empty(mcmc_cfg$vb_warm_start_control))$sigmagam) &&
      !is.null(vb_cfg$sigmagam)) {
    mcmc_cfg$vb_warm_start_control <- modifyList(
      .exal_list_or_empty(mcmc_cfg$vb_warm_start_control),
      list(sigmagam = vb_cfg$sigmagam)
    )
  }

  vb_out <- .exal_resolve_vb_config(vb_cfg, p_vec = p_vec, verbose = verbose)
  mcmc_out <- .exal_resolve_mcmc_config(mcmc_cfg, p_vec = p_vec, verbose = verbose)

  active <- if (identical(method, "vb")) vb_out else mcmc_out
  readout_scale <- isTRUE(inference_cfg$readout_scale %||% active$readout_scale %||% FALSE)

  list(
    method = method,
    likelihood_family = likelihood_family,
    readout_scale = readout_scale,
    init_gamma = active$init_gamma,
    init_sigma = active$init_sigma,
    prior_gamma_mu0 = active$prior_gamma_mu0,
    prior_gamma_s20 = active$prior_gamma_s20,
    prior_sigma_a = active$prior_sigma_a,
    prior_sigma_b = active$prior_sigma_b,
    beta_prior_type = active$beta_prior_type,
    beta_prior_tau2 = active$beta_prior_tau2,
    beta_prior_rhs = active$beta_prior_rhs,
    vb = vb_out,
    mcmc = mcmc_out
  )
}

exal_make_beta_prior <- function(type = c("ridge", "rhs", "rhs_ns"), tau2 = NULL, rhs = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  type <- tolower(match.arg(type))
  if (identical(type, "rhs")) {
    if (is.null(rhs) || !is.list(rhs)) {
      .stopf("RHS beta prior requires a list of rhs hyperparameters.")
    }
    return(beta_prior("rhs", rhs = rhs))
  }
  if (identical(type, "rhs_ns")) {
    if (is.null(rhs) || !is.list(rhs)) {
      .stopf("RHS_NS beta prior requires a list of rhs_ns hyperparameters.")
    }
    return(beta_prior("rhs_ns", rhs = rhs))
  }

  tau2 <- as.numeric(tau2 %||% 1e4)[1L]
  if (!is.finite(tau2) || tau2 <= 0) .stopf("ridge tau2 must be positive.")
  beta_prior("ridge", ridge = list(tau2 = tau2))
}

resolve_exal_quantile_fit_spec <- function(inference_cfg, idx_p, p0) {
  `%||%` <- function(a, b) if (is.null(a)) b else a

  if (!is.list(inference_cfg) || is.null(inference_cfg$method)) {
    .stopf("resolve_exal_quantile_fit_spec: invalid inference config.")
  }

  idx_p <- as.integer(idx_p)[1L]
  if (!is.finite(idx_p) || idx_p < 1L) .stopf("resolve_exal_quantile_fit_spec: idx_p must be >= 1.")

  beta_type <- tolower(as.character(inference_cfg$beta_prior_type %||% "ridge")[1L])
  beta_prior_obj <- exal_make_beta_prior(
    type = beta_type,
    tau2 = inference_cfg$beta_prior_tau2,
    rhs = inference_cfg$beta_prior_rhs
  )

  gamma_init <- if (!is.null(inference_cfg$init_gamma)) as.numeric(inference_cfg$init_gamma[idx_p]) else 0
  sigma_init <- if (!is.null(inference_cfg$init_sigma)) as.numeric(inference_cfg$init_sigma[idx_p]) else 1

  gamma_mu0 <- if (!is.null(inference_cfg$prior_gamma_mu0)) as.numeric(inference_cfg$prior_gamma_mu0[idx_p]) else 0
  gamma_s20 <- if (!is.null(inference_cfg$prior_gamma_s20)) as.numeric(inference_cfg$prior_gamma_s20[idx_p]) else 10
  sigma_a <- if (!is.null(inference_cfg$prior_sigma_a)) as.numeric(inference_cfg$prior_sigma_a[idx_p]) else 1
  sigma_b <- if (!is.null(inference_cfg$prior_sigma_b)) as.numeric(inference_cfg$prior_sigma_b[idx_p]) else 1

  log_prior_gamma <- if (!is.null(inference_cfg$prior_gamma_mu0)) {
    function(g) stats::dnorm(g, mean = gamma_mu0, sd = sqrt(gamma_s20), log = TRUE)
  } else {
    function(g) 0
  }

  out <- list(
    method = inference_cfg$method,
    likelihood_family = tolower(as.character(inference_cfg$likelihood_family %||% "exal")[1L]),
    beta_type = beta_type,
    beta_prior_obj = beta_prior_obj,
    init = list(gamma = gamma_init, sigma = sigma_init),
    prior_gamma = list(mu0 = gamma_mu0, s20 = gamma_s20),
    prior_sigma = list(a = sigma_a, b = sigma_b),
    log_prior_gamma = log_prior_gamma
  )
  if (!out$likelihood_family %in% c("exal", "al")) {
    .stopf("resolve_exal_quantile_fit_spec: unsupported likelihood family '%s'.", out$likelihood_family)
  }

  if (identical(inference_cfg$method, "vb")) {
    vb_control <- inference_cfg$vb$args_base
    vb_control$tol <- inference_cfg$vb$tol_for(p0)
    vb_control$tol_par <- inference_cfg$vb$tol_par_for(p0)
    out$vb_control <- vb_control
    out$online_control <- inference_cfg$vb$online
  } else {
    out$mcmc_control <- inference_cfg$mcmc$control_base
  }

  out
}
