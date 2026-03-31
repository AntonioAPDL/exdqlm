#
log_g<-function(gam){	base::log(2)+stats::pnorm(-abs(gam),log=TRUE)+0.5*gam^2 }
L.fn<-function(p0){ stats::uniroot(function(gam) exp(log_g(gam))-(1-p0), c(-1000,0))$root }
U.fn<-function(p0){ stats::uniroot(function(gam) exp(log_g(gam))-p0, c(0,1000))$root }
p.fn<-function(p0,gam){ (p0-as.numeric(gam<0))/exp(log_g(gam))+as.numeric(gam<0)}
A.fn<-function(p0,gam){ temp.p = p.fn(p0,gam); return((1-2*temp.p)/(temp.p*(1-temp.p))) }
B.fn<-function(p0,gam){ temp.p = p.fn(p0,gam); return((2)/(temp.p*(1-temp.p))) }
C.fn<-function(p0,gam){ temp.p = p.fn(p0,gam); return((as.numeric(gam>0)-temp.p)^(-1)) }
# Internal helper: validate bounds and fall back to R reference if needed.
.gamma_bounds_ok_basic <- function(L, U) {
  if (!is.numeric(L) || !is.numeric(U) || length(L) != 1L || length(U) != 1L) return(FALSE)
  if (!is.finite(L) || !is.finite(U)) return(FALSE)
  if (L >= U) return(FALSE)
  # Gamma bounds should always straddle 0 for p0 in (0, 1).
  if (L > 0 || U < 0) return(FALSE)
  TRUE
}

.gamma_bounds_ok_cpp <- function(L, U, p0, tol_log = 1e-4) {
  if (!.gamma_bounds_ok_basic(L, U)) return(FALSE)
  log_target_L <- base::log1p(-p0)
  log_target_U <- base::log(p0)
  if (!is.finite(log_target_L) || !is.finite(log_target_U)) return(FALSE)

  # Validate against the defining equations on the log scale:
  #   g_gamma(L) = 1 - p0,  g_gamma(U) = p0
  logL <- log_g(L)
  logU <- log_g(U)
  if (!is.finite(logL) || !is.finite(logU)) return(FALSE)

  (abs(logL - log_target_L) <= tol_log) && (abs(logU - log_target_U) <= tol_log)
}

.gamma_bounds_ref <- function(p0) {
  c(L = L.fn(p0), U = U.fn(p0))
}

.gamma_bounds <- function(p0) {
  stopifnot(is.numeric(p0), length(p0) == 1L, is.finite(p0), p0 > 0, p0 < 1)
  out_cpp <- try(get_gamma_bounds_cpp(p0), silent = TRUE)
  if (!inherits(out_cpp, "try-error") && length(out_cpp) == 2L) {
    if (is.null(names(out_cpp))) names(out_cpp) <- c("L", "U")
    if (.gamma_bounds_ok_cpp(out_cpp[1], out_cpp[2], p0)) return(out_cpp)
  }
  out_ref <- try(.gamma_bounds_ref(p0), silent = TRUE)
  if (!inherits(out_ref, "try-error") && .gamma_bounds_ok_basic(out_ref[1], out_ref[2])) {
    return(out_ref)
  }
  stop("Unable to compute valid gamma bounds for p0 = ", p0)
}

.sample_gig_devroye_required <- function(n_samples, p, a, b_vec, context = "gig") {
  if (!exists("sample_gig_devroye_vector", mode = "function")) {
    stop(sprintf("%s requires sample_gig_devroye_vector(), but it is not available", context))
  }

  eps_gig <- sqrt(.Machine$double.eps)
  p <- as.numeric(p)[1]
  a <- as.numeric(a)[1]
  b_vec <- as.numeric(b_vec)

  if (!is.finite(p)) {
    stop(sprintf("%s requires a finite lambda; got %.6g", context, p))
  }

  if (!is.finite(a) || a <= 0) a <- eps_gig
  b_vec[!is.finite(b_vec) | b_vec <= 0] <- eps_gig

  draws <- sample_gig_devroye_vector(
    as.integer(n_samples)[1],
    p = p,
    a = a,
    b_vec = b_vec
  )

  bad <- which(!is.finite(draws) | draws <= 0)
  if (length(bad)) {
    first <- bad[1]
    stop(sprintf("%s returned %d invalid draws (first index=%d, value=%.6g)",
                 context, length(bad), first, draws[first]))
  }

  pmax(draws, eps_gig)
}

.sample_gig_devroye_pairs_required <- function(n_samples, p, a_vec, b_vec, context = "gig") {
  if (!exists("sample_gig_devroye_pairs", mode = "function")) {
    stop(sprintf("%s requires sample_gig_devroye_pairs(), but it is not available", context))
  }

  eps_gig <- sqrt(.Machine$double.eps)
  p <- as.numeric(p)[1]
  a_vec <- as.numeric(a_vec)
  b_vec <- as.numeric(b_vec)

  if (!is.finite(p)) {
    stop(sprintf("%s requires a finite lambda; got %.6g", context, p))
  }
  if (length(a_vec) != length(b_vec)) {
    stop(sprintf("%s requires a_vec and b_vec to have the same length", context))
  }

  a_vec[!is.finite(a_vec) | a_vec <= 0] <- eps_gig
  b_vec[!is.finite(b_vec) | b_vec <= 0] <- eps_gig

  draws <- sample_gig_devroye_pairs(
    as.integer(n_samples)[1],
    p = p,
    a_vec = a_vec,
    b_vec = b_vec
  )

  bad <- which(!is.finite(draws) | draws <= 0)
  if (length(bad)) {
    first <- bad[1]
    stop(sprintf("%s returned %d invalid draws (first index=%d, value=%.6g)",
                 context, length(bad), first, draws[first]))
  }

  pmax(draws, eps_gig)
}


.exdqlm_unwrap_fit_bundle <- function(obj, max_depth = 32L) {
  depth <- 0L
  fit <- obj
  normalized <- NULL
  meta <- NULL
  is_bundle <- function(x) {
    is.list(x) && all(c("fit", "normalized", "meta") %in% names(x))
  }
  while (is_bundle(fit) && depth < max_depth) {
    if (is.null(normalized) && !is.null(fit$normalized)) normalized <- fit$normalized
    if (is.null(meta) && !is.null(fit$meta)) meta <- fit$meta
    fit <- fit$fit
    depth <- depth + 1L
  }
  list(fit = fit, normalized = normalized, meta = meta, depth = depth)
}

.normalize_gamma_prior_trunc_t <- function(PriorGamma = NULL) {
  if (is.null(PriorGamma)) {
    PriorGamma <- list(m_gam = 0, s_gam = 1, df_gam = 1)
  } else {
    need <- c("m_gam", "s_gam", "df_gam")
    if (!is.list(PriorGamma) || any(is.na(match(need, names(PriorGamma))))) {
      stop("`PriorGamma` must be a list containing `m_gam`, `s_gam`, and `df_gam`")
    }
  }

  PriorGamma$m_gam <- as.numeric(PriorGamma$m_gam)[1]
  PriorGamma$s_gam <- as.numeric(PriorGamma$s_gam)[1]
  PriorGamma$df_gam <- as.numeric(PriorGamma$df_gam)[1]

  if (!is.finite(PriorGamma$m_gam)) stop("`PriorGamma$m_gam` must be finite")
  if (!is.finite(PriorGamma$s_gam) || PriorGamma$s_gam <= 0) stop("`PriorGamma$s_gam` must be > 0")
  if (!is.finite(PriorGamma$df_gam) || PriorGamma$df_gam <= 0) stop("`PriorGamma$df_gam` must be > 0")

  PriorGamma
}

.gamma_log_prior_trunc_t <- function(gamma, bounds, PriorGamma = NULL) {
  bounds <- as.numeric(bounds)
  if (length(bounds) != 2L || !all(is.finite(bounds)) || bounds[1] >= bounds[2]) {
    stop("`bounds` must be a finite length-2 vector with bounds[1] < bounds[2]")
  }
  prior <- .normalize_gamma_prior_trunc_t(PriorGamma)
  crch::dtt(
    gamma,
    location = prior$m_gam,
    scale = prior$s_gam,
    df = prior$df_gam,
    left = bounds[1],
    right = bounds[2],
    log = TRUE
  )
}

.gamma_prior_density_trunc_t <- function(gamma, bounds, PriorGamma = NULL, log = FALSE) {
  lp <- .gamma_log_prior_trunc_t(gamma, bounds = bounds, PriorGamma = PriorGamma)
  if (isTRUE(log)) lp else exp(lp)
}

.exdqlm_uni_slice_bounded <- function(
  x0,
  log_density,
  w = 0.1,
  m = Inf,
  lower = -Inf,
  upper = Inf,
  ...
) {
  if (!is.numeric(x0) || length(x0) != 1L || !is.finite(x0)) {
    stop("x0 must be a single finite numeric value.")
  }
  if (!is.function(log_density)) stop("log_density must be a function.")
  if (!is.numeric(w) || length(w) != 1L || !is.finite(w) || w <= 0) {
    stop("w must be a single positive finite numeric value.")
  }
  if (!is.numeric(m) || length(m) != 1L ||
      (!is.infinite(m) && (!is.finite(m) || m <= 0 || floor(m) != m))) {
    stop("m must be Inf or a single positive integer.")
  }
  if (!is.numeric(lower) || length(lower) != 1L || !is.finite(lower)) {
    stop("lower must be a single finite numeric value.")
  }
  if (!is.numeric(upper) || length(upper) != 1L || !is.finite(upper)) {
    stop("upper must be a single finite numeric value.")
  }
  if (lower >= upper) stop("lower must be strictly less than upper.")
  if (x0 < lower || x0 > upper) stop("x0 must lie within [lower, upper].")

  n_eval <- 0L
  logf <- function(x) {
    n_eval <<- n_eval + 1L
    as.numeric(log_density(x, ...))[1]
  }

  gx0 <- logf(x0)
  if (!is.finite(gx0)) {
    stop("log_density(x0) must be finite for slice sampling.")
  }

  logy <- gx0 - stats::rexp(1)
  u <- stats::runif(1, 0, w)
  L <- x0 - u
  R <- x0 + (w - u)

  if (is.infinite(m)) {
    repeat {
      if (L <= lower) break
      if (logf(L) <= logy) break
      L <- L - w
    }
    repeat {
      if (R >= upper) break
      if (logf(R) <= logy) break
      R <- R + w
    }
  } else if (m > 1) {
    J <- floor(stats::runif(1, 0, m))
    K <- (m - 1) - J
    while (J > 0) {
      if (L <= lower) break
      if (logf(L) <= logy) break
      L <- L - w
      J <- J - 1L
    }
    while (K > 0) {
      if (R >= upper) break
      if (logf(R) <= logy) break
      R <- R + w
      K <- K - 1L
    }
  }

  L <- max(L, lower)
  R <- min(R, upper)

  repeat {
    x1 <- stats::runif(1, L, R)
    gx1 <- logf(x1)
    if (gx1 >= logy) {
      return(list(
        value = x1,
        log_density = gx1,
        evals = n_eval,
        interval = c(lower = L, upper = R)
      ))
    }
    if (x1 > x0) {
      R <- x1
    } else {
      L <- x1
    }
  }
}
#
CheckLossFn = function(p0,diff){diff*p0 - diff*as.numeric(diff<0)}
#
dlm_df = function(y, model, df, dim.df, s.priors = list(l0=1,S0=10), just.lik=FALSE){
  ### Gets the Time Series Length / Replicate number
  y = check_ts(y)
  TT = nrow(y)
  ### Gets the State Parameter dimension and Prior Distribution Parameters
  m0 = model$m0
  C0 = model$C0
  l0 = s.priors$l0
  S0 = s.priors$S0
  n = length(m0)
  ### Constructs F and G
  FF = model$FF
  GG = model$GG
  ### Variable Saving
  ### Posterior Distribution
  m = matrix(0,TT,n)
  C = array(0,c(TT,n,n))
  ### Predictive State Distribution
  a = matrix(0,TT,n)
  R = array(0,dim = c(TT,n,n))
  P = array(0,dim = c(TT,n,n))
  W = array(0,dim = c(TT,n,n))
  ### One-Step Ahead Forecast
  f = matrix(0,TT,1)
  Q = array(0,c(TT,1,1))
  inv.Q = array(0,c(TT,1,1))
  ### Regression Variables
  e = matrix(0,TT,1)
  A = array(0,c(TT,n,1))
  ### Sample Variance
  S = vector("numeric",TT)
  l = vector("numeric",TT)

  # Prior Dim Check
  m0 = matrix(m0,n,1)
  C0 = matrix(C0,n,n)
  ### Discount Factor Blocking
  df.mat = make_df_mat(df,dim.df,n)

  ### First Update
  ### One-step state forecast
  a[1,]  = GG[,,1] %*% m0
  P[1,,] = GG[,,1] %*% C0 %*% t(GG[,,1])
  W[1,,] = df.mat * P[1,,]
  R[1,,] = P[1,,] + W[1,,]
  ### One-step ahead forecast
  f[1,] = t(FF[,1]) %*% a[1,]
  Q[1,,] = as.matrix(1 + t(FF[,1]) %*% R[1,,] %*% FF[,1],1,1)
  inv.Q[1,,] = chol2inv(chol(Q[1,,]))
  ### Auxilary Variables
  e[1,]  = as.matrix(y[1,] - f[1,],1,1)
  A[1,,] = R[1,,] %*% FF[,1] %*% inv.Q[1,,]
  ### Variance update
  l[1] = l0 + 1
  S[1] = l0 * S0 / l[1] + (t(e[1,]) %*% inv.Q[1,,] %*% e[1,] / l[1])
  ### Posterior Distribution
  m[1,]  = a[1,] + as.matrix(A[1,,],n,1) %*% e[1,]
  C[1,,] = R[1,,] - as.matrix(A[1,,],n,1) %*% Q[1,,] %*% t(A[1,,])
  C[1,,] = (C[1,,] + t(C[1,,]))/2

  for(i in 2:TT){
    ### One-step state forecast
    a[i,]  = GG[,,i] %*% m[i-1,]
    P[i,,] = GG[,,i] %*% C[i-1,,] %*% t(GG[,,i])
    W[i,,] = df.mat * P[i,,]
    R[i,,] = P[i,,] + W[i,,]
    ### One-step ahead forecast
    f[i,] = t(FF[,i]) %*% a[i,]
    Q[i,,] = matrix(1 + t(FF[,i])%*% R[i,,]%*% FF[,i],1,1)
    inv.Q[i,,] = chol2inv(chol(Q[i,,]))
    ### Auxilary Variables
    e[i,]  = as.matrix(y[i,] - f[i,],1,1)
    A[i,,] = as.matrix(R[i,,] %*% FF[,i] %*% inv.Q[i,,],n,1)
    ### Variance update
    l[i] = l[i-1] + 1
    S[i] = l[i-1] * S[i-1] / l[i] + (t(e[i,]) %*% inv.Q[i,,] %*% e[i,] / l[i])
    ### Posterior Distribution
    m[i,]  = a[i,] + as.matrix(A[i,,],n,1) %*% e[i,]
    C[i,,] = R[i,,] - as.matrix(A[i,,],n,1) %*% Q[i,,] %*% t(as.matrix(A[i,,],n,1))
    C[i,,] = (C[i,,] + t(C[i,,]))/2
  }

  ### Adjust By Variance
  R[1,,] = S0 * R[1,,]
  Q[1,,]   = S0 * Q[1,,]
  C[1,,]   = S[1] * C[1,,]
  for(i in 2:TT){
    R[i,,] = S[i-1] * R[i,,]
    Q[i,,]   = S[i-1] * Q[i,,]
    C[i,,]   = S[i] * C[i,,]
  }

  # Calculate Log-Likelihood
  det.Q = log(abs(Q[1,,])) ; llik = lgamma((l0+1)/2)-lgamma(l0/2)-log(pi*l0)/2-det.Q/2-(l0+1)*log(1+t(e[1,])%*%inv.Q[1,,]%*%e[1,]/l0)/2
  for(t in 2:TT){
    det.Q = log(abs(Q[t,,]))
    llik = llik + lgamma((l[t-1]+1)/2)-lgamma(l[t-1]/2)-log(pi*l[t-1])/2-det.Q/2-(l[t-1]+1)*log(1+t(e[t,])%*%inv.Q[t,,]%*%e[t,]/l[t-1])/2
  }
  if(just.lik){
    return(list(llik = llik))
  }

  ## SMOOTHING
  ### Initializes recursive relations
  sa = matrix(0,TT,n)
  sR = array(0, dim = c(TT,n,n))
  ### Runs the recursive equations
  sa[TT,]  = m[TT,]
  sR[TT,,] = C[TT,,]
  for(k in 1:(TT-1)){
  ### Computes the Auxilary recursion Variable B
    B = C[TT-k,,] %*% t(GG[,,i]) %*% solve(R[TT-k+1,,])
    sa[TT-k,] = m[TT-k,] + B %*% (sa[TT-k+1,] - a[TT-k+1,])
    sR[TT-k,,] = C[TT-k,,] + B %*% (sR[TT-k+1,,] - R[TT-k+1,,]) %*% t(B)
  }
  ### Adjusts the variance update
  for(k in 1:TT){
    sR[TT-k,,] = S[TT] * sR[TT-k,,] / S[TT-k]
  }
  return(list(fm = m, fC = C, m = sa, C = sR,model = model, s = S, n = l))
}
#
make_df_mat = function(df,dim.df,n){
  if(sum(dim.df)!=n){ stop("sum of component dimensions given in dim.df does not match m0") }
  if(length(df)!=length(dim.df)){ stop("length of component discount factors does not match length of component dimensions") }
  dfs = rep(df,dim.df)
  n.dfs = length(dim.df)
  ind.dfs = c(0,sapply(1:length(dim.df),function(x){sum(dim.df[1:x])}),n)
  df.mat = matrix(0,n,n)
  for(j in 1:n.dfs){
    df.mat[(ind.dfs[j]+1):ind.dfs[(j+1)],(ind.dfs[j]+1):ind.dfs[(j+1)]] = (1-dfs[ind.dfs[(j+1)]])/dfs[ind.dfs[(j+1)]]
  }
  return(df.mat)
}
#
check_mod = function(model){
  if(!is.exdqlm(model)){
    stop("Model must be an 'exdqlm' object. To create an 'exdqlm', use functions as.exdqlm(), seasMod(), or polytrendMod().")
  }
  
  ## check all dimensions
  # m0
  if(!is.vector(model$m0)){
    if(nrow(model$m0) != 1 & ncol(model$m0) != 1){
      stop("m0 must be a vector, or a matrix with 1 column or 1 row")
    }
  }
  model$m0 = as.matrix(c(model$m0))
  p = nrow(model$m0)
  # C0
  model$C0 = as.matrix(model$C0)
  if(p != dim(model$C0)[1] & p != dim(model$C0)[2]){
    stop("C0 must be a square matrix matching the dimension of m0")
    }
  if(!all.equal(model$C0, t(model$C0)) | !all(eigen(model$C0)$values >= 0)){
    stop("C0 must be a covariance matrix")
  }
  # FF
  if(!is.vector(model$FF)){
    if(nrow(model$FF) != p & ncol(model$FF) != p){
      stop("FF must be a vector of length matching the dimension of m0, or a matrix with number of rows matching the dimension of m0")
    }
    if(ncol(model$FF) == p){
      model$FF = t(model$FF)
    }
  }else{
    if(length(model$FF) != p){
      stop("FF must be a vector of length matching the dimension of m0, or a matrix with number of rows matching the dimension of m0")
    }else{
      model$FF = matrix(model$FF,p,1)
    }
  }
  # GG
  if(is.null(dim(model$GG)[3])){
    model$GG = as.matrix(model$GG)
  }else{
    if(is.na(dim(model$GG)[3])){
      model$GG = as.matrix(model$GG)
    }else{
      model$GG = as.array(model$GG)
    }
  }
  if(p != dim(model$GG)[1] & p != dim(model$GG)[2]){
    stop("GG must be a square matrix matching the dimension of m0, or an array with first two dimensions matching the dimension of m0")
  }
  
  return(model)
}
#
check_logics = function(gam.init,sig.init,fix.gamma,fix.sigma,dqlm.ind){
  retval <- NULL
  retval$gam.init = gam.init
  retval$fix.gamma = fix.gamma
  retval$dqlm.ind = dqlm.ind
  if(dqlm.ind){
    if(gam.init!=0 | !fix.gamma){
      retval$gam.init <- gam.init <- 0
      retval$fix.gamma <- fix.gamma <- TRUE
    }
  }else{
    if(gam.init==0 && fix.gamma==TRUE){
      retval$dqlm.ind = TRUE
    }
  }
  if(fix.gamma & is.na(gam.init)){ stop("when fix.gamma = TRUE, gam.init must be specified") }
  if(fix.sigma & is.na(sig.init)){ stop("when fix.sigma = TRUE, sig.init must be specified") }
  return(retval)
}
#
check_ts = function(dat){
  dat = as.matrix(dat)
  if(all(dim(dat)>1)){
    stop("data must be univariate time-series")
  }
  if(dim(dat)[1]<dim(dat)[2]){
    dat = t(dat)
  }
  return(invisible(dat))
}

# Internal helpers for reduced AL (DQLM) variational updates.
.dqlm_gig_moment <- function(k, chi, psi, r) {
  chi <- pmax(as.numeric(chi), 1e-14)
  psi <- pmax(as.numeric(psi), 1e-14)
  z <- sqrt(chi * psi)
  num <- besselK(z, nu = k + r, expon.scaled = TRUE)
  den <- besselK(z, nu = k, expon.scaled = TRUE)
  ratio <- num / den
  ratio[!is.finite(ratio)] <- 1
  (sqrt(chi / psi)^r) * ratio
}

.dqlm_gig_elog <- function(k, chi, psi) {
  chi <- pmax(as.numeric(chi), 1e-14)
  psi <- pmax(as.numeric(psi), 1e-14)
  z <- sqrt(chi * psi)
  eps <- 1e-6
  logK <- function(nu) {
    val <- besselK(z, nu = nu, expon.scaled = TRUE)
    log(pmax(val, 1e-300)) - z
  }
  dlogK <- (logK(k + eps) - logK(k - eps)) / (2 * eps)
  0.5 * (log(chi) - log(psi)) + dlogK
}

.dqlm_gig_entropy <- function(k, chi, psi, E_inv_v, E_v, E_log_v) {
  chi <- pmax(as.numeric(chi), 1e-14)
  psi <- pmax(as.numeric(psi), 1e-14)
  z <- sqrt(chi * psi)
  logK <- log(pmax(besselK(z, nu = k, expon.scaled = TRUE), 1e-300)) - z
  logc <- (k / 2) * (log(psi) - log(chi)) - log(2) - logK
  sum(-logc - (k - 1) * E_log_v + 0.5 * (chi * E_inv_v + psi * E_v))
}

.vb_joint_controls <- function(tol_state, has_gamma = TRUE) {
  tol_state <- as.numeric(tol_state)[1]
  if (!is.finite(tol_state) || tol_state <= 0) tol_state <- 1e-3

  tol_sigma <- as.numeric(getOption("exdqlm.tol_sigma", tol_state))[1]
  if (!is.finite(tol_sigma) || tol_sigma <= 0) tol_sigma <- tol_state

  tol_gamma <- as.numeric(getOption("exdqlm.tol_gamma", tol_state))[1]
  if (!is.finite(tol_gamma) || tol_gamma <= 0) tol_gamma <- tol_state

  tol_elbo <- as.numeric(getOption("exdqlm.tol_elbo", pmax(1e-5, tol_state / 10)))[1]
  if (!is.finite(tol_elbo) || tol_elbo <= 0) tol_elbo <- pmax(1e-5, tol_state / 10)

  min_iter <- suppressWarnings(as.integer(getOption("exdqlm.vb.min_iter", 10L))[1])
  if (!is.finite(min_iter) || min_iter < 1L) min_iter <- 10L

  patience <- suppressWarnings(as.integer(getOption("exdqlm.vb.patience", 3L))[1])
  if (!is.finite(patience) || patience < 1L) patience <- 3L

  allow_elbo_drop <- as.numeric(getOption("exdqlm.vb.allow_elbo_drop", tol_elbo))[1]
  if (!is.finite(allow_elbo_drop) || allow_elbo_drop < 0) allow_elbo_drop <- tol_elbo

  list(
    tol_state = tol_state,
    tol_sigma = tol_sigma,
    tol_gamma = if (isTRUE(has_gamma)) tol_gamma else NA_real_,
    tol_elbo = tol_elbo,
    min_iter = min_iter,
    patience = patience,
    allow_elbo_drop = allow_elbo_drop,
    has_gamma = isTRUE(has_gamma)
  )
}

.vb_joint_step <- function(
  iter,
  d_state,
  d_sigma,
  d_gamma = NA_real_,
  d_elbo = NA_real_,
  controls,
  compute_elbo = TRUE,
  stable_count = 0L
) {
  state_ok <- is.finite(d_state) && (d_state <= controls$tol_state)
  sigma_ok <- is.finite(d_sigma) && (d_sigma <= controls$tol_sigma)
  gamma_ok <- if (isTRUE(controls$has_gamma)) {
    is.finite(d_gamma) && (d_gamma <= controls$tol_gamma)
  } else {
    TRUE
  }

  if (!isTRUE(compute_elbo)) {
    elbo_ok <- TRUE
  } else if (is.finite(d_elbo)) {
    elbo_ok <- (d_elbo <= controls$tol_elbo) && (d_elbo >= -controls$allow_elbo_drop)
  } else {
    elbo_ok <- FALSE
  }

  joint_ok <- state_ok && sigma_ok && gamma_ok && elbo_ok
  stable_next <- if (iter >= controls$min_iter && joint_ok) stable_count + 1L else 0L
  stop_now <- stable_next >= controls$patience

  list(
    state_ok = state_ok,
    sigma_ok = sigma_ok,
    gamma_ok = gamma_ok,
    elbo_ok = elbo_ok,
    joint_ok = joint_ok,
    stable_count = stable_next,
    stop_now = stop_now
  )
}

.exdqlm_pos_truncnorm_moments <- function(mu, tau2) {
  mu <- as.numeric(mu)
  tau2 <- pmax(as.numeric(tau2), 1e-14)
  tau <- sqrt(tau2)
  alpha <- mu / tau
  Phi <- pmax(stats::pnorm(alpha), 1e-12)
  phi <- stats::dnorm(alpha)
  Lambda <- phi / Phi
  E_pos <- mu + tau * Lambda
  E2_pos <- tau2 + mu^2 + tau * mu * Lambda
  list(
    mean = E_pos,
    second = E2_pos,
    sd = sqrt(pmax(E2_pos - E_pos^2, 0)),
    tau = tau,
    alpha = alpha,
    Phi = Phi,
    Lambda = Lambda
  )
}

.exdqlm_trace_summary <- function(x) {
  z <- as.numeric(x)
  z <- z[is.finite(z)]
  if (!length(z)) {
    return(list(
      mean = NA_real_,
      sd = NA_real_,
      q05 = NA_real_,
      median = NA_real_,
      q95 = NA_real_,
      min = NA_real_,
      max = NA_real_
    ))
  }
  qs <- stats::quantile(z, probs = c(0.05, 0.5, 0.95), na.rm = TRUE, names = FALSE, type = 8)
  list(
    mean = mean(z),
    sd = stats::sd(z),
    q05 = qs[1],
    median = qs[2],
    q95 = qs[3],
    min = min(z),
    max = max(z)
  )
}

.exdqlm_chain_health_metrics <- function(x, n_keep = length(x)) {
  z <- as.numeric(x)
  z <- z[is.finite(z)]
  n_keep <- suppressWarnings(as.numeric(n_keep)[1])
  if (!is.finite(n_keep) || n_keep <= 0) n_keep <- length(z)

  ess <- if (length(z) >= 10L) {
    tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(z))), error = function(e) NA_real_)
  } else {
    NA_real_
  }

  acf1 <- if (length(z) >= 10L) {
    ac <- tryCatch(stats::acf(z, lag.max = 1L, plot = FALSE)$acf, error = function(e) NULL)
    if (is.null(ac) || length(ac) < 2L) NA_real_ else as.numeric(ac[2L])
  } else {
    NA_real_
  }

  geweke_absz <- if (length(z) >= 20L) {
    gz <- tryCatch(coda::geweke.diag(coda::as.mcmc(z))$z, error = function(e) NA_real_)
    as.numeric(abs(gz[1]))
  } else {
    NA_real_
  }

  half_drift <- if (length(z) >= 20L) {
    i <- floor(length(z) / 2L)
    s <- stats::sd(z)
    if (!is.finite(s) || s <= 0 || i < 5L || (length(z) - i) < 5L) {
      NA_real_
    } else {
      as.numeric(abs(mean(z[(i + 1L):length(z)]) - mean(z[seq_len(i)])) / s)
    }
  } else {
    NA_real_
  }

  list(
    n = as.integer(length(z)),
    ess = ess,
    ess_per1k = if (is.finite(ess) && is.finite(n_keep) && n_keep > 0) as.numeric(ess / n_keep * 1000) else NA_real_,
    acf1 = acf1,
    geweke_absz = geweke_absz,
    half_drift = half_drift
  )
}

# Reduced dynamic DQLM CAVI core (no gamma / no s_t block).
.run_dynamic_dqlm_cavi <- function(
  y, p0, model, df, dim.df,
  fix.sigma = TRUE, sig.init = NA_real_,
  tol = 0.1, n.samp = 200L,
  PriorSigma = NULL,
  verbose = TRUE,
  exps0 = NULL,
  max_iter = 200L
) {
  y <- as.numeric(y)
  TT <- length(y)
  p <- length(model$m0)

  GG <- array(model$GG, c(p, p, TT))
  FF <- matrix(model$FF, p, TT)
  m0 <- as.numeric(model$m0)
  C0 <- as.matrix(model$C0)
  df.mat <- make_df_mat(df, dim.df, p)

  # Fixed AL constants at gamma = 0.
  A_tau <- (1 - 2 * p0) / (p0 * (1 - p0))
  B_tau <- 2 / (p0 * (1 - p0))

  if (is.null(PriorSigma)) {
    m_sigma <- 1
    v_sigma <- 10
    PriorSigma <- list(
      a_sig = (m_sigma^2) / v_sigma + 2,
      b_sig = (m_sigma^3) / v_sigma + m_sigma
    )
  }
  a0 <- as.numeric(PriorSigma$a_sig)[1]
  b0 <- as.numeric(PriorSigma$b_sig)[1]
  if (!is.finite(a0) || !is.finite(b0) || a0 <= 0 || b0 <= 0) {
    stop("PriorSigma must define positive finite a_sig and b_sig.")
  }

  sig0 <- if (!is.na(sig.init)) as.numeric(sig.init)[1] else 1
  if (!is.finite(sig0) || sig0 <= 0) sig0 <- 1
  if (isTRUE(fix.sigma) && is.na(sig.init)) {
    stop("fix.sigma=TRUE requires a finite sig.init in reduced DQLM CAVI.")
  }

  # Initialize q(v) moments and q(sigma) moments.
  E_v <- rep(sig0, TT)
  E_inv_v <- rep(1 / sig0, TT)
  E_log_v <- rep(0, TT)
  kappa <- 1 / sig0
  E_sigma <- sig0
  E_inv_sigma <- 1 / sig0
  E_log_sigma <- log(sig0)
  shape_sigma <- NA_real_
  scale_sigma <- NA_real_

  # Local R smoother used for both updates and dynamic ELBO state block.
  update_theta_reduced <- function(ex.f, ex.q) {
    m <- sm <- matrix(NA_real_, p, TT)
    C <- sC <- array(NA_real_, c(p, p, TT))
    a_store <- matrix(NA_real_, p, TT)
    P_store <- array(NA_real_, c(p, p, TT))
    f_vec <- rep(NA_real_, TT)
    q_vec <- rep(NA_real_, TT)
    sfe <- rep(NA_real_, TT)

    # Forward filter
    a <- as.vector(GG[, , 1] %*% m0)
    P <- GG[, , 1] %*% C0 %*% t(GG[, , 1])
    R <- P + df.mat * P
    R <- (R + t(R)) / 2
    f <- as.numeric(t(FF[, 1]) %*% a + ex.f[1])
    q <- as.numeric(t(FF[, 1]) %*% R %*% FF[, 1] + ex.q[1])
    q <- pmax(q, 1e-12)
    m[, 1] <- a + as.vector(t(R) %*% FF[, 1]) * (y[1] - f) / q
    C[, , 1] <- R - (t(R) %*% FF[, 1] %*% t(FF[, 1]) %*% R) / q
    C[, , 1] <- (C[, , 1] + t(C[, , 1])) / 2
    a_store[, 1] <- a
    P_store[, , 1] <- R
    f_vec[1] <- f
    q_vec[1] <- q
    sfe[1] <- (y[1] - f) / sqrt(q)

    if (TT >= 2) {
      for (t in 2:TT) {
        a <- as.vector(GG[, , t] %*% m[, (t - 1)])
        P <- GG[, , t] %*% C[, , (t - 1)] %*% t(GG[, , t])
        R <- P + df.mat * P
        R <- (R + t(R)) / 2
        f <- as.numeric(t(FF[, t]) %*% a + ex.f[t])
        # Keep matrix shape (1 x p) so covariance update uses a p x p outer product.
        fB <- t(FF[, t]) %*% R
        q <- as.numeric(fB %*% FF[, t] + ex.q[t])
        q <- pmax(q, 1e-12)
        m[, t] <- a + as.vector(t(fB)) * (y[t] - f) / q
        C[, , t] <- R - (t(fB) %*% fB) / q
        C[, , t] <- (C[, , t] + t(C[, , t])) / 2
        a_store[, t] <- a
        P_store[, , t] <- R
        f_vec[t] <- f
        q_vec[t] <- q
        sfe[t] <- (y[t] - f) / sqrt(q)
      }
    }

    # Backward smoothing
    sC[, , TT] <- C[, , TT]
    sm[, TT] <- m[, TT]
    if (TT >= 2) {
      for (t in (TT - 1):1) {
        Pn <- P_store[, , (t + 1)]
        svd_P <- svd(Pn)
        inv_P <- svd_P$u %*% diag(1 / pmax(svd_P$d, 1e-12), p) %*% t(svd_P$u)
        J <- C[, , t] %*% t(GG[, , (t + 1)]) %*% inv_P
        sm[, t] <- m[, t] + J %*% (sm[, (t + 1)] - a_store[, (t + 1)])
        sC[, , t] <- C[, , t] + J %*% (sC[, , (t + 1)] - Pn) %*% t(J)
        sC[, , t] <- (sC[, , t] + t(sC[, , t])) / 2
      }
    }

    exps <- apply(FF * sm, 2, sum)
    vars <- vapply(seq_len(TT), function(t) {
      as.numeric(t(FF[, t]) %*% sC[, , t] %*% FF[, t])
    }, numeric(1))
    exps2 <- exps^2 + vars

    # Dynamic ELBO state block via pseudo-model identity.
    y_star <- y - ex.f
    log_py_star <- -0.5 * sum(log(2 * pi * q_vec) + ((y - f_vec)^2) / q_vec)
    E_log_pseudo <- -0.5 * sum(log(2 * pi * ex.q) + (vars + (y_star - exps)^2) / ex.q)
    elbo_alpha <- as.numeric(log_py_star - E_log_pseudo)

    list(
      exps = exps,
      vars = vars,
      exps2 = exps2,
      standard.forecast.errors = sfe,
      sm = sm,
      sC = sC,
      fm = m,
      fC = C,
      elbo_alpha = elbo_alpha
    )
  }

  # Initial theta moments
  if (!is.null(exps0)) {
    if (length(exps0) != TT) stop("exps0 must have same length as y.")
    exps_init <- as.numeric(exps0)
  } else {
    init_dlm <- dlm_df(y, model, df, dim.df, s.priors = list(l0 = 1, S0 = sig0), just.lik = FALSE)
    exps_init <- apply(FF * t(init_dlm$m), 2, sum)
  }

  prev_exps <- exps_init
  prev_sigma <- E_sigma
  iter <- 0L
  stable_count <- 0L
  seq.sigma <- E_sigma
  elbo.seq <- numeric(0)
  delta_state <- numeric(0)
  delta_sigma <- numeric(0)
  delta_elbo <- numeric(0)
  controls <- .vb_joint_controls(tol_state = tol, has_gamma = FALSE)
  stop_reason <- "max_iter"

  tictoc::tic("run time")
  while (iter < max_iter) {
    iter <- iter + 1L

    # q(alpha_{0:T}) update using reduced pseudo-observation model
    ex.f <- A_tau / pmax(E_inv_v, 1e-12)
    ex.q <- B_tau / pmax(kappa * E_inv_v, 1e-12)
    theta.out <- update_theta_reduced(ex.f, ex.q)

    # Residual moments under q(alpha_t)
    E_r <- y - theta.out$exps
    E_r2 <- y^2 - 2 * y * theta.out$exps + theta.out$exps2

    # q(v_t) update (lambda = 1/2)
    chi <- (kappa / B_tau) * E_r2
    psi <- kappa * (2 + (A_tau^2) / B_tau)
    chi <- pmax(chi, 1e-12)
    psi <- pmax(psi, 1e-12)

    E_inv_v <- sqrt(psi / chi)
    E_v <- sqrt(chi / psi) * (1 + 1 / sqrt(chi * psi))
    E_log_v <- .dqlm_gig_elog(0.5, chi, psi)

    # q(sigma) update (or fixed sigma)
    if (!isTRUE(fix.sigma)) {
      shape_sigma <- a0 + 1.5 * TT
      scale_sigma <- b0 + sum(E_v) + (1 / (2 * B_tau)) * sum(E_inv_v * E_r2 - 2 * A_tau * E_r + (A_tau^2) * E_v)
      scale_sigma <- pmax(scale_sigma, 1e-12)

      E_inv_sigma <- shape_sigma / scale_sigma
      E_sigma <- if (shape_sigma > 1) scale_sigma / (shape_sigma - 1) else scale_sigma / shape_sigma
      E_log_sigma <- log(scale_sigma) - digamma(shape_sigma)
      kappa <- E_inv_sigma
    } else {
      E_sigma <- as.numeric(sig.init)[1]
      E_inv_sigma <- 1 / E_sigma
      E_log_sigma <- log(E_sigma)
      kappa <- E_inv_sigma
      shape_sigma <- NA_real_
      scale_sigma <- NA_real_
    }

    # Dynamic ELBO (reduced model)
    E_log_p_sigma <- a0 * log(b0) - lgamma(a0) - (a0 + 1) * E_log_sigma - b0 * E_inv_sigma
    E_log_p_v <- -TT * E_log_sigma - E_inv_sigma * sum(E_v)
    E_log_p_y <- - (TT / 2) * log(2 * pi) - (TT / 2) * log(B_tau) - (TT / 2) * E_log_sigma -
      0.5 * sum(E_log_v) -
      (E_inv_sigma / (2 * B_tau)) * sum(E_inv_v * E_r2 - 2 * A_tau * E_r + (A_tau^2) * E_v)
    H_sigma <- if (!isTRUE(fix.sigma)) {
      shape_sigma + log(scale_sigma) + lgamma(shape_sigma) - (shape_sigma + 1) * digamma(shape_sigma)
    } else {
      0
    }
    H_v <- .dqlm_gig_entropy(0.5, chi, psi, E_inv_v, E_v, E_log_v)
    elbo <- as.numeric(theta.out$elbo_alpha + E_log_p_sigma + E_log_p_v + E_log_p_y + H_sigma + H_v)
    elbo.seq <- c(elbo.seq, elbo)

    # Convergence diagnostics (joint: state + sigma + ELBO)
    d_state <- max(abs(theta.out$exps - prev_exps))
    d_sigma <- abs(E_sigma - prev_sigma)
    d_elbo <- if (length(elbo.seq) >= 2L) {
      elbo.seq[length(elbo.seq)] - elbo.seq[length(elbo.seq) - 1L]
    } else {
      NA_real_
    }
    step <- .vb_joint_step(
      iter = iter,
      d_state = d_state,
      d_sigma = d_sigma,
      d_elbo = d_elbo,
      controls = controls,
      compute_elbo = TRUE,
      stable_count = stable_count
    )
    stable_count <- step$stable_count
    delta_state <- c(delta_state, d_state)
    delta_sigma <- c(delta_sigma, d_sigma)
    delta_elbo <- c(delta_elbo, d_elbo)

    prev_exps <- theta.out$exps
    prev_sigma <- E_sigma
    seq.sigma <- c(seq.sigma, E_sigma)

    if (verbose && (iter %% 5L == 0L)) {
      message(sprintf(
        "DQLM-CAVI iter %3d | d_state=%.3g d_sigma=%.3g | sigma=%.4f | ELBO=%.6f (Delta=%.3e) | stable=%d/%d",
        iter, d_state, d_sigma, E_sigma, elbo, d_elbo, stable_count, controls$patience
      ))
      utils::flush.console()
    }

    if (step$stop_now) {
      stop_reason <- "joint_converged"
      break
    }
  }
  run.time <- tictoc::toc(quiet = TRUE)

  # Posterior sampling from variational factors
  ns <- as.integer(n.samp)
  if (!isTRUE(fix.sigma) && is.finite(shape_sigma) && is.finite(scale_sigma)) {
    samp.sigma <- 1 / stats::rgamma(ns, shape = shape_sigma, rate = scale_sigma)
  } else {
    samp.sigma <- rep(E_sigma, ns)
  }

  # q(v_t): require the package C++ Devroye sampler.
  samp.v <- t(.sample_gig_devroye_required(
    ns, p = 0.5, a = psi, b_vec = chi, context = "q(v_t) sampling"
  ))

  # q(theta_t): independent Gaussian draws per t from smoothed marginals.
  samp.theta <- array(NA_real_, dim = c(p, TT, ns))
  for (t in seq_len(TT)) {
    mu_t <- as.numeric(theta.out$sm[, t])
    S_t <- matrix(theta.out$sC[, , t], nrow = p, ncol = p)
    S_t <- (S_t + t(S_t)) / 2
    chol_t <- tryCatch(chol(S_t), error = function(e) NULL)
    if (is.null(chol_t)) {
      eig <- eigen(S_t, symmetric = TRUE)
      vals <- pmax(eig$values, 1e-12)
      chol_t <- eig$vectors %*% diag(sqrt(vals), p) %*% t(eig$vectors)
    }
    Z <- matrix(stats::rnorm(p * ns), nrow = p, ncol = ns)
    samp.theta[, t, ] <- mu_t + chol_t %*% Z
  }

  # Posterior predictive draws at gamma = 0 (AL model).
  samp.post.pred <- matrix(NA_real_, nrow = TT, ncol = ns)
  for (t in seq_len(TT)) {
    theta_t <- matrix(samp.theta[, t, ], nrow = p, ncol = ns)
    xb <- as.numeric(crossprod(FF[, t], theta_t))
    samp.post.pred[t, ] <- rexal(ns, p0, xb, samp.sigma, 0)
  }

  sig.out <- list(
    E.sigma = E_sigma,
    E.inv.sigma = E_inv_sigma,
    E.log.sigma = E_log_sigma,
    shape = shape_sigma,
    scale = scale_sigma
  )
  vts.out <- list(
    E.uts = E_v,
    E.inv.uts = E_inv_v,
    E.log.uts = sum(E_log_v),
    uts.chi = chi,
    uts.psi = psi,
    uts.lambda = 0.5
  )

  list(
    y = y,
    run.time = (run.time$toc - run.time$tic),
    iter = iter,
    dqlm.ind = TRUE,
    model = model,
    p0 = p0,
    df = df,
    dim.df = dim.df,
    sig.init = sig.init,
    seq.sigma = seq.sigma,
    samp.theta = samp.theta,
    samp.post.pred = samp.post.pred,
    map.standard.forecast.errors = theta.out$standard.forecast.errors,
    samp.sigma = samp.sigma,
    samp.vts = samp.v,
    theta.out = theta.out,
    sig.out = sig.out,
    vts.out = vts.out,
    fix.sigma = fix.sigma,
    fix.gamma = TRUE,
    diagnostics = list(
      elbo = elbo.seq,
      convergence = list(
        converged = identical(stop_reason, "joint_converged"),
        stop_reason = stop_reason,
        iter = iter,
        stable_count = stable_count,
        criteria = controls,
        final = list(
          delta_state = if (length(delta_state)) utils::tail(delta_state, 1L) else NA_real_,
          delta_sigma = if (length(delta_sigma)) utils::tail(delta_sigma, 1L) else NA_real_,
          delta_gamma = NA_real_,
          delta_elbo = if (length(delta_elbo)) utils::tail(delta_elbo, 1L) else NA_real_
        )
      ),
      deltas = list(
        state = delta_state,
        sigma = delta_sigma,
        gamma = rep(NA_real_, length(delta_state)),
        elbo = delta_elbo
      )
    )
  )
}


# Reduced static DQLM CAVI core (no gamma / no s block).
.run_static_dqlm_cavi <- function(
  y, X, p0,
  max_iter = 1000L,
  tol = 1e-4,
  b0 = NULL,
  V0 = NULL,
  beta_prior_obj = NULL,
  a_sigma = 1,
  b_sigma = 1,
  init = NULL,
  verbose = TRUE
) {
  y <- as.numeric(y)
  X <- as.matrix(X)
  storage.mode(X) <- "double"
  n <- length(y)
  p <- ncol(X)
  if (nrow(X) != n) stop("nrow(X) must match length(y).")
  if (!(p0 > 0 && p0 < 1)) stop("p0 must be in (0,1).")

  if (is.null(b0)) b0 <- rep(0, p)
  if (is.null(V0)) V0 <- diag(1e6, p)
  V0 <- as.matrix(V0)
  if (!all(dim(V0) == c(p, p))) stop("V0 must be p x p.")
  if (is.null(beta_prior_obj)) {
    beta_prior_obj <- .static_beta_prior_make(
      beta_prior = "ridge",
      p = p,
      b0 = b0,
      V0 = V0,
      beta_prior_controls = NULL,
      warn_rhs_b0 = FALSE,
      warn_rhs_V0 = FALSE
    )
  }

  A_tau <- (1 - 2 * p0) / (p0 * (1 - p0))
  B_tau <- 2 / (p0 * (1 - p0))

  # Initialization
  m_beta <- if (!is.null(init$beta)) as.numeric(init$beta) else rep(0, p)
  if (length(m_beta) != p) m_beta <- rep(m_beta[1], p)
  V_beta <- V0
  beta_state <- beta_prior_obj$init_vb()

  sigma0 <- if (!is.null(init$sigma)) as.numeric(init$sigma)[1] else 1
  if (!is.finite(sigma0) || sigma0 <= 0) sigma0 <- 1
  a_q <- a_sigma + 1.5 * n
  b_q <- a_q * sigma0
  kappa <- a_q / b_q

  ell <- rep(1, n) # E[1 / v_t]
  nu <- rep(1, n)  # E[v_t]
  mlogv <- rep(0, n)
  chi <- rep(1, n)
  psi <- 1

  converged <- FALSE
  elbo_trace <- numeric(0)
  iter <- 0L
  stable_count <- 0L
  delta_beta <- numeric(0)
  delta_sigma <- numeric(0)
  delta_elbo <- numeric(0)
  controls <- .vb_joint_controls(tol_state = tol, has_gamma = FALSE)
  stop_reason <- "max_iter"

  if (verbose) {
    cat(sprintf("Static DQLM CAVI | n=%d, p=%d | max_iter=%d, tol=%.1e\n",
                n, p, as.integer(max_iter), tol))
  }

  t0 <- proc.time()[3]
  for (iter in seq_len(as.integer(max_iter))) {
    prev_m_beta <- m_beta
    prev_sigma <- if (a_q > 1) b_q / (a_q - 1) else b_q / a_q

    # (1) q(beta): Normal
    W <- (kappa / B_tau) * ell
    Xw <- X * sqrt(W)
    prior_sys <- beta_prior_obj$beta_system_vb(beta_state)
    V_inv <- crossprod(Xw) + prior_sys$Prec
    Uc <- tryCatch(chol(V_inv), error = function(e) NULL)
    if (is.null(Uc)) Uc <- chol(V_inv + 1e-10 * diag(p))
    V_beta <- chol2inv(Uc)

    rhs <- prior_sys$h + (kappa / B_tau) * (
      crossprod(X, ell * y) - A_tau * colSums(X)
    )
    m_beta <- as.numeric(V_beta %*% rhs)
    beta_state <- beta_prior_obj$update_vb(
      beta_state,
      list(m = m_beta, V = V_beta)
    )

    # Residual moments under q(beta)
    m_eta <- as.numeric(X %*% m_beta)
    s_eta <- rowSums((X %*% V_beta) * X)
    E_r <- y - m_eta
    E_r2 <- s_eta + E_r^2

    # (2) q(v_t): GIG(lambda=1/2)
    chi <- (kappa / B_tau) * E_r2
    psi <- kappa * (2 + (A_tau^2) / B_tau)
    chi <- pmax(chi, 1e-12)
    psi <- pmax(psi, 1e-12)

    ell <- sqrt(psi / chi)
    nu <- sqrt(chi / psi) * (1 + 1 / sqrt(chi * psi))
    mlogv <- .dqlm_gig_elog(0.5, chi, psi)

    # (3) q(sigma): Inverse-gamma
    a_q <- a_sigma + 1.5 * n
    b_q <- b_sigma + sum(nu) + (1 / (2 * B_tau)) *
      sum(ell * E_r2 - 2 * A_tau * E_r + (A_tau^2) * nu)
    b_q <- pmax(b_q, 1e-12)
    kappa <- a_q / b_q

    E_sigma <- if (a_q > 1) b_q / (a_q - 1) else b_q / a_q
    E_inv_sigma <- kappa
    E_log_sigma <- log(b_q) - digamma(a_q)

    # ELBO
    E_log_p_beta <- beta_prior_obj$elbo_vb(
      beta_state,
      list(m = m_beta, V = V_beta)
    )

    E_log_p_sigma <- a_sigma * log(b_sigma) - lgamma(a_sigma) -
      (a_sigma + 1) * E_log_sigma - b_sigma * E_inv_sigma

    E_log_p_v <- -n * E_log_sigma - E_inv_sigma * sum(nu)

    E_log_p_y <- -(n / 2) * log(2 * pi) - (n / 2) * log(B_tau) -
      (n / 2) * E_log_sigma - 0.5 * sum(mlogv) -
      (E_inv_sigma / (2 * B_tau)) *
      sum(ell * E_r2 - 2 * A_tau * E_r + (A_tau^2) * nu)

    logdetVb <- as.numeric(determinant(V_beta, logarithm = TRUE)$modulus)
    H_beta <- 0.5 * (p * (1 + log(2 * pi)) + logdetVb)
    H_sigma <- a_q + log(b_q) + lgamma(a_q) - (a_q + 1) * digamma(a_q)
    H_v <- .dqlm_gig_entropy(0.5, chi, rep(psi, n), ell, nu, mlogv)

    elbo <- as.numeric(E_log_p_beta + E_log_p_sigma + E_log_p_v + E_log_p_y + H_beta + H_sigma + H_v)
    elbo_trace <- c(elbo_trace, elbo)

    d_beta <- max(abs(m_beta - prev_m_beta))
    d_sigma <- abs(E_sigma - prev_sigma)
    d_elbo <- if (length(elbo_trace) >= 2) {
      elbo_trace[length(elbo_trace)] - elbo_trace[length(elbo_trace) - 1]
    } else {
      NA_real_
    }
    step <- .vb_joint_step(
      iter = iter,
      d_state = d_beta,
      d_sigma = d_sigma,
      d_elbo = d_elbo,
      controls = controls,
      compute_elbo = TRUE,
      stable_count = stable_count
    )
    stable_count <- step$stable_count
    delta_beta <- c(delta_beta, d_beta)
    delta_sigma <- c(delta_sigma, d_sigma)
    delta_elbo <- c(delta_elbo, d_elbo)

    if (verbose && (iter %% 25L == 0L)) {
      cat(sprintf(
        "iter %4d | d_beta=%.3e d_sigma=%.3e | sigma=%.4f | ELBO=%.6f (Delta=%.3e) | stable=%d/%d\n",
        iter, d_beta, d_sigma, E_sigma, elbo, d_elbo, stable_count, controls$patience
      ))
    }

    if (step$stop_now) {
      converged <- TRUE
      stop_reason <- "joint_converged"
      break
    }
  }

  t1 <- proc.time()[3]

  ret <- list(
    dqlm.ind = TRUE,
    qbeta = list(m = m_beta, V = V_beta),
    qv = list(
      chi = chi,
      psi = psi,
      E_v = nu,
      E_inv_v = ell,
      E_log_v = mlogv
    ),
    qsig = list(
      a = a_q,
      b = b_q,
      E_sigma = if (a_q > 1) b_q / (a_q - 1) else b_q / a_q,
      E_inv_sigma = kappa,
      E_log_sigma = log(b_q) - digamma(a_q)
    ),
    converged = converged,
    iter = iter,
    run.time = as.numeric(t1 - t0),
    beta_prior = list(
      type = beta_prior_obj$type,
      controls = beta_prior_obj$controls,
      summary = beta_prior_obj$summary_vb(beta_state),
      state = if (.static_is_rhs_family(beta_prior_obj$type)) beta_state else NULL
    ),
    misc = list(
      p0 = p0,
      n = n,
      p = p,
      A = A_tau,
      B = B_tau,
      elbo = elbo_trace
    ),
    diagnostics = list(
      elbo = elbo_trace,
      convergence = list(
        converged = converged,
        stop_reason = stop_reason,
        iter = iter,
        stable_count = stable_count,
        criteria = controls,
        final = list(
          delta_state = if (length(delta_beta)) utils::tail(delta_beta, 1L) else NA_real_,
          delta_sigma = if (length(delta_sigma)) utils::tail(delta_sigma, 1L) else NA_real_,
          delta_gamma = NA_real_,
          delta_elbo = if (length(delta_elbo)) utils::tail(delta_elbo, 1L) else NA_real_
        )
      ),
      deltas = list(
        state = delta_beta,
        sigma = delta_sigma,
        gamma = rep(NA_real_, length(delta_beta)),
        elbo = delta_elbo
      )
    )
  )
  if (.static_is_rhs_family(beta_prior_obj$type)) {
    .static_rhs_maybe_warn_collapse(ret$beta_prior$summary, beta_prior_obj$controls)
  }
  ret
}
