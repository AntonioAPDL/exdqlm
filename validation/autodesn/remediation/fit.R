# Training-only development fits. No truth or held-out response is read.
args<-commandArgs(TRUE);family<-if(length(args))args[1] else 'F1';phase<-if(length(args)>1)args[2] else 'pilot';budget<-if(length(args)>2)as.integer(args[3]) else 32000L
families<-c('F1','F2','SV','F2flat','SVseasonal','F1ridge','F2ridge');stopifnot(family%in%families,phase%in%c('pilot','production'));prior_kind<-if(grepl('ridge$',family))'ridge' else 'rhs'
run_label<-Sys.getenv('AUTODESN_RUN_LABEL',unset='');stopifnot(grepl('^[A-Za-z0-9_]*$',run_label));suffix<-if(nzchar(run_label))paste0('_',run_label) else ''
local_path<-Sys.getenv('AUTODESN_LOCAL_PROPOSAL',unset='')
statistics_path<-Sys.getenv('AUTODESN_STATISTICS_CACHE',unset='')
local_scales<-identical(Sys.getenv('AUTODESN_LOCAL_SCALE_PROPOSAL',unset='0'),'1')
root<-'validation/autodesn/remediation';directory<-file.path(root,'artifacts',family,if(phase=='pilot')'pilot' else paste0('production_',budget,suffix));dir.create(directory,recursive=TRUE,showWarnings=FALSE)
scale_path<-Sys.getenv('AUTODESN_FROZEN_PROPOSAL',unset='');if(!nzchar(scale_path))scale_path<-file.path(root,'artifacts',family,'frozen_proposal.rds')
snapshot<-Sys.getenv('AUTODESN_SOURCE_SNAPSHOT',unset='.')
relative_paths<-c(list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=FALSE),'autodesn_rhs.cpp','RcppExports.cpp','fit.R')
paths<-c(file.path(snapshot,'R',head(relative_paths,-3L)),file.path(snapshot,'src',c('autodesn_rhs.cpp','RcppExports.cpp')),file.path(snapshot,'validation/autodesn/remediation/fit.R'))
logical_paths<-substring(paths,nchar(snapshot)+2L)
source_sha<-setNames(vapply(paths,function(p)digest::digest(file=p,algo='sha256'),''),logical_paths)
for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
Rcpp::sourceCpp(file.path(snapshot,'src/autodesn_rhs.cpp'),cacheDir=file.path(root,'artifacts/cpp'),showOutput=FALSE)
basepath<-'validation/autodesn/nonlinear_heteroscedastic/artifacts/standardized_bank/bank.rds';use_cache<-identical(Sys.getenv('AUTODESN_INFERENCE_CACHE'),'1');cache_manifest<-NULL
if(use_cache){cache_manifest<-jsonlite::fromJSON(file.path(root,'artifacts/inference_cache_manifest.json'));stopifnot(identical(digest::digest(file=cache_manifest$path,algo='sha256'),cache_manifest$sha256),identical(digest::digest(file=basepath,algo='sha256'),cache_manifest$source_bank_sha256));b<-readRDS(cache_manifest$path)} else b<-readRDS(basepath)
stopifnot(b$n==2000L,identical(b$keep_idx,501:2500),length(b$history)==2500L,length(b$models)==426L)
if(use_cache){key<-if(family%in%c('F1','F1ridge'))'F1' else if(family=='F2flat')'F2flat' else 'F2';entry<-cache_manifest$extensions[[key]];stopifnot(identical(digest::digest(file=entry$path,algo='sha256'),entry$sha256));bank<-b;bank$extension<-readRDS(entry$path);class(bank)<-c('autodesn_extended_bank',class(bank));stopifnot(identical(bank$extension$id,entry$bank_id))} else bank<-autodesn_extend_bank(b,list(lags=1:90,prior=if(family%in%c('F1','F2flat','F1ridge'))'flat' else 'grouped',cache_size=32),if(family%in%c('F1','F1ridge'))NULL else list(periods=20:120,harmonics=16))
vc<-if(family%in%c('SV','SVseasonal'))list(type='sv',seasonal=family=='SVseasonal',save_state_paths=TRUE) else NULL
if(nzchar(statistics_path)){
 cached_statistics<-readRDS(statistics_path)
 stopifnot(identical(cached_statistics$bank_id,bank$extension$id),identical(cached_statistics$version,1L))
 bank$extension$statistics_cache<-cached_statistics
 rm(cached_statistics)
}
rm(b);gc(FALSE)
burn<-if(phase=='pilot')1000L else if(budget==32000L)8000L else if(budget==128000L)32000L else 64000L
retained<-if(phase=='pilot')2000L else budget
config<-list(family=family,beta_prior=prior_kind,storage_label=run_label,inference_cache_sha256=if(use_cache)cache_manifest$sha256 else NULL,cache_manifest_sha256=if(use_cache)digest::digest(file=file.path(root,'artifacts/inference_cache_manifest.json'),algo='sha256') else NULL,augmentation_sha256=if(use_cache)entry$sha256 else NULL,proposal_sha256=if(phase=='production')digest::digest(file=scale_path,algo='sha256') else NULL,priors=list(intercept_variance=10,observation_variance=list(shape=3,rate=1),rhs=if(prior_kind=='rhs')list(tau0=.001,slab_scale=1,slab_df=4,global='unit half-Cauchy',local='unit half-Cauchy') else NULL,ridge_precision=if(prior_kind=='ridge')list(shape=2,rate=2) else NULL),phase=phase,burn=burn,retained=retained,chains=4L,rows=c(501L,2500L),training_response_sd=sd(bank$y),source_sha256=as.list(source_sha),input_bank_sha256=digest::digest(file=basepath,algo='sha256'),bank_id=bank$extension$id,confirmation=FALSE,test_data_read=FALSE,forecast_allowed=FALSE)
if(phase=='production'){config$proposal_sha256<-digest::digest(file=scale_path,algo='sha256');config$proposal_path<-scale_path}
if(nzchar(statistics_path)){
 config$statistics_cache_path<-statistics_path
 config$statistics_cache_sha256<-digest::digest(file=statistics_path,algo='sha256')
 config$statistics_cache_entries<-length(bank$extension$statistics_cache$entries)
 config$statistics_cache_payload_bytes<-bank$extension$statistics_cache$payload_bytes
}
if(nzchar(local_path)){
 stopifnot(prior_kind=='rhs',phase=='production');config$local_proposal_path<-local_path;config$local_proposal_sha256<-digest::digest(file=local_path,algo='sha256')
 lp<-readRDS(local_path)$proposal
 if(!is.null(lp$kernel_coordinates)){
  stopifnot('kernel_coordinates'%in%names(formals(autodesn_extended_local_proposal)))
  config$local_kernel_coordinates<-lp$kernel_coordinates
 }
 rm(lp)
}
if(local_scales){stopifnot(nzchar(local_path),phase=='production');config$local_scale_proposal<-TRUE}
contract_id<-digest::digest(config,algo='sha256');contract_path<-file.path(directory,'contract.rds')
if(file.exists(contract_path))stopifnot(identical(readRDS(contract_path)$id,contract_id)) else saveRDS(list(id=contract_id,configuration=config),contract_path)
jsonlite::write_json(config,file.path(directory,'configuration.json'),pretty=TRUE,auto_unbox=TRUE)
write.csv(bank$model_info,file.path(directory,'model_metadata.csv'),row.names=FALSE)
model_control<-list(moves=4L,joint_moves=2L,save_draws=if(phase=='pilot')512L else 2048L)
if(phase=='production') {
 proposal_path<-scale_path;proposal<-readRDS(proposal_path);stopifnot(identical(digest::digest(file=proposal_path,algo='sha256'),config$proposal_sha256))
 stopifnot(identical(proposal$bank_id,bank$extension$id),isTRUE(proposal$frozen_before_production))
 model_control$proposal<-proposal$model;model_control$period_proposal<-proposal$period;if(prior_kind=='rhs')model_control$joint_proposal<-proposal$joint
}
if(nzchar(local_path)){proposal<-readRDS(local_path);stopifnot(isTRUE(proposal$frozen_before_production),isTRUE(proposal$training_only),identical(proposal$proposal$bank_id,bank$extension$id));model_control$local_proposal<-proposal$proposal;model_control$local_moves<-1L;if(local_scales)model_control$local_scale_proposal<-TRUE;rm(proposal)}
run_chain<-function(chain) {
 path<-file.path(directory,paste0('chain_',chain,'.rds'))
 if(file.exists(path)){saved<-readRDS(path);stopifnot(identical(saved$contract_id,contract_id));rm(saved);return(list(chain=chain,complete=TRUE))}
 mc<-model_control;mc$initial_model<-as.integer(round(seq(1,426,length.out=4))[chain]);mc$initial_period<-as.integer(round(seq(1,length(bank$extension$periods),length.out=4))[chain])
 rhs<-list(tau0=.001,slab_scale=1,slab_df=4,initial_global=c(.1,1,10,100)[chain],interweave_global=TRUE)
 if(local_scales)rhs$initial_slab<-c(.1,1,4,16)[chain]
 vc_chain<-vc
 if(!is.null(vc_chain)){vc_chain$initial_phi<-c(.1,.5,.8,.95)[chain];vc_chain$initial_omega<-c(.1,.2,.4,.8)[chain]}
 cat(family,phase,'chain',chain,'started\n');flush.console()
 a<-list(bank=bank,n_burn=burn,n_mcmc=retained,beta_prior=prior_kind,model_control=mc,variance_control=vc_chain,initial_variance=c(.1,.5,1,4)[chain],seed=if(phase=='pilot')2266020L+chain+100L*match(family,families) else 2466020L+chain+100L*match(family,families)+budget,backend='cpp')
 if(prior_kind=='rhs')a$rhs_control<-rhs else a$ridge_precision<-c(.1,1,10,100)[chain]
 f<-do.call(autodesn_fit_bank,a)
 f$bank<-NULL;f$reconstruction_bank<-list(path=basepath,extension_id=bank$extension$id,readout=bank$extension$readout,seasonal=bank$extension$seasonal)
 saved<-list(fit=f,contract_id=contract_id,source_sha256=source_sha)
 tmp<-paste0(path,'.writing');saveRDS(saved,tmp);stopifnot(identical(readRDS(tmp)$contract_id,contract_id));stopifnot(file.rename(tmp,path))
 tr<-f$trace;tr$chain<-chain;for(j in seq_len(ncol(f$probes)))tr[[paste0('fitted_probe_',j)]]<-f$probes[,j]
 write.csv(tr,file.path(directory,paste0('trace_',chain,'.csv')),row.names=FALSE)
 jsonlite::write_json(list(complete=TRUE,chain=chain,phase=phase,contract_id=contract_id,target_id=f$controls$target_id,qualified=FALSE,computation=f$computation,checkpoint_sha256=digest::digest(file=path,algo='sha256')),file.path(directory,paste0('chain_',chain,'_status.json')),pretty=TRUE,auto_unbox=TRUE)
 rm(saved,f,tr);gc(FALSE);list(chain=chain,complete=TRUE)
}
workers<-as.integer(Sys.getenv('AUTODESN_CHAIN_WORKERS',unset='1'));stopifnot(workers%in%c(1L,2L,4L));gc(FALSE)
if(workers>1L){gate<-jsonlite::fromJSON(file.path(root,'evidence/fork_cache_preflight_reloaded.json'));memory<-jsonlite::fromJSON(file.path(root,'evidence/fork_cache_preflight_reloaded_resources.json'));stopifnot(use_cache,isTRUE(gate$complete),gate$retained>=4000L,memory$exit_code==0L,memory$sampled_peak_environment_cgroup_anon_bytes<6400000000)}
selected_chains<-as.integer(strsplit(Sys.getenv('AUTODESN_CHAINS',unset='1,2,3,4'),',',fixed=TRUE)[[1]]);stopifnot(length(selected_chains)>0L,!anyDuplicated(selected_chains),all(selected_chains%in%1:4))
completed<-parallel::mclapply(selected_chains,run_chain,mc.cores=workers,mc.set.seed=FALSE)
stopifnot(length(completed)==length(selected_chains),all(vapply(completed,function(x)is.list(x)&&isTRUE(x$complete),TRUE)))
present<-file.exists(file.path(directory,paste0('chain_',1:4,'.rds')))
if(!all(present)){jsonlite::write_json(list(complete=FALSE,chains_present=which(present),qualified=FALSE,forecast_allowed=FALSE),file.path(directory,'status.json'),pretty=TRUE,auto_unbox=TRUE);cat('Requested chains complete; full four-chain target pending\n');quit(status=0)}

fits<-lapply(1:4,function(k)readRDS(file.path(directory,paste0('chain_',k,'.rds')))$fit)
stopifnot(length(unique(vapply(fits,function(f)f$controls$target_id,'')))==1)
if(phase=='pilot') {
 training<-do.call(rbind,lapply(fits,`[[`,'trace'));joint<-NULL
 if(prior_kind=='rhs'){cols<-grep('^log_global_',names(training),value=TRUE)
 Z<-as.matrix(cbind(log(training$variance),training[cols],training$log_slab));D<-ncol(Z);C<-cov(Z);C<-.9*C+.1*diag(diag(C))+diag(c(.05,rep(.2,D-1))^2)
 centers<-matrix(rep(colMeans(Z),each=426),426,D)
 for(m in 1:426){ids<-which(training$model==m);if(length(ids)>=30L)centers[m,]<-colMeans(Z[ids,,drop=FALSE])}
 joint<-autodesn_extended_proposal(centers,C*3/5*1.2^2,wide_center=colMeans(Z),wide_scale=9*C)
 }
 q<-.2*bank$prior+.8*tabulate(training$model,426)/nrow(training);qp<-.2*bank$extension$period_prior+.8*tabulate(training$period_index,length(bank$extension$periods))/nrow(training)
 proposal<-list(bank_id=bank$extension$id,joint=joint,model=q,period=qp,frozen_before_production=TRUE,training_only=TRUE,sources=lapply(1:4,function(k)list(path=file.path(directory,paste0('chain_',k,'.rds')),sha256=digest::digest(file=file.path(directory,paste0('chain_',k,'.rds')),algo='sha256'))))
 saveRDS(proposal,file.path(root,'artifacts',family,'frozen_proposal.rds'))
}
jsonlite::write_json(list(complete=TRUE,phase=phase,qualified=FALSE,forecast_allowed=FALSE,bank_id=bank$extension$id,chains=4L,retained_per_chain=retained,target_id=fits[[1]]$controls$target_id,source_sha256=as.list(source_sha)),file.path(directory,'status.json'),pretty=TRUE,auto_unbox=TRUE)
cat(family,phase,'four chains complete; independent qualification required\n')
