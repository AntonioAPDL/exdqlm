# Check numeric artifacts after archive extraction, without the original big bank.
args<-commandArgs(TRUE);stopifnot(length(args)==1);base<-file.path(args[1],'validation/autodesn/remediation/artifacts');verified<-0L
for(family in c('F1','F2'))for(k in 1:4) {
 d<-file.path(base,family,'pilot');path<-file.path(d,paste0('chain_',k,'.rds'));x<-readRDS(path);status<-jsonlite::fromJSON(file.path(d,paste0('chain_',k,'_status.json')));tr<-read.csv(file.path(d,paste0('trace_',k,'.csv')))
 stopifnot(is.null(x$fit[["bank"]]),identical(digest::digest(file=path,algo='sha256'),status$checkpoint_sha256),identical(x$fit$controls$target_id,status$target_id),nrow(x$fit$draws)==length(x$fit$beta),length(x$fit$beta)==length(x$fit$local),length(x$fit$beta)==length(x$fit$volatility),isTRUE(all.equal(as.matrix(tr[,names(x$fit$trace)]),as.matrix(x$fit$trace),check.attributes=FALSE,tolerance=1e-12)))
 occupancy<-tabulate(x$fit$trace$model,nrow(x$fit$model_summary))/nrow(x$fit$trace);stopifnot(max(abs(occupancy-x$fit$model_summary$posterior_probability))<1e-14);verified<-verified+1L
}
jsonlite::write_json(list(complete=TRUE,verified_chain_checkpoints=verified,trace_occupancy_reproduced=TRUE,posterior_qualified=FALSE), 'validation/autodesn/remediation/evidence/restored_checkpoint_001_test.json',pretty=TRUE,auto_unbox=TRUE)
