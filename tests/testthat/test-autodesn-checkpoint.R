checkpoint_bank <- function() {
  y <- sin(seq_len(12)/2)
  b <- autodesn_prepare_bank(y, list(cbind(y, cos(y)), matrix(y^2, ncol=1)),
    standardize_features=TRUE, normalize_features=FALSE)
  autodesn_extend_bank(b, seasonal_control=list(periods=c(7,11), harmonics=1))
}

test_that('paused and resumed chains reproduce every recorded joint state', {
  b <- checkpoint_bank()
  backends <- 'R'
  if (exists('autodesn_weighted_gaussian_cpp', envir=environment(autodesn_fit_bank), inherits=TRUE)) backends <- c(backends,'cpp')
  for (engine in backends) for (prior in c('ridge','rhs')) for (sv in c(FALSE,TRUE)) {
    args <- list(bank=b, n_burn=8L, n_mcmc=31L, thin=3L, beta_prior=prior,
      model_control=list(moves=2L,joint_moves=1L,save_draws=6L),
      rhs_control=if(prior=='rhs')list(interweave_global=TRUE) else list(),
      variance_control=if(sv)list(type='sv',save_state_paths=TRUE,seasonal=FALSE) else NULL,
      backend=engine, seed=4411)
    reference <- do.call(autodesn_fit_bank,args)
    path <- tempfile('sampler-checkpoint-')
    cp <- list(path=path,every=4L,stop_after=5L,source_id=paste(rep('a',64),collapse=''))
    set.seed(81);old <- .Random.seed
    expect_error(do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp))),class='autodesn_checkpoint_pause')
    expect_identical(.Random.seed,old)
    expect_equal(readRDS(path)$payload$iteration,5L)
    expect_equal(readRDS(path)$payload$retained,0L)
    cp$resume<-TRUE;cp$stop_after<-17L
    expect_error(do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp))),class='autodesn_checkpoint_pause')
    expect_equal(readRDS(path)$payload$iteration,17L)
    cp$stop_after<-Inf
    resumed <- do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp)))
    completed_again <- do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp)))
    for (field in c('draws','trace','beta','local','volatility','probes','model_summary','period_summary','controls')) {
      expect_identical(resumed[[field]],reference[[field]])
      expect_identical(completed_again[[field]],reference[[field]])
    }
    counters <- setdiff(names(reference$computation),'elapsed_seconds')
    expect_identical(resumed$computation[counters],reference$computation[counters])
    unlink(path)
  }
})

test_that('resume refuses incompatible contracts and corrupted state', {
  args <- list(bank=checkpoint_bank(),n_burn=3L,n_mcmc=10L,beta_prior='rhs',backend='R',seed=41L)
  path <- tempfile('sampler-checkpoint-')
  cp <- list(path=path,every=2L,stop_after=4L)
  expect_error(do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp))),class='autodesn_checkpoint_pause')
  expect_error(do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp))),'Checkpoint exists')
  cp$resume<-TRUE;cp$stop_after<-Inf
  for (field in c('seed','n_burn','n_mcmc','thin')) {
    bad<-args;bad[[field]]<-if(is.null(bad[[field]]))2L else bad[[field]]+1L
    expect_error(do.call(autodesn_fit_bank,c(bad,list(checkpoint_control=cp))),'identity')
  }
  bad<-args;bad$model_control<-list(moves=3L)
  expect_error(do.call(autodesn_fit_bank,c(bad,list(checkpoint_control=cp))),'identity')
  bad<-args;bad$rhs_control<-list(tau0=.002)
  expect_error(do.call(autodesn_fit_bank,c(bad,list(checkpoint_control=cp))),'identity')
  x<-readRDS(path);x$payload$state$s2<-99;saveRDS(x,path)
  expect_error(do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp))),'checksum')
  unlink(path)
  expect_error(do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp))),'does not exist')
  cp$resume<-FALSE;cp$every<-0L
  expect_error(do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp))),'every')
  cp$every<-2L;cp$extra<-TRUE
  expect_error(do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp))),'Unknown')
})

test_that('joint local proposals, categorical moves and seasonal SV resume exactly', {
  y<-sin(seq_len(15)/2)
  b<-autodesn_prepare_bank(y,list(cbind(y,cos(y)),matrix(y^2,ncol=1)),standardize_features=TRUE,normalize_features=FALSE)
  b$history<-b$history_scaled<-c(.1,.2,y);b$keep_idx<-3:17
  b<-autodesn_extend_bank(b,list(lags=1:2,prior='grouped'),list(periods=c(11,13),harmonics=1))
  local<-autodesn_extended_local_proposal(lapply(b$models,function(m)matrix(0,2,m$d)),lapply(b$models,function(m)rep(1,m$d)),bank_id=b$extension$id)
  joint<-autodesn_extended_proposal(matrix(0,2,4),diag(4))
  args<-list(bank=b,n_burn=5L,n_mcmc=20L,beta_prior='rhs',rhs_control=list(interweave_global=TRUE),
    model_control=list(method='categorical',joint_proposal=joint,local_proposal=local,local_scale_proposal=TRUE,save_draws=8L),
    variance_control=list(type='sv',seasonal=TRUE,save_state_paths=TRUE),seed=145L,backend='R')
  reference<-do.call(autodesn_fit_bank,args);path<-tempfile('joint-checkpoint-')
  cp<-list(path=path,every=3L,stop_after=7L)
  expect_error(do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp))),class='autodesn_checkpoint_pause')
  cp$resume<-TRUE
  expect_error(do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp))),'must exceed')
  cp$stop_after<-Inf
  resumed<-do.call(autodesn_fit_bank,c(args,list(checkpoint_control=cp)))
  for(field in c('draws','trace','beta','local','volatility','probes','model_summary','period_summary','controls'))expect_identical(resumed[[field]],reference[[field]])
  unlink(path)
})

test_that('checkpointing rejects hidden-normal-cache RNG kinds', {
  old<-RNGkind();on.exit(do.call(RNGkind,as.list(old)))
  RNGkind(normal.kind='Box-Muller')
  expect_error(autodesn_fit_bank(checkpoint_bank(),n_burn=1,n_mcmc=2,backend='R',checkpoint_control=list(path=tempfile())),'RNGkind')
})
