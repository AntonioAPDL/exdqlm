# Learned-local grouped RHS reference with a deliberately non-prior proposal.
root<-'validation/autodesn/remediation';snapshot<-Sys.getenv('AUTODESN_SOURCE_SNAPSHOT');stopifnot(nzchar(snapshot))
for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
Rcpp::sourceCpp(file.path(snapshot,'src/autodesn_rhs.cpp'),cacheDir=file.path(root,'artifacts/cpp'),showOutput=FALSE)
y<-c(.1,.5,-.3,.2,.4,-.1);x<-seq(-1,1,length.out=6)
b<-autodesn_prepare_bank(y,list(matrix(x),cbind(x,x*x)),model_prior=c(.4,.6),normalize_features=FALSE,standardize_features=TRUE)
b$keep_idx<-3:8;b$history<-b$history_scaled<-c(-.1,.2,y)
e<-autodesn_extend_bank(b,list(lags=1,prior='grouped'),list(periods=c(12,18),harmonics=1,prior=c(.3,.7)))
fixture<-list(y=y,model_prior=e$prior,period_prior=e$extension$period_prior,designs=list(),tau0=.2,intercept_variance=10,calendar_variance=.5^2/(1+(1/4)^4))
for(p in 1:2)for(m in 1:2){d<-.ext_design(e,m,p);fixture$designs[[length(fixture$designs)+1]]<-list(model=m,period_index=p,X=d$X,groups=c('intercept',d$groups),slots=c(0L,d$slots))}
jsonlite::write_json(fixture,file.path(root,'artifacts/local_reference_fixture.json'),pretty=TRUE,auto_unbox=TRUE,digits=NA)
proposal<-autodesn_extended_local_proposal(list(matrix(c(-1,0,1),3,1),matrix(c(-.6,.1,1.3,.1,.6,1.2),3,2)),list(.6,c(.7,.5)),slope=list(-.3,c(-.5,-.2)),reference_log_global=.5,weight=.75,bank_id=e$extension$id)
out<-file.path(root,'artifacts/local_reference');dir.create(out,recursive=TRUE,showWarnings=FALSE)
for(k in 1:4){
 path<-file.path(out,paste0('chain_',k,'.rds'));stopifnot(!file.exists(path))
 f<-autodesn_fit_bank(e,n_burn=3000,n_mcmc=24000,beta_prior='rhs',rhs_control=list(tau0=.2,slab_scale=1,slab_df=4,initial_global=c(.1,1,10,100)[k],interweave_global=TRUE),model_control=list(method='categorical',joint_moves=2,joint_scale_sd=.8,local_proposal=proposal,local_moves=2,proposal=c(.7,.3),period_proposal=c(.8,.2),save_draws=512,initial_model=c(1,2,1,2)[k],initial_period=c(1,1,2,2)[k]),initial_variance=c(.1,.5,1,4)[k],seed=9566100+k,backend='cpp')
 f$bank<-NULL;saveRDS(f,path);tr<-f$trace;tr$fitted_mean_4<-f$probes[,4]
 write.csv(tr,file.path(out,paste0('trace_',k,'.csv')),row.names=FALSE);cat('Learned-local reference chain',k,'complete\n');flush.console()
}
jsonlite::write_json(list(complete=TRUE,chains=4,warmup=3000,retained=24000,scope='Conditional learned-local grouped RHS and exact active-vector local-scale independence moves; not recursive SBC or production convergence'),file.path(out,'status.json'),pretty=TRUE,auto_unbox=TRUE)
