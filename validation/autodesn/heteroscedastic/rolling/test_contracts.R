source("validation/autodesn/load_checkout.R")
source("validation/autodesn/long_horizon/helpers.R")
source("validation/autodesn/heteroscedastic/dgp.R")
source("validation/autodesn/heteroscedastic/forecasting.R")
source("validation/autodesn/heteroscedastic/rolling/helpers.R")
library(testthat)
test_that("rolling states and recursive forecasts obey issue-time information", {
  y <- hh_simulate("smooth_scale",2600L,611L)$y
  bank <- autodesn_build_bank(y[1:2500],lh_specs()$specifications[c(1L,20L)],conditioning=500L,washout=500L)
  fit <- hh_fit(bank,list(chains=3L,n_burn=10L,n_mcmc=30L),710L,1L)
  cp <- hr_checkpoint(fit$fit,1:8,fit$diagnostics)
  origins <- 2500:2503; states <- hr_origin_states(cp,y[1:2503],origins)
  # Verify every layer against the shared feature builder with frozen scaling.
  z <- (y[1:2503]-bank$preprocessing$center)/bank$preprocessing$scale
  for(j in unique(cp$draws$model)) {
    spec <- bank$specifications[[j]]
    template <- .autodesn_seed(spec$seed,function() do.call(qdesn_fit_vb,c(list(y=z,p0=.5,fit_readout=FALSE),spec)))
    for(i in seq_along(origins)) for(d in seq_len(spec$D))
      expect_equal(states$states[[i]][[j]][[d]],as.numeric(template$states$H_all[[d]][origins[i],]),tolerance=1e-12)
  }
  noise <- matrix(seq(-1,1,length.out=30L*16L),30L,16L)
  first <- hr_auto(cp,states$states[[1]],z[1:2500],30L,2L,noise)
  direct <- hh_auto(fit$fit,30L,1:8,2L,noise)
  expect_equal(first$yrep,direct$yrep,tolerance=1e-12)
  expect_equal(first$mu_draws,direct$mu_draws,tolerance=1e-12)
  one <- hh_auto(fit$fit,4L,1:8,2L,noise[1:4,],y[2501:2504])
  for(i in seq_along(origins)) {
    f <- hr_auto(cp,states$states[[i]],z[seq_len(origins[i])],30L,2L,noise)
    expect_equal(f$mu_draws[1,],one$mu_draws[i,],tolerance=1e-12)
    expect_identical(f$model,rep(cp$draws$model,each=2L))
    expect_identical(f$source_draw,rep(cp$source_ids,each=2L))
  }
  changed <- y[1:2503];changed[2502:2503] <- changed[2502:2503]+4
  s2 <- hr_origin_states(cp,changed,origins)
  for(i in 1:2) {
    f <- hr_auto(cp,states$states[[i]],states$history_scaled[seq_len(origins[i])],30L,2L,noise)
    g <- hr_auto(cp,s2$states[[i]],s2$history_scaled[seq_len(origins[i])],30L,2L,noise)
    expect_identical(f$yrep,g$yrep)
  }
  f <- hr_auto(cp,states$states[[3]],states$history_scaled[1:2502],30L,2L,noise)
  g <- hr_auto(cp,s2$states[[3]],s2$history_scaled[1:2502],30L,2L,noise)
  expect_gt(max(abs(f$yrep-g$yrep)),0)
  run <- function(i) hr_auto(cp,states$states[[i]],states$history_scaled[seq_len(origins[i])],30L,2L,noise)$yrep
  serial <- lapply(seq_along(origins),run)
  forked <- parallel::mclapply(seq_along(origins),run,mc.cores=2L,mc.set.seed=FALSE)
  expect_identical(serial,forked)
  expect_lt(as.numeric(object.size(cp)),2e6)
})
test_that("rolling innovation banks and origin coverage are reproducible", {
  z <- hr_noise(864020L,2500L,16L)
  all <- .autodesn_seed(864420L,function() matrix(rnorm(100L*192L*128L),100L))
  cols <- as.vector(outer(1:16,(0:191)*128L,"+"))
  expect_identical(z,all[1:30,cols])
  small <- hr_noise(864020L,2500L,8L)
  choose <- as.vector(outer(1:8,(0:191)*16L,"+"))
  expect_identical(small,z[,choose])
  lattice <- expand.grid(origin=2500:2570,horizon=1:30)
  expect_equal(nrow(lattice),2130L)
  expect_equal(range(lattice$origin+lattice$horizon),c(2501L,2600L))
  expect_equal(as.integer(table(lattice$horizon)),rep(71L,30L))
})
cat("ROLLING_CONTRACTS_COMPLETED\n")
test_that("three-layer state order and GJR observed updates agree with direct recursion", {
  y <- sin((1:200)/7)+.1*cos((1:200)/3)
  s <- list(D=3L,n=rep(4L,3),n_tilde=rep(4L,2),m=2L,alpha=.4,rho=rep(.5,3),
    washout=20L,seed=31L,act_f="tanh",act_k="identity",standardize_inputs=TRUE)
  bank <- autodesn_build_bank(y[1:190],list(s),conditioning=20L,washout=20L)
  object <- bank$templates[[1L]];object$fit <- list(target_label="test");class(object) <- c("qdesn_normal_fit","list")
  z <- (y-bank$preprocessing$center)/bank$preprocessing$scale
  x <- bank$specifications[[1L]]
  complete <- .autodesn_seed(x$seed,function() do.call(qdesn_fit_vb,c(list(y=z,p0=.5,fit_readout=FALSE),x)))
  state <- lapply(object$states$H_all,function(a) as.numeric(a[190,]))
  for(t in 190:198) {
    state <- hr_probe(object,state,z[seq_len(t)],z[t+1L])
    for(d in 1:3) expect_equal(state[[d]],as.numeric(complete$states$H_all[[d]][t+1L,]),tolerance=1e-12)
  }
  data <- sin((1:2600)/6)
  g <- list(parameters=c(intercept=.1,phi=.4,omega=.03,alpha=.06,gamma=.12,beta=.85),
    variance=.5,error=-.2,last_y=data[2500])
  objects <- hr_gjr_origins(g,data,2500:2503)
  noise <- matrix(seq(-1,1,length.out=4*16),4,16)
  direct <- hh_gjr(g,4L,noise,data[2501:2504])
  for(i in 1:4) {
    f <- hh_gjr(objects[[i]],1L,noise[i,,drop=FALSE])
    expect_equal(f$mu_draws[1,],direct$mu_draws[i,],tolerance=1e-12)
    expect_equal(f$sd_draws[1,],direct$sd_draws[i,],tolerance=1e-12)
  }
})
cat("ALL_ROLLING_CONTRACTS_COMPLETED\n")
