# Utilities for model selection v2 (YAML-driven workflow)

`%||%` <- function(x, alt) if (!is.null(x)) x else alt

ms_deep_merge <- function(a, b) {
  if (is.null(b)) return(a)
  if (is.null(a)) return(b)
  if (is.list(a) && is.list(b)) {
    na <- names(a)
    nb <- names(b)
    if (is.null(na) || is.null(nb)) return(b)
    if (!length(na) || !length(nb)) return(b)
    keys <- unique(c(na, nb))
    out <- lapply(keys, function(k) ms_deep_merge(a[[k]], b[[k]]))
    names(out) <- keys
    out
  } else {
    b
  }
}

ms_read_yaml <- function(path) {
  yaml::read_yaml(path)
}

ms_write_yaml <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(x, path)
}

ms_fix_bool_keys <- function(x) {
  if (is.null(x) || !is.list(x)) return(x)
  nm <- names(x)
  if (!is.null(nm) && "TRUE" %in% nm)  { x[["y"]] <- x[["TRUE"]];  x[["TRUE"]]  <- NULL }
  if (!is.null(nm) && "FALSE" %in% nm) { x[["n"]] <- x[["FALSE"]]; x[["FALSE"]] <- NULL }
  x
}

ms_fix_desn_keys <- function(d) {
  if (is.null(d) || !is.list(d)) return(d)
  nm <- names(d)
  if (!is.null(nm) && "FALSE" %in% nm) { d[["n"]] <- d[["FALSE"]]; d[["FALSE"]] <- NULL }
  d
}

ms_fix_cfg_keys <- function(x) {
  if (is.null(x) || !is.list(x)) return(x)
  if (!is.null(x[["desn"]]))    x[["desn"]]    <- ms_fix_desn_keys(x[["desn"]])
  if (!is.null(x[["columns"]])) x[["columns"]] <- ms_fix_bool_keys(x[["columns"]])
  x
}

ms_norm_num <- function(x) {
  if (is.null(x)) return(NULL)
  if (is.list(x)) x <- unlist(x, use.names = FALSE)
  x <- as.numeric(x)
  if (length(x) == 0L || all(is.na(x))) return(NULL)
  x
}

ms_norm_int <- function(x) {
  x <- ms_norm_num(x)
  if (is.null(x)) return(NULL)
  as.integer(x)
}

ms_sanitize_vector_len <- function(x, D) {
  if (is.null(x)) return(x)
  if (length(x) == 1L && D > 1L) return(rep(x, D))
  x
}

ms_resolve_desn <- function(cfg) {
  if (is.null(cfg$desn)) return(cfg)
  d <- cfg$desn
  Dcfg <- as.integer((d$D %||% 1L))

  n_vec       <- ms_norm_int(d$n)
  n_tilde_vec <- ms_norm_int(d$n_tilde)
  rho_vec     <- ms_norm_num(d$rho)

  if (is.null(n_vec)) stop("Config error: desn$n is missing.")

  if (Dcfg > 1L && length(n_vec) == 1L) n_vec <- rep(n_vec, Dcfg)
  if (!is.null(rho_vec) && Dcfg > 1L && length(rho_vec) == 1L) rho_vec <- rep(rho_vec, Dcfg)

  if (length(n_vec) != Dcfg) {
    stop(sprintf("Config error: length(desn$n)=%d but desn$D=%d", length(n_vec), Dcfg))
  }

  if (Dcfg <= 1L) {
    n_tilde_vec <- integer(0)
  } else {
    if (is.null(n_tilde_vec)) {
      stop(sprintf("Config error: desn$n_tilde is required when desn$D=%d", Dcfg))
    }
    if (length(n_tilde_vec) == 1L) n_tilde_vec <- rep(n_tilde_vec, Dcfg - 1L)
    if (length(n_tilde_vec) != (Dcfg - 1L)) {
      stop(sprintf("Config error: length(desn$n_tilde)=%d but expected D-1=%d",
                   length(n_tilde_vec), Dcfg - 1L))
    }
  }

  cfg$desn$D <- Dcfg
  cfg$desn$n <- n_vec
  cfg$desn$n_tilde <- n_tilde_vec
  if (!is.null(rho_vec)) cfg$desn$rho <- rho_vec
  cfg
}

ms_resolve_split <- function(cfg_split, T_full) {
  use_last   <- TRUE
  T_use      <- T_full
  train_n    <- NULL
  train_prop <- NULL

  if (!is.null(cfg_split)) {
    has_train_n    <- "train_n"    %in% names(cfg_split)
    has_train_prop <- "train_prop" %in% names(cfg_split)

    if (!is.null(cfg_split$use_last))   use_last   <- isTRUE(cfg_split$use_last)
    if (!is.null(cfg_split$use_prop))   T_use      <- max(1L, floor(as.numeric(cfg_split$use_prop) * T_full))
    if (!is.null(cfg_split$T_use))      T_use      <- as.integer(cfg_split$T_use)
    if (has_train_n)                    train_n    <- suppressWarnings(as.integer(cfg_split$train_n))
    if (has_train_prop)                 train_prop <- suppressWarnings(as.numeric(cfg_split$train_prop))

    norm_opt <- function(x) {
      if (is.null(x)) return(NULL)
      if (length(x) == 0L) return(NULL)
      if (all(is.na(x))) return(NULL)
      x
    }
    train_n    <- norm_opt(train_n)
    train_prop <- norm_opt(train_prop)
  }

  T_use <- min(T_full, as.integer(T_use))
  idx_use <- if (use_last) seq.int(T_full - T_use + 1L, T_full) else seq_len(T_use)

  if (!is.null(train_n) && !is.null(train_prop)) {
    stop(sprintf("Split config conflict: both train_n (%s) and train_prop (%s) are set.",
                 as.character(train_n), as.character(train_prop)))
  }
  if (!is.null(train_prop) && !(is.finite(train_prop) && train_prop > 0 && train_prop < 1)) {
    stop(sprintf("Invalid train_prop=%s. Must be in (0,1).", as.character(train_prop)))
  }
  if (!is.null(train_n) && !(is.finite(train_n) && train_n >= 1L && train_n <= (T_use - 1L))) {
    stop(sprintf("Invalid train_n=%s for T_use=%d. Must be in [1, %d].",
                 as.character(train_n), T_use, T_use - 1L))
  }

  n_train <- if (!is.null(train_n)) {
    as.integer(train_n)
  } else if (!is.null(train_prop)) {
    max(1L, min(T_use - 1L, floor(train_prop * T_use)))
  } else {
    max(1L, min(T_use - 1L, floor(0.9 * T_use)))
  }

  H_forecast <- as.integer(T_use - n_train)
  if (H_forecast < 1L) {
    stop(sprintf("Invalid split: H_forecast=%d (n_train=%d, T_use=%d).", H_forecast, n_train, T_use))
  }

  list(
    use_last = use_last,
    T_use = T_use,
    idx_use = idx_use,
    n_train = n_train,
    H_forecast = H_forecast
  )
}

ms_build_origin_set_sim <- function(split_info) {
  n_train <- split_info$n_train
  T_use <- split_info$T_use
  origins_full <- seq.int(n_train, T_use)
  origins_lead1 <- if (T_use > n_train) seq.int(n_train, T_use - 1L) else integer(0)
  targets <- origins_lead1 + 1L
  list(origins_full = origins_full, origins_lead1 = origins_lead1, targets = targets)
}

ms_build_origin_set_real <- function(split_info, X_all, forecast_horizon) {
  n_train <- split_info$n_train
  T_use <- split_info$T_use
  idx_use <- split_info$idx_use

  origins_full_max  <- T_use
  origins_lead1_max <- T_use - 1L
  xreg_all_full <- NULL
  xreg_all_lead1 <- NULL

  if (!is.null(X_all) && ncol(X_all) > 0) {
    start_idx <- idx_use[1L]
    end_avail <- nrow(X_all)
    xreg_len <- end_avail - start_idx + 1L

    max_origin_by_x_full <- xreg_len - forecast_horizon
    origins_full_max <- min(T_use, max_origin_by_x_full)
    if (origins_full_max < n_train) {
      stop(sprintf("Not enough exogenous rows for forecast_horizon=%d.", forecast_horizon))
    }

    end_needed_full <- start_idx + origins_full_max + forecast_horizon - 1L
    X_future_full <- X_all[start_idx:end_needed_full, , drop = FALSE]
    xreg_all_full <- lapply(seq_len(ncol(X_future_full)), function(j) X_future_full[, j])
    names(xreg_all_full) <- colnames(X_future_full)

    max_origin_by_x1 <- xreg_len - 1L
    origins_lead1_max <- min(T_use - 1L, max_origin_by_x1)
    end_needed_1 <- start_idx + origins_lead1_max
    X_future_1 <- X_all[start_idx:end_needed_1, , drop = FALSE]
    xreg_all_lead1 <- lapply(seq_len(ncol(X_future_1)), function(j) X_future_1[, j])
    names(xreg_all_lead1) <- colnames(X_future_1)
  }

  origins_full <- seq.int(n_train, origins_full_max)
  origins_lead1 <- seq.int(n_train, origins_lead1_max)
  targets <- origins_lead1 + 1L

  list(
    origins_full = origins_full,
    origins_lead1 = origins_lead1,
    targets = targets,
    xreg_all_full = xreg_all_full,
    xreg_all_lead1 = xreg_all_lead1
  )
}

ms_deterministic_origin_subsample <- function(origins, policy, frac = NULL, seed = NULL, stride_k = NULL) {
  policy <- tolower(policy %||% "all")
  if (policy == "all" || length(origins) == 0L) return(origins)
  if (policy == "stride") {
    k <- as.integer(stride_k %||% 1L)
    if (k <= 1L) return(origins)
    return(origins[seq(1L, length(origins), by = k)])
  }
  if (policy == "subsample") {
    frac <- as.numeric(frac %||% 1)
    if (!is.finite(frac) || frac <= 0 || frac >= 1) return(origins)
    n <- length(origins)
    m <- max(1L, floor(frac * n))
    if (!is.null(seed)) set.seed(as.integer(seed))
    return(sort(sample(origins, size = m, replace = FALSE)))
  }
  origins
}

ms_crps_empirical_sorted <- function(x, target) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 1L) return(NA_real_)
  x <- sort(x)
  term1 <- mean(abs(x - target))
  term2 <- sum((2 * seq_len(n) - n - 1) * x) / (n^2)
  term1 - term2
}

ms_crps_row <- function(y, z) {
  z <- sort(z)
  M <- length(z)
  mean(abs(z - y)) - sum((2 * seq_len(M) - M - 1) * z) / (M^2)
}

ms_crps_vec <- function(y_vec, draws_mat) {
  stopifnot(length(y_vec) == nrow(draws_mat))
  vapply(seq_len(nrow(draws_mat)), function(i) ms_crps_row(y_vec[i], draws_mat[i, ]), numeric(1))
}

ms_calcrps_from_predictive_draws <- function(y_true, yrep_mat, tau) {
  yrep_mat <- as.matrix(yrep_mat)
  if (nrow(yrep_mat) != length(y_true)) {
    stop("yrep_mat rows must match length(y_true)")
  }
  R <- ncol(yrep_mat)
  c_draws <- numeric(R)
  for (r in seq_len(R)) {
    c_draws[r] <- mean(y_true <= yrep_mat[, r])
  }
  cal_crps <- ms_crps_empirical_sorted(c_draws, tau)
  list(cal_crps = cal_crps, c_draws = c_draws)
}

ms_p_vec_id <- function(p_vec) {
  digest::digest(as.numeric(p_vec))
}

ms_verify_window_id <- function(t_start, t_end, lead_set_id, origins_spec_id, weight_spec_id) {
  digest::digest(list(t_start = t_start, t_end = t_end, lead_set_id = lead_set_id,
                      origins_spec_id = origins_spec_id, weight_spec_id = weight_spec_id))
}

ms_origins_spec_id <- function(policy, frac = NULL, seed = NULL, stride_k = NULL) {
  digest::digest(list(policy = policy, frac = frac, seed = seed, stride_k = stride_k))
}

ms_weight_spec_id <- function() {
  "uniform"
}

ms_candidate_id <- function(candidate) {
  digest::digest(candidate)
}

ms_expand_candidate_grid <- function(grid, budget = NULL, seed = NULL) {
  if (is.null(grid)) return(list())

  if (!is.null(grid$n_list)) {
    n_list <- grid$n_list
    if (!is.list(n_list)) stop("candidate_grid$n_list must be a list of numeric vectors")
    candidates <- lapply(seq_along(n_list), function(i) list(n = as.integer(n_list[[i]])))
    return(candidates)
  }

  D_vals <- grid$D %||% 1L
  n1_vals <- grid$n1 %||% 500L
  r2_vals <- grid$r2 %||% 1.0
  r3_vals <- grid$r3 %||% 1.0
  n_tilde_vals <- grid$n_tilde %||% NULL
  m_vals <- grid$m %||% 50L
  alpha_vals <- grid$alpha %||% 0.2
  rho_vals <- grid$rho %||% 0.95
  seed_vals <- grid$seed %||% NA

  grid_df <- expand.grid(
    D = as.integer(D_vals),
    n1 = as.integer(n1_vals),
    r2 = as.numeric(r2_vals),
    r3 = as.numeric(r3_vals),
    m = as.integer(m_vals),
    alpha = as.numeric(alpha_vals),
    rho = as.numeric(rho_vals),
    seed = as.numeric(seed_vals),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )

  candidates <- lapply(seq_len(nrow(grid_df)), function(i) {
    row <- grid_df[i, ]
    D <- as.integer(row$D)
    n1 <- as.integer(row$n1)
    r2 <- as.numeric(row$r2)
    r3 <- as.numeric(row$r3)
    n_vec <- if (D == 1L) {
      c(n1)
    } else if (D == 2L) {
      c(n1, max(1L, as.integer(round(n1 * r2))))
    } else {
      c(n1,
        max(1L, as.integer(round(n1 * r2))),
        max(1L, as.integer(round(n1 * r3))))
    }
    # Default repo-native n_tilde if not explicitly provided:
    # for D>1, use the subsequent layer sizes (length D-1), i.e. n_tilde = n[2:D].
    n_tilde_default <- if (D > 1L) as.integer(n_vec[2:D]) else integer(0)
    list(
      D = D,
      n = as.integer(n_vec),
      n_tilde = if (!is.null(n_tilde_vals)) as.integer(n_tilde_vals) else n_tilde_default,
      m = as.integer(row$m),
      alpha = as.numeric(row$alpha),
      rho = as.numeric(row$rho),
      seed = as.numeric(row$seed)
    )
  })

  if (!is.null(budget) && is.list(budget) && !is.null(budget$max_candidates)) {
    max_candidates <- as.integer(budget$max_candidates)
    if (length(candidates) > max_candidates) {
      if (!is.null(seed)) set.seed(as.integer(seed))
      keep_idx <- sample(seq_along(candidates), size = max_candidates, replace = FALSE)
      candidates <- candidates[sort(keep_idx)]
    }
  }

  candidates
}

ms_build_stage_candidates <- function(stage, prev_candidates = NULL, prev_summary = NULL) {
  if (!is.null(stage$candidate_grid)) {
    return(ms_expand_candidate_grid(stage$candidate_grid, stage$budget, stage$origins$seed %||% NULL))
  }
  if (!is.null(stage$candidate_refine) && !is.null(prev_summary)) {
    k <- as.integer(stage$candidate_refine$top_k_from_previous %||% 5L)
    top_ids <- head(prev_summary$candidate_id, k)
    if (!length(top_ids)) return(list())
    out <- prev_candidates[prev_summary$candidate_idx[seq_len(min(k, nrow(prev_summary)) )]]
    return(out)
  }
  list()
}

ms_maybe_use_default <- function(value, default_val) {
  if (is.character(value) && length(value) == 1L && tolower(value) == "use_default") return(default_val)
  if (is.null(value)) return(default_val)
  value
}

ms_build_readout_design_sim <- function(y_full, desn_args, readout_include_input, readout_reservoir_lags) {
  shared_fit <- do.call(qdesn_fit_vb, c(list(y = y_full, p0 = 0.50, fit_readout = FALSE), desn_args))
  keep_all_abs <- as.integer(shared_fit$meta$keep_idx)
  X_all_kept <- as.matrix(shared_fit$X)

  sanitize_colnames <- function(nm, n, prefix = "x") {
    if (is.null(nm) || length(nm) != n) nm <- rep("", n)
    nm <- as.character(nm)
    nm[is.na(nm)] <- ""
    empty_idx <- which(!nzchar(nm))
    if (length(empty_idx)) nm[empty_idx] <- sprintf("%s_%03d", prefix, empty_idx)
    nm <- make.unique(nm, sep = "_")
    nm
  }

  make_reservoir_colnames <- function(D, n_vec, n_tilde, add_bias) {
    D <- as.integer(D)
    n_vec <- as.integer(n_vec)
    n_tilde <- as.integer(n_tilde)
    if (D <= 1L) {
      base <- paste0("h1_", seq_len(n_vec[1L]))
    } else {
      base <- paste0("h", D, "_", seq_len(n_vec[D]))
      for (d in seq_len(D - 1L)) {
        nt <- if (length(n_tilde) >= d && is.finite(n_tilde[d]) && n_tilde[d] > 0L) n_tilde[d] else n_vec[d]
        base <- c(base, paste0("htilde", d, "_", seq_len(nt)))
      }
    }
    if (isTRUE(add_bias)) c("bias", base) else base
  }

  res_names <- make_reservoir_colnames(desn_args$D, desn_args$n, desn_args$n_tilde, desn_args$add_bias)
  if (length(res_names) == ncol(X_all_kept)) {
    colnames(X_all_kept) <- sanitize_colnames(res_names, ncol(X_all_kept), prefix = "res")
  } else {
    colnames(X_all_kept) <- sanitize_colnames(colnames(X_all_kept), ncol(X_all_kept), prefix = "res")
  }

  build_lag_mat_vec <- function(vec, lags, prefix = "lag_") {
    if (!length(lags)) return(NULL)
    cols <- lapply(lags, function(L) c(rep(NA_real_, L), vec[seq_len(length(vec) - L)]))
    out <- do.call(cbind, cols)
    colnames(out) <- paste0(prefix, lags)
    out
  }

  build_mat_lags <- function(M, lags, prefix = "lag_") {
    if (is.null(M) || !length(lags)) return(NULL)
    n <- nrow(M)
    p <- ncol(M)
    base <- colnames(M)
    if (is.null(base)) base <- paste0("z", seq_len(p))
    out_list <- lapply(lags, function(L) {
      rbind(matrix(NA_real_, nrow = L, ncol = p), M[seq_len(n - L), , drop = FALSE])
    })
    out <- do.call(cbind, out_list)
    colnames(out) <- unlist(lapply(lags, function(L) paste0(base, "_", prefix, L)), use.names = FALSE)
    out
  }

  cbind_safe <- function(...) {
    parts <- Filter(Negate(is.null), list(...))
    if (!length(parts)) return(NULL)
    do.call(cbind, parts)
  }

  input_lags_y <- if (isTRUE(readout_include_input) && as.integer(desn_args$m) > 0L) {
    seq_len(as.integer(desn_args$m))
  } else integer(0)
  res_lags_vec <- if (readout_reservoir_lags > 0L) seq_len(readout_reservoir_lags) else integer(0)

  X_res_all <- X_all_kept
  input_block_all <- NULL
  if (length(input_lags_y)) {
    y_lag_all <- build_lag_mat_vec(y_full, input_lags_y, prefix = "in_y_lag_")
    input_block_all <- y_lag_all[keep_all_abs, , drop = FALSE]
  }

  z_lag_all <- NULL
  if (length(res_lags_vec)) {
    X_res_no_bias <- if (isTRUE(desn_args$add_bias)) X_all_kept[, -1, drop = FALSE] else X_all_kept
    z_lag_all <- build_mat_lags(X_res_no_bias, res_lags_vec, prefix = "res_lag_")
  }

  keep_aug_abs <- keep_all_abs
  if (length(res_lags_vec)) {
    if (length(keep_all_abs) <= readout_reservoir_lags) stop("Not enough rows to apply reservoir_lags at readout.")
    keep_idx <- seq.int(readout_reservoir_lags + 1L, length(keep_all_abs))
    keep_aug_abs <- keep_all_abs[keep_idx]
    X_res_all <- X_res_all[keep_idx, , drop = FALSE]
    if (!is.null(input_block_all)) input_block_all <- input_block_all[keep_idx, , drop = FALSE]
    if (!is.null(z_lag_all)) z_lag_all <- z_lag_all[keep_idx, , drop = FALSE]
  }

  X_aug_all <- cbind_safe(X_res_all, input_block_all, z_lag_all)
  if (is.null(X_aug_all)) stop("Failed to build readout design matrix.")
  colnames(X_aug_all) <- sanitize_colnames(colnames(X_aug_all), ncol(X_aug_all), prefix = "x")

  list(shared_fit = shared_fit, X_aug_all = X_aug_all, X_res_all = X_res_all, keep_aug_abs = keep_aug_abs)
}

ms_build_readout_design_real <- function(y_full, X_use, cfg, desn_args, readout_include_input, readout_reservoir_lags, readout_scale) {
  lags_cfg <- cfg$lags %||% list()
  exp_y <- lags_cfg$y
  exp_x <- lags_cfg$x
  m_y <- as.integer(lags_cfg$m_y %||% 0L)
  m_x <- as.integer(lags_cfg$m_x %||% 0L)
  lags_y <- if (!is.null(exp_y)) as.integer(exp_y) else if (m_y > 0L) seq_len(m_y) else integer(0)
  lags_x <- if (!is.null(exp_x)) as.integer(exp_x) else if (m_x > 0L) 0:m_x else integer(0)
  lags_y <- unique(lags_y)
  lags_x <- unique(lags_x)
  lag_max <- max(c(0L, lags_y, lags_x))

  build_lag_mat <- function(vec, lags) {
    if (!length(lags)) return(NULL)
    cols <- lapply(lags, function(L) c(rep(NA_real_, L), vec[seq_len(length(vec) - L)]))
    out <- do.call(cbind, cols)
    colnames(out) <- paste0("lag_y_", lags)
    out
  }
  build_lag_mat_multi <- function(M, lags, base_names) {
    if (is.null(M) || !length(lags)) return(NULL)
    out_list <- lapply(seq_along(base_names), function(j) {
      v <- M[, j]
      cols <- lapply(lags, function(L) c(rep(NA_real_, L), v[seq_len(length(v) - L)]))
      tmp <- do.call(cbind, cols)
      colnames(tmp) <- paste0(base_names[j], "_lag_", lags)
      tmp
    })
    do.call(cbind, out_list)
  }
  build_mat_lags <- function(M, lags, prefix = "res_lag_") {
    if (is.null(M) || !length(lags)) return(NULL)
    n <- nrow(M)
    p <- ncol(M)
    base <- colnames(M)
    if (is.null(base)) base <- paste0("z", seq_len(p))
    out_list <- lapply(lags, function(L) {
      rbind(matrix(NA_real_, nrow = L, ncol = p), M[seq_len(n - L), , drop = FALSE])
    })
    out <- do.call(cbind, out_list)
    colnames(out) <- unlist(lapply(lags, function(L) paste0(base, "_", prefix, L)), use.names = FALSE)
    out
  }
  cbind_safe <- function(...) {
    parts <- Filter(Negate(is.null), list(...))
    if (!length(parts)) return(NULL)
    do.call(cbind, parts)
  }

  Ylags_all <- build_lag_mat(y_full, lags_y)
  Xlags_all <- build_lag_mat_multi(X_use, lags_x, base_names = if (!is.null(X_use)) colnames(X_use) else character(0))

  shared_fit <- do.call(qdesn_fit_vb, c(list(y = y_full, p0 = 0.50, fit_readout = FALSE), desn_args))
  keep_all_abs <- as.integer(shared_fit$meta$keep_idx)
  X_all_kept <- as.matrix(shared_fit$X)

  sanitize_colnames <- function(nm, n, prefix = "x") {
    if (is.null(nm) || length(nm) != n) nm <- rep("", n)
    nm <- as.character(nm)
    nm[is.na(nm)] <- ""
    empty_idx <- which(!nzchar(nm))
    if (length(empty_idx)) nm[empty_idx] <- sprintf("%s_%03d", prefix, empty_idx)
    nm <- make.unique(nm, sep = "_")
    nm
  }
  make_reservoir_colnames <- function(D, n_vec, n_tilde, add_bias) {
    D <- as.integer(D)
    n_vec <- as.integer(n_vec)
    n_tilde <- as.integer(n_tilde)
    if (D <= 1L) {
      base <- paste0("h1_", seq_len(n_vec[1L]))
    } else {
      base <- paste0("h", D, "_", seq_len(n_vec[D]))
      for (d in seq_len(D - 1L)) {
        nt <- if (length(n_tilde) >= d && is.finite(n_tilde[d]) && n_tilde[d] > 0L) n_tilde[d] else n_vec[d]
        base <- c(base, paste0("htilde", d, "_", seq_len(nt)))
      }
    }
    if (isTRUE(add_bias)) c("bias", base) else base
  }

  res_names <- make_reservoir_colnames(desn_args$D, desn_args$n, desn_args$n_tilde, desn_args$add_bias)
  if (length(res_names) == ncol(X_all_kept)) {
    colnames(X_all_kept) <- sanitize_colnames(res_names, ncol(X_all_kept), prefix = "res")
  } else {
    colnames(X_all_kept) <- sanitize_colnames(colnames(X_all_kept), ncol(X_all_kept), prefix = "res")
  }

  keep_abs2 <- keep_all_abs[keep_all_abs > lag_max]
  row_sel <- which(keep_all_abs %in% keep_abs2)
  X_res2 <- X_all_kept[row_sel, , drop = FALSE]
  Ylags2 <- if (!is.null(Ylags_all)) Ylags_all[keep_abs2, , drop = FALSE] else NULL
  Xlags2 <- if (!is.null(Xlags_all)) Xlags_all[keep_abs2, , drop = FALSE] else NULL

  input_block2 <- if (isTRUE(readout_include_input)) cbind_safe(Ylags2, Xlags2) else NULL
  res_lags_vec <- if (readout_reservoir_lags > 0L) seq_len(readout_reservoir_lags) else integer(0)

  Zlags2 <- NULL
  if (length(res_lags_vec)) {
    X_res_no_bias <- if (isTRUE(desn_args$add_bias)) X_all_kept[, -1, drop = FALSE] else X_all_kept
    Zlags_all <- build_mat_lags(X_res_no_bias, res_lags_vec, prefix = "res_lag_")
    Zlags2 <- Zlags_all[row_sel, , drop = FALSE]
  }

  if (length(res_lags_vec)) {
    if (length(keep_abs2) <= readout_reservoir_lags) stop("Not enough rows to apply reservoir_lags at readout.")
    keep_idx <- seq.int(readout_reservoir_lags + 1L, length(keep_abs2))
    keep_abs2 <- keep_abs2[keep_idx]
    X_res2 <- X_res2[keep_idx, , drop = FALSE]
    if (!is.null(Ylags2)) Ylags2 <- Ylags2[keep_idx, , drop = FALSE]
    if (!is.null(Xlags2)) Xlags2 <- Xlags2[keep_idx, , drop = FALSE]
    if (!is.null(input_block2)) input_block2 <- input_block2[keep_idx, , drop = FALSE]
    if (!is.null(Zlags2)) Zlags2 <- Zlags2[keep_idx, , drop = FALSE]
  }

  readout_block2 <- if (isTRUE(readout_include_input)) input_block2 else cbind_safe(Ylags2, Xlags2)
  X_aug2 <- cbind_safe(X_res2, readout_block2, Zlags2)
  if (is.null(X_aug2)) stop("Failed to build readout design matrix.")
  colnames(X_aug2) <- sanitize_colnames(colnames(X_aug2), ncol(X_aug2), prefix = "x")

  list(
    shared_fit = shared_fit,
    X_aug_all = X_aug2,
    X_res_all = X_res2,
    keep_aug_abs = keep_abs2,
    lags_y = lags_y,
    lags_x = lags_x,
    lag_max = lag_max
  )
}
