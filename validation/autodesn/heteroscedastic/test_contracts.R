source("validation/autodesn/load_checkout.R")
source("validation/autodesn/long_horizon/helpers.R")
source("validation/autodesn/heteroscedastic/dgp.R")
source("validation/autodesn/heteroscedastic/forecasting.R")
library(testthat)

test_that("all simulated prefixes are invariant and scales vary", {
  for (kind in hh_kinds) {
    a <- hh_simulate(kind, 2600L, 783001L); b <- hh_simulate(kind, 2500L, 783001L)
    for (field in c("y", "mu", "sd", "state")) expect_identical(a[[field]][1:2500], b[[field]])
    expect_true(all(is.finite(a$y))); expect_true(all(a$sd > 0))
    expect_gt(max(a$sd)/min(a$sd), 2)
    filter <- hh_filter(kind, a$y)
    if (kind != "switching_seasonal") {
      expect_equal(filter$mean, a$mu, tolerance = 1e-12)
      expect_equal(filter$predictive_sd, a$sd, tolerance = 1e-12)
    } else {
      expect_equal(rowSums(filter$filtered_weights), rep(1,2600), tolerance = 1e-12)
      expect_true(all(filter$filtered_weights >= 0))
    }
  }
})
test_that("GJR recursion agrees with an independent manual calculation", {
  eps <- c(-2, 1, -.5); manual <- numeric(3); previous <- 1
  for (i in 1:3) {
    manual[i] <- .03 + (.06 + ifelse(eps[i] < 0, .12, 0))*eps[i]^2 + .85*previous
    previous <- manual[i]
  }
  result <- Reduce(function(v,e) hh_gjr_step(e,v), eps, init = 1, accumulate = TRUE)[-1L]
  expect_equal(unlist(result), manual)
  expect_equal(.06+.12/2+.85, .97)
  expect_lt(3*(.06^2+.06*.12+.12^2/2)+2*.85*(.06+.12/2)+.85^2, 1)
  p <- hh_gjr_parameters(c(.1,.5,-2,1,2,3))
  expect_true(all(p[3:6]>0)); expect_lt(p[4]+p[5]/2+p[6],.995)
})
test_that("the fitted GJR likelihood agrees with a scalar implementation", {
  y <- sin(1:50/3)+cos(1:50/7); theta <- c(.1,.3,-2,1,2,3)
  p <- hh_gjr_parameters(theta); variance <- .8; error <- 0; last <- 0; ll <- 0
  for(t in seq_along(y)) {
    variance <- p[3]+p[4]*error^2+p[5]*error^2*(error<0)+p[6]*variance
    error <- y[t]-p[1]-p[2]*last; last <- y[t]
    if(t>10) ll <- ll+.5*(log(2*pi*variance)+error^2/variance)
  }
  f <- hh_gjr_filter(y,11:50,theta,.8,TRUE)
  expect_equal(f$objective,unname(ll),tolerance=1e-12)
  expect_equal(f$variance,unname(variance),tolerance=1e-12)
  expect_equal(f$error,unname(error),tolerance=1e-12)
})
test_that("the hidden-state filter and predictive mixture match hand calculations", {
  y <- c(.1,-.8,.4); f <- hh_filter("switching_seasonal", y)
  w <- c(5/7,2/7); lag <- hh_lags(numeric())
  for(t in seq_along(y)) {
    pred <- as.numeric(w %*% matrix(c(.98,.02,.05,.95),2,byrow=TRUE))
    mu <- c(hh_location("switching_seasonal",t,lag,1),hh_location("switching_seasonal",t,lag,2))
    sd <- c(hh_scale("switching_seasonal",t,lag,1),hh_scale("switching_seasonal",t,lag,2))
    w <- pred*dnorm(y[t],mu,sd); w <- w/sum(w)
    expect_equal(f$filtered_weights[t,],unname(w),tolerance=1e-12)
    lag <- hh_shift(lag,y[t])
  }
  exact <- hh_components("switching_seasonal",4,lag,1,w)
  fc <- hh_oracle("switching_seasonal",y,1L,60000L,91L)
  predvar <- exact$predictive_sd^2
  expect_lt(abs(mean(fc$yrep)-exact$mean),6*sqrt(predvar/60000))
  fourth <- sum(exact$probability*(3*exact$sd^4+6*exact$sd^2*(exact$mu-exact$mean)^2+(exact$mu-exact$mean)^4))
  expect_lt(abs(mean((fc$yrep-exact$mean)^2)-predvar),6*sqrt((fourth-predvar^2)/60000))
})
test_that("oracle issue time excludes current and later observations", {
  for(kind in hh_kinds) {
    d <- hh_simulate(kind,2600L,721L); observed <- d$y[2501:2600]
    a <- hh_oracle(kind,d$y[1:2500],100L,128L,31L,observed)
    observed[26:100] <- observed[26:100]+3
    b <- hh_oracle(kind,d$y[1:2500],100L,128L,31L,observed)
    expect_identical(a$yrep[1:26,],b$yrep[1:26,])
    expect_gt(max(abs(a$mu_draws[27:100,]-b$mu_draws[27:100,])),0)
  }
})
test_that("exact rows, parallel replay and AutoDESN feedback are correct", {
  d <- hh_simulate("smooth_scale",2600L,901L)
  bank <- autodesn_build_bank(d$y[1:2500],lh_specs()$specifications[c(1L,20L)],conditioning=500L,washout=500L)
  expect_identical(bank$keep_idx,501:2500); expect_equal(bank$n,2000L)
  expect_equal(bank$preprocessing$center,mean(d$y[1:500]))
  cfg <- list(chains=3L,n_burn=15L,n_mcmc=40L)
  set.seed(31); rng <- .Random.seed
  a <- hh_fit(bank,cfg,101L,1L); b <- hh_fit(bank,cfg,101L,3L)
  expect_identical(.Random.seed,rng)
  expect_identical(a$fit$draws,b$fit$draws); expect_identical(a$fit$beta,b$fit$beta)
  z <- matrix(seq(-1,1,length.out=100*8),100,8); ids <- 1:4
  observed <- d$y[2501:2600]
  f <- hh_auto(a$fit,100L,ids,2L,z,observed)
  # Independent serial single-draw calls verify the optimized shared-history
  # adapter across every lead, not just its first Gaussian location.
  for(k in seq_along(ids)) {
    j <- a$fit$draws$model[ids[k]]; beta <- a$fit$beta[[ids[k]]]
    beta[-1L] <- beta[-1L]/bank$models[[j]]$divisor
    object <- bank$templates[[j]]; object$fit <- list(target_label="test")
    class(object) <- c("qdesn_normal_fit","list")
    direct <- forecast_paths.qdesn_normal_fit(object,100L,y_hist=bank$history_scaled,
      draws=list(beta=matrix(beta,1L),omega2=a$fit$draws$variance[ids[k]]),
      y_future_obs=(observed-bank$preprocessing$center)/bank$preprocessing$scale,
      innovations=matrix(0,100L,1L),backend="serial")
    expect_equal(f$mu_draws[,2*k-1L],as.numeric(.autodesn_unscale(bank,direct$mu_draws)),tolerance=1e-12)
  }
  observed[26:100] <- observed[26:100]+3
  g <- hh_auto(a$fit,100L,ids,2L,z,observed)
  expect_identical(f$mu_draws[1:26,],g$mu_draws[1:26,])
  expect_gt(max(abs(f$mu_draws[27:100,]-g$mu_draws[27:100,])),0)
  recursive <- hh_auto(a$fit,100L,ids,2L,z)
  expect_equal(f$mu_draws[1,],recursive$mu_draws[1,],tolerance=1e-12)
  expect_equal(f$yrep,f$mu_draws+f$sd_draws*z,tolerance=1e-12)
  expect_equal(recursive$origin,2500L)
  expect_true(all(is.finite(recursive$yrep)))
  ref <- hh_gaussian_fit(bank,1L,8L,111L)
  r <- hh_gaussian(ref,100L,z,d$y[2501:2600]); s <- hh_gaussian(ref,100L,z,observed)
  expect_identical(r$mu_draws[1:26,],s$mu_draws[1:26,])
  gjr <- hh_gjr_fit(d$y[1:2500],bank$keep_idx)
  expect_equal(gjr$convergence,0L); expect_true(is.finite(gjr$objective))
  p <- gjr$parameters
  nextvar <- p[3]+p[4]*gjr$error^2+p[5]*gjr$error^2*(gjr$error<0)+p[6]*gjr$variance
  gf <- hh_gjr(gjr,100L,z,d$y[2501:2600]); gg <- hh_gjr(gjr,100L,z,observed)
  expect_equal(unname(gf$sd_draws[1,]),rep(unname(sqrt(nextvar)),8L))
  expect_identical(gf$yrep[1:26,],gg$yrep[1:26,])
})
test_that("mixture log scores are stable and match exact Gaussian densities", {
  expect_equal(hh_logmean(c(-1000,-1000)), -1000)
  expect_equal(hh_logmean(log(c(.2,.8))),log(.5))
  z <- matrix(qnorm((1:1000-.5)/1000),1L)
  fc <- list(yrep=z*2+3,mu_draws=matrix(3,1L,1000L),sd_draws=matrix(2,1L,1000L))
  s <- hh_score(fc,4,3,3)
  expect_equal(s$negative_log_score,-dnorm(4,3,2,log=TRUE))
  expect_equal(s$predictive_sd,2); expect_equal(s$innovation_sd,2)
})
