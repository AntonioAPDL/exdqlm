# Independent Python calculations consume the exported states below.
source("validation/autodesn/nonlinear_heteroscedastic/helpers.R")
library(testthat)
out<-file.path(nh_root,"artifacts/validation/joint_oracle");dir.create(out,recursive=TRUE,showWarnings=FALSE)
center<-rbind(c(log(.4),-.7,log(1.2)),c(log(.6),.8,log(2)))
S<-matrix(c(.25,.07,-.03,.07,1.2,.16,-.03,.16,.6),3)
proposal<-autodesn_rhs_joint_proposal(center,S,df=5,moves=2L,wide_weight=.1)
test_that("proper joint proposal support and controls are enforced",{
 expect_error(autodesn_rhs_joint_proposal(center,diag(c(1,1,-1))),"positive definite")
 expect_error(autodesn_rhs_joint_proposal(center,S,wide_weight=-.1),"in ")
 expect_error(autodesn_rhs_joint_proposal(center,S,df=0),"positive")
 expect_error(.autodesn_rhs_model_control(list(method="categorical",joint_proposal=proposal),c(.4,.6)),"requires")
 expect_error(.autodesn_rhs_model_control(list(joint_proposal=proposal),1),"one center")
})
y<-c(.8,-.3);x<-c(-1,1)/sqrt(2)
bank<-autodesn_prepare_bank(y,list(matrix(numeric(),2,0),matrix(x,2,1)),model_prior=c(.4,.6),normalize_features=FALSE)
states<-rbind(c(log(.3),-.6,log(.9)),c(log(.8),1.1,log(2.4)),c(log(.45),.2,log(1.1)))
rows<-list()
for(m in 1:2) for(i in 1:3) {
 z<-states[i,];v<-.autodesn_rhs_log_variance(rep(0,bank$models[[m]]$d),z[2],z[3],.3)
 g<-.autodesn_rhs_gaussian_R(bank$models[[m]],bank$y,exp(z[1]),c(log(1),v))
 rows[[length(rows)+1L]]<-data.frame(model=m,state=i,log_variance=z[1],log_global=z[2],log_slab=z[3],
  log_likelihood=g$log_evidence,log_target=.autodesn_rhs_joint_log_target(log(bank$prior[m]),g$log_evidence,z,3,1,4,1),
  log_q=.autodesn_rhs_joint_logq(z,m,proposal))
}
write.csv(do.call(rbind,rows),file.path(out,"densities.csv"),row.names=FALSE)
state_rows<-do.call(rbind,rows);pairs<-list()
for(a in seq_len(nrow(state_rows))) for(b in seq_len(nrow(state_rows))) {
 left<-state_rows[a,];right<-state_rows[b,]
 ratio<-.autodesn_rhs_joint_log_ratio(left$model,right$model,as.numeric(unlist(left[c("log_variance","log_global","log_slab")])),
  as.numeric(unlist(right[c("log_variance","log_global","log_slab")])),left$log_likelihood,right$log_likelihood,
  c(.4,.6),c(.7,.3),proposal,3,1,4,1)
 pairs[[length(pairs)+1L]]<-data.frame(old_row=a,new_row=b,implemented_log_ratio=ratio)
}
write.csv(do.call(rbind,pairs),file.path(out,"acceptance_ratios.csv"),row.names=FALSE)
jsonlite::write_json(list(center=center,scale=S,wide_center=proposal$wide_center,
 wide_scale=proposal$wide_scale,df=5,wide_weight=.1,model_proposal=c(.7,.3)),file.path(out,"proposal.json"),digits=16,auto_unbox=TRUE)
test_that("disabled joint kernel preserves earlier RHS draws exactly",{
 old<-new.env(parent=.GlobalEnv);gold<-tempfile(fileext=".R")
 stopifnot(system2("git",c("show","d67aabe912e7a81b02d3d19920bfcb2b8cb6d9d1:R/autodesn_rhs.R"),stdout=gold)==0L)
 sys.source(gold,old);unlink(gold)
 f<-autodesn_fit_bank;environment(f)<-old
 args<-list(bank=bank,beta_prior="rhs",n_burn=20L,n_mcmc=80L,seed=714,
  rhs_control=list(tau0=.3,slab_scale=1),model_control=list(method="mh",moves=4L),backend="R")
 a<-do.call(f,args);b<-do.call(autodesn_fit_bank,args)
 expect_identical(a$draws,b$draws);expect_identical(a$beta,b$beta)
 expect_identical(a$sampler_stats,b$sampler_stats);expect_identical(a$controls$target,b$controls$target)
})
fits<-list()
for(k in 1:3) {
 fit<-autodesn_fit_bank(bank,beta_prior="rhs",n_burn=1500L,n_mcmc=14000L,seed=7150+k,
  intercept_variance=1,rhs_control=list(tau0=.3,slab_scale=1,slab_df=4,fixed_local_scales=1),
  model_control=list(method="mh",moves=2L,proposal=c(.7,.3),joint_proposal=proposal),backend="R")
 stopifnot(sum(fit$sampler_stats$joint_acceptances)>0)
 fits[[k]]<-cbind(chain=k,fit$draws)
}
write.csv(do.call(rbind,fits),file.path(out,"posterior.csv"),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,"session.txt"))
cat("Joint kernel deterministic/default checks and three small posterior chains complete.\n")
