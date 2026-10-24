# Same-prior computational recovery after the first joint 3x128k control
# failed the frozen architecture-frequency-range gate. The prior, likelihood,
# designs and forecast budgets stay fixed. Proposal fitting uses training only.
source("validation/autodesn/nonlinear_heteroscedastic/helpers.R")
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1L,args[1]%in%c("requested","scaling_only"))
scenario<-args[1];stopifnot(scenario=="scaling_only");root<-nh_root;base<-file.path(root,"artifacts")
frozen_cfg<-nh_configuration();bank_contract<-readRDS(file.path(base,"standardized_bank/contract.rds"))
study<-jsonlite::fromJSON(file.path(root,"study.json"));sc<-study$scenarios[study$scenarios$id==scenario,,drop=FALSE]
sources<-list(list(path=file.path(base,"scaling_only_joint_initial/rhs"),attempt=4L))
draws<-list();source_records<-list();source_seconds<-source_pilots<-0
for(i in seq_along(sources)) {
 src<-sources[[i]];st<-jsonlite::fromJSON(file.path(src$path,"status.json"))
 stopifnot(isTRUE(st$fit_complete),!isTRUE(st$qualified),!file.exists(file.path(src$path,"scores.csv")))
 contract<-readRDS(file.path(src$path,"contract.rds"))
 old<-contract$contract$configuration
 stopifnot(identical(contract$contract$bank_id,bank_contract$id),
  identical(old$input_sha256,frozen_cfg$input_sha256),
  identical(old$dgp_source_sha256,frozen_cfg$dgp_source_sha256))
 stopifnot(old$rhs_control$tau0==1,old$rhs_control$slab_scale==2,old$rhs_control$slab_df==4)
 source_seconds<-source_seconds+st$timings$inference_seconds_all_attempts
 if(!is.null(st$timings$training_pilot_seconds)) source_pilots<-source_pilots+st$timings$training_pilot_seconds
 for(k in 1:3) {
  path<-file.path(src$path,paste0("attempt_",src$attempt),paste0("chain_",k,".rds"))
  saved<-readRDS(path);stopifnot(identical(saved$contract_id,contract$id))
  d<-saved$fit$draws;draws[[length(draws)+1L]]<-d[c("model","variance","log_global","log_slab")]
  source_records[[length(source_records)+1L]]<-list(path=path,sha256=digest::digest(file=path,algo="sha256"),contract_id=contract$id)
  rm(saved,d);gc(FALSE)
 }
}
training<-do.call(rbind,draws);rm(draws);gc(FALSE)
bank<-readRDS(file.path(base,"standardized_bank/bank.rds"));M<-length(bank$models)
stopifnot(identical(bank$keep_idx,501:2500),identical(as.numeric(bank$history),as.numeric(c1_data()$y[1:2500])))
counts<-tabulate(training$model,nbins=M);q<-.2*bank$prior+.8*counts/sum(counts);q<-q/sum(q)
Z<-cbind(log(training$variance),training$log_global,training$log_slab)
center<-matrix(NA_real_,M,3);shape<-array(NA_real_,c(3,3,M));df<-5
pooled<-cov(Z)+diag(c(.015,.15,.15)^2)
for(j in seq_len(M)) {
 ids<-which(training$model==j)
 if(length(ids)>=30L) {
  z<-Z[ids,,drop=FALSE];center[j,]<-colMeans(z);C<-cov(z)
  C<-.8*C+.2*diag(diag(C))+diag(c(.015,.15,.15)^2)
 } else {center[j,]<-colMeans(Z);C<-4*pooled}
 shape[,,j]<-C*(df-2)/df*1.2^2
}
joint<-autodesn_rhs_joint_proposal(center,shape,df=df,moves=2L,wide_weight=.1,
 wide_center=colMeans(Z),wide_scale=4*pooled)
cfg<-nh_configuration();cfg$standardized_study<-study
cfg$readout_standardization<-study[c("standardize_features","normalize_features","feature_sd_tol","interpretation")]
cfg$scenario<-as.list(sc);cfg$rhs_control<-c(list(tau0=sc$tau0,slab_scale=sc$slab_scale,slab_df=sc$slab_df),study$sampler)
cfg$rhs_seed<-sc$seed+200000L
cfg$attempts<-data.frame(n_burn=16000L,n_mcmc=128000L)
cfg$pilot<-list(n_burn=0L,n_mcmc=0L,chains=0L)
cfg$model_control<-list(method="mh",moves=study$model_moves,rb_every=study$rb_every,proposal=q,joint_proposal=joint)
cfg$joint_training_proposal<-list(frozen_before_production=TRUE,test_outcomes_used=FALSE,
 target_changed=FALSE,training_sources=source_records,training_inference_seconds=source_seconds,
 training_pilot_seconds=source_pilots,training_rows=501:2500,
 rule="0.2 prior +0.8 training occupancy; model-conditional log-scale Student-t mixture with full support",
 scaling_only_transport="Same-prior training source, without any scale transport; exact target correction retained.",
 original_shared_source_inference_seconds=old$joint_training_proposal$training_inference_seconds,
 original_shared_source_pilot_seconds=old$joint_training_proposal$training_pilot_seconds,
 recovery_reason="Original 3x128k fit failed the frozen architecture-frequency-range gate; no test forecasts issued. Proposal refitted on its training draws only.")
declaration<-jsonlite::fromJSON(file.path(root,"control_recovery.json"))
stopifnot(cfg$rhs_seed==declaration$base_seed,cfg$attempts$n_burn==declaration$burn_per_chain,
 cfg$attempts$n_mcmc==declaration$retained_per_chain,cfg$model_control$moves==declaration$model_moves,
 cfg$model_control$joint_proposal$moves==declaration$joint_moves)
cfg$same_prior_recovery_declaration<-declaration
cfg$extra_harness_source<-data.frame(path=file.path(root,"fit_control_recovery.R"),sha256=digest::digest(file=file.path(root,"fit_control_recovery.R"),algo="sha256"))
options<-rhs_options(character());options$method<-"rhs";options$backend<-"cpp";options$stage<-"fit";options$out<-file.path(base,scenario)
dir.create(options$out,recursive=TRUE,showWarnings=FALSE)
rhs_json(cfg,file.path(options$out,"configuration.json"))
write.csv(data.frame(model=seq_len(M),candidate=bank$model_info$candidate,prior=bank$prior,training_count=counts,proposal=q),file.path(options$out,"joint_training_proposal.csv"),row.names=FALSE)
rhs_save(joint,file.path(options$out,"joint_training_proposal.rds"))
# Require model-indicator diagnostics within every attempted budget, before
# creating a compact posterior. Independent rank/function checks follow.
original_diagnostics<-autodesn_diagnostics
autodesn_diagnostics<-function(fits) {
 d<-original_diagnostics(fits);d$nh_draws<-nrow(fits[[1L]]$draws);d
}
rejections<-file.path(options$out,"rhs/independent_rejected_budgets.json")
rejected<-if(file.exists(rejections)) jsonlite::fromJSON(rejections)$retained else integer()
original_gate<-rhs_diagnostic_gate
rhs_diagnostic_gate<-function(dg,cfg) {
 big<-dg$models$posterior_probability>=.01;m<-dg$models
 !(dg$nh_draws%in%rejected)&&original_gate(dg,cfg)&&all(is.finite(m$rhat_indicator[big]))&&
  all(is.finite(m$ess_indicator_spectral[big]))&&max(m$rhat_indicator[big])<=1.01&&
  min(m$ess_indicator_spectral[big])>=400
}
cp<-rhs_run_model(list(bank=bank,id=attr(bank,"comparison_bank_id"),load_seconds=0),cfg,options)
d<-file.path(options$out,"rhs");status<-jsonlite::fromJSON(file.path(d,"status.json"),simplifyVector=FALSE)
status$scenario<-scenario;status$timings$training_pilot_seconds<-0
status$timings$additional_same_prior_training_inference_seconds<-source_seconds
status$timings$shared_training_source_inference_seconds<-old$joint_training_proposal$training_inference_seconds
status$timings$shared_training_source_pilot_seconds<-old$joint_training_proposal$training_pilot_seconds
rhs_json(status,file.path(d,"status.json"))
if(is.null(cp$readout_beta)) {
 cp$readout_beta<-cp$beta
 cp$beta<-lapply(seq_along(cp$beta),function(k) as.vector(.autodesn_raw_beta(bank$models[[cp$draws$model[k]]],matrix(cp$readout_beta[[k]],1))))
 cp$bank$divisors[]<-1;cp$coefficient_transport<-"Frozen standardization to raw reservoir coefficients with intercept shift"
 public<-readRDS(file.path(d,paste0("attempt_",status$selected_attempt),"chain_1.rds"))$fit
 public$bank<-bank;public$draws<-cp$draws;public$beta<-cp$readout_beta
 ids<-1:192;noise<-c1_noise(cfg$innovation_seed,2500L,8L,192L,30L)
 direct<-forecast_paths.autodesn_fit(public,30L,draw_index=ids,inner_paths=8L,innovations=noise,backend="batched")
 thin<-cp;thin$draws<-cp$draws[ids,,drop=FALSE];thin$beta<-cp$beta[ids]
 states<-lapply(cp$bank$templates,function(t) t$states$H_last)
 ref<-hr_auto(thin,states,bank$history_scaled,30L,8L,noise)
 error<-max(abs(direct$yrep-ref$yrep),abs(direct$mu_draws-ref$mu_draws));stopifnot(error<1e-10)
 rhs_json(list(complete=TRUE,max_path_error=error,future_observations_used=FALSE),file.path(d,"transport_parity.json"))
 rhs_save(cp,file.path(d,"posterior_checkpoint.rds"))
}
cat(scenario,"joint architecture/scale fit passed R gates; independent screens required before forecasting.\n")
