# Archive only forecast-relevant reservoirs, preserving original model IDs.
# Zero-probability templates are replaced by NULL; all 384 joint draws,
# coefficients, frozen weights, scaling history and diagnostics are retained.
args<-commandArgs(trailingOnly=TRUE)
base<-if(length(args)) args[1] else "validation/autodesn/standardized_rhs/artifacts"
out<-"validation/autodesn/standardized_rhs/evidence";dir.create(out,recursive=TRUE,showWarnings=FALSE)
cfg<-jsonlite::fromJSON("validation/autodesn/standardized_rhs/configuration.json")
b<-readRDS(file.path(base,"standardized_bank/bank.rds"))
geometry<-list(model_info=b$model_info,prior=b$prior,preprocessing=b$preprocessing,keep_idx=b$keep_idx,
 models=lapply(b$models,function(m) m[c("d","raw_d","divisor","feature_center","feature_scale","active_features","dropped_features","readout_scale_info")]))
saveRDS(geometry,file.path(out,"frozen_feature_geometry.rds"),compress="xz")
rm(b,geometry);gc(FALSE)
for(i in seq_len(nrow(cfg$scenarios))) {
 sc<-cfg$scenarios[i,];d<-file.path(base,sc$id,sc$method);path<-file.path(d,"posterior_checkpoint.rds")
 if(!file.exists(path)) next
 cp<-readRDS(path);stopifnot(isTRUE(cp$qualified),length(cp$beta)==384L)
 used<-sort(unique(cp$draws$model));unused<-setdiff(seq_along(cp$bank$templates),used)
 cp$bank$templates[unused]<-rep(list(NULL),length(unused))
 cp$archival_note<-"Unused templates are NULL; original model indices and every predictive joint draw are preserved. Rebuild the bank for inference."
 saveRDS(cp,file.path(out,paste0(sc$id,"_forecast_checkpoint.rds")),compress="xz")
 cat(sc$id,"forecast checkpoint:",length(used),"retained reservoir templates\n")
 rm(cp);gc(FALSE)
}
