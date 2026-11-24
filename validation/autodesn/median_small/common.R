# Study-local orchestration; core reservoir, conjugate readout and AL kernels are reused.
ms_root <- 'validation/autodesn/median_small'
ms_load <- function(native=FALSE) {
  source('validation/autodesn/load_checkout.R',local=.GlobalEnv)
  if(native) {
    cache <- Sys.getenv('MEDIAN_CACHE', file.path(tempdir(),'median_cpp'))
    dir.create(cache,recursive=TRUE,showWarnings=FALSE)
    # Standalone copies avoid loading unrelated package-wide LinkingTo dependencies.
    native<-file.path(cache,'sources');dir.create(native,showWarnings=FALSE)
    oldflags<-Sys.getenv('PKG_CPPFLAGS');on.exit(Sys.setenv(PKG_CPPFLAGS=oldflags),add=TRUE)
    Sys.setenv(PKG_CPPFLAGS=paste(oldflags,paste0('-I',system.file('include',package='BH'))))
    for(f in c('sampling_utils.cpp','sampling_truncnorm.cpp','exAL.cpp')) {
      target<-file.path(native,f)
      if(!file.exists(target)||!identical(digest::digest(file=target,algo='sha256'),digest::digest(file=file.path('src',f),algo='sha256')))
        file.copy(file.path('src',f),target,overwrite=TRUE)
      stopifnot(identical(digest::digest(file=target,algo='sha256'),digest::digest(file=file.path('src',f),algo='sha256')))
      Rcpp::sourceCpp(target,cacheDir=cache,showOutput=FALSE,verbose=FALSE)
    }
  }
}
ms_config <- function() list(seed=20261124L,n=3500L,washout=500L,cutoff=1900L,
  refit=2900L,H=60L,val_origins=as.integer(round(seq(1900,2840,length.out=10))),
  test_origins=2900L+60L*(0:9),phi=.88,innovation_scale=.12,
  season=c(.4,1.1,.3,-.8,-.4,-.1,.7,1.6,.1,-.9,-1.2,-.8),
  ridge=c(.1,1,10,100),coarse_paths=16L,fine_paths=256L,finalists=16L,
  burn=3000L,retained=5000L,forecast_paths=2048L,forecast_seed=60261124L)
ms_json <- function(x,path) {
  dir.create(dirname(path),recursive=TRUE,showWarnings=FALSE)
  jsonlite::write_json(x,path,pretty=TRUE,auto_unbox=TRUE,digits=16,na='null')
}
ms_hash <- function(path) digest::digest(file=path,algo='sha256')
ms_g <- function(z) asinh(z)+.45*tanh(2.5*z)
ms_season <- function(t,cfg=ms_config()) {
  s<-cfg$season-mean(cfg$season);s[1L+((t-1L)%%12L)]
}
ms_truth <- function(z,origin,h,p=.5,cfg=ms_config()) {
  stopifnot(all(h>=1),all(p>0&p<1))
  loc<-cfg$phi^h*z;sc<-cfg$innovation_scale*(1-cfg$phi^h)/(1-cfg$phi)
  ms_season(origin+h,cfg)+ms_g(loc+sc*tan(pi*(p-.5)))
}
ms_generate <- function(cfg=ms_config()) {
  RNGkind('Mersenne-Twister','Inversion','Rejection');set.seed(cfg$seed)
  z<-numeric(cfg$n);prev<-rcauchy(1,scale=cfg$innovation_scale/(1-cfg$phi))
  initial<-prev
  for(t in seq_len(cfg$n)){z[t]<-cfg$phi*prev+rcauchy(1,scale=cfg$innovation_scale);prev<-z[t]}
  lag<-c(initial,head(z,-1L));time<-seq_len(cfg$n)
  data.frame(time=time,y=ms_season(time,cfg)+ms_g(z),z=z,
    season=ms_season(time,cfg),median_one_step=ms_season(time,cfg)+ms_g(cfg$phi*lag))
}
ms_grid <- function() {
  g<-expand.grid(D=c(1L,2L,3L),width=c(12L,24L),m=c(1L,3L,12L),
    alpha=c(.25,.7),rho=c(.5,.9),seed=c(301L,907L),KEEP.OUT.ATTRS=FALSE)
  g$id<-seq_len(nrow(g));g
}
ms_calendar <- function(t) outer(1L+((t-1L)%%12L),1:11,`==`)*1
ms_build <- function(y,spec,cutoff,check_washout=TRUE) {
  stopifnot(length(y)>=cutoff,cutoff>500L)
  ctr<-mean(y[1:500]);scl<-sd(y[1:500]);ys<-(y-ctr)/scl
  a<-list(y=ys,p0=.5,D=as.integer(spec$D),n=rep(as.integer(spec$width),spec$D),
    n_tilde=rep(as.integer(spec$width),max(0L,spec$D-1L)),m=as.integer(spec$m),
    alpha=spec$alpha,rho=rep(spec$rho,spec$D),washout=500L,add_bias=TRUE,
    standardize_inputs=FALSE,input_bound='tanh',win_scale_global=.6,
    pi_w=.1,pi_in=.1,act_f='tanh',act_k='identity',seed=as.integer(spec$seed),fit_readout=FALSE)
  raw<-do.call(qdesn_fit_vb,a);idx<-raw$meta$keep_idx
  stopifnot(identical(as.integer(idx),seq.int(501L,length(y))))
  X0<-cbind(raw$X,ys[idx-1L],ys[idx-12L],ms_calendar(idx))
  use<-idx<=cutoff
  active_columns<-c(1L,1L+which(apply(X0[use,-1L,drop=FALSE],2L,sd)>1e-10))
  scaled<-readout_scale_fit(X0[use,active_columns,drop=FALSE],has_intercept=TRUE)
  X<-readout_scale_apply(X0[,active_columns,drop=FALSE],scaled$scale_info)
  washerr<-NA_real_
  if(check_washout) {
    e<-.normal_desn_transition_engine(raw,'serial')
    hp<-lapply(raw$reservoir$W,function(w) rep(1,nrow(w)));hm<-lapply(hp,`-`)
    history<-rep(0,raw$meta$m)
    for(t in 1:500){u<-e$input(history);hp<-e$step(hp,u)$h;hm<-e$step(hm,u)$h;history<-c(history,ys[t])}
    washerr<-max(abs(unlist(hp)-unlist(hm)))
    if(!is.finite(washerr)||washerr>.001)stop('frozen washout admission failed')
  }
  list(raw=raw,X=X,X_fit=X[use,,drop=FALSE],y_fit=ys[idx[use]],ys=ys,
    index=idx,scale_info=scaled$scale_info,center=ctr,response_scale=scl,
    cutoff=cutoff,spec=spec,washout_error=washerr,active_columns=active_columns)
}
ms_gaussian <- function(b,precision) normal_desn_fit(b$X_fit,b$y_fit,
  beta_prior_type='scaled_ridge',prior=list(tau2=1/precision,intercept_var=10),
  omega_prior=list(a=3,b=1))

# Noise is explicit for paired numerical tests. No future-response argument exists.
ms_paths <- function(b,beta,noise,origin,y_history,backend='batched') {
  stopifnot(length(y_history)==origin,origin<=length(b$ys),
    is.matrix(beta),is.matrix(noise),ncol(noise)==nrow(beta),all(is.finite(beta)),all(is.finite(noise)))
  nd<-nrow(beta);H<-nrow(noise);eng<-.normal_desn_transition_engine(b$raw,'batched')
  hp<-lapply(b$raw$states$H_all,function(h) matrix(h[origin,],nrow=ncol(h),ncol=nd))
  buf<-matrix(rev(tail((y_history-b$center)/b$response_scale,12L)),12L,nd)
  out<-matrix(NA_real_,H,nd)
  for(h in seq_len(H)) {
    lags<-buf[seq_len(eng$m),,drop=FALSE];u<-rbind(rep(eng$win_scale_bias,nd),eng$process_lags(lags)*eng$win_scale_global)
    step<-eng$step(hp,u)
    cal<-matrix(ms_calendar(origin+h),11L,nd)
    x<-rbind(step$x,buf[1L,],buf[12L,],cal)
    x<-readout_scale_apply(t(x)[,b$active_columns,drop=FALSE],b$scale_info)
    mu<-rowSums(x*beta);yy<-mu+noise[h,]
    stopifnot(all(is.finite(yy)))
    out[h,]<-b$center+b$response_scale*yy
    buf<-rbind(yy,buf[1:11,,drop=FALSE]);hp<-step$h
  }
  out
}
ms_forecast_gaussian <- function(b,fit,origin,y_history,nd,seed) {
  set.seed(seed);d<-normal_desn_posterior_draws(fit,nd=nd)
  noise<-sweep(matrix(rnorm(60L*nd),60L,nd),2L,sqrt(d$omega2),`*`)
  ms_paths(b,d$beta,noise,origin,y_history)
}
ms_al_noise <- function(sigma,H=60L) {
  u<-matrix(runif(H*length(sigma),-.5,.5),H,length(sigma))
  sweep(-sign(u)*log1p(-2*abs(u)),2L,2*sigma,`*`)
}
ms_score <- function(pred,observed) {
  med<-apply(pred,1L,median);mean(abs(observed-med))*.5
}
ms_row <- function(basis,fit,origins,y,nd,seed) {
  loss<-numeric(length(origins));for(i in seq_along(origins)){
    o<-origins[i];v<-ms_forecast_gaussian(basis,fit,o,y[seq_len(o)],nd,seed+i)
    loss[i]<-ms_score(v,y[o+seq_len(60L)])
  };mean(loss)
}
ms_summary <- function(paths,origin,z=NULL) {
  q<-t(apply(paths,1L,quantile,probs=c(.05,.25,.5,.75,.95),names=FALSE,type=8))
  data.frame(origin=origin,horizon=seq_len(nrow(paths)),time=origin+seq_len(nrow(paths)),
    q05=q[,1],q25=q[,2],median=q[,3],q75=q[,4],q95=q[,5])
}
ms_sources <- function() {
  p<-c(list.files('R',pattern='\\.R$',full.names=TRUE),
    list.files(ms_root,pattern='\\.(R|py|json|md|txt)$',full.names=TRUE))
  as.list(setNames(vapply(p,ms_hash,''),p))
}
