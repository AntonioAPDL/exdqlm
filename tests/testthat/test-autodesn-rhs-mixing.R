# Exact computational reparameterizations; no changed prior or likelihood.
mix_internal <- function(n) get(n,environment(autodesn_fit_bank),inherits=TRUE)

test_that("layerwise auxiliary slots align layer/neuron identities", {
 y<-sin(seq_len(38)/4)
 specs<-list(list(D=1L,n=3L,m=1L,alpha=.5,rho=.4,seed=1L,washout=3L),
  list(D=2L,n=c(3L,2L),n_tilde=2L,m=1L,alpha=c(.5,.5),rho=c(.4,.4),seed=1L,washout=3L))
 b<-autodesn_build_bank(y,specs,conditioning=5L,standardize_features=TRUE,normalize_features=FALSE)
 lay<-mix_internal(".autodesn_rhs_layout")(b,"layerwise")
 expect_identical(lay$dimension,5L)
 expect_identical(lay$index,list(1:3,c(4L,5L,1L,2L)))
 # Each architecture uses distinct iid coordinates. Unused proper priors
 # integrate to one; the Gaussian law depends only on active variances.
 ell<-c(-.3,.7,-1,1.2,.2);logv<-mix_internal(".autodesn_rhs_log_variance")
 gauss<-mix_internal(".autodesn_rhs_gaussian_R")
 for(j in 1:2) {
  idx<-lay$index[[j]];lv<-c(log(10),logv(ell[idx],.1,log(2),.001))
  actual<-gauss(b$models[[j]],b$y,.8,lv)
  X<-b$models[[j]]$X;C<-.8*diag(b$n)+X%*%diag(exp(lv))%*%t(X)
  expected<--.5*(b$n*log(2*pi)+as.numeric(determinant(C,logarithm=TRUE)$modulus)+sum(b$y*solve(C,b$y)))
  expect_equal(actual$log_evidence,expected,tolerance=1e-9)
 }
 expect_error(autodesn_fit_bank(autodesn_prepare_bank(1:5,list(matrix(1:5,5))),
  beta_prior="rhs",rhs_control=list(local_layout="layerwise"),n_mcmc=2L),"requires a reservoir bank")
 # Scalar fixed local scales remove the embedding from the marginal target.
 ctl<-list(learn_global=FALSE,learn_slab=FALSE,fixed_local_scales=1)
 a<-autodesn_fit_bank(b,beta_prior="rhs",rhs_control=ctl,n_burn=2L,n_mcmc=10L,seed=451L,backend="R")
 z<-autodesn_fit_bank(b,beta_prior="rhs",rhs_control=c(ctl,list(local_layout="layerwise")),n_burn=2L,n_mcmc=10L,seed=451L,backend="R")
 expect_identical(a$draws$model,z$draws$model);expect_identical(a$beta,z$beta)
})

test_that("interweaving preserves scale products and restores auxiliary conditionals", {
 fun<-mix_internal(".autodesn_rhs_interweave");lv<-mix_internal(".autodesn_rhs_log_variance")
 hc<-function(x) -log(pi)-log(cosh(x))
 rho<-c(-.7,1.2)
 # Independent numerical conditional on products, including both HC priors
 # and log-coordinate Jacobians. No production target helper is used here.
 den<-function(r) vapply(r,function(z) exp(hc(z)+sum(hc(rho-z))),0)
 Z<-integrate(den,-Inf,Inf,rel.tol=1e-10)$value
 ref<-integrate(function(r) r*den(r),-50,50,rel.tol=1e-10)$value/Z
 cutoff<-.3;cdf<-integrate(den,-Inf,cutoff,rel.tol=1e-10)$value/Z
 set.seed(7102);r<-0;draws<-numeric(12000);residual<-numeric(12000)
 for(i in seq_along(draws)) {
  before<-lv(rho-r,r,log(2),.001)
  z<-fun(rho-r,r,1,50L,10000L);r<-z$log_global
  if(i==1) expect_equal(lv(z$log_local,r,log(2),.001),before,tolerance=1e-13)
  draws[i]<-r
  # rate/nu ~ Gamma(1,1) under the independently derived IG conditional.
  residual[i]<-exp(log1p(exp(-2*z$log_local[1]))-z$log_aux[1])
 }
 x<-draws[-(1:1000)];e<-residual[-(1:1000)]
 expect_equal(mean(x),ref,tolerance=.035)
 expect_equal(mean(x<=cutoff),cdf,tolerance=.025)
 expect_equal(mean(e),1,tolerance=.04)
 expect_equal(mean(e^2),2,tolerance=.16)
 expect_error(autodesn_rhs_control(interweave_global=TRUE,learn_global=FALSE),"requires sampled")
 expect_error(autodesn_rhs_control(interweave_global=TRUE,fixed_local_scales=1),"requires sampled")
})

test_that("interwoven RHS runs reproducibly without changing the stated target", {
 x<-seq(-1,1,length.out=14);b<-autodesn_prepare_bank(sin(x),list(cbind(x),cbind(x,x^2)))
 f<-function(interweave) autodesn_fit_bank(b,beta_prior="rhs",rhs_control=list(tau0=.001,slab_scale=1,interweave_global=interweave),
  n_burn=30L,n_mcmc=100L,seed=1611L,backend="R")
 a<-f(TRUE);z<-f(TRUE);base<-f(FALSE)
 expect_identical(a$draws,z$draws);expect_identical(a$beta,z$beta)
 expect_identical(a$controls$target,base$controls$target)
 expect_true(all(is.finite(as.matrix(a$draws))))
 expect_gt(a$sampler_stats$slice_proposals['interweave'],0)
})

test_that("normalized unidentifiable slopes leave all scale priors unchanged", {
 # The zero slope has no likelihood information. Integrating its normalized
 # Gaussian coefficient prior gives exactly one for every global/local/slab.
 b<-autodesn_prepare_bank(c(-.4,.2,.5),list(matrix(0,3,1)),normalize_features=FALSE)
 f<-autodesn_fit_bank(b,beta_prior="rhs",rhs_control=list(tau0=.001,slab_scale=1,
   slab_df=4,interweave_global=TRUE,save_local=TRUE),n_burn=1000L,n_mcmc=10000L,seed=1721L,backend="R")
 u<-2/pi*atan(f$draws$global_scale)
 local<-2/pi*atan(unlist(f$local_scales))
 slab<-pgamma(2/f$draws$slab_variance,shape=2,lower.tail=FALSE)
 for(x in list(u,local,slab)) {
  expect_equal(mean(x),.5,tolerance=.035)
  expect_equal(mean(x^2),1/3,tolerance=.035)
 }
})
