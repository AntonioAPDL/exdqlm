# Inter-layer residual Q-DESN utilities.
#
# This file deliberately leaves qdesn_fit_vb() and forecast_paths.qdesn_fit()
# unchanged.  The plain arm therefore remains the current implementation,
# while the residual arm reuses the exact same W, Win, and Q draws and changes
# only the inter-layer state candidate.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, alt) if (!is.null(x)) x else alt
}

.qdesn_residual_activation <- function(a) {
  if (is.function(a)) return(a)
  switch(
    tolower(as.character(a)[1L]),
    tanh = base::tanh,
    relu = function(x) pmax(0, x),
    identity = function(x) x,
    stop("Unsupported activation: ", a, call. = FALSE)
  )
}

.qdesn_rectangular_identity <- function(n_to, n_from) {
  n_to <- as.integer(n_to)[1L]
  n_from <- as.integer(n_from)[1L]
  if (!is.finite(n_to) || !is.finite(n_from) || n_to < 1L || n_from < 1L) {
    stop("Residual projection dimensions must be positive integers.", call. = FALSE)
  }
  out <- matrix(0, nrow = n_to, ncol = n_from)
  k <- min(n_to, n_from)
  out[cbind(seq_len(k), seq_len(k))] <- 1
  out
}

.qdesn_make_skip_matrices <- function(reservoir) {
  D <- as.integer(reservoir$D)[1L]
  if (D <= 1L) return(list())
  n <- as.integer(reservoir$n)
  n_tilde <- as.integer(reservoir$n_tilde)
  lapply(seq.int(2L, D), function(d) {
    .qdesn_rectangular_identity(n_to = n[d], n_from = n_tilde[d - 1L])
  })
}

.qdesn_validate_connection <- function(connection_type, skip_scale) {
  connection_type <- match.arg(
    as.character(connection_type)[1L],
    c("plain", "interlayer_residual")
  )
  skip_scale <- as.numeric(skip_scale)[1L]
  if (!is.finite(skip_scale) || skip_scale < 0) {
    stop("skip_scale must be a finite nonnegative scalar.", call. = FALSE)
  }
  list(connection_type = connection_type, skip_scale = skip_scale)
}

.qdesn_process_lags_from_meta <- function(lags, meta) {
  lags <- as.numeric(lags)
  if (!length(lags)) return(numeric(0))

  center <- as.numeric(meta$lag_center %||% rep(0, length(lags)))
  scale <- as.numeric(meta$lag_scale %||% rep(1, length(lags)))
  if (length(center) == 1L) center <- rep(center, length(lags))
  if (length(scale) == 1L) scale <- rep(scale, length(lags))
  if (length(center) != length(lags) || length(scale) != length(lags)) {
    stop("Lag preprocessing metadata has incompatible dimensions.", call. = FALSE)
  }
  scale[!is.finite(scale) | abs(scale) < 1e-12] <- 1

  out <- lags
  if (isTRUE(meta$standardize_inputs %||% FALSE)) {
    out <- (out - center) / scale
  }

  lag_weights <- meta$win_scale_lags %||% NULL
  if (!is.null(lag_weights)) {
    lag_weights <- as.numeric(lag_weights)
    if (length(lag_weights) != length(out)) {
      stop("win_scale_lags has incompatible dimensions.", call. = FALSE)
    }
    out <- out * lag_weights
  }

  input_bound <- tolower(as.character(meta$input_bound %||% "none")[1L])
  if (identical(input_bound, "tanh")) out <- base::tanh(out)
  if (!input_bound %in% c("none", "tanh")) {
    stop("Unsupported input_bound in residual state recursion.", call. = FALSE)
  }
  out
}

.qdesn_make_input_from_buffer <- function(lag_buffer, meta) {
  z <- .qdesn_process_lags_from_meta(lag_buffer, meta)
  u <- c(1, z)
  u[1L] <- u[1L] * as.numeric(meta$win_scale_bias %||% 1)
  if (length(u) > 1L) {
    u[-1L] <- u[-1L] * as.numeric(meta$win_scale_global %||% 1)
  }
  u
}

.qdesn_layer_candidate <- function(preactivation, h_tilde, layer, reservoir, activation) {
  candidate <- as.numeric(activation(preactivation))
  connection_type <- reservoir$connection_type %||% "plain"

  if (identical(connection_type, "interlayer_residual")) {
    Pskip <- reservoir$Pskip %||% list()
    P_layer <- Pskip[[layer - 1L]] %||% NULL
    if (is.null(P_layer)) {
      stop("Residual projection is missing for layer ", layer, ".", call. = FALSE)
    }
    candidate <- candidate +
      as.numeric(reservoir$skip_scale %||% 1) *
      as.numeric(P_layer %*% h_tilde)
  }
  candidate
}

.qdesn_state_summary <- function(H, preactivation) {
  rows <- lapply(seq_along(H), function(d) {
    hd <- as.numeric(H[[d]])
    ad <- as.numeric(preactivation[[d]])
    data.frame(
      layer = as.integer(d),
      max_abs_state = if (length(hd)) max(abs(hd), na.rm = TRUE) else NA_real_,
      rms_state = if (length(hd)) sqrt(mean(hd^2, na.rm = TRUE)) else NA_real_,
      max_abs_preactivation = if (length(ad)) max(abs(ad), na.rm = TRUE) else NA_real_,
      tanh_saturation_rate = if (length(ad)) mean(abs(ad) > 3, na.rm = TRUE) else NA_real_,
      finite = all(is.finite(hd)) && all(is.finite(ad)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

.qdesn_roll_architecture_states <- function(y, base_fit,
                                            connection_type = c("plain", "interlayer_residual"),
                                            skip_scale = 1,
                                            initial_states = NULL) {
  y <- as.numeric(y)
  if (!length(y) || any(!is.finite(y))) {
    stop("y must be a nonempty finite numeric vector.", call. = FALSE)
  }
  if (is.null(base_fit$reservoir) || is.null(base_fit$meta)) {
    stop("base_fit must contain reservoir and meta components.", call. = FALSE)
  }

  conn <- .qdesn_validate_connection(connection_type, skip_scale)
  meta <- base_fit$meta
  reservoir <- base_fit$reservoir
  D <- as.integer(reservoir$D)[1L]
  n <- as.integer(reservoir$n)
  n_tilde <- as.integer(reservoir$n_tilde)
  m_input <- as.integer(meta$m_input %||% meta$m %||% 0L)[1L]
  Tn <- length(y)

  mode_effective <- tolower(as.character(
    meta$input_mode_effective %||% meta$input_mode %||% "raw_y_lags"
  )[1L])
  if (!identical(mode_effective, "raw_y_lags")) {
    stop(
      "The inter-layer residual implementation currently supports raw_y_lags only; ",
      "decomposition inputs are intentionally outside this focused ablation.",
      call. = FALSE
    )
  }
  if (length(n) != D || (D > 1L && length(n_tilde) != D - 1L)) {
    stop("Reservoir dimensions are inconsistent.", call. = FALSE)
  }

  reservoir$connection_type <- conn$connection_type
  reservoir$skip_scale <- conn$skip_scale
  reservoir$Pskip <- .qdesn_make_skip_matrices(reservoir)

  f_act <- .qdesn_residual_activation(reservoir$act_f)
  k_act <- .qdesn_residual_activation(reservoir$act_k)
  alpha <- as.numeric(reservoir$alpha)
  if (length(alpha) == 1L) alpha <- rep(alpha, D)
  if (length(alpha) != D) stop("Reservoir alpha has incompatible length.", call. = FALSE)

  Q_is_identity <- reservoir$Q_is_identity %||% rep(FALSE, max(0L, D - 1L))
  if (length(Q_is_identity) != max(0L, D - 1L)) {
    stop("Q_is_identity has incompatible length.", call. = FALSE)
  }

  if (is.null(initial_states)) {
    h_prev <- lapply(n, function(nd) numeric(nd))
  } else {
    if (!is.list(initial_states) || length(initial_states) != D) {
      stop("initial_states must be a list with one vector per layer.", call. = FALSE)
    }
    h_prev <- lapply(seq_len(D), function(d) {
      x <- as.numeric(initial_states[[d]])
      if (length(x) != n[d] || any(!is.finite(x))) {
        stop("Invalid initial state for layer ", d, ".", call. = FALSE)
      }
      x
    })
  }

  H <- lapply(seq_len(D), function(d) matrix(0, nrow = Tn, ncol = n[d]))
  H_tilde <- if (D >= 2L) {
    lapply(seq_len(D - 1L), function(d) matrix(0, nrow = Tn, ncol = n_tilde[d]))
  } else {
    list()
  }
  preactivation <- lapply(seq_len(D), function(d) matrix(0, nrow = Tn, ncol = n[d]))
  lag_buffer <- if (m_input > 0L) numeric(m_input) else numeric(0)

  for (t in seq_len(Tn)) {
    u_t <- .qdesn_make_input_from_buffer(lag_buffer, meta)

    pre1 <- reservoir$W[[1L]] %*% h_prev[[1L]] + reservoir$Win[[1L]] %*% u_t
    omega1 <- as.numeric(f_act(pre1))
    h1 <- (1 - alpha[1L]) * h_prev[[1L]] + alpha[1L] * omega1
    H[[1L]][t, ] <- h1
    preactivation[[1L]][t, ] <- as.numeric(pre1)
    h_prev[[1L]] <- h1

    if (D >= 2L) {
      for (d in seq.int(2L, D)) {
        h_tilde <- if (isTRUE(Q_is_identity[d - 1L])) {
          as.numeric(h_prev[[d - 1L]])
        } else {
          as.numeric(reservoir$Q[[d - 1L]] %*% h_prev[[d - 1L]])
        }
        H_tilde[[d - 1L]][t, ] <- h_tilde

        pre_d <- reservoir$W[[d]] %*% h_prev[[d]] +
          reservoir$Win[[d]] %*% h_tilde
        omega_d <- .qdesn_layer_candidate(
          preactivation = pre_d,
          h_tilde = h_tilde,
          layer = d,
          reservoir = reservoir,
          activation = f_act
        )
        h_d <- (1 - alpha[d]) * h_prev[[d]] + alpha[d] * omega_d
        H[[d]][t, ] <- h_d
        preactivation[[d]][t, ] <- as.numeric(pre_d)
        h_prev[[d]] <- h_d
      }
    }

    if (m_input > 0L) {
      lag_buffer <- c(y[t], lag_buffer[seq_len(max(0L, m_input - 1L))])
    }
  }

  build_row <- function(t) {
    if (D == 1L) return(as.numeric(H[[1L]][t, ]))
    lower <- unlist(lapply(seq_len(D - 1L), function(d) {
      as.numeric(k_act(H_tilde[[d]][t, ]))
    }), use.names = FALSE)
    c(as.numeric(H[[D]][t, ]), lower)
  }
  feature_dim <- n[D] + if (D > 1L) sum(n_tilde) else 0L
  X_all <- t(vapply(seq_len(Tn), build_row, numeric(feature_dim)))
  if (isTRUE(meta$add_bias %||% FALSE)) X_all <- cbind(1, X_all)

  keep_idx <- as.integer(meta$keep_idx %||% integer(0))
  if (!length(keep_idx) || max(keep_idx) > Tn) {
    drop <- as.integer(meta$drop %||% max(meta$m %||% 0L, meta$washout %||% 0L))
    if (drop >= Tn) stop("Washout leaves no observations for the readout.", call. = FALSE)
    keep_idx <- seq.int(drop + 1L, Tn)
  }

  out <- list(
    fit = NULL,
    X = X_all[keep_idx, , drop = FALSE],
    X_raw = X_all[keep_idx, , drop = FALSE],
    y_fit = y[keep_idx],
    mu_hat = rep(NA_real_, length(keep_idx)),
    reservoir = reservoir,
    states = list(
      H_last = H[[D]],
      H_all = H,
      H_tilde = H_tilde,
      preactivation = preactivation,
      decomposition = NULL
    ),
    meta = utils::modifyList(meta, list(
      T = Tn,
      keep_idx = keep_idx,
      connection_type = conn$connection_type,
      skip_scale = conn$skip_scale,
      skip_projection = "identity_or_rectangular_identity",
      state_summary = .qdesn_state_summary(H, preactivation)
    ))
  )
  class(out) <- c("qdesn_architecture_design", "qdesn_fit")
  out
}

.qdesn_attach_plain_architecture <- function(base_fit, skip_scale = 1) {
  base_fit$X_raw <- base_fit$X
  base_fit$reservoir$connection_type <- "plain"
  base_fit$reservoir$skip_scale <- 0
  base_fit$reservoir$Pskip <- .qdesn_make_skip_matrices(base_fit$reservoir)
  base_fit$meta$connection_type <- "plain"
  base_fit$meta$skip_scale <- 0
  base_fit$meta$skip_projection <- "identity_or_rectangular_identity"
  if (is.null(base_fit$states$preactivation)) {
    base_fit$meta$state_summary <- NULL
  }
  class(base_fit) <- c("qdesn_architecture_design", "qdesn_fit")
  base_fit
}

#' Build paired plain and residual Q-DESN designs
#'
#' Generates the ordinary Q-DESN once with [qdesn_fit_vb()] in design-only
#' mode, then rerolls the residual states using exactly the same recurrent,
#' input, and reduction matrices.  Only the inter-layer candidate-state
#' equation differs.
#'
#' @param y Observed series through the forecast origin.
#' @param D Number of reservoir layers.
#' @param n Scalar common width or a length-D vector.
#' @param n_tilde Optional reducer widths.  By default lower-layer widths are
#'   retained, giving identity reducers when all layers have width `n`.
#' @param m Number of output lags entering the reservoir.
#' @param alpha Scalar or layer-specific leak.
#' @param rho Scalar or layer-specific spectral radius.
#' @param skip_scale Fixed residual-path multiplier.  It is not tuned by the
#'   ablation workflow.
#' @param ... Additional arguments forwarded to [qdesn_fit_vb()].
#' @return A list containing `plain`, `interlayer_residual`, and pairing
#'   metadata.
#' @export
qdesn_build_paired_architecture_designs <- function(
    y,
    D = 2L,
    n = 30L,
    n_tilde = NULL,
    m = 12L,
    alpha = 0.30,
    rho = 0.85,
    pi_w = 0.10,
    pi_in = 1.00,
    washout = 500L,
    add_bias = TRUE,
    standardize_inputs = TRUE,
    input_bound = "none",
    act_f = "tanh",
    act_k = "identity",
    seed = 123L,
    skip_scale = 1,
    ...) {
  y <- as.numeric(y)
  D <- as.integer(D)[1L]
  if (!is.finite(D) || D < 1L) stop("D must be a positive integer.", call. = FALSE)

  n <- as.integer(n)
  if (length(n) == 1L) n <- rep(n, D)
  if (length(n) != D || any(!is.finite(n)) || any(n < 1L)) {
    stop("n must be a positive scalar or a length-D positive integer vector.", call. = FALSE)
  }

  if (is.null(n_tilde)) {
    n_tilde <- if (D <= 1L) integer(0) else n[seq_len(D - 1L)]
  }
  n_tilde <- as.integer(n_tilde)
  if (D <= 1L) n_tilde <- integer(0)
  if (D > 1L && (length(n_tilde) != D - 1L || any(n_tilde < 1L))) {
    stop("n_tilde must have length D - 1 with positive entries.", call. = FALSE)
  }

  alpha <- as.numeric(alpha)
  if (length(alpha) == 1L) alpha <- rep(alpha, D)
  rho <- as.numeric(rho)
  if (length(rho) == 1L) rho <- rep(rho, D)

  dots <- list(...)
  forbidden <- intersect(names(dots), c(
    "y", "p0", "D", "n", "n_tilde", "m", "alpha", "rho",
    "pi_w", "pi_in", "washout", "add_bias", "standardize_inputs",
    "input_bound", "act_f", "act_k", "seed", "fit_readout",
    "input_mode", "decomposition", "segments", "weights", "state_noise_sd"
  ))
  if (length(forbidden)) {
    stop("Arguments controlled by the paired-design contract cannot be overridden: ",
         paste(forbidden, collapse = ", "), call. = FALSE)
  }

  base_args <- c(list(
    y = y,
    p0 = 0.50,
    D = D,
    n = n,
    n_tilde = n_tilde,
    m = as.integer(m)[1L],
    input_mode = "raw_y_lags",
    decomposition = NULL,
    alpha = alpha,
    rho = rho,
    act_f = act_f,
    act_k = act_k,
    pi_w = pi_w,
    pi_in = pi_in,
    washout = as.integer(washout)[1L],
    add_bias = isTRUE(add_bias),
    standardize_inputs = isTRUE(standardize_inputs),
    input_bound = input_bound,
    weights = NULL,
    state_noise_sd = 0,
    segments = NULL,
    seed = as.integer(seed)[1L],
    fit_readout = FALSE
  ), dots)

  base_fit <- do.call(qdesn_fit_vb, base_args)
  plain <- .qdesn_attach_plain_architecture(base_fit, skip_scale = skip_scale)

  # Reroll the plain path only to recover preactivation diagnostics and to
  # enforce exact nestedness against the untouched legacy implementation.
  plain_audit_started <- proc.time()[3]
  plain_audit <- .qdesn_roll_architecture_states(
    y = y,
    base_fit = base_fit,
    connection_type = "plain",
    skip_scale = 0
  )
  parity_error <- max(abs(as.matrix(plain$X) - as.matrix(plain_audit$X)))
  if (!is.finite(parity_error) || parity_error > 1e-10) {
    stop(
      sprintf("Plain-state reroll failed legacy parity: max error = %.3e.", parity_error),
      call. = FALSE
    )
  }
  plain_audit_runtime_sec <- as.numeric(proc.time()[3] - plain_audit_started)
  plain$states$preactivation <- plain_audit$states$preactivation
  plain$meta$state_summary <- plain_audit$meta$state_summary
  plain$meta$legacy_parity_max_abs_error <- parity_error
  plain$meta$state_roll_runtime_sec <- plain_audit_runtime_sec

  residual_started <- proc.time()[3]
  residual <- .qdesn_roll_architecture_states(
    y = y,
    base_fit = base_fit,
    connection_type = "interlayer_residual",
    skip_scale = skip_scale
  )
  residual_runtime_sec <- as.numeric(proc.time()[3] - residual_started)
  residual$meta$state_roll_runtime_sec <- residual_runtime_sec

  base_hash <- digest::digest(
    list(W = base_fit$reservoir$W, Win = base_fit$reservoir$Win, Q = base_fit$reservoir$Q),
    algo = "sha256"
  )
  plain$meta$base_reservoir_sha256 <- base_hash
  residual$meta$base_reservoir_sha256 <- base_hash

  out <- list(
    plain = plain,
    interlayer_residual = residual,
    pairing = list(
      base_reservoir_sha256 = base_hash,
      seed = as.integer(seed)[1L],
      D = D,
      n = n,
      n_tilde = n_tilde,
      m = as.integer(m)[1L],
      alpha = alpha,
      rho = rho,
      skip_scale = as.numeric(skip_scale)[1L],
      plain_state_roll_runtime_sec = plain_audit_runtime_sec,
      residual_state_roll_runtime_sec = residual_runtime_sec
    )
  )
  class(out) <- "qdesn_paired_architecture_designs"
  out
}
