# Learned locals + interweaving + joint MH on a one-dimensional prefix bank.
# Layerwise reservoir geometry is checked separately in test_workflow.R.
# Independent normalized-prior integration is performed in test_joint_local.py.
library(exdqlm)
out<-"validation/autodesn/nonlinear_heteroscedastic/artifacts/validation/joint_local_oracle"
dir.create(out,recursive=TRUE,showWarnings=FALSE)
y<-c(.8,-.3);x<-c(-1,1)/sqrt(2)
bank<-autodesn_prepare_bank(y,list(matrix(numeric(),2,0),matrix(x,2,1)),
 model_prior=c(.4,.6),normalize_features=FALSE)
proposal<-autodesn_rhs_joint_proposal(rbind(c(log(.4),-.7,log(1.2)),c(log(.6),.8,log(2))),
 matrix(c(.25,.07,-.03,.07,1.2,.16,-.03,.16,.6),3),moves=2L)
rows<-list()
for(k in 1:3) {
 f<-autodesn_fit_bank(bank,beta_prior="rhs",n_burn=2000L,n_mcmc=20000L,
  seed=89710+k,intercept_variance=1,
  rhs_control=list(tau0=.3,slab_scale=1,slab_df=4,save_local=TRUE,
    local_layout="prefix",interweave_global=TRUE),
  model_control=list(method="mh",moves=2L,proposal=c(.7,.3),joint_proposal=proposal),backend="cpp")
 active<-vapply(seq_len(nrow(f$draws)),function(i) {
  if(f$draws$model[i]==1L) return(.5) # exactly integrate the inactive HC prior
  as.numeric(f$local_log_scales[[i]][1L]<0)
 },0)
 rows[[k]]<-data.frame(chain=k,f$draws,local_below_1_RB=active)
 cat("Learned-local/interwoven joint oracle chain",k,"complete\n");flush.console()
}
write.csv(do.call(rbind,rows),file.path(out,"posterior.csv"),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,"session.txt"))
