# Fixed-exogenous-design SBC only. No NHS1 outcome, hidden state or future data.
args<-commandArgs(TRUE);family<-if(length(args))args[1] else 'rhs';cases<-if(length(args)>1)as.integer(args[2]) else 200L
retained<-if(length(args)>2)as.integer(args[3]) else 3000L;burn<-if(retained==3000L)600L else as.integer(retained/4);stopifnot(family%in%c('ridge','rhs'),cases>=1L,retained>=3000L)
root<-'validation/autodesn/remediation';out<-file.path(root,'artifacts',paste0('sbc_',family,if(retained==3000L)'' else paste0('_',retained)));dir.create(out,recursive=TRUE,showWarnings=FALSE)
snapshot<-Sys.getenv('AUTODESN_SOURCE_SNAPSHOT',unset='.')
relative<-c(paste0('R/',list.files(file.path(snapshot,'R'),pattern='[.]R$')), 'src/autodesn_rhs.cpp','validation/autodesn/remediation/sbc.R')
paths<-file.path(snapshot,relative);sha<-setNames(vapply(paths,function(p)digest::digest(file=p,algo='sha256'),''),relative)
for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
Rcpp::sourceCpp(file.path(snapshot,'src/autodesn_rhs.cpp'),cacheDir=file.path(root,'artifacts/cpp'),showOutput=FALSE)
n<-8L;x<-seq(-1,1,length.out=n);features<-list(cbind(x),cbind(x,sin(2*x)));prior<-c(.4,.6);period<-list(periods=c(4,11),harmonics=2,prior=c(.3,.7));L<-127L
contract<-list(source_sha256=as.list(sha),family=family,replications=cases,n=n,retained=retained,warmup=burn,comparison_draws=L,scope='fixed_exogenous_design_SBC_not_response_adaptive_recursive_calibration')
id<-digest::digest(contract,algo='sha256');cp<-file.path(out,'contract.rds');if(file.exists(cp))stopifnot(identical(readRDS(cp)$id,id)) else saveRDS(list(id=id,contract=contract),cp)
base<-autodesn_prepare_bank(rep(0,n),features,model_prior=prior,normalize_features=FALSE,standardize_features=TRUE);template<-autodesn_extend_bank(base,seasonal_control=period)
for(r in seq_len(cases)) {
 path<-file.path(out,paste0('case_',r,'.rds'));if(file.exists(path)){stopifnot(identical(readRDS(path)$contract_id,id));next}
 set.seed(2666020L+r);m<-sample.int(2,1,prob=prior);p<-sample.int(2,1,prob=period$prior);d<-.ext_design(template,m,p);s2<-1/rgamma(1,3,rate=1)
 if(family=='rhs') {
  global<-abs(rcauchy(1));slab<-1/rgamma(1,2,rate=2);local<-abs(rcauchy(d$d));v<-1/(1/slab+1/(.2*global*local)^2)
 } else {ridge<-rgamma(1,2,rate=2);v<-rep(1/ridge,d$d)}
 B<-rnorm(ncol(d$X),sd=sqrt(c(10,v)));mu<-as.vector(d$X%*%B);y<-mu+rnorm(n,sd=sqrt(s2));true_ll<-sum(dnorm(y,mu,sqrt(s2),log=TRUE))
 bank<-autodesn_extend_bank(autodesn_prepare_bank(y,features,model_prior=prior,normalize_features=FALSE,standardize_features=TRUE),seasonal_control=period)
 a<-list(bank=bank,n_burn=burn,n_mcmc=retained,beta_prior=family,model_control=list(method='categorical',joint_moves=1,save_draws=512),seed=2866020L+r,backend='cpp')
 if(family=='rhs')a$rhs_control<-list(tau0=.2,slab_scale=1,slab_df=4,interweave_global=TRUE)
 fit<-do.call(autodesn_fit_bank,a);j<-as.integer(round(seq(1,nrow(fit$draws),length.out=L)));rows<-fit$draws[j,,drop=FALSE]
 means<-vapply(j,function(k)as.vector(.ext_design(bank,fit$draws$model[k],fit$draws$period_index[k])$X%*%fit$beta[[k]]),numeric(n))
 loglik<-vapply(seq_along(j),function(k)sum(dnorm(y,means[,k],sqrt(rows$variance[k]),log=TRUE)),0)
 continuous<-function(samples,truth)(sum(samples<truth)+runif(1))/(length(samples)+1)
 discrete<-function(samples,truth){z<-runif(1);rank<-sum(samples<truth|(samples==truth&runif(length(samples))<z));(rank+runif(1))/(length(samples)+1)}
 values<-c(variance=continuous(rows$variance,s2),fitted_mean=continuous(means[4,],mu[4]),joint_likelihood=continuous(loglik,true_ll),architecture=discrete(rows$model,m),period=discrete(rows$period_index,p))
 if(family=='rhs')values<-c(values,global=continuous(rows$log_global_1,log(global)),slab=continuous(rows$log_slab,log(slab))) else values<-c(values,ridge=continuous(rows$ridge_precision,ridge))
 fields<-c('variance','intercept',if(family=='rhs')c('log_global_1','log_slab') else 'ridge_precision')
 ess<-vapply(fields,function(field).autodesn_ess(list(fit$trace[[field]])),0)
 record<-list(contract_id=id,case=r,u=values,ess=ess,target_id=fit$controls$target_id,computation=fit$computation)
 tmp<-paste0(path,'.writing');saveRDS(record,tmp);stopifnot(file.rename(tmp,path))
 if(r%%10==0){cat(family,'SBC cases',r,'of',cases,'\n');flush.console()}
}
records<-lapply(seq_len(cases),function(r)readRDS(file.path(out,paste0('case_',r,'.rds'))));U<-do.call(rbind,lapply(records,`[[`,'u'));ESS<-do.call(rbind,lapply(records,`[[`,'ess'))
write.csv(U,file.path(out,'ranks.csv'),row.names=FALSE);write.csv(ESS,file.path(out,'ess.csv'),row.names=FALSE)
D<-apply(U,2,function(v){s<-sort(v);max(seq_along(s)/length(s)-s,s-(seq_along(s)-1)/length(s))});bound<-sqrt(log(2*ncol(U)/.01)/(2*cases))
result<-list(complete=TRUE,family=family,replications=cases,contract_id=id,scope=contract$scope,maximum_uniform_ecdf_deviation=max(D),simultaneous_DKW_bound=bound,uniformity_envelope_passed=all(D<=bound),minimum_case_spectral_ess=min(ESS),cases_below_400_ess=sum(apply(ESS,1,min)<400),computational_calibration_resolved=all(D<=bound)&&all(ESS>=400),posterior_production_qualified=FALSE,source_sha256=as.list(sha))
jsonlite::write_json(result,file.path(root,'evidence',paste0('sbc_',family,if(retained==3000L)'' else paste0('_',retained),'.json')),pretty=TRUE,auto_unbox=TRUE);print(result[c('complete','replications','uniformity_envelope_passed','minimum_case_spectral_ess','cases_below_400_ess','computational_calibration_resolved')])
