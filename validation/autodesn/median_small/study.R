source('validation/autodesn/median_small/common.R')
args<-commandArgs(TRUE);stage<-args[1L];ms_load(identical(stage,'fit'))
cfg<-ms_config();out<-file.path(ms_root,'output');ev<-file.path(ms_root,'evidence')
dir.create(out,recursive=TRUE,showWarnings=FALSE);dir.create(ev,recursive=TRUE,showWarnings=FALSE)
write_csv<-function(x,name) write.csv(x,file.path(out,name),row.names=FALSE)

if(stage=='generate') {
  stopifnot(!file.exists(file.path(out,'data.csv')))
  ms_json(cfg,file.path(ms_root,'configuration.json'))
  d<-ms_generate(cfg);write_csv(d,'data.csv');write_csv(ms_grid(),'reservoir_specs.csv')
  ms_json(list(complete=TRUE,seed=cfg$seed,n=nrow(d),data_sha256=ms_hash(file.path(out,'data.csv')),
    source_sha256=ms_sources(),R=R.version.string,scope='One frozen development series; no selection scores viewed'),file.path(ev,'generation.json'))
}
if(stage=='screen') {
  d<-read.csv(file.path(out,'data.csv'));y<-d$y[1:cfg$refit] # No test observations/truth passed to screening.
  grid<-ms_grid();rows<-list();start<-proc.time()[3]
  path<-file.path(out,'gaussian_coarse_scores.csv')
  signature<-digest::digest(list(config=cfg,common=ms_hash(file.path(ms_root,'common.R')),
    study=ms_hash(file.path(ms_root,'study.R')),y=y),algo='sha256')
  contract_path<-file.path(ev,'screen_contract.json')
  if(file.exists(path))stopifnot(jsonlite::read_json(contract_path)$signature==signature)
  else ms_json(list(signature=signature,heldout_read=FALSE),contract_path)
  prior_rows<-if(file.exists(path))read.csv(path) else NULL
  for(i in seq_len(nrow(grid))) {
    spec<-as.list(grid[i,]);
    if(!is.null(prior_rows)&&sum(prior_rows$reservoir_id==i)==length(cfg$ridge)) {
      rows<-c(rows,lapply(which(prior_rows$reservoir_id==i),function(k)prior_rows[k,,drop=FALSE]));next
    }
    begin<-proc.time()[3]
    b<-tryCatch(ms_build(y,spec,cfg$cutoff),error=function(e)e)
    build_seconds<-unname(proc.time()[3]-begin)
    for(lambda in cfg$ridge) {
      cid<-sprintf('r%03d_l%g',i,lambda);why<-'';score<-NA_real_
      if(inherits(b,'error'))why<-conditionMessage(b) else {
        t0<-proc.time()[3]
        f<-ms_gaussian(b,lambda)
        fit_seconds<-unname(proc.time()[3]-t0);t0<-proc.time()[3]
        score<-ms_row(b,f,cfg$val_origins,y,cfg$coarse_paths,400100L)
        forecast_seconds<-unname(proc.time()[3]-t0)
      }
      rows[[length(rows)+1L]]<-data.frame(candidate_id=cid,reservoir_id=i,precision=lambda,
        stage='coarse',paths=cfg$coarse_paths,origins=10L,horizon=60L,pairs=600L,
        validation_pinball=score,dimension=if(inherits(b,'error'))NA else ncol(b$X_fit),
        washout_error=if(inherits(b,'error'))NA else b$washout_error,
        construction_seconds=build_seconds,
        ridge_fit_seconds=if(nzchar(why))0 else fit_seconds,
        forecast_seconds=if(nzchar(why))0 else forecast_seconds,
        status=if(nzchar(why))'rejected' else 'ok',reason=why)
    }
    write.csv(do.call(rbind,rows),path,row.names=FALSE)
    cat(sprintf('COARSE %d/%d elapsed %.1fs\n',i,nrow(grid),proc.time()[3]-start));flush.console()
    rm(b);gc(FALSE)
  }
  coarse<-do.call(rbind,rows);good<-coarse[coarse$status=='ok'&is.finite(coarse$validation_pinball),]
  good<-good[order(good$validation_pinball,good$dimension,good$candidate_id),]
  stopifnot(nrow(good)>=cfg$finalists);short<-head(good,cfg$finalists);fine<-list()
  for(k in seq_len(nrow(short))) {
    r<-short[k,];spec<-as.list(grid[r$reservoir_id,]);t0<-proc.time()[3]
    b<-ms_build(y,spec,cfg$cutoff);r$construction_seconds<-unname(proc.time()[3]-t0);t0<-proc.time()[3]
    f<-ms_gaussian(b,r$precision);r$ridge_fit_seconds<-unname(proc.time()[3]-t0);t0<-proc.time()[3]
    r$stage<-'fine';r$paths<-cfg$fine_paths
    r$validation_pinball<-ms_row(b,f,cfg$val_origins,y,cfg$fine_paths,400100L)
    r$forecast_seconds<-unname(proc.time()[3]-t0)
    fine[[k]]<-r;cat('FINE',k,'/',nrow(short),'\n');flush.console()
  }
  fine<-do.call(rbind,fine);fine<-fine[order(fine$validation_pinball,fine$dimension,fine$candidate_id),]
  write_csv(fine,'gaussian_fine_scores.csv');best<-fine[1,]
  selected<-list(candidate=as.list(best),specification=as.list(grid[best$reservoir_id,]),
    selection='Observed validation median pinball across ten H60 origins; no truth/test selection',
    selected_before_test=TRUE,coarse_configurations=nrow(coarse),fine_configurations=nrow(fine),
    selection_input_sha256=digest::digest(y,algo='sha256'),source_sha256=ms_sources())
  ms_json(selected,file.path(out,'selected_specification.json'))
  ms_json(list(complete=TRUE,elapsed_seconds=unname(proc.time()[3]-start),
    Gaussian_objects_saved=FALSE,heldout_read=FALSE,selected_candidate=best$candidate_id,
    files=c('gaussian_coarse_scores.csv','gaussian_fine_scores.csv','reservoir_specs.csv','selected_specification.json')),
    file.path(ev,'screening.json'))
}
if(stage=='fit') {
  stopifnot(!file.exists(file.path(out,'al_posterior.rds')))
  d<-read.csv(file.path(out,'data.csv'));y<-d$y[1:cfg$refit]
  sel<-jsonlite::read_json(file.path(out,'selected_specification.json'),simplifyVector=TRUE)
  b<-ms_build(y,sel$specification,cfg$refit);initial<-ms_gaussian(b,sel$candidate$precision)
  init<-qdesn_normal_to_mcmc_init(initial,likelihood_family='al',beta_prior_type='rhs',p0=.5)
  controls<-exal_make_mcmc_control(n_burn=cfg$burn,n_mcmc=cfg$retained,thin=1,
    verbose=TRUE,progress_every=250,store_latent_draws=FALSE,store_rhs_draws=TRUE)
  prior<-exal_make_beta_prior('rhs',rhs=list(tau0=.001,nu=4,s=1,shrink_intercept=FALSE,intercept_prec=.1))
  set.seed(70261124L);start<-proc.time()[3]
  f<-exal_mcmc_fit(b$y_fit,b$X_fit,p0=.5,gamma_bounds=c(-1,1),likelihood_family='al',
    al_fixed_gamma=0,mcmc_control=controls,init=init,prior_sigma=list(a=3,b=1),beta_prior_obj=prior)
  sampler_seconds<-unname(proc.time()[3]-start)
  beta<-as.matrix(f$samp.beta);sig<-as.numeric(f$samp.sigma)
  stopifnot(nrow(beta)==cfg$retained,all(is.finite(beta)),all(is.finite(sig)),all(sig>0),
    identical(f$likelihood_family,'al'),all(as.numeric(f$samp.gamma)==0),is.null(f$samp.v),is.null(f$samp.s))
  # Compact retained posterior only. No n-by-draw latent arrays or Gaussian object.
  saved<-list(beta=beta,sigma=sig,tau=as.numeric(f$samp.tau),c2=as.numeric(f$samp.c2),
    last=f$last,RNG=.Random.seed,controls=f$control,prior=prior$hypers,
    source_sha256=ms_sources(),selected_specification=sel,session=capture.output(sessionInfo()),
    resume_supported=FALSE,scope='Last state is observational; driver has no certified resume API')
  saveRDS(saved,file.path(out,'al_posterior.rds'),compress='xz')
  ids<-unique(as.integer(round(seq(1,nrow(b$X_fit),length.out=8))))
  probes<-beta%*%t(b$X_fit[ids,,drop=FALSE])
  trace<-data.frame(iteration=seq_len(cfg$retained),sigma=sig,tau=saved$tau,
    slab_sd=sqrt(saved$c2),intercept=beta[,1],beta_lag1=beta[,match(ncol(b$raw$X)+1L,b$active_columns)])
  for(j in seq_len(ncol(probes)))trace[[paste0('median_probe',j)]]<-b$center+b$response_scale*probes[,j]
  trace$log_likelihood<-vapply(seq_len(nrow(beta)),function(j)
    -nrow(b$X_fit)*log(4*sig[j])-sum(abs(b$y_fit-as.numeric(b$X_fit%*%beta[j,])))/(2*sig[j]),0)
  locals<-as.matrix(f$samp.lambda)
  trace$log_joint<-trace$log_likelihood+vapply(seq_len(nrow(beta)),function(j){
    v<-1/(1/saved$c2[j]+1/(saved$tau[j]*locals[j,-1])^2)
    sum(dnorm(beta[j,-1],0,sqrt(v),log=TRUE))+dnorm(beta[j,1],0,sqrt(10),log=TRUE)+
      sum(log(2)+dcauchy(locals[j,-1],log=TRUE))+
      log(2)+dcauchy(saved$tau[j],scale=.001,log=TRUE)+
      2*log(2)-lgamma(2)-3*log(saved$c2[j])-2/saved$c2[j]+
      3*log(1)-lgamma(3)-4*log(sig[j])-1/sig[j]
    },0)
  write_csv(trace,'al_trace.csv')
  mu<-b$X_fit%*%t(beta);qs<-t(apply(mu,1,quantile,probs=c(.05,.5,.95),names=FALSE))
  fits<-data.frame(time=501:cfg$refit,observed=y[501:cfg$refit],
    true_median=d$median_one_step[501:cfg$refit],
    q05=b$center+b$response_scale*qs[,1],median=b$center+b$response_scale*qs[,2],q95=b$center+b$response_scale*qs[,3])
  write_csv(fits,'fitted_medians.csv')
  diag<-lapply(names(trace)[-1],function(nm){v<-trace[[nm]];ess<-as.numeric(coda::effectiveSize(v));
    batches<-colMeans(matrix(v,nrow=100));mcse<-sd(batches)/sqrt(length(batches));
    data.frame(parameter=nm,ESS=ess,MCSE=mcse,half_drift=mean(head(v,length(v)/2))-mean(tail(v,length(v)/2)))})
  diag<-do.call(rbind,diag);write_csv(diag,'al_diagnostics.csv')
  ms_json(list(complete=TRUE,chains=1L,burn=cfg$burn,retained=cfg$retained,
    elapsed_seconds=unname(proc.time()[3]-start),sampler_seconds=sampler_seconds,dimension=ncol(beta),
    maximum_feature_mean=max(abs(colMeans(b$X_fit[,-1]))),
    maximum_feature_sd_error=max(abs(apply(b$X_fit[,-1],2,sd)-1)),
    minimum_reported_ess=min(diag$ESS),Rhat=NULL,
    Rhat_reason='Single production chain; no between-chain convergence assessment',
    single_chain_screen_passed=all(diag$ESS>=100)&all(diag$MCSE[grepl('median_probe',diag$parameter)]<=.05*sd(y[501:cfg$refit])),
    sampler_diagnostics=f$diagnostics,prior=prior$hypers,
    coefficient_credible_interval_scope='Conditional median given observed histories; working AL posterior, not predictive intervals',
    posterior_sha256=ms_hash(file.path(out,'al_posterior.rds')),source_sha256=ms_sources()),file.path(ev,'fit.json'))
  rm(mu,f,initial,b);gc()
}
if(stage=='forecast') {
  d<-read.csv(file.path(out,'data.csv'));p<-readRDS(file.path(out,'al_posterior.rds'))
  sel<-p$selected_specification;b<-ms_build(d$y[1:cfg$refit],sel$specification,cfg$refit)
  # Validate computational precision on observed validation origins before reading test outcomes.
  mc<-list();nd<-cfg$forecast_paths
  for(o in tail(cfg$val_origins,2)) {
    set.seed(cfg$forecast_seed+o);ix<-sample.int(nrow(p$beta),nd,replace=TRUE)
    paths<-ms_paths(b,p$beta[ix,,drop=FALSE],ms_al_noise(p$sigma[ix]),o,d$y[1:o])
    delta<-max(abs(apply(paths[,1:1024],1,median)-apply(paths,1,median)))
    mc[[length(mc)+1]]<-data.frame(origin=o,paths_low=1024,paths_high=nd,max_median_difference=delta)
  }
  mc<-do.call(rbind,mc);write_csv(mc,'predictive_mc_validation.csv')
  # This is a computational check only: final AL parameters already use training+validation.
  # These are not out-of-sample AL validation performance scores.
  if(max(mc$max_median_difference)>.05*sd(d$y[501:cfg$refit]))nd<-4096L
  rows<-list();start<-proc.time()[3]
  for(o in cfg$test_origins) {
    # Rebuild deterministic states through observed origin, retaining final-training scalers.
    bo<-ms_build(d$y[1:o],sel$specification,cfg$refit,check_washout=FALSE)
    stopifnot(isTRUE(all.equal(bo$scale_info,b$scale_info,tolerance=1e-12)))
    set.seed(cfg$forecast_seed+o);ix<-sample.int(nrow(p$beta),nd,replace=TRUE)
    paths<-ms_paths(bo,p$beta[ix,,drop=FALSE],ms_al_noise(p$sigma[ix]),o,d$y[1:o])
    r<-ms_summary(paths,o);r$true_median<-ms_truth(d$z[o],o,1:60)
    r$observed<-d$y[r$time]
    r$median_MCSE<-apply(paths,1,function(v){n<-floor(length(v)/8);sd(apply(matrix(v[1:(n*8)],n,8),2,median))/sqrt(8)})
    rows[[length(rows)+1]]<-r;cat('FORECAST',o,'paths',nd,'\n');flush.console()
  }
  pred<-do.call(rbind,rows);stopifnot(nrow(pred)==600,identical(sort(pred$time),2901:3500),!anyDuplicated(pred$time))
  write_csv(pred,'test_forecasts.csv')
  ms_json(list(complete=TRUE,origins=cfg$test_origins,horizon=60L,pairs=nrow(pred),paths_per_origin=nd,
    observed_state_updates_between_origins=TRUE,parameters_refit_at=2900L,parameters_updated_between_origins=FALSE,
    future_observations_within_forecast=FALSE,elapsed_seconds=unname(proc.time()[3]-start),
    posterior_sha256=ms_hash(file.path(out,'al_posterior.rds')),source_sha256=ms_sources(),
    interval_scope='Working-AL posterior predictive intervals; no calibrated coverage claim'),file.path(ev,'forecast.json'))
}
