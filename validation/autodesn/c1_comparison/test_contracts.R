source("validation/autodesn/c1_comparison/helpers.R")
library(testthat)
test_that("grouped integrated scores preserve dense Gaussian target and Gibbs RNG", {
  set.seed(71);y <- rnorm(30)
  b <- autodesn_prepare_bank(y,list(matrix(numeric(),30,0),matrix(rnorm(90),30,3),matrix(rnorm(90),30,3),matrix(rnorm(180),30,6)))
  cache <- c1_score_cache(b)
  for(v in c(.1,1,5)) for(lam in c(.1,1,10)) {
    expect_equal(c1_grouped(cache,b,v,lam),.autodesn_model_probabilities(b,v,lam),tolerance=1e-12)
    logp <- vapply(b$models,function(m) {
      C <- v*diag(length(y))+10+tcrossprod(m$X[,-1,drop=FALSE])/lam
      R <- chol(C);z <- forwardsolve(t(R),y)
      -.5*(length(y)*log(2*pi)+2*sum(log(diag(R)))+sum(z^2))
    },0)
    expect_equal(c1_grouped(cache,b,v,lam),.autodesn_softmax(log(b$prior)+logp),tolerance=1e-10)
  }
  original <- autodesn_fit_bank(b,n_burn=10,n_mcmc=40,seed=23)
  fast <- c1_sampler(b)(b,n_burn=10,n_mcmc=40,seed=23)
  expect_identical(original$draws,fast$draws);expect_identical(original$beta,fast$beta)
})
test_that("shared recursive API matches builder and never reads future targets", {
  set.seed(72);y <- rnorm(180)
  specs <- autodesn_candidates(D=1:2,n=5,m=3,alpha=.6,rho=.4,seed=11,washout=30,act_k="identity")
  specs <- lapply(specs,function(x) {x$n_tilde <- x$n[seq_len(x$D-1L)];x})
  b <- autodesn_build_bank(y[1:150],specs,conditioning=30,washout=30)
  for(t in b$templates) expect_lt(c1_warmup(t,b$history_scaled,30L),1e-3)
  f <- autodesn_fit_bank(b,n_burn=10,n_mcmc=50,seed=5)
  cp <- c1_compact(f,1:20,list())
  states <- hr_origin_states(cp,y,150:160)
  full <- autodesn_build_bank(y[1:160],specs,conditioning=30,washout=30)
  for(j in 1:2) expect_equal(states$states[[11]][[j]],c1_lean_template(full$templates[[j]])$states$H_last,tolerance=1e-11)
  z <- matrix(rnorm(3*20*2),3)
  fc <- hr_auto(cp,states$states[[1]],states$history_scaled[1:150],3,2,z)
  p <- forecast_paths.autodesn_fit(f,3,draw_index=1:20,inner_paths=2,innovations=z,backend="batched")
  expect_equal(fc$yrep,p$yrep,tolerance=1e-12)
  changed <- y;changed[151:180] <- 1e6
  s2 <- hr_origin_states(cp,changed,150:160)
  f2 <- hr_auto(cp,s2$states[[1]],s2$history_scaled[1:150],3,2,z)
  expect_identical(fc$yrep,f2$yrep)
})
test_that("AutoARIMA fixed-parameter updates agree at the initial origin", {
  set.seed(73);y <- as.numeric(arima.sim(list(ar=.65),n=100))
  f <- forecast::Arima(y[1:80],order=c(1,0,0),method="ML")
  updated <- forecast::Arima(y[1:80],model=f);updated$sigma2 <- f$sigma2
  expect_identical(coef(f),coef(updated))
  expect_equal(forecast::forecast(f,h=3)$mean,forecast::forecast(updated,h=3)$mean,tolerance=1e-9)
  changed <- y;changed[81:100] <- 1e8
  u2 <- forecast::Arima(changed[1:80],model=f);u2$sigma2 <- f$sigma2
  expect_equal(forecast::forecast(updated,h=3)$upper,forecast::forecast(u2,h=3)$upper,tolerance=1e-10)
  u3 <- forecast::Arima(y[1:81],model=f)
  expect_identical(coef(f),coef(u3))
})
cat("C1 R CONTRACTS PASSED\n")
