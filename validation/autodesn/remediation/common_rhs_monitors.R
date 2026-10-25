# Common-coordinate monitors: all90 lag slopes, locals and prior variances.
args<-commandArgs(TRUE);stopifnot(length(args)%in%c(1L,4L));phase<-args[1];family<-if(length(args)==4L)args[2] else 'F1'
r<-'validation/autodesn/remediation';d<-if(length(args)==4L)args[3] else file.path(r,'artifacts/F1',phase)
configuration<-jsonlite::fromJSON(file.path(d,'configuration.json'));sources<-list()
coefficient_scale<-configuration$training_response_sd
# Early pilots omitted this display-unit metadata. Positive fixed rescaling
# cannot affect rank R-hat or ESS; retain their fitted response units explicitly.
if(is.null(coefficient_scale))coefficient_scale<-1
stopifnot(length(coefficient_scale)==1L,is.finite(coefficient_scale),coefficient_scale>0)
out<-if(length(args)==4L)args[4] else file.path(r,'artifacts/common_rhs_monitors',phase);dir.create(out,recursive=TRUE,showWarnings=FALSE)
for(k in 1:4){
 p<-file.path(d,paste0('chain_',k,'.rds'));status<-jsonlite::fromJSON(file.path(d,paste0('chain_',k,'_status.json')))
 stopifnot(status$complete,identical(digest::digest(file=p,algo='sha256'),status$checkpoint_sha256))
 f<-readRDS(p)$fit;stopifnot(f$meta$global_groups[1]%in%c('all','lag'),f$controls$rhs_control$tau0==.001,
   f$controls$rhs_control$slab_scale==1,f$controls$rhs_control$slab_df==4,nrow(f$draws)==length(f$beta),length(f$local)==length(f$beta))
 B<-t(vapply(f$beta,function(x)x[2:91],numeric(90)))/coefficient_scale
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
jsonlite::write_json(list(complete=TRUE,phase=phase,family=family,source_checkpoints=sources,coefficient_scale=coefficient_scale,coefficient_units=if(is.null(configuration$training_response_sd))'fitted scaled-response units; no response-SD display normalization' else 'training-response-SD units',source_snapshot=Sys.getenv('AUTODESN_SOURCE_SNAPSHOT'),monitors=270L,heldout_used=FALSE,posterior_qualified=FALSE),file.path(out,'status.json'),pretty=TRUE,auto_unbox=TRUE)
