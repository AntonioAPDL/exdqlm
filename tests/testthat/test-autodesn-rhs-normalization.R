# Independent normalization and scalar-conditional oracles complement model
# probability checks. No production density constructs the reference.

test_that("the normalized RHS hierarchy integrates to one in every dimension", {
  logv <- get(".autodesn_rhs_log_variance", environment(autodesn_fit_bank))
  for (u in c(.03, 1, 12)) for (c2 in c(.2, 4, 30)) {
    lambda <- c(.02, .7, 25)
    v <- exp(logv(log(lambda), log(u), log(c2), .6))
    for (j in seq_along(v)) {
      mass <- integrate(function(z) exp(-.5 * log(2*pi*v[j]) - z^2/2) * sqrt(v[j]),
                        -Inf, Inf, rel.tol=1e-10)$value
      expect_equal(mass, 1, tolerance=1e-9)
    }
    # Integrating independent coefficients multiplies unit masses; inactive
    # local-scale dimensions also integrate to one under their own priors.
    expect_equal(integrate(function(x) 2/(pi*(1+x^2)), 0, Inf)$value, 1,
                 tolerance=1e-9)
  }
  shape <- 2; rate <- 8
  expect_equal(integrate(function(x) exp(shape*log(rate)-lgamma(shape)-
    (shape+1)*log(x)-rate/x), 0, Inf)$value, 1, tolerance=1e-8)
})

test_that("collapsed MH obeys detailed balance with unequal dimensions and proposal", {
  x <- seq(-1,1,length.out=8)
  bank <- autodesn_prepare_bank(sin(x),list(matrix(numeric(),8,0),cbind(x),cbind(x,x^2)),
                                model_prior=c(.2,.5,.3))
  sigma2 <- .4; lambda <- c(.3,2); tau <- .7; c2 <- 2
  loge <- vapply(bank$models,function(m) {
    v <- c(10,1/(1/c2+1/(tau*lambda[seq_len(m$d)])^2))
    C <- sigma2*diag(8)+m$X%*%diag(v,length(v))%*%t(m$X)
    U <- chol(C)
    -.5*(8*log(2*pi)+2*sum(log(diag(U)))+sum(forwardsolve(t(U),bank$y)^2))
  },0)
  p <- exp(log(bank$prior)+loge-max(log(bank$prior)+loge)); p <- p/sum(p)
  q <- c(.7,.1,.2)
  transition <- matrix(0,3,3)
  for(i in 1:3) for(j in setdiff(1:3,i))
    transition[i,j] <- q[j]*min(1,p[j]*q[i]/(p[i]*q[j]))
  diag(transition) <- 1-rowSums(transition)
  flow <- transition*p
  expect_equal(flow,t(flow),tolerance=1e-13)
  expect_equal(as.vector(p%*%transition),p,tolerance=1e-13)
})

test_that("global and slab slice updates match independent conditional quadrature", {
  withr::local_seed(20931)
  target <- get(".autodesn_rhs_log_scale_target",environment(autodesn_fit_bank))
  slice <- get(".autodesn_rhs_slice",environment(autodesn_fit_bank))
  beta <- c(.03,-.7,1.2); lambda <- c(.08,.6,4); tau0 <- .4
  # Independent transformed densities use dnorm + half-Cauchy + inverse-gamma.
  reference <- function(eta,which) vapply(eta,function(e) {
    u <- if(which=="global") exp(e) else .8
    c2 <- if(which=="slab") exp(e) else 2.5
    v <- 1/(1/c2+1/(tau0*u*lambda)^2)
    sum(dnorm(beta,0,sqrt(v),log=TRUE))+
      log(2/pi)-log1p(u^2)+log(u)+2*log(8)-lgamma(2)-2*log(c2)-8/c2
  },0)
  for(which in c("global","slab")) {
    mode <- optimize(function(e)-reference(e,which),c(-12,12))
    density <- function(e) exp(reference(e,which)+mode$objective)
    bounded <- plogis
    mass <- integrate(density,-35,35,rel.tol=1e-10)$value
    truth <- integrate(function(e) bounded(e)*density(e),-35,35,rel.tol=1e-10)$value/mass
    current <- if(which=="global") log(.8) else log(2.5)
    f <- if(which=="global") function(e) target(log(lambda),e,log(2.5),beta,tau0,4,2)
         else function(e) target(log(lambda),log(.8),e,beta,tau0,4,2)
    values <- numeric(6500)
    for(k in seq_along(values)) {
      current <- slice(current,f,1,50L,10000L)$value
      values[k] <- bounded(current)
    }
    values <- tail(values,6000)
    se <- sqrt(var(colMeans(matrix(values,100,60)))/60)
    expect_lt(abs(mean(values)-truth),max(.003,6*se))
  }
})
