# Training-only development fits. No truth or held-out response is read.
args<-commandArgs(TRUE);family<-if(length(args))args[1] else 'F1';phase<-if(length(args)>1)args[2] else 'pilot';budget<-if(length(args)>2)as.integer(args[3]) else 32000L
stopifnot(family%in%c('F1','F2','SV'),phase%in%c('pilot','production'))
root<-'validation/autodesn/remediation';directory<-file.path(root,'artifacts',family,if(phase=='pilot')'pilot' else paste0('production_',budget));dir.create(directory,recursive=TRUE,showWarnings=FALSE)
snapshot<-Sys.getenv('AUTODESN_SOURCE_SNAPSHOT',unset='.')
relative_paths<-c(list.files(file.path(snapshot,'R'),pattern='\\.R$',full.names=FALSE),'autodesn_rhs.cpp','RcppExports.cpp','fit.R')
paths<-c(file.path(snapshot,'R',head(relative_paths,-3L)),file.path(snapshot,'src',c('autodesn_rhs.cpp','RcppExports.cpp')),file.path(snapshot,'validation/autodesn/remediation/fit.R'))
logical_paths<-substring(paths,nchar(snapshot)+2L)
source_sha<-setNames(vapply(paths,function(p)digest::digest(file=p,algo='sha256'),''),logical_paths)
for(p in list.files(file.path(snapshot,'R'),pattern='\\.R$',full.names=TRUE))source(p,local=.GlobalEnv)
Rcpp::sourceCpp(file.path(snapshot,'src/autodesn_rhs.cpp'),cacheDir=file.path(root,'artifacts/cpp'),showOutput=FALSE)
basepath<-'validation/autodesn/nonlinear_heteroscedastic/artifacts/standardized_bank/bank.rds';b<-readRDS(basepath)
stopifnot(b$n==2000L,identical(b$keep_idx,501:2500),length(b$history)==2500L,length(b$models)==426L)
bank<-autodesn_extend_bank(b,list(lags=1:90,prior=if(family=='F1')'flat' else 'grouped',cache_size=32),if(family=='F1')NULL else list(periods=20:120,harmonics=16))
vc<-if(family=='SV')list(type='sv',save_state_paths=TRUE) else NULL
burn<-if(phase=='pilot')1000L else if(budget==32000L)8000L else if(budget==128000L)32000L else 64000L
retained<-if(phase=='pilot')2000L else budget
config<-list(family=family,phase=phase,burn=burn,retained=retained,chains=4L,rows=c(501L,2500L),source_sha256=as.list(source_sha),input_bank_sha256=digest::digest(file=basepath,algo='sha256'),bank_id=bank$extension$id,confirmation=FALSE,test_data_read=FALSE,forecast_allowed=FALSE)
contract_id<-digest::digest(config,algo='sha256');contract_path<-file.path(directory,'contract.rds')
if(file.exists(contract_path))stopifnot(identical(readRDS(contract_path)$id,contract_id)) else saveRDS(list(id=contract_id,configuration=config),contract_path)
jsonlite::write_json(config,file.path(directory,'configuration.json'),pretty=TRUE,auto_unbox=TRUE)
model_control<-list(moves=4L,joint_moves=2L,save_draws=if(phase=='pilot')512L else 2048L)
if(phase=='production') {
 proposal<-readRDS(file.path(root,'artifacts',family,'frozen_proposal.rds'))
 stopifnot(identical(proposal$bank_id,bank$extension$id),isTRUE(proposal$frozen_before_production))
 model_control$proposal<-proposal$model;model_control$period_proposal<-proposal$period;model_control$joint_proposal<-proposal$joint
}
run_chain<-function(chain) {
 path<-file.path(directory,paste0('chain_',chain,'.rds'))
 if(file.exists(path)){saved<-readRDS(path);stopifnot(identical(saved$contract_id,contract_id));rm(saved);return(list(chain=chain,complete=TRUE))}
 mc<-model_control;mc$initial_model<-as.integer(round(seq(1,426,length.out=4))[chain]);mc$initial_period<-as.integer(round(seq(1,length(bank$extension$periods),length.out=4))[chain])
 rhs<-list(tau0=.001,slab_scale=1,slab_df=4,initial_global=c(.1,1,10,100)[chain],interweave_global=TRUE)
 vc_chain<-vc
 if(!is.null(vc_chain)){vc_chain$initial_phi<-c(.1,.5,.8,.95)[chain];vc_chain$initial_omega<-c(.1,.2,.4,.8)[chain]}
 cat(family,phase,'chain',chain,'started\n');flush.console()
 f<-autodesn_fit_bank(bank,n_burn=burn,n_mcmc=retained,beta_prior='rhs',rhs_control=rhs,model_control=mc,variance_control=vc_chain,initial_variance=c(.1,.5,1,4)[chain],seed=if(phase=='pilot')2266020L+chain+100L*match(family,c('F1','F2','SV')) else 2466020L+chain+100L*match(family,c('F1','F2','SV'))+budget,backend='cpp')
 f$bank<-NULL;f$bank_reference<-list(path=basepath,extension_id=bank$extension$id,readout=bank$extension$readout,seasonal=bank$extension$seasonal)
 saved<-list(fit=f,contract_id=contract_id,source_sha256=source_sha)
 tmp<-paste0(path,'.writing');saveRDS(saved,tmp);stopifnot(identical(readRDS(tmp)$contract_id,contract_id));stopifnot(file.rename(tmp,path))
 tr<-f$trace;tr$chain<-chain;for(j in seq_len(ncol(f$probes)))tr[[paste0('fitted_probe_',j)]]<-f$probes[,j]
 write.csv(tr,file.path(directory,paste0('trace_',chain,'.csv')),row.names=FALSE)
 jsonlite::write_json(list(complete=TRUE,chain=chain,phase=phase,contract_id=contract_id,target_id=f$controls$target_id,qualified=FALSE,computation=f$computation,checkpoint_sha256=digest::digest(file=path,algo='sha256')),file.path(directory,paste0('chain_',chain,'_status.json')),pretty=TRUE,auto_unbox=TRUE)
 rm(saved,f,tr);gc(FALSE);list(chain=chain,complete=TRUE)
}
workers<-as.integer(Sys.getenv('AUTODESN_CHAIN_WORKERS',unset='1'));stopifnot(workers%in%1:2);gc(FALSE)
completed<-parallel::mclapply(1:4,run_chain,mc.cores=workers,mc.set.seed=FALSE)
stopifnot(length(completed)==4L,all(vapply(completed,function(x)is.list(x)&&isTRUE(x$complete),TRUE)),all(file.exists(file.path(directory,paste0('chain_',1:4,'.rds')))))

fits<-lapply(1:4,function(k)readRDS(file.path(directory,paste0('chain_',k,'.rds')))$fit)
stopifnot(length(unique(vapply(fits,function(f)f$controls$target_id,'')))==1)
if(phase=='pilot') {
 training<-do.call(rbind,lapply(fits,`[[`,'trace'));cols<-grep('^log_global_',names(training),value=TRUE)
 Z<-as.matrix(cbind(log(training$variance),training[cols],training$log_slab));D<-ncol(Z);C<-cov(Z);C<-.9*C+.1*diag(diag(C))+diag(c(.05,rep(.2,D-1))^2)
 centers<-matrix(rep(colMeans(Z),each=426),426,D)
 for(m in 1:426){ids<-which(training$model==m);if(length(ids)>=30L)centers[m,]<-colMeans(Z[ids,,drop=FALSE])}
 q<-.2*bank$prior+.8*tabulate(training$model,426)/nrow(training);qp<-.2*bank$extension$period_prior+.8*tabulate(training$period_index,length(bank$extension$periods))/nrow(training)
 proposal<-list(bank_id=bank$extension$id,joint=autodesn_extended_proposal(centers,C*3/5*1.2^2,wide_center=colMeans(Z),wide_scale=9*C),model=q,period=qp,frozen_before_production=TRUE,training_only=TRUE,sources=lapply(1:4,function(k)list(path=file.path(directory,paste0('chain_',k,'.rds')),sha256=digest::digest(file=file.path(directory,paste0('chain_',k,'.rds')),algo='sha256'))))
 saveRDS(proposal,file.path(root,'artifacts',family,'frozen_proposal.rds'))
}
jsonlite::write_json(list(complete=TRUE,phase=phase,qualified=FALSE,forecast_allowed=FALSE,bank_id=bank$extension$id,chains=4L,retained_per_chain=retained,target_id=fits[[1]]$controls$target_id,source_sha256=as.list(source_sha)),file.path(directory,'status.json'),pretty=TRUE,auto_unbox=TRUE)
cat(family,phase,'four chains complete; independent qualification required\n')
