# Full public Gibbs sampler on the independently integrated two-response target.
root<-'validation/autodesn/remediation';snapshot<-Sys.getenv('AUTODESN_SOURCE_SNAPSHOT',unset='.')
for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
Rcpp::sourceCpp(file.path(snapshot,'src/autodesn_rhs.cpp'),cacheDir=file.path(root,'artifacts/cpp'),showOutput=FALSE)
source_identity<-digest::digest(file=file.path(snapshot,'manifest.json'),algo='sha256')
out<-file.path(root,'artifacts/sv_joint_reference');dir.create(out,recursive=TRUE,showWarnings=FALSE)
y<-c(.2,1.1);b<-autodesn_prepare_bank(y,list(matrix(0,2,1)),normalize_features=FALSE,standardize_features=TRUE);e<-autodesn_extend_bank(b)
for(k in 1:4) {
 path<-file.path(out,paste0('chain_',k,'.rds'))
 if(file.exists(path)){f<-readRDS(path);stopifnot(identical(f$validation_source_identity,source_identity))} else {
 f<-autodesn_fit_bank(e,n_burn=2000,n_mcmc=16000,beta_prior='ridge',model_control=list(moves=0,joint_moves=0,save_draws=2048),variance_control=list(type='sv',initial_phi=c(.1,.5,.8,.95)[k],initial_omega=c(.1,.2,.4,.8)[k],save_state_paths=TRUE),initial_variance=c(.1,.5,1,4)[k],seed=8466100+k,backend='cpp')
 f$bank<-NULL;f$validation_source_identity<-source_identity;saveRDS(f,path)
 }
 write.csv(f$trace,file.path(out,paste0('trace_',k,'.csv')),row.names=FALSE)
 dr<-f$draws;u<-do.call(rbind,lapply(f$volatility,`[[`,'path'));eta<-u*dr$omega
 s<-data.frame(variance=dr$variance,log_variance=log(dr$variance),intercept=dr$intercept,intercept_squared=dr$intercept^2,phi=dr$phi,omega=dr$omega,omega_squared=dr$omega^2,u1=u[,1],u2=u[,2],u1_u2=u[,1]*u[,2],eta1=eta[,1],eta2=eta[,2],log_likelihood=vapply(seq_len(nrow(dr)),function(i)sum(dnorm(y,dr$intercept[i],sqrt(dr$variance[i]*exp(eta[i,])),log=TRUE)),0))
 write.csv(s,file.path(out,paste0('joint_',k,'.csv')),row.names=FALSE);cat('SV reference chain',k,'complete\n');flush.console()
}
jsonlite::write_json(list(complete=TRUE,chains=4,retained=16000,warmup=2000,snapshots=2048,scope='Two-response full SV reference, not production posterior qualification'),file.path(out,'status.json'),pretty=TRUE,auto_unbox=TRUE)
