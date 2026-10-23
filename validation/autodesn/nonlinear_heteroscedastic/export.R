# Export all retained scalar traces and hyperparameter summaries, bank-free.
args<-commandArgs(trailingOnly=TRUE);base<-if(length(args)) args[1] else "validation/autodesn/nonlinear_heteroscedastic/artifacts"
cfg<-jsonlite::fromJSON("validation/autodesn/nonlinear_heteroscedastic/study.json")
# Write and compress a closed regular file before publishing it. The former
# direct gzfile export left two truncated streams despite a zero process exit;
# the original RDS chains were intact. Downstream audits read every gzip to EOF.
export_trace<-function(x,path) {
 gzip<-Sys.which("gzip");stopifnot(nzchar(gzip))
 tmp<-tempfile("trace-",tmpdir=dirname(path),fileext=".csv")
 on.exit(unlink(c(tmp,paste0(tmp,".gz"))),add=TRUE)
 write.csv(x,tmp,row.names=FALSE)
 stopifnot(system2(gzip,c("-n","-f",shQuote(tmp)))==0L,
           file.exists(paste0(tmp,".gz")))
 stopifnot(file.rename(paste0(tmp,".gz"),path))
}
selected<-NULL
at<-which(args=="--scenario")
if(length(at)) {
 stopifnot(length(at)==1L,at<length(args),args[at+1L]%in%cfg$scenarios$id)
 selected<-args[at+1L];cfg$scenarios<-cfg$scenarios[cfg$scenarios$id==selected,,drop=FALSE]
}
for(legacy_case in list.files(base,pattern="_initial_proposal$")) {
legacy<-file.path(base,legacy_case,"rhs")
if(dir.exists(legacy) && is.null(selected)) for(ad in list.dirs(legacy,full.names=TRUE,recursive=FALSE)) {
 if(!grepl("attempt_[0-9]+$",ad)) next
 old<-lapply(1:3,function(k) readRDS(file.path(ad,paste0("chain_",k,".rds"))))
 tr<-do.call(rbind,lapply(1:3,function(k) cbind(chain=k,old[[k]]$fit$draws)))
 export_trace(tr,file.path(ad,"traces.csv.gz"))
 saveRDS(lapply(old,function(x) list(contract_id=x$contract_id,inference_seconds=x$inference_seconds,
  controls=x$fit$controls,sampler_stats=x$fit$sampler_stats)),file.path(ad,"chain_metadata.rds"),compress="xz")
 rm(old,tr);gc(FALSE)
}
}
for(i in seq_len(nrow(cfg$scenarios))) {
 sc<-cfg$scenarios[i,];d<-file.path(base,sc$id,sc$method)
 st<-jsonlite::fromJSON(file.path(d,"status.json"));stopifnot(isTRUE(st$fit_complete))
 ad<-file.path(d,paste0("attempt_",st$selected_attempt))
 r<-lapply(1:3,function(k) readRDS(file.path(ad,paste0("chain_",k,".rds"))))
 metadata<-lapply(r,function(x) list(contract_id=x$contract_id,inference_seconds=x$inference_seconds,
   controls=x$fit$controls,sampler_stats=x$fit$sampler_stats))
 saveRDS(metadata,file.path(d,"chain_metadata.rds"),compress="xz")
 if(sc$method=="rhs" && dir.exists(file.path(d,"pilot"))) {
  pilots<-lapply(1:3,function(k) readRDS(file.path(d,"pilot",paste0("chain_",k,".rds"))))
  saveRDS(lapply(pilots,function(x) list(contract_id=x$contract_id,inference_seconds=x$inference_seconds,
   controls=x$fit$controls,sampler_stats=x$fit$sampler_stats)),file.path(d,"pilot_metadata.rds"),compress="xz")
  actual<-do.call(rbind,lapply(1:3,function(k) {
   z<-pilots[[k]];data.frame(chain=k,n_burn=z$fit$controls$n_burn,n_mcmc=z$fit$controls$n_mcmc,
    seed=z$fit$controls$seed,inference_seconds=z$inference_seconds)
  }))
  write.csv(actual,file.path(d,"effective_pilot_controls.csv"),row.names=FALSE)
  rm(pilots);gc(FALSE)
 }
 tr<-do.call(rbind,lapply(1:3,function(k) cbind(chain=k,r[[k]]$fit$draws)))
 export_trace(tr,file.path(d,"traces.csv.gz"))
 if(sc$method=="rhs") {
  names<-c("global_scale","global_tau","slab_variance","effective_slopes_diagonal")
  q<-do.call(rbind,lapply(names,function(n) data.frame(parameter=n,q05=quantile(tr[[n]],.05),median=median(tr[[n]]),q95=quantile(tr[[n]],.95))))
  write.csv(q,file.path(d,"shrinkage_quantiles.csv"),row.names=FALSE)
 }
 # Forecast-relevant functions also have a common meaning across differing
 # coefficient dimensions. Monitor six fixed training-row fitted means.
 bank<-readRDS(file.path(base,"standardized_bank/bank.rds"))
 anchors<-as.integer(round(seq(1L,bank$n,length.out=6L)))
 functional<-do.call(rbind,lapply(1:3,function(k) {
  f<-r[[k]]$fit;value<-matrix(NA_real_,nrow(f$draws),length(anchors))
  for(j in unique(f$draws$model)) {
   ids<-which(f$draws$model==j);coef<-do.call(rbind,f$beta[ids])
   value[ids,]<-coef%*%t(bank$models[[j]]$X[anchors,,drop=FALSE])
  }
  stopifnot(all(is.finite(value)))
  value<-bank$preprocessing$center+bank$preprocessing$scale*value
  colnames(value)<-paste0("fitted_time_",bank$keep_idx[anchors])
  data.frame(chain=k,iteration=seq_len(nrow(value)),value)
 }))
 export_trace(functional,file.path(d,"functional_traces.csv.gz"))
 rm(bank,functional);gc(FALSE)
 explore<-do.call(rbind,lapply(1:3,function(k) {
  f<-r[[k]]$fit;s<-f$sampler_stats
  data.frame(chain=k,draws=nrow(f$draws),unique_models=length(unique(f$draws$model)),switches=sum(diff(f$draws$model)!=0),
   nonself_proposals=if(is.null(s$nonself_proposals)) NA_real_ else s$nonself_proposals,
   nonself_acceptances=if(is.null(s$nonself_acceptances)) NA_real_ else s$nonself_acceptances)
 }))
 explore$proposal_scope<-"all_sweeps_including_burnin";explore$switch_scope<-"retained_draws"
 write.csv(explore,file.path(d,"exploration.csv"),row.names=FALSE)
 # Failed attempts retain all scalar traces and exact controls too. Full
 # coefficient vectors remain local; the compact joint checkpoint preserves
 # every draw used for the full forecasts and predictive-budget sensitivity.
 for(attempt in list.dirs(d,full.names=TRUE,recursive=FALSE)) {
  if(!grepl("attempt_[0-9]+$",attempt) || identical(attempt,ad)) next
  old<-lapply(1:3,function(k) readRDS(file.path(attempt,paste0("chain_",k,".rds"))))
  ot<-do.call(rbind,lapply(1:3,function(k) cbind(chain=k,old[[k]]$fit$draws)))
  export_trace(ot,file.path(attempt,"traces.csv.gz"))
  saveRDS(lapply(old,function(x) list(contract_id=x$contract_id,inference_seconds=x$inference_seconds,
   controls=x$fit$controls,sampler_stats=x$fit$sampler_stats)),file.path(attempt,"chain_metadata.rds"),compress="xz")
  rm(old,ot);gc(FALSE)
 }
 cat(sc$id,"trace export finished\n");rm(r,tr);gc(FALSE)
}
