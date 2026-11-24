source('validation/autodesn/median_small/common.R');ms_load(TRUE)
checks<-0L;check<-function(x,label){if(!isTRUE(x))stop(label);checks<<-checks+1L;cat('PASS',label,'\n')}
cfg<-ms_config();check(length(cfg$val_origins)==10L,'ten validation origins')
check(length(unique(unlist(lapply(cfg$test_origins,function(o)o+1:60))))==600L,'600 unique test targets')
check(identical(sort(unlist(lapply(cfg$test_origins,function(o)o+1:60))),2901:3500),'test exact coverage')
check(all(cfg$val_origins+60<=2900)&all(cfg$val_origins>=1900),'validation chronology')
check(nrow(ms_grid())==144,'frozen 144 reservoir definitions / 576 ridge configurations')
check(all(diff(ms_g(seq(-50,50,length.out=10001)))>0),'strictly monotone transform')
for(h in c(1L,2L,60L))for(p in c(.05,.5,.95)) {
  loc<-cfg$phi^h*.8;scale<-cfg$innovation_scale*sum(cfg$phi^(0:(h-1)))
  independent<-ms_season(1000+h)+ms_g(loc+scale*qcauchy(p))
  check(abs(independent-ms_truth(.8,1000,h,p))<1e-12,paste('analytic quantile',h,p))
}
set.seed(9301);X<-cbind(1,matrix(rnorm(21),7,3));y<-rnorm(7)
f<-normal_desn_fit(X,y,prior=list(tau2=.7,intercept_var=10),omega_prior=list(a=3,b=1))
P<-diag(c(.1,rep(1/.7,3)));C<-(diag(7)+X%*%solve(P,t(X)))/3;U<-chol(C)
quad<-sum(forwardsolve(t(U),y)^2);nu<-6
ref<-lgamma((nu+7)/2)-lgamma(nu/2)-7/2*log(nu*pi)-sum(log(diag(U)))-(nu+7)/2*log1p(quad/nu)
check(abs(f$log_marginal-ref)<1e-10,'Gaussian integrated likelihood vs independent multivariate t')
write.csv(data.frame(log_evidence=f$log_marginal,reference=ref),file.path(ms_root,'evidence/gaussian_reference.csv'),row.names=FALSE)
d<-ms_generate();spec<-as.list(ms_grid()[2,]);b<-ms_build(d$y[1:620],spec,600L)
check(max(abs(colMeans(b$X_fit[,-1])))<1e-10,'training-only feature centering')
check(max(abs(apply(b$X_fit[,-1],2,sd)-1))<1e-10,'training-only unit slope SD')
eng<-.normal_desn_transition_engine(b$raw,'serial');o<-599L
hp<-lapply(b$raw$states$H_all,function(x)x[o,]);step<-eng$step(hp,eng$input(b$ys[1:o]))
check(max(abs(step$x-b$raw$X[600-500,]))<1e-10,'shared transition matches original builder')
set.seed(22);beta<-matrix(rnorm(3*ncol(b$X_fit),sd=.02),3);noise<-matrix(rnorm(15,sd=.1),5,3)
a<-ms_paths(b,beta,noise,600L,d$y[1:600]);s<-sapply(1:3,function(j)ms_paths(b,beta[j,,drop=FALSE],noise[,j,drop=FALSE],600L,d$y[1:600]))
check(max(abs(a-s))<1e-11,'batched vs scalar recursive forecast')
y2<-d$y[1:620];y2[601:620]<-y2[601:620]+100
b2<-ms_build(y2,spec,600L)
check(isTRUE(all.equal(b$X_fit,b2$X_fit,tolerance=1e-12)),'future perturbation leaves fitting features unchanged')
check(max(abs(ms_paths(b2,beta,noise,600L,d$y[1:600])-a))<1e-11,'future perturbation leaves issued forecasts unchanged')
check(max(abs(b$scale_info$center-b2$scale_info$center))<1e-12,'future perturbation leaves scalers unchanged')
set.seed(29);v<-as.numeric(ms_al_noise(rep(.7,100000),H=1))
check(abs(mean(abs(v))-1.4)<.025,'AL median parameterization equals Laplace scale 2 sigma')
check(abs(median(v))<.025,'AL noise median zero')
pr<-exal_make_beta_prior('rhs',rhs=list(tau0=.001,nu=4,s=1,shrink_intercept=FALSE,intercept_prec=.1))
check(pr$type=='rhs'&pr$hypers$tau0==.001&pr$hypers$s==1&pr$hypers$nu==4,'normalized RHS explicit controls')
set.seed(50);XX<-cbind(1,seq(-1,1,length.out=40));yy<-XX%*%c(.3,.5)+rnorm(40,sd=.2)
smoke<-exal_mcmc_fit(as.numeric(yy),XX,.5,c(-1,1),likelihood_family='al',al_fixed_gamma=0,
  n_burn=40,n_mcmc=100,thin=1,verbose=FALSE,beta_prior_obj=pr,prior_sigma=list(a=3,b=1))
check(nrow(smoke$samp.beta)==100&all(is.finite(smoke$samp.beta)),'existing AL-RHS kernel finite smoke chain')
check(all(as.numeric(smoke$samp.gamma)==0),'AL shape stays fixed zero')
check(is.null(smoke$samp.v)&is.null(smoke$samp.s),'latent draw arrays disabled')
ms_json(list(complete=TRUE,checks_passed=checks,production_chain=FALSE,
  source_sha256=ms_sources(),scope='Independent algebra and causal/parity tests plus small sampler feasibility; not posterior convergence'),
  file.path(ms_root,'evidence/tests.json'))
cat('TESTS_COMPLETE',checks,'\n')
