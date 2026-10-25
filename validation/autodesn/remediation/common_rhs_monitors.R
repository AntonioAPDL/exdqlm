# Common-coordinate monitors: all90 lag slopes, locals and prior variances.
phase<-commandArgs(TRUE);stopifnot(length(phase)==1L)
r<-'validation/autodesn/remediation';d<-file.path(r,'artifacts/F1',phase)
configuration<-jsonlite::fromJSON(file.path(d,'configuration.json'));sources<-list()
out<-file.path(r,'artifacts/common_rhs_monitors',phase);dir.create(out,recursive=TRUE,showWarnings=FALSE)
for(k in 1:4){
 p<-file.path(d,paste0('chain_',k,'.rds'));status<-jsonlite::fromJSON(file.path(d,paste0('chain_',k,'_status.json')))
 stopifnot(status$complete,identical(digest::digest(file=p,algo='sha256'),status$checkpoint_sha256))
 f<-readRDS(p)$fit;stopifnot(f$meta$period_policy=='none',f$controls$rhs_control$tau0==.001,
   f$controls$rhs_control$slab_scale==1,f$controls$rhs_control$slab_df==4,nrow(f$draws)==length(f$beta),length(f$local)==length(f$beta))
 B<-t(vapply(f$beta,function(x)x[2:91],numeric(90)))/configuration$training_response_sd
 ell<-t(vapply(f$local,function(x)x[1:90],numeric(90)))
 a<--f$draws$log_slab;b<--2*(log(.001)+f$draws$log_global_1+ell)
 logv<--pmax(a,b)-log1p(exp(-abs(a-b)))
 colnames(B)<-paste0('lag_beta_',1:90);colnames(ell)<-paste0('log_local_',1:90);colnames(logv)<-paste0('log_prior_variance_',1:90)
 z<-data.frame(chain=k,iteration=f$draws$iteration,B,ell,logv)
 stopifnot(ncol(z)==272L,all(is.finite(as.matrix(z))))
 write.csv(z,file.path(out,paste0('chain_',k,'.csv')),row.names=FALSE)
 sources[[k]]<-list(path=p,sha256=status$checkpoint_sha256,target_id=f$controls$target_id)
 rm(f,B,ell,logv,z);gc(FALSE)
}
stopifnot(length(unique(vapply(sources,`[[`,'','target_id')))==1L)
jsonlite::write_json(list(complete=TRUE,phase=phase,source_checkpoints=sources,source_snapshot=Sys.getenv('AUTODESN_SOURCE_SNAPSHOT'),monitors=270L,heldout_used=FALSE,posterior_qualified=FALSE),file.path(out,'status.json'),pretty=TRUE,auto_unbox=TRUE)
