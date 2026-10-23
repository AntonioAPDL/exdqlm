# Training-only computational recovery, using the existing exact-Hastings
# adapter pattern. Neither the RHS target nor any forecast setting changes.
source("validation/autodesn/nonlinear_heteroscedastic/helpers.R")
root<-nh_root;base<-file.path(root,"artifacts")
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1L,args[1]%in%c("requested","scaling_only"));scenario<-args[1]
study<-jsonlite::fromJSON(file.path(root,"study.json"));sc<-study$scenarios[study$scenarios$id==scenario,,drop=FALSE]
source_dir<-file.path(base,paste0(scenario,"_initial_proposal"),"rhs")
source_contract<-readRDS(file.path(source_dir,"contract.rds"))
cfg<-source_contract$contract$configuration
st<-jsonlite::fromJSON(file.path(source_dir,"status.json"))
stopifnot(isTRUE(st$fit_complete),!isTRUE(st$qualified),!file.exists(file.path(source_dir,"scores.csv")),
 cfg$fit_start==501L,cfg$fit_end==2500L,cfg$rhs_control$tau0==sc$tau0,
 cfg$rhs_control$slab_scale==sc$slab_scale,cfg$rhs_control$slab_df==sc$slab_df,
 isTRUE(cfg$readout_standardization$standardize_features),!cfg$readout_standardization$normalize_features)
for(name in names(cfg$input_sha256))
 stopifnot(identical(digest::digest(file=file.path(c1_root,"input",name),algo="sha256"),cfg$input_sha256[[name]]))
now<-rhs_source_manifest();stopifnot(identical(now,source_contract$contract$production_source))
bank<-readRDS(file.path(base,"standardized_bank/bank.rds"))
stopifnot(identical(attr(bank,"comparison_bank_id"),source_contract$contract$bank_id),identical(bank$keep_idx,501:2500))
bank_result<-list(bank=bank,id=attr(bank,"comparison_bank_id"),load_seconds=0)
path<-file.path(source_dir,"attempt_4/model_probabilities.csv");p<-read.csv(path)
stopifnot(identical(as.integer(p$model),seq_along(bank$models)),
 identical(as.character(p$candidate),as.character(bank$model_info$candidate)),
 isTRUE(all.equal(p$prior_probability,bank$prior,tolerance=1e-12)),all(is.finite(p$occupancy)),
 all(p$occupancy>=0),abs(sum(p$occupancy)-1)<1e-10)
q<-.2*bank$prior+.8*p$occupancy;q<-q/sum(q)
stopifnot(all(q>0),all(is.finite(q)),abs(sum(q)-1)<1e-12)
cfg$attempts<-data.frame(n_burn=10000L,n_mcmc=64000L)
cfg$pilot<-list(n_burn=0L,n_mcmc=0L,chains=0L,scope="No new pilots; fixed proposal from earlier completed training chains")
# Fresh predeclared production seeds follow the earlier seed schedule. They
# are separate from every chain used to estimate q; no seed search is done.
cfg$rhs_seed<-cfg$rhs_seed+50000L
cfg$model_control$proposal<-q
cfg$training_proposal<-list(rule="0.2 * original prior + 0.8 * completed training-chain occupancy",
 source_file=path,source_file_sha256=digest::digest(file=path,algo="sha256"),
 source_contract_id=source_contract$id,source_attempt=4L,
 source_inference_seconds_all_attempts=st$timings$inference_seconds_all_attempts,
 frozen_before_chain=TRUE,test_outcomes_used=FALSE,prior_or_likelihood_changed=FALSE,
 all_architectures_positive=TRUE,fresh_production_seeds=cfg$rhs_seed+1:3,
 adapter_sha256=digest::digest(file=file.path(root,"run_rebalanced.R"),algo="sha256"))
options<-rhs_options(character());options$method<-"rhs";options$backend<-"cpp"
options$stage<-"fit";options$out<-file.path(base,scenario)
dir.create(options$out,recursive=TRUE,showWarnings=FALSE)
rhs_json(cfg,file.path(options$out,"configuration.json"))
write.csv(data.frame(model=p$model,candidate=p$candidate,prior=bank$prior,
 source_occupancy=p$occupancy,proposal=q),file.path(options$out,"rebalanced_training_proposal.csv"),row.names=FALSE)
rhs_json(list(frozen_before_sampling=TRUE,reason="Prior budgets failed the architecture-frequency gate; short pilots severely underproposed some appreciable-mass architectures.",
 target_changed=FALSE,forecast_protocol_changed=FALSE,attempts=cfg$attempts,
 source=cfg$training_proposal),file.path(options$out,"extension_protocol.json"))
if("--validate-only"%in%commandArgs(trailingOnly=TRUE)) {
 cat("Training-only proposal validated; all",length(q),"architectures retain positive mass. No chains run.\n")
 quit(status=0)
}
cp<-rhs_run_model(bank_result,cfg,options)
d<-file.path(options$out,"rhs")
status<-jsonlite::fromJSON(file.path(d,"status.json"),simplifyVector=FALSE)
status$scenario<-scenario;status$timings$training_pilot_seconds<-0
status$timings$previous_training_source_seconds<-cfg$training_proposal$source_inference_seconds_all_attempts
rhs_json(status,file.path(d,"status.json"))
big<-cp$diagnostics$models$posterior_probability>=.01
md<-cp$diagnostics$models
pass<-all(is.finite(md$rhat_indicator[big]))&&all(is.finite(md$ess_indicator_spectral[big]))&&
 max(md$rhat_indicator[big])<=1.01&&min(md$ess_indicator_spectral[big])>=400
if(!pass) {
 s<-jsonlite::fromJSON(file.path(d,"status.json"));s$qualified<-FALSE;s$diagnostic_gates_passed<-FALSE
 rhs_json(s,file.path(d,"status.json"));cp$qualified<-FALSE;rhs_save(cp,file.path(d,"posterior_checkpoint.rds"))
 stop("Additional architecture R-hat/ESS gates failed; no forecasts issued")
}
if(is.null(cp$readout_beta)) {
 cp$readout_beta<-cp$beta
 cp$beta<-lapply(seq_along(cp$beta),function(k)
  as.vector(.autodesn_raw_beta(bank$models[[cp$draws$model[k]]],matrix(cp$readout_beta[[k]],1))))
 cp$bank$divisors[]<-1
 cp$coefficient_transport<-"Frozen standardized to raw coefficients, including intercept shift"
 # Production forecast API versus the independently assembled rolling adapter.
 public<-readRDS(file.path(d,"attempt_1/chain_1.rds"))$fit;public$bank<-bank
 public$draws<-cp$draws;public$beta<-cp$readout_beta
 ids<-1:192;noise<-c1_noise(cfg$innovation_seed,2500L,8L,192L,30L)
 direct<-forecast_paths.autodesn_fit(public,30L,draw_index=ids,inner_paths=8L,innovations=noise,backend="batched")
 thin<-cp;thin$draws<-cp$draws[ids,,drop=FALSE];thin$beta<-cp$beta[ids]
 states<-lapply(cp$bank$templates,function(x) x$states$H_last)
 ref<-hr_auto(thin,states,bank$history_scaled,30L,8L,noise)
 error<-max(abs(direct$yrep-ref$yrep),abs(direct$mu_draws-ref$mu_draws));stopifnot(error<1e-10)
 rhs_json(list(complete=TRUE,max_path_error=error,future_observations_used=FALSE),file.path(d,"transport_parity.json"))
 rhs_save(cp,file.path(d,"posterior_checkpoint.rds"))
}
cat("Rebalanced requested-prior fit qualified; no test forecasts issued by this fitting driver.\n")
