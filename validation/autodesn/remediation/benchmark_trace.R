# Exact Markov-state and RNG parity against the committed data.frame sampler.
source('validation/autodesn/load_checkout.R');root<-'validation/autodesn/remediation'
args<-commandArgs(TRUE);label<-if(length(args))args[1] else 'trace_storage';stopifnot(grepl('^[A-Za-z0-9_]+$',label),!file.exists(file.path(root,'evidence',paste0(label,'_benchmark.json'))))
Rcpp::sourceCpp('src/autodesn_rhs.cpp',cacheDir=file.path(root,'artifacts/cpp'),showOutput=FALSE)
reference<-tempfile(fileext='.R');writeLines(system2('git',c('show','cccb22d595efb74445fff8d6cb855c5c7076f7f5:R/autodesn_extended.R'),stdout=TRUE),reference)
old<-new.env(parent=.GlobalEnv);sys.source(reference,old);old_dispatch<-autodesn_fit_bank;environment(old_dispatch)<-old
x<-seq(-1,1,length.out=12);b<-autodesn_prepare_bank(sin(x),list(matrix(x),cbind(x,x*x)),normalize_features=FALSE,standardize_features=TRUE)
e<-autodesn_extend_bank(b,seasonal_control=list(periods=c(4,11),harmonics=2));count<-0L
for(prior in c('ridge','rhs'))for(sv in c(FALSE,TRUE)){
 a<-list(bank=e,n_burn=20,n_mcmc=200,beta_prior=prior,model_control=list(method='categorical',joint_moves=1,save_draws=25),seed=8236100,backend='cpp',variance_control=if(sv)list(type='sv',save_state_paths=TRUE) else NULL)
 if(prior=='rhs')a$rhs_control<-list(tau0=.2,interweave_global=TRUE)
 old_fit<-do.call(old_dispatch,a);new_fit<-do.call(autodesn_fit_bank,a)
 for(field in c('draws','trace','beta','local','volatility','probes','model_summary','period_summary','controls'))stopifnot(identical(old_fit[[field]],new_fit[[field]]))
 count<-count+1L
}
a<-list(bank=e,n_burn=500,n_mcmc=5000,beta_prior='rhs',rhs_control=list(tau0=.2,interweave_global=TRUE),model_control=list(method='categorical',joint_moves=1,save_draws=128),seed=8336100,backend='cpp')
rows<-list();at<-0L
for(replicate in 1:3)for(backend in if(replicate%%2)c('data.frame','matrix') else c('matrix','data.frame')){
 f<-do.call(if(backend=='matrix')autodesn_fit_bank else old_dispatch,a);at<-at+1L;rows[[at]]<-data.frame(replicate=replicate,storage=backend,inference_elapsed_seconds=f$computation$elapsed_seconds)
 if(backend=='data.frame')old_state<-f else new_state<-f
 if(exists('old_state')&&exists('new_state')){stopifnot(identical(old_state$trace,new_state$trace),identical(old_state$beta,new_state$beta),identical(old_state$local,new_state$local))}
}
table<-do.call(rbind,rows);write.csv(table,file.path(root,'evidence',paste0(label,'_timings.csv')),row.names=FALSE)
med<-aggregate(inference_elapsed_seconds~storage,table,median)
jsonlite::write_json(list(complete=TRUE,optimization=label,reference_commit='cccb22d595efb74445fff8d6cb855c5c7076f7f5',bit_identical_cases=count,full_trace_and_matching_joint_states_identical=TRUE,replicates=3,timings=med,scope='Paired small-target public sampler optimization benchmark; other training jobs active; not a whole-study speedup'),file.path(root,'evidence',paste0(label,'_benchmark.json')),pretty=TRUE,auto_unbox=TRUE);print(med)
