# Canonical, normalized Piironen--Vehtari regularized horseshoe readout.
# This file deliberately does not implement the distinct rhs_ns prior.

#' Controls for the independent regularized horseshoe AutoDESN readout
#'
#' The common auxiliary global scale is u ~ half-Cauchy(0,1), and model m
#' uses `tau_m = tau0[m] * u`. Slopes have variance
#' (1 / (tau_m^2 * lambda_j^2) + 1 / c^2)^(-1), independently of
#' observation variance. The intercept retains its separate proper prior.
#' Local scales have independent standard half-Cauchy priors, and
#' c^2 ~ inverse-gamma(slab_df/2, slab_df*slab_scale^2/2).
#'
#' @param tau0 Positive global prior multiplier, scalar or one per candidate.
#' @param slab_scale Positive slab scale (not its variance).
#' @param slab_df Positive slab prior degrees of freedom.
#' @param learn_global,learn_slab Whether the global/slab scale is sampled.
#' @param fixed_local_scales Optional positive lambda values, scalar or length
#'   equal to the largest slope count. NULL learns the local scales.
#' @param initial_global Initial common auxiliary u; also its fixed value when
#'   learn_global=FALSE.
#' @param initial_slab Initial c^2, also its fixed value when learn_slab=FALSE.
#'   NULL uses slab_scale^2.
#' @param save_local Save each retained draw's active local scales.
#' @param slice_width Positive unbounded log-scale slice width.
#' @param slice_steps Maximum randomized stepping-out budget per slice update.
#' @param slice_max_shrink Maximum slice proposals before reporting failure.
#' @param local_max_attempts Maximum exact local rejection proposals per update.
#' @param ... Reserved; unknown arguments are rejected.
#' @return A validated list of RHS controls.
#' @export
autodesn_rhs_control <- function(tau0 = 1, slab_scale = 2, slab_df = 4,
    learn_global = TRUE, learn_slab = TRUE, fixed_local_scales = NULL,
    initial_global = 1, initial_slab = NULL, save_local = FALSE,
    slice_width = 1, slice_steps = 50L, slice_max_shrink = 10000L,
    local_max_attempts = 100000L, ...) {
  extra <- list(...)
  if (length(extra)) stop("Unknown RHS control arguments: ",
    paste(if (is.null(names(extra))) "<unnamed>" else names(extra), collapse = ", "),
    call. = FALSE)
  if (!is.numeric(tau0) || !length(tau0) || any(!is.finite(tau0) | tau0 <= 0))
    stop("tau0 must contain positive finite values.", call. = FALSE)
  for (nm in c("slab_scale", "slab_df", "initial_global", "slice_width"))
    .autodesn_positive(get(nm), nm)
  for (nm in c("learn_global", "learn_slab", "save_local"))
    .autodesn_flag(get(nm), nm)
  for (nm in c("slice_steps", "slice_max_shrink", "local_max_attempts"))
    .autodesn_integer(get(nm), nm)
  if (!is.null(initial_slab)) .autodesn_positive(initial_slab, "initial_slab (c^2)")
  if (!is.null(fixed_local_scales) && (!is.numeric(fixed_local_scales) ||
      !length(fixed_local_scales) || any(!is.finite(fixed_local_scales) | fixed_local_scales <= 0)))
    stop("fixed_local_scales must contain positive finite lambda values.", call. = FALSE)
  out <- list(tau0 = as.numeric(tau0), slab_scale = slab_scale, slab_df = slab_df,
    learn_global = learn_global, learn_slab = learn_slab,
    fixed_local_scales = fixed_local_scales, initial_global = initial_global,
    initial_slab = initial_slab, save_local = save_local,
    slice_width = slice_width, slice_steps = as.integer(slice_steps),
    slice_max_shrink = as.integer(slice_max_shrink),
    local_max_attempts = as.integer(local_max_attempts))
  structure(out, class = c("autodesn_rhs_control", "list"))
}

.autodesn_rhs_named_list <- function(x, name) {
  if (!is.list(x) || (length(x) && (is.null(names(x)) ||
      any(!nzchar(names(x))) || anyDuplicated(names(x)))))
    stop(name, " must be a list with unique nonempty argument names.", call. = FALSE)
  x
}

.autodesn_rhs_model_control <- function(x, prior) {
  if (is.null(x)) x <- list()
  .autodesn_rhs_named_list(x, "model_control")
  unknown <- setdiff(names(x), c("method", "moves", "proposal", "rb_every", "initial_model"))
  if (length(unknown)) stop("Unknown model_control arguments: ", paste(unknown, collapse = ", "), call. = FALSE)
  defaults <- list(method = "mh", moves = 2L, proposal = prior,
    rb_every = 0L, initial_model = NULL)
  z <- utils::modifyList(defaults, x, keep.null = TRUE)
  z$method <- match.arg(z$method, c("mh", "categorical"))
  .autodesn_integer(z$moves, "model_control$moves")
  .autodesn_integer(z$rb_every, "model_control$rb_every", 0L)
  if (is.null(z$proposal)) z$proposal <- prior
  if (!is.numeric(z$proposal) || length(z$proposal) != length(prior) ||
      any(!is.finite(z$proposal) | z$proposal <= 0))
    stop("model_control$proposal must have positive finite mass on every model.", call. = FALSE)
  z$proposal <- z$proposal / max(z$proposal)
  z$proposal <- z$proposal / sum(z$proposal)
  if (any(z$proposal <= 0)) stop("Model proposal probabilities underflowed to zero.", call. = FALSE)
  if (!is.null(z$initial_model)) {
    .autodesn_integer(z$initial_model, "model_control$initial_model")
    if (z$initial_model > length(prior)) stop("initial_model is outside the bank.", call. = FALSE)
    z$initial_model <- as.integer(z$initial_model)
  }
  if (z$method == "categorical") z$moves <- 1L
  z
}

.autodesn_rhs_logadd <- function(a, b) {
  high <- pmax(a, b)
  ans <- high + log1p(exp(-abs(a - b)))
  both_negative <- is.infinite(high) & high < 0
  ans[both_negative] <- -Inf
  ans
}

.autodesn_rhs_log_variance <- function(log_local, log_global, log_slab, tau0 = 1) {
  -.autodesn_rhs_logadd(-log_slab, -2 * (log(tau0) + log_global + log_local))
}

# Exact Gaussian coefficient integral in the ORIGINAL feature basis. Whiten
# by prior SD to avoid forming enormous local prior precisions.
.autodesn_rhs_gaussian_R <- function(model, y, variance, log_prior_variance) {
  p <- ncol(model$X)
  if (length(log_prior_variance) != p || any(!is.finite(log_prior_variance)))
    stop("Invalid RHS log prior variances.", call. = FALSE)
  .autodesn_positive(variance, "variance")
  sqrt_prior <- as.numeric(exp(log_prior_variance / 2))
  if (any(!is.finite(sqrt_prior))) stop("RHS prior SD overflow; inspect scale draws.", call. = FALSE)
  K <- (model$XtX * tcrossprod(sqrt_prior)) / variance
  diag(K) <- diag(K) + 1
  if (any(!is.finite(K))) stop("RHS Gaussian system overflow; inspect scales.", call. = FALSE)
  R <- tryCatch(chol(K), error = function(e)
    stop("RHS Gaussian Cholesky failed: ", conditionMessage(e), call. = FALSE))
  rhs <- sqrt_prior * model$Xty / variance
  whitened_mean <- backsolve(R, forwardsolve(t(R), rhs))
  mu <- as.numeric(sqrt_prior * whitened_mean)
  yty <- if (is.null(model$yty)) sum(y * y) else model$yty
  cross <- sum(mu * model$Xty)
  fit2 <- sum(mu * as.numeric(model$XtX %*% mu))
  rss <- yty - 2 * cross + fit2
  cancellation <- 128 * .Machine$double.eps * (abs(yty) + 2 * abs(cross) + abs(fit2))
  if (!is.finite(rss) || rss <= cancellation)
    rss <- sum((y - as.numeric(model$X %*% mu))^2)
  quadratic <- rss / variance + sum(whitened_mean * whitened_mean)
  log_evidence <- -0.5 * (length(y) * (log(2 * pi) + log(variance)) +
    2 * sum(log(diag(R))) + quadratic)
  if (!is.finite(log_evidence) || any(!is.finite(mu)))
    stop("Nonfinite RHS Gaussian integral; no candidate was silently discarded.", call. = FALSE)
  list(log_evidence = log_evidence, mean = mu, chol = unname(R), sqrt_prior = sqrt_prior)
}

.autodesn_rhs_beta_draw <- function(gaussian, z) {
  if (length(z) != length(gaussian$mean) || any(!is.finite(z)))
    stop("Invalid standard-normal vector for RHS coefficient draw.", call. = FALSE)
  as.numeric(gaussian$mean + gaussian$sqrt_prior * backsolve(gaussian$chol, z))
}

# Exact PV local scale update. With x=lambda^2, nu the half-Cauchy
# auxiliary, A=1/c^2, B=1/tau^2 and b=1/nu+beta^2/(2*tau^2),
# f(x) is proportional to sqrt(A+B/x) x^(-3/2) exp(-b/x).
# The envelope (sqrt(A)+sqrt(B/x)) gives a mixture of IG(1/2,b)
# and IG(1,b). Its acceptance probability is at least 1/sqrt(2).
.autodesn_rhs_local_R <- function(log_local, log_aux, beta, log_tau, log_slab,
                                  max_attempts = 100000L) {
  if (length(log_local) != length(beta) || length(log_aux) != length(beta))
    stop("Local RHS update has inconsistent dimensions.", call. = FALSE)
  attempts <- integer(length(beta))
  for (j in seq_along(beta)) {
    log_quad <- if (beta[j] == 0) -Inf else 2 * log(abs(beta[j])) - log(2) - 2 * log_tau
    log_b <- .autodesn_rhs_logadd(-log_aux[j], log_quad)
    log_A <- -log_slab
    log_B <- -2 * log_tau
    log_w1 <- 0.5 * log_A + 0.5 * log(pi) - 0.5 * log_b
    log_w2 <- 0.5 * log_B - log_b
    mixture <- stats::plogis(log_w1 - log_w2)
    accepted <- FALSE
    for (k in seq_len(max_attempts)) {
      shape <- if (stats::runif(1) < mixture) 0.5 else 1
      gamma_draw <- stats::rgamma(1, shape = shape, rate = 1)
      if (!is.finite(gamma_draw) || gamma_draw <= 0)
        stop("Numerically invalid gamma variate in RHS local update.", call. = FALSE)
      log_x <- log_b - log(gamma_draw)
      ratio <- exp(-0.5 * abs(log_A - (log_B - log_x)))
      log_accept <- 0.5 * log1p(ratio^2) - log1p(ratio)
      if (log(stats::runif(1)) <= log_accept) {
        accepted <- TRUE
        attempts[j] <- k
        break
      }
    }
    if (!accepted) stop("Exact RHS local rejection sampler exhausted its budget.", call. = FALSE)
    log_local[j] <- 0.5 * log_x
    gamma_draw <- stats::rgamma(1, shape = 1, rate = 1)
    if (!is.finite(gamma_draw) || gamma_draw <= 0)
      stop("Numerically invalid gamma variate in RHS auxiliary update.", call. = FALSE)
    log_aux[j] <- .autodesn_rhs_logadd(0, -log_x) - log(gamma_draw)
  }
  list(log_local = log_local, log_aux = log_aux, attempts = attempts)
}

# Log density in log(u), log(c^2), with beta slopes and local scales fixed.
# Includes Gaussian normalizers and both transformation Jacobians.
.autodesn_rhs_log_scale_target <- function(log_local, log_global, log_slab,
    beta, tau0, slab_df, slab_scale) {
  log_v <- .autodesn_rhs_log_variance(log_local, log_global, log_slab, tau0)
  log_beta2 <- rep(-Inf, length(beta))
  nonzero <- beta != 0
  log_beta2[nonzero] <- 2 * log(abs(beta[nonzero]))
  quadratic <- sum(exp(log_beta2 - log_v))
  gaussian <- -0.5 * (length(beta) * log(2 * pi) + sum(log_v) + quadratic)
  global <- log(2 / pi) - abs(log_global) - log1p(exp(-2 * abs(log_global)))
  shape <- slab_df / 2
  log_rate <- log(slab_df / 2) + 2 * log(slab_scale)
  slab <- shape * log_rate - lgamma(shape) - shape * log_slab - exp(log_rate - log_slab)
  ans <- gaussian + global + slab
  if (is.na(ans) || ans == Inf) stop("Invalid RHS scale log density.", call. = FALSE)
  ans
}

# Randomized finite stepping-out is a valid unbounded slice kernel. Hitting
# the shrinkage safety budget is an explicit failure, not a retained bad draw.
.autodesn_rhs_slice <- function(x, log_density, width, steps, max_shrink) {
  current <- log_density(x)
  if (!is.finite(current)) stop("RHS slice sampler started outside finite density.", call. = FALSE)
  level <- current + log(stats::runif(1))
  left <- x - width * stats::runif(1)
  right <- left + width
  j <- floor(steps * stats::runif(1))
  k <- steps - 1L - j
  count_out <- 0L
  while (j > 0L && log_density(left) > level) {
    left <- left - width; j <- j - 1L; count_out <- count_out + 1L
  }
  while (k > 0L && log_density(right) > level) {
    right <- right + width; k <- k - 1L; count_out <- count_out + 1L
  }
  if (!is.finite(left) || !is.finite(right) || left >= right)
    stop("Numerically invalid unbounded RHS slice bracket.", call. = FALSE)
  for (attempt in seq_len(max_shrink)) {
    proposal <- stats::runif(1, left, right)
    if (log_density(proposal) >= level)
      return(list(value = proposal, proposals = attempt, steps_out = count_out))
    if (proposal < x) left <- proposal else right <- proposal
  }
  stop("RHS slice sampler exhausted its shrinkage budget.", call. = FALSE)
}

.autodesn_rhs_backend <- function(backend, model, y, variance, log_prior_variance) {
  backend <- match.arg(tolower(backend), c("auto", "r", "cpp"))
  gaussian_r <- .autodesn_rhs_gaussian_R
  if (backend == "r") return(list(name = "r", gaussian = gaussian_r, local = .autodesn_rhs_local_R))
  available <- exists("autodesn_rhs_gaussian_cpp", mode = "function") &&
    exists("autodesn_rhs_local_cpp", mode = "function")
  if (available) {
    # A source-loaded generated wrapper can exist without its DLL. One
    # deterministic call checks actual availability before entering the chain.
    probe <- try(autodesn_rhs_gaussian_cpp(model$XtX, model$Xty, sum(y^2),
      variance, log_prior_variance, model$X, y), silent = TRUE)
    available <- !inherits(probe, "try-error")
  }
  if (!available) {
    if (backend == "cpp") stop("The requested RHS C++ backend is not loaded.", call. = FALSE)
    return(list(name = "r", gaussian = gaussian_r, local = .autodesn_rhs_local_R))
  }
  list(name = "cpp", gaussian = function(model, y, variance, log_prior_variance)
    autodesn_rhs_gaussian_cpp(model$XtX, model$Xty,
      if (is.null(model$yty)) sum(y^2) else model$yty,
      variance, log_prior_variance, model$X, y),
    local = autodesn_rhs_local_cpp)
}

.autodesn_fit_rhs_bank <- function(bank, n_burn, n_mcmc, thin,
    intercept_variance, a_sigma, b_sigma, initial_variance, seed,
    rhs_control = NULL, model_control = NULL, backend = "auto") {
  if (!inherits(bank, "autodesn_bank")) stop("Expected an autodesn_bank.", call. = FALSE)
  for (nm in c("n_burn", "n_mcmc", "thin"))
    .autodesn_integer(get(nm), nm, if (nm == "n_burn") 0L else 1L)
  for (nm in c("intercept_variance", "a_sigma", "b_sigma")) .autodesn_positive(get(nm), nm)
  if (is.null(initial_variance)) initial_variance <- max(stats::var(bank$y), 0.01)
  .autodesn_positive(initial_variance, "initial_variance")
  if (is.null(rhs_control)) rhs_control <- list()
  .autodesn_rhs_named_list(rhs_control, "rhs_control")
  rc <- do.call(autodesn_rhs_control, unclass(rhs_control))
  M <- length(bank$models)
  dims <- vapply(bank$models, function(m) as.integer(m$d), integer(1))
  dmax <- max(dims)
  if (!length(rc$tau0) %in% c(1L, M)) stop("tau0 must be scalar or have one value per model.", call. = FALSE)
  tau0 <- rep(rc$tau0, length.out = M)
  fixed_local <- rc$fixed_local_scales
  if (!is.null(fixed_local) && !length(fixed_local) %in% unique(c(1L, dmax)))
    stop("fixed_local_scales must be scalar or have length equal to the largest slope count.", call. = FALSE)
  if (!is.null(fixed_local)) fixed_local <- rep(fixed_local, length.out = dmax)
  initial_slab <- if (is.null(rc$initial_slab)) rc$slab_scale^2 else rc$initial_slab
  .autodesn_positive(initial_slab, "initial slab variance")
  mc <- .autodesn_rhs_model_control(model_control, bank$prior)
  iterations <- n_burn + n_mcmc
  .autodesn_integer(iterations, "total iterations")
  retained <- seq.int(n_burn + 1L, iterations, by = thin)
  keep <- logical(iterations); keep[retained] <- TRUE
  K <- length(retained)
  # Fixed sufficient statistics; no feature rotation or column rescaling.
  bank$models <- lapply(bank$models, function(m) {m$yty <- sum(bank$y^2); m})
  target <- list(beta_prior_type = "independent_rhs", prior_family = "regularized_horseshoe_pv",
    intercept_variance = intercept_variance, a_sigma = a_sigma, b_sigma = b_sigma,
    tau0 = tau0, slab_scale = if (rc$learn_slab) rc$slab_scale else NULL,
    slab_df = if (rc$learn_slab) rc$slab_df else NULL,
    learn_global = rc$learn_global, learn_slab = rc$learn_slab,
    fixed_global = if (rc$learn_global) NULL else rc$initial_global,
    fixed_slab = if (rc$learn_slab) NULL else initial_slab,
    fixed_local_scales = fixed_local)
  .autodesn_seed(seed, function() {
    model_id <- if (is.null(mc$initial_model)) sample.int(M, 1L, prob = bank$prior) else mc$initial_model
    log_u <- log(rc$initial_global); log_c2 <- log(initial_slab)
    ell <- if (is.null(fixed_local)) rep(0, dmax) else log(fixed_local)
    log_aux <- rep(0, dmax)
    variance <- initial_variance
    first_logv <- c(log(intercept_variance), .autodesn_rhs_log_variance(
      ell[seq_len(dims[model_id])], log_u, log_c2, tau0[model_id]))
    engine <- .autodesn_rhs_backend(backend, bank$models[[model_id]], bank$y, variance, first_logv)
    draws <- data.frame(iteration = retained, model = integer(K), variance = numeric(K),
      global_scale = numeric(K), global_tau = numeric(K), slab_variance = numeric(K),
      log_global = numeric(K), log_slab = numeric(K), mean_log_local = numeric(K),
      intercept = numeric(K), fitted_rms = numeric(K), effective_slopes_diagonal = numeric(K))
    beta <- vector("list", K)
    local_saved <- if (rc$save_local) vector("list", K) else NULL
    local_log_saved <- if (rc$save_local) vector("list", K) else NULL
    cp <- if (mc$method == "categorical") matrix(NA_real_, K, M) else NULL
    rb <- list(); rb_iterations <- integer(0)
    proposals <- acceptances <- transitions <- matrix(0L, M, M)
    evaluations <- 0L; local_attempts <- 0L; local_updates <- 0L
    slice_proposals <- c(global = 0L, slab = 0L)
    slice_steps_out <- c(global = 0L, slab = 0L)
    evaluate <- function(j) {
      evaluations <<- evaluations + 1L
      lv <- c(log(intercept_variance), .autodesn_rhs_log_variance(
        ell[seq_len(dims[j])], log_u, log_c2, tau0[j]))
      engine$gaussian(bank$models[[j]], bank$y, variance, lv)
    }
    k <- 0L
    for (it in seq_len(iterations)) {
      full_p <- NULL
      gaussian <- evaluate(model_id)
      if (mc$method == "categorical") {
        all_fit <- vector("list", M); all_fit[[model_id]] <- gaussian
        for (j in setdiff(seq_len(M), model_id)) all_fit[[j]] <- evaluate(j)
        full_p <- .autodesn_softmax(log(bank$prior) + vapply(all_fit, `[[`, 0, "log_evidence"))
        old <- model_id
        model_id <- sample.int(M, 1L, prob = full_p)
        gaussian <- all_fit[[model_id]]
        transitions[old, model_id] <- transitions[old, model_id] + 1L
      } else {
        for (move in seq_len(mc$moves)) {
          proposed <- sample.int(M, 1L, prob = mc$proposal)
          old <- model_id
          proposals[old, proposed] <- proposals[old, proposed] + 1L
          if (proposed == model_id) {
            acceptances[old, proposed] <- acceptances[old, proposed] + 1L
          } else {
            candidate <- evaluate(proposed)
            ratio <- log(bank$prior[proposed]) + candidate$log_evidence - log(mc$proposal[proposed]) -
              log(bank$prior[model_id]) - gaussian$log_evidence + log(mc$proposal[model_id])
            if (log(stats::runif(1)) < min(0, ratio)) {
              model_id <- proposed; gaussian <- candidate
              acceptances[old, proposed] <- acceptances[old, proposed] + 1L
            }
          }
          transitions[old, model_id] <- transitions[old, model_id] + 1L
        }
      }
      if (keep[it] && mc$rb_every > 0L && ((k + 1L) %% mc$rb_every == 0L)) {
        if (is.null(full_p)) {
          loge <- numeric(M); loge[model_id] <- gaussian$log_evidence
          for (j in setdiff(seq_len(M), model_id)) loge[j] <- evaluate(j)$log_evidence
          full_p <- .autodesn_softmax(log(bank$prior) + loge)
        }
        rb[[length(rb) + 1L]] <- full_p
        rb_iterations <- c(rb_iterations, it)
      }
      # This redraw MUST immediately follow the beta-collapsed model move.
      b <- .autodesn_rhs_beta_draw(gaussian, stats::rnorm(length(gaussian$mean)))
      fitted <- as.numeric(bank$models[[model_id]]$X %*% b)
      variance <- 1 / stats::rgamma(1L, shape = a_sigma + bank$n / 2,
        rate = b_sigma + sum((bank$y - fitted)^2) / 2)
      .autodesn_positive(variance, "sampled observation variance")
      active <- seq_len(dims[model_id])
      if (is.null(fixed_local)) {
        if (length(active)) {
          upd <- engine$local(ell[active], log_aux[active], b[-1L],
            log(tau0[model_id]) + log_u, log_c2, rc$local_max_attempts)
          ell[active] <- upd$log_local; log_aux[active] <- upd$log_aux
          local_attempts <- local_attempts + sum(upd$attempts)
          local_updates <- local_updates + length(active)
        }
        inactive <- setdiff(seq_len(dmax), active)
        if (length(inactive)) {
          # Draw inactive auxiliaries from their proper joint half-Cauchy prior.
          ell[inactive] <- log(abs(stats::rcauchy(length(inactive))))
          g <- stats::rgamma(length(inactive), shape = 1, rate = 1)
          log_aux[inactive] <- .autodesn_rhs_logadd(0, -2 * ell[inactive]) - log(g)
          if (any(!is.finite(c(ell[inactive], log_aux[inactive]))))
            stop("Numerically invalid inactive RHS prior draw.", call. = FALSE)
        }
      }
      target_scale <- function(u, slab) .autodesn_rhs_log_scale_target(
        ell[active], u, slab, b[-1L], tau0[model_id], rc$slab_df, rc$slab_scale)
      if (rc$learn_global) {
        upd <- .autodesn_rhs_slice(log_u, function(x) target_scale(x, log_c2),
          rc$slice_width, rc$slice_steps, rc$slice_max_shrink)
        log_u <- upd$value
        slice_proposals["global"] <- slice_proposals["global"] + upd$proposals
        slice_steps_out["global"] <- slice_steps_out["global"] + upd$steps_out
      }
      if (rc$learn_slab) {
        upd <- .autodesn_rhs_slice(log_c2, function(x) target_scale(log_u, x),
          rc$slice_width, rc$slice_steps, rc$slice_max_shrink)
        log_c2 <- upd$value
        slice_proposals["slab"] <- slice_proposals["slab"] + upd$proposals
        slice_steps_out["slab"] <- slice_steps_out["slab"] + upd$steps_out
      }
      if (keep[it]) {
        k <- k + 1L
        lv <- .autodesn_rhs_log_variance(ell[active], log_u, log_c2, tau0[model_id])
        info <- if (length(active)) diag(bank$models[[model_id]]$XtX)[-1L] else numeric(0)
        effective <- sum(stats::plogis(lv + log(info) - log(variance)))
        draws[k, -1L] <- c(model_id, variance, exp(log_u), exp(log(tau0[model_id]) + log_u),
          exp(log_c2), log_u, log_c2, if (dmax) mean(ell) else 0,
          b[1L], sqrt(mean(fitted^2)), effective)
        beta[[k]] <- b
        if (!is.null(cp)) cp[k, ] <- full_p
        if (rc$save_local) {
          local_saved[[k]] <- exp(ell[active]); local_log_saved[[k]] <- ell[active]
        }
      }
    }
    occupancy <- tabulate(draws$model, nbins = M) / K
    posterior <- if (is.null(cp)) occupancy else colMeans(cp)
    summary <- cbind(bank$model_info, prior_probability = bank$prior,
      posterior_probability = posterior, occupancy = occupancy)
    rb_matrix <- if (length(rb)) do.call(rbind, rb) else matrix(numeric(0), 0L, M)
    if (nrow(rb_matrix)) summary$rao_blackwell_probability <- colMeans(rb_matrix)
    off_diagonal <- row(proposals) != col(proposals)
    stats <- list(model_proposals = proposals, model_acceptances = acceptances,
      model_transitions = transitions, model_evaluations = evaluations,
      nonself_proposals = sum(proposals[off_diagonal]),
      nonself_acceptances = sum(acceptances[off_diagonal]),
      local_rejection_attempts = local_attempts, local_updates = local_updates,
      slice_proposals = slice_proposals, slice_steps_out = slice_steps_out,
      numerical_failures = 0L, iteration_scope = "all_sweeps_including_burnin")
    structure(list(bank = bank, draws = draws, beta = beta,
      conditional_probabilities = cp, rb_probabilities = rb_matrix,
      rb_iterations = rb_iterations, local_scales = local_saved,
      local_log_scales = local_log_saved, model_summary = summary, sampler_stats = stats,
      controls = list(n_burn = n_burn, n_mcmc = n_mcmc, thin = thin,
        intercept_variance = intercept_variance, a_sigma = a_sigma, b_sigma = b_sigma,
        initial_variance = initial_variance, seed = seed, rhs_control = unclass(rc),
        model_control = mc, backend = engine$name, target = target),
      meta = utils::modifyList(if (is.null(bank$meta)) list() else bank$meta,
        list(inference_method = if (mc$method == "mh") "collapsed_mh" else "blocked_gibbs_rhs",
          likelihood_family = "normal", target = "conditional_mean",
          beta_prior_type = "independent_rhs", prior_family = "regularized_horseshoe_pv",
          probability_estimator = if (is.null(cp)) "occupancy" else "rao_blackwell",
          local_scale_augmentation = "common_max_dimension_prefix",
          mean_log_local_definition = "mean_of_common_auxiliary_vector_zero_when_dimension_zero",
          shrinkage_diagnostic = "diagonal_design_approximation",
          scale_support = "unbounded_log_scale"))), class = "autodesn_fit")
  })
}
