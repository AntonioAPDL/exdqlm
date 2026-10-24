ext_internal <- function(n)get(n,envir=environment(autodesn_fit_bank),inherits=TRUE)
ext_example <- function() {
 set.seed(610);y<-sin((1:80)/3)+rnorm(80,sd=.2)
 specs<-list(a=list(D=1,n=4,n_tilde=integer(0),m=2,alpha=.4,rho=.5,seed=31,washout=5,pi_in=1,pi_w=1),b=list(D=2,n=c(4,3),n_tilde=2,m=3,alpha=c(.4,.6),rho=c(.5,.6),seed=39,washout=5,pi_in=1,pi_w=1))
 autodesn_build_bank(y,specs,conditioning=5,washout=10,standardize_features=TRUE,normalize_features=FALSE)
}

test_that('frozen local-scale proposals normalize and retain exact product-space ratios', {
 constructor<-autodesn_extended_local_proposal
 logq<-ext_internal('.ext_local_logq');correction<-ext_internal('.ext_local_correction')
 hc<-function(z)log(2/pi)-abs(z)-log1p(exp(-2*abs(z)))
 proposal<-constructor(list(matrix(c(-2,.5,2),3,1),matrix(c(-1,.7,2,.1,-.4,.8),3,2)),list(.6,c(.4,.7)),slope=list(-.5,c(-.3,-.8)),reference_log_global=c(1,-1),weight=c(.8,.7),bank_id='fixture')
 mass<-integrate(function(x)vapply(x,function(z)exp(logq(z,1,2,proposal)),0),-35,35,rel.tol=1e-10)$value
 expect_equal(mass,1,tolerance=1e-10)
 value<-c(-.6,1.2);u<-.3;shift<-proposal$slope[[2]]*(u+1)
 product<-prod(vapply(1:2,function(j)mean(dnorm(value[j],proposal$centers[[2]][,j]+shift[j],proposal$bandwidth[[2]][j])),0))
 expect_equal(exp(logq(value,2,u,proposal)),.3*exp(sum(hc(value)))+.7*product,tolerance=1e-13)
 # Full-space prior and proposal, including inactive dimensions, independently.
 old<-c(.7,-1.1,.3);new<-c(-.2,1.4,-.8);pm<-c(.4,.6);qm<-c(.8,.2)
 likelihood_old<--1.7;likelihood_new<--.8
 full<-likelihood_new-likelihood_old+log(pm[2]/pm[1])+sum(hc(new))-sum(hc(old))+
   log(qm[1])+logq(old[1],1,u,proposal)+sum(hc(old[2:3]))-
   log(qm[2])-logq(new[1:2],2,u,proposal)-hc(new[3])
 active<-likelihood_new-likelihood_old+log(pm[2]/pm[1])+log(qm[1]/qm[2])+
   correction(new[1:2],2,u,proposal)-correction(old[1],1,u,proposal)
 expect_equal(active,full,tolerance=1e-13)
 expect_lte(correction(value,2,u,proposal),-log1p(-proposal$weight[2]))
 expect_equal(logq(1e200,1,u,proposal),log1p(-proposal$weight[1])+hc(1e200))
 expect_error(constructor(list(matrix(0,1,1)),list(1),weight=1,bank_id='x'),'prior component')
 expect_error(constructor(list(matrix(0,1,1)),list(0),bank_id='x'),'dimensions or scales')
})

test_that('local-scale moves preserve prior-only architecture masses across dimensions', {
 proposal<-autodesn_extended_local_proposal(list(matrix(c(-1,0,1),3,1),matrix(c(-1,0,1,.2,.5,1.2),3,2)),list(.7,c(.5,.8)),weight=.75,bank_id='fixture')
 logq<-ext_internal('.ext_local_logq');draw<-ext_internal('.ext_local_draw');hc<-ext_internal('.autodesn_rhs_log_hc_log')
 # Independent full-space transition calculation, with three total slots.
 set.seed(7729);pm<-c(.3,.7);qm<-c(.7,.3);m<-1L;ell<-rep(0,3);out<-numeric(20000)
 for(i in 1:22000){a<-sample.int(2,1,prob=qm);z<-log(abs(rcauchy(3)));z[seq_len(a)]<-draw(a,.5,proposal)
  logproposal<-function(v,model)log(qm[model])+logq(v[seq_len(model)],model,.5,proposal)+sum(hc(v[-seq_len(model)]))
  ratio<-log(pm[a]/pm[m])+sum(hc(z))-sum(hc(ell))+logproposal(ell,m)-logproposal(z,a)
  if(log(runif(1))<min(0,ratio)){m<-a;ell<-z};if(i>2000)out[i-2000]<-as.numeric(m==2)
 }
 se<-ext_internal('.autodesn_batch_mcse')(list(out));expect_lt(abs(mean(out)-pm[2]),7*se)
 expect_lt(abs(mean(out)-pm[2]),.04)
})

test_that('kernel-coordinate proposals retain normalized priors in every other coordinate', {
 hc<-function(z)log(2/pi)-abs(z)-log1p(exp(-2*abs(z)))
 p<-autodesn_extended_local_proposal(list(matrix(c(-1,0,1),3,1),matrix(c(-1,.3,1,.1,.6,1.2),3,2)),list(.6,c(.7,.5)),slope=list(-.2,c(-.3,-.4)),reference_log_global=.2,weight=.75,bank_id='fixture',kernel_coordinates=list(integer(0),2L))
 logq<-ext_internal('.ext_local_logq');corr<-ext_internal('.ext_local_correction');draw<-ext_internal('.ext_local_draw')
 value<-c(-.5,.8);u<-.7;centers<-p$centers[[2]][,2]+p$slope[[2]][2]*(u-.2)
 mixture<-.25*exp(hc(value[2]))+.75*mean(dnorm(value[2],centers,.5))
 expect_equal(logq(value,2,u,p),hc(value[1])+log(mixture),tolerance=1e-13)
 expect_equal(corr(value,2,u,p),hc(value[2])-log(mixture),tolerance=1e-13)
 mass<-integrate(function(z)vapply(z,function(x)exp(logq(c(.4,x),2,u,p)),0),-35,35,rel.tol=1e-10)$value
 expect_equal(mass,exp(hc(.4)),tolerance=1e-10)
 expect_equal(logq(.3,1,u,p),hc(.3));expect_equal(corr(.3,1,u,p),0)
 old<-c(.4,-.2,.1);new<-c(-.5,.8,-1);pm<-c(.4,.6);qm<-c(.7,.3)
 full<-log(pm[2]/pm[1])+sum(hc(new))-sum(hc(old))+log(qm[1])+logq(old[1],1,u,p)+sum(hc(old[2:3]))-log(qm[2])-logq(new[1:2],2,u,p)-hc(new[3])
 reduced<-log(pm[2]/pm[1])+log(qm[1]/qm[2])+corr(new[1:2],2,u,p)-corr(old[1],1,u,p)
 expect_equal(full,reduced,tolerance=1e-12)
 set.seed(440);samples<-replicate(5000,draw(2,u,p));prob<-.25*.5+.75*mean(pnorm(0,centers,.5))
 expect_lt(abs(mean(samples[2,]<=0)-prob),7*sqrt(prob*(1-prob)/5000))
 expect_lt(abs(mean(samples[1,]<=0)-.5),7*sqrt(.25/5000))
 expect_error(autodesn_extended_local_proposal(list(matrix(0,2,2)),list(c(1,1)),bank_id='fixture',kernel_coordinates=list(c(1,1))),'distinct')
 expect_error(autodesn_extended_local_proposal(list(matrix(0,2,2)),list(c(1,1)),bank_id='fixture',kernel_coordinates=list(3)),'distinct')
 # Disabled option retains the complete previous object, density and RNG path.
 ref<-new.env(parent=environment(autodesn_fit_bank));sys.source(testthat::test_path('fixtures','local_proposal_pre_coordinates.R'),ref)
 a<-autodesn_extended_local_proposal(list(matrix(c(-1,0,1),3,1)),list(.6),bank_id='fixture')
 b<-ref$autodesn_extended_local_proposal(list(matrix(c(-1,0,1),3,1)),list(.6),bank_id='fixture')
 expect_identical(a,b);expect_identical(logq(.4,1,.7,a),ref$.ext_local_logq(.4,1,.7,b))
 set.seed(119);x<-draw(1,.7,a);set.seed(119);y<-ref$.ext_local_draw(1,.7,b);expect_identical(x,y)
})

test_that('optional local-scale moves are full-support and explicit in computation metadata', {
 b<-autodesn_extend_bank(ext_example(),list(lags=1:2,prior='grouped'),list(periods=c(12,18),harmonics=1))
 p<-autodesn_extended_local_proposal(lapply(b$models,function(m)matrix(0,2,m$d)),lapply(b$models,function(m)rep(1,m$d)),bank_id=b$extension$id)
 f<-autodesn_fit_bank(b,n_burn=5,n_mcmc=20,beta_prior='rhs',rhs_control=list(tau0=.001),model_control=list(local_proposal=p,joint_moves=1,save_draws=5),seed=93,backend='R')
 expect_equal(f$computation$local_proposals,25);expect_gte(f$computation$local_acceptances,0)
 expect_true(all(is.finite(f$trace$log_likelihood)));expect_true(all(is.finite(unlist(f$local))))
 bad<-p;bad$bank_id<-'other';expect_error(autodesn_fit_bank(b,n_burn=1,n_mcmc=2,beta_prior='rhs',model_control=list(local_proposal=bad)),'does not match')
 expect_error(autodesn_fit_bank(b,n_burn=1,n_mcmc=2,beta_prior='rhs',rhs_control=list(fixed_local_scales=1),model_control=list(local_proposal=p)),'learned RHS')
 expect_error(autodesn_fit_bank(b,n_burn=1,n_mcmc=2,model_control=list(local_moves=1)),'requires a frozen')
 joint<-autodesn_extended_proposal(matrix(rep(c(log(.3),0,0,0),each=2),2,4),diag(4))
 g<-autodesn_fit_bank(b,n_burn=5,n_mcmc=20,beta_prior='rhs',rhs_control=list(tau0=.001),model_control=list(local_proposal=p,joint_proposal=joint,local_scale_proposal=TRUE,joint_moves=1,save_draws=5),seed=93,backend='R')
 expect_true(g$controls$model_control$local_scale_proposal);expect_equal(g$computation$local_proposals,25)
 expect_true(all(is.finite(as.matrix(g$trace))));expect_true(all(is.finite(unlist(g$local))))
 expect_error(autodesn_fit_bank(b,n_burn=1,n_mcmc=2,beta_prior='rhs',model_control=list(local_proposal=p,local_scale_proposal=TRUE)),'frozen joint_proposal')
})

test_that('joint scale/local ratios match the complete fixed-space target and conditional proposal', {
 lp<-autodesn_extended_local_proposal(list(matrix(c(-1,0,1),3,1),matrix(c(-1,0,1,.2,.5,1.2),3,2)),list(.7,c(.5,.8)),slope=list(-.4,c(-.5,-.2)),weight=.75,bank_id='fixture')
 jp<-autodesn_extended_proposal(matrix(c(-1,.2,.5,.1,-.5,-.2,.4,.7),2,4),diag(c(.5,1,2,.8)),wide_center=rep(0,4))
 logq<-ext_internal('.ext_local_logq');qz<-ext_internal('.ext_joint_logq');corr<-ext_internal('.ext_local_correction')
 hc<-function(z)log(2/pi)-abs(z)-log1p(exp(-2*abs(z)))
 prior<-function(z)3*log(1)-lgamma(3)-3*z[1]-exp(-z[1])+sum(hc(z[2:3]))+2*log(2)-lgamma(2)-2*z[4]-2*exp(-z[4])
 a<-c(log(.4),-.3,.5,log(2));b<-c(log(.3),.2,-.4,log(1.5));old<-c(.7,-1.1,.3);new<-c(-.2,1.4,-.8)
 pm<-c(.4,.6);qm<-c(.8,.2);likelihood_difference<-.93
 # Complete proposal includes every active/inactive scale and both transformed
 # global draws. Inactive priors cancel only after writing their full density.
 full<-likelihood_difference+log(pm[2]/pm[1])+prior(b)-prior(a)+sum(hc(new))-sum(hc(old))+
  log(qm[1])+qz(a,1,jp)+logq(old[1],1,a[3],lp)+sum(hc(old[2:3]))-
  log(qm[2])-qz(b,2,jp)-logq(new[1:2],2,b[3],lp)-hc(new[3])
 reduced<-likelihood_difference+log(pm[2]/pm[1])+log(qm[1]/qm[2])+prior(b)-prior(a)+qz(a,1,jp)-qz(b,2,jp)+corr(new[1:2],2,b[3],lp)-corr(old[1],1,a[3],lp)
 expect_equal(full,reduced,tolerance=1e-13)
 wrong_condition<-likelihood_difference+log(pm[2]/pm[1])+log(qm[1]/qm[2])+prior(b)-prior(a)+qz(a,1,jp)-qz(b,2,jp)+corr(new[1:2],2,a[3],lp)-corr(old[1],1,a[3],lp)
 expect_gt(abs(wrong_condition-reduced),.01)
})

test_that('augmented controls reject ambiguous or unsupported inputs', {
 expect_error(autodesn_readout_control(lags=c(1,1)),'distinct')
 expect_error(autodesn_readout_control(lags=0),'positive')
 expect_error(autodesn_readout_control(other=3),'Unknown')
 expect_error(autodesn_seasonal_control(periods=c(2,3)),'greater')
 expect_error(autodesn_seasonal_control(periods=10,prior=0),'positive')
 expect_error(autodesn_variance_control(initial_phi=1),'inside')
 expect_error(autodesn_variance_control(seasonal=TRUE),'requires')
 b<-ext_example();bad<-b;bad$normalize_features<-TRUE
 expect_error(autodesn_extend_bank(bad),'standardize')
 expect_error(autodesn_extend_bank(b,list(lags=20)),'history')
 e<-autodesn_extend_bank(b,list(lags=1:2));expect_error(autodesn_fit_bank(e,n_burn=1,n_mcmc=2,beta_prior='rhs',rhs_control=list(local_layout='layerwise')),'family-indexed')
})

test_that('augmentation preserves bank mass and frozen training geometry', {
 b<-ext_example();e<-autodesn_extend_bank(b,list(lags=c(1,3)),list(periods=c(12,18),harmonics=4))
 expect_identical(e$prior,b$prior);expect_identical(e$templates,b$templates)
 expect_equal(unname(colMeans(e$extension$lag$X)),c(0,0),tolerance=1e-13)
 expect_equal(unname(apply(e$extension$lag$X,2,sd)),c(1,1),tolerance=1e-13)
 for(S in e$extension$calendar)expect_equal(unname(apply(S$X,2,sd)),rep(1,ncol(S$X)),tolerance=1e-13)
 expect_equal(sum(outer(e$prior,e$extension$period_prior)),1)
 d<-ext_internal('.ext_design')(e,2,1)
 expect_identical(length(unique(d$slots)),length(d$slots));expect_equal(ncol(d$X),1+2+e$models[[2]]$d+8)
})

test_that('raw coefficient transport includes all block and response intercept corrections', {
 b<-ext_example();e<-autodesn_extend_bank(b,list(lags=c(1,3)),list(periods=c(12,18),harmonics=2))
 f<-autodesn_fit_bank(e,n_burn=4,n_mcmc=12,beta_prior='ridge',model_control=list(moves=2,joint_moves=0),seed=172)
 for(k in seq_len(nrow(f$draws))) {
  m<-f$draws$model[k];p<-f$draws$period_index[k];r<-b$models[[m]]
  R<-matrix(rep(r$feature_center,each=b$n),b$n,r$raw_d)
  R[,r$active_features]<-sweep(sweep(r$X[,-1,drop=FALSE],2,r$feature_scale[r$active_features],'*'),2,r$feature_center[r$active_features],'+')
  L<-vapply(e$extension$readout$lags,function(lag)b$history_scaled[b$keep_idx-lag],numeric(b$n))
  S<-ext_internal('.ext_fourier')(b$keep_idx,e$extension$periods[p],2)
  expected<-as.vector(ext_internal('.ext_design')(e,m,p)$X%*%f$beta[[k]])
  raw<-autodesn_readout_coefficients(f,k,FALSE)[[1]]$coefficients
  expect_equal(as.vector(cbind(1,L,R,S)%*%raw),expected,tolerance=1e-11)
  original<-autodesn_readout_coefficients(f,k,TRUE)[[1]]$coefficients
  original_L<-b$preprocessing$center+b$preprocessing$scale*L
  expect_equal(as.vector(cbind(1,original_L,R,S)%*%original),b$preprocessing$center+b$preprocessing$scale*expected,tolerance=1e-11)
 }
 bad<-f;bad$bank$extension$id<-'other';expect_error(autodesn_readout_coefficients(bad,1),'does not match')
 # Matrix-only banks have identity response geometry and dropped constants.
 a<-autodesn_extend_bank(autodesn_prepare_bank(rep(0,8),list(matrix(0,8,1)),normalize_features=FALSE,standardize_features=TRUE))
 z<-autodesn_fit_bank(a,n_burn=2,n_mcmc=4,beta_prior='ridge',seed=14)
 raw<-autodesn_readout_coefficients(z,1)[[1]]$coefficients
 expect_identical(names(raw),c('intercept','reservoir_1'));expect_equal(raw[2],c(reservoir_1=0))
 pp<-posterior_predict(z,nd=3,seed=32);expect_equal(dim(pp$sd_draws),c(8L,3L));expect_true(all(pp$sd_draws>0))
})

test_that('weighted Gaussian integral and coefficient covariance match dense independent reference', {
 set.seed(91);X<-cbind(1,matrix(rnorm(45),9,5));X<-cbind(X,X[,2]);y<-rnorm(9);d<-list(X=X,XtX=crossprod(X),Xty=as.vector(crossprod(X,y)))
 for(lv in list(seq(-10,3,length.out=ncol(X)),rep(-.3,ncol(X))))for(ld in list(rep(log(.3),9),seq(-2,1,length.out=9))) {
  V<-diag(exp(lv));D<-diag(exp(ld));C<-D+X%*%V%*%t(X);U<-chol(C)
  expected<--.5*(9*log(2*pi)+2*sum(log(diag(U)))+sum(forwardsolve(t(U),y)^2))
  g<-ext_internal('.ext_gaussian')(d,y,ld,lv,'R')
  expect_equal(g$log_evidence,expected,tolerance=2e-9)
  P<-solve(V)+crossprod(X,solve(D,X));Cov<-solve(P);expect_equal(g$mean,as.vector(Cov%*%crossprod(X,solve(D,y))),tolerance=1e-9)
  T<-diag(g$sqrt_prior)%*%backsolve(g$chol,diag(ncol(X)));expect_equal(tcrossprod(T),Cov,tolerance=1e-9)
  cpp<-tryCatch(ext_internal('autodesn_weighted_gaussian_cpp'),error=function(e)NULL)
  if(!is.null(cpp)) {
   z<-cpp(X,y,ld,lv);expect_equal(z$log_evidence,g$log_evidence,tolerance=2e-9);expect_equal(z$mean,g$mean,tolerance=2e-9)
  }
 }
})

test_that('grouped prior uses independent variance conventions and finite slab normalization', {
 b<-autodesn_extend_bank(ext_example(),list(lags=c(1,3),prior='grouped'),list(periods=c(12,18),harmonics=3))
 d<-ext_internal('.ext_design')(b,2,1);ell<-seq(-2,2,length.out=b$extension$dimension);u<-log(c(.4,.9));c2<-log(2)
 v<-ext_internal('.ext_logv')(d,ell,u,c2,c(.001,.002),'rhs',1,10)
 for(i in seq_len(d$d)) {
  expected<-if(d$gaussian[i])d$gaussian_variance[i] else {g<-match(d$groups[i],c('lag','reservoir'));1/(1/2+1/(c(.001,.002)[g]*exp(u[g]+ell[d$slots[i]]))^2)}
  expect_equal(exp(v[i+1]),expected,tolerance=1e-13)
 }
 expect_equal(exp(v[1]),10)
})

test_that('joint architecture and period probabilities agree with observation-space quadrature', {
 x<-seq(-1,1,length.out=9);b<-autodesn_prepare_bank(.5*x+c(.1,-.1,.2,-.1,0,.1,-.2,.1,0),list(matrix(x),cbind(x,x*x)),normalize_features=FALSE,standardize_features=TRUE,model_prior=c(.3,.7))
 e<-autodesn_extend_bank(b,seasonal_control=list(periods=c(8,12),harmonics=1,prior=c(.4,.6)))
 design<-ext_internal('.ext_design');raw<-numeric(4)
 for(p in 1:2)for(m in 1:2) {
  d<-design(e,m,p);v<-c(10,rep(.7^2*1.2^2/(1+.7^2*1.2^2/2),d$d))
  ld<-function(z)vapply(z,function(z){C<-exp(z)*diag(9)+d$X%*%diag(v)%*%t(d$X);U<-chol(C);-.5*(9*log(2*pi)+2*sum(log(diag(U)))+sum(forwardsolve(t(U),b$y)^2))+3*log(1)-lgamma(3)-3*z-exp(-z)},0)
  shift<--optimize(function(z)-ld(z),c(-15,15))$objective
  raw[m+2*(p-1)]<-log(e$prior[m]*e$extension$period_prior[p])+shift+log(integrate(function(z)exp(ld(z)-shift),-25,20,rel.tol=1e-9)$value)
 }
 truth<-exp(raw-max(raw));truth<-truth/sum(truth)
 control<-list(tau0=.7,fixed_local_scales=1.2,learn_global=FALSE,initial_global=1,learn_slab=FALSE,initial_slab=2)
 for(method in c('mh','categorical')) {
  f<-autodesn_fit_bank(e,n_burn=1000,n_mcmc=6000,beta_prior='rhs',rhs_control=control,model_control=list(method=method,moves=2,joint_moves=1,proposal=c(.8,.2),period_proposal=c(.7,.3)),seed=83,backend='R')
  for(j in 1:4) {
   q<-as.numeric(f$draws$model+2*(f$draws$period_index-1)==j)
   se<-ext_internal('.autodesn_batch_mcse')(list(q));expect_lt(abs(mean(q)-truth[j]),max(.015,7*se))
  }
 }
})

test_that('Gaussian-prior elliptical updates have independent exact Gaussian moments', {
 set.seed(421);n<-3;Q<-outer(1:n,1:n,function(a,b).7^abs(a-b));prior<-chol(Q);obs<-c(.2,-.3,.6);v<-.4
 C<-solve(solve(Q)+diag(1/v,n));mu<-as.vector(C%*%(obs/v));x<-numeric(n);B<-matrix(0,5000,n)
 for(i in 1:5500){x<-ext_internal('.ext_ellipse')(x,as.vector(t(prior)%*%rnorm(n)),function(x)sum(dnorm(obs,x,sqrt(v),log=TRUE)));if(i>500)B[i-500,]<-x}
 for(j in 1:n){se<-ext_internal('.autodesn_batch_mcse')(list(B[,j]));expect_lt(abs(mean(B[,j])-mu[j]),7*se)}
 for(j in 1:n)for(k in 1:n){v<-B[,j]*B[,k];se<-ext_internal(".autodesn_batch_mcse")(list(v));expect_lt(abs(mean(v)-C[j,k]-mu[j]*mu[k]),7*se)}
})

test_that('legacy shared reservoir transition is bit-identical after extraction', {
 b<-ext_example();t<-b$templates[[2]];t$fit<-list(target_label='reference');class(t)<-c('qdesn_normal_fit','list')
 env<-new.env(parent=environment(autodesn_fit_bank));sys.source(testthat::test_path('fixtures','qdesn_normal_pre_engine.R'),env)
 set.seed(42);B<-matrix(rnorm(3*ncol(t$X)),3);z<-matrix(rnorm(15),5,3)
 args<-list(object=t,H=5,y_hist=b$history_scaled,draws=list(beta=B,omega2=c(.1,.3,.8)),innovations=z,backend='batched',return_design=TRUE)
 expect_identical(do.call(forecast_paths.qdesn_normal_fit,args),do.call(env$forecast_paths.qdesn_normal_fit,args))
})

test_that('augmented forecasts use simulated lags and observed updates match causal designs', {
 b<-ext_example();e<-autodesn_extend_bank(b,list(lags=1:2),list(periods=12,harmonics=2))
 f<-autodesn_fit_bank(e,n_burn=5,n_mcmc=8,beta_prior='ridge',model_control=list(moves=1,joint_moves=0),seed=31)
 d<-ext_internal('.ext_design')(e,1,1);B<-rep(0,ncol(d$X));B[1:3]<-c(.1,.5,-.2);f$beta[[1]]<-B;f$draws$model[1]<-1;f$draws$period_index[1]<-1
 z<-matrix(c(.1,-.3,.2),3,1);a<-forecast_paths(f,3,draw_index=1,inner_paths=1,innovations=z,seed=17)
 history<-b$history_scaled
 for(h in 1:3){L<-matrix(history[length(history)+1-1:2],1);s<-.1+sum(ext_internal('.ext_apply')(e$extension$lag,L)*c(.5,-.2));expect_equal(a$mu_draws[h,1],b$preprocessing$center+b$preprocessing$scale*s,tolerance=1e-11);history<-c(history,(a$yrep[h,1]-b$preprocessing$center)/b$preprocessing$scale)}
 oldid<-f$controls$target_id;updated<-autodesn_update_history(f,c(.12,.3));expect_identical(updated$beta,f$beta);expect_identical(updated$controls$target_id,oldid)
 # First observed update design uses no second appended observation.
 changed<-autodesn_update_history(f,c(.12,300));expect_identical(updated$bank$extension$last_observation_features[[1]][1,],changed$bank$extension$last_observation_features[[1]][1,])
 expect_identical(forecast_paths(f,3,draw_index=1,innovations=z,inner_paths=1,seed=17)$yrep,a$yrep)
})

test_that('H_last-only reservoir templates reproduce complete-state causal forecasts', {
 b<-ext_example();compact<-b
 compact$templates<-lapply(b$templates,function(t){t$states<-list(H_last=ext_internal('.ext_template_initial')(t));t})
 e<-autodesn_extend_bank(b,list(lags=1:2),list(periods=12,harmonics=2))
 ec<-autodesn_extend_bank(compact,list(lags=1:2),list(periods=12,harmonics=2))
 expect_identical(e$extension$initial_states,ec$extension$initial_states)
 args<-list(n_burn=3,n_mcmc=6,beta_prior='ridge',seed=818,backend='R')
 f<-do.call(autodesn_fit_bank,c(list(bank=e),args));g<-do.call(autodesn_fit_bank,c(list(bank=ec),args))
 expect_identical(f$trace,g$trace);expect_identical(f$beta,g$beta)
 expect_identical(forecast_paths(f,5,draw_index=1:3,seed=32)$yrep,forecast_paths(g,5,draw_index=1:3,seed=32)$yrep)
 u<-autodesn_update_history(f,c(.1,.3));v<-autodesn_update_history(g,c(.1,.3))
 expect_identical(u$bank$extension$current_states,v$bank$extension$current_states)
 expect_identical(forecast_paths(u,3,draw_index=1:3,seed=41)$yrep,forecast_paths(v,3,draw_index=1:3,seed=41)$yrep)
 # Old augmented checkpoints used empty lists with compact recovered templates.
 old<-g;old$bank$extension$initial_states<-rep(list(list()),length(b$models))
 expect_identical(forecast_paths(old,3,draw_index=1:3,seed=45)$yrep,forecast_paths(g,3,draw_index=1:3,seed=45)$yrep)
})

test_that('conditional SV filtering preserves weights and rejects stale states', {
 b<-autodesn_extend_bank(ext_example(),list(lags=1:2),list(periods=12,harmonics=2))
 f<-autodesn_fit_bank(b,n_burn=10,n_mcmc=20,beta_prior='ridge',variance_control=list(type='sv',seasonal=TRUE),seed=51)
 fil<-autodesn_filter(f,1:2,particles=128,seed=31);expect_false(fil$static_weights_updated)
 f2<-autodesn_update_history(f,c(.1,.2));expect_identical(f$draws,f2$draws)
 expect_error(forecast_paths(f2,2,draw_index=1:2,state_filter=fil),'stale')
 next_filter<-autodesn_filter(f2,1:2,particles=128,previous=fil,seed=32)
 z<-matrix(0,2,4);a<-forecast_paths(f2,2,draw_index=1:2,inner_paths=2,state_filter=next_filter,innovations=z,volatility_innovations=z,seed=33)
 expect_true(all(is.finite(a$yrep)));expect_true(all(a$sd_draws>0));expect_false(a$static_weights_updated)
 bad<-f2;bad$beta[[1]][1]<-bad$beta[[1]][1]+.1;expect_error(forecast_paths(bad,2,draw_index=1:2,state_filter=next_filter),'stale')
 bad<-f2;bad$bank$templates[[f2$draws$model[1]]]$reservoir$W[[1]][1,1]<-bad$bank$templates[[f2$draws$model[1]]]$reservoir$W[[1]][1,1]+.1
 expect_error(forecast_paths(bad,2,draw_index=1:2,state_filter=next_filter),'stale')
})

test_that('frozen general-dimensional proposal uses normalized t-mixture densities', {
 set.seed(73)
 for(D in 3:4) {
  C<-matrix(seq_len(2*D)/7,2,D);S<-crossprod(matrix(seq_len(D*D)/20,D))+diag(D)
  p<-autodesn_extended_proposal(C,S,df=5,wide_weight=.2,wide_center=rep(0,D))
  for(i in 1:6) {
   z<-rnorm(D);direct<-function(mu,V){U<-chol(V);q<-sum(forwardsolve(t(U),z-mu)^2);exp(lgamma((5+D)/2)-lgamma(5/2)-D/2*log(5*pi)-sum(log(diag(U)))-(5+D)/2*log1p(q/5))}
   expected<-log(.8*direct(C[1,],S)+.2*direct(rep(0,D),9*S))
   expect_equal(ext_internal('.ext_joint_logq')(z,1,p),expected,tolerance=1e-12)
  }
 }
 b<-autodesn_extend_bank(ext_example(),list(lags=1:2,prior='grouped'),list(periods=12,harmonics=1))
 p<-autodesn_extended_proposal(matrix(rep(c(0,2,2,0),each=2),2),diag(4))
 f<-autodesn_fit_bank(b,n_burn=10,n_mcmc=30,beta_prior='rhs',rhs_control=list(tau0=.001),model_control=list(joint_proposal=p,save_draws=6),seed=39)
 expect_equal(nrow(f$trace),30);expect_equal(nrow(f$draws),6);expect_equal(length(f$beta),6)
 expect_equal(rowSums(f$trace[paste0('edf_',c('intercept','lag','reservoir','calendar'))]),f$trace$edf,tolerance=1e-10)
 expect_true(all(is.finite(as.matrix(f$trace[c('norm_lag','norm_reservoir','norm_calendar','log_likelihood','terminal_log_variance')]))))
 expect_true(all(is.finite(unlist(f$beta))));expect_true(all(is.finite(predict_mu(f))))
 one<-autodesn_update_history(f,.2);expect_equal(length(one$bank$history),length(f$bank$history)+1)
})

test_that('SV bootstrap filtering agrees with independent two-state grid integration', {
 step<-ext_internal('.ext_filter_step');phi<-.7;omega<-.6;s2<-.4;residual<-c(.2,1.1)
 grid<-seq(-7,7,length.out=501)
 # Independent normalized joint density of (u1,u2,y1,y2).
 Q<-outer(grid,grid,function(u,v)dnorm(u)*dnorm(v,phi*u,sqrt(1-phi^2))*dnorm(residual[1],0,sqrt(s2*exp(omega*u)))*dnorm(residual[2],0,sqrt(s2*exp(omega*v))))
 expected<-sum(sweep(Q,2,tanh(grid),'*'))/sum(Q)
 means<-numeric(8)
 for(j in 1:8) {
  set.seed(9260+j);N<-8192L;a<-step(numeric(N),rep(-log(N),N),residual[1],s2,phi,omega,0,TRUE)
  b<-step(a$particles,a$logw,residual[2],s2,phi,omega,0)
  means[j]<-sum(exp(b$logw)*tanh(b$particles))
 }
 expect_lt(abs(mean(means)-expected),7*sd(means)/sqrt(length(means)))
 # Zero log volatility gives an exact likelihood independently of filter particles.
 set.seed(16);N<-64L;a<-step(numeric(N),rep(-log(N),N),.3,s2,phi,0,0,TRUE)
 expect_equal(a$log_increment,dnorm(.3,0,sqrt(s2),log=TRUE),tolerance=1e-13)
 expect_equal(a$ess,N,tolerance=1e-12)
})

test_that('SV conditional fitted replicates use the matching saved smoothing state', {
 b<-autodesn_extend_bank(ext_example(),list(lags=1:2),list(periods=12,harmonics=2))
 f<-autodesn_fit_bank(b,n_burn=5,n_mcmc=10,beta_prior='ridge',variance_control=list(type='sv',seasonal=TRUE,save_state_paths=TRUE),model_control=list(save_draws=4),seed=48)
 pp<-posterior_predict(f,nd=3,seed=35)
 for(j in 1:3){k<-pp$draw_index[j];u<-f$volatility[[k]];v<-f$draws$variance[k]*exp(ext_internal('.ext_sv_w')(b,f$draws$period_index[k])%*%u$gamma+f$draws$omega[k]*u$path);expect_equal(pp$sd_draws[,j]^2,as.numeric(v)*b$preprocessing$scale^2,tolerance=1e-12)}
 expect_false(pp$recursive_replication)
})

test_that('constant responses and short-period boundaries are handled explicitly', {
 b<-autodesn_prepare_bank(rep(0,8),list(matrix(0,8,1)),normalize_features=FALSE,standardize_features=TRUE)
 e<-autodesn_extend_bank(b,seasonal_control=list(periods=4.5,harmonics=4))
 expect_equal(e$extension$calendar[[1]]$raw_d,4)
 expect_error(autodesn_fit_bank(e,n_burn=1,n_mcmc=2,beta_prior='rhs',variance_control=list(type='sv',seasonal=TRUE)),'greater than eight')
 z<-autodesn_fit_bank(e,n_burn=5,n_mcmc=8,beta_prior='rhs',seed=19)
 expect_true(all(is.finite(z$draws$variance)));expect_true(all(z$draws$variance>0))
 expect_identical(z$meta$period_policy,'fixed_period')
})

test_that('batched forecasts preserve previous path assignments and conditional SV draws', {
 ref<-new.env(parent=environment(autodesn_fit_bank));sys.source(testthat::test_path('fixtures','forecast_pre_batch.R'),ref)
 # Identity hashing changed with optional smoothing storage; freeze that helper.
 ref$.ext_draw_identity<-ext_internal('.ext_draw_identity')
 b<-autodesn_extend_bank(ext_example(),list(lags=1:2),list(periods=c(12,18),harmonics=2))
 for(sv in c(FALSE,TRUE)) {
  f<-autodesn_fit_bank(b,n_burn=5,n_mcmc=12,beta_prior='ridge',variance_control=if(sv)list(type='sv',seasonal=TRUE) else NULL,seed=61)
  ids<-c(1,3,1,2,7,9);fil<-if(sv)autodesn_filter(f,ids,particles=32,seed=91) else NULL
  a<-forecast_paths(f,4,draw_index=ids,inner_paths=3,state_filter=fil,seed=38)
  r<-ref$forecast_paths.autodesn_extended_fit(f,4,draw_index=ids,inner_paths=3,state_filter=fil,seed=38)
  expect_equal(a$yrep,r$yrep,tolerance=1e-12);expect_equal(a$mu_draws,r$mu_draws,tolerance=1e-12);expect_equal(a$sd_draws,r$sd_draws,tolerance=1e-12)
  expect_identical(a$draw_index,r$draw_index);expect_identical(a$state_filter,r$state_filter)
 }
})

test_that('SV conditional targets keep stationary and transformed density constants', {
 u<-c(.3,-.2,.7,.1,-.4);shape<-c(10,1.5);target<-ext_internal('.ext_sv_phi_logit_target')
 for(phi in c(-.8,0,.9)) {
  C<-outer(seq_along(u),seq_along(u),function(a,b)phi^abs(a-b));U<-chol(C)
  dense<--.5*(length(u)*log(2*pi)+2*sum(log(diag(U)))+sum(forwardsolve(t(U),u)^2))
  expected<-dense+dbeta((phi+1)/2,shape[1],shape[2],log=TRUE)+log((1-phi^2)/4)
  expect_equal(target(qlogis((phi+1)/2),u,shape),expected,tolerance=1e-11)
 }
 expect_identical(ext_internal('.ext_sv_loglik')(rep(-1000,5),rep(0,5),.4),2500)
 expect_identical(ext_internal('.ext_sv_omega_log_target')(1000,u,rep(0,5),.4,rep(0,5),.5),-Inf)
})


test_that('inference-only caches cannot be used as reservoir forecast templates', {
 e<-autodesn_extend_bank(ext_example(),list(lags=1:2));f<-autodesn_fit_bank(e,n_burn=2,n_mcmc=3,beta_prior='ridge',seed=63)
 f$bank$meta$inference_only<-TRUE
 expect_error(forecast_paths(f,2,nd=2),'inference matrix cache')
 expect_error(autodesn_update_history(f,.2),'inference matrix cache')
})
