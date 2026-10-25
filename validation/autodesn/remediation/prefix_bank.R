# Training-prefix bank construction through the existing candidate builder.
# Call after sourcing rhs_comparison/helpers.R from the verified builder tree.
remediation_prefix_compact_template <- function(template) {
  # Drop unused construction closures before checkpoint serialization. Numeric
  # maps, terminal states and every input transform remain exactly unchanged.
  clean<-template;clean$reservoir[c('w_dist','in_dist')]<-NULL
  clean$meta<-clean$meta[intersect(names(clean$meta),c('D','n','n_tilde','m','m_input','add_bias','input_mode','standardize_inputs','lag_center','lag_scale','input_bound','input_bound_divisor','win_scale_bias','win_scale_global','win_scale_lags','readout_spec'))]
  for(backend in c('serial','batched')){
    a<-.normal_desn_transition_engine(template,backend);b<-.normal_desn_transition_engine(clean,backend)
    history<-seq_len(max(1L,a$m+1L))/max(1L,a$m+1L)
    stopifnot(identical(a$input(history),b$input(history)))
    h<-template$states$H_last;u<-a$input(history)
    if(backend=='batched'){h<-lapply(h,function(v)matrix(v,length(v),2));u<-matrix(u,length(u),2)}
    stopifnot(identical(a$step(h,u),b$step(h,u)))
  }
  clean
}

remediation_prefix_warmup <- function(template,z,drop=500L) {
  n<-template$reservoir$n;m<-as.integer(template$meta$m_input);stopifnot(m<drop)
  expected<-unlist(lapply(template$states$H_all,function(h)as.numeric(h[drop,])))
  engine<-.normal_desn_transition_engine(c1_lean_template(template),'batched')
  max(vapply(c(-1,1),function(sign){
    states<-lapply(n,function(k)matrix(sign,k,1))
    lags<-if(m)matrix(rev(z[seq_len(m)]),m,1) else matrix(numeric(),0,1)
    for(t in seq.int(m+1L,drop)){
      u<-rbind(engine$win_scale_bias,engine$process_lags(lags)*engine$win_scale_global)
      states<-engine$step(states,u)$h
      if(m)lags<-rbind(z[t],lags[seq_len(m-1L),,drop=FALSE])
    }
    max(abs(unlist(states)-expected))
  },0))
}

remediation_prefix_bank <- function(y, cutoff, specifications, grid, directory,
                                    washout=500L, tolerance=1e-5, feature_sd_tol=1e-8) {
  stopifnot(length(cutoff)==1L,is.finite(cutoff),cutoff==as.integer(cutoff),
    cutoff<=length(y),cutoff>=washout+2L,length(specifications)==nrow(grid),
    is.character(names(specifications)),identical(names(specifications),grid$candidate),!anyDuplicated(grid$candidate))
  # Only these values enter construction or its reusable target contract.
  prefix<-as.numeric(y[seq_len(cutoff)]);stopifnot(all(is.finite(prefix)))
  cfg<-list(mode='full',washout=as.integer(washout),fit_start=as.integer(washout+1L),
    fit_end=as.integer(cutoff),n_train=as.integer(cutoff-washout),washout_tolerance=tolerance,
    feature_workers=1L,input_sha256=list(training_prefix=digest::digest(prefix,algo='sha256'),
      prefix_adapter=digest::digest(list(deparse(body(remediation_prefix_bank)),deparse(body(remediation_prefix_warmup)),deparse(body(remediation_prefix_compact_template)),deparse(body(.normal_desn_transition_engine))),algo='sha256')))
  # Rebind only the documented dataset/specification providers. The original
  # builder, admission calculation, depth-balanced prior and reservoir code run.
  e<-new.env(parent=environment(rhs_build_bank))
  e$input<-data.frame(time=seq_len(cutoff),y=prefix)
  e$definitions<-list(specs=specifications,grid=grid)
  e$c1_data<-evalq(function()input,e)
  e$rhs_specifications<-evalq(function(cfg)definitions,e)
  e$c1_warmup<-remediation_prefix_warmup
  original_save<-rhs_save
  e$rhs_save<-function(x,path){
    if(is.list(x)&&!is.null(x$template)&&!is.null(x$model))x$template<-remediation_prefix_compact_template(x$template)
    original_save(x,path)
  }
  builder<-rhs_build_bank;environment(builder)<-e
  raw<-builder(cfg,file.path(directory,'raw_bank'))
  id<-rhs_guard(file.path(directory,'standardized_bank'),list(raw_bank_id=raw$id,
    standardize_features=TRUE,normalize_features=FALSE,feature_sd_tol=feature_sd_tol,
    scaling_sha256=digest::digest(file='R/autodesn_scaling.R',algo='sha256')))
  path<-file.path(directory,'standardized_bank/bank.rds')
  if(file.exists(path)){
    b<-readRDS(path);stopifnot(identical(attr(b,'comparison_bank_id'),id));return(b)
  }
  b<-raw$bank
  features<-lapply(b$models,function(m)m$X[,-1L,drop=FALSE]*m$divisor)
  normalized<-autodesn_prepare_bank(b$y,features,model_info=b$model_info,model_prior=b$prior,
    normalize_features=FALSE,standardize_features=TRUE,feature_sd_tol=feature_sd_tol)
  b$models<-normalized$models;b$normalize_features<-FALSE;b$standardize_features<-TRUE
  b$feature_sd_tol<-feature_sd_tol;attr(b,'comparison_bank_id')<-id
  stopifnot(identical(b$keep_idx,seq.int(washout+1L,cutoff)),length(b$history)==cutoff,
    b$n==cutoff-washout,all(b$prior>0),abs(sum(b$prior)-1)<1e-12)
  audit<-do.call(rbind,lapply(seq_along(b$models),function(j){
    m<-b$models[[j]];F<-m$X[,-1L,drop=FALSE]
    data.frame(model=j,candidate=b$model_info$candidate[j],raw_slopes=m$raw_d,
      fitted_slopes=m$d,dropped=length(m$dropped_features),
      max_abs_mean=if(m$d)max(abs(colMeans(F))) else 0,
      max_sd_error=if(m$d)max(abs(apply(F,2,sd)-1)) else 0)
  }))
  stopifnot(max(audit$max_abs_mean)<1e-9,max(audit$max_sd_error)<1e-9)
  write.csv(audit,file.path(directory,'standardized_bank/feature_audit.csv'),row.names=FALSE)
  rhs_save(b,path)
  rhs_json(list(complete=TRUE,bank_id=id,cutoff=cutoff,washout=washout,
    scored_rows=range(b$keep_idx),candidates=length(specifications),admitted=length(b$models),
    candidate_names=names(specifications),admitted_names=b$model_info$candidate,
    prefix_sha256=cfg$input_sha256$training_prefix,unit_variance=TRUE,dimension_normalization=FALSE,
    maximum_center_error=max(audit$max_abs_mean),maximum_sd_error=max(audit$max_sd_error),
    reducer_policy='Original fixed identity or seeded random row-normalized projections; no PCA is fitted. All456 frozen production definitions use identity bridges.',
    feature_geometry_sha256=digest::digest(lapply(b$models,function(m)m[c('feature_center','feature_scale','active_features','raw_d')]),algo='sha256'),
    qualified=FALSE,forecast_allowed=FALSE),file.path(directory,'standardized_bank/status.json'))
  b
}
