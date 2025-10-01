#' exDQLM - LDVB algorithm (Laplace–Delta)
#'
#' The function applies an Importance Sampling Variational Bayes (LDVB) algorithm to estimate the posterior of an exDQLM.
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
#' @param n.IS Number of particles for the importance sampling of joint variational distribution of sigma and gamma. Default is `n.IS=500`.
#' @param n.samp Number of samples to draw from the approximated posterior distribution. Default is `n.samp=200`.
#' @param PriorSigma List of parameters for inverse gamma prior on sigma; shape `a_sig` and scale `b_sig`. Default is an inverse gamma with mean 1 (or `sig.init` if provided) and variance 10.
#' @param PriorGamma List of parameters for truncated student-t prior on gamma; center `m_gam`, scale `s_gam` and degrees of freedom `df_gam`. Default is a standard student-t with 1 degree of freedom, truncated to the support of gamma.
#' @param verbose Logical value indicating whether progress should be displayed.
#' @param debug_shapes Logical; if TRUE, print KF input/output shapes every `debug_every` iterations.
#' @param debug_every  Integer; frequency (in iterations) for shape prints when `debug_shapes=TRUE`.
#'
#' @return A list of the following is returned:
#' \itemize{
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
#' }
#' If `dqlm.ind=FALSE`, the list also contains:
#' \itemize{
#'   \item `gam.init` - Initial value for gamma, or value at which gamma was fixed if `fix.gamma=TRUE`.
#'   \item `seq.gamma` - Sequence of gamma estimated by the algorithm until convergence.
#'   \item `samp.gamma` - Posterior sample of skewness parameter gamma variational distribution.
#'   \item `samp.sts` - Posterior sample of latent parameters, s_t, variational distributions.
#'   \item `gammasig.out` - List containing the IS estimate of the variational distribution of sigma and gamma.
#'   \item `sts.out` - List containing the variational distributions of latent parameters s_t.
#' }
#' Or if `dqlm.ind=TRUE`, the list also contains:
#'  \itemize{
#'  \item `sig.out` - List containing the IS estimate of the variational distribution of sigma.
#'  }
#' @export
#'
#' @importFrom stats median
#' @importFrom nimble dinvgamma
#'
#' @details
#' Advanced options (set via \code{options()}):
#' \itemize{
#'   \item \code{exdqlm.use_cpp_kf}: use the C++ Kalman filter bridge (default TRUE).
#'   \item \code{exdqlm.compute_elbo}: compute ELBO every iteration (default TRUE).
#'   \item \code{exdqlm.tol_elbo}: ELBO convergence tolerance (default 1e-6).
#'   \item \code{exdqlm.use_cpp_samplers}: use C++ samplers for s_t, u_t, theta (default FALSE).
#'         When FALSE, R fallbacks (truncnorm, GH::rgig, SVD sampling) are used.
#'   \item \code{exdqlm.use_cpp_postpred}: use C++ posterior predictive sampler (default FALSE).
#' }
#'
#' @examples
#' \donttest{
#' y = scIVTmag[1:1095]
#' trend.comp = polytrendMod(1,mean(y),10)
#' seas.comp = seasMod(365,c(1,2,4),C0=10*diag(6))
#' model = combineMods(trend.comp,seas.comp)
#' M0 = exdqlmLDVB(y,p0=0.85,model,df=c(1,1),dim.df = c(1,6),
#'                  gam.init=-3.5,sig.init=15,tol=0.05)
#' }
#'
exdqlmLDVB <- function(y, p0, model, df, dim.df,
                       fix.gamma = FALSE, gam.init = NA,
                       fix.sigma = TRUE, sig.init = NA,
                       dqlm.ind = FALSE,
                       exps0,
                       tol = 0.1,
                       n.IS = 500,
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
  dqlm.int = rv$dqlm.ind
  fix.gamma = rv$fix.gamma

  ### Define L and U
  L = L.fn(p0); U = U.fn(p0)
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
  if(is.null(PriorGamma)){
    PriorGamma$m_gam = 0
    PriorGamma$s_gam = 1
    PriorGamma$df_gam = 1
   }else{
     if(!is.list(PriorGamma) | any( is.na( match(c("m_gam", "s_gam", "df_gam"),names(PriorGamma)) ) )){
       stop("`PriorGamma` must be a list containing `m_gam`,`s_gam`, and `df_gam`")
     }
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

  ### Initialize VB
  gam0 = ifelse(!is.na(gam.init),gam.init,(L+U)/2)
  sig0 = ifelse(!is.na(sig.init),sig.init,1)
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
  new.sts.out = list(E.sts=rep(truncnorm::etruncnorm(a=0,b=Inf,mean=1,sd=1),TT),
                     E.sts2=rep(truncnorm::etruncnorm(a=0,b=Inf,mean=1,sd=1)^2+truncnorm::vtruncnorm(a=0,b=Inf,mean=1,sd=1),TT))
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
  conv.count = 0
  new.max = Inf
  seq.gamma = new.gamsig.out$E.gam
  seq.sigma = new.gamsig.out$E.sigma

  # function update q(st)  (trunc-normal on (0, \\infty))
  update_sts <- function(exps, inv.uts, c2.invb.absgam2.sigma, c.invb.absgam, c.a.invb.absgam) {
    s.sig2 <- 1 / (1 + c2.invb.absgam2.sigma * inv.uts)
    s.sig  <- sqrt(s.sig2)
    s.mu   <- s.sig2 * (c.invb.absgam * (y - exps) * inv.uts - c.a.invb.absgam)

    # moments
    E.sts  <- truncnorm::etruncnorm(a = rep(0, TT), b = rep(Inf, TT), mean = s.mu, sd = s.sig)
    V.sts  <- truncnorm::vtruncnorm(a = rep(0, TT), b = rep(Inf, TT), mean = s.mu, sd = s.sig)
    E.sts2 <- s.mu^2 + s.sig2 + s.mu * s.sig *
      exp(stats::dnorm(-s.mu / s.sig, log = TRUE) - stats::pnorm(s.mu / s.sig, log.p = TRUE))

    # entropy of half-line truncated normal:
    # H = log \sigma + log \Phi(\mu/\sigma) + 0.5*(1 + \alpha \zeta) + 0.5*log(2\pi),
    # where \alpha = -\mu/\sigma, \zeta = \Phi(\alpha) / (1-\Phi(\alpha)) = \Phi(-\mu/\sigma)/\Phi(\mu/\sigma)
    alpha    <- -s.mu / s.sig
    logtail  <- stats::pnorm(alpha, lower.tail = FALSE, log.p = TRUE)   # log(1 - \Phi(\alpha)) = log \Phi(\mu/\sigma)
    logphi   <- stats::dnorm(alpha, log = TRUE)
    zeta     <- exp(logphi - logtail)                                   # \Phi(\alpha)/(1-\Phi(\alpha))
    # H = log \sigma + log \Phi(\mu/\sigma) + 0.5*log(2\pi) + 0.5 + 0.5*(\alpha \zeta - \zeta^2)
    H_sts_t <- log(s.sig) + logtail + 0.5*log(2*pi) + 0.5 + 0.5 * (alpha * zeta - zeta^2)
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
      sB = C[,,t]%*%t(GG[,,t])%*%inv.R
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
  PriorGammaDens <- function(gamma, prior) {
    crch::dtt(gamma, location = prior[1], scale = prior[2], df = prior[3],
              left = L, right = U, log = FALSE)
  }

  LL <- L+0.001
  UU <- U-0.001

  update_gamma_sigma_ldcore <- function(y, nn, prior_g, prior_s,
                                        gamma, var.gam, sigma, var.sig,
                                        exps, exps2, sts, sts2, uts, inv.uts,
                                        s_init, g_init){

    dq_transf <- function(theta_s,theta_g){
        sig <- exp(theta_s)
        gam <- LL+(-LL+UU)*exp(-exp(theta_g))
            a = A.fn(p0,gam); b = B.fn(p0,gam); c = C.fn(p0,gam); p.fn(p0,gam)

        # Prior
        yy <- log(PriorGammaDens(gam, prior_g)) - (prior_s[1] + 1) * log(sig) - prior_s[2]/sig

        # Likelihood
        yy <- yy - (1.5*nn)*log(sig) - (0.5*nn)*log(b)-sum(uts)/sig 
        yy <- yy - 0.5*sum( inv.uts*(y^2-2*y*exps+exps2)/sig
                        - (y-exps)*2*(inv.uts*c*abs(gam)*sts + a/sig)
                        + sig*inv.uts*(c^2)*(abs(gam)^2)*sts2
                        + 2*c*abs(gam)*sts*a
                        + (uts*a^2)/sig )/b
        
        # Jacobian of (theta_s, theta_g) -> (sigma, gamma)
        yy <- yy + theta_s + theta_g - exp(theta_g) + log(U - L)
                
        return(yy)
    }

    theta_s_init <- log(s_init)
    theta_g_init <- log(log((-L+U)/(-L+g_init)))
    initial_values <- c(theta_s_init, theta_g_init)

    # Optimization step
    optim_results <- optim(par = initial_values, 
                        fn = function(x) -dq_transf(x[1], x[2]), # Maximizing by minimizing the negative
                        method = "L-BFGS-B", # This method allows box constraints
                        lower = c(-Inf, -Inf), # Transform bounds for gam to theta_g space if needed
                        upper = c(Inf, Inf),
                        hessian = TRUE)
    # Evaluate the Hessian at the optimal value
    hessian_at_optimal <- -optim_results$hessian # SINCE WE MIN -f, not MAX f
    # Take the inverse of the Hessian
    inverse_hessian <- solve(hessian_at_optimal)

    LD_mu <- optim_results$par
    LD_S <- -inverse_hessian 

    Expected_f <- function(f, theta_s, theta_g){
      x <- numDeriv::hessian(func = f, x = LD_mu) %*% LD_S
      f(LD_mu) + 0.5 * sum(diag(x))
    }


    f.exp.theta_g <- function(theta){
      sig = exp(theta[1]); gam = LL+(-LL+UU)*exp(-exp(theta[2]));
      a = A.fn(p0,gam); b = B.fn(p0,gam); c = C.fn(p0,gam);
      yy <- exp(theta[2])
      return(yy)
    }

    f.log.sig.b <- function(theta){
      sig = exp(theta[1]); gam = LL+(-LL+UU)*exp(-exp(theta[2]));
      a = A.fn(p0,gam); b = B.fn(p0,gam); c = C.fn(p0,gam);
      yy <- log(sig*b)
      return(yy)
    }

    f.log.sig <- function(theta){
      sig = exp(theta[1]); gam = LL+(-LL+UU)*exp(-exp(theta[2]));
      a = A.fn(p0,gam); b = B.fn(p0,gam); c = C.fn(p0,gam);
      yy <- log(sig)
      return(yy)
    }

    f.prior.sig.gam <- function(theta){
      sig = exp(theta[1]); gam = LL+(-LL+UU)*exp(-exp(theta[2]));
      a = A.fn(p0,gam); b = B.fn(p0,gam); c = C.fn(p0,gam);
      yy <- crch::dtt(gam, location = prior_g[1], scale = prior_g[2], df = prior_g[3], left = L, right = U, log = TRUE)
      yy <- yy + nimble::dinvgamma(sig, shape = prior_s[1], scale =  prior_s[2], log = TRUE)
      return(yy)
    }


    f.c2.s.abs.g2.inv.b <- function(theta){
      sig = exp(theta[1]); gam = LL+(-LL+UU)*exp(-exp(theta[2]));
      a = A.fn(p0,gam); b = B.fn(p0,gam); c = C.fn(p0,gam);
      yy <- c^2*sig*abs(gam)^2/b
      return(yy)
    }

    f.inv.sig <- function(theta){
      sig = exp(theta[1])
      yy <- 1/sig
      return(yy)
    }

    f.c.abs.g.inv.b <- function(theta){
      gam = LL+(-LL+UU)*exp(-exp(theta[2]))
      b = B.fn(p0,gam); c = C.fn(p0,gam);
      yy <- c*abs(gam)/b
      return(yy)
    }

    f.c.abs.g.a.inv.b <- function(theta){
      sig = exp(theta[1]); gam = LL+(-LL+UU)*exp(-exp(theta[2]));
      a = A.fn(p0,gam); b = B.fn(p0,gam); c = C.fn(p0,gam);
      yy <- c*abs(gam)*a/b
      return(yy)
    }

    f.inv.s.inv.b <- function(theta){
      sig = exp(theta[1]); gam = LL+(-LL+UU)*exp(-exp(theta[2]));
      a = A.fn(p0,gam); b = B.fn(p0,gam); c = C.fn(p0,gam);
      yy <- 1/sig/b
      return(yy)
    }

    f.a.inv.s.inv.b <- function(theta){
      sig = exp(theta[1]); gam = LL+(-LL+UU)*exp(-exp(theta[2]));
      a = A.fn(p0,gam); b = B.fn(p0,gam); c = C.fn(p0,gam);
      yy <- a/sig/b
      return(yy)
    }

    f.a2.inv.s.inv.b <- function(theta){
      sig = exp(theta[1]); gam = LL+(-LL+UU)*exp(-exp(theta[2]));
      a = A.fn(p0,gam); b = B.fn(p0,gam); c = C.fn(p0,gam);
      yy <- a^2/sig/b
      return(yy)
    }

    f.sig <- function(theta){
      sig = exp(theta[1]); 
      yy <- sig
      return(yy)
    }

    f.gam <- function(theta){
      gam = LL+(-LL+UU)*exp(-exp(theta[2]));
      yy <- gam
      return(yy)
    }

    #############################################################################################################################################
    #############################################################################################################################################

    E.sig = Expected_f(f.sig, LD_mu[1], LD_mu[2]);
    E.gam = Expected_f(f.gam, LD_mu[1], LD_mu[2]);


    E.inv.sigma = Expected_f(f.inv.sig, LD_mu[1], LD_mu[2])
    E.c2.invb.absgam2.sigma = Expected_f(f.c2.s.abs.g2.inv.b, LD_mu[1], LD_mu[2])
    E.c.invb.absgam = Expected_f(f.c.abs.g.inv.b, LD_mu[1], LD_mu[2])
    E.c.a.invb.absgam = Expected_f(f.c.abs.g.a.inv.b, LD_mu[1], LD_mu[2])
    E.a2.invb.inv.sigma = Expected_f(f.a2.inv.s.inv.b, LD_mu[1], LD_mu[2])
    E.invb.inv.sigma = Expected_f(f.inv.s.inv.b, LD_mu[1], LD_mu[2])
    E.a.invb.inv.sigma = Expected_f(f.a.inv.s.inv.b, LD_mu[1], LD_mu[2])
    E.log.sig.b = Expected_f(f.log.sig.b, LD_mu[1], LD_mu[2])
    E.log.sig = Expected_f(f.log.sig, LD_mu[1], LD_mu[2])
    E.prior.sig.gam = Expected_f(f.prior.sig.gam, LD_mu[1], LD_mu[2])
    E.exp.theta_g =  Expected_f(f.exp.theta_g, LD_mu[1], LD_mu[2])

    # H(q_{θ}) + E_q[log|J(θ)|], J = diag(exp(theta_s), (U-L)exp(theta_g - exp(theta_g)))
    entrop <- log(2*pi*exp(1)) +
              0.5 * determinant(as.matrix(LD_S), logarithm = TRUE)$modulus[1] +
              (log(U - L) + sum(LD_mu) - E.exp.theta_g)

    return(list(E.sigma=E.sig,E.inv.sigma=E.inv.sigma,E.gam=E.gam,
                E.c2.invb.absgam2.sigma = E.c2.invb.absgam2.sigma, E.c.invb.absgam = E.c.invb.absgam,
                E.c.a.invb.absgam = E.c.a.invb.absgam, E.a2.invb.inv.sigma = E.a2.invb.inv.sigma,
                E.invb.inv.sigma = E.invb.inv.sigma, E.a.invb.inv.sigma = E.a.invb.inv.sigma,
                Hess.LD = LD_S,
                E.log.sig.b=E.log.sig.b, 
                E.log.sig = E.log.sig, 
                E.prior.sig.gam= E.prior.sig.gam,
                E.theta = LD_mu,
                entrop = entrop))
  }

  update_gamma_sigma <- function(gamma, var.gam, sigma, var.sig,
                                exps, exps2, sts, sts2, uts, inv.uts) {
    # pull needed globals from parent env (already available in your function)
    y_local  <- y
    nn       <- length(y_local)

    # priors packed as numeric vectors (what your core expects)
    prior_g  <- c(PriorGamma$m_gam, PriorGamma$s_gam, PriorGamma$df_gam)
    prior_s  <- c(PriorSigma$a_sig, PriorSigma$b_sig)

    # inits: if user fixed, honor; else use current estimates
    s_init   <- if (!is.na(sig.init)) sig.init else sigma
    g_init   <- if (!is.na(gam.init)) gam.init else gamma

    rv <- update_gamma_sigma_ldcore(
      y = as.numeric(y_local), nn = nn,
      prior_g = prior_g, prior_s = prior_s,
      gamma = gamma, var.gam = var.gam,
      sigma = sigma, var.sig = var.sig,
      exps = as.numeric(exps), exps2 = as.numeric(exps2),
      sts = as.numeric(sts), sts2 = as.numeric(sts2),
      uts = as.numeric(uts), inv.uts = as.numeric(inv.uts),
      s_init = s_init, g_init = g_init
    )

    # harmonize LD outputs to what the rest of the code expects
    rv$V.gam <- NA_real_
    rv$V.sigma <- NA_real_
    rv$E.log.inv.sigma <- -rv$E.log.sig
    rv$elbo_logZ <- NULL   # signal to use fallback ELBO

    # (Optional) keep IS fields alive so later code doesn't crash even if untouched
    n_is <- if (exists("n.IS", inherits = TRUE)) get("n.IS", inherits = TRUE) else 1L
    rv$gamma.samples <- rep(rv$E.gam,   n_is)
    rv$sigma.samples <- rep(rv$E.sigma, n_is)
    rv$weights       <- rep(1/n_is,     n_is)
    return(rv)
  }


  # one-line header 
  if (verbose) {
    message(" Starting LDVB: TT=", TT, " p=", p,
            " use_cpp=", isTRUE(getOption("exdqlm.use_cpp_kf", FALSE)))
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
    # helper: robust log|·| for 1x1 or array→matrix slices
    .safe_logdet <- function(A) {
      d <- dim(A)
      if (length(d) >= 2L) {
        M <- matrix(A, nrow = d[1L], ncol = d[2L])
      } else { # scalar (p == 1)
        M <- matrix(A, nrow = 1L, ncol = 1L)
      }
      determinant(M, logarithm = TRUE)$modulus[1]
    }

    # θ-entropy from bridge if present; otherwise recompute robustly
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

      # add σ,γ prior + entropy (Laplace–Delta block)
      elbo_gs <- gs$E.prior.sig.gam + gs$entrop

      total <- as.numeric(lik + H_theta + H_sts + H_uts + elbo_gs)
      breakdown <- c(lik = lik, H_theta = H_theta, H_sts = H_sts, H_uts = H_uts,
                    prior_gs = gs$E.prior.sig.gam, H_gs = gs$entrop)

    }

    list(total = total, breakdown = breakdown)
  }


  tictoc::tic("run time")
  ### estimate posterior
  while( (new.max > tol && conv.count < 5) && iter < 200 ){

    # counter
    iter <- iter + 1L
    if (verbose && iter %% 5 == 0) {
      message(sprintf("LDVB iteration %d: new.max=%.4f, conv.count=%d",
                      iter, new.max, conv.count))
      utils::flush.console()
    }

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
    if (isTRUE(getOption("exdqlm.compute_elbo", TRUE))) {
      elbo.obj <- .elbo_snapshot(y, new.theta.out, new.sts.out, new.uts.out, new.gamsig.out)
      if (!exists("elbo.seq", inherits = FALSE)) elbo.seq <- numeric(0)
      elbo.seq <- c(elbo.seq, elbo.obj$total)

      if (verbose && iter %% 5 == 0) {
        dELBO <- if (length(elbo.seq) >= 2) elbo.seq[length(elbo.seq)] - elbo.seq[length(elbo.seq)-1] else NA_real_
        # Optional: show gs_logZ when available
        if (!is.null(new.gamsig.out$elbo_logZ)) {
          message(sprintf("    ELBO: %.6f  \\Delta=%.3e  (gs_logZ=%.6f)",
                          elbo.obj$total, dELBO, new.gamsig.out$elbo_logZ))
        } else {
          message(sprintf("    ELBO: %.6f  \\Delta=%.3e", elbo.obj$total, dELBO))
        }
        utils::flush.console()
      }

      # ELBO-based stopping (paired with your param-diff)
      tol_elbo <- getOption("exdqlm.tol_elbo", 1e-4)
      if (length(elbo.seq) >= 2) {
        if (abs(elbo.seq[length(elbo.seq)] - elbo.seq[length(elbo.seq)-1]) < tol_elbo && new.max < tol) {
          break
        }
      }
    }

    # save LDVB gamma and sigma estimates
    seq.gamma = c(seq.gamma,new.gamsig.out$E.gam)
    seq.sigma = c(seq.sigma,new.gamsig.out$E.sigma)

    # evaluate convergence
    new.max    <- max(abs(c(cur.theta.out$exps - new.theta.out$exps)))
    conv.count <- ifelse(new.max < tol, conv.count + 1L, 0L)

  }
  run.time <- tictoc::toc(quiet = TRUE)
  if (verbose) {
    cat(sprintf("LDVB converged: %s iterations, %s seconds",
                iter, round(run.time$toc - run.time$tic, 3)), "\n")
  }

  ### posterior samples ------------------------------------------------------

  # helper: coerce a 3D array/cube to (p, TT, ns) if it’s a permutation
  .normalize_cube <- function(x, p, TT, ns, name = "cube") {
    d    <- dim(x)
    want <- as.integer(c(p, TT, ns))
    if (length(d) != 3L) {
      stop(sprintf("%s must be 3D, got length(dim)=%d", name, length(d)))
    }
    if (all(d == want)) return(x)
    perms <- list(
      c(2, 1, 3),  # TT, p, ns -> p, TT, ns
      c(1, 3, 2),  # p, ns, TT -> p, TT, ns
      c(3, 1, 2),  # ns, p, TT -> p, TT, ns
      c(2, 3, 1),  # TT, ns, p -> p, TT, ns
      c(3, 2, 1)   # ns, TT, p -> p, TT, ns
    )
    for (P in perms) {
      if (all(d[P] == want)) return(aperm(x, P))
    }
    stop(sprintf("%s has unexpected dims %s; expected %s",
                 name, paste(d, collapse = "x"), paste(want, collapse = "x")))
  }

  # IS selection indices for (gamma, sigma)
  samp.index <- sample.int(n.IS, n.samp, replace = TRUE, prob = new.gamsig.out$weights)
  samp.gamma <- new.gamsig.out$gamma.samples[samp.index]
  samp.sigma <- new.gamsig.out$sigma.samples[samp.index]

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
    svd.sC <- svd(new.theta.out$sC[, , t])
    LL     <- svd.sC$u %*% diag(sqrt(pmax(svd.sC$d, 0)), p, p)   # p x p
    Z      <- matrix(stats::rnorm(ns * p), nrow = p, ncol = ns)  # p x ns

    # turn mean into p x ns by column-replication
    mu_t   <- matrix(new.theta.out$sm[, t], nrow = p, ncol = ns)
    samp.theta[, t, ] <- mu_t + LL %*% Z
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
      samp.post.pred[t, ] <- brms::rasym_laplace(
        ns,
        mu       = loc,
        sigma    = samp.sigma,
        quantile = tau
      )
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
    retlist = list(run.time=(run.time$toc-run.time$tic),iter=iter,dqlm.ind=dqlm.ind,
                   model=model,p0=p0,df=df,dim.df=dim.df,
                   sig.init=sig.init,seq.sigma=seq.sigma,gam.init=gam.init,seq.gamma=seq.gamma,
                   samp.theta=samp.theta,samp.post.pred=samp.post.pred,
                   map.standard.forecast.errors=new.theta.out$standard.forecast.errors,
                   samp.sigma=samp.sigma,samp.gamma=samp.gamma,samp.sts=samp.sts,samp.vts=samp.uts,
                   theta.out=new.theta.out,gammasig.out=new.gamsig.out,sts.out=new.sts.out,vts.out=new.uts.out)
  }else{
    retlist = list(run.time=(run.time$toc-run.time$tic),iter=iter,dqlm.ind=dqlm.ind,
                   model=model,p0=p0,df=df,dim.df=dim.df,
                   sig.init=sig.init,seq.sigma=seq.sigma,
                   samp.theta=samp.theta,samp.post.pred=samp.post.pred,
                   map.standard.forecast.errors=new.theta.out$standard.forecast.errors,
                   samp.sigma=samp.sigma,samp.vts=samp.uts,
                   theta.out=new.theta.out,sig.out=new.gamsig.out,vts.out=new.uts.out)
  }

  retlist$diagnostics <- list(
  elbo = if (exists("elbo.seq", inherits = FALSE)) elbo.seq else NULL
  )

  # return results
  class(retlist) <- "exdqlm"
  return(retlist)
}
