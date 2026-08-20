#!/usr/bin/env Rscript

suppressPackageStartupMessages(for (p in c("digest","jsonlite","pkgload"))
  if (!requireNamespace(p,quietly=TRUE)) stop("Missing package: ",p))
args <- commandArgs(trailingOnly=TRUE)
arg <- function(flag,default=NULL) { i<-which(args==flag); if(!length(i)) default else args[i[1]+1] }
repo <- normalizePath(arg("--repo-root",system("git rev-parse --show-toplevel",intern=TRUE)),winslash="/",mustWork=TRUE)
setwd(repo); pkgload::load_all(repo,quiet=TRUE)
source(file.path(repo,"validation/fitforecast_v2/R/qdesn_canonical_gap_mcmc_v2.R"))
from <- arg("--from"); run_tag <- arg("--run-tag"); mat <- normalizePath(arg("--materialization-root"),winslash="/",mustWork=TRUE)
out <- normalizePath(arg("--output-root",file.path(mat,"adaptive")),winslash="/",mustWork=FALSE); dir.create(out,recursive=TRUE,showWarnings=FALSE)
if (!from %in% c("screen","refine","confirmation") || !nzchar(run_tag)) stop("Valid --from and --run-tag are required")
plan <- qdesn_ssv2_read_csv(file.path(mat,paste0(from,"_plan.csv")))
collect <- do.call(rbind,lapply(seq_len(nrow(plan)),function(i){
  root <- qdesn_cgcv2_job_root(repo,run_tag,plan$job_id[i]); status_path<-file.path(root,"job_status.json")
  status <- if(file.exists(status_path)) qdesn_ssv2_read_json(status_path) else list(status="MISSING")
  v <- qdesn_cgcv2_metric_values(root)
  data.frame(plan[i,,drop=FALSE],status=as.character(status$status),
    fit_qtrue_rmse=unname(v["fit_qtrue_rmse"]),forecast_qtrue_mae_H1000=unname(v["forecast_qtrue_mae_H1000"]),
    forecast_check_loss_H1000=unname(v["forecast_check_loss_H1000"]),stringsAsFactors=FALSE)
}))
qdesn_ssv2_write_csv(collect,file.path(out,paste0(from,"_results.csv")))
if(any(collect$status!="SUCCESS")) stop("Cannot advance: incomplete or failed jobs")
metrics <- c("forecast_qtrue_mae_H1000","forecast_check_loss_H1000")
targets <- qdesn_ssv2_read_csv(file.path(repo,"config/validation",paste0(qdesn_cgcv2_stage,"_target_cells.csv")))
profiles <- qdesn_ssv2_read_csv(file.path(repo,"config/validation",paste0(qdesn_cgcv2_stage,"_candidate_profiles.csv")))
registry_path <- file.path(mat,"canonical_source_registry.csv")
windows <- qdesn_ssv2_read_csv(file.path(mat,"source_window_registry.csv"))
make_job <- function(candidate,cell,stage,chain){
  p<-profiles[profiles$candidate_id==candidate,,drop=FALSE]; t<-targets[targets$target_cell_id==cell,,drop=FALSE]
  s<-windows[windows$family==t$family & abs(windows$tau-t$tau)<1e-10 & windows$m==p$m & windows$washout==p$washout,,drop=FALSE][1,,drop=FALSE]
  job<-qdesn_cgcv2_apply_seeds(qdesn_cgcv2_make_job(repo,p,t,s,stage,registry_path,chain,sprintf("%s_r%02d",stage,chain)))
  path<-file.path(mat,"configs",stage,paste0(job$job_id,".json")); qdesn_ssv2_write_json(job,path)
  data.frame(job_id=job$job_id,stage=stage,target_cell_id=cell,likelihood_target=job$likelihood_target,
    target_metrics=paste(job$target_metrics,collapse=";"),candidate_id=candidate,chain_id=chain,reservoir_seed_id=job$reservoir_seed_id,
    source_id=job$source_id,objective_metric=job$objective_metric,current_value=job$current_value,comparator_value=job$comparator_value,
    config_path=path,config_sha256=qdesn_ssv2_sha256(path),expected_n_burn=job$config$inference$mcmc$n_burn,
    expected_n_mcmc=job$config$inference$mcmc$n_mcmc,effective_readout_dimension=job$root_spec$effective_readout_dimension,
    timeout_seconds=job$config$validation$timeout_seconds,stringsAsFactors=FALSE)
}
aggregate_candidates <- function(x){
  keys<-unique(x[,c("target_cell_id","candidate_id")]); do.call(rbind,lapply(seq_len(nrow(keys)),function(i){
    z<-x[x$target_cell_id==keys$target_cell_id[i]&x$candidate_id==keys$candidate_id[i],,drop=FALSE]
    data.frame(keys[i,,drop=FALSE],chains=nrow(z),fit_qtrue_rmse=mean(z$fit_qtrue_rmse),
      forecast_qtrue_mae_H1000=mean(z$forecast_qtrue_mae_H1000),forecast_check_loss_H1000=mean(z$forecast_check_loss_H1000))
  }))
}
agg<-aggregate_candidates(collect); qdesn_ssv2_write_csv(agg,file.path(out,paste0(from,"_candidate_summary.csv")))
if(from=="screen"){
  selected<-do.call(rbind,lapply(split(agg,agg$target_cell_id),function(x){
    t<-targets[targets$target_cell_id==x$target_cell_id[1],]; x$score<-x$forecast_qtrue_mae_H1000/t$current_forecast_qtrue_mae_H1000 + .25*x$forecast_check_loss_H1000/t$current_forecast_check_loss_H1000
    head(x[order(x$score,x$forecast_qtrue_mae_H1000),],3)
  }))
  next_plan<-do.call(rbind,lapply(seq_len(nrow(selected)),function(i) do.call(rbind,lapply(1:3,function(ch) make_job(selected$candidate_id[i],selected$target_cell_id[i],"refine",ch)))))
  qdesn_ssv2_write_csv(selected,file.path(out,"screen_selection.csv")); qdesn_ssv2_write_csv(next_plan,file.path(mat,"refine_plan.csv"))
  cat(sprintf("ADVANCE_OK from=screen selected=%d refine_jobs=%d\n",nrow(selected),nrow(next_plan)))
} else if(from=="refine"){
  nominations<-list()
  for(cell in unique(agg$target_cell_id)) for(metric in metrics){
    x<-agg[agg$target_cell_id==cell,,drop=FALSE]; t<-targets[targets$target_cell_id==cell,,drop=FALSE]
    current<-t[[paste0("current_",metric)]]; x<-x[order(x[[metric]]),,drop=FALSE]
    if(nrow(x)&&is.finite(x[[metric]][1])&&x[[metric]][1]<current) nominations[[length(nominations)+1]]<-data.frame(
      target_cell_id=cell,metric=metric,candidate_id=x$candidate_id[1],refine_value=x[[metric]][1],current_value=current,gain=current-x[[metric]][1])
  }
  nominations<-if(length(nominations)) do.call(rbind,nominations) else data.frame()
  qdesn_ssv2_write_csv(nominations,file.path(out,"refine_nominations.csv"))
  pairs<-unique(nominations[,c("target_cell_id","candidate_id"),drop=FALSE])
  next_plan<-if(nrow(pairs)) do.call(rbind,lapply(seq_len(nrow(pairs)),function(i) do.call(rbind,lapply(1:3,function(ch) make_job(pairs$candidate_id[i],pairs$target_cell_id[i],"confirmation",ch))))) else data.frame()
  qdesn_ssv2_write_csv(next_plan,file.path(mat,"confirmation_plan.csv")); cat(sprintf("ADVANCE_OK from=refine nominations=%d confirmation_jobs=%d\n",nrow(nominations),nrow(next_plan)))
} else {
  nominations<-qdesn_ssv2_read_csv(file.path(out,"refine_nominations.csv")); decisions<-nominations
  decisions$confirmation_value<-NA_real_; decisions$strict_improvement<-FALSE
  for(i in seq_len(nrow(decisions))){ x<-agg[agg$target_cell_id==decisions$target_cell_id[i]&agg$candidate_id==decisions$candidate_id[i],]; value<-x[[decisions$metric[i]]][1]
    decisions$confirmation_value[i]<-value; decisions$strict_improvement[i]<-is.finite(value)&&value<decisions$current_value[i] }
  qdesn_ssv2_write_csv(decisions,file.path(out,"confirmation_decision_ledger.csv"))
  qdesn_ssv2_write_json(list(schema_version="qdesn_canonical_gap_mcmc_v2_closeout_v1",generated_at=as.character(Sys.time()),
    decision=if(any(decisions$strict_improvement)) "STRICT_GAINS_ELIGIBLE_FOR_PROMOTION" else "NO_CONFIRMED_GAIN_RETAIN_CURRENT",
    confirmed_jobs=nrow(collect),promotable_metrics=sum(decisions$strict_improvement),diagnostics_are_veto=FALSE),file.path(out,"closeout.json"))
  cat(sprintf("CLOSEOUT_OK promotable_metrics=%d\n",sum(decisions$strict_improvement)))
}
