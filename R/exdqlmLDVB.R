#' exDQLM - LDVB algorithm (Laplace-Delta)
#'
#' The function applies a Laplace-Delta Variational Bayes (LDVB) algorithm to
#' estimate the posterior of an exDQLM.
#'
#' @param y A univariate time-series.
#' @param p0 The quantile of interest, a value between 0 and 1.
#' @param model List of the state-space model including `GG`, `FF`, prior parameters `m0` and `C0`.
#' @param df Discount factors for each block.
#' @param dim.df Dimension of each block of discount factors.
#' @param fix.gamma Logical value indicating whether to fix gamma at `gam.init`. Default is `FALSE`.
#' @param gam.init Initial value for gamma (skewness parameter), or value at which gamma will be fixed if `fix.gamma=TRUE`.
#' @param fix.sigma Logical value indicating whether to fix sigma at `sig.init`. Default is `TRUE`.
#' @param sig.init Initial value for sigma (scale parameter), or value at which sigma will be fixed if `fix.sigma=TRUE`.
#' @param dqlm.ind Logical value indicating whether to fix gamma at `0`, reducing the exDQLM to the special case of the DQLM. Default is `FALSE`.
#' @param exps0 Initial value for dynamic quantile. If `exps0` is not specified, it is set to the DLM estimate of the `p0` quantile.
#' @param tol Tolerance for convergence of dynamic quantile estimates. Default is `tol=0.1`.
#' @param n.samp Number of samples to draw from the approximated posterior distribution. Default is `n.samp=200`.
#' @param PriorSigma List of parameters for inverse gamma prior on sigma; shape `a_sig` and scale `b_sig`. Default is an inverse gamma with mean 1 (or `sig.init` if provided) and variance 10.
#' @param PriorGamma List of parameters for truncated student-t prior on gamma; center `m_gam`, scale `s_gam` and degrees of freedom `df_gam`. Default is a standard student-t with 1 degree of freedom, truncated to the support of gamma.
#' @param verbose Logical value indicating whether progress should be displayed.
#' @param debug_shapes Logical; if TRUE, print KF input/output shapes every `debug_every` iterations.
#' @param debug_every  Integer; frequency (in iterations) for shape prints when `debug_shapes=TRUE`.
#'
#' @return A object of class "\code{exdqlmLDVB}" containing the following:
#' \itemize{
#'   \item `y` - Time-series data used to fit the model.
#'   \item `run.time` - Algorithm run time in seconds.
#'   \item `iter` - Number of iterations until convergence was reached.
#'   \item `dqlm.ind` - Logical value indicating whether gamma was fixed at `0`, reducing the exDQLM to the special case of the DQLM.
#'   \item `model` - List of the state-space model including `GG`, `FF`, prior parameters `m0` and `C0`.
#'   \item `p0` - The quantile which was estimated.
#'   \item `df` - Discount factors used for each block.
#'   \item `dim.df` - Dimension used for each block of discount factors.
#'   \item `sig.init` - Initial value for sigma, or value at which sigma was fixed if `fix.sigma=TRUE`.
#'   \item `seq.sigma` - Sequence of sigma estimated by the algorithm until convergence.
#'   \item `samp.theta` - Posterior sample of the state vector variational distribution.
#'   \item `samp.post.pred` - Sample of the posterior predictive distributions.
#'   \item `map.standard.forecast.errors` - MAP standardized one-step-ahead forecast errors.
#'   \item `samp.sigma` - Posterior sample of scale parameter sigma variational distribution.
#'   \item `samp.vts` - Posterior sample of latent parameters, v_t, variational distributions.
#'   \item `theta.out` - List containing the variational distribution of the state vector including filtered distribution parameters (`fm` and `fC`) and smoothed distribution parameters (`sm` and `sC`).
#'   \item `vts.out` - List containing the variational distributions of latent parameters v_t.
#'   \item `fix.sigma` Logical value indicating whether sigma was fixed at `sig.init`.
#'   \item `diagnostics` - List containing ELBO trace and convergence diagnostics
#'   (joint stopping status, deltas for state/sigma/gamma/ELBO, and criteria used).
#' }
#' If `dqlm.ind=FALSE`, the list also contains:
#' \itemize{
#'   \item `gam.init` - Initial value for gamma, or value at which gamma was fixed if `fix.gamma=TRUE`.
#'   \item `seq.gamma` - Sequence of gamma estimated by the algorithm until convergence.
#'   \item `samp.gamma` - Posterior sample of skewness parameter gamma variational distribution.
#'   \item `samp.sts` - Posterior sample of latent parameters, s_t, variational distributions.
#'   \item `gammasig.out` - List containing the LD (Laplace-Delta) approximation for the
#'   variational distribution of `sigma` and `gamma` (means, transformed Hessian, and ELBO components).
#'   \item `sts.out` - List containing the variational distributions of latent parameters s_t.
#'   \item `fix.gamma` Logical value indicating whether gamma was fixed at `gam.init`.

#' }
#' Or if `dqlm.ind=TRUE`, the list also contains:
#' \itemize{
#'   \item `sig.out` - As above but for the DQLM case (`gamma = 0`), the LD approximation for `sigma`.
#' }
#' @export
#'
#' @importFrom stats median
#' @importFrom nimble dinvgamma
#' @importFrom stats optim
#'
#' @details
#' Advanced options (set via \code{options()}):
#' \itemize{
#'   \item \code{exdqlm.use_cpp_kf}: use the C++ Kalman filter bridge (default TRUE).
#'   \item \code{exdqlm.compute_elbo}: compute ELBO every iteration (default TRUE).
#'   \item \code{exdqlm.tol_elbo}: ELBO convergence tolerance (default 1e-6).
#'   \item \code{exdqlm.tol_sigma}: sigma-delta convergence tolerance (default: `tol`).
#'   \item \code{exdqlm.tol_gamma}: gamma-delta convergence tolerance (default: `tol`).
#'   \item \code{exdqlm.vb.min_iter}: minimum iterations before convergence can trigger (default 10).
#'   \item \code{exdqlm.vb.patience}: number of consecutive joint-converged iterations required (default 3).
#'   \item \code{exdqlm.use_cpp_samplers}: use C++ samplers for s_t, u_t, theta (default FALSE).
#'         When FALSE, R fallbacks (truncnorm, GH::rgig, SVD sampling) are used.
#'   \item \code{exdqlm.use_cpp_postpred}: use C++ posterior predictive sampler (default FALSE).
#' }
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' y = scIVTmag[1:100]
#' trend.comp = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' seas.comp = seasMod(365, c(1,2), C0 = 10*diag(4))
#' model = trend.comp + seas.comp
#' M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(1,1), dim.df = c(1,4),
#'                  gam.init = -3.5, sig.init = 15, tol = 0.05)
#'
#' M0_al = exdqlmLDVB(y, p0 = 0.85, model, df = c(1,1), dim.df = c(1,4),
#'                    dqlm.ind = TRUE, sig.init = 15, tol = 0.05)
#' }
#'
exdqlmLDVB <- function(y, p0, model, df, dim.df,
                       fix.gamma = FALSE, gam.init = NA,
                       fix.sigma = TRUE, sig.init = NA,
                       dqlm.ind = FALSE,
                       exps0,
                       tol = 0.1,
                       n.samp = 200,
                       PriorSigma = NULL,
                       PriorGamma = NULL,
                       verbose = TRUE,
                       debug_shapes = FALSE,    
                       debug_every = 5) {       

  # check inputs
  y = check_ts(y)
  model = check_mod(model)
  rv = check_logics(gam.init,sig.init,fix.gamma,fix.sigma,dqlm.ind)
  gam.init = rv$gam.init
  dqlm.ind = rv$dqlm.ind
  fix.gamma = rv$fix.gamma

  ### Define L and U
  bounds = .gamma_bounds(p0)
  L = bounds["L"]; U = bounds["U"]
  if(!is.na(gam.init)){
    if(gam.init < L | gam.init > U){
      stop(sprintf("gam.init must be between %s and %s for %s quantile",round(L,3),round(U,3),p0))
    }
  }

  ### sigma and gamma priors
  # sigma ~ IG(a_sig,b_sig)
  if(is.null(PriorSigma)){
    m_sigma = 1
    v_sigma = 10
    PriorSigma$a_sig = (m_sigma^2)/(v_sigma) + 2
    PriorSigma$b_sig = (m_sigma^3)/(v_sigma) + m_sigma
  }else{
    if(!is.list(PriorSigma) | any( is.na( match(c("a_sig", "b_sig"),names(PriorSigma)) ) )){
      stop("`PriorSigma` must be a list containing `a_sig` and `b_sig`")
      }
  }
  # gamma ~ truncated student t on L,U
  PriorGamma <- .normalize_gamma_prior_trunc_t(PriorGamma)

  ### state-space model
  ## prior, theta ~ N(m0,C0)
  m0 = model$m0
  C0 = model$C0
  #
  TT = length(y)
  p = length(m0)
  if(!is.na(dim(model$GG)[3])){
    if(dim(model$GG)[3] != TT){stop("time-varying dimension of GG does not match length of y")}
  }
  GG = array(model$GG,c(p,p,TT)); model$GG = GG
  if(ncol(model$FF)>1){
    if(ncol(model$FF) != TT){stop("time-varying dimension of FF does not match length of y")}
  }
  FF = matrix(model$FF,p,TT); model$FF = FF
  ## discount factor blocking
  if(!methods::hasArg(dim.df)){
    if(length(df)!=1){
      stop("length of component discount factors does not match length of component dimensions")
    }
    dim.df = p
  }
  df.mat = make_df_mat(df,dim.df,p)
  max_iter <- suppressWarnings(as.integer(getOption("exdqlm.max_iter", 200L)))
  if (!is.finite(max_iter) || max_iter < 1L) max_iter <- 200L

  # Reduced AL branch (DQLM): conjugate CAVI without gamma/s_t blocks.
  # In the reduced model, there is no LD step for (sigma, gamma).
  if (isTRUE(dqlm.ind)) {
    exps0_user <- if (methods::hasArg(exps0)) exps0 else NULL
    retlist <- .run_dynamic_dqlm_cavi(
      y = as.numeric(y),
      p0 = p0,
      model = model,
      df = df,
      dim.df = dim.df,
      fix.sigma = fix.sigma,
      sig.init = sig.init,
      tol = tol,
      n.samp = n.samp,
      PriorSigma = PriorSigma,
      verbose = verbose,
      exps0 = exps0_user,
      max_iter = max_iter
    )
    class(retlist) <- "exdqlm"
    return(retlist)
  }

  ld_ctrl <- .exal_static_ld_controls(list(
    optimizer_method = getOption("exdqlm.dynamic.ldvb.optimizer_method", getOption("exdqlm.static.ldvb.optimizer_method", "lbfgsb")),
    direct_commit = getOption("exdqlm.dynamic.ldvb.direct_commit", getOption("exdqlm.static.ldvb.direct_commit", NULL)),
    damping = getOption("exdqlm.dynamic.ldvb.damping", getOption("exdqlm.static.ldvb.damping", NULL)),
    xi_damping = getOption("exdqlm.dynamic.ldvb.xi_damping", getOption("exdqlm.static.ldvb.xi_damping", NULL)),
    auto_stabilize = getOption("exdqlm.dynamic.ldvb.auto_stabilize", getOption("exdqlm.static.ldvb.auto_stabilize", TRUE)),
    cycle_window = getOption("exdqlm.dynamic.ldvb.cycle_window", getOption("exdqlm.static.ldvb.cycle_window", 12L)),
    cycle_lag1_max = getOption("exdqlm.dynamic.ldvb.cycle_lag1_max", getOption("exdqlm.static.ldvb.cycle_lag1_max", -0.4)),
    cycle_lag2_min = getOption("exdqlm.dynamic.ldvb.cycle_lag2_min", getOption("exdqlm.static.ldvb.cycle_lag2_min", 0.8)),
    cycle_gamma_min_amp = getOption("exdqlm.dynamic.ldvb.cycle_gamma_min_amp", getOption("exdqlm.static.ldvb.cycle_gamma_min_amp", 0.05)),
    cycle_sigma_min_amp = getOption("exdqlm.dynamic.ldvb.cycle_sigma_min_amp", getOption("exdqlm.static.ldvb.cycle_sigma_min_amp", 0.05)),
    cycle_s_min_amp = getOption("exdqlm.dynamic.ldvb.cycle_s_min_amp", getOption("exdqlm.static.ldvb.cycle_s_min_amp", 1e-3)),
    cycle_tau2_min_amp = getOption("exdqlm.dynamic.ldvb.cycle_tau2_min_amp", getOption("exdqlm.static.ldvb.cycle_tau2_min_amp", 1e-4)),
    stabilize_damping = getOption("exdqlm.dynamic.ldvb.stabilize_damping", getOption("exdqlm.static.ldvb.stabilize_damping", NULL)),
    stabilize_xi_damping = getOption("exdqlm.dynamic.ldvb.stabilize_xi_damping", getOption("exdqlm.static.ldvb.stabilize_xi_damping", NULL)),
    reject_bad_mode_commit = getOption("exdqlm.dynamic.ldvb.reject_bad_mode_commit", getOption("exdqlm.static.ldvb.reject_bad_mode_commit", TRUE)),
    optimizer_maxit = getOption("exdqlm.dynamic.ldvb.optimizer_maxit", getOption("exdqlm.static.ldvb.optimizer_maxit", NULL)),
    eig_floor = getOption("exdqlm.dynamic.ldvb.eig_floor", getOption("exdqlm.static.ldvb.eig_floor", 1e-6)),
    eig_cap = getOption("exdqlm.dynamic.ldvb.eig_cap", getOption("exdqlm.static.ldvb.eig_cap", NULL)),
    step_cap_eta = getOption("exdqlm.dynamic.ldvb.step_cap_eta", getOption("exdqlm.static.ldvb.step_cap_eta", NULL)),
    step_cap_ell = getOption("exdqlm.dynamic.ldvb.step_cap_ell", getOption("exdqlm.static.ldvb.step_cap_ell", NULL)),
    eta_lo = getOption("exdqlm.dynamic.ldvb.eta_lo", getOption("exdqlm.static.ldvb.eta_lo", -12)),
    eta_hi = getOption("exdqlm.dynamic.ldvb.eta_hi", getOption("exdqlm.static.ldvb.eta_hi", 12)),
    sigma_bounds = getOption("exdqlm.dynamic.ldvb.sigma_bounds", getOption("exdqlm.static.ldvb.sigma_bounds", NULL)),
    sigma_init_mode = getOption("exdqlm.dynamic.ldvb.sigma_init_mode", getOption("exdqlm.static.ldvb.sigma_init_mode", "data_scale")),
    sigma_floor_abs = getOption("exdqlm.dynamic.ldvb.sigma_floor_abs", getOption("exdqlm.static.ldvb.sigma_floor_abs", 1e-6)),
    sigma_min_mult = getOption("exdqlm.dynamic.ldvb.sigma_min_mult", getOption("exdqlm.static.ldvb.sigma_min_mult", 1e-3)),
    sigma_max_mult = getOption("exdqlm.dynamic.ldvb.sigma_max_mult", getOption("exdqlm.static.ldvb.sigma_max_mult", 1e3)),
    sigma_bound_ratio_min = getOption("exdqlm.dynamic.ldvb.sigma_bound_ratio_min", getOption("exdqlm.static.ldvb.sigma_bound_ratio_min", 10)),
    gamma_init_pad_frac = getOption("exdqlm.dynamic.ldvb.gamma_init_pad_frac", getOption("exdqlm.static.ldvb.gamma_init_pad_frac", 0.05)),
    logit_eps = getOption("exdqlm.dynamic.ldvb.logit_eps", getOption("exdqlm.static.ldvb.logit_eps", 1e-8)),
    init_cov_diag = getOption("exdqlm.dynamic.ldvb.init_cov_diag", getOption("exdqlm.static.ldvb.init_cov_diag", c(1e-2, 1e-2))),
    reuse_seed = getOption("exdqlm.dynamic.ldvb.reuse_seed", getOption("exdqlm.static.ldvb.reuse_seed", NA_integer_)),
    mode_grad_tol = getOption("exdqlm.dynamic.ldvb.mode_grad_tol", getOption("exdqlm.static.ldvb.mode_grad_tol", 5e-3)),
    mode_min_eig = getOption("exdqlm.dynamic.ldvb.mode_min_eig", getOption("exdqlm.static.ldvb.mode_min_eig", 1e-8)),
    store_trace = getOption("exdqlm.dynamic.ldvb.store_trace", TRUE)
  ))

  ### Initialize VB
  init_ld <- list(
    gamma = ifelse(!is.na(gam.init), gam.init, (L + U) / 2),
    sigma = ifelse(!is.na(sig.init), sig.init, 1)
  )
  ld_setup <- .exal_static_ld_scale_setup(y = y, L = L, U = U, init = init_ld, ld_ctrl = ld_ctrl)
  gam0 <- ld_setup$gamma0
  sig0 <- ld_setup$sigma0
  eta_hat <- ld_setup$eta0
  ell_hat <- ld_setup$ell0
  Sig_eta_ell <- .exal_static_ld_regularize_cov(diag(ld_ctrl$init_cov_diag, 2L), eig_floor = ld_ctrl$eig_floor, eig_cap = ld_ctrl$eig_cap)$Sigma
  new.gamsig.out = list(E.gam=gam0,V.gam=10,
                        E.sigma=ifelse(!is.na(sig0),sig0,m_sigma),V.sig=10,
                        E.inv.sigma=ifelse(!is.na(sig0),1/sig0,1/m_sigma),
                        E.c2.invb.absgam2.sigma = sig0*(C.fn(p0,gam0)^2)*(abs(gam0)^2)/B.fn(p0,gam0),
                        E.c.invb.absgam = C.fn(p0,gam0)*abs(gam0)/B.fn(p0,gam0),
                        E.c.a.invb.absgam = C.fn(p0,gam0)*A.fn(p0,gam0)*abs(gam0)/B.fn(p0,gam0),
                        E.a2.invb.inv.sigma = (A.fn(p0,gam0)^2)/(B.fn(p0,gam0)*sig0),
                        E.invb.inv.sigma = 1/(sig0*B.fn(p0,gam0)),
                        E.a.invb.inv.sigma = A.fn(p0,gam0)/(B.fn(p0,gam0)*sig0),
                        E.log.inv.sigma = -log(sig0))
  s0_mom <- .exdqlm_pos_truncnorm_moments(rep(0, TT), rep(1, TT))
  new.sts.out = list(
    E.sts = s0_mom$mean,
    E.sts2 = s0_mom$second,
    sts.mu = rep(0, TT),
    sts.sig2 = rep(1, TT),
    entropy = sum(0.5 * log(2 * pi * rep(1, TT)) + log(pmax(s0_mom$Phi, 1e-12)) + 0.5 * (1 + (-0) * s0_mom$Lambda))
  )
  new.uts.out = list(E.uts=rep(1/sig0,TT),
                     E.inv.uts=rep(sig0,TT))
  if(methods::hasArg(exps0)){
    if(length(exps0) != TT){ stop("exps0 must have same length as y") }
  }else{
    init.dlm = dlm_df(y,model,df,dim.df,s.priors=list(l0=1,S0=sig0),just.lik=FALSE)
    exps0 = apply(FF*t(init.dlm$m),2,sum) + stats::qnorm(p0,0,sqrt(init.dlm$s[TT]))
  }
  new.theta.out = list(exps=exps0,exps2=exps0^2)

  ### initialize convergence evaluations
  iter = 0
  stable.count = 0L
  seq.gamma = new.gamsig.out$E.gam
  seq.sigma = new.gamsig.out$E.sigma
  delta.state = numeric(0)
  delta.sigma = numeric(0)
  delta.gamma = numeric(0)
  delta.s = numeric(0)
  delta.elbo = numeric(0)
  compute.elbo <- isTRUE(getOption("exdqlm.compute_elbo", TRUE))
  conv.ctrl <- .vb_joint_controls(tol_state = tol, has_gamma = TRUE)
  stop.reason <- "max_iter"
  ld_trace_rows <- vector("list", max_iter)
  s_trace_rows <- vector("list", max_iter)
  gamma_hist <- numeric(0)
  sigma_hist <- numeric(0)
  s_mean_hist <- numeric(0)
  tau2_mean_hist <- numeric(0)
  stabilize_active <- FALSE
  stabilize_since_iter <- NA_integer_
  stabilize_reason_active <- NA_character_
  stabilize_xi_method_active <- "delta"

  # function update q(st)  (trunc-normal on (0, \\infty))
  update_sts <- function(exps, inv.uts, c2.invb.absgam2.sigma, c.invb.absgam, c.a.invb.absgam) {
    s.sig2 <- 1 / (1 + c2.invb.absgam2.sigma * inv.uts)
    s.sig2 <- pmax(s.sig2, 1e-14)
    s.sig  <- sqrt(s.sig2)
    s.mu   <- s.sig2 * (c.invb.absgam * (y - exps) * inv.uts - c.a.invb.absgam)

    moms <- .exdqlm_pos_truncnorm_moments(s.mu, s.sig2)
    E.sts <- moms$mean
    E.sts2 <- moms$second
    H_sts_t <- 0.5 * log(2 * pi * s.sig2) + log(pmax(moms$Phi, 1e-12)) +
      0.5 * (1 + (s.mu / s.sig) * moms$Lambda)
    H_sts    <- sum(H_sts_t)

    list(sts.sig2 = s.sig2, sts.mu = s.mu,
        E.sts = E.sts, E.sts2 = E.sts2,
        entropy = H_sts)
  }

  # function update q(ut)  (GIG with \lambda = 1/2)
  update_uts <- function(exps, exps2, sts, sts2, inv.sigma, a2.invb.inv.sigma,
                        invb.inv.sigma, c.invb.absgam, c2.invb.absgam2.sigma) {
    u.lambda <- 0.5
    u.psi    <- (a2.invb.inv.sigma + 2 * inv.sigma)
    u.chi    <- invb.inv.sigma*(y^2 - 2*y*exps + exps2) - 2*c.invb.absgam*sts*(y - exps) +
                c2.invb.absgam2.sigma*sts2

    # numeric floors
    eps  <- getOption("exdqlm.safe_eps", 1e-8)
    u.psi[u.psi <= eps | !is.finite(u.psi)] <- eps
    u.chi[u.chi <= eps | !is.finite(u.chi)] <- eps

    z <- sqrt(u.chi * u.psi)

    # CLOSED-FORM moments for \lambda = 1/2  (robust, no besselRatio):
    E.uts     <- sqrt(u.chi / u.psi) + 1 / u.psi
    E.inv.uts <- sqrt(u.psi / u.chi)

    # E[log U] and entropy (keep your ELBO bits; guard Bessel calls)
    Klam   <- besselK(z, u.lambda)
    Klam_p <- besselK(z, u.lambda + 1e-4)
    Klam_m <- besselK(z, u.lambda - 1e-4)
    Klam[!is.finite(Klam)]     <- besselK(pmax(z, 1e-6), u.lambda)
    Klam_p[!is.finite(Klam_p)] <- besselK(pmax(z, 1e-6), u.lambda + 1e-4)
    Klam_m[!is.finite(Klam_m)] <- besselK(pmax(z, 1e-6), u.lambda - 1e-4)

    Eu_eps  <- (Klam_p / Klam) * (sqrt(u.chi / u.psi))^(1e-4)
    Eu_meps <- (Klam_m / Klam) * (sqrt(u.chi / u.psi))^(-1e-4)
    Elogu   <- (log(Eu_eps) - log(Eu_meps)) / (2e-4)

    # Entropy of GIG
    # H = - E[ log q(U) ] with q(U) \propto u^{\lambda-1} exp(-(\psi u + \chi/u)/2)
    # using E[U], E[1/U], E[log U] above
    H_t <- - (u.lambda/2) * log(u.psi / u.chi) +
            log(2 * Klam) - (u.lambda - 1) * Elogu +
            0.5 * (u.psi * E.uts + u.chi * E.inv.uts)
    H_u <- sum(H_t)

    list(uts.lambda = u.lambda, uts.psi = u.psi, uts.chi = u.chi,
        E.uts = E.uts, E.inv.uts = E.inv.uts,
        E.log.uts = sum(Elogu), entropy = H_u)
  }


  # function update q(theta) ffbsm
  update_theta<-function(ex.f,ex.q){
    # initialize ffbs
    m <- sm <- matrix(NA,p,TT)
    C <- sC <- array(NA,c(p,p,TT))
    standard.forecast.errors <- rep(NA,TT)
    ## forward filter
    # first iteration
    a = as.vector(GG[,,1]%*%m0)
    P = GG[,,1]%*%C0%*%t(GG[,,1])
    R = P + df.mat*P
    R = (R + t(R))/2
    f = t(FF[,1])%*%a + ex.f[1]
    q = t(FF[,1])%*%R%*%FF[,1]  + ex.q[1]
    m[,1] = a + t(R)%*%FF[,1]%*%(y[1]-f)/q[1]
    C[,,1] = R - t(R)%*%FF[,1]%*%t(FF[,1])%*%R/q[1]
    C[,,1] = (C[,,1] + t(C[,,1]))/2
    standard.forecast.errors[1] = (y[1]-f)/sqrt(q)
    # t = 2:TT
    for(t in 2:TT){
      a = as.vector(GG[,,t]%*%m[,(t-1)])
      P = GG[,,t]%*%C[,,(t-1)]%*%t(GG[,,t])
      R = P + df.mat*P
      R = (R + t(R))/2
      f = t(FF[,t])%*%a + ex.f[t]
      fB = t(FF[,t])%*%R
      q = fB%*%FF[,t] + ex.q[t]
      m[,t] = a + t(fB)%*%(y[t]-f)/q[1]
      C[,,t] = R - t(fB)%*%fB/q[1]
      C[,,t] = (C[,,t] + t(C[,,t]))/2
      standard.forecast.errors[t] = (y[t]-f)/sqrt(q)
    }
    ## backwards smoothing
    sC[,,TT] = C[,,TT]
    sm[,TT] = m[,TT]
    for(t in (TT-1):1){
      P = GG[,,(t+1)]%*%C[,,(t)]%*%t(GG[,,(t+1)])
      R = P + df.mat*P
      R = (R + t(R))/2
      svd.R = svd(R)
      inv.R = svd.R$u%*%diag(1/svd.R$d,p)%*%t(svd.R$u)
      sB = C[,,t]%*%t(GG[,,(t+1)])%*%inv.R
      sm[,t] = m[,t] + sB%*%(sm[,(t+1)]-as.vector(GG[,,(t+1)]%*%m[,(t)]))
      sC[,,t] = C[,,t] + sB%*%(sC[,,(t+1)]-R)%*%t(sB)
      sC[,,t] = (sC[,,t]+t(sC[,,t]))/2
    }
    exps =  apply(FF*sm,2,sum)
    vars = c(apply(matrix(1:TT,TT,1),1,function(x){t(FF[,x])%*%sC[,,x]%*%FF[,x]}))
    exps2 = exps^2 + vars
    return(list(exps=exps,vars=vars,exps2=exps2,standard.forecast.errors=standard.forecast.errors,sm=sm,sC=sC,fm=m,fC=C))
  }

  # function approximate q(sigma,gamma) with Laplace-Delta + ELBO via log-normalizer
  log_prior_gamma <- function(gamma) {
    .gamma_log_prior_trunc_t(gamma, bounds = c(L, U), PriorGamma = PriorGamma)
  }
  A_of <- function(gamma) A.fn(p0, gamma)
  B_of <- function(gamma) B.fn(p0, gamma)
  lam_of <- function(gamma) C.fn(p0, gamma) * abs(gamma)
  g_from_eta <- function(eta) {
    u <- stats::plogis(eta)
    u <- pmin(pmax(u, ld_ctrl$logit_eps), 1 - ld_ctrl$logit_eps)
    L + (U - L) * u
  }
  sig_from_ell <- function(ell) exp(ell)

  trans_par <- function(z) {
    eta <- as.numeric(z[1])
    ell <- as.numeric(z[2])
    gamma <- g_from_eta(eta)
    sigma <- sig_from_ell(ell)
    A <- A_of(gamma)
    B <- pmax(B_of(gamma), 1e-12)
    lambda <- lam_of(gamma)
    s <- stats::plogis(eta)
    s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
    log_hprime <- log(s) + log1p(-s)
    list(
      eta = eta,
      ell = ell,
      gamma = gamma,
      sigma = sigma,
      A = A,
      B = B,
      lambda = lambda,
      log_hprime = log_hprime
    )
  }

  log_qsiggam_dynamic <- function(par, state, include_jacobian = TRUE) {
    p <- trans_par(par)
    if (!is.finite(p$B) || p$B <= 0 || !is.finite(p$sigma) || p$sigma <= 0) return(-Inf)

    cache <- state$ld_cache
    if (!is.null(cache)) {
      term1 <- - (1 / (2 * p$B * p$sigma)) *
        (cache$sum_einv_quad - 2 * p$A * cache$sum_t + (p$A * p$A) * cache$sum_uts)
      term2 <- - cache$sum_uts_bsigma / p$sigma
      term3 <- + (p$lambda / p$B) * (cache$sum_s_einv_t - p$A * cache$sum_s)
      term4 <- - ((p$lambda * p$lambda) / (2 * p$B)) * p$sigma * cache$sum_s2_einv
    } else {
      t_i <- state$y - state$exps
      term1 <- - (1 / (2 * p$B * p$sigma)) * sum(
        state$inv_uts * (t_i^2 + pmax(state$theta_var, 0)) - 2 * p$A * t_i + (p$A * p$A) * state$uts
      )
      term2 <- - (sum(state$uts) + state$b_sigma) / p$sigma
      term3 <- + (p$lambda / p$B) * sum(state$sts * state$inv_uts * t_i - state$sts * p$A)
      term4 <- - ((p$lambda * p$lambda) / (2 * p$B)) * p$sigma * sum(state$sts2 * state$inv_uts)
    }

    log_prior <- log_prior_gamma(p$gamma) + state$a_sigma * log(state$b_sigma) -
      lgamma(state$a_sigma) - (state$a_sigma + 1) * p$ell
    log_det <- - (state$nn / 2) * log(p$B) - (3 * state$nn / 2) * p$ell
    val <- log_prior + log_det + term1 + term2 + term3 + term4
    if (isTRUE(include_jacobian)) {
      val <- val + .exal_static_ld_log_jacobian(p$eta, p$ell, L, U)
    }
    val
  }

  compute_dynamic_ld_delta <- function(eta_hat, ell_hat, Sigma, state) {
    z0 <- c(eta_hat, ell_hat)
    g_vec <- function(z) {
      p <- trans_par(z)
      c(
        E_sigma = p$sigma,
        E_gam = p$gamma,
        E_inv_sigma = 1 / p$sigma,
        E_c2_invb_absgam2_sigma = (p$lambda * p$lambda) * p$sigma / p$B,
        E_c_invb_absgam = p$lambda / p$B,
        E_c_a_invb_absgam = (p$lambda * p$A) / p$B,
        E_a2_invb_inv_sigma = (p$A * p$A) / (p$B * p$sigma),
        E_invb_inv_sigma = 1 / (p$B * p$sigma),
        E_a_invb_inv_sigma = p$A / (p$B * p$sigma),
        E_log_sig_b = log(p$sigma) + log(pmax(p$B, 1e-300)),
        E_log_sig = log(p$sigma),
        E_prior_sig_gam = log_prior_gamma(p$gamma) +
          nimble::dinvgamma(p$sigma, shape = PriorSigma$a_sig, scale = PriorSigma$b_sig, log = TRUE),
        zeta_logJ = .exal_static_ld_log_jacobian(p$eta, p$ell, L, U)
      )
    }

    h1s <- 1e-3 * sqrt(pmax(Sigma[1, 1], 1e-8))
    h2s <- 1e-3 * sqrt(pmax(Sigma[2, 2], 1e-8))
    h1 <- min(max(max(1e-4 * (1 + abs(eta_hat)), h1s), 1e-6), 1e-2)
    h2 <- min(max(max(1e-4 * (1 + abs(ell_hat)), h2s), 1e-6), 1e-2)

    f00 <- g_vec(z0)
    f10 <- g_vec(z0 + c(h1, 0))
    f_10 <- g_vec(z0 + c(-h1, 0))
    f01 <- g_vec(z0 + c(0, h2))
    f0_1 <- g_vec(z0 + c(0, -h2))
    f11 <- g_vec(z0 + c(h1, h2))
    f1_1 <- g_vec(z0 + c(h1, -h2))
    f_11 <- g_vec(z0 + c(-h1, h2))
    f_1_1 <- g_vec(z0 + c(-h1, -h2))

    H11 <- (f10 - 2 * f00 + f_10) / (h1^2)
    H22 <- (f01 - 2 * f00 + f0_1) / (h2^2)
    H12 <- (f11 - f1_1 - f_11 + f_1_1) / (4 * h1 * h2)
    corr <- 0.5 * (H11 * Sigma[1, 1] + 2 * H12 * Sigma[1, 2] + H22 * Sigma[2, 2])
    as.list(f00 + corr)
  }

  find_mode_ld <- function(par_start, state) {
    fn_neg <- function(z) {
      val <- log_qsiggam_dynamic(z, state = state)
      if (is.finite(val)) -val else 1e50
    }
    par_start <- c(
      min(max(as.numeric(par_start[1]), ld_ctrl$eta_lo), ld_ctrl$eta_hi),
      min(max(as.numeric(par_start[2]), ld_setup$ell_lo), ld_setup$ell_hi)
    )
    opt <- if (identical(ld_ctrl$optimizer_method, "lbfgsb")) {
      try(
        optim(
          par = par_start,
          fn = fn_neg,
          method = "L-BFGS-B",
          lower = c(ld_ctrl$eta_lo, ld_setup$ell_lo),
          upper = c(ld_ctrl$eta_hi, ld_setup$ell_hi),
          control = list(maxit = ld_ctrl$optimizer_maxit)
        ),
        silent = TRUE
      )
    } else {
      try(
        optim(
          par = par_start,
          fn = fn_neg,
          method = "BFGS",
          control = list(maxit = ld_ctrl$optimizer_maxit),
          hessian = TRUE
        ),
        silent = TRUE
      )
    }
    used_optim_fallback <- FALSE
    used_numeric_hessian <- FALSE
    used_identity_hessian <- FALSE
    if (inherits(opt, "try-error") || !is.finite(opt$value)) {
      used_optim_fallback <- TRUE
      opt <- list(par = as.numeric(par_start), value = fn_neg(par_start), hessian = diag(2) * 1e-2, convergence = 1L)
    }
    H <- opt$hessian
    if (is.null(H)) H <- matrix(NA_real_, 2L, 2L)
    H <- suppressWarnings(as.matrix(H))
    if (!all(dim(H) == c(2L, 2L)) || any(!is.finite(H))) {
      used_numeric_hessian <- TRUE
      H <- try(numDeriv::hessian(function(z) -log_qsiggam_dynamic(z, state = state), x = opt$par), silent = TRUE)
      if (inherits(H, "try-error") || any(!is.finite(H))) {
        used_identity_hessian <- TRUE
        H <- diag(2L) * 1e-2
      }
    }
    H <- (H + t(H)) / 2
    reg <- .exal_static_ld_cov_from_precision(H, eig_floor = ld_ctrl$eig_floor, eig_cap = ld_ctrl$eig_cap)
    list(
      eta_hat = as.numeric(opt$par[1]),
      ell_hat = as.numeric(opt$par[2]),
      Sigma = reg$Sigma,
      objective = as.numeric(log_qsiggam_dynamic(opt$par, state = state)),
      optim_convergence = if (!is.null(opt$convergence)) as.integer(opt$convergence)[1] else NA_integer_,
      optimizer_method = ld_ctrl$optimizer_method,
      used_fallback = used_optim_fallback || used_numeric_hessian || used_identity_hessian || isTRUE(reg$used_floor),
      used_optim_fallback = used_optim_fallback,
      used_numeric_hessian = used_numeric_hessian,
      used_identity_hessian = used_identity_hessian,
      used_cov_floor = isTRUE(reg$used_floor),
      hess_condition = reg$condition_raw,
      cov_condition = reg$condition_reg,
      cov_eig_min = min(reg$cov_eig_reg),
      cov_eig_max = max(reg$cov_eig_reg)
    )
  }

  update_gamma_sigma <- function(gamma, var.gam, sigma, var.sig,
                                exps, exps2, sts, sts2, uts, inv.uts) {
    y_vec <- as.numeric(y)
    exps_vec <- as.numeric(exps)
    theta_var_vec <- pmax(as.numeric(exps2) - exps_vec^2, 0)
    sts_vec <- as.numeric(sts)
    sts2_vec <- as.numeric(sts2)
    uts_vec <- as.numeric(uts)
    inv_uts_vec <- as.numeric(inv.uts)
    t_i <- y_vec - exps_vec
    ld_cache <- list(
      sum_einv_quad = sum(inv_uts_vec * (t_i^2 + theta_var_vec)),
      sum_t = sum(t_i),
      sum_uts = sum(uts_vec),
      sum_uts_bsigma = sum(uts_vec) + PriorSigma$b_sig,
      sum_s_einv_t = sum(sts_vec * inv_uts_vec * t_i),
      sum_s = sum(sts_vec),
      sum_s2_einv = sum(sts2_vec * inv_uts_vec)
    )
    state <- list(
      y = y_vec,
      exps = exps_vec,
      theta_var = theta_var_vec,
      sts = sts_vec,
      sts2 = sts2_vec,
      uts = uts_vec,
      inv_uts = inv_uts_vec,
      a_sigma = PriorSigma$a_sig,
      b_sigma = PriorSigma$b_sig,
      nn = length(y_vec),
      ld_cache = ld_cache
    )

    eta_prev <- eta_hat
    ell_prev <- ell_hat
    Sigma_prev <- Sig_eta_ell
    ld <- find_mode_ld(c(eta_hat, ell_hat), state = state)
    candidate <- list(
      gamma = g_from_eta(ld$eta_hat),
      sigma = exp(ld$ell_hat),
      s_mean = mean(new.sts.out$E.sts),
      tau2_mean = mean(new.sts.out$sts.sig2)
    )
    ld_hist_df <- if (length(gamma_hist)) {
      data.frame(gamma = gamma_hist, sigma = sigma_hist)
    } else {
      data.frame(gamma = numeric(0), sigma = numeric(0))
    }
    s_hist_df <- if (length(s_mean_hist)) {
      data.frame(s_mean = s_mean_hist, tau2_mean = tau2_mean_hist)
    } else {
      data.frame(s_mean = numeric(0), tau2_mean = numeric(0))
    }
    cycle_info <- .exal_static_ld_cycle_detect(ld_hist_df, s_hist_df, candidate, ld_ctrl)
    ld_cycle_detected <- isTRUE(cycle_info$triggered)
    ld_candidate_mode_quality_iter <- .exal_static_ld_mode_quality(
      log_q_fn = function(z) log_qsiggam_dynamic(z, state = state),
      par = c(ld$eta_hat, ld$ell_hat),
      grad_tol = ld_ctrl$mode_grad_tol,
      min_eig = ld_ctrl$mode_min_eig
    )
    ld_bad_mode_iter <- !isTRUE(ld_candidate_mode_quality_iter$local_mode_pass)
    ld_stabilized <- FALSE
    ld_stabilize_reason <- NA_character_
    if (isTRUE(ld_ctrl$auto_stabilize)) {
      if (isTRUE(ld_ctrl$direct_commit) &&
          !isTRUE(stabilize_active) &&
          (isTRUE(ld_cycle_detected) ||
             isTRUE(ld$used_fallback) ||
             (!is.na(ld$optim_convergence) && ld$optim_convergence != 0L) ||
             isTRUE(ld_bad_mode_iter))) {
        stabilize_active <<- TRUE
        stabilize_since_iter <<- iter
        stabilize_reason_active <<- if (isTRUE(ld_cycle_detected)) {
          cycle_info$reason
        } else if (isTRUE(ld$used_fallback)) {
          "ld_used_fallback"
        } else if (isTRUE(ld_bad_mode_iter)) {
          "ld_bad_mode"
        } else {
          sprintf("ld_optim_convergence_%s", ld$optim_convergence)
        }
      }
      if (isTRUE(stabilize_active)) {
        ld_stabilized <- TRUE
        ld_stabilize_reason <- stabilize_reason_active
      }
    }
    use_direct_commit <- isTRUE(ld_ctrl$direct_commit) &&
      !isTRUE(ld_stabilized) &&
      !(isTRUE(ld_ctrl$reject_bad_mode_commit) && isTRUE(ld_bad_mode_iter))
    ld_commit_mode <- if (use_direct_commit) "direct" else "damped"
    if (use_direct_commit) {
      eta_hat <<- as.numeric(ld$eta_hat)
      ell_hat <<- as.numeric(ld$ell_hat)
      Sig_eta_ell <<- .exal_static_ld_regularize_cov(ld$Sigma, eig_floor = ld_ctrl$eig_floor, eig_cap = ld_ctrl$eig_cap)$Sigma
    } else {
      damping_use <- if (isTRUE(ld_stabilized)) ld_ctrl$stabilize_damping else ld_ctrl$damping
      step_cap_eta_use <- if (isTRUE(ld_stabilized)) min(ld_ctrl$step_cap_eta, ld_ctrl$stabilize_step_cap_eta) else ld_ctrl$step_cap_eta
      step_cap_ell_use <- if (isTRUE(ld_stabilized)) min(ld_ctrl$step_cap_ell, ld_ctrl$stabilize_step_cap_ell) else ld_ctrl$step_cap_ell
      eta_hat <<- .exal_static_ld_mix_step(eta_prev, ld$eta_hat, damping = damping_use, step_cap = step_cap_eta_use)
      ell_hat <<- .exal_static_ld_mix_step(ell_prev, ld$ell_hat, damping = damping_use, step_cap = step_cap_ell_use)
      Sigma_mix <- (1 - damping_use) * Sigma_prev + damping_use * ld$Sigma
      Sig_eta_ell <<- .exal_static_ld_regularize_cov(Sigma_mix, eig_floor = ld_ctrl$eig_floor, eig_cap = ld_ctrl$eig_cap)$Sigma
    }

    moms <- compute_dynamic_ld_delta(eta_hat, ell_hat, Sig_eta_ell, state = state)
    ld_committed_objective <- as.numeric(log_qsiggam_dynamic(c(eta_hat, ell_hat), state = state))
    logdetSig <- as.numeric(determinant(Sig_eta_ell, logarithm = TRUE)$modulus)
    entrop <- 0.5 * (2 * (1 + log(2 * pi)) + logdetSig) + as.numeric(moms$zeta_logJ)
    mode_quality <- .exal_static_ld_mode_quality(
      log_q_fn = function(z) log_qsiggam_dynamic(z, state = state),
      par = c(eta_hat, ell_hat),
      grad_tol = ld_ctrl$mode_grad_tol,
      min_eig = ld_ctrl$mode_min_eig
    )

    list(
      E.sigma = as.numeric(moms$E_sigma),
      E.inv.sigma = as.numeric(moms$E_inv_sigma),
      E.gam = as.numeric(moms$E_gam),
      E.c2.invb.absgam2.sigma = as.numeric(moms$E_c2_invb_absgam2_sigma),
      E.c.invb.absgam = as.numeric(moms$E_c_invb_absgam),
      E.c.a.invb.absgam = as.numeric(moms$E_c_a_invb_absgam),
      E.a2.invb.inv.sigma = as.numeric(moms$E_a2_invb_inv_sigma),
      E.invb.inv.sigma = as.numeric(moms$E_invb_inv_sigma),
      E.a.invb.inv.sigma = as.numeric(moms$E_a_invb_inv_sigma),
      Hess.LD = Sig_eta_ell,
      E.log.sig.b = as.numeric(moms$E_log_sig_b),
      E.log.sig = as.numeric(moms$E_log_sig),
      E.prior.sig.gam = as.numeric(moms$E_prior_sig_gam),
      E.theta = c(eta_hat, ell_hat),
      entrop = entrop,
      V.gam = NA_real_,
      V.sigma = NA_real_,
      E.log.inv.sigma = -as.numeric(moms$E_log_sig),
      elbo_logZ = NULL,
      ld = list(
        eta_prev = eta_prev,
        ell_prev = ell_prev,
        eta = eta_hat,
        ell = ell_hat,
        eta_raw = ld$eta_hat,
        ell_raw = ld$ell_hat,
        gamma_raw = candidate$gamma,
        sigma_raw = candidate$sigma,
        optim_convergence = ld$optim_convergence,
        objective = ld$objective,
        objective_candidate = ld$objective,
        objective_committed = ld_committed_objective,
        objective_gap = ld_committed_objective - ld$objective,
        optimizer_method = ld$optimizer_method,
        used_fallback = ld$used_fallback,
        used_optim_fallback = ld$used_optim_fallback,
        used_numeric_hessian = ld$used_numeric_hessian,
        used_identity_hessian = ld$used_identity_hessian,
        used_cov_floor = ld$used_cov_floor,
        commit_mode = ld_commit_mode,
        bad_mode = ld_bad_mode_iter,
        cycle_detected = ld_cycle_detected,
        stabilized = ld_stabilized,
        stabilize_reason = ld_stabilize_reason,
        hess_condition = ld$hess_condition,
        cov_condition = ld$cov_condition,
        cov_eig_min = ld$cov_eig_min,
        cov_eig_max = ld$cov_eig_max,
        candidate_mode_quality = ld_candidate_mode_quality_iter,
        committed_mode_quality = mode_quality,
        mode_quality = mode_quality
      )
    )
  }


  # one-line header 
  if (verbose) {
    message(sprintf("LDVB start | T=%d, p=%d, tol=%.3g | KF:%s | ELBO:%s",
                    TT, p, tol,
                    if (isTRUE(getOption('exdqlm.use_cpp_kf', FALSE))) 'C++' else 'R',
                    if (isTRUE(getOption('exdqlm.compute_elbo', TRUE))) 'on' else 'off'))
    utils::flush.console()
  }

  kf_step <- function(ex.f, ex.q) {
    use_cpp <- isTRUE(getOption("exdqlm.use_cpp_kf", FALSE))
    if (use_cpp) {
      tryCatch(
        update_theta_bridge(ex.f, ex.q, GG, FF, as.numeric(y), m0, C0, df.mat),
        error = function(e) {
          warning("C++ KF failed, falling back to R: ", conditionMessage(e))
          update_theta(ex.f, ex.q)
        }
      )
    } else {
      update_theta(ex.f, ex.q)
    }
  }

  .elbo_snapshot <- function(y, th, st, ut, gs) {
    # helper: robust log|.| for 1x1 or array->matrix slices
    .safe_logdet <- function(A) {
      d <- dim(A)
      if (length(d) >= 2L) {
        M <- matrix(A, nrow = d[1L], ncol = d[2L])
      } else { # scalar (p == 1)
        M <- matrix(A, nrow = 1L, ncol = 1L)
      }
      determinant(M, logarithm = TRUE)$modulus[1]
    }

    # \theta-entropy from bridge if present; otherwise recompute robustly
    H_theta <- if (!is.null(th$elbo_theta)) {
      th$elbo_theta
    } else {
      TTloc <- dim(th$sC)[3]
      0.5 * sum(vapply(seq_len(TTloc), function(t) {
        SCt <- th$sC[, , t, drop = FALSE]
        M   <- matrix(SCt, nrow = dim(SCt)[1L], ncol = dim(SCt)[2L])
        p_t <- nrow(M)
        p_t * (1 + log(2*pi)) + .safe_logdet(M)
      }, numeric(1)))
    }

    H_sts <- st$entropy
    H_uts <- ut$entropy

    if (!is.null(gs$elbo_logZ)) {
      total <- as.numeric(H_theta + H_sts + H_uts + gs$elbo_logZ)
      breakdown <- c(H_theta = H_theta, H_sts = H_sts, H_uts = H_uts, gs_logZ = gs$elbo_logZ)
    } else {
      # (fallback lik) ... unchanged ...
      resid2 <- (y^2 - 2*y*th$exps + th$exps2)
      L1 <-  + 1.5 * length(y) * gs$E.log.inv.sigma
      L2 <-  - gs$E.inv.sigma * sum(ut$E.uts)
      L3 <-  - 0.5 * gs$E.invb.inv.sigma * sum(ut$E.inv.uts * resid2)
      L4 <-  - 0.5 * 2 * sum( (th$exps - y) * (ut$E.inv.uts * gs$E.c.invb.absgam * st$E.sts) )
      L5 <-  - 0.5 * 2 * sum( (th$exps - y) * gs$E.a.invb.inv.sigma )
      L6 <-  - 0.5 * sum( gs$E.c2.invb.absgam2.sigma * ut$E.inv.uts * st$E.sts2 )
      L7 <-  - 0.5 * 2 * sum( gs$E.c.a.invb.absgam * st$E.sts )
      L8 <-  - 0.5 * sum( ut$E.uts * gs$E.a2.invb.inv.sigma )
      # add the missing -0.5 n E[log b]
      L0 <- -0.5 * length(y) * (gs$E.log.sig.b - gs$E.log.sig)
      lik <- L0 + L1 + L2 + L3 + L4 + L5 + L6 + L7 + L8

      # add sigma,gamma prior + entropy (Laplace-Delta block)
      elbo_gs <- gs$E.prior.sig.gam + gs$entrop

      total <- as.numeric(lik + H_theta + H_sts + H_uts + elbo_gs)
      breakdown <- c(lik = lik, H_theta = H_theta, H_sts = H_sts, H_uts = H_uts,
                    prior_gs = gs$E.prior.sig.gam, H_gs = gs$entrop)

    }

    list(total = total, breakdown = breakdown)
  }


  tictoc::tic("run time")
  ### estimate posterior
  while(iter < max_iter){

    # counter
    iter <- iter + 1L
    # update distributions
    cur.uts.out = new.uts.out
    cur.sts.out = new.sts.out
    cur.theta.out = new.theta.out
    cur.gamsig.out = new.gamsig.out

    # update q(st)
    new.sts.out <- update_sts(cur.theta.out$exps,cur.uts.out$E.inv.uts,
                              cur.gamsig.out$E.c2.invb.absgam2.sigma,cur.gamsig.out$E.c.invb.absgam,cur.gamsig.out$E.c.a.invb.absgam)

    # update q(ut)
    new.uts.out <- update_uts(cur.theta.out$exps,cur.theta.out$exps2,
                              new.sts.out$E.sts,new.sts.out$E.sts2,
                              cur.gamsig.out$E.inv.sigma,cur.gamsig.out$E.a2.invb.inv.sigma,cur.gamsig.out$E.invb.inv.sigma,
                              cur.gamsig.out$E.c.invb.absgam,cur.gamsig.out$E.c2.invb.absgam2.sigma)

    # compute ex.f / ex.q 
    ex.f <- cur.gamsig.out$E.c.invb.absgam*new.sts.out$E.sts/cur.gamsig.out$E.invb.inv.sigma +
            cur.gamsig.out$E.a.invb.inv.sigma/(new.uts.out$E.inv.uts*cur.gamsig.out$E.invb.inv.sigma)
    ex.q <- (cur.gamsig.out$E.invb.inv.sigma*new.uts.out$E.inv.uts)^(-1)

    # tiny optional debug probe
    if (debug_shapes && (iter == 1 || iter %% debug_every == 0))
      .pre(iter, ex.f, ex.q, GG, FF, y, m0, C0, df.mat, p, TT)

    # numeric guard for KF
    eps_q <- getOption("exdqlm.q_floor", 1e-10)
    ex.q[!is.finite(ex.q) | ex.q <= eps_q] <- pmax(eps_q, median(ex.q[is.finite(ex.q) & ex.q > 0], na.rm = TRUE))

    # numeric guard for KF (keep your ex.q floor as-is)
    ex.f <- as.numeric(ex.f)                     # ensure plain numeric vector
    stopifnot(length(ex.f) == TT)                # sanity
    ex.q <- as.numeric(ex.q)                     # ensure plain numeric vector
    stopifnot(length(ex.q) == TT)                # sanity

    # update q(theta)
    new.theta.out <- kf_step(ex.f, ex.q)

    if (debug_shapes && (iter == 1 || iter %% debug_every == 0))
      .post(new.theta.out)

    # update q(gamma,sigma)
    new.gamsig.out <- update_gamma_sigma(
      cur.gamsig.out$E.gam, cur.gamsig.out$V.gam,
      cur.gamsig.out$E.sigma, cur.gamsig.out$V.sigma,
      new.theta.out$exps, new.theta.out$exps2,
      new.sts.out$E.sts, new.sts.out$E.sts2,
      new.uts.out$E.uts, new.uts.out$E.inv.uts
    )

    # ELBO (now uses gs$elbo_logZ if available)
    if (compute.elbo) {
      elbo.obj <- .elbo_snapshot(y, new.theta.out, new.sts.out, new.uts.out, new.gamsig.out)
      if (!exists("elbo.seq", inherits = FALSE)) elbo.seq <- numeric(0)
      elbo.seq <- c(elbo.seq, elbo.obj$total)
    }

    # save LDVB gamma and sigma estimates
    seq.gamma = c(seq.gamma,new.gamsig.out$E.gam)
    seq.sigma = c(seq.sigma,new.gamsig.out$E.sigma)

    # evaluate convergence with joint criteria (state + sigma + gamma + ELBO)
    d.state <- max(abs(c(cur.theta.out$exps - new.theta.out$exps)))
    d.sigma <- abs(cur.gamsig.out$E.sigma - new.gamsig.out$E.sigma)
    d.gamma <- abs(cur.gamsig.out$E.gam - new.gamsig.out$E.gam)
    d.s <- .exal_static_ld_rel_change(new.sts.out$E.sts, cur.sts.out$E.sts)
    d.elbo <- if (compute.elbo && exists("elbo.seq", inherits = FALSE) && length(elbo.seq) >= 2L) {
      elbo.seq[length(elbo.seq)] - elbo.seq[length(elbo.seq) - 1L]
    } else {
      NA_real_
    }
    conv.step <- .vb_joint_step(
      iter = iter,
      d_state = d.state,
      d_sigma = d.sigma,
      d_gamma = d.gamma,
      d_elbo = d.elbo,
      controls = conv.ctrl,
      compute_elbo = compute.elbo,
      stable_count = stable.count
    )
    stable.count <- conv.step$stable_count
    delta.state <- c(delta.state, d.state)
    delta.sigma <- c(delta.sigma, d.sigma)
    delta.gamma <- c(delta.gamma, d.gamma)
    delta.s <- c(delta.s, d.s)
    delta.elbo <- c(delta.elbo, d.elbo)

    if (isTRUE(ld_ctrl$store_trace)) {
      s_stats <- .exdqlm_trace_summary(new.sts.out$E.sts)
      tau2_stats <- .exdqlm_trace_summary(new.sts.out$sts.sig2)
      ld_info <- if (!is.null(new.gamsig.out$ld)) new.gamsig.out$ld else list()
      ld_trace_rows[[iter]] <- data.frame(
        iter = iter,
        eta = as.numeric(new.gamsig.out$E.theta[1]),
        ell = as.numeric(new.gamsig.out$E.theta[2]),
        gamma = new.gamsig.out$E.gam,
        sigma = new.gamsig.out$E.sigma,
        eta_raw = if (!is.null(ld_info$eta_raw)) ld_info$eta_raw else NA_real_,
        ell_raw = if (!is.null(ld_info$ell_raw)) ld_info$ell_raw else NA_real_,
        eta_step_raw = if (!is.null(ld_info$eta_raw) && !is.null(ld_info$eta_prev)) ld_info$eta_raw - ld_info$eta_prev else NA_real_,
        ell_step_raw = if (!is.null(ld_info$ell_raw) && !is.null(ld_info$ell_prev)) ld_info$ell_raw - ld_info$ell_prev else NA_real_,
        eta_step_used = if (!is.null(ld_info$eta) && !is.null(ld_info$eta_prev)) ld_info$eta - ld_info$eta_prev else NA_real_,
        ell_step_used = if (!is.null(ld_info$ell) && !is.null(ld_info$ell_prev)) ld_info$ell - ld_info$ell_prev else NA_real_,
        xi_method = "delta",
        xi_mcse_mean = NA_real_,
        xi_mcse_max = NA_real_,
        xi_replicates = 0L,
        ld_objective = if (!is.null(ld_info$objective_committed)) ld_info$objective_committed else if (!is.null(ld_info$objective)) ld_info$objective else NA_real_,
        ld_objective_candidate = if (!is.null(ld_info$objective_candidate)) ld_info$objective_candidate else if (!is.null(ld_info$objective)) ld_info$objective else NA_real_,
        ld_objective_committed = if (!is.null(ld_info$objective_committed)) ld_info$objective_committed else if (!is.null(ld_info$objective)) ld_info$objective else NA_real_,
        ld_objective_gap = if (!is.null(ld_info$objective_gap)) ld_info$objective_gap else NA_real_,
        ld_optim_convergence = if (!is.null(ld_info$optim_convergence)) ld_info$optim_convergence else NA_integer_,
        ld_optimizer_method = if (!is.null(ld_info$optimizer_method)) ld_info$optimizer_method else NA_character_,
        ld_used_fallback = if (!is.null(ld_info$used_fallback)) isTRUE(ld_info$used_fallback) else NA,
        ld_used_optim_fallback = if (!is.null(ld_info$used_optim_fallback)) isTRUE(ld_info$used_optim_fallback) else NA,
        ld_used_numeric_hessian = if (!is.null(ld_info$used_numeric_hessian)) isTRUE(ld_info$used_numeric_hessian) else NA,
        ld_used_identity_hessian = if (!is.null(ld_info$used_identity_hessian)) isTRUE(ld_info$used_identity_hessian) else NA,
        ld_used_cov_floor = if (!is.null(ld_info$used_cov_floor)) isTRUE(ld_info$used_cov_floor) else NA,
        ld_commit_mode = if (!is.null(ld_info$commit_mode)) ld_info$commit_mode else NA_character_,
        ld_bad_mode = if (!is.null(ld_info$bad_mode)) isTRUE(ld_info$bad_mode) else NA,
        ld_cycle_detected = if (!is.null(ld_info$cycle_detected)) isTRUE(ld_info$cycle_detected) else NA,
        ld_stabilized = if (!is.null(ld_info$stabilized)) isTRUE(ld_info$stabilized) else NA,
        ld_stabilize_reason = if (!is.null(ld_info$stabilize_reason)) ld_info$stabilize_reason else NA_character_,
        ld_hess_condition = if (!is.null(ld_info$hess_condition)) ld_info$hess_condition else NA_real_,
        ld_cov_condition = if (!is.null(ld_info$cov_condition)) ld_info$cov_condition else NA_real_,
        ld_cov_eig_min = if (!is.null(ld_info$cov_eig_min)) ld_info$cov_eig_min else NA_real_,
        ld_cov_eig_max = if (!is.null(ld_info$cov_eig_max)) ld_info$cov_eig_max else NA_real_,
        ld_mode_grad_inf_norm_candidate = if (!is.null(ld_info$candidate_mode_quality$grad_inf_norm)) ld_info$candidate_mode_quality$grad_inf_norm else NA_real_,
        ld_mode_neg_hess_min_eig_candidate = if (!is.null(ld_info$candidate_mode_quality$neg_hess_min_eig)) ld_info$candidate_mode_quality$neg_hess_min_eig else NA_real_,
        ld_mode_local_pass_candidate = if (!is.null(ld_info$candidate_mode_quality$local_mode_pass)) isTRUE(ld_info$candidate_mode_quality$local_mode_pass) else NA,
        ld_mode_grad_inf_norm_committed = if (!is.null(ld_info$committed_mode_quality$grad_inf_norm)) ld_info$committed_mode_quality$grad_inf_norm else if (!is.null(ld_info$mode_quality$grad_inf_norm)) ld_info$mode_quality$grad_inf_norm else NA_real_,
        ld_mode_neg_hess_min_eig_committed = if (!is.null(ld_info$committed_mode_quality$neg_hess_min_eig)) ld_info$committed_mode_quality$neg_hess_min_eig else if (!is.null(ld_info$mode_quality$neg_hess_min_eig)) ld_info$mode_quality$neg_hess_min_eig else NA_real_,
        ld_mode_local_pass_committed = if (!is.null(ld_info$committed_mode_quality$local_mode_pass)) isTRUE(ld_info$committed_mode_quality$local_mode_pass) else if (!is.null(ld_info$mode_quality$local_mode_pass)) isTRUE(ld_info$mode_quality$local_mode_pass) else NA,
        delta_state = d.state,
        delta_sigma = d.sigma,
        delta_gamma = d.gamma,
        delta_s = d.s,
        delta_elbo = d.elbo,
        s_mean = s_stats[["mean"]],
        s_sd = s_stats[["sd"]],
        s_q05 = s_stats[["q05"]],
        s_q50 = s_stats[["median"]],
        s_q95 = s_stats[["q95"]],
        s_min = s_stats[["min"]],
        s_max = s_stats[["max"]],
        stringsAsFactors = FALSE
      )
      s_trace_rows[[iter]] <- data.frame(
        iter = iter,
        phase = "vb",
        s_mean = s_stats[["mean"]],
        s_sd = s_stats[["sd"]],
        s_q05 = s_stats[["q05"]],
        s_q50 = s_stats[["median"]],
        s_q95 = s_stats[["q95"]],
        s_min = s_stats[["min"]],
        s_max = s_stats[["max"]],
        tau2_mean = tau2_stats[["mean"]],
        tau2_sd = tau2_stats[["sd"]],
        tau2_q05 = tau2_stats[["q05"]],
        tau2_q50 = tau2_stats[["median"]],
        tau2_q95 = tau2_stats[["q95"]],
        tau2_min = tau2_stats[["min"]],
        tau2_max = tau2_stats[["max"]],
        delta_s = d.s,
        stringsAsFactors = FALSE
      )
    }

    if (verbose && iter %% 5 == 0) {
      if (compute.elbo) {
        msg <- sprintf(
          "iter %3d | d_state=%.3g d_sigma=%.3g d_gamma=%.3g | sigma=%.3g | gamma=%.3g | ELBO=%.6f (Delta=%.2e) | stable=%d/%d",
          iter, d.state, d.sigma, d.gamma, new.gamsig.out$E.sigma, new.gamsig.out$E.gam,
          utils::tail(elbo.seq, 1), d.elbo, stable.count, conv.ctrl$patience
        )
      } else {
        msg <- sprintf(
          "iter %3d | d_state=%.3g d_sigma=%.3g d_gamma=%.3g | sigma=%.3g | gamma=%.3g | stable=%d/%d",
          iter, d.state, d.sigma, d.gamma, new.gamsig.out$E.sigma, new.gamsig.out$E.gam,
          stable.count, conv.ctrl$patience
        )
      }
      if (!is.null(new.gamsig.out$elbo_logZ)) msg <- sprintf("%s | gs_logZ=%.6f", msg, new.gamsig.out$elbo_logZ)
      message(msg); utils::flush.console()
    }

    if (conv.step$stop_now) {
      stop.reason <- "joint_converged"
      break
    }

  }
  run.time <- tictoc::toc(quiet = TRUE)
  if (verbose) {
    cat(sprintf("LDVB %s: %s iterations, %s seconds",
                ifelse(identical(stop.reason, "joint_converged"), "converged", "stopped"),
                iter, round(run.time$toc - run.time$tic, 3)), "\n")
  }
  ld_trace_df <- if (isTRUE(ld_ctrl$store_trace)) {
    keep <- Filter(Negate(is.null), ld_trace_rows[seq_len(iter)])
    if (length(keep)) do.call(rbind, keep) else data.frame()
  } else {
    data.frame()
  }
  s_trace_df <- if (isTRUE(ld_ctrl$store_trace)) {
    keep <- Filter(Negate(is.null), s_trace_rows[seq_len(iter)])
    if (length(keep)) do.call(rbind, keep) else data.frame()
  } else {
    data.frame()
  }
  ld_mode_quality <- if (!is.null(new.gamsig.out$ld$mode_quality)) new.gamsig.out$ld$mode_quality else list()
  ld_signoff_summary <- if (nrow(ld_trace_df)) {
    tail_n <- min(50L, nrow(ld_trace_df))
    tail_df <- utils::tail(ld_trace_df, tail_n)
    base <- list(
      tail_n = tail_n,
      candidate_local_pass_rate = mean(as.logical(tail_df$ld_mode_local_pass_candidate), na.rm = TRUE),
      committed_local_pass_rate = mean(as.logical(tail_df$ld_mode_local_pass_committed), na.rm = TRUE),
      candidate_grad_inf_median = stats::median(tail_df$ld_mode_grad_inf_norm_candidate, na.rm = TRUE),
      committed_grad_inf_median = stats::median(tail_df$ld_mode_grad_inf_norm_committed, na.rm = TRUE),
      candidate_min_eig_median = stats::median(tail_df$ld_mode_neg_hess_min_eig_candidate, na.rm = TRUE),
      committed_min_eig_median = stats::median(tail_df$ld_mode_neg_hess_min_eig_committed, na.rm = TRUE),
      stabilized_rate = mean(as.logical(tail_df$ld_stabilized), na.rm = TRUE),
      fallback_rate = mean(as.logical(tail_df$ld_used_fallback), na.rm = TRUE),
      optim_fallback_rate = mean(as.logical(tail_df$ld_used_optim_fallback), na.rm = TRUE),
      numeric_hessian_rate = mean(as.logical(tail_df$ld_used_numeric_hessian), na.rm = TRUE),
      identity_hessian_rate = mean(as.logical(tail_df$ld_used_identity_hessian), na.rm = TRUE),
      cov_floor_rate = mean(as.logical(tail_df$ld_used_cov_floor), na.rm = TRUE),
      direct_commit_rate = mean(tail_df$ld_commit_mode %in% "direct", na.rm = TRUE),
      damped_commit_rate = mean(tail_df$ld_commit_mode %in% "damped", na.rm = TRUE),
      objective_gap_median = stats::median(tail_df$ld_objective_gap, na.rm = TRUE)
    )
    c(base, .exal_static_ld_committed_stability(ld_trace_df, conv.ctrl))
  } else {
    list()
  }

  ### posterior samples ------------------------------------------------------

  # Draw (sigma, gamma) from the LD Gaussian on (theta_s, theta_g), then transform
  LD_mu <- as.numeric(new.gamsig.out$E.theta)      # length 2
  LD_S  <- as.matrix(new.gamsig.out$Hess.LD)       # 2x2 covariance in (theta_s, theta_g)
  # robust factorization for sampling
  Lfac <- try(chol(LD_S), silent = TRUE)
  if (inherits(Lfac, "try-error")) {
    eig <- eigen((LD_S + t(LD_S))/2, symmetric = TRUE)
    vals <- pmax(eig$values, .Machine$double.eps)
    Lfac <- eig$vectors %*% diag(sqrt(vals), 2) %*% t(eig$vectors)
  }
  Z  <- matrix(stats::rnorm(2L * n.samp), nrow = 2L)
  TH <- LD_mu + Lfac %*% Z
  theta_s <- TH[1L, ]
  theta_g <- TH[2L, ]
  samp.sigma <- exp(theta_s)
  samp.gamma <- L + (U - L) * stats::plogis(theta_g)

  # toggles
  use_cpp_samplers <- isTRUE(getOption("exdqlm.use_cpp_samplers", FALSE))
  use_cpp_postpred <- isTRUE(getOption("exdqlm.use_cpp_postpred", FALSE))  # keep FALSE by default

  # base dims
  J  <- 0L
  p  <- nrow(new.theta.out$sm)
  TT <- ncol(new.theta.out$sm)
  ns <- as.integer(n.samp)

  # ---- s_t (half-line truncated normal) ------------------------------------
  if (use_cpp_samplers && exists("sample_truncnorm", mode = "function")) {
    # C++ returns n_samp x TT -> transpose to TT x n_samp
    samp.sts <- t(sample_truncnorm(ns, TT, new.sts.out$sts.mu, new.sts.out$sts.sig2))
  } else {
    # R fallback
    samp.sts <- t(vapply(seq_len(TT), function(t) {
      sd_t <- sqrt(pmax(new.sts.out$sts.sig2[t], 0))
      truncnorm::rtruncnorm(ns, a = 0, b = Inf,
                            mean = new.sts.out$sts.mu[t],
                            sd   = sd_t)
    }, numeric(ns)))
  }

  # ---- u_t (GIG with lambda = 1/2) -----------------------------------------
  # coerce to length TT and clamp NA/nonpositive to a tiny epsilon
  psi_vec <- rep_len(as.numeric(new.uts.out$uts.psi), TT)
  chi_vec <- rep_len(as.numeric(new.uts.out$uts.chi), TT)
  lam_gig <- as.numeric(new.uts.out$uts.lambda)
  eps_gig <- sqrt(.Machine$double.eps)

  fix_pos <- function(x) { x[!is.finite(x) | x <= 0] <- eps_gig; x }
  psi_vec <- fix_pos(psi_vec)
  chi_vec <- fix_pos(chi_vec)

  # Safe wrapper for R fallback
  rgig_one <- function(n, chi, psi, lambda) {
    if (!is.finite(psi) || psi <= 0) psi <- eps_gig
    if (!is.finite(chi) || chi <= 0) chi <- eps_gig
    GeneralizedHyperbolic::rgig(n, chi = chi, psi = psi, lambda = lambda)
  }

  # Devroye C++ fast path only if psi is effectively constant across t
  same_psi <- (length(unique(round(psi_vec, 12))) == 1L)

  if (use_cpp_samplers && exists("sample_gig_devroye_vector", mode = "function") && same_psi) {
    a_scalar <- psi_vec[1]
    # C++ returns n_samp x TT -> transpose to TT x n_samp
    
    samp.uts <- t(sample_gig_devroye_vector(ns, lam_gig, a_scalar, chi_vec))
  } else {
    # R fallback (guarded)
    samp.uts <- t(vapply(seq_len(TT), function(t) rgig_one(ns, chi_vec[t], psi_vec[t], lam_gig),
                         numeric(ns)))
  }

  # ---- theta (multivariate normal) : R fallback via SVD per time ----
  samp.theta <- array(NA_real_, dim = c(p, TT, ns))
  for (t in seq_len(TT)) {
    svd.sC <- svd(new.theta.out$sC[, , t])                       # <-- restore this
    Lmat   <- svd.sC$u %*% diag(sqrt(pmax(svd.sC$d, 0)), p, p)
    Z      <- matrix(stats::rnorm(ns * p), nrow = p, ncol = ns)
    mu_t   <- matrix(new.theta.out$sm[, t], nrow = p, ncol = ns)
    samp.theta[, t, ] <- mu_t + Lmat %*% Z                       # <-- index [ , t, ]
  }
  
  ## posterior predictive
  samp.post.pred <- matrix(NA_real_, nrow = TT, ncol = ns)

  if (!use_cpp_postpred) {
    # Pure R path (stable and vectorized)
    for (t in seq_len(TT)) {
      # theta_t: p x ns
      theta_t <- matrix(samp.theta[, t, ], nrow = p, ncol = ns)

      # xb_i = FF[,t]^T * theta_t[,i] -> length ns
      xb <- as.numeric(crossprod(FF[, t], theta_t))

      # location shift: length ns
      loc <- xb + samp.sigma * C.fn(p0, samp.gamma) * abs(samp.gamma) * samp.sts[t, ]

      # quantile parameter tau = p.fn(p0, gamma); clamp away from {0,1}
      tau <- pmin(pmax(p.fn(p0, samp.gamma), 1e-16), 1 - 1e-16)

      # Draw ns samples (vectorized)
      samp.post.pred[t, ] <- rexal(ns, tau, loc, samp.sigma, 0)
    }
  } else {
    # Optional C++ post-pred path (shape: 1 x TT x ns for J=0)
    if (exists("samp_post_pred", mode = "function")) {
      FF_cube  <- array(FF, dim = c(p, 1L, TT))
      sts_cube <- array(samp.sts, dim = c(1L, TT, ns))
      cpp_pred <- samp_post_pred(
        ns, TT, p, J,
        samp.theta, FF_cube,
        matrix(samp.sigma, nrow = 1L), p0,
        matrix(samp.gamma, nrow = 1L),
        sts_cube
      )
      # 1 x TT x ns -> TT x ns
      samp.post.pred <- aperm(cpp_pred[1, , , drop = FALSE], c(2, 3, 1))[, , 1]
    } else {
      stop("use_cpp_postpred=TRUE but C++ post-pred sampler not found.")
    }
  }

  ### list results
  if(!dqlm.ind){
    retlist = list(y=y,run.time=(run.time$toc-run.time$tic),iter=iter,dqlm.ind=dqlm.ind,
                   model=model,p0=p0,df=df,dim.df=dim.df,
                   sig.init=sig.init,seq.sigma=seq.sigma,gam.init=gam.init,seq.gamma=seq.gamma,
                   samp.theta=samp.theta,samp.post.pred=samp.post.pred,
                   map.standard.forecast.errors=new.theta.out$standard.forecast.errors,
                   samp.sigma=samp.sigma,samp.gamma=samp.gamma,samp.sts=samp.sts,samp.vts=samp.uts,
                   theta.out=new.theta.out,gammasig.out=new.gamsig.out,sts.out=new.sts.out,vts.out=new.uts.out,
                   fix.sigma=fix.sigma,fix.gamma=fix.gamma)
  }else{
    retlist = list(y=y,run.time=(run.time$toc-run.time$tic),iter=iter,dqlm.ind=dqlm.ind,
                   model=model,p0=p0,df=df,dim.df=dim.df,
                   sig.init=sig.init,seq.sigma=seq.sigma,
                   samp.theta=samp.theta,samp.post.pred=samp.post.pred,
                   map.standard.forecast.errors=new.theta.out$standard.forecast.errors,
                   samp.sigma=samp.sigma,samp.vts=samp.uts,
                   theta.out=new.theta.out,sig.out=new.gamsig.out,vts.out=new.uts.out,
                   fix.sigma=fix.sigma)
  }

  retlist$diagnostics <- list(
    elbo = if (exists("elbo.seq", inherits = FALSE)) elbo.seq else NULL,
    convergence = list(
      converged = identical(stop.reason, "joint_converged"),
      stop_reason = stop.reason,
      iter = iter,
      stable_count = stable.count,
      criteria = conv.ctrl,
      final = list(
        delta_state = if (length(delta.state)) utils::tail(delta.state, 1L) else NA_real_,
        delta_sigma = if (length(delta.sigma)) utils::tail(delta.sigma, 1L) else NA_real_,
        delta_gamma = if (length(delta.gamma)) utils::tail(delta.gamma, 1L) else NA_real_,
        delta_s = if (length(delta.s)) utils::tail(delta.s, 1L) else NA_real_,
        delta_elbo = if (length(delta.elbo)) utils::tail(delta.elbo, 1L) else NA_real_
      )
    ),
    deltas = list(
      state = delta.state,
      sigma = delta.sigma,
      gamma = delta.gamma,
      s = delta.s,
      elbo = delta.elbo
    ),
    s_block = list(
      trace = s_trace_df,
      final = if (nrow(s_trace_df)) as.list(s_trace_df[nrow(s_trace_df), , drop = FALSE]) else list()
    ),
    ld_block = list(
      controls = ld_ctrl,
      setup = ld_setup,
      trace = ld_trace_df,
      final = if (nrow(ld_trace_df)) as.list(ld_trace_df[nrow(ld_trace_df), , drop = FALSE]) else list(),
      stabilization = list(
        active_final = stabilize_active,
        since_iter = stabilize_since_iter,
        reason = stabilize_reason_active,
        cycle_detect_count = if (nrow(ld_trace_df)) sum(ld_trace_df$ld_cycle_detected, na.rm = TRUE) else 0L,
        stabilized_iter_count = if (nrow(ld_trace_df)) sum(ld_trace_df$ld_stabilized, na.rm = TRUE) else 0L
      ),
      xi = list(method = "delta", mode = "delta", replicates = 0L, reuse_draws = FALSE, reuse_seed = NA_integer_),
      mode_quality = ld_mode_quality,
      signoff_summary = ld_signoff_summary
    )
  )
  retlist$converged <- isTRUE(retlist$diagnostics$convergence$converged)

  # return results
  class(retlist) <- "exdqlmLDVB"
  return(retlist)
}
