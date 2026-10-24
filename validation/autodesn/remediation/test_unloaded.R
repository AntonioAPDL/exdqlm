# Fresh source-only session, with no sourceCpp library loaded.
source('validation/autodesn/load_checkout.R')
y<-seq(-1,1,length.out=8);b<-autodesn_prepare_bank(y,list(matrix(y)),standardize_features=TRUE,normalize_features=FALSE);b<-autodesn_extend_bank(b)
a<-autodesn_fit_bank(b,n_burn=2,n_mcmc=5,beta_prior='rhs',backend='auto',seed=39)
r<-autodesn_fit_bank(b,n_burn=2,n_mcmc=5,beta_prior='rhs',backend='R',seed=39)
stopifnot(identical(a$draws,r$draws),identical(a$beta,r$beta),a$controls$backend=='R')
e<-try(autodesn_fit_bank(b,n_burn=2,n_mcmc=5,beta_prior='rhs',backend='cpp',seed=39),silent=TRUE)
stopifnot(inherits(e,'try-error'),grepl('unavailable',e))
jsonlite::write_json(list(complete=TRUE,auto_fallback_reproduces_R=TRUE,explicit_cpp_fails_when_unavailable=TRUE), 'validation/autodesn/remediation/evidence/unloaded_backend.json',pretty=TRUE,auto_unbox=TRUE)
