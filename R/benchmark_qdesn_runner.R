# Benchmark experiment runner for Q-DESN synthesized forecasts.

bench_qdesn_string_seed <- function(x, base_seed = 0L) {
  chars <- utf8ToInt(enc2utf8(as.character(x)[1L]))
  if (!length(chars)) return(as.integer(base_seed))
  as.integer((sum(chars * seq_along(chars)) + as.integer(base_seed)[1L]) %% 100000L)
}

bench_qdesn_scale_spec <- function(y_fit, scale_y = TRUE) {
  scale_y <- isTRUE(scale_y)
  center <- if (scale_y) mean(y_fit, na.rm = TRUE) else 0
  scale <- if (scale_y) stats::sd(y_fit, na.rm = TRUE) else 1
  if (!is.finite(scale) || scale <= 0) scale <- 1

  list(
    scale_y = scale_y,
    center = center,
    scale = scale,
    forward = function(z) if (scale_y) (z - center) / scale else z,
    inverse = function(z) if (scale_y) z * scale + center else z,
    inverse_matrix = function(M) {
      M <- as.matrix(M)
      if (scale_y) {
        M * scale + center
      } else {
        M
      }
    }
  )
}

bench_qdesn_normalize_fit_cfg <- function(fit_cfg) {
  fit_cfg <- fit_cfg %||% list()
  if (is.null(fit_cfg$n) && !is.null(fit_cfg[["FALSE"]])) {
    fit_cfg$n <- fit_cfg[["FALSE"]]
  }
  D <- as.integer(fit_cfg$D %||% 1L)
  n <- as.integer(unlist(fit_cfg$n %||% 32L, use.names = FALSE))
  if (length(n) == 1L && D > 1L) n <- rep(n, D)
  if (length(n) != D) {
    stop(sprintf("Q-DESN fit config requires length(n) == D. Got D=%d, length(n)=%d.", D, length(n)), call. = FALSE)
  }

  n_tilde <- fit_cfg$n_tilde
  if (D <= 1L) {
    n_tilde <- integer(0)
  } else {
    if (is.null(n_tilde)) {
      n_tilde <- pmax(1L, as.integer(head(n, -1L) / 2L))
    } else {
      n_tilde <- as.integer(unlist(n_tilde, use.names = FALSE))
      if (length(n_tilde) == 1L && (D - 1L) > 1L) n_tilde <- rep(n_tilde, D - 1L)
      if (length(n_tilde) != (D - 1L)) {
        stop(sprintf("Q-DESN fit config requires length(n_tilde) == D-1. Got D=%d, length(n_tilde)=%d.", D, length(n_tilde)), call. = FALSE)
      }
    }
  }

  recycle_num <- function(x, default) {
    v <- as.numeric(unlist(x %||% default, use.names = FALSE))
    if (length(v) == 1L && D > 1L) v <- rep(v, D)
    if (length(v) != D) {
      stop(sprintf("Expected vector of length %d in Q-DESN fit config.", D), call. = FALSE)
    }
    v
  }

  normalize_act <- function(x, default) {
    if (is.null(x)) return(default)
    vals <- unique(as.character(unlist(x, use.names = FALSE)))
    vals <- vals[nzchar(vals)]
    if (!length(vals)) return(default)
    vals[[1L]]
  }

  list(
    D = D,
    n = n,
    n_tilde = n_tilde,
    m = as.integer(fit_cfg$m %||% 12L),
    standardize_inputs = isTRUE(fit_cfg$standardize_inputs %||% FALSE),
    input_bound = as.character(fit_cfg$input_bound %||% "none"),
    win_scale_global = as.numeric(fit_cfg$win_scale_global %||% 1),
    win_scale_bias = as.numeric(fit_cfg$win_scale_bias %||% 1),
    win_scale_lags = if (is.null(fit_cfg$win_scale_lags)) NULL else as.numeric(unlist(fit_cfg$win_scale_lags, use.names = FALSE)),
    alpha = recycle_num(fit_cfg$alpha, 0.30),
    rho = recycle_num(fit_cfg$rho, 0.90),
    act_f = normalize_act(fit_cfg$act_f, "tanh"),
    act_k = normalize_act(fit_cfg$act_k, "identity"),
    pi_w = recycle_num(fit_cfg$pi_w, 0.10),
    pi_in = recycle_num(fit_cfg$pi_in, 1.00),
    washout = as.integer(fit_cfg$washout %||% 24L),
    add_bias = isTRUE(fit_cfg$add_bias %||% TRUE),
    state_noise_sd = as.numeric(fit_cfg$state_noise_sd %||% 0),
    seed = as.integer(fit_cfg$seed %||% 123L),
    seed_set = as.integer(unlist(fit_cfg$seed_set %||% fit_cfg$seed %||% 123L, use.names = FALSE))
  )
}

bench_qdesn_default_beta_rhs <- function() {
  list(
    tau0 = 0.001,
    nu = 4.0,
    s2 = 0.1,
    shrink_intercept = FALSE,
    intercept_prec = 1e-16,
    n_inner = 1L,
    eta_bounds = list(
      lambda = c(-20, 20),
      tau = c(-20, 20),
      c2 = c(-20, 20)
    ),
    h_curv = 1e-8,
    var_floor = 1e-8,
    verbose = FALSE,
    init_log_lambda = 0.0,
    init_log_tau = NULL,
    init_log_c2 = 0.0
  )
}

bench_qdesn_normalize_vb_args <- function(vb_args) {
  vb_args <- vb_args %||% list()
  defaults <- list(
    max_iter = 100L,
    min_iter_elbo = 20L,
    tol = 1e-4,
    tol_par = 1e-4,
    n_samp_xi = 500L,
    verbose = FALSE,
    readout_scale = TRUE,
    diagnostics = list(
      rhs_trace = TRUE,
      rhs_deep = FALSE,
      rhs_trace_thresholds = c(1e3, 1e6, 1e9),
      rhs_trace_top_k = 20L,
      rhs_trace_eps = c(1e-6, 1e-4, 1e-2)
    ),
    rhs = list(
      freeze_tau_iters = 20L,
      freeze_tau_warmup_iters = 20L,
      update_every = 1L,
      update_every_warmup = 1L,
      update_every_warmup_iters = 0L,
      beta_presteps = 1L,
      beta_presteps_iters = 0L,
      gradcheck = FALSE,
      gradcheck_iters = c(1L, 5L),
      gradcheck_h = 1e-5,
      tau_local_tol = 1e-3,
      min_tau_updates = 1L,
      max_tau_updates = NULL,
      force_tau_after_warmup = TRUE,
      recompute_elbo_after_tau_update = TRUE
    ),
    beta_prior_type = "rhs",
    beta_ridge_tau2 = 10000
  )
  out <- bench_deep_merge(defaults, vb_args)
  out$max_iter <- as.integer(out$max_iter %||% 40L)
  out$min_iter_elbo <- as.integer(out$min_iter_elbo %||% 10L)
  out$tol <- as.numeric(out$tol %||% 1e-4)
  out$tol_par <- as.numeric(out$tol_par %||% out$tol %||% 1e-4)
  out$n_samp_xi <- as.integer(out$n_samp_xi %||% 200L)
  out$verbose <- isTRUE(out$verbose %||% FALSE)
  out$readout_scale <- isTRUE(out$readout_scale %||% TRUE)
  out$beta_prior_type <- tolower(as.character(out$beta_prior_type %||% "ridge")[1L])
  out$diagnostics <- out$diagnostics %||% list()
  out$diagnostics$rhs_trace <- isTRUE(out$diagnostics$rhs_trace %||% TRUE)
  out$diagnostics$rhs_deep <- isTRUE(out$diagnostics$rhs_deep %||% FALSE)
  out$diagnostics$rhs_trace_thresholds <- as.numeric(unlist(out$diagnostics$rhs_trace_thresholds %||% c(1e3, 1e6, 1e9), use.names = FALSE))
  out$diagnostics$rhs_trace_top_k <- as.integer(out$diagnostics$rhs_trace_top_k %||% 20L)
  out$diagnostics$rhs_trace_eps <- as.numeric(unlist(out$diagnostics$rhs_trace_eps %||% c(1e-6, 1e-4, 1e-2), use.names = FALSE))
  out$rhs <- out$rhs %||% list()
  out$rhs$freeze_tau_iters <- as.integer(out$rhs$freeze_tau_iters %||% 20L)
  out$rhs$freeze_tau_warmup_iters <- as.integer(out$rhs$freeze_tau_warmup_iters %||% 20L)
  out$rhs$update_every <- as.integer(out$rhs$update_every %||% 1L)
  out$rhs$update_every_warmup <- as.integer(out$rhs$update_every_warmup %||% 1L)
  out$rhs$update_every_warmup_iters <- as.integer(out$rhs$update_every_warmup_iters %||% 0L)
  out$rhs$beta_presteps <- as.integer(out$rhs$beta_presteps %||% 1L)
  out$rhs$beta_presteps_iters <- as.integer(out$rhs$beta_presteps_iters %||% 0L)
  out$rhs$gradcheck <- isTRUE(out$rhs$gradcheck %||% FALSE)
  out$rhs$gradcheck_iters <- as.integer(unlist(out$rhs$gradcheck_iters %||% c(1L, 5L), use.names = FALSE))
  out$rhs$gradcheck_h <- as.numeric(out$rhs$gradcheck_h %||% 1e-5)
  out$rhs$tau_local_tol <- out$rhs$tau_local_tol %||% 1e-3
  out$rhs$min_tau_updates <- as.integer(out$rhs$min_tau_updates %||% 1L)
  out$rhs$force_tau_after_warmup <- isTRUE(out$rhs$force_tau_after_warmup %||% TRUE)
  out$rhs$recompute_elbo_after_tau_update <- isTRUE(out$rhs$recompute_elbo_after_tau_update %||% TRUE)

  if (identical(out$beta_prior_type, "rhs")) {
    out$beta_rhs <- bench_deep_merge(bench_qdesn_default_beta_rhs(), out$beta_rhs %||% list())
    out$beta_rhs$tau0 <- as.numeric(out$beta_rhs$tau0 %||% 0.001)
    out$beta_rhs$nu <- as.numeric(out$beta_rhs$nu %||% 4.0)
    out$beta_rhs$s2 <- as.numeric(out$beta_rhs$s2 %||% 0.1)
    out$beta_rhs$shrink_intercept <- isTRUE(out$beta_rhs$shrink_intercept %||% FALSE)
    out$beta_rhs$intercept_prec <- as.numeric(out$beta_rhs$intercept_prec %||% 1e-16)
    out$beta_rhs$n_inner <- as.integer(out$beta_rhs$n_inner %||% 1L)
    out$beta_rhs$h_curv <- as.numeric(out$beta_rhs$h_curv %||% 1e-8)
    out$beta_rhs$var_floor <- as.numeric(out$beta_rhs$var_floor %||% 1e-8)
    out$beta_rhs$verbose <- isTRUE(out$beta_rhs$verbose %||% FALSE)
    out$beta_rhs$init_log_lambda <- as.numeric(out$beta_rhs$init_log_lambda %||% 0)
    if (is.null(out$beta_rhs$init_log_tau)) {
      out$beta_rhs$init_log_tau <- NULL
    } else {
      out$beta_rhs$init_log_tau <- as.numeric(out$beta_rhs$init_log_tau)
    }
    out$beta_rhs$init_log_c2 <- as.numeric(out$beta_rhs$init_log_c2 %||% 0)
    out$beta_rhs$eta_bounds <- out$beta_rhs$eta_bounds %||% list()
    out$beta_rhs$eta_bounds$lambda <- as.numeric(unlist(out$beta_rhs$eta_bounds$lambda %||% c(-20, 20), use.names = FALSE))
    out$beta_rhs$eta_bounds$tau <- as.numeric(unlist(out$beta_rhs$eta_bounds$tau %||% c(-20, 20), use.names = FALSE))
    out$beta_rhs$eta_bounds$c2 <- as.numeric(unlist(out$beta_rhs$eta_bounds$c2 %||% c(-20, 20), use.names = FALSE))
  } else {
    out$beta_ridge_tau2 <- as.numeric(out$beta_ridge_tau2 %||% 10000)
  }

  out$vb_control <- bench_deep_merge(
    list(
      max_iter = out$max_iter,
      min_iter_elbo = out$min_iter_elbo,
      tol = out$tol,
      tol_par = out$tol_par,
      verbose = out$verbose,
      rhs_trace = out$diagnostics$rhs_trace,
      rhs_deep = out$diagnostics$rhs_deep,
      rhs_trace_thresholds = out$diagnostics$rhs_trace_thresholds,
      rhs_trace_top_k = out$diagnostics$rhs_trace_top_k,
      rhs_trace_eps = out$diagnostics$rhs_trace_eps,
      rhs_freeze_tau_iters = out$rhs$freeze_tau_iters,
      rhs_update_every = out$rhs$update_every,
      rhs_update_every_warmup = out$rhs$update_every_warmup,
      rhs_update_every_warmup_iters = out$rhs$update_every_warmup_iters,
      rhs_beta_presteps = out$rhs$beta_presteps,
      rhs_beta_presteps_iters = out$rhs$beta_presteps_iters,
      rhs_gradcheck = out$rhs$gradcheck,
      rhs_gradcheck_iters = out$rhs$gradcheck_iters,
      rhs_gradcheck_h = out$rhs$gradcheck_h,
      rhs_tau_local_tol = out$rhs$tau_local_tol,
      rhs_min_tau_updates = out$rhs$min_tau_updates,
      rhs_max_tau_updates = out$rhs$max_tau_updates,
      rhs_force_tau_after_warmup = out$rhs$force_tau_after_warmup,
      rhs_recompute_elbo_after_tau_update = out$rhs$recompute_elbo_after_tau_update
    ),
    out$vb_control %||% list()
  )

  out
}

bench_qdesn_normalize_model_cfg <- function(model_cfg, allow_single_quantile = FALSE) {
  model_cfg <- model_cfg %||% list()
  readout_approximation <- tolower(as.character(model_cfg$readout_approximation %||% "laplace_delta")[1L])
  readout_approximation <- gsub("[-[:space:]]+", "_", readout_approximation)
  if (identical(readout_approximation, "ldvb")) {
    readout_approximation <- "laplace_delta"
  }
  out <- list(
    candidate_id = as.character(model_cfg$candidate_id %||% "default"),
    seed_group_id = as.character(model_cfg$seed_group_id %||% model_cfg$candidate_id %||% "default"),
    readout_approximation = readout_approximation,
    p_vec = sort(unique(as.numeric(unlist(model_cfg$p_vec %||% c(0.05, 0.50, 0.95), use.names = FALSE)))),
    fit = bench_qdesn_normalize_fit_cfg(model_cfg$fit),
    vb_args = bench_qdesn_normalize_vb_args(model_cfg$vb_args),
    sampling = list(
      nd_draws = as.integer(model_cfg$sampling$nd_draws %||% 300L),
      chunk = as.integer(model_cfg$sampling$chunk %||% 128L)
    ),
    synthesis = list(
      n_samp = as.integer(model_cfg$synthesis$n_samp %||% 500L),
      grid_M = as.integer(model_cfg$synthesis$grid_M %||% 401L),
      isotonic = isTRUE(model_cfg$synthesis$isotonic %||% TRUE),
      rearrange = isTRUE(model_cfg$synthesis$rearrange %||% TRUE),
      seed = as.integer(model_cfg$synthesis$seed %||% 123L)
    ),
    preproc = list(
      scale_y = isTRUE(model_cfg$preproc$scale_y %||% TRUE)
    ),
    calibration = list(
      mode = tolower(as.character(model_cfg$calibration$mode %||% "none")[1L]),
      tail_h = as.integer(model_cfg$calibration$tail_h %||% NA_integer_),
      min_points = as.integer(model_cfg$calibration$min_points %||% NA_integer_),
      min_train_points = as.integer(model_cfg$calibration$min_train_points %||% NA_integer_)
    ),
    applicability = list(
      route_keys = if (is.null(model_cfg$applicability$route_keys)) NULL else as.character(unlist(model_cfg$applicability$route_keys, use.names = FALSE)),
      min_fit_points = as.integer(model_cfg$applicability$min_fit_points %||% NA_integer_),
      max_fit_points = as.integer(model_cfg$applicability$max_fit_points %||% NA_integer_)
    ),
    metrics = list(
      probs = sort(unique(as.numeric(unlist(model_cfg$metrics$probs %||% c(0.05, 0.50, 0.95), use.names = FALSE))))
    )
  )

  if (length(out$p_vec) < 2L && !isTRUE(allow_single_quantile)) {
    stop("Q-DESN synthesized forecast requires at least two quantiles in p_vec.", call. = FALSE)
  }
  if (!identical(out$readout_approximation, "laplace_delta")) {
    stop(
      sprintf(
        "Benchmark Q-DESN requires readout_approximation = 'laplace_delta'. Got '%s'.",
        out$readout_approximation
      ),
      call. = FALSE
    )
  }
  if (!out$calibration$mode %in% c("none", "bias", "affine")) {
    stop(sprintf("Unsupported benchmark Q-DESN calibration mode '%s'.", out$calibration$mode), call. = FALSE)
  }
  out$applicability$route_keys <- unique(out$applicability$route_keys)
  out
}

bench_qdesn_candidate_seed_group <- function(candidate_cfg) {
  as.character(candidate_cfg$seed_group_id %||% candidate_cfg$candidate_id %||% "default")[1L]
}

bench_qdesn_grid_expand_node <- function(node) {
  if (is.null(node)) {
    return(list(NULL))
  }

  if (!is.list(node)) {
    return(as.list(node))
  }

  node_names <- names(node)
  is_named <- !is.null(node_names) && any(nzchar(node_names))
  if (!is_named) {
    return(lapply(node, function(value) value))
  }

  child_options <- lapply(node, bench_qdesn_grid_expand_node)
  keys <- names(child_options)
  choice_grid <- expand.grid(
    lapply(child_options, seq_along),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )

  lapply(seq_len(nrow(choice_grid)), function(i) {
    out <- vector("list", length(keys))
    names(out) <- keys
    for (j in seq_along(keys)) {
      out[[j]] <- child_options[[j]][[choice_grid[[j]][[i]]]]
    }
    out
  })
}

bench_qdesn_candidate_label <- function(candidate_cfg) {
  fit <- candidate_cfg$fit
  core <- c(
    sprintf("D%d", as.integer(fit$D)),
    sprintf("n%s", paste(as.integer(fit$n), collapse = "-")),
    sprintf("m%d", as.integer(fit$m)),
    sprintf("w%d", as.integer(fit$washout))
  )

  hash <- substr(digest::digest(candidate_cfg), 1L, 8L)
  paste(c(core, hash), collapse = "__")
}

bench_qdesn_expand_candidate_grid <- function(base_cfg, grid_cfg) {
  if (is.null(grid_cfg)) {
    return(list())
  }

  block_list <- grid_cfg$blocks
  if (is.null(block_list)) {
    block_list <- list(grid_cfg)
  }

  valid_cfgs <- list()
  idx <- 1L
  for (block in block_list) {
    values_cfg <- block$values
    if (is.null(values_cfg)) {
      values_cfg <- block[setdiff(names(block), c("blocks", "values", "budget", "prefix", "candidate_id_prefix"))]
    }

    if (!length(values_cfg)) {
      next
    }

    prefix <- as.character(block$prefix %||% block$candidate_id_prefix %||% grid_cfg$prefix %||% grid_cfg$candidate_id_prefix %||% "grid")[1L]
    combos <- bench_qdesn_grid_expand_node(values_cfg)
    if (!length(combos)) {
      next
    }

    block_budget <- block$budget %||% list()
    max_candidates <- as.integer(block_budget$max_candidates %||% NA_integer_)
    sample_seed <- as.integer(block_budget$seed %||% grid_cfg$budget$seed %||% base_cfg$fit$seed %||% 123L)

    if (is.finite(max_candidates) && max_candidates > 0L && length(combos) > max_candidates) {
      set.seed(sample_seed)
      keep_idx <- sort(sample(seq_along(combos), size = max_candidates, replace = FALSE))
      combos <- combos[keep_idx]
    }

    for (combo in combos) {
      merged <- bench_deep_merge(base_cfg, combo)
      if (is.null(merged$candidate_id) || !nzchar(as.character(merged$candidate_id)[1L])) {
        merged$candidate_id <- paste(prefix, bench_qdesn_candidate_label(bench_qdesn_normalize_model_cfg(merged)), sep = "__")
      }
      valid_cfgs[[idx]] <- bench_qdesn_normalize_model_cfg(merged)
      idx <- idx + 1L
    }
  }

  valid_cfgs
}

bench_qdesn_candidate_configs <- function(cfg) {
  q_cfg <- cfg$models$qdesn_synth %||% list()
  base_cfg <- q_cfg$base %||% q_cfg
  explicit_candidates <- q_cfg$candidates %||% list()
  grid_candidates <- bench_qdesn_expand_candidate_grid(base_cfg, q_cfg$grid)

  candidates <- c(explicit_candidates, grid_candidates)
  if (!length(candidates)) {
    candidates <- list(list(candidate_id = base_cfg$candidate_id %||% "default"))
  }

  out <- lapply(candidates, function(candidate) {
    merged <- bench_deep_merge(base_cfg, candidate)
    merged$candidate_id <- candidate$candidate_id %||% merged$candidate_id %||%
      paste("grid", bench_qdesn_candidate_label(bench_qdesn_normalize_model_cfg(merged)), sep = "__")
    bench_qdesn_normalize_model_cfg(merged)
  })

  names(out) <- vapply(out, `[[`, character(1), "candidate_id")
  if (anyDuplicated(names(out))) {
    dup <- unique(names(out)[duplicated(names(out))])
    stop(sprintf("Duplicate Q-DESN candidate_id values detected: %s", paste(dup, collapse = ", ")), call. = FALSE)
  }
  out
}

bench_qdesn_candidate_registry_table <- function(candidate_cfgs) {
  if (!length(candidate_cfgs)) {
    return(data.table::data.table())
  }

  fmt <- function(x) paste(as.character(unlist(x, use.names = FALSE)), collapse = "|")
  data.table::rbindlist(lapply(candidate_cfgs, function(candidate_cfg) {
    beta_rhs <- candidate_cfg$vb_args$beta_rhs %||% list()
    rhs_ctl <- candidate_cfg$vb_args$rhs %||% list()
    data.table::data.table(
      candidate_id = candidate_cfg$candidate_id,
      seed_group_id = bench_qdesn_candidate_seed_group(candidate_cfg),
      readout_approximation = as.character(candidate_cfg$readout_approximation %||% "laplace_delta"),
      p_vec = fmt(candidate_cfg$p_vec),
      fit_D = as.integer(candidate_cfg$fit$D),
      fit_n = fmt(candidate_cfg$fit$n),
      fit_n_tilde = fmt(candidate_cfg$fit$n_tilde),
      fit_m = as.integer(candidate_cfg$fit$m),
      fit_alpha = fmt(candidate_cfg$fit$alpha),
      fit_rho = fmt(candidate_cfg$fit$rho),
      fit_pi_w = fmt(candidate_cfg$fit$pi_w),
      fit_pi_in = fmt(candidate_cfg$fit$pi_in),
      fit_washout = as.integer(candidate_cfg$fit$washout),
      fit_add_bias = as.logical(candidate_cfg$fit$add_bias),
      fit_seed_set = fmt(candidate_cfg$fit$seed_set),
      vb_max_iter = as.integer(candidate_cfg$vb_args$max_iter %||% NA_integer_),
      vb_tol = as.numeric(candidate_cfg$vb_args$tol %||% NA_real_),
      vb_beta_prior_type = as.character(candidate_cfg$vb_args$beta_prior_type %||% "ridge"),
      vb_beta_ridge_tau2 = as.numeric(candidate_cfg$vb_args$beta_ridge_tau2 %||% NA_real_),
      vb_rhs_tau0 = as.numeric(beta_rhs$tau0 %||% NA_real_),
      vb_rhs_nu = as.numeric(beta_rhs$nu %||% NA_real_),
      vb_rhs_s2 = as.numeric(beta_rhs$s2 %||% NA_real_),
      vb_rhs_init_log_tau = as.numeric(beta_rhs$init_log_tau %||% NA_real_),
      vb_rhs_init_log_lambda = as.numeric(beta_rhs$init_log_lambda %||% NA_real_),
      vb_rhs_init_log_c2 = as.numeric(beta_rhs$init_log_c2 %||% NA_real_),
      vb_rhs_eta_tau_bounds = fmt(beta_rhs$eta_bounds$tau %||% c(NA_real_, NA_real_)),
      vb_rhs_freeze_tau_iters = as.integer(rhs_ctl$freeze_tau_iters %||% NA_integer_),
      vb_rhs_freeze_tau_warmup_iters = as.integer(rhs_ctl$freeze_tau_warmup_iters %||% NA_integer_),
      vb_rhs_update_every = as.integer(rhs_ctl$update_every %||% NA_integer_),
      vb_rhs_update_every_warmup = as.integer(rhs_ctl$update_every_warmup %||% NA_integer_),
      vb_rhs_update_every_warmup_iters = as.integer(rhs_ctl$update_every_warmup_iters %||% NA_integer_),
      vb_rhs_min_tau_updates = as.integer(rhs_ctl$min_tau_updates %||% NA_integer_),
      vb_rhs_force_tau_after_warmup = as.logical(rhs_ctl$force_tau_after_warmup %||% NA),
      sampling_nd_draws = as.integer(candidate_cfg$sampling$nd_draws),
      synthesis_n_samp = as.integer(candidate_cfg$synthesis$n_samp),
      synthesis_grid_M = as.integer(candidate_cfg$synthesis$grid_M),
      preproc_scale_y = as.logical(candidate_cfg$preproc$scale_y),
      calibration_mode = as.character(candidate_cfg$calibration$mode),
      calibration_tail_h = as.integer(candidate_cfg$calibration$tail_h),
      applicability_route_keys = fmt(candidate_cfg$applicability$route_keys),
      applicability_min_fit_points = as.integer(candidate_cfg$applicability$min_fit_points),
      applicability_max_fit_points = as.integer(candidate_cfg$applicability$max_fit_points),
      metric_probs = fmt(candidate_cfg$metrics$probs)
    )
  }), fill = TRUE)
}

bench_qdesn_ensure_runtime_packages <- function(cfg) {
  requested <- bench_qdesn_baseline_names(cfg)
  if (any(requested %in% c("naive2", "ses", "holt", "damped", "theta", "comb", "ets", "auto_arima")) &&
      !requireNamespace("forecast", quietly = TRUE)) {
    install.packages("forecast", repos = "https://cloud.r-project.org")
  }

  unavailable <- requested[!vapply(requested, bench_qdesn_baseline_available, logical(1))]
  if (length(unavailable)) {
    stop(
      sprintf(
        "Requested benchmark baselines are unavailable: %s",
        paste(unavailable, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  invisible(requested)
}

bench_qdesn_validate_protocol <- function(loaded, selected_datasets, cfg) {
  meta_subset <- loaded$metadata[dataset %in% selected_datasets]
  uses_m4 <- any(meta_subset$source_family == "m4")
  if (!uses_m4) {
    return(invisible(TRUE))
  }

  if (!isTRUE(cfg$evaluation$m4_comparability$enabled %||% TRUE)) {
    return(invisible(TRUE))
  }

  baseline_names <- bench_qdesn_baseline_names(cfg)
  if (!"naive2" %in% baseline_names) {
    stop(
      "M4 comparability is enabled and at least one official M4 dataset is selected, but baseline 'naive2' is missing.",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

bench_qdesn_route_key_for_fit_n <- function(fit_n, cfg) {
  routing_cfg <- cfg$evaluation$routing %||% list(enabled = FALSE)
  if (!isTRUE(routing_cfg$enabled %||% FALSE)) {
    return("global")
  }

  fit_n <- as.integer(fit_n)[1L]
  breaks <- as.integer(unlist(routing_cfg$breaks %||% c(120L, 600L), use.names = FALSE))
  labels <- as.character(unlist(routing_cfg$labels %||% c("short", "medium", "long"), use.names = FALSE))
  if (length(labels) != (length(breaks) + 1L)) {
    stop("Routing labels must have length equal to length(breaks) + 1.", call. = FALSE)
  }

  bucket <- findInterval(fit_n, vec = breaks, rightmost.closed = TRUE) + 1L
  labels[[bucket]]
}

bench_qdesn_assign_route <- function(bundle, cfg) {
  bundle$route_key <- bench_qdesn_route_key_for_fit_n(length(bundle$fit_y), cfg)
  bundle
}

bench_qdesn_candidate_applicable <- function(candidate_cfg, fit_n = NA_integer_, route_key = "global") {
  app <- candidate_cfg$applicability %||% list()
  route_keys <- app$route_keys
  route_ok <- is.null(route_keys) || !length(route_keys) ||
    any(route_key %in% route_keys) ||
    any(route_keys %in% "all") ||
    (identical(route_key, "global") && any(route_keys %in% "global"))
  min_fit <- as.integer(app$min_fit_points %||% NA_integer_)
  max_fit <- as.integer(app$max_fit_points %||% NA_integer_)
  fit_ok <- TRUE
  if (is.finite(fit_n)) {
    if (is.finite(min_fit)) fit_ok <- fit_ok && fit_n >= min_fit
    if (is.finite(max_fit)) fit_ok <- fit_ok && fit_n <= max_fit
  }
  isTRUE(route_ok && fit_ok)
}

bench_qdesn_select_route_candidates <- function(candidate_cfgs, route_key, fit_n = NA_integer_) {
  keep <- vapply(candidate_cfgs, bench_qdesn_candidate_applicable, logical(1), fit_n = fit_n, route_key = route_key)
  candidate_cfgs[keep]
}

bench_qdesn_route_map <- function(loaded, dataset_name, series_ids, cfg) {
  if (!length(series_ids)) {
    return(data.table::data.table())
  }

  rows <- lapply(series_ids, function(series_id) {
    bundle <- bench_qdesn_assign_route(
      bench_qdesn_build_series_bundle(loaded, dataset_name, series_id, stage = "test", cfg = cfg),
      cfg
    )
    data.table::data.table(
      dataset = dataset_name,
      series_id = series_id,
      route_key = bundle$route_key,
      fit_n = length(bundle$fit_y),
      eval_n = length(bundle$eval_y),
      forecast_horizon = bundle$forecast_horizon
    )
  })

  data.table::rbindlist(rows, fill = TRUE)
}

bench_qdesn_series_ids_for_route <- function(route_map, series_ids, route_key) {
  route_map <- data.table::as.data.table(route_map)
  if (!nrow(route_map) || !length(series_ids)) {
    return(character(0))
  }

  route_key_value <- as.character(route_key)[1L]
  unique(route_map[series_id %in% series_ids & route_key %chin% route_key_value, series_id])
}

bench_qdesn_status_row <- function(bundle, model_name, candidate_id, status, runtime_sec, error_message = NA_character_, notes = NA_character_) {
  data.table::data.table(
    dataset = bundle$dataset,
    source_family = bundle$source_family,
    benchmark_pool = bundle$benchmark_pool,
    route_key = bundle$route_key %||% "global",
    series_id = bundle$series_id,
    stage = bundle$stage,
    model_name = model_name,
    candidate_id = candidate_id,
    status = status,
    runtime_sec = as.numeric(runtime_sec),
    error_message = as.character(error_message),
    notes = as.character(notes)
  )
}

bench_qdesn_run_qdesn_draws <- function(y_fit, h, candidate_cfg, seed_tag, keep_details = FALSE) {
  candidate_cfg <- bench_qdesn_normalize_model_cfg(candidate_cfg)
  scaler <- bench_qdesn_scale_spec(y_fit, scale_y = candidate_cfg$preproc$scale_y)
  y_fit_scaled <- scaler$forward(y_fit)
  seed_set <- as.integer(candidate_cfg$fit$seed_set %||% candidate_cfg$fit$seed)
  if (!length(seed_set)) {
    seed_set <- as.integer(candidate_cfg$fit$seed)
  }

  fit_args_template <- candidate_cfg$fit
  fit_args_template$seed_set <- NULL

  run_one_seed <- function(seed_val) {
    fit_args_base <- fit_args_template
    fit_args_base$seed <- bench_qdesn_string_seed(seed_tag, base_seed = seed_val)
    fits <- vector("list", length(candidate_cfg$p_vec))
    names(fits) <- paste0("p=", candidate_cfg$p_vec)
    draws_list <- vector("list", length(candidate_cfg$p_vec))
    rhs_rows <- vector("list", length(candidate_cfg$p_vec))

    for (i in seq_along(candidate_cfg$p_vec)) {
      tau <- candidate_cfg$p_vec[[i]]
      fit_args <- fit_args_base
      fit_args$y <- y_fit_scaled
      fit_args$p0 <- tau
      fit_args$vb_args <- candidate_cfg$vb_args
      fits[[i]] <- do.call(qdesn_fit_vb, fit_args)
      fore <- forecast_paths.qdesn_fit(
        fits[[i]],
        H = h,
        nd = candidate_cfg$sampling$nd_draws,
        y_hist = y_fit_scaled,
        chunk = candidate_cfg$sampling$chunk,
        seed = fit_args_base$seed + as.integer(round(1000 * tau))
      )
      draws_list[[i]] <- as.matrix(fore$yrep)
      rhs_rows[[i]] <- bench_qdesn_rhs_diagnostics_row(
        qfit = fits[[i]],
        p0 = tau,
        candidate_cfg = candidate_cfg,
        seed = fit_args_base$seed
      )
    }

    synth_scaled <- quantileSynthesis(
      draws_list = draws_list,
      p = candidate_cfg$p_vec,
      enforce_isotonic = candidate_cfg$synthesis$isotonic,
      rearrange = candidate_cfg$synthesis$rearrange,
      grid_M = candidate_cfg$synthesis$grid_M,
      n_samp = candidate_cfg$synthesis$n_samp,
      seed = fit_args_base$seed + candidate_cfg$synthesis$seed,
      T_expected = h
    )

    list(
      seed = fit_args_base$seed,
      draws = scaler$inverse_matrix(synth_scaled$draws),
      quantiles = scaler$inverse_matrix(synth_scaled$quantiles),
      per_quantile_draws = lapply(draws_list, scaler$inverse_matrix),
      rhs_diagnostics = data.table::rbindlist(rhs_rows, fill = TRUE),
      quantile_fits = if (isTRUE(keep_details)) fits else NULL
    )
  }

  seed_runs <- lapply(seed_set, run_one_seed)
  pooled_draws <- do.call(cbind, lapply(seed_runs, `[[`, "draws"))
  pooled_quantile_draws <- lapply(seq_along(candidate_cfg$p_vec), function(i) {
    do.call(cbind, lapply(seed_runs, function(run) run$per_quantile_draws[[i]]))
  })
  rhs_dt <- data.table::rbindlist(lapply(seed_runs, `[[`, "rhs_diagnostics"), fill = TRUE)

  list(
    draws = pooled_draws,
    quantile_draws = pooled_quantile_draws,
    rhs_diagnostics = rhs_dt,
    seed_set = vapply(seed_runs, `[[`, integer(1), "seed"),
    seed_runs = if (isTRUE(keep_details)) seed_runs else NULL
  )
}

bench_qdesn_recalibrate_draws <- function(fit_y, candidate_cfg, cfg, seed_tag, target_draws, forecast_horizon) {
  cal_h <- bench_qdesn_calibration_horizon(
    fit_n = length(fit_y),
    forecast_horizon = forecast_horizon,
    candidate_cfg = candidate_cfg,
    cfg = cfg
  )
  if (cal_h <= 0L) {
    return(list(
      draws = target_draws,
      recalibration = list(mode = "none", intercept = 0, slope = 1, n_cal = 0L),
      cal_h = 0L
    ))
  }

  fit_core <- fit_y[seq_len(length(fit_y) - cal_h)]
  cal_y <- tail(fit_y, cal_h)
  cal_fore <- bench_qdesn_run_qdesn_draws(
    y_fit = fit_core,
    h = cal_h,
    candidate_cfg = candidate_cfg,
    seed_tag = paste(seed_tag, "calibration", sep = "::"),
    keep_details = FALSE
  )

  recalibration <- bench_qdesn_fit_recalibration(
    y_true = cal_y,
    draws = cal_fore$draws,
    mode = candidate_cfg$calibration$mode %||% "none"
  )

  list(
    draws = bench_qdesn_apply_recalibration(target_draws, recalibration),
    recalibration = recalibration,
    cal_h = cal_h
  )
}

bench_qdesn_run_qdesn_series <- function(bundle, candidate_cfg, cfg, keep_artifacts = FALSE) {
  t0 <- Sys.time()
  candidate_cfg <- bench_qdesn_normalize_model_cfg(candidate_cfg)
  model_name <- "qdesn_synth"
  seed_tag <- paste(
    bundle$dataset,
    bundle$series_id,
    bundle$stage,
    bench_qdesn_candidate_seed_group(candidate_cfg),
    bundle$route_key %||% "global",
    sep = "::"
  )

  result <- tryCatch(
    {
      h <- length(bundle$eval_y)
      raw_fore <- bench_qdesn_run_qdesn_draws(
        y_fit = bundle$fit_y,
        h = h,
        candidate_cfg = candidate_cfg,
        seed_tag = seed_tag,
        keep_details = keep_artifacts
      )
      calibrated <- bench_qdesn_recalibrate_draws(
        fit_y = bundle$fit_y,
        candidate_cfg = candidate_cfg,
        cfg = cfg,
        seed_tag = seed_tag,
        target_draws = raw_fore$draws,
        forecast_horizon = bundle$forecast_horizon
      )
      synth_draws <- calibrated$draws
      scored <- bench_qdesn_score_forecast(
        bundle = bundle,
        model_name = model_name,
        draws = synth_draws,
        probs = candidate_cfg$metrics$probs
      )
      quantile_eval_cfg <- cfg$evaluation$quantile_eval %||% list(enabled = TRUE, tail_threshold = 0.10)
      quantile_metrics <- if (isTRUE(quantile_eval_cfg$enabled %||% TRUE)) {
        bench_qdesn_quantile_metrics_table(
          bundle = bundle,
          p_vec = candidate_cfg$p_vec,
          quantile_draws = raw_fore$quantile_draws,
          tail_threshold = quantile_eval_cfg$tail_threshold %||% 0.10
        )
      } else {
        data.table::data.table()
      }
      if (nrow(quantile_metrics)) {
        quantile_metrics[, `:=`(
          model_name = "qdesn_quantile_model",
          parent_model_name = model_name,
          candidate_id = candidate_cfg$candidate_id,
          seed_count = length(raw_fore$seed_set)
        )]
      }
      rhs_diagnostics <- data.table::as.data.table(raw_fore$rhs_diagnostics)
      if (nrow(rhs_diagnostics)) {
        rhs_diagnostics[, `:=`(
          dataset = bundle$dataset,
          source_family = bundle$source_family,
          benchmark_pool = bundle$benchmark_pool,
          route_key = bundle$route_key %||% "global",
          series_id = bundle$series_id,
          stage = bundle$stage,
          benchmark_split_protocol = bundle$benchmark_split_protocol,
          selection_protocol = bundle$selection_protocol,
          candidate_id = candidate_cfg$candidate_id,
          parent_model_name = model_name
        )]
      }
      quantile_summary <- bench_qdesn_quantile_summary_row(quantile_metrics)
      rhs_summary <- bench_qdesn_rhs_summary_row(rhs_diagnostics)

      scored$series_metrics[, candidate_id := candidate_cfg$candidate_id]
      scored$lead_metrics[, candidate_id := candidate_cfg$candidate_id]
      scored$forecast_summary[, candidate_id := candidate_cfg$candidate_id]
      scored$series_metrics[, fit_seed_count := as.integer(length(raw_fore$seed_set))]
      scored$series_metrics[, vb_beta_prior_type := as.character(candidate_cfg$vb_args$beta_prior_type %||% "ridge")]
      scored$series_metrics[, calibration_mode := as.character(candidate_cfg$calibration$mode %||% "none")]
      for (nm in names(quantile_summary)) {
        scored$series_metrics[, (nm) := quantile_summary[[nm]]]
      }
      for (nm in names(rhs_summary)) {
        scored$series_metrics[, (nm) := rhs_summary[[nm]]]
      }

      artifacts <- NULL
      if (isTRUE(keep_artifacts)) {
        artifacts <- list(
          dataset = bundle$dataset,
          dataset_label = bundle$dataset_label,
          source_family = bundle$source_family,
          series_id = bundle$series_id,
          route_key = bundle$route_key,
          stage = bundle$stage,
          model_name = model_name,
          candidate_id = candidate_cfg$candidate_id,
          p_vec = candidate_cfg$p_vec,
          synth_draws = synth_draws,
          quantile_draws = raw_fore$quantile_draws,
          per_seed_draws = if (!is.null(raw_fore$seed_runs)) lapply(raw_fore$seed_runs, `[[`, "draws") else NULL,
          seed_run_details = raw_fore$seed_runs,
          quantile_fit_details = if (!is.null(raw_fore$seed_runs)) {
            lapply(raw_fore$seed_runs, `[[`, "quantile_fits")
          } else {
            NULL
          },
          fit_seed_set = raw_fore$seed_set,
          rhs_diagnostics = rhs_diagnostics,
          recalibration = calibrated$recalibration,
          calibration_h = calibrated$cal_h,
          fit_y = bundle$fit_y,
          eval_y = bundle$eval_y,
          fit_idx = bundle$fit_idx,
          eval_idx = bundle$eval_idx,
          timestamp = bundle$timestamp,
          timestamp_eval = bundle$timestamp[bundle$eval_idx],
          t_index = bundle$t_index,
          seasonal_period = bundle$seasonal_period,
          forecast_horizon = bundle$forecast_horizon
        )
      }

      list(
        ok = TRUE,
        series_metrics = scored$series_metrics,
        lead_metrics = scored$lead_metrics,
        forecast_summary = scored$forecast_summary,
        quantile_model_metrics = quantile_metrics,
        rhs_diagnostics = rhs_diagnostics,
        status = bench_qdesn_status_row(bundle, model_name, candidate_cfg$candidate_id, "ok", difftime(Sys.time(), t0, units = "secs")),
        artifacts = artifacts
      )
    },
    error = function(e) {
      list(
        ok = FALSE,
        series_metrics = data.table::data.table(),
        lead_metrics = data.table::data.table(),
        forecast_summary = data.table::data.table(),
        quantile_model_metrics = data.table::data.table(),
        rhs_diagnostics = data.table::data.table(),
        status = bench_qdesn_status_row(
          bundle,
          model_name,
          candidate_cfg$candidate_id,
          "failed",
          difftime(Sys.time(), t0, units = "secs"),
          error_message = conditionMessage(e)
        ),
        artifacts = NULL
      )
    }
  )

  result
}

bench_qdesn_run_baseline_series <- function(bundle, baseline_name, cfg, probs = c(0.05, 0.50, 0.95), keep_artifacts = FALSE) {
  t0 <- Sys.time()
  h <- length(bundle$eval_y)
  seed <- bench_qdesn_string_seed(paste(bundle$dataset, bundle$series_id, baseline_name, sep = "::"))

  result <- tryCatch(
    {
      base_res <- bench_qdesn_run_baseline(
        model_name = baseline_name,
        train_y = bundle$fit_y,
        h = h,
        seasonal_period = bundle$seasonal_period,
        n_draws = as.integer(cfg$evaluation$baselines$n_draws %||% 500L),
        seed = seed
      )

      scored <- bench_qdesn_score_forecast(
        bundle = bundle,
        model_name = baseline_name,
        draws = base_res$draws,
        probs = probs
      )
      scored$series_metrics[, candidate_id := baseline_name]
      scored$lead_metrics[, candidate_id := baseline_name]
      scored$forecast_summary[, candidate_id := baseline_name]

      artifacts <- NULL
      if (isTRUE(keep_artifacts)) {
        artifacts <- list(
          dataset = bundle$dataset,
          source_family = bundle$source_family,
          series_id = bundle$series_id,
          stage = bundle$stage,
          model_name = baseline_name,
          candidate_id = baseline_name,
          draws = base_res$draws
        )
      }

      list(
        ok = TRUE,
        series_metrics = scored$series_metrics,
        lead_metrics = scored$lead_metrics,
        forecast_summary = scored$forecast_summary,
        status = bench_qdesn_status_row(bundle, baseline_name, baseline_name, "ok", difftime(Sys.time(), t0, units = "secs")),
        artifacts = artifacts
      )
    },
    error = function(e) {
      list(
        ok = FALSE,
        series_metrics = data.table::data.table(),
        lead_metrics = data.table::data.table(),
        forecast_summary = data.table::data.table(),
        status = bench_qdesn_status_row(
          bundle,
          baseline_name,
          baseline_name,
          "failed",
          difftime(Sys.time(), t0, units = "secs"),
          error_message = conditionMessage(e)
        ),
        artifacts = NULL
      )
    }
  )

  result
}

bench_qdesn_selection_summary_from_detail <- function(detail_dt) {
  detail_dt <- data.table::as.data.table(detail_dt)
  mean_na <- function(x) if (all(!is.finite(x))) NA_real_ else mean(x, na.rm = TRUE)
  max_na <- function(x) if (all(!is.finite(x))) NA_real_ else max(x, na.rm = TRUE)
  min_na <- function(x) if (all(!is.finite(x))) NA_real_ else min(x, na.rm = TRUE)

  if (!nrow(detail_dt)) {
    return(data.table::data.table())
  }

  detail_dt[, .(
    n_series = sum(status == "ok"),
    n_applicable = sum(status != "inapplicable"),
    n_failed = sum(status == "failed"),
    n_inapplicable = sum(status == "inapplicable"),
    crps_mean = mean(crps_mean, na.rm = TRUE),
    pinball_mean = mean(pinball_mean, na.rm = TRUE),
    mase_mean = mean(mase_mean, na.rm = TRUE),
    smape_mean = mean(smape_mean, na.rm = TRUE),
    msis95_mean = mean(msis95_mean, na.rm = TRUE),
    coverage95_mean = mean(coverage95_mean, na.rm = TRUE),
    acd95_mean = mean(acd95_mean, na.rm = TRUE),
    quantile_pinball_mean = mean_na(quantile_pinball_mean),
    tail_pinball_mean = mean_na(tail_pinball_mean),
    quantile_abs_coverage_dev_mean = mean_na(quantile_abs_coverage_dev_mean),
    max_abs_quantile_coverage_dev = max_na(max_abs_quantile_coverage_dev),
    tail_abs_quantile_coverage_dev_mean = mean_na(tail_abs_quantile_coverage_dev_mean),
    tail_abs_quantile_coverage_dev_max = max_na(tail_abs_quantile_coverage_dev_max),
    quantile_abs_pit_dev_mean = mean_na(quantile_abs_pit_dev_mean),
    max_abs_pit_dev_mean = max_na(max_abs_pit_dev_mean),
    shoulder_pinball_mean = mean_na(shoulder_pinball_mean),
    reference_pinball_mean = mean_na(reference_pinball_mean),
    shoulder_pinball_ratio = mean_na(shoulder_pinball_ratio),
    shoulder_qhat_abs_mean = mean_na(shoulder_qhat_abs_mean),
    reference_qhat_abs_mean = mean_na(reference_qhat_abs_mean),
    shoulder_qhat_ratio = mean_na(shoulder_qhat_ratio),
    rhs_quantile_rows = sum(rhs_quantile_rows, na.rm = TRUE),
    rhs_collapse_n = sum(rhs_collapse_n, na.rm = TRUE),
    rhs_near_bound_n = sum(rhs_near_bound_n, na.rm = TRUE),
    rhs_tau_last_min = min_na(rhs_tau_last_min),
    rhs_tau_last_median = mean_na(rhs_tau_last_median),
    rhs_E_invV_med_max = max_na(rhs_E_invV_med_max),
    rhs_beta_l2_min = min_na(rhs_beta_l2_min),
    runtime_sec = sum(runtime_sec, na.rm = TRUE)
  ), by = .(dataset, route_key, candidate_id)]
}

bench_qdesn_selection_job <- function(dataset_name, loaded, series_id, candidate_id, candidate_cfg, cfg, route_key) {
  bundle <- bench_qdesn_assign_route(
    bench_qdesn_build_series_bundle(loaded, dataset_name, series_id, stage = "validation", cfg = cfg),
    cfg
  )

  if (!bench_qdesn_candidate_applicable(candidate_cfg, fit_n = length(bundle$fit_y), route_key = route_key)) {
    return(list(
      detail_row = data.table::data.table(
        dataset = dataset_name,
        route_key = route_key,
        series_id = series_id,
        candidate_id = candidate_id,
        status = "inapplicable",
        crps_mean = NA_real_,
        pinball_mean = NA_real_,
        mase_mean = NA_real_,
        smape_mean = NA_real_,
        msis95_mean = NA_real_,
        coverage95_mean = NA_real_,
        acd95_mean = NA_real_,
        quantile_pinball_mean = NA_real_,
        tail_pinball_mean = NA_real_,
        quantile_abs_coverage_dev_mean = NA_real_,
        max_abs_quantile_coverage_dev = NA_real_,
        tail_abs_quantile_coverage_dev_mean = NA_real_,
        tail_abs_quantile_coverage_dev_max = NA_real_,
        quantile_abs_pit_dev_mean = NA_real_,
        max_abs_pit_dev_mean = NA_real_,
        shoulder_pinball_mean = NA_real_,
        reference_pinball_mean = NA_real_,
        shoulder_pinball_ratio = NA_real_,
        shoulder_qhat_abs_mean = NA_real_,
        reference_qhat_abs_mean = NA_real_,
        shoulder_qhat_ratio = NA_real_,
        rhs_quantile_rows = NA_real_,
        rhs_collapse_n = NA_real_,
        rhs_near_bound_n = NA_real_,
        rhs_tau_last_min = NA_real_,
        rhs_tau_last_median = NA_real_,
        rhs_E_invV_med_max = NA_real_,
        rhs_beta_l2_min = NA_real_,
        runtime_sec = NA_real_
      ),
      quantile_model_metrics = data.table::data.table(),
      rhs_diagnostics = data.table::data.table()
    ))
  }

  res <- bench_qdesn_run_qdesn_series(bundle, candidate_cfg, cfg = cfg, keep_artifacts = FALSE)
  metric_row <- if (res$ok && nrow(res$series_metrics)) res$series_metrics[1L] else data.table::data.table()
  list(
    detail_row = data.table::data.table(
      dataset = dataset_name,
      route_key = route_key,
      series_id = series_id,
      candidate_id = candidate_id,
      status = res$status$status[[1L]],
      crps_mean = if (nrow(metric_row)) metric_row$crps_mean[[1L]] else NA_real_,
      pinball_mean = if (nrow(metric_row)) metric_row$pinball_mean[[1L]] else NA_real_,
      mase_mean = if (nrow(metric_row)) metric_row$mase_mean[[1L]] else NA_real_,
      smape_mean = if (nrow(metric_row)) metric_row$smape_mean[[1L]] else NA_real_,
      msis95_mean = if (nrow(metric_row)) metric_row$msis95_mean[[1L]] else NA_real_,
      coverage95_mean = if (nrow(metric_row)) metric_row$coverage95_mean[[1L]] else NA_real_,
      acd95_mean = if (nrow(metric_row)) metric_row$acd95_mean[[1L]] else NA_real_,
      quantile_pinball_mean = if (nrow(metric_row)) metric_row$quantile_pinball_mean[[1L]] else NA_real_,
      tail_pinball_mean = if (nrow(metric_row)) metric_row$tail_pinball_mean[[1L]] else NA_real_,
      quantile_abs_coverage_dev_mean = if (nrow(metric_row)) metric_row$quantile_abs_coverage_dev_mean[[1L]] else NA_real_,
      max_abs_quantile_coverage_dev = if (nrow(metric_row)) metric_row$max_abs_quantile_coverage_dev[[1L]] else NA_real_,
      tail_abs_quantile_coverage_dev_mean = if (nrow(metric_row)) metric_row$tail_abs_quantile_coverage_dev_mean[[1L]] else NA_real_,
      tail_abs_quantile_coverage_dev_max = if (nrow(metric_row)) metric_row$tail_abs_quantile_coverage_dev_max[[1L]] else NA_real_,
      quantile_abs_pit_dev_mean = if (nrow(metric_row)) metric_row$quantile_abs_pit_dev_mean[[1L]] else NA_real_,
      max_abs_pit_dev_mean = if (nrow(metric_row)) metric_row$max_abs_pit_dev_mean[[1L]] else NA_real_,
      shoulder_pinball_mean = if (nrow(metric_row)) metric_row$shoulder_pinball_mean[[1L]] else NA_real_,
      reference_pinball_mean = if (nrow(metric_row)) metric_row$reference_pinball_mean[[1L]] else NA_real_,
      shoulder_pinball_ratio = if (nrow(metric_row)) metric_row$shoulder_pinball_ratio[[1L]] else NA_real_,
      shoulder_qhat_abs_mean = if (nrow(metric_row)) metric_row$shoulder_qhat_abs_mean[[1L]] else NA_real_,
      reference_qhat_abs_mean = if (nrow(metric_row)) metric_row$reference_qhat_abs_mean[[1L]] else NA_real_,
      shoulder_qhat_ratio = if (nrow(metric_row)) metric_row$shoulder_qhat_ratio[[1L]] else NA_real_,
      rhs_quantile_rows = if (nrow(metric_row)) metric_row$rhs_quantile_rows[[1L]] else NA_real_,
      rhs_collapse_n = if (nrow(metric_row)) metric_row$rhs_collapse_n[[1L]] else NA_real_,
      rhs_near_bound_n = if (nrow(metric_row)) metric_row$rhs_near_bound_n[[1L]] else NA_real_,
      rhs_tau_last_min = if (nrow(metric_row)) metric_row$rhs_tau_last_min[[1L]] else NA_real_,
      rhs_tau_last_median = if (nrow(metric_row)) metric_row$rhs_tau_last_median[[1L]] else NA_real_,
      rhs_E_invV_med_max = if (nrow(metric_row)) metric_row$rhs_E_invV_med_max[[1L]] else NA_real_,
      rhs_beta_l2_min = if (nrow(metric_row)) metric_row$rhs_beta_l2_min[[1L]] else NA_real_,
      runtime_sec = as.numeric(res$status$runtime_sec[[1L]])
    ),
    quantile_model_metrics = res$quantile_model_metrics %||% data.table::data.table(),
    rhs_diagnostics = res$rhs_diagnostics %||% data.table::data.table()
  )
}

bench_qdesn_select_candidate_for_dataset <- function(dataset_name, loaded, series_ids, candidate_cfgs, cfg, route_key = "global", run_dirs = NULL) {
  selection_metric_name <- as.character(cfg$evaluation$selection$metric %||% "crps_mean")[1L]
  tie_breakers <- as.character(unlist(
    cfg$evaluation$selection$tie_breakers %||%
      c("rhs_collapse_n", "rhs_near_bound_n", "shoulder_pinball_ratio", "shoulder_qhat_ratio", "tail_pinball_mean", "quantile_abs_coverage_dev_mean", "runtime_sec", "candidate_id"),
    use.names = FALSE
  ))
  workers <- as.integer(cfg$evaluation$parallel$workers %||% 1L)
  detail_parts <- list()
  quantile_parts <- list()
  rhs_parts <- list()
  idx_detail <- idx_quantile <- idx_rhs <- 1L
  candidate_ids <- names(candidate_cfgs)
  checkpoint_each_candidate <- isTRUE(cfg$evaluation$selection$checkpoint_each_candidate %||% FALSE)

  for (candidate_pos in seq_along(candidate_ids)) {
    candidate_id_value <- candidate_ids[[candidate_pos]]
    candidate_cfg <- candidate_cfgs[[candidate_id_value]]
    message(sprintf(
      "[benchmark_qdesn] selection dataset=%s route=%s candidate=%s start (%d/%d)",
      dataset_name,
      route_key,
      candidate_id_value,
      candidate_pos,
      length(candidate_ids)
    ))

    candidate_results <- bench_qdesn_lapply(
      series_ids,
      function(series_id) {
        bench_qdesn_selection_job(
          dataset_name = dataset_name,
          loaded = loaded,
          series_id = series_id,
          candidate_id = candidate_id_value,
          candidate_cfg = candidate_cfg,
          cfg = cfg,
          route_key = route_key
        )
      },
      workers = workers
    )

    candidate_detail <- data.table::rbindlist(lapply(candidate_results, `[[`, "detail_row"), fill = TRUE)
    candidate_quantile <- data.table::rbindlist(lapply(candidate_results, `[[`, "quantile_model_metrics"), fill = TRUE)
    candidate_rhs <- data.table::rbindlist(lapply(candidate_results, `[[`, "rhs_diagnostics"), fill = TRUE)

    detail_parts[[idx_detail]] <- candidate_detail
    idx_detail <- idx_detail + 1L
    if (nrow(candidate_quantile)) {
      quantile_parts[[idx_quantile]] <- candidate_quantile
      idx_quantile <- idx_quantile + 1L
    }
    if (nrow(candidate_rhs)) {
      rhs_parts[[idx_rhs]] <- candidate_rhs
      idx_rhs <- idx_rhs + 1L
    }

    partial_detail <- data.table::rbindlist(detail_parts, fill = TRUE)
    partial_quantile <- if (length(quantile_parts)) data.table::rbindlist(quantile_parts, fill = TRUE) else data.table::data.table()
    partial_rhs <- if (length(rhs_parts)) data.table::rbindlist(rhs_parts, fill = TRUE) else data.table::data.table()
    partial_summary <- bench_qdesn_selection_summary_from_detail(partial_detail)
    if (nrow(partial_summary)) {
      partial_summary[, selection_metric := selection_metric_name]
      partial_summary[, selection_metric_value := get(selection_metric_name)]
      partial_summary <- partial_summary[n_applicable > 0]
      partial_summary <- bench_qdesn_apply_selection_guards(partial_summary, cfg)
    }

    candidate_row <- partial_summary[candidate_id %chin% candidate_id_value][1L]
    message(sprintf(
      "[benchmark_qdesn] selection dataset=%s route=%s candidate=%s done ok=%s failed=%s eligible=%s reason=%s runtime=%.1fs",
      dataset_name,
      route_key,
      candidate_id_value,
      as.integer(candidate_row$n_series %||% 0L),
      as.integer(candidate_row$n_failed %||% 0L),
      as.character(candidate_row$eligible %||% NA)[1L],
      as.character(candidate_row$eligibility_reason %||% NA_character_)[1L],
      as.numeric(candidate_row$runtime_sec %||% 0)
    ))

    if (!is.null(run_dirs) && checkpoint_each_candidate) {
      bench_qdesn_write_selection_checkpoint(
        run_dirs = run_dirs,
        dataset_name = dataset_name,
        route_key = route_key,
        summary_dt = partial_summary,
        detail_dt = partial_detail,
        quantile_rows = partial_quantile,
        rhs_rows = partial_rhs,
        completed_candidates = candidate_pos,
        total_candidates = length(candidate_ids),
        last_candidate_id = candidate_id_value
      )
    }
  }

  detail_dt <- data.table::rbindlist(detail_parts, fill = TRUE)
  quantile_rows <- if (length(quantile_parts)) data.table::rbindlist(quantile_parts, fill = TRUE) else data.table::data.table()
  rhs_rows <- if (length(rhs_parts)) data.table::rbindlist(rhs_parts, fill = TRUE) else data.table::data.table()
  summary_dt <- bench_qdesn_selection_summary_from_detail(detail_dt)
  if (!selection_metric_name %in% names(summary_dt)) {
    stop(sprintf("Unknown selection metric '%s'.", selection_metric_name), call. = FALSE)
  }
  summary_dt[, selection_metric := selection_metric_name]
  summary_dt[, selection_metric_value := get(selection_metric_name)]
  summary_dt <- summary_dt[n_applicable > 0]
  summary_dt <- bench_qdesn_apply_selection_guards(summary_dt, cfg)
  summary_dt[, `:=`(selection_failed = FALSE, selection_error_message = NA_character_)]
  detail_dt[, `:=`(selection_failed = FALSE, selection_error_message = NA_character_)]
  eligible_dt <- summary_dt[eligible %in% TRUE]
  sort_cols <- unique(c("selection_metric_value", "n_failed", tie_breakers))
  sort_cols <- sort_cols[sort_cols %in% names(eligible_dt)]
  data.table::setorderv(eligible_dt, cols = sort_cols, order = rep(1L, length(sort_cols)))

  if (!nrow(eligible_dt) || !is.finite(eligible_dt$selection_metric_value[[1L]])) {
    reason_suffix <- ""
    veto_count_list <- list()
    if (nrow(summary_dt)) {
      veto_dt <- summary_dt[eligible %in% FALSE & !is.na(eligibility_reason)]
      if (nrow(veto_dt)) {
        veto_counts <- sort(table(unlist(strsplit(veto_dt$eligibility_reason, "\\|", fixed = FALSE))), decreasing = TRUE)
        veto_counts <- veto_counts[nzchar(names(veto_counts))]
        if (length(veto_counts)) {
          veto_count_list <- as.list(stats::setNames(as.integer(veto_counts), names(veto_counts)))
          reason_suffix <- paste0(
            " Guard veto summary: ",
            paste(sprintf("%s=%d", names(veto_counts), as.integer(veto_counts)), collapse = ", "),
            "."
          )
        }
      }
    }
    msg <- sprintf(
      "No successful validation runs for dataset '%s' under selection metric '%s'.%s",
      dataset_name,
      selection_metric_name,
      reason_suffix
    )
    summary_dt[, `:=`(selected = FALSE, selection_failed = TRUE, selection_error_message = msg)]
    detail_dt[, `:=`(selection_failed = TRUE, selection_error_message = msg)]
    data.table::setorderv(summary_dt, cols = c("dataset", "route_key", "eligible", "selection_metric_value", "candidate_id"), order = c(1L, 1L, -1L, 1L, 1L))
    stop(
      structure(
        list(
          message = msg,
          dataset = dataset_name,
          route_key = route_key,
          selection_metric = selection_metric_name,
          summary = summary_dt,
          detail = detail_dt,
          quantile_model_metrics = quantile_rows,
          rhs_diagnostics = rhs_rows,
          veto_counts = veto_count_list
        ),
        class = c("bench_qdesn_selection_error", "error", "condition")
      )
    )
  }

  winner_id <- eligible_dt$candidate_id[[1L]]
  summary_dt[, selected := candidate_id == winner_id]
  data.table::setorderv(summary_dt, cols = c("dataset", "route_key", "selected", "eligible", "selection_metric_value", "candidate_id"), order = c(1L, 1L, -1L, -1L, 1L, 1L))

  list(
    winner_id = winner_id,
    summary = summary_dt,
    detail = detail_dt,
    quantile_model_metrics = quantile_rows,
    rhs_diagnostics = rhs_rows
  )
}

bench_qdesn_evaluate_series_models <- function(bundle, candidate_cfg, cfg, keep_audit_artifacts = FALSE) {
  qdesn_res <- bench_qdesn_run_qdesn_series(bundle, candidate_cfg, cfg = cfg, keep_artifacts = keep_audit_artifacts)
  baseline_names <- bench_qdesn_baseline_names(cfg)
  baseline_res <- lapply(baseline_names, function(name) {
    bench_qdesn_run_baseline_series(bundle, name, cfg, probs = candidate_cfg$metrics$probs, keep_artifacts = FALSE)
  })

  all_results <- c(list(qdesn_res), baseline_res)
  list(
    series_metrics = data.table::rbindlist(lapply(all_results, `[[`, "series_metrics"), fill = TRUE),
    lead_metrics = data.table::rbindlist(lapply(all_results, `[[`, "lead_metrics"), fill = TRUE),
    forecast_summary = data.table::rbindlist(lapply(all_results, `[[`, "forecast_summary"), fill = TRUE),
    quantile_model_metrics = qdesn_res$quantile_model_metrics %||% data.table::data.table(),
    rhs_diagnostics = qdesn_res$rhs_diagnostics %||% data.table::data.table(),
    series_status = data.table::rbindlist(lapply(all_results, `[[`, "status"), fill = TRUE),
    artifacts = qdesn_res$artifacts
  )
}

bench_qdesn_default_cfg <- function(cfg) {
  cfg$evaluation <- cfg$evaluation %||% list()
  cfg$evaluation$experiment_name <- cfg$evaluation$experiment_name %||% "qdesn_synth"
  cfg$evaluation$result_root <- cfg$evaluation$result_root %||% "results/benchmarks/qdesn_synth"
  cfg$evaluation$max_series_per_dataset <- cfg$evaluation$max_series_per_dataset %||% NULL
  cfg$evaluation$parallel <- cfg$evaluation$parallel %||% list(workers = 1L)
  cfg$evaluation$series_overrides <- cfg$evaluation$series_overrides %||% list()
  for (purpose in c("evaluation", "selection", "audit")) {
    override_map <- cfg$evaluation$series_overrides[[purpose]] %||% list()
    if (length(override_map)) {
      override_map <- lapply(override_map, function(ids) {
        unique(as.character(unlist(ids, use.names = FALSE)))
      })
    }
    cfg$evaluation$series_overrides[[purpose]] <- override_map
  }
  cfg$evaluation$selection <- cfg$evaluation$selection %||% list(enabled = TRUE, subset_size = 6L, min_train_points = 24L)
  cfg$evaluation$selection$enabled <- isTRUE(cfg$evaluation$selection$enabled %||% TRUE)
  cfg$evaluation$selection$subset_size <- as.integer(cfg$evaluation$selection$subset_size %||% 6L)
  cfg$evaluation$selection$metric <- as.character(cfg$evaluation$selection$metric %||% "crps_mean")[1L]
  cfg$evaluation$selection$checkpoint_each_candidate <- isTRUE(cfg$evaluation$selection$checkpoint_each_candidate %||% FALSE)
  cfg$evaluation$selection$tie_breakers <- as.character(unlist(
    cfg$evaluation$selection$tie_breakers %||%
      c("rhs_collapse_n", "rhs_near_bound_n", "shoulder_pinball_ratio", "shoulder_qhat_ratio", "tail_pinball_mean", "quantile_abs_coverage_dev_mean", "runtime_sec", "candidate_id"),
    use.names = FALSE
  ))
  cfg$evaluation$selection$quantile_guard <- cfg$evaluation$selection$quantile_guard %||% list(
    enabled = TRUE,
    max_abs_coverage_dev = 0.35,
    max_abs_tail_coverage_dev = 0.40,
    max_abs_pit_dev_mean = 0.25,
    max_shoulder_pinball_ratio = 100,
    max_shoulder_qhat_ratio = 100,
    forbid_rhs_collapse = TRUE,
    forbid_rhs_near_bound = TRUE,
    relax_if_no_eligible_candidates = FALSE
  )
  cfg$evaluation$routing <- cfg$evaluation$routing %||% list(enabled = FALSE, breaks = c(120L, 600L), labels = c("short", "medium", "long"), fallback = "dataset")
  cfg$evaluation$routing$enabled <- isTRUE(cfg$evaluation$routing$enabled %||% FALSE)
  cfg$evaluation$routing$breaks <- as.integer(unlist(cfg$evaluation$routing$breaks %||% c(120L, 600L), use.names = FALSE))
  cfg$evaluation$routing$labels <- as.character(unlist(cfg$evaluation$routing$labels %||% c("short", "medium", "long"), use.names = FALSE))
  cfg$evaluation$routing$fallback <- as.character(cfg$evaluation$routing$fallback %||% "dataset")[1L]
  cfg$evaluation$quantile_eval <- cfg$evaluation$quantile_eval %||% list(enabled = TRUE, tail_threshold = 0.10)
  cfg$evaluation$quantile_eval$enabled <- isTRUE(cfg$evaluation$quantile_eval$enabled %||% TRUE)
  cfg$evaluation$quantile_eval$tail_threshold <- as.numeric(cfg$evaluation$quantile_eval$tail_threshold %||% 0.10)
  cfg$evaluation$audit <- cfg$evaluation$audit %||% list(subset_size = 2L, save_draws = TRUE)
  cfg$evaluation$audit$subset_size <- as.integer(cfg$evaluation$audit$subset_size %||% 2L)
  cfg$evaluation$audit$save_draws <- isTRUE(cfg$evaluation$audit$save_draws %||% TRUE)
  cfg$evaluation$baselines <- cfg$evaluation$baselines %||% list(models = c("naive", "seasonal_naive", "naive2", "drift"), n_draws = 500L)
  cfg$evaluation$baselines$n_draws <- as.integer(cfg$evaluation$baselines$n_draws %||% 500L)
  cfg$evaluation$m4_comparability <- cfg$evaluation$m4_comparability %||% list(enabled = TRUE)
  cfg$evaluation$m4_comparability$enabled <- isTRUE(cfg$evaluation$m4_comparability$enabled %||% TRUE)
  cfg
}

bench_qdesn_override_series_ids <- function(meta_ds, cfg, dataset_name, purpose = c("evaluation", "selection", "audit")) {
  purpose <- match.arg(purpose)
  override_map <- cfg$evaluation$series_overrides[[purpose]] %||% list()
  ids <- override_map[[as.character(dataset_name)[1L]]]
  if (is.null(ids)) {
    return(NULL)
  }

  ids <- unique(as.character(unlist(ids, use.names = FALSE)))
  ids <- ids[nzchar(ids)]
  if (!length(ids)) {
    return(character(0))
  }

  available_ids <- unique(as.character(meta_ds$series_id))
  unknown <- setdiff(ids, available_ids)
  if (length(unknown)) {
    stop(
      sprintf(
        "Unknown %s override series for dataset '%s': %s",
        purpose,
        as.character(dataset_name)[1L],
        paste(unknown, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  ids
}

bench_qdesn_run_experiment <- function(context) {
  cfg <- bench_qdesn_default_cfg(context$config)
  loaded <- bench_qdesn_load_processed(context)
  selected_datasets <- bench_qdesn_select_datasets(loaded, cfg)
  bench_qdesn_validate_protocol(loaded, selected_datasets, cfg)
  bench_qdesn_ensure_runtime_packages(cfg)
  candidate_cfgs <- bench_qdesn_candidate_configs(cfg)
  candidate_registry <- bench_qdesn_candidate_registry_table(candidate_cfgs)
  run_dirs <- bench_qdesn_run_dirs(context, cfg)
  bench_qdesn_write_run_manifest(context, cfg, run_dirs, selected_datasets)
  bench_write_json(candidate_cfgs, file.path(run_dirs$manifests_dir, "candidate_registry.json"))

  series_metrics_all <- list()
  lead_metrics_all <- list()
  forecast_summary_all <- list()
  quantile_model_metrics_all <- list()
  rhs_diagnostics_all <- list()
  series_status_all <- list()
  selection_summary_all <- list()
  selection_detail_all <- list()
  idx_sm <- idx_lm <- idx_fs <- idx_qm <- idx_rhs <- idx_st <- idx_sel <- idx_seld <- 1L

  bind_or_empty <- function(lst) {
    if (!length(lst)) return(data.table::data.table())
    data.table::rbindlist(lst, fill = TRUE)
  }

  collect_results <- function() {
    out <- list(
      series_metrics = bind_or_empty(series_metrics_all),
      lead_metrics = bind_or_empty(lead_metrics_all),
      forecast_summary = bind_or_empty(forecast_summary_all),
      quantile_model_metrics = bind_or_empty(quantile_model_metrics_all),
      rhs_diagnostics = bind_or_empty(rhs_diagnostics_all),
      series_status = bind_or_empty(series_status_all),
      model_selection_summary = bind_or_empty(selection_summary_all),
      model_selection_detail = bind_or_empty(selection_detail_all),
      candidate_registry = candidate_registry
    )
    out$m4_comparability <- bench_qdesn_m4_comparability_table(out$series_metrics)
    out
  }

  for (dataset_name in selected_datasets) {
    message(sprintf("[benchmark_qdesn] dataset=%s", dataset_name))
    dataset_name_local <- as.character(dataset_name)[1L]
    meta_ds <- loaded$metadata[dataset == dataset_name_local]
    eval_ids <- bench_qdesn_override_series_ids(meta_ds, cfg, dataset_name_local, "evaluation")
    if (is.null(eval_ids)) {
      eval_ids <- bench_qdesn_select_series_ids(
        meta_ds,
        n_target = cfg$evaluation$max_series_per_dataset,
        purpose = "evaluation"
      )
    }
    audit_ids <- bench_qdesn_override_series_ids(meta_ds, cfg, dataset_name_local, "audit")
    if (is.null(audit_ids)) {
      audit_ids <- bench_qdesn_select_series_ids(
        meta_ds[series_id %in% eval_ids],
        n_target = cfg$evaluation$audit$subset_size,
        purpose = "audit"
      )
    } else if (!all(audit_ids %in% eval_ids)) {
      stop(
        sprintf(
          "Audit overrides for dataset '%s' must be a subset of evaluation series.",
          dataset_name_local
        ),
        call. = FALSE
      )
    }
    selection_ids_all <- if (cfg$evaluation$selection$enabled) {
      override_ids <- bench_qdesn_override_series_ids(meta_ds, cfg, dataset_name_local, "selection")
      if (is.null(override_ids)) {
        bench_qdesn_select_series_ids(
          meta_ds,
          n_target = cfg$evaluation$selection$subset_size,
          purpose = "selection"
        )
      } else {
        override_ids
      }
    } else {
      character(0)
    }
    route_map <- bench_qdesn_route_map(
      loaded = loaded,
      dataset_name = dataset_name_local,
      series_ids = unique(c(eval_ids, selection_ids_all)),
      cfg = cfg
    )
    route_keys_needed <- if (isTRUE(cfg$evaluation$routing$enabled)) {
      unique(route_map[series_id %in% eval_ids]$route_key)
    } else {
      "global"
    }
    winner_map <- list()

    for (route_key in route_keys_needed) {
      candidate_cfgs_route <- if (route_key == "global") {
        candidate_cfgs
      } else {
        bench_qdesn_select_route_candidates(candidate_cfgs, route_key = route_key)
      }
      if (!length(candidate_cfgs_route)) {
        stop(sprintf("No candidate configurations available for dataset '%s' and route '%s'.", dataset_name_local, route_key), call. = FALSE)
      }

      route_selection_ids <- if (route_key == "global") {
        selection_ids_all
      } else {
        bench_qdesn_series_ids_for_route(route_map, selection_ids_all, route_key)
      }
      if (!length(route_selection_ids) && identical(cfg$evaluation$routing$fallback, "dataset")) {
        route_selection_ids <- selection_ids_all
      }

      if (cfg$evaluation$selection$enabled && length(candidate_cfgs_route) > 1L && length(route_selection_ids)) {
        sel_res <- tryCatch(
          bench_qdesn_select_candidate_for_dataset(
            dataset_name = dataset_name_local,
            loaded = loaded,
            series_ids = route_selection_ids,
            candidate_cfgs = candidate_cfgs_route,
            cfg = cfg,
            route_key = route_key,
            run_dirs = run_dirs
          ),
          bench_qdesn_selection_error = function(e) {
            if (nrow(e$summary)) {
              selection_summary_all[[idx_sel]] <<- e$summary
              idx_sel <<- idx_sel + 1L
            }
            if (nrow(e$detail)) {
              selection_detail_all[[idx_seld]] <<- e$detail
              idx_seld <<- idx_seld + 1L
            }
            if (nrow(e$quantile_model_metrics)) {
              quantile_model_metrics_all[[idx_qm]] <<- e$quantile_model_metrics
              idx_qm <<- idx_qm + 1L
            }
            if (nrow(e$rhs_diagnostics)) {
              rhs_diagnostics_all[[idx_rhs]] <<- e$rhs_diagnostics
              idx_rhs <<- idx_rhs + 1L
            }

            partial_results <- collect_results()
            summary_dt <- bench_qdesn_dataset_summary_table(partial_results$series_metrics)
            bench_qdesn_write_failure_state(
              run_dirs = run_dirs,
              failure = list(
                type = "selection_error",
                dataset = dataset_name_local,
                route_key = route_key,
                selection_metric = e$selection_metric,
                message = conditionMessage(e),
                veto_counts = e$veto_counts
              ),
              partial_results = partial_results,
              summary_dt = summary_dt
            )
            stop(e)
          }
        )
        winner_cfg <- candidate_cfgs_route[[sel_res$winner_id]]
        selection_summary_all[[idx_sel]] <- sel_res$summary
        selection_detail_all[[idx_seld]] <- sel_res$detail
        if (nrow(sel_res$quantile_model_metrics)) {
          quantile_model_metrics_all[[idx_qm]] <- sel_res$quantile_model_metrics
          idx_qm <- idx_qm + 1L
        }
        if (nrow(sel_res$rhs_diagnostics)) {
          rhs_diagnostics_all[[idx_rhs]] <- sel_res$rhs_diagnostics
          idx_rhs <- idx_rhs + 1L
        }
        idx_sel <- idx_sel + 1L
        idx_seld <- idx_seld + 1L
        message(sprintf("[benchmark_qdesn] dataset=%s route=%s winner=%s", dataset_name, route_key, sel_res$winner_id))
      } else {
        winner_cfg <- candidate_cfgs_route[[1L]]
        selection_summary_all[[idx_sel]] <- data.table::data.table(
          dataset = dataset_name,
          route_key = route_key,
          candidate_id = winner_cfg$candidate_id,
          selection_metric = as.character(cfg$evaluation$selection$metric %||% "crps_mean")[1L],
          selection_metric_value = NA_real_,
          n_series = NA_integer_,
          n_applicable = NA_integer_,
          n_failed = NA_integer_,
          n_inapplicable = NA_integer_,
          crps_mean = NA_real_,
          pinball_mean = NA_real_,
          mase_mean = NA_real_,
          smape_mean = NA_real_,
          msis95_mean = NA_real_,
          coverage95_mean = NA_real_,
          acd95_mean = NA_real_,
          runtime_sec = NA_real_,
          selected = TRUE
        )
        idx_sel <- idx_sel + 1L
      }

      winner_map[[route_key]] <- winner_cfg
    }

    workers <- as.integer(cfg$evaluation$parallel$workers %||% 1L)
    series_results <- bench_qdesn_lapply(eval_ids, function(series_id) {
      bundle <- bench_qdesn_assign_route(
        bench_qdesn_build_series_bundle(loaded, dataset_name_local, series_id, stage = "test", cfg = cfg),
        cfg
      )
      winner_cfg <- winner_map[[bundle$route_key %||% "global"]] %||% winner_map[["global"]] %||% winner_map[[1L]]
      keep_artifacts <- isTRUE(cfg$evaluation$audit$save_draws) && series_id %in% audit_ids
      bench_qdesn_evaluate_series_models(bundle, winner_cfg, cfg, keep_audit_artifacts = keep_artifacts)
    }, workers = workers)

    for (res in series_results) {
      if (nrow(res$series_metrics)) {
        series_metrics_all[[idx_sm]] <- res$series_metrics
        idx_sm <- idx_sm + 1L
      }
      if (nrow(res$lead_metrics)) {
        lead_metrics_all[[idx_lm]] <- res$lead_metrics
        idx_lm <- idx_lm + 1L
      }
      if (nrow(res$forecast_summary)) {
        forecast_summary_all[[idx_fs]] <- res$forecast_summary
        idx_fs <- idx_fs + 1L
      }
      if (nrow(res$quantile_model_metrics)) {
        quantile_model_metrics_all[[idx_qm]] <- res$quantile_model_metrics
        idx_qm <- idx_qm + 1L
      }
      if (nrow(res$rhs_diagnostics)) {
        rhs_diagnostics_all[[idx_rhs]] <- res$rhs_diagnostics
        idx_rhs <- idx_rhs + 1L
      }
      if (nrow(res$series_status)) {
        series_status_all[[idx_st]] <- res$series_status
        idx_st <- idx_st + 1L
      }
      if (!is.null(res$artifacts)) {
        bench_qdesn_save_audit_artifact(run_dirs, res)
      }
    }
  }

  results <- collect_results()
  bench_qdesn_write_experiment_tables(results, run_dirs)
  summary_dt <- bench_qdesn_dataset_summary_table(results$series_metrics)
  bench_save_table(summary_dt, file.path(run_dirs$tables_dir, "dataset_model_summary"), write_csv = TRUE, write_rds = TRUE, compress = "gzip")

  list(
    run_dirs = run_dirs,
    datasets = selected_datasets,
    results = results,
    summary = summary_dt
  )
}
