# Prior calibration under an explicitly independent, frozen causal feature map.
# This is not unconditional SBC of response-adaptive production preprocessing.
args<-commandArgs(TRUE);stopifnot(length(args)==4L)
cases<-as.integer(args[1]);retained<-as.integer(args[2]);sv<-identical(args[3],'sv');workers<-as.integer(args[4])
stopifnot(cases>=1L,retained>=3000L,args[3]%in%c('constant','sv'),workers%in%c(1L,2L));burn<-as.integer(retained/4)
root<-'validation/autodesn/remediation';snapshot<-Sys.getenv('AUTODESN_SOURCE_SNAPSHOT');stopifnot(nzchar(snapshot))
for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
Rcpp::sourceCpp(file.path(snapshot,'src/autodesn_rhs.cpp'),cacheDir=file.path(root,'artifacts/cpp'),showOutput=FALSE)
label<-paste0('recursive_sbc_',args[3],'_n',cases,'_k',retained);out<-file.path(root,'artifacts',label);dir.create(out,recursive=TRUE,showWarnings=FALSE)
source_paths<-c(list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE),file.path(snapshot,'src/autodesn_rhs.cpp'),file.path(snapshot,'validation/autodesn/remediation/recursive_sbc.R'))
source_sha<-setNames(vapply(source_paths,function(p)digest::digest(file=p,algo='sha256'),''),substring(source_paths,nchar(snapshot)+2L))
set.seed(6166020);prefix<-as.numeric(stats::filter(rnorm(64),.3,method='recursive'))
specs<-list(a=list(D=1L,n=3L,n_tilde=integer(),m=2L,alpha=.4,rho=.5,seed=31L,washout=12L,pi_in=1,pi_w=1),b=list(D=2L,n=c(4L,3L),n_tilde=2L,m=3L,alpha=c(.4,.6),rho=c(.5,.6),seed=39L,washout=12L,pi_in=1,pi_w=1))
raw<-autodesn_build_bank(prefix,specs,conditioning=8L,washout=12L,standardize_features=TRUE,normalize_features=FALSE,model_prior=c(.4,.6))
map<-autodesn_extend_bank(raw,list(lags=1:2),list(periods=c(4,11),harmonics=2,prior=c(.3,.7)))
# Hash only the actual frozen map, excluding unused construction closures and
# package/Git display metadata that can change between resumptions.
map_id<-digest::digest(list(conditional_bank_id=map$extension$id,forecast_map_id=map$extension$forecast_map_id,lag_geometry=map$extension$lag,calendar_geometry=map$extension$calendar,reservoir_geometry=lapply(map$models,function(x)x[c('raw_d','feature_center','feature_scale','active_features')]),prefix=prefix),algo='sha256')
n<-8L;times<-length(prefix)+seq_len(n);tau0<-.2;L<-127L;seed_offset<-if(sv)200000L else 0L
contract<-list(source_sha256=as.list(source_sha),map_id=map_id,replications=cases,retained=retained,warmup=burn,n=n,tau0=tau0,slab_scale=1,slab_df=4,intercept_variance=10,noise_IG=c(3,1),variance=if(sv)'sv' else 'constant',comparison_draws=L,seeds=list(prefix=6166020L,truth_base=6266020L+seed_offset,posterior_base=6366020L+seed_offset),scope='Recursive-model SBC conditional on an independent calibration prefix and frozen weights/projections/readout/input/response geometry; not response-adaptive production-pipeline calibration')
id<-digest::digest(contract,algo='sha256');cp<-file.path(out,'contract.rds');if(file.exists(cp))stopifnot(identical(readRDS(cp)$id,id)) else saveRDS(list(id=id,contract=contract),cp)
jsonlite::write_json(contract,file.path(out,'configuration.json'),pretty=TRUE,auto_unbox=TRUE)
apply_geometry<-function(g,x){if(!length(g$active))return(matrix(numeric(),nrow(x),0));sweep(sweep(x[,g$active,drop=FALSE],2,g$center[g$active],'-'),2,g$scale[g$active],'/')}
res_geometry<-lapply(map$models,function(x)list(active=x$active_features,center=x$feature_center,scale=x$feature_scale))
engines<-lapply(map$templates,.normal_desn_transition_engine)
row_for<-function(m,p,t,hist,res){
 lag<-matrix(hist[t-1:2],1);cal<-.ext_fourier(t,map$extension$periods[p],2L)
 c(1,as.vector(apply_geometry(map$extension$lag,lag)),as.vector(apply_geometry(res_geometry[[m]],matrix(res,1))),as.vector(apply_geometry(map$extension$calendar[[p]],cal)))
}
run_case<-function(r){
 path<-file.path(out,paste0('case_',r,'.rds'));if(file.exists(path)){z<-readRDS(path);stopifnot(identical(z$contract_id,id));return(TRUE)}
 set.seed(6266020L+seed_offset+r);m<-sample.int(2L,1L,prob=map$prior);p<-sample.int(2L,1L,prob=map$extension$period_prior)
 dim<-1L+ncol(map$extension$lag$X)+map$models[[m]]$d+ncol(map$extension$calendar[[p]]$X)
 global<-abs(rcauchy(1));slab<-1/rgamma(1,2,rate=2);local<-abs(rcauchy(dim-1L));v<-1/(1/slab+1/(tau0*global*local)^2)
 B<-rnorm(dim,sd=sqrt(c(10,v)));s2<-1/rgamma(1,3,rate=1)
 phi<-if(sv)2*rbeta(1,10,1.5)-1 else .8;omega<-if(sv)abs(rnorm(1,sd=.5)) else 0
 u<-rnorm(n);if(sv)for(t in 2:n)u[t]<-phi*u[t-1]+sqrt(1-phi^2)*u[t]
 innovation<-rnorm(n);hist<-raw$history_scaled;states<-lapply(raw$templates,.ext_template_initial)
 R<-lapply(raw$models,function(x)matrix(0,n,x$raw_d));means<-numeric(n);ys<-numeric(n)
 for(j in seq_len(n)){
  for(a in 1:2){next_state<-engines[[a]]$step(states[[a]],engines[[a]]$input(hist));states[[a]]<-lapply(next_state$h,as.numeric);R[[a]][j,]<-next_state$x[-1L]}
  means[j]<-sum(row_for(m,p,times[j],hist,R[[m]][j,])*B);ys[j]<-means[j]+sqrt(s2)*exp(omega*u[j]/2)*innovation[j];hist<-c(hist,ys[j])
 }
 stopifnot(all(is.finite(hist)))
 # Freeze every scaler from the independent prefix; never standardize on ys.
 features<-lapply(1:2,function(a)apply_geometry(res_geometry[[a]],R[[a]]))
 bank<-autodesn_prepare_bank(ys,features,model_prior=map$prior,model_info=map$model_info,normalize_features=FALSE,standardize_features=FALSE)
 fields<-c('raw_d','feature_center','feature_scale','active_features','dropped_features','standardize_features','feature_sd_tol','readout_scale_info')
 for(a in 1:2)bank$models[[a]][fields]<-map$models[[a]][fields]
 bank$standardize_features<-TRUE;bank$feature_sd_tol<-raw$feature_sd_tol;bank$history_scaled<-hist;bank$history<-raw$preprocessing$center+raw$preprocessing$scale*hist;bank$preprocessing<-raw$preprocessing;bank$keep_idx<-times
 bank$templates<-raw$templates;for(a in 1:2)bank$templates[[a]]$states<-list(H_last=states[[a]])
 bank<-autodesn_extend_bank(bank,list(lags=1:2),list(periods=c(4,11),harmonics=2,prior=c(.3,.7)))
 lag<-vapply(1:2,function(k)hist[times-k],numeric(n));bank$extension$lag<-map$extension$lag;bank$extension$lag$X<-apply_geometry(map$extension$lag,lag)
 bank$extension$calendar<-lapply(1:2,function(b){g<-map$extension$calendar[[b]];g$X<-apply_geometry(g,.ext_fourier(times,map$extension$periods[b],2L));g})
 bank$extension$id<-digest::digest(list(scope='independent_prefix_recursive_map_v1',map_id=map_id,y=ys,reservoir_X=lapply(bank$models,`[[`,'X'),lag=bank$extension$lag,calendar=bank$extension$calendar),algo='sha256');bank$extension$forecast_map_id<-.ext_forecast_map_id(bank)
 independent<-vapply(seq_len(n),function(j)sum(row_for(m,p,times[j],hist[seq_len(times[j]-1L)],R[[m]][j,])*B),0)
 stopifnot(isTRUE(all.equal(independent,means,tolerance=1e-13)),isTRUE(all.equal(as.vector(.ext_design(bank,m,p)$X%*%B),means,tolerance=1e-13)))
 a<-list(bank=bank,n_burn=burn,n_mcmc=retained,beta_prior='rhs',rhs_control=list(tau0=tau0,slab_scale=1,slab_df=4,interweave_global=TRUE),model_control=list(method='categorical',joint_moves=1,save_draws=512),seed=6366020L+seed_offset+r,backend='cpp',variance_control=if(sv)list(type='sv',save_state_paths=TRUE) else NULL)
 fit<-do.call(autodesn_fit_bank,a);ids<-as.integer(round(seq(1,nrow(fit$draws),length.out=L)));rows<-fit$draws[ids,,drop=FALSE]
 mu<-vapply(ids,function(k)as.vector(.ext_design(bank,fit$draws$model[k],fit$draws$period_index[k])$X%*%fit$beta[[k]]),numeric(n))
 loglik<-vapply(seq_along(ids),function(j){k<-ids[j];lv<-log(rows$variance[j])+if(sv)rows$omega[j]*fit$volatility[[k]]$path else 0;sum(dnorm(ys,mu[,j],exp(lv/2),log=TRUE))},0)
 true_ll<-sum(dnorm(ys,means,sqrt(s2)*exp(omega*u/2),log=TRUE))
 continuous<-function(samples,truth)(sum(samples<truth)+runif(1))/(length(samples)+1)
 discrete<-function(samples,truth){z<-runif(1);(sum(samples<truth|(samples==truth&runif(length(samples))<z))+runif(1))/(length(samples)+1)}
 ranks<-c(variance=continuous(rows$variance,s2),fitted_mean=continuous(mu[4,],means[4]),joint_likelihood=continuous(loglik,true_ll),architecture=discrete(rows$model,m),period=discrete(rows$period_index,p),global=continuous(rows$log_global_1,log(global)),slab=continuous(rows$log_slab,log(slab)))
 if(sv)ranks<-c(ranks,phi=continuous(rows$phi,phi),omega=continuous(rows$omega,omega),terminal_log_variance=continuous(rows$terminal_log_variance,log(s2)+omega*u[n]))
 monitor<-c('variance','intercept','log_global_1','log_slab','log_likelihood','fitted_rms',if(sv)c('phi','omega','volatility_rms','terminal_log_variance'))
 ess<-vapply(monitor,function(field).autodesn_ess(list(fit$trace[[field]])),0)
 record<-list(contract_id=id,case=r,u=ranks,ess=ess,target_id=fit$controls$target_id,computation=fit$computation,truth=list(model=m,period=p,variance=s2,global=global,slab=slab,phi=phi,omega=omega),frozen_geometry_verified=TRUE,causal_design_reconstruction_verified=TRUE)
 temporary<-paste0(path,'.writing');saveRDS(record,temporary);stopifnot(file.rename(temporary,path))
 if(r%%10L==0L){cat('Recursive',args[3],'SBC completed checkpoints',length(list.files(out,pattern='^case_[0-9]+[.]rds$')),'of',cases,'\n');flush.console()}
 TRUE
}
case_set<-Sys.getenv('AUTODESN_RECURSIVE_CASE_SET',unset='')
selected<-if(nzchar(case_set))as.integer(strsplit(case_set,',',fixed=TRUE)[[1]]) else seq_len(cases)
stopifnot(length(selected)>0L,!anyNA(selected),!anyDuplicated(selected),all(selected%in%seq_len(cases)))
completed<-parallel::mclapply(selected,run_case,mc.cores=workers,mc.set.seed=FALSE)
stopifnot(all(vapply(completed,isTRUE,TRUE)))
present<-file.exists(file.path(out,paste0('case_',seq_len(cases),'.rds')))
if(!all(present)){jsonlite::write_json(list(complete=FALSE,completed_cases=which(present),requested_cases=cases,contract_id=id,scope=contract$scope,computational_calibration_resolved=FALSE),file.path(out,'partial_status.json'),pretty=TRUE,auto_unbox=TRUE);cat('Requested case subset complete; full calibration remains incomplete\n');quit(status=0)}
records<-lapply(seq_len(cases),function(r)readRDS(file.path(out,paste0('case_',r,'.rds'))));U<-do.call(rbind,lapply(records,`[[`,'u'));ESS<-do.call(rbind,lapply(records,`[[`,'ess'))
write.csv(U,file.path(out,'ranks.csv'),row.names=FALSE);write.csv(ESS,file.path(out,'ess.csv'),row.names=FALSE)
D<-apply(U,2,function(v){s<-sort(v);max(seq_along(s)/length(s)-s,s-(seq_along(s)-1)/length(s))});bound<-sqrt(log(2*ncol(U)/.01)/(2*cases))
result<-list(complete=TRUE,replications=cases,retained=retained,warmup=burn,variance=if(sv)'sv' else 'constant',contract_id=id,map_id=map_id,scope=contract$scope,maximum_uniform_ecdf_deviation=max(D),simultaneous_DKW_bound=bound,uniformity_envelope_passed=all(D<=bound),minimum_case_spectral_ess=min(ESS),cases_below_400_ess=sum(apply(ESS,1,min)<400),computational_calibration_resolved=cases>=200L&&all(D<=bound)&&all(ESS>=400),posterior_production_qualified=FALSE)
jsonlite::write_json(result,file.path(root,'evidence',paste0(label,'.json')),pretty=TRUE,auto_unbox=TRUE);print(result)
