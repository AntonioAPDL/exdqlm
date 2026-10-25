calendar_cache_internal<-function(n)get(n,envir=environment(autodesn_fit_bank),inherits=TRUE)
calendar_cache_bank<-function(grouped=FALSE,seasonal=TRUE){
 y<-sin(seq_len(24)/2)+.1*cos(seq_len(24)/3)
 b<-autodesn_prepare_bank(y[13:24],list(cbind(y[13:24],y[13:24]^2),matrix(cos(y[13:24]),ncol=1)),standardize_features=TRUE,normalize_features=FALSE)
 b$history<-b$history_scaled<-y;b$keep_idx<-13:24
 autodesn_extend_bank(b,list(lags=1:2,prior=if(grouped)'grouped' else 'flat'),if(seasonal)list(periods=c(8,11,17),harmonics=8) else NULL)
}

test_that('shared calendar blocks preserve all dimensions, constants and support',{
 design<-calendar_cache_internal('.ext_design')
 for(grouped in c(FALSE,TRUE))for(seasonal in c(FALSE,TRUE)){
  b<-calendar_cache_bank(grouped,seasonal)
  for(budget in c(8,512,1024^2)){
   s<-autodesn_cache_calendar_blocks(b,max_bytes=budget)
   expect_identical(b$extension$id,s$extension$id)
   expect_identical(b$prior,s$prior);expect_identical(b$extension$period_prior,s$extension$period_prior)
   expect_lte(s$extension$statistics_cache$payload_bytes,budget)
   for(m in 1:2)for(p in seq_along(b$extension$periods)){
    x<-design(b,m,p);z<-design(s,m,p)
    expect_identical(x$X,z$X);expect_equal(x,z,tolerance=2e-13)
    v<-seq(-4,1,length.out=ncol(x$X));C<-.37*diag(b$n)+tcrossprod(sweep(x$X,2,exp(v/2),'*'))
    L<-chol(C);w<-forwardsolve(t(L),b$y)
    reference<--b$n/2*log(2*pi)-sum(log(diag(L)))-sum(w^2)/2
    R<-calendar_cache_internal('.autodesn_rhs_gaussian_R')(z,b$y,.37,v)
    expect_equal(R$log_evidence,reference,tolerance=1e-10)
   }
  }
 }
 b<-calendar_cache_bank();s<-autodesn_cache_calendar_blocks(b)
 s$extension$statistics_cache$bank_id<-'wrong'
 expect_error(design(s,1,1),'different conditional bank')
 expect_error(autodesn_cache_calendar_blocks(b,0),'max_bytes')
})

test_that('block and direct statistics give matching Gibbs paths in both backends',{
 b<-calendar_cache_bank(TRUE);s<-autodesn_cache_calendar_blocks(b,max_bytes=512)
 for(prior in c('ridge','rhs'))for(sv in c(FALSE,TRUE))for(backend in c('R','cpp')){
  if(backend=='cpp'&&!exists('autodesn_rhs_gaussian_cpp',envir=environment(autodesn_fit_bank),inherits=TRUE))next
  args<-list(n_burn=8L,n_mcmc=30L,beta_prior=prior,model_control=list(moves=2L,joint_moves=1L,save_draws=12L),seed=4427,backend=backend,variance_control=if(sv)list(type='sv',save_state_paths=TRUE) else NULL)
  x<-do.call(autodesn_fit_bank,c(list(bank=b),args));z<-do.call(autodesn_fit_bank,c(list(bank=s),args))
  expect_identical(x$draws$model,z$draws$model);expect_identical(x$draws$period_index,z$draws$period_index)
  for(field in c('trace','draws','beta','local','volatility','probes'))expect_equal(x[[field]],z[[field]],tolerance=1e-9)
  expect_identical(x$controls$target_id,z$controls$target_id)
 }
})

test_that('exact recovery binds the arithmetic cache contents',{
 b<-calendar_cache_bank(TRUE);s<-autodesn_cache_calendar_blocks(b,max_bytes=512)
 backends<-'R'
 if(exists('autodesn_rhs_gaussian_cpp',envir=environment(autodesn_fit_bank),inherits=TRUE))backends<-c(backends,'cpp')
 for(backend in backends)for(sv in c(FALSE,TRUE)){
  args<-list(bank=s,n_burn=4L,n_mcmc=19L,thin=2L,beta_prior='rhs',model_control=list(moves=2L,joint_moves=1L,save_draws=8L),variance_control=if(sv)list(type='sv',save_state_paths=TRUE) else NULL,seed=4431,backend=backend)
  reference<-do.call(autodesn_fit_bank,args);path<-tempfile('calendar-recovery-')
  cp<-list(path=path,every=3L,stop_after=8L,source_id=paste(rep('a',64),collapse=''))
  expect_error(do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp))),class='autodesn_checkpoint_pause')
  cp$resume<-TRUE;cp$stop_after<-Inf
  mutated<-s;mutated$extension$statistics_cache$models[[1]]$Xty[1]<-mutated$extension$statistics_cache$models[[1]]$Xty[1]+1e-8
  for(other in list(b,autodesn_cache_statistics(b),autodesn_cache_calendar_blocks(b,max_bytes=8),mutated)){
   bad<-args;bad$bank<-other
   expect_error(do.call(autodesn_fit_bank,c(bad,list(checkpoint_control=cp))),'identity')
  }
  resumed<-do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp)))
  for(field in c('trace','draws','beta','local','volatility','probes','model_summary','period_summary','controls'))expect_identical(reference[[field]],resumed[[field]])
  unlink(path)
 }
})
