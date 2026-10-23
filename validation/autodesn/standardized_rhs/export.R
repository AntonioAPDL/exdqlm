# Export all retained scalar traces and hyperparameter summaries, bank-free.
args<-commandArgs(trailingOnly=TRUE);base<-if(length(args)) args[1] else "validation/autodesn/standardized_rhs/artifacts"
cfg<-jsonlite::fromJSON("validation/autodesn/standardized_rhs/configuration.json")
for(i in seq_len(nrow(cfg$scenarios))) {
 sc<-cfg$scenarios[i,];d<-file.path(base,sc$id,sc$method)
 st<-jsonlite::fromJSON(file.path(d,"status.json"));stopifnot(isTRUE(st$complete),isTRUE(st$qualified))
 ad<-file.path(d,paste0("attempt_",st$selected_attempt))
 r<-lapply(1:3,function(k) readRDS(file.path(ad,paste0("chain_",k,".rds"))))
 tr<-do.call(rbind,lapply(1:3,function(k) cbind(chain=k,r[[k]]$fit$draws)))
 con<-gzfile(file.path(d,"traces.csv.gz"),"wt");write.csv(tr,con,row.names=FALSE);close(con)
 if(sc$method=="rhs") {
  names<-c("global_scale","global_tau","slab_variance","effective_slopes_diagonal")
  q<-do.call(rbind,lapply(names,function(n) data.frame(parameter=n,q05=quantile(tr[[n]],.05),median=median(tr[[n]]),q95=quantile(tr[[n]],.95))))
  write.csv(q,file.path(d,"shrinkage_quantiles.csv"),row.names=FALSE)
 }
 explore<-do.call(rbind,lapply(1:3,function(k) {
  f<-r[[k]]$fit;s<-f$sampler_stats
  data.frame(chain=k,draws=nrow(f$draws),unique_models=length(unique(f$draws$model)),switches=sum(diff(f$draws$model)!=0),
   nonself_proposals=if(is.null(s$nonself_proposals)) NA_real_ else s$nonself_proposals,
   nonself_acceptances=if(is.null(s$nonself_acceptances)) NA_real_ else s$nonself_acceptances)
 }))
 write.csv(explore,file.path(d,"exploration.csv"),row.names=FALSE)
 cat(sc$id,"trace export finished\n");rm(r,tr);gc(FALSE)
}
