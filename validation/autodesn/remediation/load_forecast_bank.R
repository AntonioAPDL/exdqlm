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

# Prefix-specific and selected-mean variants. Reattach only checksum-verified
# maps from the same training boundary; the inference target ID stays fixed.
remediation_study_forecast_bank<-function(family='F1',prefix_manifest='',selection=NULL){
 root<-'validation/autodesn/remediation'
 if(!exists('remediation_study_input',mode='function'))source(file.path(root,'fit_inputs.R'),local=environment())
 input<-remediation_study_input(root,family,prefix_manifest,TRUE,selection)
 b<-input$bank;conditional_id<-b$extension$id
 if(nzchar(prefix_manifest)){
  manifest<-jsonlite::fromJSON(prefix_manifest,simplifyVector=FALSE)
  files<-Filter(function(f)basename(f$path)=='forecast_templates.rds',manifest$files)
  stopifnot(length(files)==1L);maps<-files[[1]]
  stopifnot(identical(digest::digest(file=maps$path,algo='sha256'),maps$sha256))
  b$templates<-readRDS(maps$path)
 }else{
  maps<-jsonlite::fromJSON(file.path(root,'evidence/compact_forecast_templates.json'))
  stopifnot(isTRUE(maps$complete),identical(maps$source_bank_sha256,input$cache_manifest$source_bank_sha256),
    identical(digest::digest(file=maps$templates_path,algo='sha256'),maps$templates_sha256))
  b$templates<-readRDS(maps$templates_path)
 }
 stopifnot(length(b$templates)==length(b$models))
 b$meta$inference_only<-FALSE
 b$extension$initial_states<-lapply(b$templates,.ext_template_initial)
 b$extension$forecast_map_id<-.ext_forecast_map_id(b)
 stopifnot(identical(b$extension$id,conditional_id),length(b$history)==input$cutoff)
 maximum_error<-0
 for(m in seq_along(b$models)){
  h<-b$extension$initial_states[[m]];raw<-.ext_origin_features(b,m,h)
  error<-max(abs(.autodesn_feature_apply(b$models[[m]],matrix(raw,1))-b$models[[m]]$X[b$n,-1L]))
  stopifnot(error<1e-10);maximum_error<-max(maximum_error,error)
 }
 attr(b,'remediation_forecast_binding')<-list(conditional_bank_id=conditional_id,
  forecast_map_id=b$extension$forecast_map_id,maximum_terminal_feature_error=maximum_error,
  cutoff=input$cutoff,prefix_manifest_sha256=input$prefix_sha256,mean_selection=selection)
 b
}
