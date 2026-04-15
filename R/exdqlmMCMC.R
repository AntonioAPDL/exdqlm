#' exDQLM - MCMC algorithm
#'
#' The function applies a Markov chain Monte Carlo (MCMC) algorithm to sample the posterior of an exDQLM.
#'
#' @inheritParams exdqlmISVB
#' @param Sig.mh Covariance matrix used in the random walk MH step to jointly sample sigma and gamma.
#' @param joint.sample Logical value indicating whether or not to recompute `Sig.mh` based off the initial burn-in samples of gamma and sigma. Default is `FALSE`.
#' @param n.burn Number of MCMC iterations to burn. Default is `n.burn = 2000`.
#' @param n.mcmc Number of MCMC iterations to sample. Default is `n.mcmc = 1500`.
#' @param init.from.isvb Logical value indicating whether or not to initialize the MCMC using the ISVB algorithm. Default is `TRUE`.
#' @param init.from.vb Optional logical. If `TRUE`, run a VB pre-initialization step
#'   (`ISVB` or `LDVB`) and initialize MCMC from converged VB moments.
#'   If `NULL`, falls back to `init.from.isvb` behavior.
#' @param vb_init_controls Optional list controlling VB warm start. Supported keys:
#'   `method` (`"isvb"` or `"ldvb"`), `tol`, `n.IS`, `n.samp`, `max_iter`, `verbose`.
#' @param vb_init_fit Optional precomputed VB fit object. If supplied, warm start
#'   uses this object directly and does not rerun VB internally.
#' @param mh.proposal Character; proposal kernel for the exDQLM scale/skew block.
#'   `"laplace_rw"` (default) uses a Laplace-informed covariance then RW;
#'   `"rw"` uses joint random-walk MH on `(log sigma, logit gamma)`;
#'   `"slice"` uses
#'   an exact sigma GIG update plus a bounded univariate slice sampler directly
#'   on `gamma`.
#' @param mh.adapt Logical; adapt MH proposal scale during burn-in.
#' @param mh.adapt.interval Integer; adaptation interval (iterations).
#' @param mh.target.accept Numeric length-2 vector with lower/upper target acceptance rates.
#' @param mh.scale.bounds Numeric length-2 vector with min/max global scaling for MH covariance.
#' @param mh.max_scale.step Numeric in (0,1); maximum fractional scale change per adaptation step.
#' @param mh.min_burn_adapt Minimum burn-in iterations required to enable adaptation.
#' @param slice.width Positive numeric width for the bounded slice sampler when
#'   `mh.proposal = "slice"`. Default `0.1` for parity with `bqrgal`.
#' @param slice.max.steps Positive integer or `Inf`; maximum stepping-out
#'   expansions for the slice sampler.
#' @param trace.diagnostics Logical; if `TRUE`, retain per-iteration
#'   sigma/gamma/s/u diagnostics under `mh.diagnostics$trace`. Set `FALSE` for
#'   lighter-weight runs.
#' @param trace.every Positive integer; when `trace.diagnostics = TRUE`, record
#'   one diagnostics row every `trace.every` iterations.
#' @param progress_callback Optional callback invoked with a named list at MCMC
#'   start, at each progress checkpoint, and on completion. Intended for
#'   workflow-level progress logging.
#'
#' @return A object of class "\code{exdqlmMCMC}" containing the following:
#'  \itemize{
#'   \item `y` - Time-series data used to fit the model.
#'   \item `run.time` - Algorithm run time in seconds.
#'   \item `model` - List of the state-space model including `GG`, `FF`, prior parameters `m0` and `C0`.
#'   \item `p0` - The quantile which was estimated.
#'   \item `df` - Discount factors used for each block.
#'   \item `dim.df` - Dimension used for each block of discount factors.
#'   \item `samp.theta` - Posterior sample of the state vector.
#'   \item `samp.post.pred` - Sample of the posterior predictive distributions.
#'   \item `map.standard.forecast.errors` - MAP standardized one-step-ahead forecast errors.
#'   \item `samp.sigma` - Posterior sample of scale parameter sigma.
#'   \item `samp.vts` - Posterior sample of latent parameters, v_t.
#'   \item `theta.out` - List containing the distributions of the state vector including filtered distribution parameters (`fm` and `fC`) and smoothed distribution parameters (`sm` and `sC`).
#'   \item `n.burn` Number of MCMC iterations that were burned.
#'   \item `n.mcmc` Number of MCMC iterations that were sampled.
#' }
#' If `dqlm.ind=FALSE`, the object also contains the following:
#' \itemize{
#'   \item `samp.gamma` - Posterior sample of skewness parameter gamma.
#'   \item `samp.sts` - Posterior sample of latent parameters, s_t.
#'   \item `init.log.sigma` - Burned samples of log sigma from the random walk MH joint sampling of sigma and gamma.
#'   \item `init.logit.gamma` - Burned samples of logit gamma from the random walk MH joint sampling of sigma and gamma.
#'   \item `accept.rate` - Acceptance rate of the MH step.
#'   \item `accept.rate.burn` - MH acceptance rate during burn-in.
#'   \item `accept.rate.keep` - MH acceptance rate in kept MCMC samples.
#'   \item `Sig.mh` - Covariance matrix used in MH step to jointly sample sigma and gamma.
#'   \item `mh.diagnostics` - MH tuning diagnostics (proposal mode, scaling path, adaptation summary).
#'   \item `diagnostics` - ESS and chain-ready summaries for sigma/gamma.
#' }
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' y = scIVTmag[1:100]
#' trend.comp = polytrendMod(order = 1, m0 = stats::quantile(y, 0.85), C0 = 10)
#' seas.comp = seasMod(p = 365, h = c(1,2,4), C0 = 10*diag(6))
#' model = trend.comp + seas.comp
#' M2 = exdqlmMCMC(y, p0=0.85, model, df = c(1,1), dim.df = c(1,6),
#'                 gam.init = -3.5, sig.init = 15,
#'                 n.burn = 100, n.mcmc = 150)
#'
#' M2_al = exdqlmMCMC(y, p0=0.85, model, df = c(1,1), dim.df = c(1,6),
#'                    dqlm.ind = TRUE, sig.init = 15,
#'                    n.burn = 80, n.mcmc = 120)
#' }
#'
exdqlmMCMC <- function(y,p0,model,df,dim.df,fix.gamma=FALSE,gam.init=NA,fix.sigma=FALSE,sig.init=NA,dqlm.ind=FALSE,
                    Sig.mh,joint.sample=FALSE,n.burn=2000,n.mcmc=1500,init.from.isvb=TRUE,PriorSigma=NULL,PriorGamma=NULL,verbose=TRUE,
                    init.from.vb=NULL,vb_init_controls=NULL,vb_init_fit=NULL,
                    mh.proposal=c("laplace_rw","rw","slice"),mh.adapt=TRUE,mh.adapt.interval=50L,
                    mh.target.accept=c(0.20,0.45),mh.scale.bounds=c(0.1,10),
                    mh.max_scale.step=0.35,mh.min_burn_adapt=50L,
                    slice.width=0.1,slice.max.steps=Inf,
                    trace.diagnostics=TRUE,trace.every=1L,
                    progress_callback=NULL){

  # check inputs
  y = check_ts(y)
  model = check_mod(model)
  rv = check_logics(gam.init,sig.init,fix.gamma,fix.sigma,dqlm.ind)
  gam.init = rv$gam.init
  dqlm.ind = rv$dqlm.ind
  fix.gamma = rv$fix.gamma

  ### MCMC iterations
  if(n.mcmc<=0){
    stop("number of mcmc samples must be positive")
    }
  if(verbose & n.burn<=0){
    warning("mcmc will be sampled without burn-in, a burn-in is recommended even if initializing using the isvb algorithm")
    n.burn=0
    }
  I = n.mcmc + n.burn
  mh.proposal <- match.arg(mh.proposal)

  if (is.null(init.from.vb)) {
    init.from.vb <- isTRUE(init.from.isvb)
  }
  if (!is.null(vb_init_fit)) {
    init.from.vb <- TRUE
  }
  init.from.vb <- isTRUE(init.from.vb)

  vb.ctrl.default <- list(
    method = if (isTRUE(init.from.isvb)) "isvb" else "ldvb",
    tol = 0.5,
    n.IS = 200L,
    n.samp = 200L,
    max_iter = getOption("exdqlm.max_iter", 200L),
    verbose = FALSE
  )
  if (is.null(vb_init_controls)) vb_init_controls <- list()
  vb.ctrl <- utils::modifyList(vb.ctrl.default, vb_init_controls)
  vb.ctrl$method <- tolower(as.character(vb.ctrl$method)[1])
  if (!(vb.ctrl$method %in% c("isvb", "ldvb"))) vb.ctrl$method <- "isvb"
  vb.ctrl$tol <- as.numeric(vb.ctrl$tol)[1]
  if (!is.finite(vb.ctrl$tol) || vb.ctrl$tol <= 0) vb.ctrl$tol <- 0.5
  vb.ctrl$n.IS <- suppressWarnings(as.integer(vb.ctrl$n.IS)[1])
  if (!is.finite(vb.ctrl$n.IS) || vb.ctrl$n.IS < 20L) vb.ctrl$n.IS <- 200L
  vb.ctrl$n.samp <- suppressWarnings(as.integer(vb.ctrl$n.samp)[1])
  if (!is.finite(vb.ctrl$n.samp) || vb.ctrl$n.samp < 20L) vb.ctrl$n.samp <- 200L
  vb.ctrl$max_iter <- suppressWarnings(as.integer(vb.ctrl$max_iter)[1])
  if (!is.finite(vb.ctrl$max_iter) || vb.ctrl$max_iter < 5L) vb.ctrl$max_iter <- 200L
  vb.ctrl$verbose <- isTRUE(vb.ctrl$verbose)

  mh.adapt <- isTRUE(mh.adapt)
  mh.adapt.interval <- suppressWarnings(as.integer(mh.adapt.interval)[1])
  if (!is.finite(mh.adapt.interval) || mh.adapt.interval < 5L) mh.adapt.interval <- 50L
  mh.min_burn_adapt <- suppressWarnings(as.integer(mh.min_burn_adapt)[1])
  if (!is.finite(mh.min_burn_adapt) || mh.min_burn_adapt < 20L) mh.min_burn_adapt <- 50L
  if (length(mh.target.accept) != 2L) mh.target.accept <- c(0.20, 0.45)
  mh.target.accept <- as.numeric(mh.target.accept)
  mh.target.accept <- sort(pmin(pmax(mh.target.accept, 0.01), 0.99))
  if (length(mh.scale.bounds) != 2L) mh.scale.bounds <- c(0.1, 10)
  mh.scale.bounds <- sort(as.numeric(mh.scale.bounds))
  if (!all(is.finite(mh.scale.bounds)) || mh.scale.bounds[1] <= 0 || mh.scale.bounds[2] <= mh.scale.bounds[1]) {
    mh.scale.bounds <- c(0.1, 10)
  }
  mh.max_scale.step <- as.numeric(mh.max_scale.step)[1]
  if (!is.finite(mh.max_scale.step) || mh.max_scale.step <= 0 || mh.max_scale.step >= 1) {
    mh.max_scale.step <- 0.35
  }
  mh.laplace.refresh.interval <- suppressWarnings(as.integer(getOption("exdqlm.mcmc.laplace_refresh_interval", mh.adapt.interval))[1])
  if (!is.finite(mh.laplace.refresh.interval) || mh.laplace.refresh.interval < 5L) {
    mh.laplace.refresh.interval <- mh.adapt.interval
  }
  mh.laplace.refresh.start <- suppressWarnings(as.integer(getOption("exdqlm.mcmc.laplace_refresh_start", mh.min_burn_adapt))[1])
  if (!is.finite(mh.laplace.refresh.start) || mh.laplace.refresh.start < 1L) {
    mh.laplace.refresh.start <- mh.min_burn_adapt
  }
  mh.laplace.refresh.weight <- as.numeric(getOption("exdqlm.mcmc.laplace_refresh_weight", 0.60))[1]
  if (!is.finite(mh.laplace.refresh.weight) || mh.laplace.refresh.weight <= 0 || mh.laplace.refresh.weight > 1) {
    mh.laplace.refresh.weight <- 0.60
  }
  slice.width <- as.numeric(slice.width)[1]
  if (!is.finite(slice.width) || slice.width <= 0) slice.width <- 0.1
  slice.max.steps <- as.numeric(slice.max.steps)[1]
  if (!(is.infinite(slice.max.steps) || (is.finite(slice.max.steps) && slice.max.steps >= 1 && floor(slice.max.steps) == slice.max.steps))) {
    slice.max.steps <- Inf
  }
  trace.diagnostics <- isTRUE(trace.diagnostics)
  trace.every <- suppressWarnings(as.integer(trace.every)[1])
  if (!is.finite(trace.every) || trace.every < 1L) trace.every <- 1L
  safe_progress_callback <- function(info) {
    if (!is.function(progress_callback)) return(invisible(NULL))
    try(progress_callback(info), silent = TRUE)
    invisible(NULL)
  }

  state_signal <- function(FF_local, theta_mat) {
    drop(colSums(FF_local * theta_mat))
  }
  if (n.burn < mh.min_burn_adapt) mh.adapt <- FALSE

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
  PriorSigmaDens<-function(sigma){ LaplacesDemon::dinvgamma(sigma,shape=PriorSigma$a_sig,scale=PriorSigma$b_sig)  }
  # gamma ~ truncated student t on L,U
  PriorGamma <- .normalize_gamma_prior_trunc_t(PriorGamma)
  PriorGammaDens <- function(gamma) {
    .gamma_prior_density_trunc_t(gamma, bounds = c(L, U), PriorGamma = PriorGamma, log = FALSE)
  }

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

  ### backend controls (MCMC-specific)
  use_cpp_mcmc_opt <- isTRUE(getOption("exdqlm.use_cpp_mcmc", FALSE))
  cpp_mcmc_mode <- tolower(as.character(getOption("exdqlm.cpp_mcmc_mode", "strict")))
  if (!(cpp_mcmc_mode %in% c("strict", "fast"))) {
    warning("Invalid exdqlm.cpp_mcmc_mode; using 'strict'.")
    cpp_mcmc_mode <- "strict"
  }
  has_cpp_mcmc <- exists("mcmc_ffbs_smooth_cpp", mode = "function") &&
                  exists("mcmc_ffbs_sample_cpp", mode = "function")
  if (use_cpp_mcmc_opt && !has_cpp_mcmc) {
    warning("exdqlm.use_cpp_mcmc=TRUE but C++ MCMC FFBS kernels not available; using R backend.")
  }
  # strict mode keeps R kernels to preserve exact legacy path; fast enables C++ FFBS.
  use_cpp_mcmc <- isTRUE(use_cpp_mcmc_opt && has_cpp_mcmc && identical(cpp_mcmc_mode, "fast"))
  mcmc_backend <- if (use_cpp_mcmc) "C++" else "R"
  if (verbose) {
    cat(sprintf("MCMC backend: %s (mode=%s)\n", mcmc_backend, cpp_mcmc_mode))
  }

  cpp_ffbs_smooth <- function(ex.f, ex.q) {
    out <- mcmc_ffbs_smooth_cpp(
      GG = GG,
      m0 = as.numeric(m0),
      C0 = C0,
      FF = FF,
      y = as.numeric(y),
      ex_f = as.numeric(ex.f),
      ex_q = as.numeric(ex.q),
      df_mat = df.mat
    )
    out$standard.forecast.errors <- as.numeric(out$standard.forecast.errors)
    out$sm <- as.matrix(out$sm)
    out$fm <- as.matrix(out$fm)
    out$sC <- array(out$sC, dim = c(p, p, TT))
    out$fC <- array(out$fC, dim = c(p, p, TT))
    out
  }

  cpp_ffbs_sample <- function(ex.f, ex.q) {
    out <- mcmc_ffbs_sample_cpp(
      GG = GG,
      m0 = as.numeric(m0),
      C0 = C0,
      FF = FF,
      y = as.numeric(y),
      ex_f = as.numeric(ex.f),
      ex_q = as.numeric(ex.q),
      df_mat = df.mat
    )
    out$standard.forecast.errors <- as.numeric(out$standard.forecast.errors)
    out$sam.theta <- as.matrix(out$sam.theta)
    out$fm <- as.matrix(out$fm)
    out$fC <- array(out$fC, dim = c(p, p, TT))
    out
  }

  # function to produce smoothed estimates for return value
  smoothed_theta<-function(ex.f,ex.q){
    # initialize ffbs
    m <- sm <- matrix(NA,p,TT)
    C <- sC <- array(NA,c(p,p,TT))
    standard.forecast.errors <- rep(NA,TT)
    ## forward filter
    # first iteration
    a = as.vector(GG[,,1]%*%m0)
    P = .exdqlm_regularize_cov(GG[,,1]%*%C0%*%t(GG[,,1]), context = "mcmc_smooth_P_t1")
    R = .exdqlm_regularize_cov(P + df.mat*P, context = "mcmc_smooth_R_t1")
    f = t(FF[,1])%*%a + ex.f[1]
    q = .exdqlm_regularize_var(t(FF[,1])%*%R%*%FF[,1]  + ex.q[1], context = "mcmc_smooth_q_t1")
    m[,1] = a + t(R)%*%FF[,1]%*%(y[1]-f)/q[1]
    C[,,1] = .exdqlm_regularize_cov(
      R - t(R)%*%FF[,1]%*%t(FF[,1])%*%R/q[1],
      context = "mcmc_smooth_C_t1"
    )
    standard.forecast.errors[1] = (y[1]-f)/sqrt(q)
    # t = 2:TT
    for(t in 2:TT){
      a = as.vector(GG[,,t]%*%m[,(t-1)])
      P = .exdqlm_regularize_cov(GG[,,t]%*%C[,,(t-1)]%*%t(GG[,,t]), context = sprintf("mcmc_smooth_P_t%d", t))
      R = .exdqlm_regularize_cov(P + df.mat*P, context = sprintf("mcmc_smooth_R_t%d", t))
      f = t(FF[,t])%*%a + ex.f[t]
      fB = t(FF[,t])%*%R
      q = .exdqlm_regularize_var(fB%*%FF[,t] + ex.q[t], context = sprintf("mcmc_smooth_q_t%d", t))
      m[,t] = a + t(fB)%*%(y[t]-f)/q[1]
      C[,,t] = .exdqlm_regularize_cov(
        R - t(fB)%*%fB/q[1],
        context = sprintf("mcmc_smooth_C_t%d", t)
      )
      standard.forecast.errors[t] = (y[t]-f)/sqrt(q)
    }
    ## backwards smoothing
    sC[,,TT] = C[,,TT]
    sm[,TT] = m[,TT]
    for(t in (TT-1):1){
      P = .exdqlm_regularize_cov(GG[,,(t+1)]%*%C[,,(t)]%*%t(GG[,,(t+1)]), context = sprintf("mcmc_smooth_back_P_t%d", t + 1L))
      R.info = .exdqlm_cov_inverse(P + df.mat*P, context = sprintf("mcmc_smooth_back_R_t%d", t + 1L))
      sB = C[,,t]%*%t(GG[,,(t+1)])%*%R.info$inverse
      sm[,t] = m[,t] + sB%*%(sm[,(t+1)]-as.vector(GG[,,(t+1)]%*%m[,(t)]))
      sC[,,t] = .exdqlm_regularize_cov(
        C[,,t] + sB%*%(sC[,,(t+1)]-R.info$Sigma)%*%t(sB),
        context = sprintf("mcmc_smooth_back_C_t%d", t)
      )
    }
    return(list(standard.forecast.errors=standard.forecast.errors,sm=sm,sC=sC,fm=m,fC=C))
  }
  if (use_cpp_mcmc) {
    smoothed_theta <- function(ex.f, ex.q) cpp_ffbs_smooth(ex.f, ex.q)
  }

  ### Initialize MCMC
  init.log.sigma <- init.logit.gamma <- rep(NA,n.burn)
  save.sigma <- save.gamma <- rep(NA,n.mcmc)
  save.Ut <- save.st <- matrix(NA,TT,n.mcmc)
  save.theta <- array(NA,c(p,TT,n.mcmc))
  save.post.pred <- matrix(NA,TT,n.mcmc)
  vb.out <- NULL
  gig_backend <- "cpp_devroye_required"
  gig_eps <- 1e-12
  current_iter <- NA_integer_

  sample_gig_cpp_required <- function(chi, psi, lambda = 0.5, context = "gig") {
    if (!exists("sample_gig_devroye_vector", mode = "function")) {
      stop(sprintf("%s requires sample_gig_devroye_vector(), but it is not available", context))
    }

    chi <- as.numeric(chi)
    psi <- as.numeric(psi)[1]
    lambda <- as.numeric(lambda)[1]
    iter_suffix <- if (is.finite(current_iter)) sprintf(" (iter=%d)", current_iter) else ""

    bad <- which(!is.finite(chi))
    if (length(bad)) {
      stop(sprintf("%s%s chi has %d non-finite values (first index=%d)", context, iter_suffix, length(bad), bad[1]))
    }
    badneg <- which(chi < 0)
    if (length(badneg)) {
      stop(sprintf("%s%s chi has %d negative values (first index=%d, value=%.6g)", context, iter_suffix, length(badneg), badneg[1], chi[badneg[1]]))
    }
    if (!is.finite(psi) || psi <= 0) {
      stop(sprintf("%s%s psi must be finite and > 0; got %.6g", context, iter_suffix, psi))
    }
    if (!is.finite(lambda)) {
      stop(sprintf("%s%s lambda must be finite; got %.6g", context, iter_suffix, lambda))
    }

    chi <- pmax(chi, gig_eps)
    psi <- max(psi, gig_eps)

    draws <- as.numeric(sample_gig_devroye_vector(
      1L, p = lambda, a = psi, b_vec = chi
    )[1, ])
    bad_draws <- which(!is.finite(draws) | draws <= 0)
    if (length(bad_draws)) {
      stop(sprintf("%s%s sample_gig_devroye_vector returned %d invalid draws (first index=%d, value=%.6g)",
                   context, iter_suffix, length(bad_draws), bad_draws[1], draws[bad_draws[1]]))
    }
    pmax(draws, gig_eps)
  }

  run_vb_init <- function() {
    old_opt <- options(exdqlm.max_iter = vb.ctrl$max_iter)
    on.exit(options(old_opt), add = TRUE)
    if (vb.ctrl$method == "ldvb") {
      exdqlmLDVB(
        y = y, p0 = p0, model = model, df = df, dim.df = dim.df,
        fix.gamma = fix.gamma, gam.init = gam.init,
        fix.sigma = fix.sigma, sig.init = sig.init,
        dqlm.ind = dqlm.ind,
        tol = vb.ctrl$tol, n.samp = vb.ctrl$n.samp,
        PriorSigma = PriorSigma, PriorGamma = PriorGamma,
        verbose = vb.ctrl$verbose
      )
    } else {
      exdqlmISVB(
        y = y, p0 = p0, model = model, df = df, dim.df = dim.df,
        fix.gamma = fix.gamma, gam.init = gam.init,
        fix.sigma = fix.sigma, sig.init = sig.init,
        dqlm.ind = dqlm.ind,
        tol = vb.ctrl$tol, n.IS = vb.ctrl$n.IS, n.samp = vb.ctrl$n.samp,
        PriorSigma = PriorSigma, PriorGamma = PriorGamma,
        verbose = vb.ctrl$verbose
      )
    }
  }

  # Set initial values
  if(init.from.vb){
    if(verbose){
      cat(sprintf("running %s algorithm to initialize mcmc\n", toupper(vb.ctrl$method)))
    }
    if (!is.null(vb_init_fit)) {
      vb.out <- vb_init_fit
      if (verbose) {
        cat("using provided vb_init_fit object for MCMC initialization\n")
      }
    } else {
      vb.out <- run_vb_init()
    }
    cursam.sigma <- ifelse(fix.sigma,sig.init,ifelse(dqlm.ind,vb.out$sig.out$E.sigma,vb.out$gammasig.out$E.sigma))
    cursam.Ut <- vb.out$vts.out$E.uts
    cursam.theta <- vb.out$theta.out$sm
  }else{
    cursam.sigma <- m_sigma
    cursam.Ut <- rep(1/m_sigma,TT)
    cursam.theta <- matrix(m0,p,TT)
  }

  if (verbose) {
    cat("GIG backend: C++ Devroye (required)\n")
  }

  ######## exDQLM
  if(!dqlm.ind){

    ### Define logit and inverse logit functions
    logit = function(x){log((x-L)/(U-x))}
    inv.logit = function(x){(U*exp(x)+L)/(exp(x)+1)}
    log_prior_gamma <- function(gamma) {
      .gamma_log_prior_trunc_t(gamma, bounds = c(L, U), PriorGamma = PriorGamma)
    }

    ### Additional initial values
    if(!is.null(vb.out)){
      cursam.st <- vb.out$sts.out$E.sts
      cursam.gamma <- ifelse(fix.gamma,gam.init,vb.out$gammasig.out$E.gam)
      cursam.logit.gamma <- logit(cursam.gamma)
      cursam.log.sigma <- log(cursam.sigma)
    }else{
      cursam.st <- truncnorm::rtruncnorm(TT,a=0,b=Inf,mean=0,sd=1)
      cursam.gamma <- ifelse(!is.na(gam.init),gam.init,(L+U)/2)
      cursam.logit.gamma <- logit(cursam.gamma)
      cursam.log.sigma <- log(cursam.sigma)
    }

    ### Initialize MH
    n.accept = 0
    n.accept.burn = 0L
    n.accept.keep = 0L
    n.trial.burn = 0L
    n.trial.keep = 0L
    adapt.history <- data.frame(
      iter = integer(0),
      window_accept = numeric(0),
      mh_scale = numeric(0),
      sig11 = numeric(0),
      sig22 = numeric(0),
      laplace_refreshed = logical(0),
      stringsAsFactors = FALSE
    )
    trace_rows <- if (trace.diagnostics) vector("list", ceiling(I / trace.every)) else NULL
    trace_idx <- 0L
    mh.scale <- 1
    window.accept <- 0L
    window.total <- 0L
    laplace_refresh_attempts <- 0L
    laplace_refresh_success <- 0L

    prep_Sig_mh <- function(S) {
      S <- suppressWarnings(as.matrix(S))
      if (!all(dim(S) == c(2L, 2L))) {
        S <- diag(c(ifelse(fix.sigma, 0, 0.005), ifelse(fix.gamma, 0, 0.005)))
      }
      S[!is.finite(S)] <- 0
      S <- (S + t(S)) / 2
      if (fix.sigma) {
        S[1, ] <- 0
        S[, 1] <- 0
      }
      if (fix.gamma) {
        S[2, ] <- 0
        S[, 2] <- 0
      }
      for (j in 1:2) {
        if (!is.finite(S[j, j]) || S[j, j] < 0) S[j, j] <- 0
      }
      if (!fix.sigma && S[1, 1] <= 0) S[1, 1] <- 0.005
      if (!fix.gamma && S[2, 2] <= 0) S[2, 2] <- 0.005
      S
    }
    build_chol <- function(S) {
      S <- prep_Sig_mh(S)
      if (fix.gamma || fix.sigma) {
        sqrt(S)
      } else {
        out <- tryCatch(t(chol(S)), error = function(e) NULL)
        if (is.null(out)) {
          eig <- eigen(S, symmetric = TRUE)
          vals <- pmax(eig$values, 1e-8)
          out <- eig$vectors %*% diag(sqrt(vals), 2, 2) %*% t(eig$vectors)
        }
        out
      }
    }

    if(!methods::hasArg(Sig.mh)){
      if(!is.null(vb.out)){
        sig.samples <- NULL
        gam.samples <- NULL
        if (!is.null(vb.out$gammasig.out$sigma.samples) && !is.null(vb.out$gammasig.out$gamma.samples)) {
          sig.samples <- as.numeric(vb.out$gammasig.out$sigma.samples)
          gam.samples <- as.numeric(vb.out$gammasig.out$gamma.samples)
        } else if (!is.null(vb.out$samp.sigma) && !is.null(vb.out$samp.gamma)) {
          sig.samples <- as.numeric(vb.out$samp.sigma)
          gam.samples <- as.numeric(vb.out$samp.gamma)
        }
        if (!is.null(sig.samples) && !is.null(gam.samples) &&
            all(is.finite(sig.samples)) && all(sig.samples > 0) &&
            all(is.finite(gam.samples)) && all(gam.samples > L) && all(gam.samples < U)) {
          Sig.mh <- stats::cov(cbind(log(sig.samples), logit(gam.samples)))
        } else {
          Sig.mh <- diag(c(ifelse(fix.sigma,0,0.005),ifelse(fix.gamma,0,0.005)))
        }
      }else{
        Sig.mh = diag(c(ifelse(fix.sigma,0,0.005),ifelse(fix.gamma,0,0.005)))
      }
    }
    Sig.mh <- prep_Sig_mh(Sig.mh)
    Sig.mh.initial <- Sig.mh
    chol_Sig.mh <- build_chol(Sig.mh)

    # exdqlm function sample theta ffbs
    ex_samp_theta<-function(ex.f,ex.q,gamma,sigma,sts,tau,c_tau){
      # initialize ffbs
      m <- sam.theta <- matrix(NA,p,TT)
      C <- array(NA,c(p,p,TT))
      standard.forecast.errors <- post.pred <- rep(NA,TT)
      ## forward filter
      # first iteration
      a = as.vector(GG[,,1]%*%m0)
      P = .exdqlm_regularize_cov(GG[,,1]%*%C0%*%t(GG[,,1]), context = "mcmc_dqlm_sample_P_t1")
      R = .exdqlm_regularize_cov(P + df.mat*P, context = "mcmc_dqlm_sample_R_t1")
      f = t(FF[,1])%*%a + ex.f[1]
      q = .exdqlm_regularize_var(t(FF[,1])%*%R%*%FF[,1] + ex.q[1], context = "mcmc_dqlm_sample_q_t1")
      m[,1] = a + t(R)%*%FF[,1]%*%(y[1]-f)/q[1]
      C[,,1] = .exdqlm_regularize_cov(
        R - t(R)%*%FF[,1]%*%t(FF[,1])%*%R/q[1],
        context = "mcmc_dqlm_sample_C_t1"
      )
      standard.forecast.errors[1] = (y[1]-f)/sqrt(q)
      # t = 2:TT
      for(t in 2:TT){
        a = as.vector(GG[,,t]%*%m[,(t-1)])
        P = .exdqlm_regularize_cov(GG[,,t]%*%C[,,(t-1)]%*%t(GG[,,t]), context = sprintf("mcmc_dqlm_sample_P_t%d", t))
        R = .exdqlm_regularize_cov(P + df.mat*P, context = sprintf("mcmc_dqlm_sample_R_t%d", t))
        f = t(FF[,t])%*%a + ex.f[t]
        fB = t(FF[,t])%*%R
        q = .exdqlm_regularize_var(fB%*%FF[,t] + ex.q[t], context = sprintf("mcmc_dqlm_sample_q_t%d", t))
        m[,t] = a + t(fB)%*%(y[t]-f)/q[1]
        C[,,t] = .exdqlm_regularize_cov(
          R - t(fB)%*%fB/q[1],
          context = sprintf("mcmc_dqlm_sample_C_t%d", t)
        )
        standard.forecast.errors[t] = (y[t]-f)/sqrt(q)
      }
      ## backwards sample
      sC_TT = .exdqlm_regularize_cov(C[,,TT], context = "mcmc_dqlm_sample_sC_TT")
      svd.sC = svd(sC_TT)
      sam.theta[,TT] = m[,TT] + svd.sC$u%*%diag(sqrt(svd.sC$d),p)%*%stats::rnorm(p,0,1)
      reg_theta <- numeric(TT)
      reg_theta[TT] <- drop(crossprod(FF[,TT], sam.theta[,TT]))
      post.pred[TT] = rexal(1,tau,reg_theta[TT]+c_tau*sigma*abs(gamma)*sts[TT],sigma,0)
      for(t in (TT-1):1){
        P = .exdqlm_regularize_cov(GG[,,(t+1)]%*%C[,,(t)]%*%t(GG[,,(t+1)]), context = sprintf("mcmc_dqlm_back_P_t%d", t + 1L))
        R.info = .exdqlm_cov_inverse(P + df.mat*P, context = sprintf("mcmc_dqlm_back_R_t%d", t + 1L))
        sB = C[,,t]%*%t(GG[,,(t+1)])%*%R.info$inverse
        sm = m[,t] + sB%*%(sam.theta[,(t+1)]-as.vector(GG[,,(t+1)]%*%m[,(t)]))
        sC = .exdqlm_regularize_cov(
          C[,,t] - sB%*%GG[,,(t+1)]%*%C[,,t],
          context = sprintf("mcmc_dqlm_back_sC_t%d", t)
        )
        svd.sC = svd(sC)
        sam.theta[,t] = sm + svd.sC$u%*%diag(sqrt(svd.sC$d),p)%*%stats::rnorm(p,0,1)
        reg_theta[t] <- drop(crossprod(FF[,t], sam.theta[,t]))
        post.pred[t] = rexal(1,tau,reg_theta[t]+c_tau*sigma*abs(gamma)*sts[t],sigma,0)
      }
      return(list(standard.forecast.errors=standard.forecast.errors,post.pred=post.pred,sam.theta=sam.theta,fm=m,fC=C))
    }
    if (use_cpp_mcmc) {
      ex_samp_theta <- function(ex.f, ex.q, gamma, sigma, sts, tau, c_tau) {
        out <- cpp_ffbs_sample(ex.f, ex.q)
        sam.theta <- out$sam.theta
        reg_theta <- state_signal(FF, sam.theta)
        post.pred <- vapply(seq_len(TT), function(t) {
          rexal(1, tau,
                reg_theta[t] + c_tau * sigma * abs(gamma) * sts[t],
                sigma, 0)
        }, numeric(1))
        list(
          standard.forecast.errors = out$standard.forecast.errors,
          post.pred = post.pred,
          sam.theta = sam.theta,
          fm = out$fm,
          fC = out$fC
        )
      }
    }

    # exdqlm function sample uts
    ex_samp_uts<-function(reg1,gamma,sigma,sts,a_tau,b_tau,c_tau){
      chi <- as.numeric(((y-reg1-sigma*c_tau*abs(gamma)*sts)^2)/(b_tau*sigma))
      psi <- (a_tau^2)/(b_tau*sigma) + (2/sigma)
      sample_gig_cpp_required(chi = chi, psi = psi, lambda = 0.5, context = "exdqlm_mcmc_uts")
    }

    # exdqlm function sample sts
    ex_samp_sts<-function(reg1,gamma,sigma,uts,a_tau,b_tau,c_tau){
      s.sig2<-1/(1+c_tau^2*abs(gamma)^2*sigma/(b_tau*uts))
      s.sig2<-pmax(s.sig2, 1e-12)
      s.mu<-s.sig2*c_tau*abs(gamma)*(y-(reg1+a_tau*uts))/(b_tau*uts)
      truncnorm::rtruncnorm(TT,rep(0,TT),rep(Inf,TT),s.mu,sqrt(s.sig2))
    }

    # exdqlm function sample sigma and gamma
    logL<-function(reg1,log.sigma,logit.gamma,sts,uts){
      sigma=exp(log.sigma); gamma=inv.logit(logit.gamma)
      temp.p = p.fn(p0,gamma)
      a = (1-2*temp.p)/(temp.p*(1-temp.p))
      b = (2)/(temp.p*(1-temp.p))
      c = (as.numeric(gamma>0)-temp.p)^(-1)
      logJ<-logit.gamma-2*log(1+exp(logit.gamma))+log.sigma
      PriorGamma<- PriorGammaDens(gamma)
      PriorSigma<- PriorSigmaDens(sigma)
      sum(stats::dnorm(y,reg1+sigma*c*abs(gamma)*sts+a*uts,sqrt(sigma*b*uts),log = TRUE)) +
        sum(stats::dexp(uts,rate = 1/sigma,log=TRUE)) +
        log(PriorSigma) + log(PriorGamma) + logJ
    }
    make_logpost_gamma <- function(reg1, sigma, sts, uts) {
      sigma <- as.numeric(sigma)[1]
      reg1 <- as.numeric(reg1)
      sts <- as.numeric(sts)
      uts <- as.numeric(uts)
      valid_inputs <- is.finite(sigma) && sigma > 0 &&
        all(is.finite(reg1)) && all(is.finite(sts)) && all(is.finite(uts)) &&
        all(uts > 0)
      if (!valid_inputs) {
        return(function(gamma) -Inf)
      }

      y_center <- y - reg1
      sigma_sts <- sigma * sts
      sqrt_sigma_uts <- sqrt(sigma * uts)

      function(gamma) {
        gamma <- as.numeric(gamma)[1]
        if (!is.finite(gamma) || gamma <= L || gamma >= U) return(-Inf)

        temp.p <- p.fn(p0, gamma)
        a <- (1 - 2 * temp.p) / (temp.p * (1 - temp.p))
        b <- 2 / (temp.p * (1 - temp.p))
        c <- (as.numeric(gamma > 0) - temp.p)^(-1)
        if (!all(is.finite(c(a, b, c))) || b <= 0) return(-Inf)

        mu_shift <- c * abs(gamma) * sigma_sts + a * uts
        ll <- sum(stats::dnorm(
          y_center,
          mean = mu_shift,
          sd = sqrt(b) * sqrt_sigma_uts,
          log = TRUE
        ))
        lp <- log_prior_gamma(gamma)
        if (!is.finite(ll) || !is.finite(lp)) return(-Inf)
        ll + lp
      }
    }
    samp_sigma_exact <- function(reg1, sigma, gamma, sts, uts) {
      temp.p <- p.fn(p0, gamma)
      a <- (1 - 2 * temp.p) / (temp.p * (1 - temp.p))
      b <- 2 / (temp.p * (1 - temp.p))
      c <- (as.numeric(gamma > 0) - temp.p)^(-1)

      r <- y - reg1 - a * uts
      chi_sigma <- sum((r * r) / (b * uts)) + 2 * sum(uts) + 2 * PriorSigma$b_sig
      psi_sigma <- ((c * abs(gamma))^2 / b) * sum((sts * sts) / uts)
      k_sigma <- -(PriorSigma$a_sig + 1.5 * TT)
      sigma_new <- as.numeric(sample_gig_devroye_vector(
        1L, p = k_sigma, a = psi_sigma, b_vec = chi_sigma
      )[1, 1])
      if (is.finite(sigma_new) && sigma_new > 0) sigma_new else sigma
    }
    laplace_cov_init <- function(reg1, log.sigma, logit.gamma, sts, uts) {
      fn <- function(z) {
        val <- logL(reg1, z[1], z[2], sts, uts)
        if (is.finite(val)) -val else 1e12
      }
      opt <- tryCatch(
        stats::optim(c(log.sigma, logit.gamma), fn = fn, method = "BFGS",
                     control = list(maxit = 100), hessian = TRUE),
        error = function(e) NULL
      )
      H <- if (!is.null(opt) && !is.null(opt$hessian)) opt$hessian else NULL
      if (is.null(H) || any(!is.finite(H))) {
        H <- tryCatch(numDeriv::hessian(fn, x = c(log.sigma, logit.gamma)), error = function(e) NULL)
      }
      if (is.null(H) || any(!is.finite(H))) return(NULL)
      H <- (H + t(H)) / 2
      eig <- eigen(H, symmetric = TRUE)
      vals <- pmax(eig$values, 1e-6)
      cov <- eig$vectors %*% diag(1 / vals, 2, 2) %*% t(eig$vectors)
      cov
    }
    if (identical(mh.proposal, "laplace_rw") && !fix.gamma && !fix.sigma) {
      reg1.init <- state_signal(FF, cursam.theta)
      cov.lap <- laplace_cov_init(reg1.init, cursam.log.sigma, cursam.logit.gamma, cursam.st, cursam.Ut)
      if (!is.null(cov.lap)) {
        Sig.mh <- prep_Sig_mh(cov.lap)
      }
    }
    chol_Sig.mh <- build_chol(Sig.mh * (mh.scale^2))

    ex_samp_lsiglgam<-function(reg1,log.sigma,logit.gamma,sts,uts,chol_Sig){
      prop<-c(log.sigma,logit.gamma)+chol_Sig%*%stats::rnorm(2)
      if(inv.logit(prop[2]) < U && inv.logit(prop[2]) > L){
        logr<-logL(reg1,prop[1],prop[2],sts,uts)-logL(reg1,log.sigma,logit.gamma,sts,uts)
        accept=(log(stats::runif(1))<logr)
      }else{
        accept=FALSE
      }
      log.sigma.new<-accept*prop[1]+(1-accept)*log.sigma
      logit.gamma.new<-accept*prop[2]+(1-accept)*logit.gamma
      return(list(log.sigma=log.sigma.new,logit.gamma=logit.gamma.new,accept=accept))
    }

    progress_every_env <- suppressWarnings(as.integer(Sys.getenv("EXDQLM_MCMC_PROGRESS_EVERY", NA_character_))[1])
    progress_every <- if (is.finite(progress_every_env) && !is.na(progress_every_env) && progress_every_env >= 1L) {
      progress_every_env
    } else if (trace.diagnostics) {
      trace.every
    } else {
      100L
    }
    progress_every <- max(1L, as.integer(progress_every)[1])

    # Sample from exdqlm posterior
    tictoc::tic()
    safe_progress_callback(list(
      event = "start",
      iter = 0L,
      total_iter = as.integer(I),
      phase = "burn",
      n_burn = as.integer(n.burn),
      n_mcmc = as.integer(n.mcmc),
      sigma = cursam.sigma,
      gamma = cursam.gamma,
      kernel = mh.proposal,
      accept = if (identical(mh.proposal, "slice")) NA_real_ else 0
    ))
    for (i in 1:I){
      current_iter <- as.integer(i)
      # counter
      if(verbose & i%%progress_every==0){
        acc_msg <- if (identical(mh.proposal, "slice")) "NA" else round(n.accept / i, 4)
        cat(sprintf("%s iteration %s, acceptance rate %s: %s", ifelse(i<=n.burn,"burn-in","MCMC"), i , acc_msg, Sys.time()),"\n")
        utils::flush.console()
        try(flush(stdout()), silent = TRUE)
        }
      if (i %% progress_every == 0L) {
        safe_progress_callback(list(
          event = "progress",
          iter = as.integer(i),
          total_iter = as.integer(I),
          phase = if (i <= n.burn) "burn" else "keep",
          n_burn = as.integer(n.burn),
          n_mcmc = as.integer(n.mcmc),
          sigma = cursam.sigma,
          gamma = cursam.gamma,
          kernel = mh.proposal,
          accept = if (identical(mh.proposal, "slice")) NA_real_ else n.accept / i
        ))
      }

      # exAL parameters
      tau = p.fn(p0,cursam.gamma)
      a_tau = (1-2*tau)/(tau*(1-tau))
      b_tau = (2)/(tau*(1-tau))
      c_tau = (as.numeric(cursam.gamma>0)-tau)^(-1)

      # sample theta
      ex.f = cursam.sigma*c_tau*abs(cursam.gamma)*cursam.st + cursam.Ut*a_tau
      ex.q = b_tau*cursam.Ut*cursam.sigma
      theta.out <- ex_samp_theta(ex.f,ex.q,cursam.gamma,cursam.sigma,cursam.st,tau,c_tau)
      cursam.theta = theta.out$sam.theta

      # sample uts, sts
      reg1 = state_signal(FF, cursam.theta)
      cursam.Ut<-ex_samp_uts(reg1,cursam.gamma,cursam.sigma,cursam.st,a_tau,b_tau,c_tau)
      cursam.st<-ex_samp_sts(reg1,cursam.gamma,cursam.sigma,cursam.Ut,a_tau,b_tau,c_tau)

      # sample sigma and gamma
      if (identical(mh.proposal, "slice")) {
        if (!fix.sigma) {
          cursam.sigma <- samp_sigma_exact(reg1, cursam.sigma, cursam.gamma, cursam.st, cursam.Ut)
          cursam.log.sigma <- log(cursam.sigma)
        }
        gamma_log_density <- make_logpost_gamma(reg1, cursam.sigma, cursam.st, cursam.Ut)
        slice_evals <- NA_integer_
        if (!fix.gamma) {
          current_lp <- gamma_log_density(cursam.gamma)
          if (!is.finite(current_lp)) {
            cursam.gamma <- min(max(cursam.gamma, L + 1e-8), U - 1e-8)
            current_lp <- gamma_log_density(cursam.gamma)
          }
          if (!is.finite(current_lp)) {
            cursam.gamma <- min(max(0, L + 1e-8), U - 1e-8)
          }
          slice_out <- .exdqlm_uni_slice_bounded(
            x0 = cursam.gamma,
            log_density = gamma_log_density,
            w = slice.width,
            m = slice.max.steps,
            lower = L + 1e-10,
            upper = U - 1e-10
          )
          cursam.gamma <- as.numeric(slice_out$value)[1]
          slice_evals <- as.integer(slice_out$evals)
        }
        cursam.logit.gamma <- logit(cursam.gamma)
        lsiglgam.out <- list(
          log.sigma = cursam.log.sigma,
          logit.gamma = cursam.logit.gamma,
          accept = NA,
          slice_evals = slice_evals
        )
      } else {
        lsiglgam.out<-ex_samp_lsiglgam(reg1,cursam.log.sigma,cursam.logit.gamma,cursam.st,cursam.Ut,chol_Sig.mh)
        cursam.gamma<-inv.logit(lsiglgam.out$logit.gamma)
        cursam.logit.gamma<-lsiglgam.out$logit.gamma
        cursam.sigma<-exp(lsiglgam.out$log.sigma)
        cursam.log.sigma<-lsiglgam.out$log.sigma
        n.accept = n.accept + lsiglgam.out$accept
      }
      if (trace.diagnostics && (i %% trace.every == 0L)) {
        s_stats <- .exdqlm_trace_summary(cursam.st)
        u_stats <- .exdqlm_trace_summary(cursam.Ut)
        trace_idx <- trace_idx + 1L
        trace_rows[[trace_idx]] <- data.frame(
          iter = i,
          phase = if (i <= n.burn) "burn" else "keep",
          sigma = cursam.sigma,
          gamma = cursam.gamma,
          accepted = if (identical(mh.proposal, "slice")) NA else isTRUE(lsiglgam.out$accept),
          mh_scale = if (identical(mh.proposal, "slice")) NA_real_ else mh.scale,
          slice_evals = if (!is.null(lsiglgam.out$slice_evals)) lsiglgam.out$slice_evals else NA_integer_,
          s_mean = s_stats[["mean"]],
          s_sd = s_stats[["sd"]],
          s_q05 = s_stats[["q05"]],
          s_q50 = s_stats[["median"]],
          s_q95 = s_stats[["q95"]],
          s_min = s_stats[["min"]],
          s_max = s_stats[["max"]],
          u_mean = u_stats[["mean"]],
          u_sd = u_stats[["sd"]],
          u_q05 = u_stats[["q05"]],
          u_q50 = u_stats[["median"]],
          u_q95 = u_stats[["q95"]],
          u_min = u_stats[["min"]],
          u_max = u_stats[["max"]],
          stringsAsFactors = FALSE
        )
      }

      # save samples after burn
      if(i <= n.burn){
        if (!identical(mh.proposal, "slice")) {
          n.trial.burn <- n.trial.burn + 1L
          n.accept.burn <- n.accept.burn + as.integer(isTRUE(lsiglgam.out$accept))
          window.accept <- window.accept + as.integer(isTRUE(lsiglgam.out$accept))
          window.total <- window.total + 1L
        }
        init.log.sigma[i] = cursam.log.sigma
        init.logit.gamma[i] = cursam.logit.gamma
        laplace_refreshed <- FALSE
        if (identical(mh.proposal, "laplace_rw") && !fix.gamma && !fix.sigma &&
            i >= mh.laplace.refresh.start && i < n.burn &&
            (i %% mh.laplace.refresh.interval == 0)) {
          laplace_refresh_attempts <- laplace_refresh_attempts + 1L
          cov.lap.step <- laplace_cov_init(reg1, cursam.log.sigma, cursam.logit.gamma, cursam.st, cursam.Ut)
          if (!is.null(cov.lap.step) && all(is.finite(cov.lap.step))) {
            cov.lap.step <- prep_Sig_mh(cov.lap.step)
            Sig.mh <- prep_Sig_mh((1 - mh.laplace.refresh.weight) * Sig.mh + mh.laplace.refresh.weight * cov.lap.step)
            laplace_refreshed <- TRUE
            laplace_refresh_success <- laplace_refresh_success + 1L
          }
        }
        if (!identical(mh.proposal, "slice") && mh.adapt && i >= mh.min_burn_adapt && i < n.burn && (i %% mh.adapt.interval == 0)) {
          acc.win <- window.accept / pmax(window.total, 1L)
          if (acc.win < mh.target.accept[1]) {
            mh.scale <- mh.scale * (1 - mh.max_scale.step)
          } else if (acc.win > mh.target.accept[2]) {
            mh.scale <- mh.scale * (1 + mh.max_scale.step)
          }
          mh.scale <- min(max(mh.scale, mh.scale.bounds[1]), mh.scale.bounds[2])
          Sig.scaled <- prep_Sig_mh(Sig.mh * (mh.scale^2))
          chol_Sig.mh <- build_chol(Sig.scaled)
          adapt.history <- rbind(
            adapt.history,
            data.frame(
              iter = i,
              window_accept = acc.win,
              mh_scale = mh.scale,
              sig11 = Sig.scaled[1, 1],
              sig22 = Sig.scaled[2, 2],
              laplace_refreshed = isTRUE(laplace_refreshed),
              stringsAsFactors = FALSE
            )
          )
          window.accept <- 0L
          window.total <- 0L
        }
        if(!identical(mh.proposal, "slice") && i==n.burn && joint.sample){
          Sig.mh = stats::cov(cbind(init.log.sigma[1:n.burn],init.logit.gamma[1:n.burn]))
          Sig.mh <- prep_Sig_mh(Sig.mh)
          chol_Sig.mh <- build_chol(Sig.mh * (mh.scale^2))
          }
      }else{
        if (!identical(mh.proposal, "slice")) {
          n.trial.keep <- n.trial.keep + 1L
          n.accept.keep <- n.accept.keep + as.integer(isTRUE(lsiglgam.out$accept))
        }
        save.sigma[(i-n.burn)] = cursam.sigma
        save.gamma[(i-n.burn)] = cursam.gamma
        save.theta[,,(i-n.burn)] = cursam.theta
        save.Ut[,(i-n.burn)] = cursam.Ut
        save.st[,(i-n.burn)] = cursam.st
        save.post.pred[,(i-n.burn)] = theta.out$post.pred
      }

    }
    run.time = tictoc::toc(quiet = TRUE)
    if(verbose){
      cat(sprintf("MCMC complete: %s iterations, %s seconds",I,round(run.time$toc-run.time$tic,3)),"\n")
    }
    safe_progress_callback(list(
      event = "complete",
      iter = as.integer(I),
      total_iter = as.integer(I),
      phase = "done",
      n_burn = as.integer(n.burn),
      n_mcmc = as.integer(n.mcmc),
      sigma = cursam.sigma,
      gamma = cursam.gamma,
      kernel = mh.proposal,
      accept = if (identical(mh.proposal, "slice")) NA_real_ else n.accept / I,
      runtime_sec = as.numeric(run.time$toc - run.time$tic)
    ))

    # exdqlm MAP standard forecast errors
    map.gam = mean(save.gamma)
    map.sig = mean(save.sigma)
    map.st = rowMeans(save.st)
    map.Ut = rowMeans(save.Ut)
    tau = p.fn(p0,map.gam)
    a_tau = (1-2*tau)/(tau*(1-tau))
    b_tau = (2)/(tau*(1-tau))
    c_tau = (as.numeric(map.gam>0)-tau)^(-1)
    theta.out <- smoothed_theta(map.sig*c_tau*abs(map.gam)*map.st+map.Ut*a_tau,b_tau*map.Ut*map.sig)
    map.standard.forecast.errors = theta.out$standard.forecast.errors

    Sig.mh.final <- prep_Sig_mh(Sig.mh * (mh.scale^2))
    ess_sigma <- tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.sigma))), error = function(e) NA_real_)
    ess_gamma <- tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.gamma))), error = function(e) NA_real_)
    chain_health_sigma <- .exdqlm_chain_health_metrics(save.sigma, n_keep = n.mcmc)
    chain_health_gamma <- .exdqlm_chain_health_metrics(save.gamma, n_keep = n.mcmc)
    accept_total <- if (identical(mh.proposal, "slice")) NA_real_ else n.accept / I
    accept_burn <- if (identical(mh.proposal, "slice")) NA_real_ else if (n.trial.burn > 0) n.accept.burn / n.trial.burn else NA_real_
    accept_keep <- if (identical(mh.proposal, "slice")) NA_real_ else if (n.trial.keep > 0) n.accept.keep / n.trial.keep else NA_real_
    kernel_exact <- mh.proposal %in% c("rw", "laplace_rw", "slice")
    mh.diag <- list(
      proposal = mh.proposal,
      adapt = if (identical(mh.proposal, "slice")) FALSE else mh.adapt,
      joint_sample = isTRUE(joint.sample),
      adapt_interval = if (identical(mh.proposal, "slice")) NA_integer_ else mh.adapt.interval,
      target_accept = if (identical(mh.proposal, "slice")) c(NA_real_, NA_real_) else mh.target.accept,
      scale_bounds = if (identical(mh.proposal, "slice")) c(NA_real_, NA_real_) else mh.scale.bounds,
      scale_final = if (identical(mh.proposal, "slice")) NA_real_ else mh.scale,
      joint_sigma_gamma = mh.proposal %in% c("rw", "laplace_rw"),
      transformed_state = if (mh.proposal %in% c("rw", "laplace_rw")) c("log_sigma", "logit_gamma") else c("gamma"),
      # Backward-compatible aliases used by some diagnostics scripts.
      final_scale = if (identical(mh.proposal, "slice")) NA_real_ else mh.scale,
      slice_width = if (identical(mh.proposal, "slice")) slice.width else NA_real_,
      slice_max_steps = if (identical(mh.proposal, "slice")) slice.max.steps else NA_real_,
      laplace_refresh = list(
        enabled = identical(mh.proposal, "laplace_rw"),
        interval = if (identical(mh.proposal, "laplace_rw")) as.integer(mh.laplace.refresh.interval) else NA_integer_,
        start = if (identical(mh.proposal, "laplace_rw")) as.integer(mh.laplace.refresh.start) else NA_integer_,
        weight = if (identical(mh.proposal, "laplace_rw")) as.numeric(mh.laplace.refresh.weight) else NA_real_,
        attempts = if (identical(mh.proposal, "laplace_rw")) as.integer(laplace_refresh_attempts) else NA_integer_,
        success = if (identical(mh.proposal, "laplace_rw")) as.integer(laplace_refresh_success) else NA_integer_
      ),
      kernel_exact = kernel_exact,
      signoff_ready = kernel_exact,
      approximation_note = NA_character_,
      accept = list(
        total = accept_total,
        burn = accept_burn,
        kept = accept_keep,
        n_accept = if (identical(mh.proposal, "slice")) NA_integer_ else n.accept,
        n_total = if (identical(mh.proposal, "slice")) NA_integer_ else I
      ),
      Sig.mh.initial = if (identical(mh.proposal, "slice")) matrix(NA_real_, 2, 2) else Sig.mh.initial,
      Sig.mh.final = if (identical(mh.proposal, "slice")) matrix(NA_real_, 2, 2) else Sig.mh.final,
      adaptation = if (identical(mh.proposal, "slice")) data.frame() else adapt.history,
      adapt_trace = if (identical(mh.proposal, "slice")) data.frame() else adapt.history,
      trace_enabled = trace.diagnostics,
      trace_every = if (trace.diagnostics) trace.every else NA_integer_,
      trace = if (trace.diagnostics && trace_idx > 0L) {
        do.call(rbind, trace_rows[seq_len(trace_idx)])
      } else {
        data.frame()
      }
    )

    # exdqlm results
    retlist = list(y=y,run.time=(run.time$toc-run.time$tic),model=model,p0=p0,df=df,dim.df=dim.df,
                samp.theta = coda::as.mcmc(save.theta), theta.out = theta.out,
                samp.post.pred = save.post.pred, map.standard.forecast.errors = map.standard.forecast.errors,
                samp.sigma = coda::as.mcmc(save.sigma), samp.gamma = coda::as.mcmc(save.gamma),
                init.log.sigma = coda::as.mcmc(init.log.sigma), init.logit.gamma = coda::as.mcmc(init.logit.gamma),
                samp.vts = coda::as.mcmc(save.Ut), samp.sts = coda::as.mcmc(save.st),
                accept.rate = accept_total,
                accept.rate.burn = accept_burn,
                accept.rate.keep = accept_keep,
                Sig.mh = if (identical(mh.proposal, "slice")) matrix(NA_real_, 2, 2) else Sig.mh.final,
                init.from.vb = init.from.vb,
                vb.init.method = if (init.from.vb) vb.ctrl$method else NA_character_,
                mh.diagnostics = mh.diag,
                diagnostics = list(
                  mh = mh.diag,
                  ess = list(sigma = ess_sigma, gamma = ess_gamma),
                  chain_health = list(
                    sigma = chain_health_sigma,
                    gamma = chain_health_gamma
                  ),
                  s_block = list(
                    trace = mh.diag$trace,
                    final = if (is.data.frame(mh.diag$trace) && nrow(mh.diag$trace)) {
                      as.list(mh.diag$trace[nrow(mh.diag$trace), , drop = FALSE])
                    } else {
                      list()
                    }
                  ),
                  rhat_ready = list(
                    sigma = as.numeric(save.sigma),
                    gamma = as.numeric(save.gamma)
                  )
                ),
                n.burn=n.burn,n.mcmc=n.mcmc)

  }else{
    ######## DQLM

    # fixed AL parameters
    a_tau = (1-2*p0)/(p0*(1-p0))
    b_tau = (2)/(p0*(1-p0))

    # dqlm function sample theta ffbs
    samp_theta<-function(ex.f,ex.q,sigma){
      # initialize ffbs
      m <- sam.theta <- matrix(NA,p,TT)
      C <- array(NA,c(p,p,TT))
      standard.forecast.errors <- post.pred <- rep(NA,TT)
      ## forward filter
      # first iteration
      a = as.vector(GG[,,1]%*%m0)
      P = .exdqlm_regularize_cov(GG[,,1]%*%C0%*%t(GG[,,1]), context = "mcmc_al_sample_P_t1")
      R = .exdqlm_regularize_cov(P + df.mat*P, context = "mcmc_al_sample_R_t1")
      f = t(FF[,1])%*%a + ex.f[1]
      q = .exdqlm_regularize_var(t(FF[,1])%*%R%*%FF[,1] + ex.q[1], context = "mcmc_al_sample_q_t1")
      m[,1] = a + t(R)%*%FF[,1]%*%(y[1]-f)/q[1]
      C[,,1] = .exdqlm_regularize_cov(
        R - t(R)%*%FF[,1]%*%t(FF[,1])%*%R/q[1],
        context = "mcmc_al_sample_C_t1"
      )
      standard.forecast.errors[1] = (y[1]-f)/sqrt(q)
      # t = 2:TT
      for(t in 2:TT){
        a = as.vector(GG[,,t]%*%m[,(t-1)])
        P = .exdqlm_regularize_cov(GG[,,t]%*%C[,,(t-1)]%*%t(GG[,,t]), context = sprintf("mcmc_al_sample_P_t%d", t))
        R = .exdqlm_regularize_cov(P + df.mat*P, context = sprintf("mcmc_al_sample_R_t%d", t))
        f = t(FF[,t])%*%a + ex.f[t]
        fB = t(FF[,t])%*%R
        q = .exdqlm_regularize_var(fB%*%FF[,t] + ex.q[t], context = sprintf("mcmc_al_sample_q_t%d", t))
        m[,t] = a + t(fB)%*%(y[t]-f)/q[1]
        C[,,t] = .exdqlm_regularize_cov(
          R - t(fB)%*%fB/q[1],
          context = sprintf("mcmc_al_sample_C_t%d", t)
        )
        standard.forecast.errors[t] = (y[t]-f)/sqrt(q)
      }
      ## backwards sample
      sC_TT = .exdqlm_regularize_cov(C[,,TT], context = "mcmc_al_sample_sC_TT")
      svd.sC = svd(sC_TT)
      sam.theta[,TT] = m[,TT] + svd.sC$u%*%diag(sqrt(svd.sC$d),p)%*%stats::rnorm(p,0,1)
      reg_theta <- numeric(TT)
      reg_theta[TT] <- drop(crossprod(FF[,TT], sam.theta[,TT]))
      post.pred[TT] = rexal(1,p0,reg_theta[TT],sigma,0)
      for(t in (TT-1):1){
        P = .exdqlm_regularize_cov(GG[,,(t+1)]%*%C[,,(t)]%*%t(GG[,,(t+1)]), context = sprintf("mcmc_al_back_P_t%d", t + 1L))
        R.info = .exdqlm_cov_inverse(P + df.mat*P, context = sprintf("mcmc_al_back_R_t%d", t + 1L))
        sB = C[,,t]%*%t(GG[,,(t+1)])%*%R.info$inverse
        sm = m[,t] + sB%*%(sam.theta[,(t+1)]-as.vector(GG[,,(t+1)]%*%m[,(t)]))
        sC = .exdqlm_regularize_cov(
          C[,,t] - sB%*%GG[,,(t+1)]%*%C[,,t],
          context = sprintf("mcmc_al_back_sC_t%d", t)
        )
        svd.sC = svd(sC)
        sam.theta[,t] = sm + svd.sC$u%*%diag(sqrt(svd.sC$d),p)%*%stats::rnorm(p,0,1)
        reg_theta[t] <- drop(crossprod(FF[,t], sam.theta[,t]))
        post.pred[t] = rexal(1,p0,reg_theta[t],sigma,0)
      }
      return(list(standard.forecast.errors=standard.forecast.errors,post.pred=post.pred,sam.theta=sam.theta,fm=m,fC=C))
    }
    if (use_cpp_mcmc) {
      samp_theta <- function(ex.f, ex.q, sigma) {
        out <- cpp_ffbs_sample(ex.f, ex.q)
        sam.theta <- out$sam.theta
        reg_theta <- state_signal(FF, sam.theta)
        post.pred <- vapply(seq_len(TT), function(t) {
          rexal(1, p0, reg_theta[t], sigma, 0)
        }, numeric(1))
        list(
          standard.forecast.errors = out$standard.forecast.errors,
          post.pred = post.pred,
          sam.theta = sam.theta,
          fm = out$fm,
          fC = out$fC
        )
      }
    }

    # dqlm function sample uts
    samp_uts<-function(reg1,sigma){
      chi <- as.numeric(((y-reg1)^2)/(b_tau*sigma))
      psi <- (a_tau^2)/(b_tau*sigma) + (2/sigma)
      sample_gig_cpp_required(chi = chi, psi = psi, lambda = 0.5, context = "dqlm_mcmc_uts")
    }

    # dqlm function sample sigma
    samp_sigma<-function(reg1,uts){
      1/stats::rgamma(1, shape = PriorSigma$a_sig + 1.5*TT,
               rate = PriorSigma$b_sig + 0.5*sum( ((as.vector(y) - reg1 - a_tau*uts)^2)/(b_tau*uts) ) + sum(uts) )
    }

    progress_every_env <- suppressWarnings(as.integer(Sys.getenv("EXDQLM_MCMC_PROGRESS_EVERY", NA_character_))[1])
    progress_every <- if (is.finite(progress_every_env) && !is.na(progress_every_env) && progress_every_env >= 1L) {
      progress_every_env
    } else if (trace.diagnostics) {
      trace.every
    } else {
      100L
    }
    progress_every <- max(1L, as.integer(progress_every)[1])

    # Sample from dqlm posterior
    tictoc::tic()
    safe_progress_callback(list(
      event = "start",
      iter = 0L,
      total_iter = as.integer(I),
      phase = "burn",
      n_burn = as.integer(n.burn),
      n_mcmc = as.integer(n.mcmc),
      sigma = cursam.sigma,
      gamma = NA_real_,
      kernel = "conjugate",
      accept = NA_real_
    ))
    for (i in 1:I){
      current_iter <- as.integer(i)
      # counter
      if(verbose & i%%progress_every==0){
        cat(sprintf("%s iteration %s: %s ", ifelse(i<=n.burn,"burn-in","MCMC"), i, Sys.time()), "\n")
        utils::flush.console()
        try(flush(stdout()), silent = TRUE)
        }
      if (i %% progress_every == 0L) {
        safe_progress_callback(list(
          event = "progress",
          iter = as.integer(i),
          total_iter = as.integer(I),
          phase = if (i <= n.burn) "burn" else "keep",
          n_burn = as.integer(n.burn),
          n_mcmc = as.integer(n.mcmc),
          sigma = cursam.sigma,
          gamma = NA_real_,
          kernel = "conjugate",
          accept = NA_real_
        ))
      }

      # sample theta
      ex.f = cursam.Ut*a_tau
      ex.q = b_tau*cursam.Ut*cursam.sigma
      theta.out <- samp_theta(ex.f,ex.q,cursam.sigma)
      cursam.theta = theta.out$sam.theta

      # sample uts
      reg1 = state_signal(FF, cursam.theta)
      if (!is.finite(cursam.sigma) || cursam.sigma <= 0 || any(!is.finite(reg1))) {
        stop(sprintf(
          "dqlm_mcmc_pre_uts (iter=%d) invalid state before chi update: sigma=%s reg1_finite=%s max_abs_reg1=%s max_abs_theta=%s",
          i,
          format(cursam.sigma, digits = 6),
          all(is.finite(reg1)),
          if (all(is.finite(reg1))) format(max(abs(reg1), na.rm = TRUE), digits = 6) else "NA",
          if (all(is.finite(cursam.theta))) format(max(abs(cursam.theta), na.rm = TRUE), digits = 6) else "NA"
        ))
      }
      cursam.Ut<-samp_uts(reg1,cursam.sigma)

      # sample sigma
      if(!fix.sigma){
        cursam.sigma <- samp_sigma(reg1,cursam.Ut)
      }

      # save samples after burn
      if(i > n.burn){
        save.sigma[(i-n.burn)] = cursam.sigma
        save.theta[,,(i-n.burn)] = cursam.theta
        save.Ut[,(i-n.burn)] = cursam.Ut
        save.post.pred[,(i-n.burn)] = theta.out$post.pred
      }

    }
    run.time = tictoc::toc(quiet = TRUE)
    if(verbose){
      cat(sprintf("MCMC complete: %s iterations, %s seconds",I,round(run.time$toc-run.time$tic,3)),"\n")
    }
    safe_progress_callback(list(
      event = "complete",
      iter = as.integer(I),
      total_iter = as.integer(I),
      phase = "done",
      n_burn = as.integer(n.burn),
      n_mcmc = as.integer(n.mcmc),
      sigma = cursam.sigma,
      gamma = NA_real_,
      kernel = "conjugate",
      accept = NA_real_,
      runtime_sec = as.numeric(run.time$toc - run.time$tic)
    ))

    # dqlm MAP standard forecast errors
    map.sig = mean(save.sigma)
    map.Ut = rowMeans(save.Ut)
    theta.out <- smoothed_theta(map.Ut*a_tau,b_tau*map.Ut*map.sig)
    map.standard.forecast.errors = theta.out$standard.forecast.errors
    ess_sigma <- tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(save.sigma))), error = function(e) NA_real_)

    # dqlm results
    retlist = list(y=y,run.time=(run.time$toc-run.time$tic),model=model,p0=p0,df=df,dim.df=dim.df,
                samp.theta = coda::as.mcmc(save.theta), theta.out = theta.out,
                samp.post.pred = save.post.pred, map.standard.forecast.errors = map.standard.forecast.errors,
                samp.sigma = coda::as.mcmc(save.sigma),
                samp.vts = coda::as.mcmc(save.Ut),
                init.from.vb = init.from.vb,
                vb.init.method = if (init.from.vb) vb.ctrl$method else NA_character_,
                diagnostics = list(
                  ess = list(sigma = ess_sigma, gamma = NA_real_),
                  rhat_ready = list(
                    sigma = as.numeric(save.sigma),
                    gamma = numeric(0)
                  )
                ),
                n.burn=n.burn,n.mcmc=n.mcmc)
  }

  retlist$backend <- list(mcmc = mcmc_backend, mode = cpp_mcmc_mode, gig = gig_backend)

  # return results
  class(retlist) <- "exdqlmMCMC"
  return(retlist)
}

# Internal helper for diagnostics-only multichain validation.
.exdqlm_mcmc_multichain_diag <- function(n.chains = 4L, seeds = NULL, mcmc_args = list()) {
  n.chains <- suppressWarnings(as.integer(n.chains)[1])
  if (!is.finite(n.chains) || n.chains < 2L) {
    stop("n.chains must be >= 2 for multichain diagnostics.")
  }

  if (is.null(seeds)) {
    seeds <- seq_len(n.chains) + 20260300L
  }
  seeds <- as.integer(seeds)
  if (length(seeds) != n.chains) {
    stop("Length of seeds must match n.chains.")
  }

  fits <- vector("list", n.chains)
  for (i in seq_len(n.chains)) {
    set.seed(seeds[i])
    args_i <- utils::modifyList(mcmc_args, list(verbose = FALSE))
    fits[[i]] <- do.call(exdqlmMCMC, args_i)
  }

  sigma_list <- coda::mcmc.list(lapply(fits, function(f) coda::as.mcmc(as.numeric(f$samp.sigma))))
  sigma_rhat <- tryCatch(
    as.numeric(coda::gelman.diag(sigma_list, autoburnin = FALSE)$psrf[1, "Point est."]),
    error = function(e) NA_real_
  )
  sigma_ess <- tryCatch(as.numeric(coda::effectiveSize(sigma_list))[1], error = function(e) NA_real_)

  has_gamma <- !isTRUE(fits[[1]]$dqlm.ind) && !is.null(fits[[1]]$samp.gamma)
  if (has_gamma) {
    gamma_list <- coda::mcmc.list(lapply(fits, function(f) coda::as.mcmc(as.numeric(f$samp.gamma))))
    gamma_rhat <- tryCatch(
      as.numeric(coda::gelman.diag(gamma_list, autoburnin = FALSE)$psrf[1, "Point est."]),
      error = function(e) NA_real_
    )
    gamma_ess <- tryCatch(as.numeric(coda::effectiveSize(gamma_list))[1], error = function(e) NA_real_)
  } else {
    gamma_list <- NULL
    gamma_rhat <- NA_real_
    gamma_ess <- NA_real_
  }

  list(
    fits = fits,
    seeds = seeds,
    diagnostics = list(
      sigma = list(rhat = sigma_rhat, ess = sigma_ess, chains = sigma_list),
      gamma = list(rhat = gamma_rhat, ess = gamma_ess, chains = gamma_list)
    )
  )
}
