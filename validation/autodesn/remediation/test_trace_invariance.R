# Adding monitoring must not perturb the Markov transition or its random stream.
source('validation/autodesn/load_checkout.R');old<-new.env(parent=.GlobalEnv)
reference<-'validation/autodesn/remediation/artifacts/sv_reference_sources/5627d6d0a04282c5a94c310cb485c79716363dd9545e968e80b59f3308ca480c'
for(path in list.files(file.path(reference,'R'),pattern='[.]R$',full.names=TRUE))sys.source(path,old)
x<-seq(-1,1,length.out=9);y<-sin(x);b<-autodesn_prepare_bank(y,list(matrix(x),cbind(x,x*x)),normalize_features=FALSE,standardize_features=TRUE);e<-autodesn_extend_bank(b,seasonal_control=list(periods=c(12,18),harmonics=2));cases<-0L
for(prior in c('ridge','rhs'))for(sv in c(FALSE,TRUE)) {
 a<-list(bank=e,n_burn=5,n_mcmc=30,beta_prior=prior,model_control=list(moves=2,joint_moves=1,save_draws=10),seed=9186100,backend='R',variance_control=if(sv)list(type='sv',seasonal=TRUE,save_state_paths=TRUE) else NULL)
 if(prior=='rhs')a$rhs_control<-list(tau0=.001,slab_scale=1,interweave_global=TRUE)
 f<-do.call(autodesn_fit_bank,a);ref<-do.call(old$autodesn_fit_bank,a)
 stopifnot(identical(f$trace[,names(ref$trace)],ref$trace),identical(f$beta,ref$beta),identical(f$local,ref$local),identical(f$volatility,ref$volatility),identical(f$probes,ref$probes),identical(f$controls$target_id,ref$controls$target_id));cases<-cases+1L
}
jsonlite::write_json(list(complete=TRUE,cases=cases,common_traces_bit_identical=TRUE,coefficient_local_and_volatility_states_bit_identical=TRUE,scope='Monitoring additions under ridge/RHS and constant/SV targets, same seeds and R algebra'), 'validation/autodesn/remediation/evidence/trace_invariance.json',pretty=TRUE,auto_unbox=TRUE)
