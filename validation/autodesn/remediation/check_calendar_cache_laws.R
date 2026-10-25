# Diagnose the failed full-bank path check at its original immutable sources.
r<-'validation/autodesn/remediation';snapshot<-file.path(r,'artifacts/calendar_cache_sources/af348cd9eca2248ad4800cf01d18fb0dfba809feac66640f8ec2647e30e996d4')
for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
Rcpp::sourceCpp(file.path(snapshot,'src/autodesn_rhs.cpp'),cacheDir=file.path(r,'artifacts/cpp'),showOutput=FALSE)
manifest<-jsonlite::fromJSON(file.path(r,'artifacts/inference_cache_manifest.json'));stopifnot(identical(digest::digest(file=manifest$path,algo='sha256'),manifest$sha256))
b<-readRDS(manifest$path);b$extension<-readRDS(manifest$extensions$F2$path);class(b)<-c('autodesn_extended_bank',class(b))
directory<-file.path(r,'artifacts/calendar_cache_benchmark');s<-b;s$extension$statistics_cache<-readRDS(file.path(directory,'blocks.rds'))
stopifnot(identical(s$extension$statistics_cache$bank_id,b$extension$id))
f<-readRDS(file.path(directory,'fit_1_direct.rds'));other<-readRDS(file.path(directory,'fit_1_blocks.rds'))
rows<-list()
check<-function(m,p,ell,logu,logc2,variance,label,dense=FALSE){
 a<-.ext_design(b,m,p);z<-.ext_design(s,m,p);lv<-.ext_logv(a,ell,logu,logc2,rep(.001,2),'rhs',1,10)
 g<-autodesn_rhs_gaussian_cpp(a$XtX,a$Xty,sum(b$y^2),variance,lv,a$X,b$y)
 h<-autodesn_rhs_gaussian_cpp(z$XtX,z$Xty,sum(b$y^2),variance,lv,z$X,b$y)
 # Whitened precision comparison gives a coordinate-invariant Gaussian KL.
 T<-h$chol%*%backsolve(g$chol,diag(ncol(a$X)))
 delta<-eigen(crossprod(T)-diag(ncol(T)),symmetric=TRUE,only.values=TRUE)$values
 dm<-(g$mean-h$mean)/g$sqrt_prior
 kl<-max(0,sum(delta-log1p(delta)))/2+sum((h$chol%*%dm)^2)/2
 prediction_error<-max(abs(a$X%*%(g$mean-h$mean)))
 dense_error<-NA_real_
 if(dense){
  C<-variance*diag(b$n)+tcrossprod(sweep(a$X,2,exp(lv/2),'*'));L<-chol(C);w<-forwardsolve(t(L),b$y)
  reference<--b$n/2*log(2*pi)-sum(log(diag(L)))-sum(w^2)/2
  dense_error<-max(abs(c(g$log_evidence,h$log_evidence)-reference))
 }
 stopifnot(kl<=1e-14,abs(g$log_evidence-h$log_evidence)<=1e-8,prediction_error<=1e-8*sd(b$y),is.na(dense_error)||dense_error<=1e-8)
 rows[[length(rows)+1L]]<<-data.frame(label=label,model=m,period_index=p,dimension=ncol(a$X),log_evidence_error=abs(g$log_evidence-h$log_evidence),gaussian_KL=kl,maximum_fitted_mean_error=prediction_error,dense_response_log_evidence_error=dense_error)
}
for(k in seq_len(nrow(f$draws)))check(f$draws$model[k],f$draws$period_index[k],f$local[[k]],c(f$draws$log_global_1[k],f$draws$log_global_2[k]),f$draws$log_slab[k],f$draws$variance[k],paste0('saved_',k))
m<-which.max(vapply(b$models,`[[`,0L,'d'))
for(p in c(1L,51L,101L))for(tau in c(.001,1))check(m,p,rep(0,b$extension$dimension),rep(log(tau/.001),2),log(4),.23,paste0('maximum_dimension_tau',tau),dense=p==1L)
table<-do.call(rbind,rows);write.csv(table,file.path(r,'evidence/calendar_cache_law_checks.csv'),row.names=FALSE)
differences<-lapply(c('trace','draws','beta','local','probes'),function(n){a<-unlist(f[[n]]);z<-unlist(other[[n]]);list(field=n,maximum_absolute_error=max(abs(a-z)),mean_absolute_error=mean(abs(a-z)))})
record<-list(complete=TRUE,checks=nrow(table),maximum_log_evidence_error=max(table$log_evidence_error),maximum_gaussian_KL=max(table$gaussian_KL),maximum_fitted_mean_error=max(table$maximum_fitted_mean_error),maximum_dense_response_log_evidence_error=max(table$dense_response_log_evidence_error,na.rm=TRUE),original_strict_path_check_passed=FALSE,model_period_sequences_identical=identical(f$draws$model,other$draws$model)&&identical(f$draws$period_index,other$draws$period_index),path_differences=differences,source_snapshot=basename(snapshot),posterior_qualified=FALSE,scope='Same-hyperparameter Gaussian laws and independent dense response-space evidence at32 saved states and six maximum-dimension stress cases. The first path check remains failed at its original relative tolerance; a cache may reorder floating-point sums without a bit-identical Markov trajectory.')
jsonlite::write_json(record,file.path(r,'evidence/calendar_cache_law_checks.json'),pretty=TRUE,auto_unbox=TRUE,digits=16)
print(record)
