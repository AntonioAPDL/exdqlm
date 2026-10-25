# Production prior controls on the independently integrated six-response target.
# Same7D reference construction; conditional check, not production convergence.
# Independent seven-dimensional target, now with scale/local/model joint moves.
args<-commandArgs(TRUE);stopifnot(length(args)==1L,args[1]%in%c('fixture','mcmc'))
root<-'validation/autodesn/remediation';snapshot<-Sys.getenv('AUTODESN_SOURCE_SNAPSHOT');stopifnot(nzchar(snapshot))
for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
Rcpp::sourceCpp(file.path(snapshot,'src/autodesn_rhs.cpp'),cacheDir=file.path(root,'artifacts/cpp'),showOutput=FALSE)
y<-c(.1,.5,-.3,.2,.4,-.1);x<-seq(-1,1,length.out=6)
b<-autodesn_prepare_bank(y,list(matrix(x),cbind(x,x*x)),model_prior=c(.4,.6),normalize_features=FALSE,standardize_features=TRUE)
b$keep_idx<-3:8;b$history<-b$history_scaled<-c(-.1,.2,y)
e<-autodesn_extend_bank(b,list(lags=1,prior='grouped'),list(periods=c(12,18),harmonics=1,prior=c(.3,.7)))
fixture<-list(y=y,model_prior=e$prior,period_prior=e$extension$period_prior,designs=list(),tau0=.001,intercept_variance=10,calendar_variance=.5^2/(1+(1/4)^4))
for(p in 1:2)for(m in 1:2){d<-.ext_design(e,m,p);fixture$designs[[length(fixture$designs)+1]]<-list(model=m,period_index=p,X=d$X,groups=c('intercept',d$groups),slots=c(0L,d$slots))}
fixture_path<-file.path(root,'artifacts/production_scale_reference_fixture.json');jsonlite::write_json(fixture,fixture_path,pretty=TRUE,auto_unbox=TRUE,digits=NA)
if(args[1]=='fixture')quit(status=0)
reference<-jsonlite::fromJSON(file.path(root,'evidence/production_scale_prior_integration.json'))
stopifnot(identical(digest::digest(file=fixture_path,algo='sha256'),reference$fixture_sha256))
proposal<-autodesn_extended_local_proposal(list(matrix(c(-1,0,1),3,1),matrix(c(-.6,.1,1.3,.1,.6,1.2),3,2)),list(.6,c(.7,.5)),slope=list(-.3,c(-.5,-.2)),reference_log_global=.5,weight=.75,bank_id=e$extension$id)
z<-c(log(.33),0,0,.2);C<-diag(c(.45,1.8,1.8,.8)^2);joint<-autodesn_extended_proposal(matrix(rep(z,each=2),2,4),C,wide_center=z,wide_scale=9*C)
out<-file.path(root,'artifacts/production_scale_reference');dir.create(out,recursive=TRUE,showWarnings=FALSE)
contract<-list(source_manifest_sha256=digest::digest(file=file.path(snapshot,'manifest.json'),algo='sha256'),fixture_sha256=digest::digest(file=fixture_path,algo='sha256'),prior=list(tau0=.001,slab_scale=1,slab_df=4),warmup=3000L,retained=24000L,seeds=9156021:9156024)
contract_id<-digest::digest(contract,algo='sha256');contract_path<-file.path(out,'contract.rds')
if(file.exists(contract_path))stopifnot(identical(readRDS(contract_path)$id,contract_id)) else saveRDS(list(id=contract_id,contract=contract),contract_path)
for(k in 1:4){
 path<-file.path(out,paste0('chain_',k,'.rds'))
 if(file.exists(path)){old<-readRDS(path);stopifnot(old$controls$rhs_control$tau0==.001,old$controls$n_mcmc==24000L,old$controls$seed==9156020+k);tr<-old$trace;tr$fitted_mean_4<-old$probes[,4];write.csv(tr,file.path(out,paste0('trace_',k,'.csv')),row.names=FALSE);next}
 f<-autodesn_fit_bank(e,n_burn=3000,n_mcmc=24000,beta_prior='rhs',rhs_control=list(tau0=.001,slab_scale=1,slab_df=4,initial_global=c(.1,1,10,100)[k],interweave_global=TRUE),model_control=list(method='categorical',joint_moves=2,joint_proposal=joint,local_proposal=proposal,local_moves=2,local_scale_proposal=TRUE,proposal=c(.7,.3),period_proposal=c(.8,.2),save_draws=512,initial_model=c(1,2,1,2)[k],initial_period=c(1,1,2,2)[k]),initial_variance=c(.1,.5,1,4)[k],seed=9156020+k,backend='cpp',checkpoint_control=list(path=file.path(out,paste0('progress_',k,'.rds')),every=4000L,resume=file.exists(file.path(out,paste0('progress_',k,'.rds'))),source_id=digest::digest(file=file.path(snapshot,'src/autodesn_rhs.cpp'),algo='sha256')))
 stopifnot(f$controls$rhs_control$tau0==.001,f$controls$rhs_control$slab_scale==1,f$controls$rhs_control$slab_df==4)
 f$bank<-NULL;temporary<-paste0(path,'.writing');saveRDS(f,temporary);stopifnot(file.rename(temporary,path));tr<-f$trace;tr$fitted_mean_4<-f$probes[,4];write.csv(tr,file.path(out,paste0('trace_',k,'.csv')),row.names=FALSE)
 cat('Joint scale/local reference chain',k,'complete\n');flush.console()
}
jsonlite::write_json(list(complete=TRUE,chains=4,warmup=3000,retained=24000,prior_controls=list(tau0=.001,slab_scale=1,slab_df=4),fixture_sha256=digest::digest(file=fixture_path,algo='sha256'),scope='Learned-local grouped RHS with frozen exact joint noise/global/slab/reservoir-local/model proposals; same seven-dimensional reference target; not recursive calibration or production qualification'),file.path(out,'status.json'),pretty=TRUE,auto_unbox=TRUE)
