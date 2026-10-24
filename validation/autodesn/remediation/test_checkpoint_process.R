# Executed in separate R processes to expose hidden process/RNG dependencies.
args<-commandArgs(TRUE);stopifnot(length(args)==2L,args[1]%in%c('start','resume','reference','compare'))
root<-'validation/autodesn/remediation';snapshot<-Sys.getenv('AUTODESN_SOURCE_SNAPSHOT',unset='.')
for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
Rcpp::sourceCpp(file.path(snapshot,'src/autodesn_rhs.cpp'),cacheDir=file.path(root,'artifacts/cpp'),showOutput=FALSE)
directory<-args[2];dir.create(directory,recursive=TRUE,showWarnings=FALSE)
manifest<-jsonlite::fromJSON(file.path(snapshot,'manifest.json'))
source_id<-digest::digest(manifest,algo='sha256')
y<-sin(seq_len(15)/2)
b<-autodesn_prepare_bank(y,list(cbind(y,cos(y)),matrix(y^2,ncol=1)),standardize_features=TRUE,normalize_features=FALSE)
b$history<-b$history_scaled<-c(.1,.2,y);b$keep_idx<-3:17
b<-autodesn_extend_bank(b,list(lags=1:2,prior='grouped'),list(periods=c(11,13),harmonics=1))
lp<-autodesn_extended_local_proposal(lapply(b$models,function(m)matrix(0,2,m$d)),lapply(b$models,function(m)rep(1,m$d)),bank_id=b$extension$id)
jp<-autodesn_extended_proposal(matrix(0,2,4),diag(4))
a<-list(bank=b,n_burn=20L,n_mcmc=100L,thin=2L,beta_prior='rhs',rhs_control=list(interweave_global=TRUE),
 model_control=list(joint_proposal=jp,local_proposal=lp,local_scale_proposal=TRUE,save_draws=30L),variance_control=list(type='sv',seasonal=TRUE,save_state_paths=TRUE),seed=6176021L,backend='cpp')
if(args[1]=='start'){
 stopifnot(!file.exists(file.path(directory,'state.rds')))
 e<-tryCatch(do.call(autodesn_fit_bank,c(a,list(checkpoint_control=list(path=file.path(directory,'state.rds'),every=10L,stop_after=47L,source_id=source_id)))),autodesn_checkpoint_pause=function(e)e)
 stopifnot(inherits(e,'autodesn_checkpoint_pause'),e$iteration==47L);cat('EXPECTED_PAUSE_47\n')
} else if(args[1]=='resume'){
 f<-do.call(autodesn_fit_bank,c(a,list(checkpoint_control=list(path=file.path(directory,'state.rds'),every=10L,resume=TRUE,source_id=source_id))));f$bank<-NULL;saveRDS(f,file.path(directory,'resumed.rds'))
} else if(args[1]=='reference'){
 f<-do.call(autodesn_fit_bank,a);f$bank<-NULL;saveRDS(f,file.path(directory,'reference.rds'))
} else {
 x<-readRDS(file.path(directory,'reference.rds'));z<-readRDS(file.path(directory,'resumed.rds'))
 fields<-c('draws','trace','beta','local','volatility','probes','model_summary','period_summary','controls');same<-setNames(vapply(fields,function(field)identical(x[[field]],z[[field]]),TRUE),fields)
 counters<-setdiff(names(x$computation),'elapsed_seconds');stopifnot(all(same),identical(x$computation[counters],z$computation[counters]))
 jsonlite::write_json(list(complete=TRUE,fresh_R_processes=4L,paused_after_sweep=47L,total_sweeps=120L,backend='cpp',prior='normalized_grouped_rhs',conditional_variance='seasonal_sv',joint_scale_local_proposals=TRUE,recorded_states_bit_identical=as.list(same),counters_bit_identical=TRUE,source_id=source_id,source_snapshot=snapshot,scope='Deterministic interrupted-versus-uninterrupted computation check, not posterior convergence'),file.path(root,'evidence/checkpoint_fresh_process.json'),pretty=TRUE,auto_unbox=TRUE)
 cat('FRESH_PROCESS_RECOVERY_IDENTICAL\n')
}
