# Measure copy-on-write chain parallelism before spending production budgets.
source('validation/autodesn/load_checkout.R');Rcpp::sourceCpp('src/autodesn_rhs.cpp',cacheDir='validation/autodesn/remediation/artifacts/cpp',showOutput=FALSE)
b<-readRDS('validation/autodesn/nonlinear_heteroscedastic/artifacts/standardized_bank/bank.rds')
e<-autodesn_extend_bank(b,list(lags=1:90),list(periods=20:120,harmonics=16));gc()
start<-proc.time()[3]
r<-parallel::mclapply(1:2,function(k){f<-autodesn_fit_bank(e,n_burn=20,n_mcmc=50,beta_prior='rhs',rhs_control=list(tau0=.001,slab_scale=1),model_control=list(save_draws=20),backend='cpp',seed=3266100+k);list(computation=f$computation,draws=f$draws,bank_id=f$controls$target$bank_id)},mc.cores=2,mc.set.seed=FALSE)
stopifnot(!any(vapply(r,inherits,TRUE,'try-error')),identical(r[[1]]$bank_id,r[[2]]$bank_id),!identical(r[[1]]$draws,r[[2]]$draws))
jsonlite::write_json(list(complete=TRUE,workers=2,shared_bank=TRUE,elapsed_seconds=unname(proc.time()[3]-start),chains=lapply(r,`[[`,'computation'),qualified=FALSE), 'validation/autodesn/remediation/evidence/fork_preflight.json',pretty=TRUE,auto_unbox=TRUE)
