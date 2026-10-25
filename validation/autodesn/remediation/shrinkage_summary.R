# Descriptive saved-joint-state shrinkage audit; not posterior qualification.
args<-commandArgs(TRUE);stopifnot(length(args)==1L);phase<-args[1];root<-'validation/autodesn/remediation';d<-file.path(root,'artifacts/F1',phase)
config<-jsonlite::fromJSON(file.path(d,'configuration.json'));sd_y<-config$training_response_sd;stopifnot(is.finite(sd_y),sd_y>0)
rows<-list();at<-0L;sources<-list()
for(chain in 1:4){
 path<-file.path(d,paste0('chain_',chain,'.rds'));f<-readRDS(path)$fit
 stopifnot(f$meta$beta_prior_type=='independent_rhs',f$meta$period_policy=='none',nrow(f$draws)==length(f$beta),length(f$local)==length(f$beta))
 for(k in seq_along(f$beta)){
  B<-f$beta[[k]][-1];ell<-f$local[[k]];stopifnot(length(B)==length(ell),length(B)>=90L)
  a<--f$draws$log_slab[k];b<--2*(log(.001)+f$draws$log_global_1[k]+ell)
  logv<--pmax(a,b)-log1p(exp(-abs(a-b)));stopifnot(all(is.finite(logv)),all(logv<=f$draws$log_slab[k]+1e-12))
  at<-at+1L;rows[[at]]<-data.frame(chain=chain,iteration=f$draws$iteration[k],model=f$draws$model[k],slopes=length(B),lag_norm=sqrt(sum(B[1:90]^2))/sd_y,reservoir_norm=sqrt(sum(B[-(1:90)]^2))/sd_y,fraction_below_001_sd=mean(abs(B)<.01*sd_y),number_above_01_sd=sum(abs(B)>.1*sd_y),median_conditional_prior_sd=exp(median(logv)/2)/sd_y,actual_tau=.001*exp(f$draws$log_global_1[k]),slab_sd=exp(f$draws$log_slab[k]/2))
 }
 sources[[chain]]<-list(path=path,sha256=digest::digest(file=path,algo='sha256'));rm(f);gc(FALSE)
}
table<-do.call(rbind,rows);write.csv(table,file.path(root,'evidence',paste0('F1_',phase,'_shrinkage_draws.csv')),row.names=FALSE)
fields<-setdiff(names(table),c('chain','iteration','model'));summary<-lapply(fields,function(field){v<-table[[field]];list(quantity=field,q05=unname(quantile(v,.05)),median=median(v),q95=unname(quantile(v,.95)))} )
record<-list(complete=TRUE,phase=phase,joint_states=nrow(table),training_response_sd=sd_y,summary=summary,source_checkpoints=sources,posterior_qualified=FALSE,scope='Descriptive joint-draw quantities on an unqualified F1 run; coefficients are standardized-feature effects divided by training-response SD. Thresholds and norms are not variable selection or a function-space capacity measure; correlated bases and changing readout dimensions matter.')
jsonlite::write_json(record,file.path(root,'evidence',paste0('F1_',phase,'_shrinkage.json')),pretty=TRUE,auto_unbox=TRUE);print(do.call(rbind,lapply(summary,as.data.frame)))
