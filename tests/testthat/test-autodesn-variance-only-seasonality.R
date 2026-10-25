variance_only_internal<-function(n)get(n,envir=environment(autodesn_fit_bank),inherits=TRUE)
variance_only_bank<-function(){
 y<-sin(seq_len(56)/3)+.1*cos(seq_len(56)/5)
 specs<-list(a=list(D=1,n=4,n_tilde=integer(0),m=2,alpha=.4,rho=.5,seed=31,washout=5,pi_in=1,pi_w=1),b=list(D=2,n=c(4,3),n_tilde=2,m=3,alpha=c(.4,.6),rho=c(.5,.6),seed=39,washout=5,pi_in=1,pi_w=1))
 autodesn_build_bank(y,specs,conditioning=5,washout=10,standardize_features=TRUE,normalize_features=FALSE)
}

test_that('a variance-only period does not add mean coefficients or prior factors',{
 b<-variance_only_bank()
 plain<-autodesn_extend_bank(b,list(lags=1:2))
 seasonal<-autodesn_extend_bank(b,list(lags=1:2),list(periods=c(20,25,30),harmonics=0,prior=c(2,3,5)))
 expect_identical(seasonal$prior,plain$prior)
 expect_equal(seasonal$extension$period_prior,c(.2,.3,.5))
 expect_equal(seasonal$extension$calendar_slots,0)
 design<-variance_only_internal('.ext_design');gaussian<-variance_only_internal('.autodesn_rhs_gaussian_R')
 for(m in seq_along(b$models)){
  a<-design(plain,m,1);values<-numeric(3)
  for(p in 1:3){
   z<-design(seasonal,m,p)
   expect_identical(a,z)
   logv<-seq(-5,.1,length.out=ncol(z$X))
   values[p]<-gaussian(z,b$y,.4,logv)$log_evidence
   reference<-gaussian(a,b$y,.4,logv)$log_evidence
   expect_identical(values[p],reference)
  }
  expect_equal(log(sum(exp(values-max(values))*seasonal$extension$period_prior))+max(values),values[1],tolerance=1e-13)
 }
 expect_error(autodesn_seasonal_control(20,harmonics=-1),'harmonics')
 expect_error(autodesn_seasonal_control(20,harmonics=.5),'harmonics')
})

test_that('seasonal volatility fits retain the selected nonseasonal mean in both backends',{
 b<-autodesn_extend_bank(variance_only_bank(),list(lags=1:2),list(periods=c(20,25),harmonics=0))
 args<-list(bank=b,n_burn=5,n_mcmc=24,beta_prior='rhs',rhs_control=list(tau0=.001,slab_scale=1),variance_control=list(type='sv',seasonal=TRUE,save_state_paths=TRUE),model_control=list(save_draws=8),seed=7461)
 reference<-do.call(autodesn_fit_bank,c(args,list(backend='R')))
 expect_true(all(is.finite(as.matrix(reference$trace))))
 expect_true(all(reference$trace$norm_calendar==0))
 expect_equal(sum(reference$period_summary$posterior),1)
 if(exists('autodesn_rhs_gaussian_cpp',envir=environment(autodesn_fit_bank),inherits=TRUE)){
  compiled<-do.call(autodesn_fit_bank,c(args,list(backend='cpp')))
  for(name in c('trace','beta','local','probes','draws','volatility'))expect_equal(reference[[name]],compiled[[name]],tolerance=1e-8)
 }
 # Training histories are explicit: appending observed data does not refit the
 # selected mean's training geometry or make it a Fourier mean model.
 updated<-autodesn_update_history(reference,c(.2,-.1))
 expect_identical(updated$bank$extension$calendar,reference$bank$extension$calendar)
 expect_identical(updated$bank$models,reference$bank$models)
})
