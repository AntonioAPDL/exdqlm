# R/exal_static_mcmc.R
#
# GIG parameterization used here:
#   Math:  GIG(k, chi, psi) proportional to z^{k-1} exp( - (chi/z + psi z)/2 )
#   C++ :  sample_gig_devroye(p, a, b) has density proportional to x^{p-1} exp( - (a x + b/x)/2 )
#   Map :  p = k, a = psi, b = chi
#
#' exAL (static) - MCMC algorithm
#'
#' The function applies a Gibbs sampler for static Extended Asymmetric Laplace regression
#' (exAL). We update \eqn{\beta, v, s} from their full conditionals, then update
#' \eqn{(\sigma,\gamma)} either jointly on transformed coordinates
#' \eqn{(\ell,\eta)=(\log \sigma,\mathrm{logit}((\gamma-L)/(U-L)))} (for
#' \code{"rw"} and \code{"laplace_rw"}) or with the legacy gamma-only kernels
#' (\code{"slice"}, \code{"slice_eta"}, \code{"laplace_local"}).
#' Optional multi-refresh and global-jump controls are available to improve
#' exAL mixing in hard cases.
#'
#' @param y Numeric vector of length \eqn{n}.
#' @param X Numeric matrix \eqn{n \times p} (design).
#' @param p0 Quantile level in \eqn{(0,1)}.
#' @param b0,V0 Prior mean and covariance for \eqn{\beta} (Normal). Defaults:
#'   \eqn{b_0=\mathbf{0}_p}, \eqn{V_0=10^6 I_p}.
#' @param beta_prior Coefficient prior type: \code{"ridge"} (default),
#'   \code{"rhs"} (regularized horseshoe), or \code{"rhs_ns"}
#'   (Nishimura-Suchard regularized horseshoe with a closed-form
#'   inverse-gamma hierarchy for static inference).
#' @param beta_prior_controls Optional list of prior-specific controls. For
#'   RHS-family priors (that is, when \code{beta_prior} is \code{"rhs"} or
#'   \code{"rhs_ns"}), supported keys follow the qdesn-style static interface:
#'   \code{tau0}, \code{nu}, \code{s} or \code{s2},
#'   \code{shrink_intercept}, \code{intercept_prec}, \code{n_inner},
#'   \code{eta_bounds}, \code{var_floor}, \code{h_curv}, \code{verbose},
#'   \code{init_lambda}, \code{init_log_lambda}, \code{init_tau},
#'   \code{init_log_tau}, \code{init_c2}, \code{init_log_c2},
#'   \code{collapse_tau_ratio_tol}, \code{collapse_beta_max_abs_tol},
#'   \code{collapse_invV_med_tol}, \code{collapse_beta_l2_tol},
#'   \code{collapse_small_beta_frac_tol}, \code{small_beta_abs_tol},
#'   \code{slice_width}, and \code{slice_max_steps}. For
#'   \code{beta_prior = "rhs_ns"}, optional slab controls
#'   \code{a_zeta}, \code{b_zeta}, and \code{zeta2_fixed} are also supported.
#'   In this mode, the local-global-slab block is represented by
#'   \eqn{(\lambda_j^2,\nu_j,\tau^2,\xi,\zeta^2)} and updated with
#'   closed-form Gibbs steps. When
#'   \code{beta_prior} is \code{"rhs"} or \code{"rhs_ns"}, \code{b0} and \code{V0}
#'   are ignored for the
#'   shrunk coefficients and retained only for backward-compatible ridge
#'   behavior. If both \code{init_log_tau} and \code{init_tau} are omitted
#'   (or \code{NULL}), the RHS global scale initializes at \code{tau = 1}
#'   (\code{init_log_tau = 0}) instead of \code{tau0}. By default
#'   (\code{shrink_intercept = FALSE}), the intercept is excluded from
#'   horseshoe shrinkage and uses \code{intercept_prec}.
#' @param a_sigma,b_sigma Hyperparameters for an inverse-gamma prior on
#'   \code{sigma}, with density proportional to
#'   \code{sigma^{-(a_sigma+1)} exp(-b_sigma/sigma)}.
#' @param gamma_bounds Numeric length-2 vector (L, U) for \code{gamma}.
#'   Defaults to \code{c(L.fn(p0), U.fn(p0))}.
#' @param log_prior_gamma Function \code{function(g) log pi(g)} for \code{gamma}
#'   on (L, U). Default is a truncated Student-t prior centered at 0 on the
#'   admissible support.
#' @param init Optional list with starting values: \code{beta}, \code{sigma},
#'   \code{gamma}, \code{v} (length \eqn{n}), \code{s} (length \eqn{n}), and
#'   for RHS-family priors optionally \code{lambda}, \code{tau}, and
#'   \code{c2}. For \code{beta_prior = "rhs_ns"}, the squared-scale
#'   parameterization \code{lambda2}, \code{tau2}, \code{zeta2}, and optional
#'   auxiliaries \code{nu}, \code{xi} are also accepted. Missing pieces are
#'   filled sensibly.
#' @param dqlm.ind Logical; if \code{TRUE}, fit the reduced AL model
#'   (\code{gamma = 0}), corresponding to Bayesian linear quantile regression
#'   under the AL working likelihood. This removes the \code{gamma}- and
#'   \code{s}-blocks and leaves conjugate Gibbs updates for \code{beta},
#'   \code{sigma}, and \code{v}.
#' @param n.burn Number of burn-in iterations. Default \code{2000}.
#' @param n.mcmc Number of kept MCMC iterations (after burn). Default \code{1500}.
#' @param thin Integer; save every \code{thin}-th iteration after burn. We internally run
#'   \code{n.burn + n.mcmc * thin} iterations to return exactly \code{n.mcmc} saved draws.
#' @param init.from.vb Logical; if \code{TRUE}, run static VB first and use its
#'   posterior moments as MCMC initialization.
#' @param vb_init_controls Optional list controlling VB warm start. Supported keys:
#'   \code{max_iter}, \code{tol}, \code{n_samp_xi}, \code{verbose}, and
#'   \code{ld_controls} (passed through to \code{exal_static_LDVB()}).
#' @param mh.proposal Character string controlling the exAL nonconjugate update
#'   kernel. \code{"slice"} (default) uses an exact bounded univariate slice
#'   sampler on \code{gamma} (with \code{sigma} updated from its conditional),
#'   and \code{"slice_eta"} does the same on transformed \code{eta}.
#'   \code{"laplace_rw"} uses a Laplace-informed adaptive random-walk MH update
#'   on the transformed joint block
#'   \eqn{(\eta,\ell)=(\mathrm{logit}((\gamma-L)/(U-L)), \log\sigma)}.
#'   \code{"rw"} uses the same exact joint update with identity base covariance.
#'   \code{"laplace_local"} reproduces the prior approximate local-Gaussian
#'   gamma draw (not signoff-ready).
#'   Only \code{"laplace_local"} is approximate.
#' @param mh.adapt Logical; adapt the random-walk proposal scale during burn-in
#'   for \code{"rw"} and \code{"laplace_rw"}. Ignored for
#'   \code{"laplace_local"}, \code{"slice"}, and \code{"slice_eta"}.
#' @param mh.adapt.interval Integer adaptation window for RW-based kernels.
#' @param mh.target.accept Numeric length-2 target acceptance band.
#' @param mh.scale.bounds Numeric length-2 lower/upper bounds for RW proposal
#'   scale multiplier.
#' @param mh.max_scale.step Numeric multiplicative adaptation cap in \code{(0,1)}.
#' @param mh.min_burn_adapt Integer minimum burn-in before adaptation starts.
#' @param slice.width Positive numeric width for bounded slice updates when
#'   \code{mh.proposal = "slice"} or \code{"slice_eta"}.
#' @param slice.max.steps Positive integer or \code{Inf}; maximum stepping-out
#'   expansions for the slice sampler.
#' @param gamma.substeps Positive integer; number of consecutive gamma-kernel
#'   refreshes per outer MCMC iteration. Default \code{1}.
#' @param p.global.eta.jump Numeric in \code{[0,1]}; per-substep probability of
#'   proposing a global independence-MH move on eta (the logit transform of
#'   gamma) using a Laplace proposal with MH correction. Default \code{0}.
#' @param global.eta.jump.scale Positive numeric scale multiplier applied to the
#'   Laplace proposal SD used in global eta jumps.
#' @param trace.diagnostics Logical; if \code{TRUE}, retain per-iteration
#'   gamma/s diagnostics under \code{mh.diagnostics$trace}. Set \code{FALSE}
#'   for lighter-weight runs.
#' @param trace.every Positive integer; when \code{trace.diagnostics=TRUE},
#'   record one diagnostics row every \code{trace.every} iterations.
#' @param verbose Print progress every \code{progress_every} iterations.
#' @param progress_callback Optional callback invoked with a named list at MCMC
#'   start, at each progress checkpoint, and on completion. Intended for
#'   workflow-level per-case progress logging.
#'
#' @return A object of class "\code{exal_mcmc}" containing:
#' \itemize{
#'   \item \code{run.time} - total wall time in seconds.
#'   \item \code{X}, \code{p0}, \code{bounds} - design, quantile, and (L, U).
#'   \item \code{samp.beta} - posterior sample of \code{beta} as \code{coda::mcmc} (n.mcmc x p).
#'   \item \code{samp.sigma} - posterior sample of \code{sigma} as \code{coda::mcmc}.
#'   \item \code{samp.gamma} - posterior sample of \code{gamma} as \code{coda::mcmc}.
#'   \item \code{samp.v} - latent \code{v} draws as \code{coda::mcmc} (\code{n.mcmc x n}).
#'   \item \code{samp.s} - latent \code{s} draws as \code{coda::mcmc} (\code{n.mcmc x n}).
#'   \item \code{samp.lambda}, \code{samp.tau}, \code{samp.c2} - RHS latent
#'         draws when an RHS-family prior is used; otherwise \code{NULL}.
#'   \item \code{beta_prior} - prior metadata and, for RHS-family priors,
#'         posterior summaries of the shrinkage block. For \code{"rhs_ns"},
#'         the state tracks \code{lambda2}, \code{nu}, \code{tau2}, \code{xi},
#'         and \code{zeta2}.
#'   \item \code{mh.diagnostics} - proposal kernel diagnostics for the exAL gamma update,
#'         including whether the saved kernel is exact/signoff-ready.
#'   \item \code{rhs.diagnostics} - RHS latent summaries and optional trace
#'         metadata when an RHS-family prior is used, including the resolved
#'         preflight configuration used at fit start.
#'   \item \code{last} - last state of the chain (useful for restarts).
#' }
#' @export
#'
#' @examples
#' \donttest{
#' set.seed(123)
#' n <- 80; p <- 3
#' X <- cbind(1, rnorm(n), rnorm(n))
#' beta0 <- c(0.5, -1, 0.8); sigma0 <- 1.2
#' y <- as.numeric(X %*% beta0 + rnorm(n, 0, sigma0))
#' fit <- exal_static_mcmc(
#'   y, X, p0 = 0.5, n.burn = 200, n.mcmc = 200, thin = 1, verbose = FALSE
#' )
#' summary(fit$samp.beta)
#'
#' fit_rhs <- exal_static_mcmc(
#'   y, X, p0 = 0.5,
#'   beta_prior = "rhs",
#'   beta_prior_controls = list(tau0 = 0.5, nu = 3, s2 = 1, shrink_intercept = FALSE),
#'   n.burn = 120, n.mcmc = 120, thin = 1, mh.proposal = "slice", verbose = FALSE
#' )
#' fit_rhs$beta_prior$type
#'
#' fit_rhs_ns <- exal_static_mcmc(
#'   y, X, p0 = 0.5,
#'   beta_prior = "rhs_ns",
#'   beta_prior_controls = list(tau0 = 0.5, a_zeta = 1.5, b_zeta = 1, zeta2_fixed = 1),
#'   n.burn = 80, n.mcmc = 80, thin = 1, mh.proposal = "slice", verbose = FALSE
#' )
#' fit_rhs_ns$beta_prior$type
#'
#' fit_al <- exal_static_mcmc(
#'   y, X, p0 = 0.5,
#'   dqlm.ind = TRUE,
#'   n.burn = 120, n.mcmc = 120, thin = 1, verbose = FALSE
#' )
#' fit_al$dqlm.ind
#' }
exal_static_mcmc <- function(
  y, X, p0,
  b0 = NULL, V0 = NULL,
  beta_prior = c("ridge", "rhs", "rhs_ns"),
  beta_prior_controls = NULL,
  a_sigma = 1, b_sigma = 1,
  gamma_bounds = c(L.fn(p0), U.fn(p0)),
  log_prior_gamma = NULL,
  init = NULL,
  dqlm.ind = FALSE,
  n.burn = 2000, n.mcmc = 1500, thin = 1,
  init.from.vb = FALSE,
  vb_init_controls = NULL,
  mh.proposal = c("slice", "laplace_rw", "rw", "slice_eta", "laplace_local"),
  mh.adapt = TRUE,
  mh.adapt.interval = 50L,
  mh.target.accept = c(0.20, 0.45),
  mh.scale.bounds = c(0.1, 10),
  mh.max_scale.step = 0.35,
  mh.min_burn_adapt = 50L,
  slice.width = 0.1,
  slice.max.steps = Inf,
  gamma.substeps = 1L,
  p.global.eta.jump = 0,
  global.eta.jump.scale = 1,
  trace.diagnostics = TRUE,
  trace.every = 1L,
  verbose = TRUE,
  progress_callback = NULL
){
  ## --- checks (mirror exdqlmMCMC style) ------------------------------------
  y <- as.numeric(y)
  X <- as.matrix(X); storage.mode(X) <- "double"
  n <- length(y); p <- ncol(X)
  if (nrow(X) != n) stop("nrow(X) must match length(y).")
  if (!(p0 > 0 && p0 < 1)) stop("p0 must be in (0,1).")
  if (n.burn < 0 || n.mcmc <= 0 || thin < 1) stop("n.burn>=0, n.mcmc>0, thin>=1 required.")

  b0_missing <- is.null(b0)
  V0_missing <- is.null(V0)
  if (is.null(b0)) b0 <- rep(0, p)
  if (is.null(V0)) V0 <- diag(1e6, p)
  V0 <- as.matrix(V0)
  if (!all(dim(V0) == c(p, p))) stop("V0 must be p x p.")
  beta_prior_obj <- .static_beta_prior_make(
    beta_prior = beta_prior,
    p = p,
    b0 = b0,
    V0 = V0,
    beta_prior_controls = beta_prior_controls,
    warn_rhs_b0 = !b0_missing,
    warn_rhs_V0 = !V0_missing
  )
  rhs_active_idx <- if (.static_is_rhs_family(beta_prior_obj$type)) {
    .static_rhs_active_idx(p, beta_prior_obj$controls$shrink_intercept)
  } else {
    integer(0)
  }
  rhs_preflight <- NULL
  if (.static_is_rhs_family(beta_prior_obj$type)) {
    rhs_preflight <- .static_rhs_preflight_config(beta_prior_obj$controls)
    if (isTRUE(verbose) || isTRUE(beta_prior_obj$controls$verbose)) {
      .static_rhs_preflight_emit(rhs_preflight, context = "exal_static_mcmc")
    }
  }

  L <- gamma_bounds[1]; U <- gamma_bounds[2]
  if (!(L < U)) stop("gamma_bounds must satisfy L < U.")
  if (is.null(log_prior_gamma)) {
    log_prior_gamma <- function(g) .gamma_log_prior_trunc_t(g, bounds = c(L, U))
  }

  ## --- shorthands for A,B,C,lambda -----------------------------------------
  A_of   <- function(g) A.fn(p0, g)
  B_of   <- function(g) B.fn(p0, g)
  C_of   <- function(g) C.fn(p0, g)
  lam_of <- function(g) C_of(g) * abs(g)
  mh.proposal <- match.arg(mh.proposal)
  mh.adapt <- isTRUE(mh.adapt)
  mh.adapt.interval <- suppressWarnings(as.integer(mh.adapt.interval)[1])
  if (!is.finite(mh.adapt.interval) || mh.adapt.interval < 5L) mh.adapt.interval <- 50L
  mh.min_burn_adapt <- suppressWarnings(as.integer(mh.min_burn_adapt)[1])
  if (!is.finite(mh.min_burn_adapt) || mh.min_burn_adapt < 20L) mh.min_burn_adapt <- 50L
  if (length(mh.target.accept) != 2L) mh.target.accept <- c(0.20, 0.45)
  mh.target.accept <- sort(pmin(pmax(as.numeric(mh.target.accept), 0.01), 0.99))
  if (length(mh.scale.bounds) != 2L) mh.scale.bounds <- c(0.1, 10)
  mh.scale.bounds <- sort(as.numeric(mh.scale.bounds))
  if (!all(is.finite(mh.scale.bounds)) || mh.scale.bounds[1] <= 0 || mh.scale.bounds[2] <= mh.scale.bounds[1]) {
    mh.scale.bounds <- c(0.1, 10)
  }
  mh_max_scale_step <- as.numeric(mh.max_scale.step)[1]
  if (!is.finite(mh_max_scale_step) || mh_max_scale_step <= 0 || mh_max_scale_step >= 1) {
    mh_max_scale_step <- 0.35
  }
  mh_laplace_refresh_interval <- suppressWarnings(as.integer(getOption("exdqlm.static.mcmc.laplace_refresh_interval", mh.adapt.interval))[1])
  if (!is.finite(mh_laplace_refresh_interval) || mh_laplace_refresh_interval < 5L) {
    mh_laplace_refresh_interval <- mh.adapt.interval
  }
  mh_laplace_refresh_start <- suppressWarnings(as.integer(getOption("exdqlm.static.mcmc.laplace_refresh_start", mh.min_burn_adapt))[1])
  if (!is.finite(mh_laplace_refresh_start) || mh_laplace_refresh_start < 1L) {
    mh_laplace_refresh_start <- mh.min_burn_adapt
  }
  mh_laplace_refresh_weight <- as.numeric(getOption("exdqlm.static.mcmc.laplace_refresh_weight", 0.60))[1]
  if (!is.finite(mh_laplace_refresh_weight) || mh_laplace_refresh_weight <= 0 || mh_laplace_refresh_weight > 1) {
    mh_laplace_refresh_weight <- 0.60
  }
  slice.width <- as.numeric(slice.width)[1]
  if (!is.finite(slice.width) || slice.width <= 0) slice.width <- 0.1
  slice.max.steps <- as.numeric(slice.max.steps)[1]
  if (!(is.infinite(slice.max.steps) || (is.finite(slice.max.steps) && slice.max.steps >= 1 && floor(slice.max.steps) == slice.max.steps))) {
    slice.max.steps <- Inf
  }
  eta.slice.bounds <- c(-20, 20)
  gamma.substeps <- suppressWarnings(as.integer(gamma.substeps)[1])
  if (!is.finite(gamma.substeps) || gamma.substeps < 1L) gamma.substeps <- 1L
  p.global.eta.jump <- as.numeric(p.global.eta.jump)[1]
  if (!is.finite(p.global.eta.jump)) p.global.eta.jump <- 0
  p.global.eta.jump <- min(max(p.global.eta.jump, 0), 1)
  global.eta.jump.scale <- as.numeric(global.eta.jump.scale)[1]
  if (!is.finite(global.eta.jump.scale) || global.eta.jump.scale <= 0) {
    global.eta.jump.scale <- 1
  }
  trace.diagnostics <- isTRUE(trace.diagnostics)
  trace.every <- suppressWarnings(as.integer(trace.every)[1])
  if (!is.finite(trace.every) || trace.every < 1L) trace.every <- 1L
  if (n.burn < mh.min_burn_adapt) mh.adapt <- FALSE
  progress_every_env <- suppressWarnings(as.integer(Sys.getenv("EXDQLM_MCMC_PROGRESS_EVERY", NA_character_))[1])
  progress_every <- if (is.finite(progress_every_env) && !is.na(progress_every_env) && progress_every_env >= 1L) {
    progress_every_env
  } else if (trace.diagnostics) {
    trace.every
  } else {
    100L
  }
  progress_every <- max(1L, as.integer(progress_every)[1])
  safe_progress_callback <- function(info) {
    if (!is.function(progress_callback)) return(invisible(NULL))
    try(progress_callback(info), silent = TRUE)
    invisible(NULL)
  }
  fail_state <- function(msg, iter = NA_integer_) {
    iter_lab <- if (is.finite(iter)) sprintf("iter=%d", as.integer(iter)[1]) else "iter=NA"
    stop(sprintf("Static MCMC state invalid (%s): %s", iter_lab, msg), call. = FALSE)
  }
  require_finite_scalar <- function(x, label, positive = FALSE) {
    val <- as.numeric(x)[1]
    if (!is.finite(val)) fail_state(sprintf("%s is non-finite", label))
    if (positive && val <= 0) fail_state(sprintf("%s must be > 0; got %.6g", label, val))
    val
  }
  require_finite_vector <- function(x, label, positive = FALSE) {
    val <- as.numeric(x)
    bad <- which(!is.finite(val))
    if (length(bad)) fail_state(sprintf("%s has %d non-finite values (first index=%d)", label, length(bad), bad[1]))
    if (positive) {
      badp <- which(val <= 0)
      if (length(badp)) fail_state(sprintf("%s has %d non-positive values (first index=%d, value=%.6g)", label, length(badp), badp[1], val[badp[1]]))
    }
    val
  }
  validate_gig_inputs <- function(chi, psi, iter, label) {
    chi <- as.numeric(chi)
    bad <- which(!is.finite(chi))
    if (length(bad)) {
      fail_state(sprintf("%s chi has %d non-finite values (first index=%d)", label, length(bad), bad[1]), iter = iter)
    }
    badneg <- which(chi < 0)
    if (length(badneg)) {
      fail_state(sprintf("%s chi has %d negative values (first index=%d, value=%.6g)", label, length(badneg), badneg[1], chi[badneg[1]]), iter = iter)
    }
    if (!is.finite(psi) || psi <= 0) {
      fail_state(sprintf("%s psi must be finite and > 0; got %.6g", label, psi), iter = iter)
    }
    list(chi = pmax(chi, 1e-12), psi = max(as.numeric(psi)[1], 1e-12))
  }

  if (is.null(init)) init <- list()
  sanitize_init_component <- function(name, positive = FALSE) {
    val <- init[[name]]
    if (is.null(val)) return(invisible(NULL))
    vec <- suppressWarnings(as.numeric(val))
    bad <- !is.finite(vec) | if (positive) vec <= 0 else FALSE
    if (any(bad)) {
      kind <- if (positive) "non-finite/non-positive" else "non-finite"
      warning(
        sprintf(
          "Dropping %s warm-start values in init$%s; falling back to internal defaults.",
          kind, name
        ),
        call. = FALSE
      )
      init[[name]] <<- NULL
    }
    invisible(NULL)
  }
  if (isTRUE(init.from.vb)) {
    vb.ctrl.default <- list(
      max_iter = 500L,
      tol = 1e-4,
      n_samp_xi = 200L,
      verbose = FALSE,
      ld_controls = NULL
    )
    if (is.null(vb_init_controls)) vb_init_controls <- list()
    vb.ctrl <- utils::modifyList(vb.ctrl.default, vb_init_controls)
    vb.ctrl$max_iter <- suppressWarnings(as.integer(vb.ctrl$max_iter)[1])
    if (!is.finite(vb.ctrl$max_iter) || vb.ctrl$max_iter < 10L) vb.ctrl$max_iter <- 500L
    vb.ctrl$tol <- as.numeric(vb.ctrl$tol)[1]
    if (!is.finite(vb.ctrl$tol) || vb.ctrl$tol <= 0) vb.ctrl$tol <- 1e-4
    vb.ctrl$n_samp_xi <- suppressWarnings(as.integer(vb.ctrl$n_samp_xi)[1])
    if (!is.finite(vb.ctrl$n_samp_xi) || vb.ctrl$n_samp_xi < 50L) vb.ctrl$n_samp_xi <- 200L
    vb.ctrl$verbose <- isTRUE(vb.ctrl$verbose)
    if (!is.null(vb.ctrl$ld_controls) && !is.list(vb.ctrl$ld_controls)) {
      stop("vb_init_controls$ld_controls must be a list or NULL")
    }

    vb_b0 <- if (b0_missing) NULL else b0
    vb_V0 <- if (V0_missing) NULL else V0
    vb.fit <- exal_static_LDVB(
      y = y, X = X, p0 = p0,
      max_iter = vb.ctrl$max_iter,
      tol = vb.ctrl$tol,
      b0 = vb_b0, V0 = vb_V0,
      beta_prior = beta_prior,
      beta_prior_controls = beta_prior_controls,
      a_sigma = a_sigma, b_sigma = b_sigma,
      gamma_bounds = gamma_bounds,
      log_prior_gamma = log_prior_gamma,
      init = init,
      dqlm.ind = dqlm.ind,
      n_samp_xi = vb.ctrl$n_samp_xi,
      ld_controls = vb.ctrl$ld_controls,
      verbose = vb.ctrl$verbose
    )

    if (isTRUE(dqlm.ind)) {
      if (is.null(init$beta)) init$beta <- as.numeric(vb.fit$qbeta$m)
      if (is.null(init$sigma)) init$sigma <- as.numeric(vb.fit$qsig$E_sigma)
      if (is.null(init$v)) init$v <- as.numeric(vb.fit$qv$E_v)
    } else {
      if (is.null(init$beta)) init$beta <- as.numeric(vb.fit$qbeta$m)
      if (is.null(init$sigma)) init$sigma <- as.numeric(vb.fit$qsiggam$sigma_mean)
      if (is.null(init$gamma)) init$gamma <- as.numeric(vb.fit$qsiggam$gamma_mean)
      if (is.null(init$v)) init$v <- as.numeric(vb.fit$qv$E_v)
      if (is.null(init$s)) init$s <- as.numeric(vb.fit$qs$E_s)
    }
  }

  # VB warm starts can occasionally carry non-finite seeds in hard cases.
  # Drop invalid components and let standard defaults initialize those blocks.
  sanitize_init_component("beta", positive = FALSE)
  sanitize_init_component("sigma", positive = TRUE)
  sanitize_init_component("gamma", positive = FALSE)
  sanitize_init_component("v", positive = TRUE)
  sanitize_init_component("s", positive = FALSE)
  sanitize_init_component("lambda", positive = TRUE)
  sanitize_init_component("tau", positive = TRUE)
  sanitize_init_component("c2", positive = TRUE)

  ## --- storage (post-burn) --------------------------------------------------
  n_save <- n.mcmc
  save.beta  <- matrix(NA_real_, n_save, p)
  save.sigma <- numeric(n_save)
  save.gamma <- numeric(n_save)
  save.v     <- matrix(NA_real_, n, n_save)
  save.s     <- matrix(NA_real_, n, n_save)
  save.lambda <- if (.static_is_rhs_family(beta_prior_obj$type)) matrix(NA_real_, n_save, p) else NULL
  save.tau <- if (.static_is_rhs_family(beta_prior_obj$type)) numeric(n_save) else NULL
  save.c2 <- if (.static_is_rhs_family(beta_prior_obj$type)) numeric(n_save) else NULL

  ## --- initialize -----------------------------------------------------------
  beta  <- if (is.null(init$beta)) rep(0, p) else as.numeric(init$beta)
  if (length(beta) != p) beta <- rep(beta[1], p)
  beta <- require_finite_vector(beta, "init$beta")
  sigma <- if (is.null(init$sigma)) 1 else as.numeric(init$sigma)[1]
  sigma <- require_finite_scalar(sigma, "init$sigma", positive = TRUE)
  gamma <- if (is.null(init$gamma)) 0 else as.numeric(init$gamma)[1]
  gamma <- require_finite_scalar(gamma, "init$gamma")
  gamma <- min(max(gamma, L + 1e-6), U - 1e-6)
  xb <- drop(X %*% beta)

  A <- A_of(gamma); B <- B_of(gamma); lambda <- lam_of(gamma)

  v <- if (is.null(init$v)) rep(1, n) else as.numeric(init$v)
  if (length(v) != n) v <- rep(v[1], n)
  v <- require_finite_vector(v, "init$v", positive = TRUE)
  s <- if (is.null(init$s)) abs(stats::rnorm(n)) else as.numeric(init$s)
  if (length(s) != n) s <- rep(s[1], n)
  s <- require_finite_vector(s, "init$s")
  s <- pmax(0, s)
  beta_state <- beta_prior_obj$init_mcmc()
  if (.static_is_rhs_family(beta_prior_obj$type)) {
    if (isTRUE(init.from.vb) && exists("vb.fit", inherits = FALSE) &&
        !is.null(vb.fit$beta_prior$state)) {
      vb_state <- vb.fit$beta_prior$state
      if (identical(beta_prior_obj$type, "rhs_ns")) {
        if (!is.null(vb_state$lambda2)) {
          lam2 <- as.numeric(vb_state$lambda2)
          if (length(lam2) == 1L) lam2 <- rep(lam2, p)
          if (length(lam2) == p) beta_state$lambda2 <- pmax(lam2, 1e-16)
        } else if (!is.null(vb_state$eta_lambda_hat)) {
          beta_state$lambda2 <- pmax(.static_rhs_safe_exp(vb_state$eta_lambda_hat)^2, 1e-16)
        }
        if (!is.null(vb_state$tau2)) {
          beta_state$tau2 <- pmax(as.numeric(vb_state$tau2)[1], 1e-16)
        } else if (!is.null(vb_state$eta_tau_hat)) {
          beta_state$tau2 <- pmax(.static_rhs_safe_exp(vb_state$eta_tau_hat)^2, 1e-16)
        }
        if (!is.null(vb_state$zeta2)) {
          beta_state$zeta2 <- pmax(as.numeric(vb_state$zeta2)[1], 1e-16)
        } else if (!is.null(vb_state$c2)) {
          beta_state$zeta2 <- pmax(as.numeric(vb_state$c2)[1], 1e-16)
        } else if (!is.null(vb_state$eta_c_hat)) {
          beta_state$zeta2 <- pmax(.static_rhs_safe_exp(vb_state$eta_c_hat)[1], 1e-16)
        }
        if (!is.null(vb_state$nu)) {
          nu0 <- as.numeric(vb_state$nu)
          if (length(nu0) == 1L) nu0 <- rep(nu0, p)
          if (length(nu0) == p) beta_state$nu <- pmax(nu0, 1e-16)
        }
        if (!is.null(vb_state$xi)) beta_state$xi <- pmax(as.numeric(vb_state$xi)[1], 1e-16)
        beta_state <- .static_rhs_ns_recompute_moments(beta_state, beta_prior_obj$controls)
      } else {
        beta_state$lambda <- .static_rhs_safe_exp(vb_state$eta_lambda_hat)
        beta_state$tau <- .static_rhs_safe_exp(vb_state$eta_tau_hat)
        beta_state$c2 <- .static_rhs_safe_exp(vb_state$eta_c_hat)
      }
    }
    if (identical(beta_prior_obj$type, "rhs_ns")) {
      if (!is.null(init$lambda)) {
        lam0 <- as.numeric(init$lambda)
        if (length(lam0) == 1L) lam0 <- rep(lam0, p)
        if (length(lam0) == p) beta_state$lambda2 <- pmax(lam0^2, 1e-16)
      }
      if (!is.null(init$lambda2)) {
        lam2 <- as.numeric(init$lambda2)
        if (length(lam2) == 1L) lam2 <- rep(lam2, p)
        if (length(lam2) == p) beta_state$lambda2 <- pmax(lam2, 1e-16)
      }
      if (!is.null(init$nu)) {
        nu0 <- as.numeric(init$nu)
        if (length(nu0) == 1L) nu0 <- rep(nu0, p)
        if (length(nu0) == p) beta_state$nu <- pmax(nu0, 1e-16)
      }
      if (!is.null(init$tau)) beta_state$tau2 <- pmax(as.numeric(init$tau)[1]^2, 1e-16)
      if (!is.null(init$tau2)) beta_state$tau2 <- pmax(as.numeric(init$tau2)[1], 1e-16)
      if (!is.null(init$xi)) beta_state$xi <- pmax(as.numeric(init$xi)[1], 1e-16)
      if (!is.null(init$c2)) beta_state$zeta2 <- pmax(as.numeric(init$c2)[1], 1e-16)
      if (!is.null(init$zeta2)) beta_state$zeta2 <- pmax(as.numeric(init$zeta2)[1], 1e-16)
      beta_state <- .static_rhs_ns_recompute_moments(beta_state, beta_prior_obj$controls)
    } else {
      if (!is.null(init$lambda)) {
        lam0 <- as.numeric(init$lambda)
        if (length(lam0) == 1L) lam0 <- rep(lam0, p)
        if (length(lam0) == p) beta_state$lambda <- pmax(lam0, 1e-16)
      }
      if (!is.null(init$tau)) beta_state$tau <- pmax(as.numeric(init$tau)[1], 1e-16)
      if (!is.null(init$c2)) beta_state$c2 <- pmax(as.numeric(init$c2)[1], 1e-16)
    }
  }

  # --- reduced AL / DQLM Gibbs path (no gamma, no s) ------------------------
  if (isTRUE(dqlm.ind)) {
    A <- (1 - 2 * p0) / (p0 * (1 - p0))
    B <- 2 / (p0 * (1 - p0))

    n_save <- n.mcmc
    save.beta  <- matrix(NA_real_, n_save, p)
    save.sigma <- numeric(n_save)
    save.v     <- matrix(NA_real_, n, n_save)

    beta  <- if (is.null(init$beta)) rep(0, p) else as.numeric(init$beta)
    if (length(beta) != p) beta <- rep(beta[1], p)
    beta <- require_finite_vector(beta, "init$beta")
    sigma <- if (is.null(init$sigma)) 1 else as.numeric(init$sigma)[1]
    sigma <- require_finite_scalar(sigma, "init$sigma", positive = TRUE)

    v <- if (is.null(init$v)) rep(1, n) else as.numeric(init$v)
    if (length(v) != n) v <- rep(v[1], n)
    v <- require_finite_vector(v, "init$v", positive = TRUE)
    v <- pmax(v, 1e-12)

    I <- n.burn + n.mcmc * thin
    .exdqlm_progress(
      "MCMC start",
      model = "AL special case",
      n = n,
      p = p,
      burn = n.burn,
      keep = n.mcmc,
      thin = thin,
      kernel = "conjugate",
      warm_start = if (isTRUE(init.from.vb)) "ldvb" else "none",
      .verbose = verbose
    )
    safe_progress_callback(list(
      event = "start",
      iter = 0L,
      total_iter = as.integer(I),
      phase = "burn",
      n_burn = as.integer(n.burn),
      n_mcmc = as.integer(n.mcmc),
      thin = as.integer(thin),
      kept_completed = 0L,
      kept_target = as.integer(n.mcmc),
      sigma = sigma,
      gamma = NA_real_,
      kernel = "conjugate",
      accept = NA_real_
    ))

    tictoc::tic()
    ksave <- 0L
    for (i in 1:I) {
      # (1) beta | sigma, v, y
      W_diag <- 1 / (B * sigma * v)
      Xw     <- X * sqrt(W_diag)
      prior_sys <- beta_prior_obj$beta_system_mcmc(beta_state)
      V_inv  <- crossprod(Xw) + prior_sys$Prec
      rhs    <- crossprod(X, W_diag * (y - A * v)) + prior_sys$h

      Uc <- tryCatch(chol(V_inv), error = function(e) NULL)
      if (is.null(Uc)) Uc <- chol(V_inv + 1e-10 * diag(p))
      m_beta <- backsolve(Uc, forwardsolve(t(Uc), rhs))
      beta   <- as.numeric(m_beta + backsolve(Uc, stats::rnorm(p)))
      xb     <- drop(X %*% beta)
      beta_state <- beta_prior_obj$update_mcmc(beta_state, beta)

      # (2) sigma | beta, v, y (inverse-gamma)
      r <- y - xb - A * v
      shape_sigma <- a_sigma + 1.5 * n
      rate_sigma  <- b_sigma + sum(v) + sum((r * r) / (2 * B * v))
      sigma <- 1 / stats::rgamma(1, shape = shape_sigma, rate = pmax(rate_sigma, 1e-12))

      # (3) v_i | beta, sigma, y_i (GIG with lambda = 1/2)
      r0 <- y - xb
      chi_i <- (r0 * r0) / (B * sigma)
      psi_i <- (A * A / B + 2) / sigma
      gig_in <- validate_gig_inputs(chi_i, psi_i, i, "static_al")
      v <- as.numeric(sample_gig_devroye_vector(
        1L, p = 0.5, a = gig_in$psi, b_vec = gig_in$chi
      )[1, ])
      v <- pmax(v, 1e-12)

      if (i > n.burn && ((i - n.burn) %% thin == 0)) {
        ksave <- ksave + 1L
        save.beta[ksave, ] <- beta
        save.sigma[ksave]  <- sigma
        save.v[, ksave]    <- v
        if (.static_is_rhs_family(beta_prior_obj$type)) {
          lam_draw <- rep(NA_real_, p)
          lam_draw[rhs_active_idx] <- beta_state$lambda[rhs_active_idx]
          save.lambda[ksave, ] <- lam_draw
          save.tau[ksave] <- beta_state$tau
          save.c2[ksave] <- beta_state$c2
        }
      }

      if (i %% progress_every == 0L) {
        .exdqlm_progress(
          "MCMC progress",
          model = "AL special case",
          phase = if (i <= n.burn) "burn" else "keep",
          iter = sprintf("%d/%d", i, I),
          sigma = sigma,
          kept = sprintf("%d/%d", ksave, n.mcmc),
          .verbose = verbose
        )
        safe_progress_callback(list(
          event = "progress",
          iter = as.integer(i),
          total_iter = as.integer(I),
          phase = if (i <= n.burn) "burn" else "keep",
          n_burn = as.integer(n.burn),
          n_mcmc = as.integer(n.mcmc),
          thin = as.integer(thin),
          kept_completed = as.integer(ksave),
          kept_target = as.integer(n.mcmc),
          sigma = sigma,
          gamma = NA_real_,
          kernel = "conjugate",
          accept = NA_real_
        ))
      }
    }
    run.time <- tictoc::toc(quiet = TRUE)
    .exdqlm_progress(
      "MCMC done",
      model = "AL special case",
      status = "complete",
      iter = I,
      runtime_sec = run.time$toc - run.time$tic,
      sigma = sigma,
      .verbose = verbose
    )
    safe_progress_callback(list(
      event = "complete",
      iter = as.integer(I),
      total_iter = as.integer(I),
      phase = "done",
      n_burn = as.integer(n.burn),
      n_mcmc = as.integer(n.mcmc),
      thin = as.integer(thin),
      kept_completed = as.integer(ksave),
      kept_target = as.integer(n.mcmc),
      sigma = sigma,
      gamma = NA_real_,
      kernel = "conjugate",
      accept = NA_real_,
      runtime_sec = as.numeric(run.time$toc - run.time$tic)
    ))

    ret <- list(
      run.time   = (run.time$toc - run.time$tic),
      y          = y,
      X          = X,
      p0         = p0,
      dqlm.ind   = TRUE,
      bounds     = c(L = NA_real_, U = NA_real_),
      samp.beta  = coda::as.mcmc(save.beta),
      samp.sigma = coda::as.mcmc(save.sigma),
      samp.lambda = if (.static_is_rhs_family(beta_prior_obj$type)) coda::as.mcmc(save.lambda) else NULL,
      samp.tau = if (.static_is_rhs_family(beta_prior_obj$type)) coda::as.mcmc(save.tau) else NULL,
      samp.c2 = if (.static_is_rhs_family(beta_prior_obj$type)) coda::as.mcmc(save.c2) else NULL,
      samp.v     = coda::as.mcmc(t(save.v)),
      init.from.vb = isTRUE(init.from.vb),
      vb.init.controls = if (isTRUE(init.from.vb)) vb.ctrl else NULL,
      n.burn = n.burn,
      n.mcmc = n.mcmc,
      accept.rate = NA_real_,
      accept.rate.burn = NA_real_,
      accept.rate.keep = NA_real_,
      mh.diagnostics = list(
        proposal = NA_character_,
        adapt = FALSE,
        kernel_exact = TRUE,
        signoff_ready = TRUE,
        approximation_note = NA_character_,
        accept = list(total = NA_real_, burn = NA_real_, keep = NA_real_),
        adaptation = data.frame()
      ),
      diagnostics = list(
        ess = list(
          sigma = tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.sigma))), error = function(e) NA_real_),
          gamma = NA_real_
        ),
        acceptance = list(total = NA_real_, burn = NA_real_, keep = NA_real_)
      ),
      beta_prior = list(
        type = beta_prior_obj$type,
        controls = beta_prior_obj$controls,
        summary = beta_prior_obj$summary_mcmc(beta_state, beta = beta),
        state = if (.static_is_rhs_family(beta_prior_obj$type)) beta_state else NULL
      ),
      rhs.diagnostics = if (.static_is_rhs_family(beta_prior_obj$type)) {
        list(
          preflight = rhs_preflight,
          summary = beta_prior_obj$summary_mcmc(beta_state, beta = beta),
          ess = list(
            tau = tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.tau))), error = function(e) NA_real_),
            c2 = tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.c2))), error = function(e) NA_real_)
          )
        )
      } else NULL,
      last = list(beta = beta, sigma = sigma, v = v)
    )
    class(ret) <- c("exal_mcmc", "exal_static_mcmc")
    return(ret)
  }

  ## --- helpers (keep names tidy like exdqlmMCMC) ---------------------------
  clamp_scale <- function(x) {
    x <- as.numeric(x)[1]
    if (!is.finite(x) || x <= 0) x <- mean(mh.scale.bounds)
    min(max(x, mh.scale.bounds[1]), mh.scale.bounds[2])
  }

  # eta <-> gamma transform on (L,U); ell <-> sigma
  g_from_eta <- function(eta) {
    s <- stats::plogis(eta); s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
    L + (U - L) * s
  }
  sig_from_ell <- function(ell) exp(as.numeric(ell)[1L])
  logJ <- function(eta) {
    s <- stats::plogis(eta); s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
    log(U - L) + log(s) + log1p(-s)
  }

  # log posterior in eta (gamma) kernel
  logpost_eta <- function(eta, xb, sigma, v, s_vec) {
    eta   <- as.numeric(eta)[1L]
    xb    <- as.numeric(xb); v <- as.numeric(v); s_vec <- as.numeric(s_vec)
    if (!all(is.finite(c(xb, sigma, v, s_vec)))) return(-Inf)
    if (sigma <= 0 || any(v <= 0)) return(-Inf)
    g   <- g_from_eta(eta)
    A   <- as.numeric(A_of(g))[1L]
    B   <- as.numeric(B_of(g))[1L]
    lam <- as.numeric(lam_of(g))[1L]
    if (!is.finite(B) || B <= 0) return(-Inf)

    mu   <- xb + lam * sigma * s_vec + A * v
    res  <- y - mu
    quad <- sum((res * res) / (B * sigma * v))
    if (!is.finite(quad)) return(-Inf)

    -(n / 2) * log(B) - 0.5 * quad + log_prior_gamma(g) + logJ(eta)
  }

  # log posterior in transformed joint block (eta, ell=log sigma)
  logpost_eta_ell <- function(par, xb, v, s_vec) {
    par <- as.numeric(par)
    eta <- par[1L]
    ell <- par[2L]
    sigma <- sig_from_ell(ell)
    xb <- as.numeric(xb); v <- as.numeric(v); s_vec <- as.numeric(s_vec)
    if (!all(is.finite(c(eta, ell, xb, sigma, v, s_vec)))) return(-Inf)
    if (sigma <= 0 || any(v <= 0)) return(-Inf)

    g <- g_from_eta(eta)
    A <- as.numeric(A_of(g))[1L]
    B <- as.numeric(B_of(g))[1L]
    lam <- as.numeric(lam_of(g))[1L]
    if (!is.finite(B) || B <= 0 || !is.finite(A) || !is.finite(lam)) return(-Inf)

    t_vec <- y - xb
    inv_v <- 1 / v
    sum_einv_quad <- sum((t_vec * t_vec) * inv_v)
    sum_t <- sum(t_vec)
    sum_v <- sum(v)
    sum_s_einv_t <- sum(s_vec * t_vec * inv_v)
    sum_s <- sum(s_vec)
    sum_s2_einv <- sum((s_vec * s_vec) * inv_v)
    if (!all(is.finite(c(sum_einv_quad, sum_t, sum_v, sum_s_einv_t, sum_s, sum_s2_einv)))) return(-Inf)

    term1 <- - (1 / (2 * B * sigma)) * (sum_einv_quad - 2 * A * sum_t + (A * A) * sum_v)
    term2 <- - (sum_v + b_sigma) / sigma
    term3 <- + (lam / B) * (sum_s_einv_t - sum_s * A)
    term4 <- - ((lam * lam) / (2 * B)) * sigma * sum_s2_einv

    log_prior <- log_prior_gamma(g)
    if (!is.finite(log_prior)) return(-Inf)

    # Includes transformed Jacobian for eta and ell.
    log_det <- - (n / 2) * log(B) - (((3 * n) / 2) + a_sigma + 1) * ell
    log_prior + log_det + term1 + term2 + term3 + term4 +
      .exal_static_ld_log_jacobian(eta = eta, ell = ell, L = L, U = U)
  }

  logpost_gamma <- function(g, xb, sigma, v, s_vec) {
    g <- as.numeric(g)[1L]
    xb <- as.numeric(xb)
    v <- as.numeric(v)
    s_vec <- as.numeric(s_vec)
    if (!is.finite(g) || g <= L || g >= U) return(-Inf)
    if (!all(is.finite(c(xb, sigma, v, s_vec)))) return(-Inf)
    if (sigma <= 0 || any(v <= 0)) return(-Inf)
    A <- as.numeric(A_of(g))[1L]
    B <- as.numeric(B_of(g))[1L]
    lam <- as.numeric(lam_of(g))[1L]
    if (!is.finite(B) || B <= 0 || !is.finite(A) || !is.finite(lam)) return(-Inf)

    mu <- xb + lam * sigma * s_vec + A * v
    res <- y - mu
    quad <- sum((res * res) / (B * sigma * v))
    lp <- log_prior_gamma(g)
    if (!is.finite(quad) || !is.finite(lp)) return(-Inf)

    -(n / 2) * log(B) - 0.5 * quad + lp
  }

  find_mode_eta <- function(eta0, xb, sigma, v, s_vec) {
    fn_log <- function(e) {
      val <- logpost_eta(e, xb, sigma, v, s_vec)
      if (!is.finite(val)) -Inf else val
    }
    fn_neg <- function(e) {
      val <- fn_log(e)
      if (!is.finite(val)) 1e50 else -val
    }
    base   <- as.numeric(eta0)[1L]
    starts <- c(base, base + c(-1, 1, -2, 2, -4, 4, -8, 8), 0)
    starts <- pmin(pmax(starts, -20), 20)
    cand   <- unique(starts)
    vals   <- sapply(cand, fn_log)
    idx    <- which(is.finite(vals))
    eta_start <- if (length(idx)) cand[idx[which.max(vals[idx])]] else 0
    used_fallback <- FALSE

    opt <- try(
      optim(par = eta_start, fn = fn_neg, method = "BFGS",
            control = list(maxit = 200), hessian = TRUE),
      silent = TRUE
    )
    if (inherits(opt, "try-error") || !is.finite(opt$value)) {
      used_fallback <- TRUE
      opt <- list(par = eta_start, value = fn_neg(eta_start), hessian = matrix(1e-4, 1, 1), convergence = 1L)
    }
    eta_hat <- as.numeric(opt$par)[1L]

    info_try <- try(-as.numeric(numDeriv::hessian(fn_log, x = eta_hat)),
                    silent = TRUE)
    info <- if (is.finite(info_try) && info_try > 0) info_try
            else if (!is.null(opt$hessian)) as.numeric(opt$hessian)
            else 1e-4
    if (!is.finite(info) || info <= 0) {
      used_fallback <- TRUE
      info <- 1e-4
    }
    list(
      eta_hat = eta_hat,
      ell_hat = NA_real_,
      info = info,
      info_min_eig = info,
      info_max_eig = info,
      cov = matrix(1 / pmax(info, 1e-8), 1L, 1L),
      objective = fn_log(eta_hat),
      optim_convergence = if (!is.null(opt$convergence)) as.integer(opt$convergence)[1] else NA_integer_,
      used_fallback = used_fallback
    )
  }

  prep_cov_2d <- function(cov_in, fallback_diag = c(1, 1)) {
    C <- as.matrix(cov_in)
    if (!all(dim(C) == c(2, 2)) || any(!is.finite(C))) {
      C <- diag(as.numeric(fallback_diag), 2L)
    }
    C <- (C + t(C)) / 2
    eig <- eigen(C, symmetric = TRUE)
    vals <- pmax(eig$values, 1e-8)
    eig$vectors %*% diag(vals, 2L, 2L) %*% t(eig$vectors)
  }
  chol_cov_2d <- function(cov_in) {
    C <- prep_cov_2d(cov_in)
    R <- tryCatch(chol(C), error = function(e) NULL)
    if (!is.null(R)) return(R)
    C <- C + 1e-8 * diag(2L)
    R <- tryCatch(chol(C), error = function(e) NULL)
    if (!is.null(R)) return(R)
    chol(diag(c(1e-3, 1e-3), 2L))
  }
  log_dmvnorm_chol2 <- function(x, mean, chol_cov) {
    x <- as.numeric(x); mean <- as.numeric(mean)
    if (length(x) != 2L || length(mean) != 2L || any(!is.finite(c(x, mean))) || any(!is.finite(chol_cov))) {
      return(-Inf)
    }
    z <- forwardsolve(t(chol_cov), x - mean)
    log_det <- sum(log(diag(chol_cov)))
    -log(2 * pi) - log_det - 0.5 * sum(z * z)
  }

  find_mode_eta_ell <- function(par0, xb, v, s_vec) {
    fn_log <- function(z) {
      val <- logpost_eta_ell(z, xb, v, s_vec)
      if (!is.finite(val)) -Inf else val
    }
    fn_neg <- function(z) {
      val <- fn_log(z)
      if (!is.finite(val)) 1e50 else -val
    }

    base <- as.numeric(par0)
    if (length(base) != 2L || any(!is.finite(base))) {
      base <- c(0, log(pmax(stats::sd(y), 1e-2)))
    }
    starts <- unique(rbind(
      base,
      base + c(-1, 0), base + c(1, 0),
      base + c(0, -0.5), base + c(0, 0.5),
      c(0, base[2]), c(base[1], 0), c(0, 0)
    ))
    vals <- apply(starts, 1L, fn_log)
    idx <- which(is.finite(vals))
    start <- if (length(idx)) starts[idx[which.max(vals[idx])], ] else c(0, 0)
    used_fallback <- FALSE

    opt <- try(
      optim(
        par = start, fn = fn_neg, method = "BFGS",
        control = list(maxit = 300), hessian = TRUE
      ),
      silent = TRUE
    )
    if (inherits(opt, "try-error") || is.null(opt$par) || any(!is.finite(opt$par)) || !is.finite(opt$value)) {
      used_fallback <- TRUE
      opt <- list(par = start, value = fn_neg(start), hessian = diag(c(1, 1), 2L), convergence = 1L)
    }
    z_hat <- as.numeric(opt$par)[1:2]
    info <- if (!is.null(opt$hessian)) as.matrix(opt$hessian) else matrix(NA_real_, 2L, 2L)
    if (any(!is.finite(info)) || !all(dim(info) == c(2, 2))) {
      info <- tryCatch(numDeriv::hessian(fn_neg, x = z_hat), error = function(e) matrix(NA_real_, 2L, 2L))
    }
    if (any(!is.finite(info)) || !all(dim(info) == c(2, 2))) {
      used_fallback <- TRUE
      info <- diag(c(1e-3, 1e-3), 2L)
    }
    info <- (info + t(info)) / 2
    eig <- eigen(info, symmetric = TRUE)
    eig_vals <- pmax(eig$values, 1e-8)
    cov_pd <- eig$vectors %*% diag(1 / eig_vals, 2L, 2L) %*% t(eig$vectors)
    list(
      eta_hat = z_hat[1],
      ell_hat = z_hat[2],
      info = min(eig_vals),
      info_min_eig = min(eig_vals),
      info_max_eig = max(eig_vals),
      cov = cov_pd,
      objective = fn_log(z_hat),
      optim_convergence = if (!is.null(opt$convergence)) as.integer(opt$convergence)[1] else NA_integer_,
      used_fallback = used_fallback
    )
  }
  sample_sigma_conditional <- function(k, chi, psi) {
    k <- as.numeric(k)[1]
    chi <- as.numeric(chi)[1]
    psi <- as.numeric(psi)[1]

    if (!is.finite(k) || !is.finite(chi) || chi <= 0 || !is.finite(psi) || psi < 0) {
      return(NA_real_)
    }

    if (psi <= 1e-12) {
      if (k >= 0) return(NA_real_)
      # GIG(k, chi, 0) with k < 0 reduces to inverse-gamma(shape=-k, rate=chi/2).
      return(1 / stats::rgamma(1L, shape = -k, rate = pmax(0.5 * chi, 1e-12)))
    }

    as.numeric(sample_gig_devroye_vector(
      1L, p = k, a = psi, b_vec = chi
    )[1, 1])
  }

  # initialize transformed nonconjugate block
  eta <- stats::qlogis((gamma - L) / (U - L))
  ell <- log(sigma)

  I <- n.burn + n.mcmc * thin
  proposal_scale <- NA_real_
  proposal_scale_init <- NA_real_
  proposal_cov <- matrix(NA_real_, 2L, 2L)
  proposal_cov_init <- matrix(NA_real_, 2L, 2L)
  proposal_chol <- NULL
  n.accept <- 0L
  n.accept.burn <- 0L
  n.accept.keep <- 0L
  n.global.accept <- 0L
  n.global.accept.burn <- 0L
  n.global.accept.keep <- 0L
  n.global.trial <- 0L
  n.global.trial.burn <- 0L
  n.global.trial.keep <- 0L
  n.approx_local_draw <- 0L
  n.trial.burn <- 0L
  n.trial.keep <- 0L
  window.accept <- 0L
  window.total <- 0L
  laplace_refresh_attempts <- 0L
  laplace_refresh_success <- 0L
  adapt.history <- data.frame(
    iter = integer(0),
    window_accept = numeric(0),
    proposal_sd = numeric(0),
    proposal_scale = numeric(0),
    cov11 = numeric(0),
    cov22 = numeric(0),
    cov12 = numeric(0),
    mode_info = numeric(0),
    mode_info_max = numeric(0),
    laplace_refreshed = logical(0),
    stringsAsFactors = FALSE
  )
  trace_rows <- if (trace.diagnostics) vector("list", ceiling(I / trace.every)) else NULL
  trace_idx <- 0L
  if (mh.proposal %in% c("rw", "laplace_rw")) {
    mode0 <- find_mode_eta_ell(c(eta, ell), xb, v, s)
    proposal_cov <- if (identical(mh.proposal, "laplace_rw")) {
      prep_cov_2d(mode0$cov, fallback_diag = c(1, 1))
    } else {
      diag(c(1, 1), 2L)
    }
    proposal_cov_init <- proposal_cov
    proposal_scale <- if (identical(mh.proposal, "laplace_rw")) {
      clamp_scale(1)
    } else {
      clamp_scale(0.5)
    }
    proposal_scale_init <- proposal_scale
    proposal_chol <- chol_cov_2d(proposal_cov * (proposal_scale^2))
  }

  ## --- main loop (burn + mcmc, prints like exdqlmMCMC) ---------------------
  .exdqlm_progress(
    "MCMC start",
    model = "Static exAL",
    n = n,
    p = p,
    burn = n.burn,
    keep = n.mcmc,
    thin = thin,
    kernel = mh.proposal,
    warm_start = if (isTRUE(init.from.vb)) "ldvb" else "none",
    .verbose = verbose
  )
  safe_progress_callback(list(
    event = "start",
    iter = 0L,
    total_iter = as.integer(I),
    phase = "burn",
    n_burn = as.integer(n.burn),
    n_mcmc = as.integer(n.mcmc),
    thin = as.integer(thin),
    kept_completed = 0L,
    kept_target = as.integer(n.mcmc),
    sigma = sigma,
    gamma = gamma,
    kernel = mh.proposal,
    accept = NA_real_,
    gamma_substeps = as.integer(gamma.substeps),
    p_global_eta_jump = p.global.eta.jump
  ))

  tictoc::tic()
  ksave <- 0L
  for (i in 1:I) {

    ## (1) v | rest ~ GIG(1/2, chi_i, psi)
    z     <- y - xb - lambda * sigma * s
    chi_i <- (z * z) / (B * sigma)
    psi_i <- (A * A) / (B * sigma) + (2 / sigma)
    gig_in <- validate_gig_inputs(chi_i, psi_i, i, "static_exal")
    v     <- as.numeric(sample_gig_devroye_vector(
      1L, p = 0.5, a = gig_in$psi, b_vec = gig_in$chi
    )[1, ])
    v <- pmax(v, 1e-12)

    ## (2) s | rest ~ N^+(mu, tau^2), truncated to (0, Inf)
    r     <- y - xb - A * v
    tau2  <- 1 / (1 + (lambda * lambda) * sigma / (B * v))
    tau2  <- pmax(tau2, 1e-12)
    mu_s  <- tau2 * (lambda * r) / (B * v)
    s     <- as.numeric(sample_truncnorm(1L, n, sts_mu = mu_s, sts_sig2 = tau2)[1, ])

    ## (3) beta | rest ~ N(m, V) with W = diag(1/(B sigma v))
    W_diag <- 1 / (B * sigma * v)
    Xw     <- X * sqrt(W_diag)
    prior_sys <- beta_prior_obj$beta_system_mcmc(beta_state)
    V_inv  <- crossprod(Xw) + prior_sys$Prec
    y_star <- y - lambda * sigma * s - A * v
    rhs    <- crossprod(X, W_diag * y_star) + prior_sys$h

    Uc    <- tryCatch(chol(V_inv), error = function(e) NULL)
    if (is.null(Uc)) Uc <- chol(V_inv + 1e-10 * diag(p))
    m_beta <- backsolve(Uc, forwardsolve(t(Uc), rhs))
    beta   <- as.numeric(m_beta + backsolve(Uc, stats::rnorm(p)))
    xb     <- drop(X %*% beta)
    beta_state <- beta_prior_obj$update_mcmc(beta_state, beta)

    ## (4) sigma update:
    ## for slice/laplace_local kernels keep exact conditional sigma update;
    ## for rw/laplace_rw update sigma jointly with gamma in transformed space.
    if (!(mh.proposal %in% c("rw", "laplace_rw"))) {
      r          <- y - xb - A * v
      chi_sigma  <- sum((r * r) / (B * v)) + 2 * sum(v) + 2 * b_sigma
      psi_sigma  <- (lambda * lambda / B) * sum((s * s) / v)
      k_sigma    <- -(a_sigma + 1.5 * n)
      sigma_new  <- sample_sigma_conditional(k = k_sigma, chi = chi_sigma, psi = psi_sigma)
      if (is.finite(sigma_new) && sigma_new > 0) sigma <- sigma_new
      ell <- log(sigma)
    }

    ## (5) nonconjugate update kernel
    mode_out <- list(
      eta_hat = NA_real_,
      ell_hat = NA_real_,
      info = NA_real_,
      info_min_eig = NA_real_,
      info_max_eig = NA_real_,
      cov = matrix(NA_real_, 2L, 2L),
      objective = NA_real_,
      optim_convergence = NA_integer_,
      used_fallback = NA
    )
    accepted <- NA
    proposal_sd_used <- NA_real_
    slice_evals <- NA_integer_
    global_jump_attempts_iter <- 0L
    global_jump_accepts_iter <- 0L
    local_kernel_steps_iter <- 0L
    global_kernel_steps_iter <- 0L
    adapted_this_iter <- FALSE

    for (g_step in seq_len(gamma.substeps)) {
      use_global_jump <- (p.global.eta.jump > 0) && (stats::runif(1) < p.global.eta.jump)

      if (isTRUE(use_global_jump)) {
        global_kernel_steps_iter <- global_kernel_steps_iter + 1L
        global_jump_attempts_iter <- global_jump_attempts_iter + 1L
        if (mh.proposal %in% c("rw", "laplace_rw")) {
          mode_out <- find_mode_eta_ell(c(eta, ell), xb, v, s)
          z_cur <- c(eta, ell)
          cur_lp <- logpost_eta_ell(z_cur, xb, v, s)
          if (!is.finite(cur_lp)) {
            z_cur <- c(mode_out$eta_hat, mode_out$ell_hat)
            cur_lp <- logpost_eta_ell(z_cur, xb, v, s)
          }
          jump_cov <- prep_cov_2d((global.eta.jump.scale^2) * mode_out$cov, fallback_diag = c(1, 1))
          jump_chol <- chol_cov_2d(jump_cov)
          z_mode <- c(mode_out$eta_hat, mode_out$ell_hat)
          z_prop <- z_mode + as.numeric(jump_chol %*% stats::rnorm(2))
          prop_lp <- logpost_eta_ell(z_prop, xb, v, s)
          log_q_cur <- log_dmvnorm_chol2(z_cur, mean = z_mode, chol_cov = jump_chol)
          log_q_prop <- log_dmvnorm_chol2(z_prop, mean = z_mode, chol_cov = jump_chol)
          accepted <- is.finite(prop_lp) &&
            (log(stats::runif(1)) < ((prop_lp + log_q_cur) - (cur_lp + log_q_prop)))
          if (isTRUE(accepted)) z_cur <- z_prop
          eta <- z_cur[1]
          ell <- z_cur[2]
          sigma <- sig_from_ell(ell)
          gamma <- g_from_eta(eta)
          proposal_sd_used <- sqrt(mean(diag(jump_cov)))
        } else {
          mode_out <- find_mode_eta(eta, xb, sigma, v, s)
          current_lp <- logpost_eta(eta, xb, sigma, v, s)
          if (!is.finite(current_lp)) {
            eta <- mode_out$eta_hat
            current_lp <- logpost_eta(eta, xb, sigma, v, s)
          }
          jump_sd <- clamp_scale(global.eta.jump.scale * sqrt(1 / pmax(mode_out$info, 1e-8)))
          eta_prop <- stats::rnorm(1, mean = mode_out$eta_hat, sd = jump_sd)
          prop_lp <- logpost_eta(eta_prop, xb, sigma, v, s)
          log_q_cur <- stats::dnorm(eta, mean = mode_out$eta_hat, sd = jump_sd, log = TRUE)
          log_q_prop <- stats::dnorm(eta_prop, mean = mode_out$eta_hat, sd = jump_sd, log = TRUE)
          accepted <- is.finite(prop_lp) &&
            (log(stats::runif(1)) < ((prop_lp + log_q_cur) - (current_lp + log_q_prop)))
          if (isTRUE(accepted)) eta <- eta_prop
          gamma <- g_from_eta(eta)
          proposal_sd_used <- jump_sd
        }

        n.global.trial <- n.global.trial + 1L
        n.global.accept <- n.global.accept + as.integer(isTRUE(accepted))
        if (i <= n.burn) {
          n.global.trial.burn <- n.global.trial.burn + 1L
          n.global.accept.burn <- n.global.accept.burn + as.integer(isTRUE(accepted))
        } else {
          n.global.trial.keep <- n.global.trial.keep + 1L
          n.global.accept.keep <- n.global.accept.keep + as.integer(isTRUE(accepted))
        }
        global_jump_accepts_iter <- global_jump_accepts_iter + as.integer(isTRUE(accepted))
      } else if (mh.proposal %in% c("slice", "slice_eta")) {
        local_kernel_steps_iter <- local_kernel_steps_iter + 1L
        if (identical(mh.proposal, "slice_eta")) {
          eta_lo <- eta.slice.bounds[1]
          eta_hi <- eta.slice.bounds[2]
          eta_w <- max(0.25, 4 * slice.width)
          if (!is.finite(eta) || eta <= eta_lo || eta >= eta_hi) {
            eta <- min(max(eta, eta_lo + 1e-8), eta_hi - 1e-8)
          }
          current_eta_lp <- logpost_eta(eta, xb, sigma, v, s)
          if (!is.finite(current_eta_lp)) {
            mode_out <- find_mode_eta(eta, xb, sigma, v, s)
            eta <- min(max(mode_out$eta_hat, eta_lo + 1e-8), eta_hi - 1e-8)
            current_eta_lp <- logpost_eta(eta, xb, sigma, v, s)
          }
          if (!is.finite(current_eta_lp)) {
            eta <- 0
          }
          slice_out <- .exdqlm_uni_slice_bounded(
            x0 = eta,
            log_density = function(e) logpost_eta(e, xb, sigma, v, s),
            w = eta_w,
            m = slice.max.steps,
            lower = eta_lo,
            upper = eta_hi
          )
          eta <- as.numeric(slice_out$value)[1]
          gamma <- g_from_eta(eta)
          slice_evals <- as.integer(slice_out$evals)
          proposal_sd_used <- eta_w
        } else {
          current_gamma_lp <- logpost_gamma(gamma, xb, sigma, v, s)
          if (!is.finite(current_gamma_lp)) {
            gamma <- min(max(gamma, L + 1e-8), U - 1e-8)
            current_gamma_lp <- logpost_gamma(gamma, xb, sigma, v, s)
          }
          if (!is.finite(current_gamma_lp)) {
            gamma <- min(max(0, L + 1e-8), U - 1e-8)
            current_gamma_lp <- logpost_gamma(gamma, xb, sigma, v, s)
          }
          slice_out <- .exdqlm_uni_slice_bounded(
            x0 = gamma,
            log_density = function(g) logpost_gamma(g, xb, sigma, v, s),
            w = slice.width,
            m = slice.max.steps,
            lower = L + 1e-10,
            upper = U - 1e-10
          )
          gamma <- as.numeric(slice_out$value)[1]
          eta <- stats::qlogis((gamma - L) / (U - L))
          slice_evals <- as.integer(slice_out$evals)
        }
      } else if (mh.proposal %in% c("rw", "laplace_rw")) {
        local_kernel_steps_iter <- local_kernel_steps_iter + 1L
        z_cur <- c(eta, ell)
        cur_lp <- logpost_eta_ell(z_cur, xb, v, s)
        if (!is.finite(cur_lp)) {
          mode_out <- find_mode_eta_ell(z_cur, xb, v, s)
          z_cur <- c(mode_out$eta_hat, mode_out$ell_hat)
          cur_lp <- logpost_eta_ell(z_cur, xb, v, s)
        }
        z_prop <- z_cur + as.numeric(proposal_chol %*% stats::rnorm(2))
        prop_lp <- logpost_eta_ell(z_prop, xb, v, s)
        accepted <- is.finite(prop_lp) && (log(stats::runif(1)) < (prop_lp - cur_lp))
        if (isTRUE(accepted)) z_cur <- z_prop
        eta <- z_cur[1]
        ell <- z_cur[2]
        sigma <- sig_from_ell(ell)
        gamma <- g_from_eta(eta)
        proposal_sd_used <- proposal_scale

        if (i <= n.burn) {
          n.trial.burn <- n.trial.burn + 1L
          n.accept.burn <- n.accept.burn + as.integer(isTRUE(accepted))
          window.accept <- window.accept + as.integer(isTRUE(accepted))
          window.total <- window.total + 1L
          if (
            mh.adapt && !adapted_this_iter &&
            i >= mh.min_burn_adapt && i < n.burn &&
            (i %% mh.adapt.interval == 0)
          ) {
            laplace_refreshed <- FALSE
            if (identical(mh.proposal, "laplace_rw") &&
                i >= mh_laplace_refresh_start &&
                (i %% mh_laplace_refresh_interval == 0)) {
              laplace_refresh_attempts <- laplace_refresh_attempts + 1L
              mode_refresh <- find_mode_eta_ell(c(eta, ell), xb, v, s)
              cov_refresh <- prep_cov_2d(mode_refresh$cov, fallback_diag = c(1, 1))
              if (all(is.finite(cov_refresh))) {
                proposal_cov <- prep_cov_2d((1 - mh_laplace_refresh_weight) * proposal_cov + mh_laplace_refresh_weight * cov_refresh)
                laplace_refresh_success <- laplace_refresh_success + 1L
                laplace_refreshed <- TRUE
              }
            }
            acc_win <- window.accept / pmax(window.total, 1L)
            if (acc_win < mh.target.accept[1]) {
              proposal_scale <- proposal_scale * (1 - mh_max_scale_step)
            } else if (acc_win > mh.target.accept[2]) {
              proposal_scale <- proposal_scale * (1 + mh_max_scale_step)
            }
            proposal_scale <- clamp_scale(proposal_scale)
            proposal_chol <- chol_cov_2d(proposal_cov * (proposal_scale^2))
            adapt.history <- rbind(
              adapt.history,
              data.frame(
                iter = i,
                window_accept = acc_win,
                proposal_sd = proposal_scale,
                proposal_scale = proposal_scale,
                cov11 = proposal_cov[1, 1],
                cov22 = proposal_cov[2, 2],
                cov12 = proposal_cov[1, 2],
                mode_info = mode_out$info_min_eig,
                mode_info_max = mode_out$info_max_eig,
                laplace_refreshed = isTRUE(laplace_refreshed),
                stringsAsFactors = FALSE
              )
            )
            window.accept <- 0L
            window.total <- 0L
            adapted_this_iter <- TRUE
          }
        } else {
          n.trial.keep <- n.trial.keep + 1L
          n.accept.keep <- n.accept.keep + as.integer(isTRUE(accepted))
        }
        n.accept <- n.accept + as.integer(isTRUE(accepted))
      } else {
        local_kernel_steps_iter <- local_kernel_steps_iter + 1L
        mode_out <- find_mode_eta(eta, xb, sigma, v, s)
        current_lp <- logpost_eta(eta, xb, sigma, v, s)
        if (!is.finite(current_lp)) {
          eta <- mode_out$eta_hat
          current_lp <- logpost_eta(eta, xb, sigma, v, s)
        }

        proposal_sd_used <- clamp_scale(sqrt(1 / pmax(mode_out$info, 1e-8)))

        if (identical(mh.proposal, "laplace_local")) {
          eta <- stats::rnorm(1, mean = mode_out$eta_hat, sd = proposal_sd_used)
          n.approx_local_draw <- n.approx_local_draw + 1L
        }
        gamma <- g_from_eta(eta)
        ell <- log(sigma)
      }
    }
    A <- A_of(gamma); B <- B_of(gamma); lambda <- lam_of(gamma)
    rhs_summary <- if (.static_is_rhs_family(beta_prior_obj$type)) beta_prior_obj$summary_mcmc(beta_state, beta = beta) else NULL
    if (trace.diagnostics && (i %% trace.every == 0L)) {
      s_stats <- .exdqlm_trace_summary(s)
      tau2_stats <- .exdqlm_trace_summary(tau2)
      trace_idx <- trace_idx + 1L
      trace_rows[[trace_idx]] <- data.frame(
        iter = i,
        phase = if (i <= n.burn) "burn" else "keep",
        eta = eta,
        ell = ell,
        gamma = gamma,
        sigma = sigma,
        mode_eta = mode_out$eta_hat,
        mode_ell = mode_out$ell_hat,
        mode_info = mode_out$info,
        mode_info_max = mode_out$info_max_eig,
        mode_objective = mode_out$objective,
        mode_optim_convergence = mode_out$optim_convergence,
        mode_used_fallback = isTRUE(mode_out$used_fallback),
        proposal_sd = proposal_sd_used,
        accepted = if ((mh.proposal %in% c("laplace_local", "slice", "slice_eta")) && global_jump_attempts_iter == 0L) NA else isTRUE(accepted),
        kernel = mh.proposal,
        gamma_substeps = as.integer(gamma.substeps),
        gamma_local_steps = as.integer(local_kernel_steps_iter),
        gamma_global_steps = as.integer(global_kernel_steps_iter),
        gamma_global_jump_attempts = as.integer(global_jump_attempts_iter),
        gamma_global_jump_accepts = as.integer(global_jump_accepts_iter),
        p_global_eta_jump = p.global.eta.jump,
        global_eta_jump_scale = global.eta.jump.scale,
        slice_evals = slice_evals,
        s_mean = s_stats[["mean"]],
        s_sd = s_stats[["sd"]],
        s_q05 = s_stats[["q05"]],
        s_q50 = s_stats[["median"]],
        s_q95 = s_stats[["q95"]],
        s_min = s_stats[["min"]],
        s_max = s_stats[["max"]],
        s_tau2_mean = tau2_stats[["mean"]],
        s_tau2_sd = tau2_stats[["sd"]],
        s_tau2_q05 = tau2_stats[["q05"]],
        s_tau2_q50 = tau2_stats[["median"]],
        s_tau2_q95 = tau2_stats[["q95"]],
        s_tau2_min = tau2_stats[["min"]],
        s_tau2_max = tau2_stats[["max"]],
        rhs_tau = if (!is.null(rhs_summary)) rhs_summary$tau else NA_real_,
        rhs_log_tau = if (!is.null(rhs_summary)) rhs_summary$log_tau else NA_real_,
        rhs_c2 = if (!is.null(rhs_summary)) rhs_summary$c2 else NA_real_,
        rhs_lambda_mean = if (!is.null(rhs_summary)) rhs_summary$lambda_mean else NA_real_,
        rhs_lambda_min = if (!is.null(rhs_summary)) rhs_summary$lambda_min else NA_real_,
        rhs_lambda_max = if (!is.null(rhs_summary)) rhs_summary$lambda_max else NA_real_,
        rhs_e_invv_med = if (!is.null(rhs_summary)) rhs_summary$collapse_E_invV_med else NA_real_,
        rhs_beta_l2 = if (!is.null(rhs_summary)) rhs_summary$collapse_beta_l2 else NA_real_,
        rhs_small_beta_frac = if (!is.null(rhs_summary)) rhs_summary$collapse_small_beta_frac else NA_real_,
        rhs_collapse_flag = if (!is.null(rhs_summary)) isTRUE(rhs_summary$collapse_flag) else NA,
        stringsAsFactors = FALSE
      )
    }

    ## save after burn every 'thin' iterations
    if (i > n.burn && ((i - n.burn) %% thin == 0)) {
      ksave <- ksave + 1L
      save.beta[ksave, ] <- beta
      save.sigma[ksave]  <- sigma
      save.gamma[ksave]  <- gamma
      save.v[, ksave]    <- v
      save.s[, ksave]    <- s
      if (.static_is_rhs_family(beta_prior_obj$type)) {
        lam_draw <- rep(NA_real_, p)
        lam_draw[rhs_active_idx] <- beta_state$lambda[rhs_active_idx]
        save.lambda[ksave, ] <- lam_draw
        save.tau[ksave] <- beta_state$tau
        save.c2[ksave] <- beta_state$c2
      }
    }

    if (i %% progress_every == 0L) {
      accept_now <- if (mh.proposal %in% c("laplace_local", "slice", "slice_eta")) {
        NA_real_
      } else {
        n.accept / pmax(n.trial.burn + n.trial.keep, 1L)
      }
      .exdqlm_progress(
        "MCMC progress",
        model = "Static exAL",
        phase = if (i <= n.burn) "burn" else "keep",
        iter = sprintf("%d/%d", i, I),
        sigma = sigma,
        gamma = gamma,
        kernel = mh.proposal,
        accept = accept_now,
        kept = sprintf("%d/%d", ksave, n.mcmc),
        .verbose = verbose
      )
      safe_progress_callback(list(
        event = "progress",
        iter = as.integer(i),
        total_iter = as.integer(I),
        phase = if (i <= n.burn) "burn" else "keep",
        n_burn = as.integer(n.burn),
        n_mcmc = as.integer(n.mcmc),
        thin = as.integer(thin),
        kept_completed = as.integer(ksave),
        kept_target = as.integer(n.mcmc),
        sigma = sigma,
        gamma = gamma,
        kernel = mh.proposal,
        accept = accept_now,
        gamma_substeps = as.integer(gamma.substeps),
        p_global_eta_jump = p.global.eta.jump,
        global_jump_attempts_iter = as.integer(global_jump_attempts_iter),
        global_jump_accepts_iter = as.integer(global_jump_accepts_iter)
      ))
    }
  }
  run.time <- tictoc::toc(quiet = TRUE)
  .exdqlm_progress(
    "MCMC done",
    model = "Static exAL",
    status = "complete",
    iter = I,
    runtime_sec = run.time$toc - run.time$tic,
    sigma = sigma,
    gamma = gamma,
    kernel = mh.proposal,
    accept = if (mh.proposal %in% c("laplace_local", "slice", "slice_eta")) NULL else n.accept / pmax(n.trial.burn + n.trial.keep, 1L),
    .verbose = verbose
  )
  safe_progress_callback(list(
    event = "complete",
    iter = as.integer(I),
    total_iter = as.integer(I),
    phase = "done",
    n_burn = as.integer(n.burn),
    n_mcmc = as.integer(n.mcmc),
    thin = as.integer(thin),
    kept_completed = as.integer(ksave),
    kept_target = as.integer(n.mcmc),
    sigma = sigma,
    gamma = gamma,
    kernel = mh.proposal,
    accept = if (mh.proposal %in% c("laplace_local", "slice", "slice_eta")) NA_real_ else n.accept / pmax(n.trial.burn + n.trial.keep, 1L),
    gamma_substeps = as.integer(gamma.substeps),
    p_global_eta_jump = p.global.eta.jump,
    global_jump_attempts = as.integer(n.global.trial),
    global_jump_accepts = as.integer(n.global.accept),
    runtime_sec = as.numeric(run.time$toc - run.time$tic)
  ))

  accept_total <- if (mh.proposal %in% c("laplace_local", "slice", "slice_eta")) NA_real_ else n.accept / pmax(n.trial.burn + n.trial.keep, 1L)
  accept_burn <- if (mh.proposal %in% c("laplace_local", "slice", "slice_eta")) NA_real_ else if (n.trial.burn > 0) n.accept.burn / n.trial.burn else NA_real_
  accept_keep <- if (mh.proposal %in% c("laplace_local", "slice", "slice_eta")) NA_real_ else if (n.trial.keep > 0) n.accept.keep / n.trial.keep else NA_real_
  global_accept_total <- if (n.global.trial > 0L) n.global.accept / n.global.trial else NA_real_
  global_accept_burn <- if (n.global.trial.burn > 0L) n.global.accept.burn / n.global.trial.burn else NA_real_
  global_accept_keep <- if (n.global.trial.keep > 0L) n.global.accept.keep / n.global.trial.keep else NA_real_
  ess_sigma <- tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.sigma))), error = function(e) NA_real_)
  ess_gamma <- tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.gamma))), error = function(e) NA_real_)
  chain_health_sigma <- .exdqlm_chain_health_metrics(save.sigma, n_keep = n.mcmc)
  chain_health_gamma <- .exdqlm_chain_health_metrics(save.gamma, n_keep = n.mcmc)
  kernel_exact <- (n.approx_local_draw == 0L)
  mh_diag <- list(
    proposal = mh.proposal,
    adapt = if (mh.proposal %in% c("laplace_local", "slice", "slice_eta")) FALSE else mh.adapt,
    adapt_interval = if (mh.proposal %in% c("laplace_local", "slice", "slice_eta")) NA_integer_ else mh.adapt.interval,
    target_accept = if (mh.proposal %in% c("laplace_local", "slice", "slice_eta")) c(NA_real_, NA_real_) else mh.target.accept,
    scale_bounds = if (mh.proposal %in% c("laplace_local", "slice", "slice_eta")) c(NA_real_, NA_real_) else mh.scale.bounds,
    scale_initial = if (mh.proposal %in% c("laplace_local", "slice", "slice_eta")) NA_real_ else proposal_scale_init,
    scale_final = if (mh.proposal %in% c("laplace_local", "slice", "slice_eta")) NA_real_ else proposal_scale,
    joint_sigma_gamma = mh.proposal %in% c("rw", "laplace_rw"),
    transformed_state = if (mh.proposal %in% c("rw", "laplace_rw")) c("eta", "ell") else c("eta"),
    proposal_cov_initial = if (mh.proposal %in% c("rw", "laplace_rw")) proposal_cov_init else matrix(NA_real_, 2L, 2L),
    proposal_cov_final = if (mh.proposal %in% c("rw", "laplace_rw")) proposal_cov else matrix(NA_real_, 2L, 2L),
    slice_width = if (mh.proposal %in% c("slice", "slice_eta")) slice.width else NA_real_,
    slice_max_steps = if (mh.proposal %in% c("slice", "slice_eta")) slice.max.steps else NA_real_,
    slice_space = if (identical(mh.proposal, "slice")) "gamma" else if (identical(mh.proposal, "slice_eta")) "eta" else NA_character_,
    gamma_substeps = as.integer(gamma.substeps),
    global_eta_jump = list(
      enabled = p.global.eta.jump > 0,
      p = p.global.eta.jump,
      scale = global.eta.jump.scale,
      attempts = list(total = as.integer(n.global.trial), burn = as.integer(n.global.trial.burn), keep = as.integer(n.global.trial.keep)),
      accepts = list(total = as.integer(n.global.accept), burn = as.integer(n.global.accept.burn), keep = as.integer(n.global.accept.keep)),
      accept = list(total = global_accept_total, burn = global_accept_burn, keep = global_accept_keep)
    ),
    laplace_refresh = list(
      enabled = identical(mh.proposal, "laplace_rw"),
      interval = if (identical(mh.proposal, "laplace_rw")) as.integer(mh_laplace_refresh_interval) else NA_integer_,
      start = if (identical(mh.proposal, "laplace_rw")) as.integer(mh_laplace_refresh_start) else NA_integer_,
      weight = if (identical(mh.proposal, "laplace_rw")) as.numeric(mh_laplace_refresh_weight) else NA_real_,
      attempts = if (identical(mh.proposal, "laplace_rw")) as.integer(laplace_refresh_attempts) else NA_integer_,
      success = if (identical(mh.proposal, "laplace_rw")) as.integer(laplace_refresh_success) else NA_integer_
    ),
    approx_local_draws = as.integer(n.approx_local_draw),
    kernel_exact = kernel_exact,
    signoff_ready = kernel_exact,
    approximation_note = if (kernel_exact) {
      NA_character_
    } else {
      sprintf(
        "gamma used %d laplace_local approximation draw(s) without MH correction",
        as.integer(n.approx_local_draw)
      )
    },
    accept = list(total = accept_total, burn = accept_burn, keep = accept_keep),
    adaptation = adapt.history,
    trace_enabled = trace.diagnostics,
    trace_every = if (trace.diagnostics) trace.every else NA_integer_,
    trace = if (trace.diagnostics && trace_idx > 0L) {
      do.call(rbind, trace_rows[seq_len(trace_idx)])
    } else {
      data.frame()
    }
  )

  ## --- return (match exdqlmMCMC style) -------------------------------------
  ret <- list(
    run.time   = (run.time$toc - run.time$tic),
    y          = y,
    X          = X,
    p0         = p0,
    dqlm.ind   = FALSE,
    bounds     = c(L = L, U = U),
    samp.beta  = coda::as.mcmc(save.beta),
    samp.sigma = coda::as.mcmc(save.sigma),
    samp.gamma = coda::as.mcmc(save.gamma),
    samp.lambda = if (.static_is_rhs_family(beta_prior_obj$type)) coda::as.mcmc(save.lambda) else NULL,
    samp.tau = if (.static_is_rhs_family(beta_prior_obj$type)) coda::as.mcmc(save.tau) else NULL,
    samp.c2 = if (.static_is_rhs_family(beta_prior_obj$type)) coda::as.mcmc(save.c2) else NULL,
    samp.v     = coda::as.mcmc(t(save.v)),
    samp.s     = coda::as.mcmc(t(save.s)),
    accept.rate = accept_total,
    accept.rate.burn = accept_burn,
    accept.rate.keep = accept_keep,
    mh.diagnostics = mh_diag,
    beta_prior = list(
      type = beta_prior_obj$type,
      controls = beta_prior_obj$controls,
      summary = beta_prior_obj$summary_mcmc(beta_state, beta = beta),
      state = if (.static_is_rhs_family(beta_prior_obj$type)) beta_state else NULL
    ),
    rhs.diagnostics = if (.static_is_rhs_family(beta_prior_obj$type)) {
      list(
        preflight = rhs_preflight,
        summary = beta_prior_obj$summary_mcmc(beta_state, beta = beta),
        ess = list(
          tau = tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.tau))), error = function(e) NA_real_),
          c2 = tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.c2))), error = function(e) NA_real_),
          lambda = tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.lambda))), error = function(e) rep(NA_real_, p))
        )
      )
    } else NULL,
    diagnostics = list(
      mh = mh_diag,
      ess = list(sigma = ess_sigma, gamma = ess_gamma),
      chain_health = list(
        sigma = chain_health_sigma,
        gamma = chain_health_gamma
      ),
      acceptance = list(total = accept_total, burn = accept_burn, keep = accept_keep),
      rhat_ready = list(sigma = as.numeric(save.sigma), gamma = as.numeric(save.gamma)),
      rhs = if (.static_is_rhs_family(beta_prior_obj$type)) {
        list(
          tau = as.numeric(save.tau),
          c2 = as.numeric(save.c2),
          lambda = save.lambda
        )
      } else NULL
    ),
    init.from.vb = isTRUE(init.from.vb),
    vb.init.controls = if (isTRUE(init.from.vb)) vb.ctrl else NULL,
    n.burn = n.burn,
    n.mcmc = n.mcmc,
    last = list(beta = beta, sigma = sigma, gamma = gamma, v = v, s = s)
  )
  class(ret) <- c("exal_mcmc", "exal_static_mcmc")
  if (.static_is_rhs_family(beta_prior_obj$type)) {
    .static_rhs_maybe_warn_collapse(ret$beta_prior$summary, beta_prior_obj$controls)
  }
  ret
}
