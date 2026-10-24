# Small workflow contracts, not posterior-convergence or performance evidence.
source("validation/autodesn/nonlinear_heteroscedastic/helpers.R")
library(testthat)
cfg <- nh_configuration();y <- c1_data()$y
test_that("new inputs and temporal protocol are isolated and frozen",{
 expect_identical(cfg$series,"NHS1");expect_identical(names(c1_data()),c("time","y"))
 expect_equal(c(cfg$washout,cfg$n_train,cfg$n_test),c(500,2000,500))
 expect_equal(cfg$origins*cfg$H,14130);expect_false(cfg$refit_per_origin)
 original <- read.csv("validation/autodesn/c1_comparison/input/C1.csv")$y
 expect_false(identical(y,original))
 expect_identical(digest::digest(file=file.path(nh_root,"input/specifications.rds"),algo="sha256"),
  digest::digest(file="validation/autodesn/c1_comparison/input/specifications.rds",algo="sha256"))
})
spec <- autodesn_candidates(D=1:2,n=6,m=5,alpha=.65,rho=.4,seed=11,washout=30)
spec <- lapply(spec,function(s) {s$n_tilde<-s$n[seq_len(s$D-1L)];s})
bank <- autodesn_build_bank(y[1:180],spec,conditioning=30,washout=30,
 standardize_features=TRUE,normalize_features=FALSE)
test_that("new-series readouts have frozen unit-variance training geometry",{
 expect_identical(bank$keep_idx,31:180)
 for(m in bank$models) {
  expect_lt(max(abs(colMeans(m$X[,-1,drop=FALSE]))),1e-10)
  expect_lt(max(abs(apply(m$X[,-1,drop=FALSE],2,sd)-1)),1e-10)
  expect_identical(m$divisor,1)
 }
})
Rcpp::sourceCpp("src/autodesn_rhs.cpp",cacheDir=file.path(nh_root,"artifacts/test_cpp"),showOutput=FALSE)
args <- list(bank=bank,beta_prior="rhs",n_burn=30,n_mcmc=80,seed=710099,
 rhs_control=list(tau0=.001,slab_scale=1,slab_df=4,local_layout="layerwise",interweave_global=TRUE),
 model_control=list(method="mh",moves=4))
r <- do.call(autodesn_fit_bank,c(args,list(backend="R")))
cpp <- do.call(autodesn_fit_bank,c(args,list(backend="cpp")))
test_that("new-series small R and native chains agree",{
 expect_equal(as.matrix(r$draws),as.matrix(cpp$draws),tolerance=1e-7)
 expect_equal(unlist(r$beta),unlist(cpp$beta),tolerance=1e-7)
 expect_identical(r$draws$model,cpp$draws$model)
})
test_that("forecast API uses the fitted standardized geometry",{
 noise <- matrix(seq(-1,1,length.out=5*4),5)
 a <- forecast_paths.autodesn_fit(cpp,5,draw_index=1:4,inner_paths=1,innovations=noise,backend="batched")
 expect_identical(dim(a$yrep),c(5L,4L));expect_true(all(is.finite(a$yrep)))
 b <- forecast_paths.autodesn_fit(cpp,5,draw_index=1:4,inner_paths=1,innovations=noise,backend="batched")
 expect_identical(a$yrep,b$yrep)
})
cat("Small NHS1 workflow checks passed; these short chains do not establish convergence.\n")
joint<-autodesn_rhs_joint_proposal(matrix(c(log(.5),0,0),2,3,byrow=TRUE),diag(c(.5,1,1)^2))
args$model_control$joint_proposal<-joint
jr<-do.call(autodesn_fit_bank,c(args,list(backend="R")))
jcpp<-do.call(autodesn_fit_bank,c(args,list(backend="cpp")))
test_that("new-series joint architecture/scale updates agree across backends",{
 expect_equal(as.matrix(jr$draws),as.matrix(jcpp$draws),tolerance=1e-7)
 expect_equal(unlist(jr$beta),unlist(jcpp$beta),tolerance=1e-7)
 expect_identical(jr$draws$model,jcpp$draws$model)
 expect_identical(jr$controls$target,cpp$controls$target)
})
