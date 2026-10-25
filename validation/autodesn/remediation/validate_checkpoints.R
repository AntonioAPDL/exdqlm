# Validate completed chain artifacts even if a launcher failed after checkpointing.
args<-commandArgs(TRUE);stopifnot(length(args)%in%c(2L,4L));root<-'validation/autodesn/remediation';d<-if(length(args)==4L)args[3] else file.path(root,'artifacts',args[1],args[2])
output<-if(length(args)==4L)args[4] else file.path(root,'evidence',paste0(args[1],'_',args[2],'_checkpoint_validation.json'))
contract<-readRDS(file.path(d,'contract.rds'));targets<-character(4);inputs<-list();joint_states<-integer(4)
input_hash<-function(name){p<-file.path(d,name);inputs[[name]]<<-digest::digest(file=p,algo='sha256');p}
input_hash('contract.rds');input_hash('configuration.json')
for(k in 1:4) {
 p<-input_hash(paste0('chain_',k,'.rds'));x<-readRDS(p);st<-jsonlite::fromJSON(input_hash(paste0('chain_',k,'_status.json')))
 stopifnot(identical(x$contract_id,contract$id),identical(st$contract_id,contract$id),identical(digest::digest(file=p,algo='sha256'),st$checkpoint_sha256),nrow(x$fit$trace)==contract$configuration$retained,all(is.finite(as.matrix(x$fit$trace))))
 stopifnot(identical(st$target_id,x$fit$controls$target_id),x$fit$controls$n_mcmc==contract$configuration$retained,x$fit$controls$n_burn==contract$configuration$burn)
 csv<-read.csv(input_hash(paste0('trace_',k,'.csv')));stopifnot(nrow(csv)==nrow(x$fit$trace),isTRUE(all.equal(as.matrix(csv[,names(x$fit$trace)]),as.matrix(x$fit$trace),tolerance=1e-12,check.attributes=FALSE)))
 if(ncol(x$fit$probes))stopifnot(isTRUE(all.equal(as.matrix(csv[,paste0('fitted_probe_',seq_len(ncol(x$fit$probes))),drop=FALSE]),x$fit$probes,tolerance=1e-12,check.attributes=FALSE)))
 ix<-match(x$fit$draws$iteration,x$fit$trace$iteration)
 stopifnot(!anyNA(ix),!anyDuplicated(ix),isTRUE(all.equal(x$fit$draws,x$fit$trace[ix,,drop=FALSE],tolerance=0)),nrow(x$fit$draws)==length(x$fit$beta),all(is.finite(unlist(x$fit$beta))))
 if(x$fit$meta$beta_prior_type=='independent_rhs')stopifnot(length(x$fit$local)==nrow(x$fit$draws),all(is.finite(unlist(x$fit$local))))
 joint_states[k]<-nrow(x$fit$draws)
 metadata_path<-file.path(d,'model_metadata.csv');if(file.exists(metadata_path)){metadata<-read.csv(input_hash('model_metadata.csv'));stopifnot(isTRUE(all.equal(metadata,x$fit$model_summary[,names(metadata),drop=FALSE],check.attributes=FALSE,tolerance=1e-12)))}
 targets[k]<-x$fit$controls$target_id;rm(x,csv);gc(FALSE)
}
stopifnot(length(unique(targets))==1L)
if(args[2]=='pilot') {
 proposal<-readRDS(file.path(dirname(d),'frozen_proposal.rds'))
 stopifnot(isTRUE(proposal$frozen_before_production),all(proposal$model>0),all(proposal$period>0),abs(sum(proposal$model)-1)<1e-10,abs(sum(proposal$period)-1)<1e-10)
}
record<-list(complete=TRUE,chain_artifacts_verified=4L,contract_id=contract$id,target_id=targets[1],proposal_verified=args[2]=='pilot',matching_joint_states_per_chain=joint_states,input_files_sha256=inputs,posterior_qualified=FALSE,scope='Complete RDS/status/contract identities, trace and fitted-probe CSV parity, exact matching coefficient/local-state indices; launcher completion and posterior qualification remain separate')
jsonlite::write_json(record,output,pretty=TRUE,auto_unbox=TRUE);print(record)
