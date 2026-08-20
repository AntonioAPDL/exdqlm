#!/usr/bin/env Rscript
suppressPackageStartupMessages(if(!requireNamespace("jsonlite",quietly=TRUE)) stop("Missing jsonlite"))
args<-commandArgs(trailingOnly=TRUE); arg<-function(flag,default=NULL){i<-which(args==flag);if(!length(i))default else args[i[1]+1]}
repo<-normalizePath(arg("--repo-root",system("git rev-parse --show-toplevel",intern=TRUE)),winslash="/",mustWork=TRUE)
source(file.path(repo,"validation/fitforecast_v2/R/qdesn_canonical_gap_mcmc_v2.R"))
mat<-normalizePath(arg("--materialization-root"),winslash="/",mustWork=TRUE); stage<-arg("--stage","static")
output<-normalizePath(arg("--output",file.path(mat,paste0(stage,"_verification.json"))),winslash="/",mustWork=FALSE)
stub<-file.path(repo,"config/validation",qdesn_cgcv2_stage)
targets<-qdesn_ssv2_read_csv(paste0(stub,"_target_cells.csv")); profiles<-qdesn_ssv2_read_csv(paste0(stub,"_candidate_profiles.csv"))
history<-qdesn_ssv2_read_csv(file.path(repo,"config/validation/qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_history_signature_ledger.csv"))
registry<-qdesn_ssv2_read_csv(file.path(mat,"canonical_source_registry.csv")); manifest<-qdesn_ssv2_read_json(file.path(mat,"materialization_manifest.json"))
base_plans<-lapply(c(smoke="smoke_plan.csv",calibration="calibration_plan.csv",screen="screen_plan.csv"),function(x)qdesn_ssv2_read_csv(file.path(mat,x)))
configs<-unlist(lapply(base_plans,`[[`,"config_path")); jobs<-lapply(configs,qdesn_ssv2_read_json)
job_ok<-vapply(jobs,function(j){lik<-as.character(j$likelihood_target);all(
  identical(as.character(j$schema_version),qdesn_cgcv2_schema),identical(as.integer(j$study_contract$train_window),c(8501L,9000L)),
  identical(as.integer(j$study_contract$forecast_window),c(9001L,10000L)),identical(as.integer(j$study_contract$max_lead),30L),
  identical(as.integer(j$study_contract$origin_stride),30L),!isTRUE(j$config$metrics$rolling_origin$refit_per_origin),
  lik!="exal"||identical(as.character(j$config$inference$mcmc$slice$core_update_mode),qdesn_cgcv2_method_id),
  as.integer(j$root_spec$effective_readout_dimension)<=900L,identical(as.integer(j$config$cpp$postpred_threads),1L),
  !isTRUE(j$config$outputs$keep_draws),!isTRUE(j$config$outputs$keep_mcmc_vb_init),!isTRUE(j$study_contract$posterior_recycled_as_prior))},logical(1))
checks<-c(targets=nrow(targets)==4L,profiles=nrow(profiles)==64L&&all(table(profiles$target_cell_id)==16L),
 novelty=!any(profiles$profile_signature%in%history$profile_signature),capacity=all(profiles$effective_readout_dimension<=900L),
 sources=nrow(registry)==4L&&all(file.exists(registry$series_wide_path))&&all(vapply(registry$series_wide_path,qdesn_ssv2_sha256,character(1))==registry$series_wide_sha256),
 parent_hashes=all(file.exists(registry$parent_request_path))&&all(vapply(registry$parent_request_path,qdesn_ssv2_sha256,character(1))==registry$parent_request_sha256),
 plans=nrow(base_plans$smoke)==2L&&nrow(base_plans$calibration)==4L&&nrow(base_plans$screen)==128L,
 configs=length(configs)==134L&&!anyDuplicated(configs)&&all(file.exists(configs)),jobs=all(job_ok),
 manifest=manifest$target_cells==4L&&manifest$candidate_profiles==64L,
 branch=identical(system("git branch --show-current",intern=TRUE),qdesn_cgcv2_branch))
runtime<-NULL
if(stage!="static"){
 plan<-qdesn_ssv2_read_csv(normalizePath(arg("--plan"),winslash="/",mustWork=TRUE));run_tag<-arg("--run-tag")
 runtime<-do.call(rbind,lapply(seq_len(nrow(plan)),function(i){root<-qdesn_cgcv2_job_root(repo,run_tag,plan$job_id[i]);sp<-file.path(root,"job_status.json");s<-if(file.exists(sp))qdesn_ssv2_read_json(sp)else list(status="MISSING");v<-qdesn_cgcv2_metric_values(root);data.frame(job_id=plan$job_id[i],status=as.character(s$status),finite=all(is.finite(v[unlist(strsplit(plan$target_metrics[i],";",fixed=TRUE))])),binary=as.integer(s$binary_payloads_remaining%||%NA_integer_))}))
 checks<-c(checks,runtime_rows=nrow(runtime)==nrow(plan),runtime_success=all(runtime$status=="SUCCESS"),runtime_metrics=all(runtime$finite),runtime_storage=all(runtime$binary==0L));qdesn_ssv2_write_csv(runtime,sub("[.]json$","_runtime.csv",output))
}
binaries<-list.files(mat,pattern="[.](rds|rda|RData)$",recursive=TRUE,full.names=TRUE,ignore.case=TRUE);checks<-c(checks,materialization_storage=!length(binaries))
result<-list(schema_version="qdesn_canonical_gap_mcmc_v2_verification_v1",generated_at=as.character(Sys.time()),stage=stage,decision=if(all(checks))"PASS"else"FAIL",checks=as.list(checks),runtime_rows=if(is.null(runtime))0L else nrow(runtime),forbidden_payloads=as.list(binaries))
qdesn_ssv2_write_json(result,output);cat(sprintf("VERIFY_%s checks=%d output=%s\n",result$decision,length(checks),output));if(!all(checks))stop("Failed: ",paste(names(checks)[!checks],collapse=", "))
