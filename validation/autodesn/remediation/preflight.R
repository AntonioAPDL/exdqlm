source_at_start<-setNames(vapply(c("R/autodesn_extended.R","R/autodesn_extended_forecast.R","R/autodesn_extended_proposal.R","src/autodesn_rhs.cpp"),function(p)digest::digest(file=p,algo="sha256"),""),c("R/autodesn_extended.R","R/autodesn_extended_forecast.R","R/autodesn_extended_proposal.R","src/autodesn_rhs.cpp"))
source('validation/autodesn/load_checkout.R')
Rcpp::sourceCpp('src/autodesn_rhs.cpp',cacheDir='validation/autodesn/remediation/artifacts/cpp',showOutput=FALSE)
root<-'validation/autodesn/remediation';b<-readRDS('validation/autodesn/nonlinear_heteroscedastic/artifacts/standardized_bank/bank.rds')
stopifnot(length(b$models)==426,b$n==2000,identical(b$keep_idx,501:2500))
args<-commandArgs(TRUE);which<-if(length(args))args[1] else 'F1'
season<-if(which=='F1')NULL else list(periods=20:120,harmonics=16)
start<-proc.time()[3];e<-autodesn_extend_bank(b,list(lags=1:90,prior=if(which=='F1')'flat' else 'grouped',cache_size=32),season);build<-proc.time()[3]-start
vc<-if(which=='SV')list(type='sv') else NULL
start<-proc.time()[3]
f<-autodesn_fit_bank(e,n_burn=30,n_mcmc=100,beta_prior='rhs',rhs_control=list(tau0=.001,slab_scale=1,slab_df=4,interweave_global=TRUE),model_control=list(moves=2,joint_moves=1),variance_control=vc,seed=2266021,backend='cpp')
elapsed<-proc.time()[3]-start
bytes<-as.numeric(object.size(f));f$bank<-NULL;f$bank_reference<-list(path='validation/autodesn/nonlinear_heteroscedastic/artifacts/standardized_bank/bank.rds',extension_id=e$extension$id,readout=e$extension$readout,seasonal=e$extension$seasonal);saveRDS(f,file.path(root,'artifacts',paste0('preflight_',which,'.rds')))
d<-list(complete=TRUE,stage='training_only_feasibility_not_qualified',family=which,bank_models=length(e$models),period_states=length(e$extension$periods),build_seconds=unname(build),sweeps=130,seconds=unname(elapsed),seconds_per_sweep=unname(elapsed/130),projected_four_32k_chains_seconds=unname(elapsed/130*4*40000),object_bytes=bytes,computation=f$computation,source_sha256=as.list(source_at_start),test_outcomes_used=FALSE)
jsonlite::write_json(d,file.path(root,'evidence',paste0('preflight_',which,'.json')),pretty=TRUE,auto_unbox=TRUE);print(d)
