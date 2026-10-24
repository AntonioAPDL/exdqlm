# Validate completed chain artifacts even if a launcher failed after checkpointing.
args<-commandArgs(TRUE);stopifnot(length(args)==2L);root<-'validation/autodesn/remediation';d<-file.path(root,'artifacts',args[1],args[2])
contract<-readRDS(file.path(d,'contract.rds'));targets<-character(4)
for(k in 1:4) {
 p<-file.path(d,paste0('chain_',k,'.rds'));x<-readRDS(p);st<-jsonlite::fromJSON(file.path(d,paste0('chain_',k,'_status.json')))
 stopifnot(identical(x$contract_id,contract$id),identical(st$contract_id,contract$id),identical(digest::digest(file=p,algo='sha256'),st$checkpoint_sha256),nrow(x$fit$trace)==contract$configuration$retained,all(is.finite(as.matrix(x$fit$trace))))
 csv<-read.csv(file.path(d,paste0('trace_',k,'.csv')));stopifnot(nrow(csv)==nrow(x$fit$trace),isTRUE(all.equal(as.matrix(csv[,names(x$fit$trace)]),as.matrix(x$fit$trace),tolerance=1e-12,check.attributes=FALSE)))
 targets[k]<-x$fit$controls$target_id
}
stopifnot(length(unique(targets))==1L)
if(args[2]=='pilot') {
 proposal<-readRDS(file.path(root,'artifacts',args[1],'frozen_proposal.rds'))
 stopifnot(isTRUE(proposal$frozen_before_production),all(proposal$model>0),all(proposal$period>0),abs(sum(proposal$model)-1)<1e-10,abs(sum(proposal$period)-1)<1e-10)
}
record<-list(complete=TRUE,chain_artifacts_verified=4L,contract_id=contract$id,target_id=targets[1],proposal_verified=args[2]=='pilot',posterior_qualified=FALSE,scope='Saved chain checksums, target identities and exported trace parity; launcher status remains a separate execution record')
jsonlite::write_json(record,file.path(root,'evidence',paste0(args[1],'_',args[2],'_checkpoint_validation.json')),pretty=TRUE,auto_unbox=TRUE);print(record)
