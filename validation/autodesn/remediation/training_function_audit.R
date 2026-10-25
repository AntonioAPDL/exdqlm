# Descriptive training function audit, not qualification or forecast selection.
args<-commandArgs(TRUE);stopifnot(length(args)==1L);phase<-args[1]
r<-'validation/autodesn/remediation';snapshot<-Sys.getenv('AUTODESN_SOURCE_SNAPSHOT');stopifnot(nzchar(snapshot))
for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
d<-file.path(r,'artifacts/F1',phase);configuration<-jsonlite::fromJSON(file.path(d,'configuration.json'))
qualification<-jsonlite::fromJSON(file.path(d,'qualification.json'));stopifnot(qualification$screen_passed,!qualification$qualified)
manifest<-jsonlite::fromJSON(file.path(r,'artifacts/inference_cache_manifest.json'))
stopifnot(identical(digest::digest(file=manifest$path,algo='sha256'),manifest$sha256))
b<-readRDS(manifest$path);entry<-manifest$extensions$F1
stopifnot(identical(digest::digest(file=entry$path,algo='sha256'),entry$sha256))
b$extension<-readRDS(entry$path);class(b)<-c('autodesn_extended_bank',class(b))
stopifnot(identical(b$extension$id,configuration$bank_id),identical(b$extension$lag$active,1:90),
  identical(b$keep_idx,501:2500),length(b$history)==2500L)
stopifnot(identical(digest::digest(file=configuration$statistics_cache_path,algo='sha256'),configuration$statistics_cache_sha256))
b$extension$statistics_cache<-readRDS(configuration$statistics_cache_path)
truth<-read.csv('validation/autodesn/nonlinear_heteroscedastic/input/dgp_truth.csv',nrows=2500)
stopifnot(identical(truth$time,1:2500),isTRUE(all.equal(truth$y,b$history,tolerance=1e-13)))
scale<-b$preprocessing$scale;center<-b$preprocessing$center
conditional<-(truth$conditional_mean[b$keep_idx]-center)/scale
samples<-2048L;means<-matrix(NA_real_,b$n,4L*samples);chain_means<-matrix(NA_real_,b$n,4L)
counts<-integer(length(b$models));sources<-list();maximum_parity_error<-0
for(k in 1:4){
 path<-file.path(d,paste0('chain_',k,'.rds'));status<-jsonlite::fromJSON(file.path(d,paste0('chain_',k,'_status.json')))
 stopifnot(identical(digest::digest(file=path,algo='sha256'),status$checkpoint_sha256))
 f<-readRDS(path)$fit
 stopifnot(nrow(f$draws)==samples,length(f$beta)==samples,all(f$draws$period_index==1L),
   identical(f$controls$target_id,qualification$target_id),f$controls$rhs_control$tau0==.001,
   f$controls$rhs_control$slab_scale==1,f$controls$rhs_control$slab_df==4)
 for(ids in split(seq_len(samples),f$draws$model)){
  m<-f$draws$model[ids[1]];X<-cbind(1,b$extension$lag$X,b$models[[m]]$X[,-1L,drop=FALSE])
  B<-do.call(cbind,f$beta[ids]);stopifnot(nrow(B)==ncol(X))
  means[,(k-1L)*samples+ids]<-X%*%B;counts[m]<-counts[m]+length(ids)
 }
 chain_means[,k]<-rowMeans(means[,(k-1L)*samples+seq_len(samples),drop=FALSE])
 f$bank<-b;reference<-predict_mu.autodesn_extended_fit(f)
 maximum_parity_error<-max(maximum_parity_error,max(abs(reference-(center+scale*chain_means[,k]))))
 sources[[k]]<-list(path=path,sha256=status$checkpoint_sha256)
 rm(f);gc(FALSE)
}
stopifnot(all(is.finite(means)),sum(counts)==ncol(means),maximum_parity_error<1e-10)
post<-rowMeans(means);ols<-oracle_projection<-numeric(b$n);bounds<-list()
capacity<-read.csv(file.path(r,'evidence/representation_capacity.csv'));capacity<-capacity[capacity$space=='F1',]
for(m in which(counts>0L)){
 X<-cbind(1,b$extension$lag$X,b$models[[m]]$X[,-1L,drop=FALSE])
 s<-svd(X,nu=min(dim(X)),nv=0L);keep<-which(s$d>max(dim(X))*.Machine$double.eps*s$d[1]);U<-s$u[,keep,drop=FALSE]
 fitted<-as.vector(U%*%crossprod(U,b$y));privileged<-as.vector(U%*%crossprod(U,conditional))
 weight<-counts[m]/sum(counts);ols<-ols+weight*fitted;oracle_projection<-oracle_projection+weight*privileged
 error<-sqrt(mean((conditional-privileged)^2))*scale
 stopifnot(abs(error-capacity$conditional_mean_training_span_rmse[capacity$model==m])<1e-8)
 bounds[[length(bounds)+1L]]<-data.frame(model=m,stored_states=counts[m],snapshot_weight=weight,rank=length(keep),conditional_mean_span_rmse=error)
}
quantiles<-t(apply(means,1,quantile,probs=c(.05,.25,.75,.95),names=FALSE))
out<-data.frame(time=b$keep_idx,y=truth$y[b$keep_idx],conditional_mean=truth$conditional_mean[b$keep_idx],
 posterior_mean=center+scale*post,q05=center+scale*quantiles[,1],q25=center+scale*quantiles[,2],
 q75=center+scale*quantiles[,3],q95=center+scale*quantiles[,4],
 weighted_unpenalized_y_fit=center+scale*ols,weighted_privileged_projection=center+scale*oracle_projection)
for(k in 1:4)out[[paste0('chain_mean_',k)]]<-center+scale*chain_means[,k]
write.csv(out,file.path(r,'evidence',paste0('F1_',phase,'_training_function.csv')),row.names=FALSE)
write.csv(do.call(rbind,bounds),file.path(r,'evidence',paste0('F1_',phase,'_training_function_architectures.csv')),row.names=FALSE)
rmse<-function(x,y)sqrt(mean((x-y)^2))
metrics<-list(training_observed_rmse=rmse(out$posterior_mean,out$y),
 training_conditional_mean_rmse=rmse(out$posterior_mean,out$conditional_mean),
 realized_innovation_rmse=rmse(out$y,out$conditional_mean),
 weighted_unpenalized_fit_conditional_mean_rmse=rmse(out$weighted_unpenalized_y_fit,out$conditional_mean),
 weighted_privileged_projection_rmse=rmse(out$weighted_privileged_projection,out$conditional_mean),
 conditional_mean_correlation=cor(out$posterior_mean,out$conditional_mean),
 maximum_chain_mean_range=max(apply(chain_means,1,function(x)diff(range(x))))*scale,
 mean_pointwise_90_percent_latent_width=mean(out$q95-out$q05),
 descriptive_training_latent_coverage90=mean(out$conditional_mean>=out$q05&out$conditional_mean<=out$q95))
record<-list(complete=TRUE,phase=phase,chains=4L,stored_states_per_chain=samples,rows=c(501L,2500L),
 models_with_stored_states=sum(counts>0L),source_checkpoints=sources,metrics=metrics,
 public_predict_mu_maximum_error=maximum_parity_error,source_snapshot=snapshot,
 heldout_used=FALSE,new_random_draws_generated=FALSE,posterior_qualified=FALSE,forecast_allowed=FALSE,
 scope='Descriptive in-sample conditional means from8192 existing matching coefficient states. Latent bands omit observation noise. Unpenalized and privileged projections use the same finite-snapshot architecture weights and are optimistic training diagnostics, not predictive alternatives or new fits selected by test outcomes. Each occupied-model projection reproduces its independently audited span error. No architecture is removed from the sampler; finite saved states do not visit every supported model. This does not replace successive-budget or forecast qualification.')
jsonlite::write_json(record,file.path(r,'evidence',paste0('F1_',phase,'_training_function.json')),pretty=TRUE,auto_unbox=TRUE)
print(metrics)
