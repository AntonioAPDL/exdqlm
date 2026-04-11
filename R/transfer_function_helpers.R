.normalize_tf_df <- function(tf.df) {
  tf.df <- as.numeric(tf.df)
  if (length(tf.df) == 1L) {
    tf.df <- rep(tf.df, 2L)
  }
  if (length(tf.df) != 2L || any(!is.finite(tf.df))) {
    stop("tf.df must contain one or two finite discount factors")
  }
  tf.df
}

.prepare_transfer_inputs <- function(y, X, model, df, dim.df, lam, tf.df,
                                     tf.m0, tf.C0, dim.df_missing = FALSE) {
  y <- check_ts(y)
  X <- check_ts(X)
  if (length(X) != length(y)) {
    stop("y and X must be time-series of the same length")
  }
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
  tf.df <- .normalize_tf_df(tf.df)
  if (length(tf.m0) != 2L) {
    stop("tf.m0 should have length 2")
  }
  tf.C0 <- as.matrix(tf.C0)
  if (any(dim(tf.C0) != 2L)) {
    stop("tf.C0 should be a 2 by 2 covariance matrix")
  }

  TT <- length(y)
  temp.p <- length(model$m0)
  p_aug <- temp.p + 2L
  FF <- matrix(0, p_aug, TT)
  FF[1:temp.p, ] <- model$FF
  FF[seq(temp.p + 1L, temp.p + 2L, 2L), ] <- 1

  GG <- array(0, c(p_aug, p_aug, TT))
  GG[1:temp.p, 1:temp.p, ] <- model$GG
  GG[(temp.p + 1L):(temp.p + 2L), (temp.p + 1L):(temp.p + 2L), ] <- matrix(c(lam, 0, NA, 1), 2, 2)
  GG[temp.p + 1L, temp.p + 2L, ] <- X

  tf.model <- as.exdqlm(list(
    GG = GG,
    FF = FF,
    m0 = c(model$m0, tf.m0),
    C0 = magic::adiag(model$C0, tf.C0)
  ))

  list(
    y = y,
    X = X,
    model = model,
    df = df,
    dim.df = dim.df,
    lam = lam,
    tf.df = tf.df,
    tf.m0 = tf.m0,
    tf.C0 = tf.C0,
    tf.model = tf.model,
    tf.model.df = c(df, tf.df),
    tf.model.dim.df = c(dim.df, rep(1, 2)),
    TT = TT
  )
}

.transfer_median_kt <- function(tf.model, theta.out, X, lam, threshold = 1e-3) {
  X <- c(X)
  TT <- length(X)
  sm <- theta.out$sm
  k_seq <- (log(threshold) - log(abs(c(tf.model$m0[1], sm[(dim(sm)[1] - 1), -TT]) * X))) / log(lam)
  stats::median(k_seq)
}
