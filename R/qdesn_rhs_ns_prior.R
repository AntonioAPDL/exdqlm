if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, alt) if (!is.null(x)) x else alt
}
if (!exists(".stopf", mode = "function")) {
  .stopf <- function(fmt, ...) stop(sprintf(fmt, ...), call. = FALSE)
}

.rhs_ns_intercept_idx <- function(p, shrink_intercept, intercept_index = NULL) {
  if (isTRUE(shrink_intercept)) {
    return(integer(0))
  }
  idx <- suppressWarnings(as.integer(intercept_index %||% 1L))
  idx <- idx[is.finite(idx) & idx >= 1L & idx <= p]
  idx <- sort(unique(idx))
  if (length(idx)) idx else if (p >= 1L) 1L else integer(0)
}

.rhs_ns_active_idx <- function(p, shrink_intercept, intercept_index = NULL) {
  if (isTRUE(shrink_intercept)) return(seq_len(p))
  intercept_idx <- .rhs_ns_intercept_idx(p, shrink_intercept, intercept_index)
  setdiff(seq_len(p), intercept_idx)
}

.rhs_ns_intercept_prec_vec <- function(p, intercept_idx, intercept_prec) {
  prec <- rep(NA_real_, p)
  if (!length(intercept_idx)) return(prec)
  vals <- as.numeric(intercept_prec %||% 1e-16)
  vals <- vals[is.finite(vals) & vals > 0]
  if (!length(vals)) vals <- 1e-16
  if (length(vals) == 1L) vals <- rep(vals, length(intercept_idx))
  if (length(vals) != length(intercept_idx)) vals <- rep(vals[[1L]], length(intercept_idx))
  prec[intercept_idx] <- vals
  prec
}

.rhs_ns_ig_entropy <- function(a, b) {
  a <- pmax(as.numeric(a), 1e-12)
  b <- pmax(as.numeric(b), 1e-12)
  a + log(b) + lgamma(a) - (1 + a) * digamma(a)
}

qdesn_rhs_ns_prior_obj <- function(
  hypers = list(
    tau0 = 1.0,
    a_zeta = 2.0,
    b_zeta = 1.0,
    zeta2_fixed = NULL,
    s2 = 1.0,
    shrink_intercept = FALSE,
    intercept_prec = 1e-16
  ),
  init = list(
    lambda2 = 1.0,
    nu = 1.0,
    tau2 = NULL,
    xi = 1.0,
    zeta2 = NULL
  ),
  control = list(
    n_inner = 2L,
    var_floor = 1e-16,
    verbose = FALSE,
    freeze_tau_iters = 0L,
    freeze_tau_warmup_iters = NULL,
    force_tau_after_warmup = TRUE
  )
) {
  tau0 <- as.numeric(hypers$tau0 %||% 1.0)[1L]
  if (!is.finite(tau0) || tau0 <= 0) .stopf("RHS_NS hypers$tau0 must be > 0.")

  a_zeta0 <- as.numeric(hypers$a_zeta %||% 2.0)[1L]
  b_zeta0 <- as.numeric(hypers$b_zeta %||% 1.0)[1L]
  if (!is.finite(a_zeta0) || a_zeta0 <= 0) .stopf("RHS_NS hypers$a_zeta must be > 0.")
  if (!is.finite(b_zeta0) || b_zeta0 <= 0) .stopf("RHS_NS hypers$b_zeta must be > 0.")

  zeta2_fixed_raw <- hypers$zeta2_fixed %||% hypers$c2_fixed %||% NULL
  zeta2_fixed <- if (is.null(zeta2_fixed_raw)) NA_real_ else as.numeric(zeta2_fixed_raw)[1L]
  if (!is.na(zeta2_fixed) && (!is.finite(zeta2_fixed) || zeta2_fixed <= 0)) {
    .stopf("RHS_NS hypers$zeta2_fixed must be NULL or > 0.")
  }

  slab_s2 <- as.numeric(hypers$s2 %||% hypers$zeta2 %||% 1.0)[1L]
  if (!is.finite(slab_s2) || slab_s2 <= 0) slab_s2 <- 1.0

  shrink_intercept <- .qdesn_force_rhs_no_intercept_shrink(
    hypers$shrink_intercept %||% FALSE,
    context = "qdesn_rhs_ns_prior_obj"
  )
  intercept_index_raw <- hypers$intercept_index %||% NULL
  intercept_index <- if (is.null(intercept_index_raw)) NULL else suppressWarnings(as.integer(intercept_index_raw))
  intercept_index <- intercept_index[is.finite(intercept_index) & intercept_index >= 1L]
  intercept_prec <- as.numeric(hypers$intercept_prec %||% 1e-16)
  intercept_prec <- intercept_prec[is.finite(intercept_prec) & intercept_prec > 0]
  if (!length(intercept_prec)) intercept_prec <- 1e-16

  n_inner <- max(1L, as.integer(control$n_inner %||% 2L))
  var_floor <- as.numeric(control$var_floor %||% 1e-16)[1L]
  if (!is.finite(var_floor) || var_floor <= 0) var_floor <- 1e-16
  verbose <- isTRUE(control$verbose %||% FALSE)
  freeze_tau_iters <- suppressWarnings(as.integer(control$freeze_tau_iters %||% 0L))[1L]
  if (!is.finite(freeze_tau_iters) || freeze_tau_iters < 0L) freeze_tau_iters <- 0L
  freeze_tau_warmup_iters <- suppressWarnings(as.integer(
    control$freeze_tau_warmup_iters %||% freeze_tau_iters
  ))[1L]
  if (!is.finite(freeze_tau_warmup_iters) || freeze_tau_warmup_iters < 0L) {
    freeze_tau_warmup_iters <- freeze_tau_iters
  }
  force_tau_after_warmup <- if (is.null(control$force_tau_after_warmup)) TRUE else isTRUE(control$force_tau_after_warmup)

  list(
    type = "rhs_ns",
    hypers = list(
      tau0 = tau0,
      a_zeta = a_zeta0,
      b_zeta = b_zeta0,
      zeta2_fixed = zeta2_fixed,
      s2 = slab_s2,
      shrink_intercept = shrink_intercept,
      intercept_index = intercept_index,
      intercept_prec = intercept_prec
    ),
    control = list(
      n_inner = n_inner,
      var_floor = var_floor,
      verbose = verbose,
      freeze_tau_iters = freeze_tau_iters,
      freeze_tau_warmup_iters = freeze_tau_warmup_iters,
      force_tau_after_warmup = force_tau_after_warmup
    ),

    init = function(p) {
      p <- as.integer(p)[1L]
      if (!is.finite(p) || p <= 0) .stopf("rhs_ns_prior$init: p must be a positive integer.")

      intercept_idx <- .rhs_ns_intercept_idx(p, shrink_intercept, intercept_index)
      active_idx <- .rhs_ns_active_idx(p, shrink_intercept, intercept_idx)
      m_active <- length(active_idx)

      lambda2 <- as.numeric(init$lambda2 %||% init$init_lambda2 %||% 1.0)
      if (length(lambda2) == 1L) lambda2 <- rep(lambda2, p)
      if (length(lambda2) != p) .stopf("rhs_ns_prior$init: lambda2 must be scalar or length p.")
      lambda2 <- pmax(lambda2, var_floor)

      nu <- as.numeric(init$nu %||% init$init_nu %||% 1.0)
      if (length(nu) == 1L) nu <- rep(nu, p)
      if (length(nu) != p) .stopf("rhs_ns_prior$init: nu must be scalar or length p.")
      nu <- pmax(nu, var_floor)

      tau2 <- as.numeric(init$tau2 %||% init$init_tau2 %||% (tau0^2))[1L]
      if (!is.finite(tau2) || tau2 <= 0) tau2 <- tau0^2
      tau2 <- max(tau2, var_floor)

      xi <- as.numeric(init$xi %||% init$init_xi %||% 1.0)[1L]
      if (!is.finite(xi) || xi <= 0) xi <- 1.0
      xi <- max(xi, var_floor)

      zeta2_init <- as.numeric(init$zeta2 %||% init$init_zeta2 %||% slab_s2)[1L]
      if (!is.finite(zeta2_init) || zeta2_init <= 0) zeta2_init <- slab_s2
      if (!is.na(zeta2_fixed)) zeta2_init <- zeta2_fixed
      zeta2_init <- max(zeta2_init, var_floor)

      a_lambda <- rep(1.0, p)
      b_lambda <- pmax(lambda2, var_floor)
      a_nu <- rep(1.0, p)
      b_nu <- pmax(nu, var_floor)

      a_tau <- max((m_active + 1.0) / 2.0, 1e-12)
      b_tau <- max(a_tau * tau2, var_floor)
      a_xi <- 1.0
      b_xi <- max(xi, var_floor)

      if (is.na(zeta2_fixed)) {
        a_zeta <- max(a_zeta0, 1e-12)
        b_zeta <- max(a_zeta * zeta2_init, var_floor)
        e_inv_zeta <- a_zeta / b_zeta
      } else {
        a_zeta <- NA_real_
        b_zeta <- NA_real_
        e_inv_zeta <- 1.0 / zeta2_fixed
      }

      e_inv_lambda <- a_lambda / b_lambda
      e_inv_nu <- a_nu / b_nu
      e_inv_tau <- a_tau / b_tau
      e_inv_xi <- a_xi / b_xi

      list(
        p = p,
        shrink_intercept = shrink_intercept,
        intercept_index = intercept_idx,
        intercept_prec = intercept_prec,
        zeta2_is_fixed = !is.na(zeta2_fixed),
        zeta2_fixed = zeta2_fixed,

        # point state used by MCMC initialization
        lambda2 = lambda2,
        nu = nu,
        tau2 = tau2,
        xi = xi,
        zeta2 = zeta2_init,

        # variational factors
        a_lambda = a_lambda,
        b_lambda = b_lambda,
        a_nu = a_nu,
        b_nu = b_nu,
        a_tau = a_tau,
        b_tau = b_tau,
        a_xi = a_xi,
        b_xi = b_xi,
        a_zeta = a_zeta,
        b_zeta = b_zeta,

        # cached moments
        E_inv_lambda2 = e_inv_lambda,
        E_inv_nu = e_inv_nu,
        E_inv_tau2 = e_inv_tau,
        E_inv_xi = e_inv_xi,
        E_inv_zeta2 = e_inv_zeta,

        iter = 0L,
        freeze_tau = FALSE,
        update_tau_only = FALSE,
        tau_update_count = 0L,
        has_post_warmup_tau_update = FALSE,
        last_schedule = list()
      )
    },

    expected_prec = function(state, p) {
      p <- as.integer(p)[1L]
      if (is.null(state$p) || as.integer(state$p) != p) .stopf("rhs_ns_prior$expected_prec: p mismatch.")

      e_inv_tau <- as.numeric(state$E_inv_tau2 %||% NA_real_)[1L]
      e_inv_zeta <- as.numeric(state$E_inv_zeta2 %||% NA_real_)[1L]
      e_inv_lambda <- as.numeric(state$E_inv_lambda2 %||% rep(NA_real_, p))
      if (length(e_inv_lambda) != p) .stopf("rhs_ns_prior$expected_prec: invalid E_inv_lambda2 length.")

      e_inv_tau <- if (is.finite(e_inv_tau) && e_inv_tau > 0) e_inv_tau else 1.0 / pmax(as.numeric(state$tau2 %||% 1.0)[1L], var_floor)
      e_inv_zeta <- if (is.finite(e_inv_zeta) && e_inv_zeta > 0) e_inv_zeta else 1.0 / pmax(as.numeric(state$zeta2 %||% 1.0)[1L], var_floor)
      e_inv_lambda[!is.finite(e_inv_lambda) | e_inv_lambda <= 0] <- 1.0 / pmax(as.numeric(state$lambda2 %||% rep(1.0, p))[!is.finite(e_inv_lambda) | e_inv_lambda <= 0], var_floor)

      intercept_idx <- .rhs_ns_intercept_idx(p, state$shrink_intercept, state$intercept_index)
      active_idx <- .rhs_ns_active_idx(p, state$shrink_intercept, intercept_idx)
      prec <- .rhs_ns_intercept_prec_vec(p, intercept_idx, state$intercept_prec %||% intercept_prec)
      prec[is.na(prec)] <- 1e-16
      if (length(active_idx)) {
        prec[active_idx] <- e_inv_tau * e_inv_lambda[active_idx] + e_inv_zeta
      } else if (isTRUE(state$shrink_intercept) && p > 0L) {
        prec <- e_inv_tau * e_inv_lambda + e_inv_zeta
      }
      pmax(as.numeric(prec), var_floor)
    },

    update = function(state, qbeta) {
      if (is.null(state$p)) .stopf("rhs_ns_prior$update: state is missing p.")
      p <- as.integer(state$p)
      if (is.null(qbeta$m) || is.null(qbeta$V)) .stopf("rhs_ns_prior$update: qbeta must provide m and V.")
      if (length(qbeta$m) != p) .stopf("rhs_ns_prior$update: qbeta$m length mismatch.")
      if (!all(dim(qbeta$V) == c(p, p))) .stopf("rhs_ns_prior$update: qbeta$V dim mismatch.")

      beta2 <- as.numeric(qbeta$m)^2 + diag(qbeta$V)
      intercept_idx <- .rhs_ns_intercept_idx(p, state$shrink_intercept, state$intercept_index)
      active_idx <- .rhs_ns_active_idx(p, state$shrink_intercept, intercept_idx)
      m_active <- length(active_idx)
      iter_now <- as.integer(state$iter %||% 0L) + 1L
      tau_warmup <- isTRUE(freeze_tau_warmup_iters > 0L && iter_now <= freeze_tau_warmup_iters)
      force_tau_now <- !tau_warmup &&
        isTRUE(force_tau_after_warmup) &&
        isTRUE(freeze_tau_warmup_iters > 0L) &&
        !isTRUE(state$has_post_warmup_tau_update %||% FALSE)
      tau_updated <- FALSE

      a_lambda <- as.numeric(state$a_lambda %||% rep(1.0, p))
      b_lambda <- pmax(as.numeric(state$b_lambda %||% rep(1.0, p)), var_floor)
      a_nu <- as.numeric(state$a_nu %||% rep(1.0, p))
      b_nu <- pmax(as.numeric(state$b_nu %||% rep(1.0, p)), var_floor)
      a_tau <- max(as.numeric(state$a_tau %||% ((m_active + 1.0) / 2.0))[1L], 1e-12)
      b_tau <- max(as.numeric(state$b_tau %||% 1.0)[1L], var_floor)
      a_xi <- max(as.numeric(state$a_xi %||% 1.0)[1L], 1e-12)
      b_xi <- max(as.numeric(state$b_xi %||% 1.0)[1L], var_floor)

      # constants for this prior family
      a_lambda[] <- 1.0
      a_nu[] <- 1.0
      a_xi <- 1.0
      a_tau <- max((m_active + 1.0) / 2.0, 1e-12)

      if (length(active_idx)) {
        for (inner in seq_len(n_inner)) {
          e_inv_tau <- a_tau / b_tau
          e_inv_nu <- a_nu / b_nu

          b_lambda[active_idx] <- pmax(0.5 * beta2[active_idx] * e_inv_tau + e_inv_nu[active_idx], var_floor)
          e_inv_lambda <- a_lambda / b_lambda

          b_nu[active_idx] <- pmax(1.0 + e_inv_lambda[active_idx], var_floor)
          e_inv_nu <- a_nu / b_nu

          if (!isTRUE(tau_warmup)) {
            e_inv_xi <- a_xi / b_xi
            b_tau <- pmax(0.5 * sum(beta2[active_idx] * e_inv_lambda[active_idx]) + e_inv_xi, var_floor)

            e_inv_tau <- a_tau / b_tau
            b_xi <- pmax((1.0 / (tau0^2)) + e_inv_tau, var_floor)
            tau_updated <- TRUE
          }
        }
      }

      if (isTRUE(state$zeta2_is_fixed)) {
        a_zeta <- NA_real_
        b_zeta <- NA_real_
        e_inv_zeta <- 1.0 / pmax(as.numeric(state$zeta2_fixed)[1L], var_floor)
      } else {
        a_zeta <- a_zeta0 + m_active / 2.0
        b_zeta <- b_zeta0 + 0.5 * if (length(active_idx)) sum(beta2[active_idx]) else 0.0
        a_zeta <- max(as.numeric(a_zeta), 1e-12)
        b_zeta <- max(as.numeric(b_zeta), var_floor)
        e_inv_zeta <- a_zeta / b_zeta
      }

      e_inv_lambda <- a_lambda / b_lambda
      e_inv_nu <- a_nu / b_nu
      e_inv_tau <- a_tau / b_tau
      e_inv_xi <- a_xi / b_xi

      # keep point state aligned with inverse-moment centers for MCMC warm starts
      state$lambda2 <- 1.0 / pmax(e_inv_lambda, var_floor)
      state$nu <- 1.0 / pmax(e_inv_nu, var_floor)
      state$tau2 <- as.numeric(1.0 / pmax(e_inv_tau, var_floor))[1L]
      state$xi <- as.numeric(1.0 / pmax(e_inv_xi, var_floor))[1L]
      state$zeta2 <- if (isTRUE(state$zeta2_is_fixed)) {
        as.numeric(state$zeta2_fixed)[1L]
      } else {
        as.numeric(1.0 / pmax(e_inv_zeta, var_floor))[1L]
      }

      state$a_lambda <- a_lambda
      state$b_lambda <- b_lambda
      state$a_nu <- a_nu
      state$b_nu <- b_nu
      state$a_tau <- a_tau
      state$b_tau <- b_tau
      state$a_xi <- a_xi
      state$b_xi <- b_xi
      state$a_zeta <- if (isTRUE(state$zeta2_is_fixed)) NA_real_ else a_zeta
      state$b_zeta <- if (isTRUE(state$zeta2_is_fixed)) NA_real_ else b_zeta
      state$E_inv_lambda2 <- e_inv_lambda
      state$E_inv_nu <- e_inv_nu
      state$E_inv_tau2 <- e_inv_tau
      state$E_inv_xi <- e_inv_xi
      state$E_inv_zeta2 <- e_inv_zeta
      state$iter <- iter_now
      state$freeze_tau <- isTRUE(tau_warmup)
      state$update_tau_only <- FALSE
      state$tau_update_count <- as.integer(state$tau_update_count %||% 0L) + if (tau_updated) 1L else 0L
      state$has_post_warmup_tau_update <- isTRUE(
        state$has_post_warmup_tau_update %||% FALSE
      ) || isTRUE(tau_updated)
      state$last_schedule <- list(
        iter = iter_now,
        tau_warmup = tau_warmup,
        reason = if (tau_warmup) "warmup" else if (force_tau_now) "force_after_warmup" else "scheduled",
        tau_updated = tau_updated,
        tau_update_count = state$tau_update_count
      )

      if (isTRUE(verbose)) {
        cat(sprintf(
          "[RHS_NS] tau=%.4g zeta2=%.4g E[1/tau2]=%.4g E[1/zeta2]=%.4g\n",
          state$tau2^0.5, state$zeta2, state$E_inv_tau2, state$E_inv_zeta2
        ))
      }

      state
    },

    elbo = function(state, qbeta) {
      if (is.null(state$p)) .stopf("rhs_ns_prior$elbo: state missing p.")
      p <- as.integer(state$p)
      if (is.null(qbeta$m) || is.null(qbeta$V)) .stopf("rhs_ns_prior$elbo: qbeta must provide m and V.")
      if (length(qbeta$m) != p) .stopf("rhs_ns_prior$elbo: qbeta$m length mismatch.")
      if (!all(dim(qbeta$V) == c(p, p))) .stopf("rhs_ns_prior$elbo: qbeta$V dim mismatch.")

      beta2 <- as.numeric(qbeta$m)^2 + diag(qbeta$V)
      intercept_idx <- .rhs_ns_intercept_idx(p, state$shrink_intercept, state$intercept_index)
      active_idx <- .rhs_ns_active_idx(p, state$shrink_intercept, intercept_idx)

      a_lambda <- as.numeric(state$a_lambda %||% rep(1.0, p))
      b_lambda <- pmax(as.numeric(state$b_lambda %||% rep(1.0, p)), var_floor)
      a_nu <- as.numeric(state$a_nu %||% rep(1.0, p))
      b_nu <- pmax(as.numeric(state$b_nu %||% rep(1.0, p)), var_floor)
      a_tau <- max(as.numeric(state$a_tau %||% 1.0)[1L], 1e-12)
      b_tau <- max(as.numeric(state$b_tau %||% 1.0)[1L], var_floor)
      a_xi <- max(as.numeric(state$a_xi %||% 1.0)[1L], 1e-12)
      b_xi <- max(as.numeric(state$b_xi %||% 1.0)[1L], var_floor)

      e_log_lambda <- log(b_lambda) - digamma(a_lambda)
      e_log_nu <- log(b_nu) - digamma(a_nu)
      e_inv_lambda <- a_lambda / b_lambda
      e_inv_nu <- a_nu / b_nu
      e_log_tau <- log(b_tau) - digamma(a_tau)
      e_inv_tau <- a_tau / b_tau
      e_log_xi <- log(b_xi) - digamma(a_xi)
      e_inv_xi <- a_xi / b_xi

      if (isTRUE(state$zeta2_is_fixed)) {
        e_log_zeta <- log(pmax(as.numeric(state$zeta2_fixed)[1L], var_floor))
        e_inv_zeta <- 1.0 / pmax(as.numeric(state$zeta2_fixed)[1L], var_floor)
        e_log_p_zeta <- 0.0
        h_zeta <- 0.0
      } else {
        a_zeta <- max(as.numeric(state$a_zeta %||% a_zeta0)[1L], 1e-12)
        b_zeta <- max(as.numeric(state$b_zeta %||% b_zeta0)[1L], var_floor)
        e_log_zeta <- log(b_zeta) - digamma(a_zeta)
        e_inv_zeta <- a_zeta / b_zeta
        e_log_p_zeta <- a_zeta0 * log(b_zeta0) - lgamma(a_zeta0) -
          (a_zeta0 + 1.0) * e_log_zeta - b_zeta0 * e_inv_zeta
        h_zeta <- .rhs_ns_ig_entropy(a_zeta, b_zeta)
      }

      if (!length(active_idx)) {
        e_log_joint <- 0.0
        h_latent <- 0.0
      } else {
        k_half <- 0.5
        log2pi_half <- -0.5 * log(2 * pi)

        # E log p(beta_j | tau2, lambda_j2)
        e_log_p_beta_hs <- sum(
          log2pi_half -
            0.5 * e_log_tau -
            0.5 * e_log_lambda[active_idx] -
            0.5 * beta2[active_idx] * e_inv_tau * e_inv_lambda[active_idx]
        )

        # E log p(z_j=0 | beta_j, zeta2)
        e_log_p_beta_slab <- sum(
          log2pi_half -
            0.5 * e_log_zeta -
            0.5 * beta2[active_idx] * e_inv_zeta
        )

        # local half-Cauchy mixture
        e_log_p_lambda_given_nu <- sum(
          k_half * (-e_log_nu[active_idx]) -
            lgamma(k_half) -
            (k_half + 1.0) * e_log_lambda[active_idx] -
            e_inv_nu[active_idx] * e_inv_lambda[active_idx]
        )
        e_log_p_nu <- sum(
          -lgamma(k_half) -
            (k_half + 1.0) * e_log_nu[active_idx] -
            e_inv_nu[active_idx]
        )

        # global half-Cauchy mixture with scale tau0
        e_log_p_tau_given_xi <- (
          k_half * (-e_log_xi) -
            lgamma(k_half) -
            (k_half + 1.0) * e_log_tau -
            e_inv_xi * e_inv_tau
          )
        e_log_p_xi <- (
          k_half * log(1.0 / (tau0^2)) -
            lgamma(k_half) -
            (k_half + 1.0) * e_log_xi -
            (1.0 / (tau0^2)) * e_inv_xi
        )

        e_log_joint <- e_log_p_beta_hs + e_log_p_beta_slab +
          e_log_p_lambda_given_nu + e_log_p_nu +
          e_log_p_tau_given_xi + e_log_p_xi + e_log_p_zeta

        h_latent <- sum(.rhs_ns_ig_entropy(a_lambda[active_idx], b_lambda[active_idx])) +
          sum(.rhs_ns_ig_entropy(a_nu[active_idx], b_nu[active_idx])) +
          .rhs_ns_ig_entropy(a_tau, b_tau) +
          .rhs_ns_ig_entropy(a_xi, b_xi) +
          h_zeta
      }

      e_log_intercept <- 0.0
      if (length(intercept_idx)) {
        prec_int <- .rhs_ns_intercept_prec_vec(p, intercept_idx, state$intercept_prec %||% intercept_prec)
        prec_int <- prec_int[intercept_idx]
        prec_int[!is.finite(prec_int) | prec_int <= 0] <- 1e-16
        e_log_intercept <- sum(0.5 * (log(prec_int) - log(2 * pi)) - 0.5 * prec_int * beta2[intercept_idx])
      }

      list(elbo = as.numeric(e_log_joint + h_latent + e_log_intercept))
    }
  )
}
