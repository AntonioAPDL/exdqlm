# Recovery audit only: this does not rerun the expanded forecasting study.
source("validation/autodesn/load_checkout.R")
folder <- "validation/autodesn/broad_rolling/recovery"
out <- file.path(folder,"audit")
dir.create(out,recursive=TRUE,showWarnings=FALSE)
cp <- readRDS(file.path(folder,"smooth_scale_r01_AutoDESN_Broad_checkpoint.rds"))
stopifnot(identical(cp$bank$keep_idx,501:2500),cp$bank$n==2000L,
 length(cp$bank$history)==2500L,nrow(cp$draws)==384L,
 all(cp$draws$variance>0),all(cp$draws$ridge_precision>0),
 all(cp$draws$chain %in% 1:3))
stopifnot(all(is.finite(cp$diagnostics$parameters$rhat)),
 max(cp$diagnostics$parameters$rhat)<=1.01,
 min(cp$diagnostics$parameters$ess_spectral)>=400,
 max(cp$diagnostics$models$chain_range)<=.05)
stopifnot(length(cp$beta)==384L,
 all(vapply(seq_along(cp$beta),function(k)
   length(cp$beta[[k]])==1L+sum(cp$bank$templates[[cp$draws$model[k]]]$reservoir$n),logical(1))))
write.csv(cp$model_summary,file.path(out,"recovered_model_summary.csv"),row.names=FALSE)
write.csv(cp$diagnostics$parameters,file.path(out,"recovered_parameter_diagnostics.csv"),row.names=FALSE)
write.csv(cp$diagnostics$models,file.path(out,"recovered_model_diagnostics.csv"),row.names=FALSE)
writeLines(capture.output(str(cp,max.level=3)),file.path(out,"checkpoint_structure.txt"))
writeLines(capture.output(sessionInfo()),file.path(out,"session.txt"))
found <- list();seen <- list()
visit <- function(x,depth=0L) {
 if(depth>15L)return(invisible(NULL))
 if(is.function(x)) {
  env <- environment(x)
  if(is.null(env) || identical(env,.GlobalEnv) || identical(env,baseenv()) ||
     identical(env,emptyenv()) || isNamespace(env))return(invisible(NULL))
  if(any(vapply(seen,identical,logical(1),env)))return(invisible(NULL))
  seen[[length(seen)+1L]] <<- env
  for(nm in ls(env,all.names=TRUE)) {
   value <- get(nm,env,inherits=FALSE)
   if(nm %in% c("grid","balanced_design","factors","specifications","specs") &&
      (is.data.frame(value)||is.list(value))) {
    key <- paste0(length(found)+1L,"_",nm);found[[key]] <<- value
    if(is.data.frame(value))write.csv(value,file.path(out,paste0(key,".csv")),row.names=FALSE)
   }
  }
 } else if(is.list(x)) for(value in x)visit(value,depth+1L)
 invisible(NULL)
}
visit(cp)
saveRDS(found,file.path(out,"recovered_specification_metadata.rds"),compress="xz")
writeLines(capture.output(str(found,max.level=2)),file.path(out,"recovered_metadata_structure.txt"))
writeLines('{"checkpoint_restored":true,"expanded_forecast_study_complete":false}',file.path(out,"audit_status.json"))
cat("RECOVERED_CHECKPOINT_RESTORATION_PASS\n")
cat("Recovered candidate count",nrow(cp$model_summary),"metadata objects",length(found),"\n")
