test_that("joint proposal remains a computational control for the same target", {
 x<-seq(-1,1,length.out=16);bank<-autodesn_prepare_bank(sin(x),list(cbind(x),cbind(x,x^2)),
  standardize_features=TRUE,normalize_features=FALSE)
 joint<-autodesn_rhs_joint_proposal(rbind(c(log(.5),0,0),c(log(.5),.5,0)),diag(c(.5,1,1)^2))
 fit<-function(enabled) autodesn_fit_bank(bank,beta_prior="rhs",n_burn=20L,n_mcmc=80L,seed=7760,
  rhs_control=list(tau0=.001,slab_scale=1,interweave_global=TRUE),
  model_control=if(enabled) list(joint_proposal=joint) else list(),backend="R")
 a<-fit(TRUE);b<-fit(TRUE);old<-fit(FALSE)
 expect_identical(a$draws,b$draws);expect_identical(a$beta,b$beta)
 expect_identical(a$controls$target,old$controls$target)
 expect_true(all(is.finite(as.matrix(a$draws))))
 expect_equal(sum(a$sampler_stats$joint_proposals),100)
 expect_gt(sum(a$sampler_stats$joint_acceptances),0)
 expect_error(autodesn_fit_bank(bank,beta_prior="rhs",n_mcmc=2,
  rhs_control=list(learn_global=FALSE),model_control=list(joint_proposal=joint)),"sampled global")
 expect_error(autodesn_fit_bank(bank,beta_prior="rhs",n_mcmc=2,
  model_control=list(method="categorical",joint_proposal=joint)),"requires")
})

test_that("joint Student-t proposals require proper full-support shapes", {
 mu<-matrix(0,2,3)
 expect_error(autodesn_rhs_joint_proposal(mu,diag(c(1,1,-1))),"positive definite")
 expect_error(autodesn_rhs_joint_proposal(mu,diag(2)),"3 by 3")
 expect_error(autodesn_rhs_joint_proposal(mu,diag(3),wide_weight=1.1),"in ")
 expect_error(autodesn_rhs_joint_proposal(mu,diag(3),df=0),"positive")
 q<-autodesn_rhs_joint_proposal(mu,diag(3),wide_weight=0)
 expect_s3_class(q,"autodesn_rhs_joint_proposal")
})
