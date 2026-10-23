# Training-only readout scaling, shared Q-DESN conventions and raw transport.
scaling_internal <- function(name) get(name,environment(autodesn_fit_bank),inherits=TRUE)

test_that("AutoDESN readout z-scores match the shared Q-DESN helper", {
 x <- seq(-2,3,length.out=31)
 H <- cbind(20+4*x,-7+.2*x^2,rep(3,31),rep(0,31))
 y <- sin(x)
 b <- autodesn_prepare_bank(y,list(H),normalize_features=FALSE,standardize_features=TRUE)
 m <- b$models[[1]]
 shared <- scaling_internal("readout_scale_fit")(cbind(1,H[,1:2]),has_intercept=TRUE)
 expect_equal(unname(m$X),unname(shared$X),tolerance=1e-12)
 expect_equal(colMeans(m$X[,-1]),c(0,0),tolerance=1e-12,ignore_attr=TRUE)
 expect_equal(apply(m$X[,-1],2,sd),c(1,1),tolerance=1e-12,ignore_attr=TRUE)
 expect_equal(m$active_features,1:2)
 expect_equal(m$dropped_features,3:4)
 expect_equal(m$raw_d,4L)
 expect_equal(m$d,2L)
 expect_equal(m$X[,1],rep(1,31))
 both <- autodesn_prepare_bank(y,list(H),normalize_features=TRUE,standardize_features=TRUE)
 expect_equal(apply(both$models[[1]]$X[,-1],2,sd),rep(1/sqrt(2),2),tolerance=1e-12,ignore_attr=TRUE)
})

test_that("defaults preserve the original feature basis and historical draws", {
 H <- cbind(seq_len(17),cos(seq_len(17)),rep(2,17));y <- sin(seq_len(17))
 a <- autodesn_prepare_bank(y,list(H))
 b <- autodesn_prepare_bank(y,list(H),standardize_features=FALSE)
 expect_identical(a,b)
 expect_equal(unname(a$models[[1]]$X),unname(cbind(1,H/sqrt(3))))
 args <- list(n_burn=5L,n_mcmc=20L,seed=511L)
 expect_identical(do.call(autodesn_fit_bank,c(list(bank=a),args))$draws,
                  do.call(autodesn_fit_bank,c(list(bank=b),args))$draws)
 # Historical fitted objects without the new metadata still transport.
 old <- a$models[[1]][setdiff(names(a$models[[1]]),c("raw_d","feature_center","feature_scale","active_features","dropped_features","standardize_features","feature_sd_tol","readout_scale_info"))]
 beta <- matrix(seq_len(8)/3,2,4)
 want <- beta;want[,-1] <- want[,-1]/sqrt(3)
 expect_equal(scaling_internal(".autodesn_raw_beta")(old,beta),want)
})

test_that("coefficient transport includes the intercept shift and frozen mask", {
 x <- seq(-1,1,length.out=23);H <- cbind(12+7*x,-4+.3*x^2,rep(2,23))
 for(norm in c(FALSE,TRUE)) {
  bank <- autodesn_prepare_bank(sin(x),list(H),normalize_features=norm,standardize_features=TRUE)
  m <- bank$models[[1]];beta <- rbind(c(2,.4,-.7),c(-1,.8,1.2))
  future <- rbind(c(123,-15,999),c(-8,7,-999))
  X <- cbind(1,scaling_internal(".autodesn_feature_apply")(m,future))
  raw <- scaling_internal(".autodesn_raw_beta")(m,beta)
  expect_equal(unname(X%*%t(beta)),unname(cbind(1,future)%*%t(raw)),tolerance=1e-11)
  expect_equal(raw[,4],c(0,0))
  expect_gt(max(abs(raw[,1]-beta[,1])),.1)
  # A future batch must never estimate another mean/SD.
  one <- scaling_internal(".autodesn_feature_apply")(m,future[1,,drop=FALSE])
  expect_equal(one,X[1,-1,drop=FALSE],tolerance=1e-12,ignore_attr=TRUE)
 }
})

test_that("constant-only and empty designs retain a proper intercept", {
 y <- sin(seq_len(11));H <- matrix(4,11,3)
 for(F in list(H,matrix(numeric(),11,0))) {
  bank <- autodesn_prepare_bank(y,list(F),standardize_features=TRUE,normalize_features=FALSE)
  m <- bank$models[[1]];expect_equal(m$d,0L)
  fit <- autodesn_fit_bank(bank,beta_prior="rhs",backend="R",n_burn=3L,n_mcmc=10L,seed=882L)
  expect_true(all(lengths(fit$beta)==1L))
  raw <- scaling_internal(".autodesn_raw_beta")(m,matrix(c(2,3),2,1))
  expect_equal(raw[,1],c(2,3));expect_equal(ncol(raw),ncol(F)+1L)
 }
})

test_that("standardized fixed-design predictions use the frozen training transform", {
 x <- seq(-1,1,length.out=20);H <- cbind(30+10*x,x^2,rep(2,20));future <- H[c(2,6,9),]
 bank <- autodesn_prepare_bank(sin(x),list(H),standardize_features=TRUE,normalize_features=FALSE)
 fit <- autodesn_fit_bank(bank,beta_prior="rhs",backend="R",n_burn=10L,n_mcmc=40L,seed=712L)
 fc <- posterior_predict.autodesn_fit(fit,nd=8L,X_new=list(future),seed=333L)
 raw <- scaling_internal(".autodesn_raw_beta")(bank$models[[1]],do.call(rbind,fit$beta[fc$draw_index]))
 expect_equal(unname(fc$mu_draws),unname(cbind(1,future)%*%t(raw)),tolerance=1e-11)
 expect_error(posterior_predict.autodesn_fit(fit,X_new=list(future[,1:2])),"fitted slope dimensions")
})

test_that("scaled recursive forecasts match frozen-basis reconstruction and facade", {
 y <- sin(seq_len(47)/4)+.1*cos(seq_len(47));spec <- list(list(D=2L,n=c(5L,3L),n_tilde=2L,m=2L,alpha=c(.5,.5),rho=c(.6,.6),pi_w=1,pi_in=1,washout=5L,seed=123L))
 bank <- autodesn_build_bank(y,spec,conditioning=9L,normalize_features=FALSE,standardize_features=TRUE)
 fit <- autodesn_fit_bank(bank,beta_prior="rhs",backend="R",n_burn=10L,n_mcmc=30L,seed=914L)
 facade <- autodesn_fit(y,spec,conditioning=9L,normalize_features=FALSE,standardize_features=TRUE,beta_prior="rhs",backend="R",mcmc_args=list(n_burn=10L,n_mcmc=30L,seed=914L))
 expect_identical(fit$draws,facade$draws);expect_identical(fit$beta,facade$beta)
 ids <- c(3L,17L);noise <- matrix(seq(-.8,.8,length.out=6),3,2)
 fc <- forecast_paths.autodesn_fit(fit,3L,draw_index=ids,innovations=noise,backend="batched")
 serial <- forecast_paths.autodesn_fit(fit,3L,draw_index=ids,innovations=noise,backend="serial")
 expect_equal(fc$yrep,serial$yrep,tolerance=1e-11)
 for(k in seq_along(ids)) {
  history <- y
  for(h in 1:3) {
   raw <- autodesn_build_bank(c(history,9999),spec,conditioning=9L,normalize_features=FALSE)
   row <- tail(raw$models[[1]]$X[,-1,drop=FALSE],1)
   row <- c(1,scaling_internal(".autodesn_feature_apply")(bank$models[[1]],row))
   mu <- sum(row*fit$beta[[ids[k]]])
   expect_equal(fc$mu_draws[h,k],bank$preprocessing$center+bank$preprocessing$scale*mu,tolerance=1e-10)
   history <- c(history,fc$yrep[h,k])
  }
 }
})
