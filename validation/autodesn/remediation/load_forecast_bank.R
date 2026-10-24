# Attach verified real propagation maps to the exact inference matrix view.
# This helper reads training objects only, never held-out outcomes or truth.
remediation_forecast_bank<-function(family='F1'){
 stopifnot(family%in%c('F1','F2','F2flat'));root<-'validation/autodesn/remediation'
 manifest<-jsonlite::fromJSON(file.path(root,'artifacts/inference_cache_manifest.json'));maps<-jsonlite::fromJSON(file.path(root,'evidence/compact_forecast_templates.json'))
 stopifnot(isTRUE(manifest$complete),isTRUE(maps$complete),maps$reservoirs==426L,
  identical(digest::digest(file=manifest$path,algo='sha256'),manifest$sha256),
  identical(digest::digest(file=maps$templates_path,algo='sha256'),maps$templates_sha256),
  identical(maps$source_bank_sha256,manifest$source_bank_sha256))
 b<-readRDS(manifest$path);entry<-manifest$extensions[[family]]
 stopifnot(identical(digest::digest(file=entry$path,algo='sha256'),entry$sha256))
 b$templates<-readRDS(maps$templates_path);b$meta$inference_only<-FALSE;b$extension<-readRDS(entry$path)
 b$extension$initial_states<-lapply(b$templates,.ext_template_initial);b$extension$forecast_map_id<-.ext_forecast_map_id(b)
 stopifnot(identical(b$extension$id,entry$bank_id),identical(b$extension$id,maps$identities[[family]]$conditional_bank_id),identical(b$extension$forecast_map_id,maps$identities[[family]]$forecast_map_id))
 class(b)<-c('autodesn_extended_bank',class(b));b
}
