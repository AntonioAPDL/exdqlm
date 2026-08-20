#!/usr/bin/env Rscript
suppressPackageStartupMessages(if(!requireNamespace("jsonlite",quietly=TRUE))stop("Missing jsonlite"))
args<-commandArgs(trailingOnly=TRUE);arg<-function(flag,default=NULL){i<-which(args==flag);if(!length(i))default else args[i[1]+1]}
repo<-normalizePath(arg("--repo-root",system("git rev-parse --show-toplevel",intern=TRUE)),winslash="/",mustWork=TRUE)
source(file.path(repo,"validation/fitforecast_v2/R/qdesn_canonical_gap_mcmc_v2.R"))
run_tag<-arg("--run-tag");plan<-qdesn_ssv2_read_csv(normalizePath(arg("--plan"),winslash="/",mustWork=TRUE));output<-normalizePath(arg("--output"),winslash="/",mustWork=FALSE)
rows<-do.call(rbind,lapply(seq_len(nrow(plan)),function(i){
 root<-qdesn_cgcv2_job_root(repo,run_tag,plan$job_id[i]);sp<-file.path(root,"job_status.json");started<-file.path(root,"job_started.json")
 s<-if(file.exists(sp))qdesn_ssv2_read_json(sp)else if(file.exists(started))list(status="RUNNING")else list(status="PENDING")
 progress_files<-list.files(file.path(root,"telemetry"),pattern="progress.*[.]csv$",full.names=TRUE)
 iteration<-0L;if(length(progress_files)){z<-tryCatch(qdesn_ssv2_read_csv(progress_files[1]),error=function(e)NULL);if(!is.null(z)){col<-intersect(c("iteration","iter","mcmc_iteration"),names(z));if(length(col))iteration<-max(as.integer(z[[col[1]]]),na.rm=TRUE)}}
 total<-as.integer(plan$expected_n_burn[i]+plan$expected_n_mcmc[i]);if(identical(as.character(s$status),"SUCCESS"))iteration<-total;v<-qdesn_cgcv2_metric_values(root)
 data.frame(stage=plan$stage[i],target_cell_id=plan$target_cell_id[i],likelihood_target=plan$likelihood_target[i],candidate_id=plan$candidate_id[i],chain_id=plan$chain_id[i],status=as.character(s$status),iteration=iteration,total_iterations=total,percent=round(100*iteration/total,1),fit_qtrue_rmse=unname(v[1]),forecast_qtrue_mae_H1000=unname(v[2]),forecast_check_loss_H1000=unname(v[3]),binary_payloads=as.integer(s$binary_payloads_remaining%||%NA_integer_),stringsAsFactors=FALSE)
}))
qdesn_ssv2_write_csv(rows,output);summary<-as.data.frame(table(rows$status),stringsAsFactors=FALSE);names(summary)<-c("status","jobs");qdesn_ssv2_write_csv(summary,sub("[.]csv$","_summary.csv",output));cat(sprintf("HEALTH jobs=%d success=%d running=%d pending=%d failed=%d\n",nrow(rows),sum(rows$status=="SUCCESS"),sum(rows$status=="RUNNING"),sum(rows$status=="PENDING"),sum(rows$status=="FAIL")))
