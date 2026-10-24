# Opt-in augmented readouts. All priors are independent of observation variance.
# The original ridge/RHS paths are untouched unless an extension is requested.

.ext_named <- function(x, allowed, name) {
  .autodesn_rhs_named_list(x, name)
  if (length(setdiff(names(x), allowed))) stop("Unknown ", name, " controls: ", paste(setdiff(names(x),allowed),collapse=", "),call.=FALSE)
}
.ext_control <- function(x, constructor) {
  if (is.null(x)) return(constructor())
  do.call(constructor, unclass(x))
}

#' Augmented AutoDESN readout controls
#' @param lags Distinct positive observation lags, or integer(0).
#' @param prior Common RHS for all slopes, or grouped lag/reservoir RHS with a Gaussian calendar.
#' @param calendar_scale Proper Gaussian calendar prior SD before harmonic decay.
#' @param cache_size Maximum number of cached model/period designs.
#' @param ... Unknown controls are rejected.
#' @return Validated controls. Defaults preserve the existing reservoir-only prior.
#' @export
autodesn_readout_control <- function(lags=integer(0), prior=c("flat","grouped"),calendar_scale=.5,cache_size=32L,...) {
  if(length(list(...)))stop("Unknown readout controls.",call.=FALSE)
  if(!is.numeric(lags)||any(!is.finite(lags)|lags<1|lags!=floor(lags))||anyDuplicated(lags))stop("lags must be distinct positive integers.",call.=FALSE)
  .autodesn_positive(calendar_scale,"calendar_scale");.autodesn_integer(cache_size,"cache_size")
  list(lags=as.integer(lags),prior=match.arg(prior),calendar_scale=calendar_scale,cache_size=as.integer(cache_size))
}

#' Seasonal period averaging controls
#' @param periods Distinct periods in observation-index units; numeric(0) disables seasonality.
#' @param harmonics Maximum Fourier order, excluding the Nyquist term.
#' @param prior Positive period masses; NULL is uniform over declared periods.
#' @param ... Unknown controls are rejected.
#' @return Validated seasonal controls. Supplied single periods represent known-calendar information.
#' @export
autodesn_seasonal_control <- function(periods=numeric(0),harmonics=16L,prior=NULL,...) {
  if(length(list(...)))stop("Unknown seasonal controls.",call.=FALSE)
  if(!is.numeric(periods)||any(!is.finite(periods)|periods<=2)||anyDuplicated(periods))stop("periods must be distinct finite numbers greater than two.",call.=FALSE)
  .autodesn_integer(harmonics,"harmonics")
  if(is.null(prior))prior<-rep(1,length(periods))
  if(!is.numeric(prior)||length(prior)!=length(periods)||any(!is.finite(prior)|prior<=0))stop("period prior must have positive finite masses.",call.=FALSE)
  if(length(prior))prior<-prior/max(prior)/sum(prior/max(prior))
  list(periods=as.numeric(periods),harmonics=as.integer(harmonics),prior=prior)
}

#' Conditional volatility controls for augmented AutoDESN
#' @param type Constant noise or stationary latent Gaussian log volatility.
#' @param seasonal Whether log volatility includes four centered Fourier harmonics.
#' @param phi_shape Beta prior shapes for (phi+1)/2.
#' @param omega_sd Half-normal prior SD for stationary log-volatility SD.
#' @param initial_phi,initial_omega Initial persistence and stationary SD.
#' @param ... Unknown controls are rejected.
#' @return A proper variance-model specification.
#' @export
autodesn_variance_control <- function(type=c("constant","sv"),seasonal=FALSE,phi_shape=c(10,1.5),omega_sd=.5,initial_phi=.8,initial_omega=.2,...) {
  if(length(list(...)))stop("Unknown variance controls.",call.=FALSE)
  type<-match.arg(type);.autodesn_flag(seasonal,"seasonal")
  if(length(phi_shape)!=2||any(!is.finite(phi_shape)|phi_shape<=0))stop("phi_shape must contain two positive values.",call.=FALSE)
  .autodesn_positive(omega_sd,"omega_sd");.autodesn_positive(initial_omega,"initial_omega")
  if(length(initial_phi)!=1||!is.finite(initial_phi)||abs(initial_phi)>=1)stop("initial_phi must be inside (-1,1).",call.=FALSE)
  if(type=="constant"&&seasonal)stop("Seasonal variance requires type='sv'.",call.=FALSE)
  list(type=type,seasonal=seasonal,phi_shape=phi_shape,omega_sd=omega_sd,initial_phi=initial_phi,initial_omega=initial_omega)
}

.ext_fourier <- function(time,period,harmonics) {
  K<-min(harmonics,floor((period-1)/2))
  if(K<1L)return(matrix(numeric(0),length(time),0L))
  a<-outer(time-1,seq_len(K),function(t,k)2*pi*t*k/period)
  S<-matrix(0,length(time),2*K);S[,seq(1,2*K,2)]<-sin(a);S[,seq(2,2*K,2)]<-cos(a)
  colnames(S)<-as.vector(rbind(paste0("sin",seq_len(K)),paste0("cos",seq_len(K))))
  S
}
.ext_geometry <- function(x,tol) {
  g<-.autodesn_feature_fit(x,TRUE,tol)
  list(X=g$features,center=g$feature_center,scale=g$feature_scale,active=g$active_features,raw_d=g$raw_d)
}
.ext_apply <- function(g,x) {
  x<-as.matrix(x);if(ncol(x)!=g$raw_d||any(!is.finite(x)))stop("Invalid augmented feature dimensions.",call.=FALSE)
  if(!length(g$active))return(matrix(numeric(0),nrow(x),0L))
  sweep(sweep(x[,g$active,drop=FALSE],2,g$center[g$active],"-"),2,g$scale[g$active],"/")
}

#' Add frozen lag and calendar blocks to an existing AutoDESN bank
#' @param bank A standardized reservoir bank with common scored rows.
#' @param readout_control,seasonal_control Controls from the corresponding constructors.
#' @return An augmented bank retaining the original architecture prior and reservoir definitions.
#' @export
autodesn_extend_bank <- function(bank,readout_control=NULL,seasonal_control=NULL) {
  if(!inherits(bank,"autodesn_bank")||inherits(bank,"autodesn_extended_bank"))stop("Supply an unextended AutoDESN bank.",call.=FALSE)
  rc<-.ext_control(readout_control,autodesn_readout_control);sc<-.ext_control(seasonal_control,autodesn_seasonal_control)
  if(!isTRUE(bank$standardize_features)||isTRUE(bank$normalize_features))stop("Extensions require standardize_features=TRUE and normalize_features=FALSE.",call.=FALSE)
  times<-bank$keep_idx
  if(is.null(times))times<-seq_len(bank$n)
  if(length(rc$lags)) {
    if(is.null(bank$history_scaled)||min(times)<=max(rc$lags))stop("Direct lags require sufficient unscored observed history.",call.=FALSE)
    L<-vapply(rc$lags,function(k)bank$history_scaled[times-k],numeric(bank$n));L<-matrix(L,bank$n,length(rc$lags))
  } else L<-matrix(numeric(0),bank$n,0)
  lag<-.ext_geometry(L,bank$feature_sd_tol)
  periods<-if(length(sc$periods))sc$periods else NA_real_
  calendar<-lapply(periods,function(P)if(is.na(P)).ext_geometry(matrix(numeric(0),bank$n,0),bank$feature_sd_tol) else .ext_geometry(.ext_fourier(times,P,sc$harmonics),bank$feature_sd_tol))
  dmax<-max(vapply(bank$models,function(m)m$raw_d,0L));smax<-max(vapply(calendar,`[[`,0L,"raw_d"))
  initial<-if(!is.null(bank$templates))lapply(bank$templates,function(t)lapply(t$states$H_all,function(h)as.numeric(h[nrow(h),]))) else NULL
  ext<-list(readout=rc,seasonal=sc,periods=periods,period_prior=if(length(sc$prior))sc$prior else 1,lag=lag,calendar=calendar,times=times,
    reservoir_slots=dmax,calendar_slots=smax,dimension=length(rc$lags)+dmax+smax,fit_origin=length(bank$history),initial_states=initial,
    training_history=bank$history,training_scaled=bank$history_scaled)
  ext$id<-digest::digest(list(y=bank$y,X=lapply(bank$models,`[[`,"X"),prior=bank$prior,ext=ext,preprocessing=bank$preprocessing),algo="sha256")
  bank$extension<-ext;class(bank)<-c("autodesn_extended_bank",class(bank));bank
}

.ext_design <- function(bank,m,p) {
  e<-bank$extension;res<-bank$models[[m]];S<-e$calendar[[p]];nl<-ncol(e$lag$X);nr<-res$d;ns<-ncol(S$X)
  X<-cbind(1,e$lag$X,res$X[,-1L,drop=FALSE],S$X)
  slots<-c(e$lag$active,length(e$readout$lags)+res$active_features,length(e$readout$lags)+e$reservoir_slots+S$active)
  groups<-c(rep("lag",nl),rep("reservoir",nr),rep("calendar",ns))
  gaussian<-e$readout$prior=="grouped" & groups=="calendar"
  frequency<-if(ns)rep(seq_len(S$raw_d/2),each=2)[S$active] else numeric(0)
  gv<-c(rep(NA_real_,nl+nr),e$readout$calendar_scale^2/(1+(frequency/4)^4))
  list(X=X,XtX=crossprod(X),Xty=as.vector(crossprod(X,bank$y)),d=ncol(X)-1L,slots=slots,groups=groups,gaussian=gaussian,gaussian_variance=gv)
}
.ext_logv <- function(design,ell,logu,logc2,tau0,beta_prior,ridge,intercept_variance) {
  v<-rep(-log(ridge),design$d)
  if(beta_prior=="rhs") {
    group<-if(length(logu)==1L)rep(1L,design$d) else match(design$groups,c("lag","reservoir"))
    active<-which(!design$gaussian)
    v[active]<-.autodesn_rhs_log_variance(ell[design$slots[active]],logu[group[active]],logc2,tau0[group[active]])
  }
  if(any(design$gaussian))v[design$gaussian]<-log(design$gaussian_variance[design$gaussian])
  c(log(intercept_variance),v)
}
.ext_gaussian <- function(design,y,logd,logv,backend="R") {
  if(length(logd)==1L)logd<-rep(logd,length(y))
  if(length(logd)!=length(y)||any(!is.finite(logd)))stop("Invalid observation log variances.",call.=FALSE)
  if(backend=="cpp")return(autodesn_weighted_gaussian_cpp(design$X,y,logd,logv))
  if(all(logd==logd[1]))return(.autodesn_rhs_gaussian_R(design,y,exp(logd[1]),logv))
  sw<-exp(-logd/2);X<-design$X*sw;z<-y*sw
  g<-.autodesn_rhs_gaussian_R(list(X=X,XtX=crossprod(X),Xty=as.vector(crossprod(X,z))),z,1,logv)
  g$log_evidence<-g$log_evidence-.5*sum(logd);g
}
.ext_ar1 <- function(z,phi) {
  if(length(z)<2L)return(z)
  c(z[1],as.numeric(stats::filter(sqrt(1-phi^2)*z[-1],phi,method="recursive",init=z[1])))
}
.ext_ar1_log <- function(u,phi) {
  if(!is.finite(phi)||abs(phi)>=1)return(-Inf)
  stats::dnorm(u[1],log=TRUE)+sum(stats::dnorm(u[-1],phi*u[-length(u)],sqrt(1-phi^2),log=TRUE))
}
.ext_ellipse <- function(x,prior_draw,loglik,max_shrink=10000L) {
  level<-loglik(x)+log(stats::runif(1));angle<-stats::runif(1,0,2*pi);lo<-angle-2*pi;hi<-angle
  for(k in seq_len(max_shrink)) {
    z<-x*cos(angle)+prior_draw*sin(angle)
    if(loglik(z)>=level)return(z)
    if(angle<0)lo<-angle else hi<-angle
    angle<-stats::runif(1,lo,hi)
  }
  stop("Elliptical slice budget exhausted.",call.=FALSE)
}
.ext_iglog <- function(z,a,b)a*log(b)-lgamma(a)-a*z-b*exp(-z)
.ext_sv_w <- function(bank,p) {
  P<-bank$extension$periods[p]
  if(is.na(P))stop("Seasonal SV requires a declared period model.",call.=FALSE)
  S<-.ext_fourier(bank$extension$times,P,4L)
  sweep(S,2,colMeans(S),"-")
}

.ext_fit <- function(bank,n_burn,n_mcmc,thin,intercept_variance,a_sigma,b_sigma,a_lambda,b_lambda,learn_ridge,ridge_precision,initial_variance,seed,beta_prior,rhs_control,model_control,backend,variance_control) {
  if(!inherits(bank,"autodesn_extended_bank"))bank<-autodesn_extend_bank(bank)
  vc<-.ext_control(variance_control,autodesn_variance_control);rc<-.ext_control(rhs_control,autodesn_rhs_control)
  if(length(rc$tau0)!=1L)stop("Extended RHS uses a scalar tau0; grouped scales have separate sampled multipliers.",call.=FALSE)
  .ext_named(model_control,c("method","moves","proposal","period_proposal","initial_model","initial_period","joint_moves","joint_scale_sd","rb_every","save_draws","joint_proposal"),"extended model")
  mc<-utils::modifyList(list(method="mh",moves=2L,proposal=bank$prior,period_proposal=bank$extension$period_prior,initial_model=1L,initial_period=1L,joint_moves=1L,joint_scale_sd=.4,rb_every=0L,save_draws=Inf),model_control)
  if(!mc$method%in%c("mh","categorical"))stop("Unknown architecture method.",call.=FALSE)
  if(length(mc$save_draws)!=1L||is.na(mc$save_draws)||mc$save_draws<1||(!is.infinite(mc$save_draws)&&mc$save_draws!=floor(mc$save_draws)))stop("save_draws must be a positive integer or Inf.",call.=FALSE)
  if(mc$rb_every!=0L)stop("Extended sampler reports occupancies; rb_every must be zero.",call.=FALSE)
  M<-length(bank$models);NP<-length(bank$extension$periods)
  for(nm in c("n_burn","n_mcmc","thin")) .autodesn_integer(get(nm),nm,if(nm=="n_burn")0L else 1L)
  for(nm in c("intercept_variance","a_sigma","b_sigma","a_lambda","b_lambda","ridge_precision")) .autodesn_positive(get(nm),nm)
  for(nm in c("moves","joint_moves")) .autodesn_integer(mc[[nm]],nm,0L)
  .autodesn_positive(mc$joint_scale_sd,"joint_scale_sd");.autodesn_flag(learn_ridge,"learn_ridge")
  for(nm in c("proposal","period_proposal")) {
    q<-mc[[nm]];expected<-if(nm=="proposal")M else NP
    if(length(q)!=expected||any(!is.finite(q)|q<=0))stop("Proposal must have full positive support.",call.=FALSE)
    mc[[nm]]<-q/max(q)/sum(q/max(q))
  }
  for(nm in c("initial_model","initial_period")) {
    .autodesn_integer(mc[[nm]],nm);if(mc[[nm]]>if(nm=="initial_model")M else NP)stop("Invalid initial model/period.",call.=FALSE)
  }
  if(vc$seasonal&&anyNA(bank$extension$periods))stop("Seasonal SV needs calendar periods.",call.=FALSE)
  available<-FALSE
  if(backend!="R"&&exists("autodesn_weighted_gaussian_cpp",mode="function")) {
    available<-!inherits(try(autodesn_weighted_gaussian_cpp(matrix(1,1,1),0,0,0),silent=TRUE),"try-error")
  }
  if(tolower(backend)=="auto")backend<-if(available)"cpp" else "R"
  if(backend=="cpp"&&!available)stop("The weighted C++ backend is unavailable; compile/install this checkout or use backend='R'.",call.=FALSE)
  target<-list(bank_id=bank$extension$id,beta_prior=beta_prior,readout=bank$extension$readout,seasonal=bank$extension$seasonal,variance=vc[setdiff(names(vc),c("initial_phi","initial_omega"))],
    rhs=rc[c("tau0","slab_scale","slab_df","learn_global","learn_slab","fixed_local_scales")],intercept_variance=intercept_variance,a_sigma=a_sigma,b_sigma=b_sigma,
    a_lambda=a_lambda,b_lambda=b_lambda,learn_ridge=learn_ridge,fixed_ridge=if(!learn_ridge)ridge_precision else NULL,
    fixed_global=if(!rc$learn_global)rc$initial_global else NULL,fixed_slab=if(!rc$learn_slab)if(is.null(rc$initial_slab))rc$slab_scale^2 else rc$initial_slab else NULL)
  target_id<-digest::digest(target,algo="sha256")
  .autodesn_seed(seed,function() {
    G<-if(bank$extension$readout$prior=="flat")1L else 2L
    if(!is.null(mc$joint_proposal)) {
      jp<-mc$joint_proposal;jp$chol<-jp$wide_chol<-NULL
      mc$joint_proposal<-do.call(autodesn_extended_proposal,jp)
      if(beta_prior!="rhs"||!rc$learn_global||!rc$learn_slab||nrow(mc$joint_proposal$center)!=M||ncol(mc$joint_proposal$center)!=G+2L)stop("Joint independence proposal requires sampled RHS scales and an M by (G+2) center.",call.=FALSE)
    }
    logu<-rep(log(rc$initial_global),G);tau0<-rep(rc$tau0,G);logc2<-log(if(is.null(rc$initial_slab))rc$slab_scale^2 else rc$initial_slab)
    fixed_local<-rc$fixed_local_scales
    if(!is.null(fixed_local)&&!length(fixed_local)%in%c(1L,bank$extension$dimension))stop("fixed_local_scales must be scalar or match the extended auxiliary dimension.",call.=FALSE)
    ell<-if(is.null(fixed_local))rep(0,bank$extension$dimension) else log(rep_len(fixed_local,bank$extension$dimension));aux<-rep(0,length(ell))
    s2<-if(is.null(initial_variance))stats::var(bank$y) else initial_variance;.autodesn_positive(s2,"initial_variance")
    m<-mc$initial_model;p<-mc$initial_period;u<-rep(0,bank$n);phi<-vc$initial_phi;omega<-if(vc$type=="sv")vc$initial_omega else 0
    gamma<-rep(0,if(vc$seasonal)8L else 0L);gvar<-rep(.25^2/(1+(seq_len(4)/2)^4),each=2)
    cache<-new.env(parent=emptyenv());lru<-character();evaluations<-0L;accepted<-proposed<-0L
    design<-function(m,p) {
      key<-paste(m,p,sep=":")
      if(exists(key,cache,inherits=FALSE)){lru<<-c(setdiff(lru,key),key);return(get(key,cache))}
      d<-.ext_design(bank,m,p);assign(key,d,cache);lru<<-c(lru,key)
      if(length(lru)>bank$extension$readout$cache_size){rm(list=lru[1],envir=cache);lru<<-lru[-1]};d
    }
    offset<-function(p)if(length(gamma))as.vector(.ext_sv_w(bank,p)%*%gamma) else rep(0,bank$n)
    evaluate<-function(m,p,ls=log(s2),lu=logu,lc=logc2) {
      d<-design(m,p);evaluations<<-evaluations+1L
      logv<-.ext_logv(d,ell,lu,lc,tau0,beta_prior,ridge_precision,intercept_variance)
      g<-if(vc$type=="constant"&&backend=="cpp")autodesn_rhs_gaussian_cpp(d$XtX,d$Xty,sum(bank$y^2),exp(ls),logv,d$X,bank$y) else .ext_gaussian(d,bank$y,ls+offset(p)+omega*u,logv,backend)
      list(g=g,d=d,logd=ls+offset(p)+omega*u)
    }
    scaleprior<-function(ls,lu,lc) .ext_iglog(ls,a_sigma,b_sigma)+if(beta_prior=="rhs")sum(.autodesn_rhs_log_hc_log(lu))+.ext_iglog(lc,rc$slab_df/2,rc$slab_df*rc$slab_scale^2/2) else 0
    retained<-seq.int(n_burn+1L,n_burn+n_mcmc,by=thin);K<-length(retained)
    keep<-logical(n_burn+n_mcmc);keep[retained]<-TRUE
    draws<-data.frame(iteration=retained,model=integer(K),period_index=integer(K),variance=numeric(K),ridge_precision=numeric(K),log_slab=numeric(K),phi=numeric(K),omega=numeric(K),intercept=numeric(K),fitted_rms=numeric(K),edf=numeric(K))
    for(g in seq_len(G))draws[[paste0("log_global_",g)]]<-numeric(K)
    probe<-unique(as.integer(round(seq(1,bank$n,length.out=min(8L,bank$n)))))
    snapshots<-unique(as.integer(round(seq(1,K,length.out=min(K,mc$save_draws)))))
    saved_slot<-integer(K);saved_slot[snapshots]<-seq_along(snapshots)
    beta<-local<-states<-vector("list",length(snapshots));probes<-matrix(0,K,length(probe));k<-0L;began<-proc.time()[3]
    for(it in seq_len(n_burn+n_mcmc)) {
      cur<-evaluate(m,p)
      if(mc$method=="categorical") {
        w<-matrix(0,M,NP);for(a in seq_len(M))for(b in seq_len(NP))w[a,b]<-log(bank$prior[a])+log(bank$extension$period_prior[b])+evaluate(a,b)$g$log_evidence
        index<-sample.int(M*NP,1,prob=.autodesn_softmax(as.vector(w)));m<-((index-1L)%%M)+1L;p<-((index-1L)%/%M)+1L;cur<-evaluate(m,p)
      } else if(mc$moves)for(j in seq_len(mc$moves)) {
        a<-sample.int(M,1,prob=mc$proposal);b<-sample.int(NP,1,prob=mc$period_proposal);nxt<-evaluate(a,b)
        ratio<-nxt$g$log_evidence-cur$g$log_evidence+log(bank$prior[a]/bank$prior[m])+log(bank$extension$period_prior[b]/bank$extension$period_prior[p])+log(mc$proposal[m]/mc$proposal[a])+log(mc$period_proposal[p]/mc$period_proposal[b]);proposed<-proposed+1L
        if(log(stats::runif(1))<min(0,ratio)){m<-a;p<-b;cur<-nxt;accepted<-accepted+1L}
      }
      if(mc$joint_moves)for(j in seq_len(mc$joint_moves)) {
        a<-sample.int(M,1,prob=mc$proposal);b<-sample.int(NP,1,prob=mc$period_proposal)
        reverse_forward<-0
        if(is.null(mc$joint_proposal)) {
          ls<-log(s2)+stats::rnorm(1,sd=mc$joint_scale_sd)
          lu<-if(beta_prior=="rhs"&&rc$learn_global)logu+stats::rnorm(G,sd=mc$joint_scale_sd) else logu
          lc<-if(beta_prior=="rhs"&&rc$learn_slab)logc2+stats::rnorm(1,sd=mc$joint_scale_sd) else logc2
        } else {
          zz<-.ext_joint_draw(a,mc$joint_proposal);ls<-zz[1L];lu<-zz[1L+seq_len(G)];lc<-zz[G+2L]
          reverse_forward<-.ext_joint_logq(c(log(s2),logu,logc2),m,mc$joint_proposal)-.ext_joint_logq(zz,a,mc$joint_proposal)
        }
        nxt<-evaluate(a,b,ls,lu,lc)
        ratio<-nxt$g$log_evidence-cur$g$log_evidence+scaleprior(ls,lu,lc)-scaleprior(log(s2),logu,logc2)+reverse_forward+log(bank$prior[a]/bank$prior[m])+log(bank$extension$period_prior[b]/bank$extension$period_prior[p])+log(mc$proposal[m]/mc$proposal[a])+log(mc$period_proposal[p]/mc$period_proposal[b]);proposed<-proposed+1L
        if(log(stats::runif(1))<min(0,ratio)){m<-a;p<-b;s2<-exp(ls);logu<-lu;logc2<-lc;cur<-nxt;accepted<-accepted+1L}
      }
      # Mandatory redraw after all collapsed moves, before any beta-conditioned step.
      B<-.autodesn_rhs_beta_draw(cur$g,stats::rnorm(length(cur$g$mean)));mu<-as.vector(cur$d$X%*%B);residual<-bank$y-mu
      if(vc$type=="sv") {
        ll<-function(z)-.5*sum(z+residual^2/s2*exp(-z))
        off<-offset(p);u<-.ext_ellipse(u,.ext_ar1(stats::rnorm(bank$n),phi),function(x)ll(off+omega*x))
        sl<-function(x,f).autodesn_rhs_slice(x,f,rc$slice_width,rc$slice_steps,rc$slice_max_shrink)$value
        z<-sl(stats::qlogis((phi+1)/2),function(z){pr<-stats::plogis(z);f<-2*pr-1;.ext_ar1_log(u,f)+stats::dbeta(pr,vc$phi_shape[1],vc$phi_shape[2],log=TRUE)+stats::plogis(z,log.p=TRUE)+stats::plogis(-z,log.p=TRUE)})
        phi<-2*stats::plogis(z)-1
        omega<-exp(sl(log(omega),function(z)ll(offset(p)+exp(z)*u)+stats::dnorm(exp(z),0,vc$omega_sd,log=TRUE)+log(2)+z))
        if(length(gamma)) {
          W<-.ext_sv_w(bank,p);gamma<-.ext_ellipse(gamma,stats::rnorm(length(gamma),sd=sqrt(gvar)),function(g)ll(as.vector(W%*%g)+omega*u))
        }
      }
      s2<-1/stats::rgamma(1,a_sigma+bank$n/2,rate=b_sigma+.5*sum(residual^2*exp(-offset(p)-omega*u)))
      if(beta_prior=="ridge") {
        ids<-which(!cur$d$gaussian)+1L
        if(learn_ridge)ridge_precision<-stats::rgamma(1,a_lambda+length(ids)/2,rate=b_lambda+sum(B[ids]^2)/2)
      } else {
        active<-which(!cur$d$gaussian);group<-if(G==1L)rep(1L,cur$d$d) else match(cur$d$groups,c("lag","reservoir"))
        for(g in seq_len(G)) {
          ix<-active[group[active]==g];slot<-cur$d$slots[ix]
          if(length(ix)&&is.null(fixed_local)) {
            f<-if(backend=="cpp")autodesn_rhs_local_cpp else .autodesn_rhs_local_R
            z<-f(ell[slot],aux[slot],B[ix+1L],log(tau0[g])+logu[g],logc2,rc$local_max_attempts);ell[slot]<-z$log_local;aux[slot]<-z$log_aux
          }
          if(rc$learn_global)logu[g]<-.autodesn_rhs_slice(logu[g],function(z).autodesn_rhs_log_scale_target(ell[slot],z,logc2,B[ix+1L],tau0[g],rc$slab_df,rc$slab_scale),rc$slice_width,rc$slice_steps,rc$slice_max_shrink)$value
        }
        inactive<-setdiff(seq_along(ell),cur$d$slots[active]);if(length(inactive)&&is.null(fixed_local)) {ell[inactive]<-log(abs(stats::rcauchy(length(inactive))));aux[inactive]<-.autodesn_rhs_logadd(0,-2*ell[inactive])-log(stats::rgamma(length(inactive),1))}
        if(rc$learn_slab)logc2<-.autodesn_rhs_slice(logc2,function(z){sum(vapply(seq_len(G),function(g){ix<-active[group[active]==g];.autodesn_rhs_log_scale_target(ell[cur$d$slots[ix]],logu[g],z,B[ix+1L],tau0[g],rc$slab_df,rc$slab_scale)-.ext_iglog(z,rc$slab_df/2,rc$slab_df*rc$slab_scale^2/2)},0))+.ext_iglog(z,rc$slab_df/2,rc$slab_df*rc$slab_scale^2/2)},rc$slice_width,rc$slice_steps,rc$slice_max_shrink)$value
      }
      if(beta_prior=="rhs"&&rc$interweave_global) {
        for(g in seq_len(G)) {
          ix<-active[group[active]==g];slot<-cur$d$slots[ix]
          iw<-.autodesn_rhs_interweave(ell[slot],logu[g],rc$slice_width,rc$slice_steps,rc$slice_max_shrink)
          ell[slot]<-iw$log_local;aux[slot]<-iw$log_aux;logu[g]<-iw$log_global
        }
      }
      if(keep[it]) {
        k<-k+1L;draws[k,2:11]<-c(m,p,s2,ridge_precision,logc2,phi,omega,B[1],sqrt(mean(mu^2)),NA_real_)
        for(g in seq_len(G))draws[k,paste0("log_global_",g)]<-logu[g]
        # The smoother trace is conditional on the Gaussian step's scales, labeled accordingly.
        draws$edf[k]<-length(B)-sum(backsolve(cur$g$chol,diag(length(B)))^2)
        slot<-saved_slot[k]
        if(slot){beta[[slot]]<-B;local[[slot]]<-ell[cur$d$slots];states[[slot]]<-list(gamma=gamma,terminal=u[length(u)])}
        probes[k,]<-mu[probe]
      }
    }
    # edf is only a Gaussian-step diagnostic; recompute in validation at matching states.
    summary<-cbind(bank$model_info,prior_probability=bank$prior,posterior_probability=tabulate(draws$model,M)/K)
    structure(list(bank=bank,draws=draws[snapshots,,drop=FALSE],trace=draws,beta=beta,local=local,volatility=states,probes=probes,probe_rows=probe,model_summary=summary,
      period_summary=data.frame(period=bank$extension$periods,prior=bank$extension$period_prior,posterior=tabulate(draws$period_index,NP)/K),
      controls=list(target=target,target_id=target_id,rhs_control=rc,variance_control=vc,model_control=mc,backend=backend,n_burn=n_burn,n_mcmc=n_mcmc,thin=thin,seed=seed),
      computation=list(elapsed_seconds=unname(proc.time()[3]-began),evidence_evaluations=evaluations,proposals=proposed,acceptances=accepted),
      meta=list(likelihood_family="normal",beta_prior_type=paste0("independent_",beta_prior),inference_method="extended_collapsed_mh",qualified=FALSE)),class=c("autodesn_extended_fit","autodesn_fit"))
  })
}
