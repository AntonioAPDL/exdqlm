`%||%` <- function(x, alt) if (!is.null(x)) x else alt

.qdesn_symmetrize <- function(M) {
  (M + t(M)) / 2
}

.qdesn_safe_solve_spd <- function(M, b, context = "qdesn", label = "matrix", jitter = 1e-10) {
  M <- .qdesn_symmetrize(as.matrix(M))
  n <- nrow(M)
  if (!is.matrix(b)) b <- as.matrix(b)
  if (ncol(M) != n || nrow(b) != n) {
    stop(sprintf("[%s] .qdesn_safe_solve_spd dimension mismatch for %s.", context, label), call. = FALSE)
  }
  if (!is.finite(jitter) || jitter <= 0) {
    stop(sprintf("[%s] .qdesn_safe_solve_spd requires positive jitter.", context), call. = FALSE)
  }

  for (k in 0:8) {
    jitter_k <- jitter * (10^k)
    M_try <- M + diag(jitter_k, n)
    U <- tryCatch(chol(M_try), error = function(e) NULL)
    if (!is.null(U)) {
      return(backsolve(U, forwardsolve(t(U), b)))
    }
  }

  stop(sprintf("[%s] failed SPD solve for %s even after jitter.", context, label), call. = FALSE)
}

.qdesn_warn_once_local <- function(option_name, message_text) {
  if (!isTRUE(getOption(option_name, FALSE))) {
    warning(message_text, call. = FALSE)
    options(structure(list(TRUE), names = option_name))
  }
}

.qdesn_expand_state_space <- function(model, T_len, context = "qdesn") {
  model <- check_mod(model)
  n_state <- length(model$m0)

  GG_arr <- model$GG
  if (is.null(dim(GG_arr)) || length(dim(GG_arr)) < 3L || is.na(dim(GG_arr)[3])) {
    GG_arr <- array(as.matrix(model$GG), dim = c(n_state, n_state, T_len))
  } else {
    gg_t <- as.integer(dim(GG_arr)[3])
    if (gg_t == 1L) {
      GG_arr <- array(GG_arr[, , 1L], dim = c(n_state, n_state, T_len))
    } else if (gg_t < T_len) {
      stop(sprintf("[%s] model$GG has only %d slices; need at least T=%d.", context, gg_t, T_len), call. = FALSE)
    } else if (gg_t > T_len) {
      GG_arr <- GG_arr[, , seq_len(T_len), drop = FALSE]
    }
  }

  FF_mat <- as.matrix(model$FF)
  if (nrow(FF_mat) != n_state) {
    stop(sprintf("[%s] model$FF row dimension does not match state dimension.", context), call. = FALSE)
  }
  if (ncol(FF_mat) == 1L) {
    FF_mat <- matrix(FF_mat[, 1L], nrow = n_state, ncol = T_len)
  } else if (ncol(FF_mat) < T_len) {
    stop(sprintf("[%s] model$FF has only %d columns; need at least T=%d.", context, ncol(FF_mat), T_len), call. = FALSE)
  } else if (ncol(FF_mat) > T_len) {
    FF_mat <- FF_mat[, seq_len(T_len), drop = FALSE]
  }

  list(
    m0 = as.numeric(model$m0),
    C0 = as.matrix(model$C0),
    FF = FF_mat,
    GG = GG_arr
  )
}

.qdesn_standardize_decomp_xreg <- function(decomp_xreg, context = "qdesn") {
  if (is.null(decomp_xreg)) return(NULL)
  if (is.vector(decomp_xreg) && !is.list(decomp_xreg)) {
    decomp_xreg <- matrix(as.numeric(decomp_xreg), ncol = 1L)
  } else if (is.data.frame(decomp_xreg)) {
    decomp_xreg <- as.matrix(decomp_xreg)
  } else if (!is.matrix(decomp_xreg)) {
    stop(sprintf("[%s] decomposition covariates must be a numeric matrix/data.frame/vector.", context), call. = FALSE)
  }

  decomp_xreg <- as.matrix(decomp_xreg)
  storage.mode(decomp_xreg) <- "double"
  if (!nrow(decomp_xreg) || !ncol(decomp_xreg)) {
    stop(sprintf("[%s] decomposition covariates must have at least one row and one column.", context), call. = FALSE)
  }
  if (any(!is.finite(decomp_xreg))) {
    stop(sprintf("[%s] decomposition covariates contain non-finite values.", context), call. = FALSE)
  }

  coln <- colnames(decomp_xreg)
  if (is.null(coln) || length(coln) != ncol(decomp_xreg)) {
    coln <- paste0("x", seq_len(ncol(decomp_xreg)))
  }
  coln <- as.character(coln)
  coln[is.na(coln)] <- ""
  empty <- which(!nzchar(coln))
  if (length(empty)) coln[empty] <- paste0("x", empty)
  colnames(decomp_xreg) <- make.unique(coln, sep = "_")
  decomp_xreg
}

.qdesn_lag_shift_zero <- function(x, lag) {
  x <- as.numeric(x)
  n <- length(x)
  lag <- as.integer(lag)[1L]
  if (!is.finite(lag) || lag < 0L) lag <- 0L
  if (lag <= 0L) return(x)
  if (lag >= n) return(rep(0, n))
  c(rep(0, lag), x[seq_len(n - lag)])
}

.qdesn_normalize_interaction_pairs <- function(pairs, available_cols, context = "qdesn", label = "component") {
  if (is.null(pairs) || !length(pairs)) return(list())
  out <- list()

  if (is.list(pairs)) {
    for (it in pairs) {
      v <- as.character(unlist(it, use.names = FALSE))
      v <- v[nzchar(v)]
      if (length(v) == 2L) out[[length(out) + 1L]] <- v
    }
  }

  if (!length(out)) return(list())

  norm_pair <- function(v) {
    v <- as.character(v)
    if (length(v) != 2L) return(NULL)
    if (any(!v %in% available_cols)) {
      stop(
        sprintf("[%s] decomposition.%s.features interaction pair has unknown column(s): %s",
                context, label, paste(v, collapse = ", ")),
        call. = FALSE
      )
    }
    if (identical(v[1L], v[2L])) {
      stop(sprintf("[%s] decomposition.%s.features interaction pairs must use two distinct columns.", context, label), call. = FALSE)
    }
    v
  }

  out <- lapply(out, norm_pair)
  out <- Filter(Negate(is.null), out)
  if (!length(out)) return(list())
  keys <- vapply(out, function(v) paste(v, collapse = "||"), character(1))
  out[!duplicated(keys)]
}

.qdesn_engineer_component_xreg <- function(X_base, feature_cfg = list(), context = "qdesn", label = "component") {
  X_base <- as.matrix(X_base)
  storage.mode(X_base) <- "double"
  if (!nrow(X_base) || !ncol(X_base)) {
    stop(sprintf("[%s] decomposition.%s requires at least one covariate column.", context, label), call. = FALSE)
  }
  if (any(!is.finite(X_base))) {
    stop(sprintf("[%s] decomposition.%s covariates contain non-finite values.", context, label), call. = FALSE)
  }
  coln <- colnames(X_base)
  if (is.null(coln) || length(coln) != ncol(X_base)) {
    coln <- paste0("x", seq_len(ncol(X_base)))
  }
  coln <- as.character(coln)
  coln[is.na(coln)] <- ""
  empty <- which(!nzchar(coln))
  if (length(empty)) coln[empty] <- paste0("x", empty)
  colnames(X_base) <- make.unique(coln, sep = "_")

  include_raw <- isTRUE(feature_cfg$include_raw %||% TRUE)
  lags <- as.integer(unlist(feature_cfg$lags %||% 0L, use.names = FALSE))
  lags <- lags[is.finite(lags) & lags >= 0L]
  if (!length(lags)) lags <- 0L
  lags <- sort(unique(lags))
  include_squares <- isTRUE(feature_cfg$include_squares %||% FALSE)
  include_interactions <- isTRUE(feature_cfg$include_interactions %||% FALSE)
  same_lag_only <- isTRUE(feature_cfg$same_lag_only %||% TRUE)
  pairs_in <- feature_cfg$interaction_pairs %||% list()
  pairs <- .qdesn_normalize_interaction_pairs(
    pairs = pairs_in,
    available_cols = colnames(X_base),
    context = context,
    label = label
  )
  if (isTRUE(include_interactions) && !length(pairs)) {
    if (ncol(X_base) < 2L) {
      include_interactions <- FALSE
    } else {
      cmb <- utils::combn(colnames(X_base), 2L, simplify = FALSE)
      pairs <- lapply(cmb, function(v) as.character(v))
    }
  }

  raw_terms <- list()
  for (nm in colnames(X_base)) {
    v <- X_base[, nm]
    for (L in lags) {
      key <- paste0(nm, "__lag", L)
      raw_terms[[key]] <- .qdesn_lag_shift_zero(v, lag = L)
    }
  }

  out_terms <- list()
  if (isTRUE(include_raw)) out_terms <- c(out_terms, raw_terms)

  if (isTRUE(include_squares) && length(raw_terms)) {
    sq_terms <- lapply(raw_terms, function(v) as.numeric(v)^2)
    names(sq_terms) <- paste0(names(raw_terms), "__sq")
    out_terms <- c(out_terms, sq_terms)
  }

  if (isTRUE(include_interactions) && length(pairs) && length(raw_terms)) {
    int_terms <- list()
    if (isTRUE(same_lag_only)) {
      for (pr in pairs) {
        a <- pr[1L]
        b <- pr[2L]
        for (L in lags) {
          ka <- paste0(a, "__lag", L)
          kb <- paste0(b, "__lag", L)
          if (!is.null(raw_terms[[ka]]) && !is.null(raw_terms[[kb]])) {
            kn <- paste0(a, "_x_", b, "__lag", L)
            int_terms[[kn]] <- as.numeric(raw_terms[[ka]]) * as.numeric(raw_terms[[kb]])
          }
        }
      }
    } else {
      for (pr in pairs) {
        a <- pr[1L]
        b <- pr[2L]
        for (La in lags) {
          for (Lb in lags) {
            ka <- paste0(a, "__lag", La)
            kb <- paste0(b, "__lag", Lb)
            if (!is.null(raw_terms[[ka]]) && !is.null(raw_terms[[kb]])) {
              kn <- paste0(a, "_x_", b, "__lag", La, "x", Lb)
              int_terms[[kn]] <- as.numeric(raw_terms[[ka]]) * as.numeric(raw_terms[[kb]])
            }
          }
        }
      }
    }
    out_terms <- c(out_terms, int_terms)
  }

  if (!length(out_terms)) {
    stop(
      sprintf("[%s] decomposition.%s feature engineering produced zero columns; enable raw/squares/interactions.", context, label),
      call. = FALSE
    )
  }

  X_out <- as.matrix(data.frame(out_terms, check.names = FALSE, stringsAsFactors = FALSE))
  storage.mode(X_out) <- "double"
  if (any(!is.finite(X_out))) {
    stop(sprintf("[%s] decomposition.%s engineered covariates contain non-finite values.", context, label), call. = FALSE)
  }
  colnames(X_out) <- make.unique(colnames(X_out), sep = "_")

  list(
    X = X_out,
    feature_names = colnames(X_out),
    feature_cfg_effective = list(
      include_raw = include_raw,
      lags = as.integer(lags),
      include_squares = include_squares,
      include_interactions = include_interactions,
      interaction_pairs = pairs,
      same_lag_only = same_lag_only
    )
  )
}

.qdesn_select_harmonics_spectral <- function(y,
                                             period,
                                             top_k = 5L,
                                             min_harmonic = 1L,
                                             max_harmonic = NA_integer_,
                                             use_log_score = TRUE,
                                             center = TRUE,
                                             context = "qdesn") {
  y <- as.numeric(y)
  y <- y[is.finite(y)]
  if (length(y) < 8L) {
    stop(sprintf("[%s] seasonal auto-harmonic selection requires at least 8 finite observations.", context), call. = FALSE)
  }

  period <- as.numeric(period)[1L]
  if (!is.finite(period) || period <= 0) {
    stop(sprintf("[%s] seasonal period must be positive for auto-harmonic selection.", context), call. = FALSE)
  }

  top_k <- as.integer(top_k)[1L]
  if (!is.finite(top_k) || top_k < 1L) {
    stop(sprintf("[%s] seasonal auto top_k must be >= 1.", context), call. = FALSE)
  }

  min_harmonic <- as.integer(min_harmonic)[1L]
  if (!is.finite(min_harmonic) || min_harmonic < 1L) {
    stop(sprintf("[%s] seasonal auto min_harmonic must be >= 1.", context), call. = FALSE)
  }

  h_max_theory <- floor(period / 2)
  if (!is.finite(h_max_theory) || h_max_theory < 1L) {
    stop(sprintf("[%s] period is too small for seasonal harmonics.", context), call. = FALSE)
  }

  max_h_eff <- if (is.na(max_harmonic)) h_max_theory else min(as.integer(max_harmonic)[1L], h_max_theory)
  if (!is.finite(max_h_eff) || max_h_eff < min_harmonic) {
    stop(sprintf("[%s] no candidate harmonics after applying min/max bounds.", context), call. = FALSE)
  }

  harmonics <- seq.int(min_harmonic, max_h_eff)
  y_work <- y
  if (isTRUE(center)) y_work <- y_work - mean(y_work)

  tt <- seq_along(y_work)
  omega <- 2 * pi * harmonics / period
  score_raw <- vapply(omega, function(w) {
    cc <- sum(y_work * cos(w * tt))
    ss <- sum(y_work * sin(w * tt))
    (cc^2 + ss^2) / length(y_work)
  }, numeric(1))
  score_used <- if (isTRUE(use_log_score)) log(pmax(score_raw, .Machine$double.eps)) else score_raw

  ord <- order(-score_used, harmonics)
  k_eff <- min(top_k, length(harmonics))
  selected <- sort(harmonics[ord][seq_len(k_eff)])
  rank_vec <- integer(length(harmonics))
  rank_vec[ord] <- seq_along(ord)

  ranking <- data.frame(
    harmonic = as.integer(harmonics),
    frequency = harmonics / period,
    implied_period = period / harmonics,
    score_raw = as.numeric(score_raw),
    score_used = as.numeric(score_used),
    rank = as.integer(rank_vec),
    selected = harmonics %in% selected,
    stringsAsFactors = FALSE
  )

  list(
    harmonics = as.integer(selected),
    ranking = ranking,
    top_k = as.integer(k_eff)
  )
}

#' @keywords internal
.qdesn_ndlm_filter_smooth_r <- function(y,
                                       FF,
                                       GG,
                                       m0,
                                       C0,
                                       df,
                                       dim_df,
                                       s_priors = list(l0 = 1, S0 = 1),
                                       compute_smoothed = TRUE,
                                       return_intermediates = TRUE,
                                       jitter = 1e-10,
                                       context = "qdesn_ndlm_filter_smooth_r") {
  y <- as.numeric(y)
  T_len <- length(y)
  if (T_len < 2L) {
    stop(sprintf("[%s] y must have length >= 2.", context), call. = FALSE)
  }

  m0 <- as.numeric(m0)
  n_state <- length(m0)
  C0 <- as.matrix(C0)
  if (nrow(C0) != n_state || ncol(C0) != n_state) {
    stop(sprintf("[%s] C0 must be square with size length(m0).", context), call. = FALSE)
  }
  if (nrow(FF) != n_state || ncol(FF) != T_len) {
    stop(sprintf("[%s] FF must be n_state x T.", context), call. = FALSE)
  }
  if (dim(GG)[1] != n_state || dim(GG)[2] != n_state || dim(GG)[3] != T_len) {
    stop(sprintf("[%s] GG must be n_state x n_state x T.", context), call. = FALSE)
  }

  l0 <- as.numeric(s_priors$l0 %||% 1)
  S0 <- as.numeric(s_priors$S0 %||% 1)
  if (!is.finite(l0) || l0 <= 0 || !is.finite(S0) || S0 <= 0) {
    stop(sprintf("[%s] variance priors l0 and S0 must be positive.", context), call. = FALSE)
  }

  df_mat <- make_df_mat(df, dim_df, n_state)

  a <- matrix(0, nrow = T_len, ncol = n_state)
  fm <- matrix(0, nrow = T_len, ncol = n_state)
  f <- numeric(T_len)
  e <- numeric(T_len)
  Q_unscaled <- numeric(T_len)
  s_seq <- numeric(T_len)
  n_seq <- numeric(T_len)
  K <- matrix(0, nrow = T_len, ncol = n_state)

  C_unscaled <- array(0, dim = c(T_len, n_state, n_state))
  R_unscaled <- array(0, dim = c(T_len, n_state, n_state))
  fC <- array(0, dim = c(T_len, n_state, n_state))

  m_prev <- m0
  C_prev <- .qdesn_symmetrize(C0)
  l_prev <- l0
  S_prev <- S0

  for (t in seq_len(T_len)) {
    G_t <- GG[, , t, drop = FALSE][, , 1L]
    F_t <- matrix(FF[, t], nrow = n_state, ncol = 1L)

    a_t <- as.vector(G_t %*% m_prev)
    P_t <- .qdesn_symmetrize(G_t %*% C_prev %*% t(G_t))
    W_t <- df_mat * P_t
    R_t <- .qdesn_symmetrize(P_t + W_t)

    q_t <- as.numeric(1 + t(F_t) %*% R_t %*% F_t)
    if (!is.finite(q_t) || q_t <= 1e-12) {
      q_t <- 1e-12
    }

    K_t <- as.vector((R_t %*% F_t) / q_t)
    f_t <- as.numeric(t(F_t) %*% a_t)
    e_t <- y[t] - f_t
    m_t <- as.vector(a_t + K_t * e_t)
    C_t <- .qdesn_symmetrize(R_t - tcrossprod(K_t) * q_t)

    l_t <- l_prev + 1
    S_t <- (l_prev * S_prev + (e_t^2) / q_t) / l_t

    a[t, ] <- a_t
    fm[t, ] <- m_t
    f[t] <- f_t
    e[t] <- e_t
    Q_unscaled[t] <- q_t
    K[t, ] <- K_t
    C_unscaled[t, , ] <- C_t
    R_unscaled[t, , ] <- R_t
    n_seq[t] <- l_t
    s_seq[t] <- S_t

    fC[t, , ] <- S_t * C_t

    m_prev <- m_t
    C_prev <- C_t
    l_prev <- l_t
    S_prev <- S_t
  }

  sm <- NULL
  sC <- NULL
  if (isTRUE(compute_smoothed)) {
    sm <- fm
    sC_unscaled <- array(0, dim = c(T_len, n_state, n_state))
    sC_unscaled[T_len, , ] <- C_unscaled[T_len, , ]
    if (T_len >= 2L) {
      for (t in seq.int(T_len - 1L, 1L, by = -1L)) {
        R_next <- R_unscaled[t + 1L, , ]
        G_next <- GG[, , t + 1L]
        invR_G <- .qdesn_safe_solve_spd(
          R_next,
          G_next,
          context = context,
          label = sprintf("R_unscaled[t=%d]", t + 1L),
          jitter = jitter
        )
        B_t <- C_unscaled[t, , ] %*% t(invR_G)
        sm_next <- matrix(sm[t + 1L, ], nrow = n_state, ncol = 1L)
        a_next <- matrix(a[t + 1L, ], nrow = n_state, ncol = 1L)
        sm[t, ] <- as.vector(matrix(fm[t, ], nrow = n_state, ncol = 1L) + B_t %*% (sm_next - a_next))
        sC_unscaled[t, , ] <- .qdesn_symmetrize(
          C_unscaled[t, , ] +
            B_t %*% (sC_unscaled[t + 1L, , ] - R_next) %*% t(B_t)
        )
      }
    }
    sC <- sC_unscaled
    sT <- s_seq[T_len]
    for (t in seq_len(T_len)) {
      denom <- s_seq[t]
      if (!is.finite(denom) || denom <= 0) {
        stop(sprintf("[%s] invalid scale sequence at t=%d.", context, t), call. = FALSE)
      }
      sC[t, , ] <- (sT / denom) * sC_unscaled[t, , ]
    }
  }

  out <- list(
    fm = fm,
    fC = fC,
    sm = sm,
    sC = sC,
    s = s_seq,
    n = n_seq
  )

  if (isTRUE(return_intermediates)) {
    out <- c(out, list(
      a = a,
      R_unscaled = R_unscaled,
      C_unscaled = C_unscaled,
      Q_unscaled = Q_unscaled,
      f = f,
      e = e,
      K = K
    ))
  }

  out
}

qdesn_ndlm_filter_smooth <- function(
    y, FF, GG, m0, C0, df, dim_df, l0, S0,
    backend = c("r", "cpp"),
    compute_smoothed = TRUE,
    return_intermediates = TRUE,
    jitter = 1e-10
) {
  backend <- match.arg(backend)

  y <- as.numeric(y)
  FF <- as.matrix(FF)
  GG <- as.array(GG)
  m0 <- as.numeric(m0)
  C0 <- as.matrix(C0)
  df <- as.numeric(df)
  dim_df <- as.integer(dim_df)

  if (identical(backend, "cpp")) {
    cpp_fit <- tryCatch(
      dlm_ndlm_filter_smooth_cpp(
        y = y,
        FF = FF,
        GG = GG,
        m0 = m0,
        C0 = C0,
        df = df,
        dim_df = dim_df,
        l0 = as.numeric(l0),
        S0 = as.numeric(S0),
        compute_smoothed = isTRUE(compute_smoothed),
        return_intermediates = isTRUE(return_intermediates),
        jitter = as.numeric(jitter)
      ),
      error = function(e) e
    )
    if (!inherits(cpp_fit, "error")) {
      if (!is.null(cpp_fit$Q_unscaled)) cpp_fit$Q_unscaled <- as.numeric(cpp_fit$Q_unscaled)
      if (!is.null(cpp_fit$f)) cpp_fit$f <- as.numeric(cpp_fit$f)
      if (!is.null(cpp_fit$e)) cpp_fit$e <- as.numeric(cpp_fit$e)
      if (!is.null(cpp_fit$s)) cpp_fit$s <- as.numeric(cpp_fit$s)
      if (!is.null(cpp_fit$n)) cpp_fit$n <- as.numeric(cpp_fit$n)
      cpp_fit$backend <- "cpp"
      return(cpp_fit)
    }
    .qdesn_warn_once_local(
      "exdqlm.warned_dlm_ndlm_cpp_fallback",
      sprintf("[qdesn_ndlm_filter_smooth] cpp backend failed; using r backend. (%s)", cpp_fit$message)
    )
  }

  out <- .qdesn_ndlm_filter_smooth_r(
    y = y,
    FF = FF,
    GG = GG,
    m0 = m0,
    C0 = C0,
    df = df,
    dim_df = dim_df,
    s_priors = list(l0 = as.numeric(l0), S0 = as.numeric(S0)),
    compute_smoothed = isTRUE(compute_smoothed),
    return_intermediates = isTRUE(return_intermediates),
    jitter = as.numeric(jitter),
    context = "qdesn_ndlm_filter_smooth"
  )
  out$backend <- "r"
  out
}

.qdesn_ndlm_structured_forecast_r <- function(
    GG, FF, state_origin, idx_trend, idx_seasonal, origin_index, H,
    context = "qdesn_ndlm_structured_forecast_r"
) {
  GG <- as.array(GG)
  FF <- as.matrix(FF)
  state_origin <- as.numeric(state_origin)
  idx_trend <- as.integer(idx_trend)
  idx_seasonal <- as.integer(idx_seasonal)
  origin_index <- as.integer(origin_index)
  H <- as.integer(H)

  if (!is.finite(H) || H < 1L) {
    stop(sprintf("[%s] H must be >= 1.", context), call. = FALSE)
  }
  if (!is.finite(origin_index) || origin_index < 1L) {
    stop(sprintf("[%s] origin_index must be >= 1.", context), call. = FALSE)
  }

  n_state <- length(state_origin)
  if (n_state < 1L) stop(sprintf("[%s] state dimension must be >= 1.", context), call. = FALSE)
  if (nrow(FF) != n_state) stop(sprintf("[%s] FF row dimension mismatch.", context), call. = FALSE)
  if (dim(GG)[1] != n_state || dim(GG)[2] != n_state) stop(sprintf("[%s] GG dimension mismatch.", context), call. = FALSE)

  if (length(idx_trend) && any(idx_trend < 1L | idx_trend > n_state)) {
    stop(sprintf("[%s] idx_trend out of range.", context), call. = FALSE)
  }
  if (length(idx_seasonal) && any(idx_seasonal < 1L | idx_seasonal > n_state)) {
    stop(sprintf("[%s] idx_seasonal out of range.", context), call. = FALSE)
  }

  g_tmax <- dim(GG)[3]
  f_tmax <- ncol(FF)
  state_now <- state_origin
  trend <- numeric(H)
  seasonal <- numeric(H)
  structured <- numeric(H)

  for (h in seq_len(H)) {
    t_abs <- origin_index + h
    g_idx <- min(max(1L, t_abs), g_tmax)
    f_idx <- min(max(1L, t_abs), f_tmax)

    G_t <- GG[, , g_idx]
    F_t <- FF[, f_idx]
    state_now <- as.vector(G_t %*% state_now)

    tr <- if (length(idx_trend)) sum(F_t[idx_trend] * state_now[idx_trend]) else 0
    se <- if (length(idx_seasonal)) sum(F_t[idx_seasonal] * state_now[idx_seasonal]) else 0
    trend[h] <- tr
    seasonal[h] <- se
    structured[h] <- tr + se
  }

  list(
    trend = trend,
    seasonal = seasonal,
    structured = structured,
    state_last = state_now
  )
}

qdesn_ndlm_structured_forecast <- function(
    GG, FF, state_origin, idx_trend, idx_seasonal, origin_index, H,
    backend = c("r", "cpp")
) {
  backend <- match.arg(backend)
  if (identical(backend, "cpp")) {
    idx_trend_cpp <- as.integer(idx_trend) - 1L
    idx_seasonal_cpp <- as.integer(idx_seasonal) - 1L
    cpp_fc <- tryCatch(
      dlm_ndlm_structured_forecast_cpp(
        GG = as.array(GG),
        FF = as.matrix(FF),
        state_origin = as.numeric(state_origin),
        idx_trend = idx_trend_cpp,
        idx_seasonal = idx_seasonal_cpp,
        origin_index = as.integer(origin_index),
        H = as.integer(H)
      ),
      error = function(e) e
    )
    if (!inherits(cpp_fc, "error")) {
      if (!is.null(cpp_fc$trend)) cpp_fc$trend <- as.numeric(cpp_fc$trend)
      if (!is.null(cpp_fc$seasonal)) cpp_fc$seasonal <- as.numeric(cpp_fc$seasonal)
      if (!is.null(cpp_fc$structured)) cpp_fc$structured <- as.numeric(cpp_fc$structured)
      if (!is.null(cpp_fc$state_last)) cpp_fc$state_last <- as.numeric(cpp_fc$state_last)
      cpp_fc$backend <- "cpp"
      return(cpp_fc)
    }
    .qdesn_warn_once_local(
      "exdqlm.warned_dlm_structured_cpp_fallback",
      sprintf("[qdesn_ndlm_structured_forecast] cpp backend failed; using r backend. (%s)", cpp_fc$message)
    )
  }

  out <- .qdesn_ndlm_structured_forecast_r(
    GG = GG,
    FF = FF,
    state_origin = state_origin,
    idx_trend = idx_trend,
    idx_seasonal = idx_seasonal,
    origin_index = origin_index,
    H = H
  )
  out$backend <- "r"
  out
}

.qdesn_build_dlm_model_from_cfg <- function(decomp_cfg, y = NULL, decomp_xreg = NULL, context = "qdesn") {
  decomp_xreg <- .qdesn_standardize_decomp_xreg(decomp_xreg, context = context)
  y <- as.numeric(y)
  T_len <- if (length(y)) length(y) else if (!is.null(decomp_xreg)) nrow(decomp_xreg) else NA_integer_
  if (!is.null(decomp_xreg) && is.finite(T_len) && nrow(decomp_xreg) != T_len) {
    stop(sprintf("[%s] decomposition covariates must have nrow equal to length(y).", context), call. = FALSE)
  }

  pick_x_cols <- function(xreg, cols, label) {
    if (is.null(xreg)) {
      stop(sprintf("[%s] decomposition.%s.enabled requires decomposition covariates.", context, label), call. = FALSE)
    }
    cols <- as.character(unlist(cols %||% character(0), use.names = FALSE))
    cols <- unique(cols[nzchar(cols)])
    if (!length(cols)) {
      return(list(X = xreg, x_cols_effective = colnames(xreg)))
    }
    missing_cols <- setdiff(cols, colnames(xreg))
    if (length(missing_cols)) {
      stop(
        sprintf("[%s] decomposition.%s.x_cols missing in decomposition covariates: %s",
                context, label, paste(missing_cols, collapse = ", ")),
        call. = FALSE
      )
    }
    list(X = as.matrix(xreg[, cols, drop = FALSE]), x_cols_effective = cols)
  }

  trend_degree <- as.integer(decomp_cfg$trend$degree %||% 1L)
  trend_order <- trend_degree + 1L
  if (!is.finite(trend_order) || trend_order < 1L) {
    stop(sprintf("[%s] decomposition.trend.degree must imply order >= 1.", context), call. = FALSE)
  }

  trend_mod <- polytrendMod(
    order = trend_order,
    m0 = rep(0, trend_order),
    C0 = diag(1e3, trend_order)
  )

  period <- as.numeric(decomp_cfg$seasonal$period %||% NA_real_)
  harmonics_requested <- as.numeric(decomp_cfg$seasonal$harmonics %||% numeric(0))
  harmonics_requested <- harmonics_requested[is.finite(harmonics_requested) & harmonics_requested > 0]
  harmonics_requested <- sort(unique(harmonics_requested))

  auto_cfg <- decomp_cfg$seasonal$auto %||% list()
  auto_enabled <- isTRUE(auto_cfg$enabled %||% FALSE)
  prefer_manual <- isTRUE(auto_cfg$prefer_manual %||% TRUE)
  harmonics <- harmonics_requested
  harmonics_source <- if (length(harmonics_requested)) "manual" else "none"
  auto_selection <- NULL

  if (isTRUE(auto_enabled)) {
    if (is.na(period) || !is.finite(period) || period <= 0) {
      stop(sprintf("[%s] decomposition.seasonal.auto.enabled requires decomposition.seasonal.period > 0.", context), call. = FALSE)
    }
    if (length(harmonics_requested) > 0L && isTRUE(prefer_manual)) {
      harmonics_source <- "manual_preferred_over_auto"
    } else {
      if (is.null(y)) {
        stop(sprintf("[%s] seasonal auto-harmonic selection requires y in model build context.", context), call. = FALSE)
      }
      auto_selection <- .qdesn_select_harmonics_spectral(
        y = y,
        period = period,
        top_k = auto_cfg$top_k %||% 5L,
        min_harmonic = auto_cfg$min_harmonic %||% 1L,
        max_harmonic = auto_cfg$max_harmonic %||% NA_integer_,
        use_log_score = isTRUE(auto_cfg$use_log_score %||% TRUE),
        center = isTRUE(auto_cfg$center %||% TRUE),
        context = context
      )
      harmonics <- auto_selection$harmonics
      harmonics_source <- "auto_spectral"
    }
  }

  harmonics <- harmonics[is.finite(harmonics) & harmonics > 0]
  harmonics <- sort(unique(harmonics))

  seasonal_enabled <- !is.na(period) && period > 0 && length(harmonics) > 0L
  seasonal_mod <- NULL
  seasonal_dim <- 0L

  if (seasonal_enabled) {
    max_h <- period / 2
    if (any(harmonics > max_h)) {
      stop(sprintf("[%s] decomposition.seasonal.harmonics must be <= period/2.", context), call. = FALSE)
    }
    seasonal_dim_tmp <- length(seasMod(period, harmonics)$m0)
    seasonal_mod <- seasMod(
      p = period,
      h = harmonics,
      m0 = rep(0, seasonal_dim_tmp),
      C0 = diag(1e3, seasonal_dim_tmp)
    )
    seasonal_dim <- length(seasonal_mod$m0)
  }

  model <- trend_mod
  if (seasonal_enabled) {
    model <- combineMods(trend_mod, seasonal_mod)
  }

  idx_trend <- seq_len(trend_order)
  idx_seasonal <- if (seasonal_dim > 0L) seq.int(trend_order + 1L, trend_order + seasonal_dim) else integer(0)
  idx_regression <- integer(0)
  idx_transfer <- integer(0)

  d_tr <- as.numeric((decomp_cfg$discount %||% list())$trend %||% 0.99)
  d_se <- as.numeric((decomp_cfg$discount %||% list())$seasonal %||% 0.99)
  d_rg <- as.numeric((decomp_cfg$discount %||% list())$regression %||% 1.0)
  d_tf_z <- as.numeric((decomp_cfg$discount %||% list())$transfer_zeta %||% 0.99)
  d_tf_p <- as.numeric((decomp_cfg$discount %||% list())$transfer_psi %||% 1.0)
  if (!is.finite(d_tr) || d_tr <= 0 || d_tr > 1) {
    stop(sprintf("[%s] decomposition.discount.trend must be in (0,1].", context), call. = FALSE)
  }
  if (!is.finite(d_se) || d_se <= 0 || d_se > 1) {
    stop(sprintf("[%s] decomposition.discount.seasonal must be in (0,1].", context), call. = FALSE)
  }
  if (!is.finite(d_rg) || d_rg <= 0 || d_rg > 1) {
    stop(sprintf("[%s] decomposition.discount.regression must be in (0,1].", context), call. = FALSE)
  }
  if (!is.finite(d_tf_z) || d_tf_z <= 0 || d_tf_z > 1) {
    stop(sprintf("[%s] decomposition.discount.transfer_zeta must be in (0,1].", context), call. = FALSE)
  }
  if (!is.finite(d_tf_p) || d_tf_p <= 0 || d_tf_p > 1) {
    stop(sprintf("[%s] decomposition.discount.transfer_psi must be in (0,1].", context), call. = FALSE)
  }

  dim_df <- c(trend_order, if (seasonal_dim > 0L) seasonal_dim else NULL)
  df_vec <- c(d_tr, if (seasonal_dim > 0L) d_se else NULL)

  reg_cfg <- decomp_cfg$regression %||% list()
  reg_enabled <- isTRUE(reg_cfg$enabled %||% FALSE)
  reg_info <- list(
    enabled = reg_enabled,
    x_cols_requested = as.character(unlist(reg_cfg$x_cols %||% character(0), use.names = FALSE)),
    x_cols_effective = character(0),
    n_state = 0L,
    x_base_cols = character(0),
    feature_names = character(0),
    features = reg_cfg$features %||% list()
  )
  if (isTRUE(reg_enabled)) {
    reg_pick <- pick_x_cols(
      xreg = decomp_xreg,
      cols = reg_cfg$x_cols %||% character(0),
      label = "regression"
    )
    reg_feat <- .qdesn_engineer_component_xreg(
      X_base = reg_pick$X,
      feature_cfg = reg_cfg$features %||% list(),
      context = context,
      label = "regression"
    )
    X_reg <- reg_feat$X
    reg_mod <- regMod(X_reg, m0 = rep(0, ncol(X_reg)), C0 = diag(1e3, ncol(X_reg)))
    model <- combineMods(model, reg_mod)
    n_reg <- ncol(X_reg)
    offset <- if (length(model$m0) > n_reg) length(model$m0) - n_reg else 0L
    idx_regression <- seq.int(offset + 1L, offset + n_reg)
    dim_df <- c(dim_df, n_reg)
    df_vec <- c(df_vec, d_rg)
    reg_info$x_cols_effective <- reg_pick$x_cols_effective
    reg_info$x_base_cols <- colnames(reg_pick$X)
    reg_info$feature_names <- reg_feat$feature_names
    reg_info$features <- reg_feat$feature_cfg_effective
    reg_info$n_state <- as.integer(n_reg)
  }

  tf_cfg <- decomp_cfg$transfer %||% list()
  tf_enabled <- isTRUE(tf_cfg$enabled %||% FALSE)
  tf_info <- list(
    enabled = tf_enabled,
    x_cols_requested = as.character(unlist(tf_cfg$x_cols %||% character(0), use.names = FALSE)),
    x_cols_effective = character(0),
    n_state = 0L,
    lambda = numeric(0),
    x_base_cols = character(0),
    feature_names = character(0),
    features = tf_cfg$features %||% list()
  )
  if (isTRUE(tf_enabled)) {
    tf_pick <- pick_x_cols(
      xreg = decomp_xreg,
      cols = tf_cfg$x_cols %||% character(0),
      label = "transfer"
    )
    tf_feat <- .qdesn_engineer_component_xreg(
      X_base = tf_pick$X,
      feature_cfg = tf_cfg$features %||% list(),
      context = context,
      label = "transfer"
    )
    X_tf <- tf_feat$X
    lambda_tf <- as.numeric(unlist(tf_cfg$lambda %||% 0.9, use.names = FALSE))
    if (!length(lambda_tf) || any(!is.finite(lambda_tf))) {
      stop(sprintf("[%s] decomposition.transfer.lambda must be finite scalar/vector.", context), call. = FALSE)
    }
    if (length(lambda_tf) == 1L) {
      lambda_tf <- rep(lambda_tf, nrow(X_tf))
    }
    if (length(lambda_tf) != nrow(X_tf)) {
      stop(sprintf("[%s] decomposition.transfer.lambda must be scalar or length nrow(xreg).", context), call. = FALSE)
    }
    tf_mod <- tfRegMod(X_tf, lambda = lambda_tf, m0 = rep(0, ncol(X_tf) + 1L), C0 = diag(1e3, ncol(X_tf) + 1L))
    model <- combineMods(model, tf_mod)
    n_tf <- ncol(X_tf)
    offset <- if (length(model$m0) > (n_tf + 1L)) length(model$m0) - (n_tf + 1L) else 0L
    idx_transfer <- seq.int(offset + 1L, offset + n_tf + 1L)
    dim_df <- c(dim_df, 1L, n_tf)
    df_vec <- c(df_vec, d_tf_z, d_tf_p)
    tf_info$x_cols_effective <- tf_pick$x_cols_effective
    tf_info$x_base_cols <- colnames(tf_pick$X)
    tf_info$feature_names <- tf_feat$feature_names
    tf_info$features <- tf_feat$feature_cfg_effective
    tf_info$n_state <- as.integer(n_tf + 1L)
    tf_info$lambda <- as.numeric(lambda_tf)
  }

  if (sum(as.integer(dim_df)) != length(model$m0)) {
    stop(sprintf("[%s] dim_df does not sum to state dimension after model assembly.", context), call. = FALSE)
  }

  list(
    model = model,
    idx = list(
      trend = idx_trend,
      seasonal = idx_seasonal,
      regression = idx_regression,
      transfer = idx_transfer
    ),
    dim_df = as.integer(dim_df),
    df = as.numeric(df_vec),
    seasonal_enabled = seasonal_enabled,
    seasonal = list(
      period = period,
      harmonics_requested = as.numeric(harmonics_requested),
      harmonics_effective = as.numeric(harmonics),
      harmonics_source = harmonics_source,
      auto_enabled = auto_enabled,
      auto_selection = auto_selection
    ),
    regression = reg_info,
    transfer = tf_info
  )
}

.qdesn_extract_decomp_series <- function(state_mat, FF, idx, y, component_names = c("trend", "seasonal", "regression", "transfer")) {
  T_len <- nrow(state_mat)
  component_names <- unique(component_names)
  component_names <- component_names[component_names %in% c("trend", "seasonal", "regression", "transfer")]

  component_series <- setNames(
    lapply(component_names, function(...) numeric(T_len)),
    component_names
  )

  for (t in seq_len(T_len)) {
    F_t <- FF[, t]
    for (nm in component_names) {
      idx_nm <- as.integer(idx[[nm]] %||% integer(0))
      component_series[[nm]][t] <- if (length(idx_nm)) sum(F_t[idx_nm] * state_mat[t, idx_nm]) else 0
    }
  }

  structured <- if (length(component_series)) {
    Reduce(`+`, component_series)
  } else {
    numeric(T_len)
  }
  residual <- as.numeric(y) - structured
  c(component_series, list(structured = structured, residual = residual))
}

#' @keywords internal
.qdesn_prepare_decomposition_runtime <- function(y, decomp_cfg, decomp_xreg = NULL, context = "qdesn") {
  y <- as.numeric(y)
  T_len <- length(y)
  if (T_len < 3L) {
    stop(sprintf("[%s] decomposition mode requires at least 3 observations.", context), call. = FALSE)
  }

  decomp_xreg <- .qdesn_standardize_decomp_xreg(decomp_xreg, context = context)
  if (!is.null(decomp_xreg) && nrow(decomp_xreg) != T_len) {
    stop(sprintf("[%s] decomposition covariates must have nrow equal to length(y).", context), call. = FALSE)
  }

  model_info <- .qdesn_build_dlm_model_from_cfg(
    decomp_cfg = decomp_cfg,
    y = y,
    decomp_xreg = decomp_xreg,
    context = context
  )
  expanded <- .qdesn_expand_state_space(model_info$model, T_len = T_len, context = context)

  variance_cfg <- decomp_cfg$variance %||% list()
  s_priors <- list(
    l0 = as.numeric(variance_cfg$l0 %||% 1),
    S0 = as.numeric(variance_cfg$S0 %||% 1)
  )
  backend_pref <- tolower(as.character(decomp_cfg$backend_effective %||% decomp_cfg$backend %||% "r")[1L])
  if (!backend_pref %in% c("r", "cpp")) backend_pref <- "r"

  filt <- qdesn_ndlm_filter_smooth(
    y = y,
    FF = expanded$FF,
    GG = expanded$GG,
    m0 = expanded$m0,
    C0 = expanded$C0,
    df = model_info$df,
    dim_df = model_info$dim_df,
    l0 = s_priors$l0,
    S0 = s_priors$S0,
    backend = backend_pref,
    compute_smoothed = TRUE,
    return_intermediates = FALSE,
    jitter = 1e-10
  )
  backend_actual <- as.character(filt$backend %||% backend_pref)[1L]

  state_est_req <- tolower(as.character(decomp_cfg$state_estimate %||% "smoothed")[1L])
  state_est_eff <- tolower(as.character(decomp_cfg$state_estimate_effective %||% state_est_req)[1L])
  if (!state_est_eff %in% c("filtered", "smoothed")) state_est_eff <- "filtered"

  series_filtered <- .qdesn_extract_decomp_series(
    state_mat = filt$fm,
    FF = expanded$FF,
    idx = model_info$idx,
    y = y
  )
  series_smoothed <- NULL
  if (!is.null(filt$sm)) {
    series_smoothed <- .qdesn_extract_decomp_series(
      state_mat = filt$sm,
      FF = expanded$FF,
      idx = model_info$idx,
      y = y
    )
  }

  series_effective <- if (identical(state_est_eff, "smoothed") && !is.null(series_smoothed)) {
    series_smoothed
  } else {
    series_filtered
  }

  input_lags <- list(
    trend = as.integer((decomp_cfg$input_lags %||% list())$trend %||% 0L),
    seasonal = as.integer((decomp_cfg$input_lags %||% list())$seasonal %||% 0L),
    regression = as.integer((decomp_cfg$input_lags %||% list())$regression %||% 0L),
    transfer = as.integer((decomp_cfg$input_lags %||% list())$transfer %||% 0L),
    residual = as.integer((decomp_cfg$input_lags %||% list())$residual %||% 0L)
  )
  for (nm in names(input_lags)) {
    if (!is.finite(input_lags[[nm]]) || input_lags[[nm]] < 0L) input_lags[[nm]] <- 0L
  }

  comp_order <- as.character(decomp_cfg$components %||% c("trend", "seasonal", "residual"))
  comp_order <- comp_order[comp_order %in% c("trend", "seasonal", "regression", "transfer", "residual")]
  if (!length(comp_order)) comp_order <- c("trend", "seasonal", "residual")

  input_components <- comp_order[vapply(comp_order, function(nm) input_lags[[nm]] > 0L, logical(1))]
  if (!length(input_components)) {
    stop(sprintf("[%s] decomposition.input_lags must include at least one positive lag.", context), call. = FALSE)
  }

  lag_component_order <- unlist(lapply(input_components, function(nm) rep(nm, input_lags[[nm]])), use.names = FALSE)
  m_input <- length(lag_component_order)

  component_names <- names(input_lags)
  component_means <- setNames(
    vapply(component_names, function(nm) mean(as.numeric(series_effective[[nm]] %||% 0), na.rm = TRUE), numeric(1)),
    component_names
  )
  component_sds <- setNames(
    vapply(component_names, function(nm) stats::sd(as.numeric(series_effective[[nm]] %||% 0), na.rm = TRUE), numeric(1)),
    component_names
  )
  component_sds[!is.finite(component_sds) | component_sds <= 1e-12] <- 1

  lag_center <- if (m_input > 0L) unname(component_means[lag_component_order]) else numeric(0)
  lag_scale <- if (m_input > 0L) unname(component_sds[lag_component_order]) else numeric(0)

  list(
    enabled = TRUE,
    backend_requested = decomp_cfg$backend,
    backend_effective = backend_actual,
    state_estimate_requested = state_est_req,
    state_estimate_effective = state_est_eff,
    components = comp_order,
    seasonal = model_info$seasonal,
    regression = model_info$regression,
    transfer = model_info$transfer,
    input_components = input_components,
    input_lags = input_lags,
    lag_component_order = lag_component_order,
    m_input = as.integer(m_input),
    lag_center = as.numeric(lag_center),
    lag_scale = as.numeric(lag_scale),
    series = series_effective,
    series_filtered = series_filtered,
    series_smoothed = series_smoothed,
    idx = model_info$idx,
    model = list(
      FF = expanded$FF,
      GG = expanded$GG,
      m0 = expanded$m0,
      C0 = expanded$C0,
      dim_df = model_info$dim_df,
      df = model_info$df
    ),
    state_filtered = filt$fm,
    state_smoothed = filt$sm,
    variance = list(s = filt$s, n = filt$n),
    xreg = list(
      provided = !is.null(decomp_xreg),
      cols = if (is.null(decomp_xreg)) character(0) else colnames(decomp_xreg)
    )
  )
}

#' @keywords internal
.qdesn_init_component_lag_buffers <- function(runtime, tau) {
  mk_buf <- function(series, L, idx) {
    L <- as.integer(L)
    if (L <= 0L) return(numeric(0))
    idx <- as.integer(idx)
    if (!is.finite(idx) || idx <= 0L) return(rep(0, L))
    avail <- min(L, idx)
    src <- series[seq.int(idx - avail + 1L, idx)]
    c(rev(src), rep(0, L - avail))
  }

  lags <- runtime$input_lags %||% list()
  out <- lapply(names(lags), function(nm) mk_buf(runtime$series[[nm]] %||% rep(0, nrow(runtime$state_filtered)), lags[[nm]], tau))
  names(out) <- names(lags)
  out
}

#' @keywords internal
.qdesn_component_lag_vector <- function(buffers, input_components) {
  if (!length(input_components)) return(numeric(0))
  unlist(lapply(input_components, function(nm) as.numeric(buffers[[nm]] %||% numeric(0))), use.names = FALSE)
}

#' @keywords internal
.qdesn_update_component_lag_buffers <- function(buffers, value_now) {
  for (nm in names(buffers)) {
    buf <- buffers[[nm]]
    if (!length(buf)) next
    v <- as.numeric(value_now[[nm]] %||% 0)[1L]
    if (length(buf) == 1L) {
      buffers[[nm]] <- v
    } else {
      buffers[[nm]] <- c(v, buf[seq_len(length(buf) - 1L)])
    }
  }
  buffers
}

#' @keywords internal
.qdesn_decomp_forecast_trajectory <- function(runtime, origin_index, H, state_origin = NULL, context = "qdesn") {
  H <- as.integer(H)
  if (H < 1L) stop(sprintf("[%s] H must be >= 1.", context), call. = FALSE)
  tau <- as.integer(origin_index)
  if (!is.finite(tau) || tau < 1L) stop(sprintf("[%s] origin_index must be >= 1.", context), call. = FALSE)

  GG <- runtime$model$GG
  FF <- runtime$model$FF
  idx <- runtime$idx %||% list()
  n_state <- nrow(FF)

  if (is.null(state_origin)) {
    if (tau > nrow(runtime$state_filtered)) {
      stop(sprintf("[%s] origin_index exceeds available state rows.", context), call. = FALSE)
    }
    state_now <- as.numeric(runtime$state_filtered[tau, ])
  } else {
    state_now <- as.numeric(state_origin)
  }
  if (length(state_now) != n_state) {
    stop(sprintf("[%s] state_origin length mismatch.", context), call. = FALSE)
  }

  backend_use <- tolower(as.character(runtime$backend_effective %||% runtime$backend_requested %||% "r")[1L])
  if (!backend_use %in% c("r", "cpp")) backend_use <- "r"
  has_extended_components <- length(idx$regression %||% integer(0)) > 0L || length(idx$transfer %||% integer(0)) > 0L

  if (!has_extended_components) {
    out_base <- qdesn_ndlm_structured_forecast(
      GG = GG,
      FF = FF,
      state_origin = state_now,
      idx_trend = idx$trend %||% integer(0),
      idx_seasonal = idx$seasonal %||% integer(0),
      origin_index = tau,
      H = H,
      backend = backend_use
    )
    out <- list(
      components = list(
        trend = as.numeric(out_base$trend),
        seasonal = as.numeric(out_base$seasonal)
      ),
      trend = as.numeric(out_base$trend),
      seasonal = as.numeric(out_base$seasonal),
      regression = rep(0, H),
      transfer = rep(0, H),
      structured = as.numeric(out_base$structured),
      state_last = as.numeric(out_base$state_last),
      backend = as.character(out_base$backend %||% backend_use)[1L]
    )
    return(out)
  }

  component_names <- names(runtime$input_lags %||% list())
  if (!length(component_names)) {
    component_names <- c("trend", "seasonal", "regression", "transfer", "residual")
  }
  component_names <- setdiff(component_names, "residual")
  component_names <- component_names[component_names %in% c("trend", "seasonal", "regression", "transfer")]
  if (!length(component_names)) component_names <- c("trend", "seasonal")

  comps <- setNames(lapply(component_names, function(...) numeric(H)), component_names)
  structured <- numeric(H)
  state_path <- state_now
  g_tmax <- dim(GG)[3]
  f_tmax <- ncol(FF)

  for (h in seq_len(H)) {
    t_abs <- tau + h
    g_idx <- min(max(1L, t_abs), g_tmax)
    f_idx <- min(max(1L, t_abs), f_tmax)
    G_t <- GG[, , g_idx]
    F_t <- FF[, f_idx]
    state_path <- as.vector(G_t %*% state_path)

    vals_h <- numeric(length(component_names))
    for (k in seq_along(component_names)) {
      nm <- component_names[k]
      idx_nm <- as.integer(idx[[nm]] %||% integer(0))
      vals_h[k] <- if (length(idx_nm)) sum(F_t[idx_nm] * state_path[idx_nm]) else 0
      comps[[nm]][h] <- vals_h[k]
    }
    structured[h] <- sum(vals_h)
  }

  out <- list(
    components = comps,
    structured = structured,
    state_last = state_path,
    backend = "r"
  )
  for (nm in names(comps)) out[[nm]] <- comps[[nm]]
  for (nm in c("trend", "seasonal", "regression", "transfer")) {
    if (is.null(out[[nm]])) out[[nm]] <- rep(0, H)
  }
  out
}
