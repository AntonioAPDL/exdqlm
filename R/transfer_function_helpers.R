.normalize_transfer_X <- function(X, TT) {
  X <- as.matrix(X)
  if (!is.numeric(X) || any(!is.finite(X))) {
    stop("X must be numeric and finite")
  }
  if (nrow(X) != TT) {
    if (ncol(X) == TT) {
      X <- t(X)
    } else {
      stop("X must have the same number of time points as y")
    }
  }
  if (!ncol(X)) {
    stop("X must contain at least one covariate")
  }
  x_names <- colnames(X)
  if (is.null(x_names) || any(!nzchar(x_names))) {
    x_names <- paste0("X", seq_len(ncol(X)))
    colnames(X) <- x_names
  }
  list(X = X, k = ncol(X), input_names = x_names)
}

.normalize_tf_df <- function(tf.df, k) {
  tf.df <- as.numeric(tf.df)
  if (any(!is.finite(tf.df))) {
    stop("tf.df must contain finite discount factors")
  }

  if (length(tf.df) == 1L) {
    tf.df_norm <- rep(tf.df, 2L)
    tf.dim.df <- c(1L, k)
  } else if (length(tf.df) == 2L) {
    tf.df_norm <- tf.df
    tf.dim.df <- c(1L, k)
  } else if (length(tf.df) == (k + 1L)) {
    tf.df_norm <- tf.df
    tf.dim.df <- rep(1L, k + 1L)
  } else {
    stop("tf.df must have length 1, 2, or k + 1 where k = ncol(X)")
  }

  list(tf.df = tf.df_norm, tf.dim.df = tf.dim.df)
}

.prepare_transfer_priors <- function(tf.m0, tf.C0, k) {
  tf_dim <- k + 1L

  if (is.null(tf.m0)) {
    tf.m0 <- rep(0, tf_dim)
  }
  if (length(tf.m0) != tf_dim) {
    stop("tf.m0 should have length k + 1 where k = ncol(X)")
  }

  if (is.null(tf.C0)) {
    tf.C0 <- diag(1, tf_dim)
  }
  tf.C0 <- as.matrix(tf.C0)
  if (any(dim(tf.C0) != tf_dim)) {
    stop("tf.C0 should be a (k + 1) by (k + 1) covariance matrix where k = ncol(X)")
  }

  list(tf.m0 = tf.m0, tf.C0 = tf.C0)
}

.prepare_transfer_inputs <- function(y, X, model, df, dim.df, lam, tf.df,
                                     tf.m0, tf.C0, dim.df_missing = FALSE) {
  y <- check_ts(y)
  TT <- length(y)
  x_info <- .normalize_transfer_X(X, TT = TT)
  X <- x_info$X
  k <- x_info$k
  transfer_input_names <- x_info$input_names

  model <- check_mod(model)
  p <- length(model$m0)
  if (length(lam) != 1L || !is.finite(lam) || lam >= 1 || lam <= 0) {
    stop("lam must be a single value between 0 and 1")
  }
  if (isTRUE(dim.df_missing)) {
    if (length(df) != 1L) {
      stop("length of component discount factors does not match length of component dimensions")
    }
    dim.df <- p
  }

  tf_df_info <- .normalize_tf_df(tf.df, k = k)
  tf.df <- tf_df_info$tf.df
  tf.dim.df <- tf_df_info$tf.dim.df

  tf_prior_info <- .prepare_transfer_priors(tf.m0, tf.C0, k = k)
  tf.m0 <- tf_prior_info$tf.m0
  tf.C0 <- tf_prior_info$tf.C0

  temp.p <- length(model$m0)
  zeta_idx <- temp.p + 1L
  psi_idx <- seq.int(temp.p + 2L, temp.p + k + 1L)
  p_aug <- temp.p + k + 1L

  FF <- matrix(0, p_aug, TT)
  FF[seq_len(temp.p), ] <- model$FF
  FF[zeta_idx, ] <- 1

  GG <- array(0, c(p_aug, p_aug, TT))
  GG[seq_len(temp.p), seq_len(temp.p), ] <- model$GG
  GG[zeta_idx, zeta_idx, ] <- lam
  for (j in seq_len(k)) {
    GG[zeta_idx, psi_idx[j], ] <- X[, j]
    GG[psi_idx[j], psi_idx[j], ] <- 1
  }

  tf.model <- as.exdqlm(list(
    GG = GG,
    FF = FF,
    m0 = c(model$m0, tf.m0),
    C0 = magic::adiag(model$C0, tf.C0)
  ))

  list(
    y = y,
    X = X,
    k = k,
    transfer_input_names = transfer_input_names,
    model = model,
    df = df,
    dim.df = dim.df,
    lam = lam,
    tf.df = tf.df,
    tf.dim.df = tf.dim.df,
    tf.m0 = tf.m0,
    tf.C0 = tf.C0,
    tf.model = tf.model,
    tf.model.df = c(df, tf.df),
    tf.model.dim.df = c(dim.df, tf.dim.df),
    zeta_idx = zeta_idx,
    psi_idx = psi_idx,
    TT = TT
  )
}

.transfer_median_kt <- function(tf.model, theta.out, X, lam, threshold = 1e-3) {
  X <- as.matrix(X)
  TT <- nrow(X)
  k <- ncol(X)
  sm <- theta.out$sm
  p_aug <- dim(sm)[1]
  psi_idx <- seq.int(p_aug - k + 1L, p_aug)

  psi_prev <- matrix(NA_real_, nrow = TT, ncol = k)
  psi_prev[1, ] <- tf.model$m0[psi_idx]
  if (TT > 1L) {
    psi_prev[2:TT, ] <- t(sm[psi_idx, seq_len(TT - 1L), drop = FALSE])
  }

  agg_effect <- abs(rowSums(X * psi_prev))
  k_seq <- numeric(TT)
  idx <- agg_effect > threshold
  k_seq[idx] <- (log(threshold) - log(agg_effect[idx])) / log(lam)
  stats::median(k_seq, na.rm = TRUE)
}
